<?php
declare(strict_types=1);
require __DIR__ . '/../src/bootstrap.php';

$user  = require_login();
$staff = is_staff($user);
$pdo   = db();

// Only plain whole numbers are accepted; anything else becomes 0 and gives a 404.
function id_param(string $name): int
{
    $v = $_GET[$name] ?? '';
    return is_string($v) && ctype_digit($v) ? (int)$v : 0;
}
$loc  = id_param('loc');
$sec  = id_param('sec');
$lang = id_param('lang');
$aud  = id_param('aud');
$self = 'content.php?loc=' . $loc . '&sec=' . $sec . '&lang=' . $lang . '&aud=' . $aud;

$st = $pdo->prepare(
    'SELECT l.name AS loc_name, s.code AS sec_code, s.label AS sec_label,
            g.code AS lang_code, g.name AS lang_name, a.label AS aud_label
       FROM location l, section_type s, language g, audience_level a
      WHERE l.location_id = ? AND s.section_type_id = ? AND g.language_id = ? AND a.audience_id = ?'
);
$st->execute([$loc, $sec, $lang, $aud]);
$meta = $st->fetch();
if (!$meta) {
    render_error('That building, section, language or reading level does not exist.', 404);
}

function load_row(PDO $pdo, int $loc, int $sec, int $lang, int $aud): array|false
{
    $st = $pdo->prepare(
        'SELECT * FROM location_content
          WHERE location_id = ? AND section_type_id = ? AND language_id = ? AND audience_id = ?'
    );
    $st->execute([$loc, $sec, $lang, $aud]);
    return $st->fetch();
}

$row = load_row($pdo, $loc, $sec, $lang, $aud);

// ---- Viewers may only read published content ----------------------------------
if (!$staff && (!$row || $row['status'] !== 'published')) {
    render_error('That content is not available.', 404);
}

// ---- Handle form submissions ---------------------------------------------------
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    csrf_check();
    if (!$staff) {
        render_error('Your role is read-only.', 403);
    }
    $act = (string)($_POST['act'] ?? '');

    try {
        if ($act === 'save') {
            $heading = trim((string)($_POST['heading'] ?? ''));
            $body    = trim((string)($_POST['body'] ?? ''));
            if ($heading === '' || mb_strlen($heading) > 200) {
                throw new RuntimeException('Enter a heading (up to 200 characters).');
            }
            if ($body === '') {
                throw new RuntimeException('The text cannot be empty.');
            }
            $pdo->beginTransaction();
            try {
                $cur = load_row($pdo, $loc, $sec, $lang, $aud);
                if (!$cur) {
                    $pdo->prepare(
                        'INSERT INTO location_content
                           (location_id, section_type_id, language_id, audience_id, heading, body, author_id)
                         VALUES (?, ?, ?, ?, ?, ?, ?)'
                    )->execute([$loc, $sec, $lang, $aud, $heading, $body, $user['user_id']]);
                    write_audit($pdo, (int)$pdo->lastInsertId(), (int)$user['user_id'], 'created', null, 'draft');
                } else {
                    if ($cur['status'] !== 'draft') {
                        throw new RuntimeException('Only drafts can be edited. Move it back to draft first.');
                    }
                    $pdo->prepare('UPDATE location_content SET heading = ?, body = ? WHERE content_id = ?')
                        ->execute([$heading, $body, $cur['content_id']]);
                    write_audit($pdo, (int)$cur['content_id'], (int)$user['user_id'], 'edited', 'draft', 'draft');
                }
                $pdo->commit();
            } catch (Throwable $t) {
                if ($pdo->inTransaction()) { $pdo->rollBack(); }
                throw $t;
            }
            flash('ok', 'Draft saved.');
        } elseif (isset(WORKFLOW_ACTIONS[$act])) {
            $cur = load_row($pdo, $loc, $sec, $lang, $aud);
            if (!$cur) {
                throw new RuntimeException('Save a draft first.');
            }
            $allowed = allowed_actions($cur['status'], $user['role']);
            if (!isset($allowed[$act])) {
                throw new RuntimeException('That action is not available for this content or your role.');
            }
            [$to, $auditAction] = WORKFLOW_ACTIONS[$act];
            $comment = trim((string)($_POST['comment'] ?? ''));
            $decision = null;
            if ($act === 'return') {
                if ($comment === '') {
                    throw new RuntimeException('Write a comment explaining what needs to change.');
                }
                $decision = 'return_for_revision';
            } elseif ($act === 'approve') {
                $decision = 'approve';
            }
            change_status((int)$cur['content_id'], $to, $user, $auditAction, $comment !== '' ? mb_substr($comment, 0, 500) : null, $decision, $comment !== '' ? $comment : null);
            flash('ok', 'Done: ' . $allowed[$act] . '.');
        } else {
            throw new RuntimeException('Unknown action.');
        }
    } catch (Throwable $t) {
        flash('error', friendly_db_error($t));
    }
    redirect($self);
}

