<?php
declare(strict_types=1);

// Workflow rules at the application level. The database triggers enforce the same
// rules independently, so a bug here can never publish unapproved content.

/** What each action does: [new status, audit action name]. */
const WORKFLOW_ACTIONS = [
    'submit'   => ['in_review', 'submitted'],
    'withdraw' => ['draft',     'returned'],
    'approve'  => ['approved',  'approved'],
    'return'   => ['draft',     'returned'],
    'publish'  => ['published', 'published'],
    'reopen'   => ['draft',     'returned'],
    'archive'  => ['archived',  'archived'],
    'restore'  => ['draft',     'restored'],
];

/** Which actions a role may take on content in a given status: [action => button label]. */
function allowed_actions(string $status, string $role): array
{
    $staff = in_array($role, ['editor', 'administrator'], true);
    $admin = $role === 'administrator';
    $a = [];
    switch ($status) {
        case 'draft':
            if ($staff) { $a['submit'] = 'Submit for review'; $a['archive'] = 'Archive'; }
            break;
        case 'in_review':
            if ($admin) { $a['approve'] = 'Approve'; $a['return'] = 'Return for revision'; }
            if ($staff) { $a['withdraw'] = 'Withdraw to draft'; $a['archive'] = 'Archive'; }
            break;
        case 'approved':
            if ($admin) { $a['publish'] = 'Publish'; }
            if ($staff) { $a['reopen'] = 'Move back to draft'; $a['archive'] = 'Archive'; }
            break;
        case 'published':
            if ($staff) { $a['reopen'] = 'Unpublish and edit (moves back to draft)'; $a['archive'] = 'Archive'; }
            break;
        case 'archived':
            if ($staff) { $a['restore'] = 'Restore as draft'; }
            break;
    }
    return $a;
}

function write_audit(PDO $pdo, int $contentId, int $actorId, string $action, ?string $from, ?string $to, ?string $detail = null): void
{
    $pdo->prepare(
        'INSERT INTO audit_event (content_id, actor_id, action, from_status, to_status, detail)
         VALUES (?, ?, ?, ?, ?, ?)'
    )->execute([$contentId, $actorId, $action, $from, $to, $detail]);
}

/**
 * Move one content row to a new status, write the audit entry (and an optional
 * reviewer comment) in a single transaction. Throws PDOException if a database
 * rule is violated; callers show the message to the user.
 */
function change_status(
    int $contentId,
    string $to,
    array $user,
    string $auditAction,
    ?string $detail = null,
    ?string $commentDecision = null,
    ?string $commentText = null
): void {
    $pdo = db();
    $pdo->beginTransaction();
    try {
        $st = $pdo->prepare('SELECT status FROM location_content WHERE content_id = ? FOR UPDATE');
        $st->execute([$contentId]);
        $from = $st->fetchColumn();
        if ($from === false) {
            throw new RuntimeException('That content no longer exists.');
        }
        if ($to === 'approved') {
            // approved_by is set in the same statement; a trigger confirms the approver is an administrator.
            $pdo->prepare('UPDATE location_content SET status = ?, approved_by = ? WHERE content_id = ?')
                ->execute([$to, $user['user_id'], $contentId]);
        } else {
            $pdo->prepare('UPDATE location_content SET status = ? WHERE content_id = ?')
                ->execute([$to, $contentId]);
        }
        write_audit($pdo, $contentId, (int)$user['user_id'], $auditAction, (string)$from, $to, $detail);
        if ($commentDecision !== null) {
            $pdo->prepare(
                'INSERT INTO review_comment (content_id, reviewer_id, decision, comment_text) VALUES (?, ?, ?, ?)'
            )->execute([$contentId, $user['user_id'], $commentDecision, $commentText]);
        }
        $pdo->commit();
    } catch (Throwable $t) {
        if ($pdo->inTransaction()) {
            $pdo->rollBack();
        }
        throw $t;
    }
}

/** Turn a database rule violation into a message a person can read. */
function friendly_db_error(Throwable $t): string
{
    if ($t instanceof PDOException && ($t->errorInfo[0] ?? '') === '45000') {
        return 'Not allowed: ' . ($t->errorInfo[2] ?? 'a database rule blocked this change.');
    }
    if ($t instanceof RuntimeException) {
        return $t->getMessage();
    }
    error_log('Unexpected database error: ' . $t->getMessage());
    return 'Unexpected error. Nothing was changed. Try again, or tell the administrator.';
}

/** Suggested heading text for a new content entry. */
function default_heading(string $sectionCode, string $langCode, string $sectionLabel): string
{
    $es = ['building_history' => 'Historia del edificio', 'name_history' => 'Historia del nombre'];
    return $langCode === 'es' ? ($es[$sectionCode] ?? $sectionLabel) : $sectionLabel;
}
