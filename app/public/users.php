<?php
declare(strict_types=1);
require __DIR__ . '/../src/bootstrap.php';

$me  = require_role('administrator');
$pdo = db();

const ROLE_NAMES = ['viewer', 'editor', 'administrator'];
const MIN_PASSWORD = 10;

function log_user_action(PDO $pdo, int $actor, int $target, string $action, ?string $from, ?string $to, ?string $detail = null): void
{
    $pdo->prepare(
        'INSERT INTO user_admin_log (actor_id, target_user_id, action, from_role, to_role, detail) VALUES (?, ?, ?, ?, ?, ?)'
    )->execute([$actor, $target, $action, $from, $to, $detail]);
}

function role_id(PDO $pdo, string $name): int
{
    $st = $pdo->prepare('SELECT role_id FROM role WHERE name = ?');
    $st->execute([$name]);
    $id = $st->fetchColumn();
    if ($id === false) {
        throw new RuntimeException('Unknown role.');
    }
    return (int)$id;
}

function other_active_admins(PDO $pdo, int $excludeUserId): int
{
    $st = $pdo->prepare(
        "SELECT COUNT(*) FROM app_user u JOIN role r ON r.role_id = u.role_id
          WHERE r.name = 'administrator' AND u.is_active = 1 AND u.user_id <> ?"
    );
    $st->execute([$excludeUserId]);
    return (int)$st->fetchColumn();
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    csrf_check();
    $act = (string)($_POST['act'] ?? '');
    try {
        $pdo->beginTransaction();

        if ($act === 'create') {
            $email = strtolower(trim((string)($_POST['email'] ?? '')));
            $name  = trim((string)($_POST['display_name'] ?? ''));
            $role  = (string)($_POST['role'] ?? '');
            $pass  = (string)($_POST['password'] ?? '');
            if (!filter_var($email, FILTER_VALIDATE_EMAIL) || mb_strlen($email) > 255) {
                throw new RuntimeException('Enter a valid email address.');
            }
            if ($name === '' || mb_strlen($name) > 100) {
                throw new RuntimeException('Enter a display name (up to 100 characters).');
            }
            if (!in_array($role, ROLE_NAMES, true)) {
                throw new RuntimeException('Choose a role.');
            }
            if (mb_strlen($pass) < MIN_PASSWORD) {
                throw new RuntimeException('The starting password must be at least ' . MIN_PASSWORD . ' characters.');
            }
            $pdo->prepare('INSERT INTO app_user (email, display_name, role_id, password_hash) VALUES (?, ?, ?, ?)')
                ->execute([$email, $name, role_id($pdo, $role), password_hash($pass, PASSWORD_DEFAULT)]);
            log_user_action($pdo, (int)$me['user_id'], (int)$pdo->lastInsertId(), 'created', null, $role);
            flash('ok', 'Account created for ' . $email . '. Give them the starting password privately.');

        } elseif ($act === 'update') {
            $uid = (int)($_POST['uid'] ?? 0);
            $st = $pdo->prepare('SELECT u.user_id, u.is_active, r.name AS role FROM app_user u JOIN role r ON r.role_id = u.role_id WHERE u.user_id = ? FOR UPDATE');
            $st->execute([$uid]);
            $t = $st->fetch();
            if (!$t) {
                throw new RuntimeException('That user does not exist.');
            }
            $newRole   = (string)($_POST['role'] ?? $t['role']);
            $newActive = isset($_POST['is_active']) ? 1 : 0;
            $newPass   = (string)($_POST['password'] ?? '');
            if (!in_array($newRole, ROLE_NAMES, true)) {
                throw new RuntimeException('Choose a valid role.');
            }
            $isSelf = $uid === (int)$me['user_id'];
            if ($isSelf && ($newRole !== $t['role'] || $newActive !== (int)$t['is_active'])) {
                throw new RuntimeException('You cannot change your own role or deactivate yourself. Ask another administrator.');
            }
            $losingAdmin = $t['role'] === 'administrator' && (int)$t['is_active'] === 1
                && ($newRole !== 'administrator' || $newActive === 0);
            if ($losingAdmin && other_active_admins($pdo, $uid) < 1) {
                throw new RuntimeException('There must always be at least one active administrator.');
            }
            if ($newPass !== '' && mb_strlen($newPass) < MIN_PASSWORD) {
                throw new RuntimeException('A new password must be at least ' . MIN_PASSWORD . ' characters.');
            }

            if ($newRole !== $t['role']) {
                $pdo->prepare('UPDATE app_user SET role_id = ? WHERE user_id = ?')->execute([role_id($pdo, $newRole), $uid]);
                log_user_action($pdo, (int)$me['user_id'], $uid, 'role_changed', $t['role'], $newRole);
            }
            if ($newActive !== (int)$t['is_active']) {
                $pdo->prepare('UPDATE app_user SET is_active = ? WHERE user_id = ?')->execute([$newActive, $uid]);
                log_user_action($pdo, (int)$me['user_id'], $uid, $newActive ? 'activated' : 'deactivated', $t['role'], $newRole);
            }
            if ($newPass !== '') {
                $pdo->prepare('UPDATE app_user SET password_hash = ? WHERE user_id = ?')
                    ->execute([password_hash($newPass, PASSWORD_DEFAULT), $uid]);
                log_user_action($pdo, (int)$me['user_id'], $uid, 'password_reset', null, null);
            }
            flash('ok', 'User updated.');
        } else {
            throw new RuntimeException('Unknown action.');
        }
        $pdo->commit();
    } catch (Throwable $t) {
        if ($pdo->inTransaction()) { $pdo->rollBack(); }
        if ($t instanceof PDOException && ($t->errorInfo[1] ?? 0) === 1062) {
            flash('error', 'An account with that email already exists.');
        } else {
            flash('error', friendly_db_error($t));
        }
    }
    redirect('users.php');
}

