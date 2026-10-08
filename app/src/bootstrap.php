<?php
declare(strict_types=1);

// Shared setup for every page: config, session, database, security helpers.

$configFile = __DIR__ . '/../config.php';
if (!is_file($configFile)) {
    http_response_code(500);
    exit('Missing app/config.php. Copy app/config.sample.php to app/config.php and fill it in.');
}
$CONFIG = require $configFile;

header('X-Frame-Options: DENY');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: same-origin');
header("Content-Security-Policy: default-src 'self'; form-action 'self'; frame-ancestors 'none'");

session_set_cookie_params([
    'lifetime' => 0,
    'path'     => '/',
    'httponly' => true,
    'samesite' => 'Lax',
    'secure'   => !empty($_SERVER['HTTPS']),
]);
session_name('icms_session');
session_start();

function db(): PDO
{
    static $pdo = null;
    global $CONFIG;
    if ($pdo === null) {
        $c = $CONFIG['db'];
        $dsn = "mysql:host={$c['host']};port={$c['port']};dbname={$c['name']};charset=utf8mb4";
        $pdo = new PDO($dsn, $c['user'], $c['pass'], [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]);
    }
    return $pdo;
}

function e($value): string
{
    return htmlspecialchars((string)$value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function redirect(string $to): never
{
    header('Location: ' . $to);
    exit;
}

function flash(string $type, string $message): void
{
    $_SESSION['flash'][] = [$type, $message];
}

// ---- CSRF protection for every POST form -------------------------------------
function csrf_token(): string
{
    if (empty($_SESSION['csrf'])) {
        $_SESSION['csrf'] = bin2hex(random_bytes(32));
    }
    return $_SESSION['csrf'];
}

function csrf_field(): string
{
    return '<input type="hidden" name="csrf" value="' . e(csrf_token()) . '">';
}

function csrf_check(): void
{
    $sent = $_POST['csrf'] ?? '';
    if (!is_string($sent) || !hash_equals($_SESSION['csrf'] ?? '', $sent)) {
        http_response_code(400);
        exit('Invalid or expired form. Go back, reload the page and try again.');
    }
}

// ---- Authentication and authorization ----------------------------------------
// The user is re-read from the database on every request, so a role change or
// deactivation by an administrator takes effect immediately, not at next login.
function require_login(): array
{
    static $user = null;
    if ($user !== null) {
        return $user;
    }
    $id = $_SESSION['uid'] ?? null;
    if (!$id) {
        redirect('login.php');
    }
    $st = db()->prepare(
        'SELECT u.user_id, u.email, u.display_name, u.is_active, r.name AS role
           FROM app_user u JOIN role r ON r.role_id = u.role_id
          WHERE u.user_id = ?'
    );
    $st->execute([$id]);
    $row = $st->fetch();
    if (!$row || !$row['is_active']) {
        unset($_SESSION['uid']);
        flash('error', 'Your account is not active.');
        redirect('login.php');
    }
    $user = $row;
    return $user;
}

function require_role(string ...$roles): array
{
    $user = require_login();
    if (!in_array($user['role'], $roles, true)) {
        render_error('You do not have permission to open this page.', 403);
    }
    return $user;
}

function is_staff(array $user): bool
{
    return in_array($user['role'], ['editor', 'administrator'], true);
}

function uuid4(): string
{
    $d = random_bytes(16);
    $d[6] = chr((ord($d[6]) & 0x0f) | 0x40);
    $d[8] = chr((ord($d[8]) & 0x3f) | 0x80);
    return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($d), 4));
}

require __DIR__ . '/layout.php';
require __DIR__ . '/workflow.php';
