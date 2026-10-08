<?php
declare(strict_types=1);
require __DIR__ . '/../src/bootstrap.php';

$user  = require_login();
$staff = is_staff($user);

// ---- Add a building (editors and administrators) -----------------------------
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    csrf_check();
    if (!$staff) {
        render_error('Only editors and administrators can add buildings.', 403);
    }
    $name = trim((string)($_POST['name'] ?? ''));
    if ($name === '' || mb_strlen($name) > 150) {
        flash('error', 'Enter a building name (up to 150 characters).');
        redirect('index.php');
    }
    $pdo = db();
    try {
        $pdo->beginTransaction();
        $pdo->prepare('INSERT INTO location (name, created_by) VALUES (?, ?)')->execute([$name, $user['user_id']]);
        $id = (int)$pdo->lastInsertId();
        $pdo->prepare('INSERT INTO location_code (location_id, token) VALUES (?, ?)')->execute([$id, uuid4()]);
        $pdo->commit();
        flash('ok', 'Building added. Open any cell below to start writing its content.');
    } catch (Throwable $t) {
        if ($pdo->inTransaction()) { $pdo->rollBack(); }
        flash('error', friendly_db_error($t));
    }
    redirect('index.php');
}

$pdo   = db();
$locs  = $pdo->query('SELECT location_id, name FROM location ORDER BY name')->fetchAll();
$secs  = $pdo->query('SELECT section_type_id, code, label FROM section_type ORDER BY sort_order')->fetchAll();
$langs = $pdo->query('SELECT language_id, code, name FROM language ORDER BY language_id')->fetchAll();
$auds  = $pdo->query('SELECT audience_id, code, label FROM audience_level ORDER BY sort_order')->fetchAll();
$cells = [];
foreach ($pdo->query('SELECT location_id, section_type_id, language_id, audience_id, status FROM location_content') as $r) {
    $cells[$r['location_id'] . '-' . $r['section_type_id'] . '-' . $r['language_id'] . '-' . $r['audience_id']] = $r['status'];
}

page_header('Dashboard', $user);
echo '<h1>Dashboard</h1>';
if ($user['role'] === 'viewer') {
    echo '<p class="muted">You have read-only access. Published content is shown below.</p>';
}
if (!$locs) {
    echo '<p>No buildings yet.' . ($staff ? ' Add the first one below.' : '') . '</p>';
}

foreach ($locs as $loc) {
    echo '<section class="card"><h2>' . e($loc['name']) . '</h2>';
    echo '<div class="table-scroll"><table class="grid"><thead><tr><th>Section and reading level</th>';
    foreach ($langs as $lg) {
        echo '<th>' . e($lg['name']) . '</th>';
    }
    echo '</tr></thead><tbody>';
    foreach ($secs as $s) {
        foreach ($auds as $a) {
            echo '<tr><th scope="row">' . e($s['label']) . '<br><span class="muted">' . e($a['label']) . '</span></th>';
            foreach ($langs as $lg) {
                $key    = $loc['location_id'] . '-' . $s['section_type_id'] . '-' . $lg['language_id'] . '-' . $a['audience_id'];
                $status = $cells[$key] ?? null;
                $url    = 'content.php?loc=' . $loc['location_id'] . '&sec=' . $s['section_type_id']
                        . '&lang=' . $lg['language_id'] . '&aud=' . $a['audience_id'];
                echo '<td>';
                if ($status === null) {
                    echo $staff ? '<a class="btn btn-small btn-ghost" href="' . e($url) . '">+ Add</a>' : '<span class="muted">-</span>';
                } elseif ($staff) {
                    echo status_badge($status) . ' <a href="' . e($url) . '">Open</a>';
                } elseif ($status === 'published') {
                    echo status_badge($status) . ' <a href="' . e($url) . '">View</a>';
                } else {
                    echo '<span class="muted">-</span>';
                }
                echo '</td>';
            }
            echo '</tr>';
        }
    }
    echo '</tbody></table></div></section>';
}

if ($staff) {
    ?>
    <section class="card">
        <h2>Add a building</h2>
        <form method="post" action="index.php" class="inline-form">
            <?= csrf_field() ?>
            <label>Building name
                <input type="text" name="name" maxlength="150" required>
            </label>
            <button type="submit" class="btn">Add building</button>
        </form>
        <p class="muted">A permanent QR code token is created for each building automatically.</p>
    </section>
    <?php
}
page_footer();