$users = $pdo->query(
    'SELECT u.user_id, u.email, u.display_name, u.is_active, (u.password_hash IS NOT NULL) AS has_password, r.name AS role
       FROM app_user u JOIN role r ON r.role_id = u.role_id ORDER BY u.display_name'
)->fetchAll();
$log = $pdo->query(
    'SELECT l.occurred_at, l.action, l.from_role, l.to_role, a.display_name AS actor, t.display_name AS target
       FROM user_admin_log l
       JOIN app_user a ON a.user_id = l.actor_id
       JOIN app_user t ON t.user_id = l.target_user_id
      ORDER BY l.log_id DESC LIMIT 25'
)->fetchAll();

page_header('Users', $me);
?>
<h1>Users and roles</h1>
<p class="muted">Viewers can read published content. Editors can write, submit and archive content. Administrators can also approve, publish, and manage users.</p>

<section class="card">
    <h2>Accounts</h2>
    <div class="table-scroll">
    <table class="grid">
        <thead><tr><th>Name and email</th><th>Role</th><th>Active</th><th>New password (optional)</th><th></th></tr></thead>
        <tbody>
        <?php foreach ($users as $u): $self = (int)$u['user_id'] === (int)$me['user_id']; $fid = 'f' . (int)$u['user_id']; ?>
            <tr>
                <td>
                    <form id="<?= e($fid) ?>" method="post" action="users.php">
                        <?= csrf_field() ?>
                        <input type="hidden" name="act" value="update">
                        <input type="hidden" name="uid" value="<?= (int)$u['user_id'] ?>">
                        <?php if ($self): ?>
                            <input type="hidden" name="role" value="<?= e($u['role']) ?>">
                            <input type="hidden" name="is_active" value="1">
                        <?php endif; ?>
                    </form>
                    <?= e($u['display_name']) ?><?= $self ? ' <span class="muted">(you)</span>' : '' ?><br>
                    <span class="muted"><?= e($u['email']) ?></span>
                    <?= $u['has_password'] ? '' : '<br><span class="muted">No password set yet</span>' ?>
                </td>
                <td>
                    <select name="role" form="<?= e($fid) ?>" <?= $self ? 'disabled' : '' ?> aria-label="Role for <?= e($u['display_name']) ?>">
                        <?php foreach (ROLE_NAMES as $rn): ?>
                            <option value="<?= e($rn) ?>" <?= $rn === $u['role'] ? 'selected' : '' ?>><?= e(ucfirst($rn)) ?></option>
                        <?php endforeach; ?>
                    </select>
                </td>
                <td>
                    <input type="checkbox" name="is_active" value="1" form="<?= e($fid) ?>" <?= $u['is_active'] ? 'checked' : '' ?> <?= $self ? 'disabled' : '' ?> aria-label="Active">
                </td>
                <td><input type="password" name="password" form="<?= e($fid) ?>" autocomplete="new-password" placeholder="Leave blank to keep"></td>
                <td><button type="submit" form="<?= e($fid) ?>" class="btn btn-small">Save</button></td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
    </div>
    <p class="muted">To remove someone's editing access, change their role to Viewer (read-only) or untick Active to block sign-in completely.</p>
</section>

<section class="card">
    <h2>Add a user</h2>
    <form method="post" action="users.php" class="stack">
        <?= csrf_field() ?>
        <input type="hidden" name="act" value="create">
        <label>Display name <input type="text" name="display_name" maxlength="100" required></label>
        <label>Email <input type="email" name="email" maxlength="255" required></label>
        <label>Role
            <select name="role">
                <option value="viewer">Viewer</option>
                <option value="editor" selected>Editor</option>
                <option value="administrator">Administrator</option>
            </select>
        </label>
        <label>Starting password (at least <?= MIN_PASSWORD ?> characters)
            <input type="password" name="password" minlength="<?= MIN_PASSWORD ?>" autocomplete="new-password" required>
        </label>
        <button type="submit" class="btn">Create account</button>
    </form>
</section>

<section class="card">
    <h2>Recent account changes</h2>
    <div class="table-scroll"><table class="grid">
        <thead><tr><th>When</th><th>Changed by</th><th>Account</th><th>What</th></tr></thead>
        <tbody>
        <?php foreach ($log as $l): ?>
            <tr>
                <td><?= e($l['occurred_at']) ?></td>
                <td><?= e($l['actor']) ?></td>
                <td><?= e($l['target']) ?></td>
                <td><?= e(str_replace('_', ' ', $l['action'])) ?><?= $l['action'] === 'role_changed' ? ': ' . e($l['from_role'] . ' → ' . $l['to_role']) : '' ?></td>
            </tr>
        <?php endforeach; ?>
        <?php if (!$log): ?><tr><td colspan="4" class="muted">No changes recorded yet.</td></tr><?php endif; ?>
        </tbody>
    </table></div>
</section>
<?php page_footer();