// ---- Display ---------------------------------------------------------------------
$title = $meta['loc_name'] . ': ' . $meta['sec_label'];
page_header($title, $user);
echo '<p><a href="index.php">&larr; Dashboard</a></p>';
echo '<h1>' . e($meta['loc_name']) . '</h1>';
echo '<p class="muted">' . e($meta['sec_label']) . ' &middot; ' . e($meta['lang_name']) . ' &middot; ' . e($meta['aud_label']) . '</p>';

if (!$staff) {
    echo '<article class="card"><h2>' . e($row['heading']) . '</h2><div class="prose">' . nl2br(e($row['body'])) . '</div></article>';
    page_footer();
    exit;
}

$status   = $row['status'] ?? null;
$editable = $status === null || $status === 'draft';
echo '<p>Status: ' . ($status ? status_badge($status) : '<span class="muted">Not written yet</span>') . '</p>';

if ($editable) {
    $heading = $row['heading'] ?? default_heading($meta['sec_code'], $meta['lang_code'], $meta['sec_label']);
    $body    = $row['body'] ?? '';
    ?>
    <form method="post" action="<?= e($self) ?>" class="card">
        <?= csrf_field() ?>
        <input type="hidden" name="act" value="save">
        <label>Heading
            <input type="text" name="heading" maxlength="200" required value="<?= e($heading) ?>">
        </label>
        <label>Text (<?= e($meta['lang_name']) ?>, <?= e($meta['aud_label']) ?>)
            <textarea name="body" rows="12" required><?= e($body) ?></textarea>
        </label>
        <button type="submit" class="btn">Save draft</button>
    </form>
    <?php
} else {
    echo '<article class="card"><h2>' . e($row['heading']) . '</h2><div class="prose">' . nl2br(e($row['body'])) . '</div></article>';
}

// Workflow buttons for this status and role
$actions = $status ? allowed_actions($status, $user['role']) : [];
if ($actions) {
    echo '<section class="card"><h2>Actions</h2>';
    if ($status === 'in_review' && isset($actions['return'])) {
        echo '<p class="muted">To return this for revision you must write a comment. It is shown to the editor.</p>';
    }
    echo '<form method="post" action="' . e($self) . '">' . csrf_field();
    if ($status === 'in_review' && $user['role'] === 'administrator') {
        echo '<label>Reviewer comment<textarea name="comment" rows="3"></textarea></label>';
    }
    echo '<div class="btn-row">';
    foreach ($actions as $act => $label) {
        $cls = in_array($act, ['approve', 'publish', 'submit'], true) ? 'btn' : 'btn btn-ghost';
        echo '<button type="submit" name="act" value="' . e($act) . '" class="' . $cls . '">' . e($label) . '</button>';
    }
    echo '</div></form></section>';
}

// Review comments and history (answers "how did this get published?")
if ($row) {
    $cm = $pdo->prepare(
        'SELECT c.created_at, c.decision, c.comment_text, u.display_name
           FROM review_comment c JOIN app_user u ON u.user_id = c.reviewer_id
          WHERE c.content_id = ? ORDER BY c.comment_id DESC'
    );
    $cm->execute([$row['content_id']]);
    $comments = $cm->fetchAll();
    if ($comments) {
        echo '<section class="card"><h2>Reviewer comments</h2><ul class="plain">';
        foreach ($comments as $c) {
            echo '<li><strong>' . e($c['display_name']) . '</strong> (' . e(str_replace('_', ' ', $c['decision'])) . ', ' . e($c['created_at']) . ')'
               . ($c['comment_text'] ? '<br>' . nl2br(e($c['comment_text'])) : '') . '</li>';
        }
        echo '</ul></section>';
    }

    $h = $pdo->prepare(
        'SELECT a.occurred_at, a.action, a.from_status, a.to_status, a.detail, u.display_name
           FROM audit_event a JOIN app_user u ON u.user_id = a.actor_id
          WHERE a.content_id = ? ORDER BY a.event_id DESC LIMIT 50'
    );
    $h->execute([$row['content_id']]);
    $hist = $h->fetchAll();
    echo '<section class="card"><h2>History</h2><div class="table-scroll"><table class="grid"><thead><tr><th>When</th><th>Who</th><th>What</th><th>Change</th></tr></thead><tbody>';
    foreach ($hist as $e) {
        echo '<tr><td>' . e($e['occurred_at']) . '</td><td>' . e($e['display_name']) . '</td><td>' . e($e['action'])
           . '</td><td>' . e(($e['from_status'] ?? '') . ($e['to_status'] ? ' → ' . $e['to_status'] : '')) . '</td></tr>';
    }
    if (!$hist) {
        echo '<tr><td colspan="4" class="muted">No history yet.</td></tr>';
    }
    echo '</tbody></table></div></section>';
}
page_footer();
