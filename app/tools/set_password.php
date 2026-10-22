<?php
declare(strict_types=1);

// Set (or reset) a user's password from the command line.
// Use this once to give the first administrator a password, since the app needs one to sign in.
//
//   C:\xampp\php\php.exe app\tools\set_password.php someone@example.com
//
// The password you type is visible on screen. Run this only on your own computer.

if (PHP_SAPI !== 'cli') {
    exit('Run this from the command line.');
}
$email = strtolower(trim($argv[1] ?? ''));
if ($email === '') {
    fwrite(STDERR, "Usage: php set_password.php <email>\n");
    exit(1);
}
$configFile = __DIR__ . '/../config.php';
if (!is_file($configFile)) {
    fwrite(STDERR, "Missing app/config.php (copy config.sample.php first).\n");
    exit(1);
}
$c = (require $configFile)['db'];
$pdo = new PDO(
    "mysql:host={$c['host']};port={$c['port']};dbname={$c['name']};charset=utf8mb4",
    $c['user'], $c['pass'],
    [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
);

$st = $pdo->prepare('SELECT user_id, display_name FROM app_user WHERE email = ?');
$st->execute([$email]);
$u = $st->fetch(PDO::FETCH_ASSOC);
if (!$u) {
    fwrite(STDERR, "No user with email $email. Add the row to app_user first.\n");
    exit(1);
}

echo "New password for {$u['display_name']} (at least 10 characters): ";
$pw = trim((string)fgets(STDIN));
if (strlen($pw) < 10) {
    fwrite(STDERR, "Too short. Nothing changed.\n");
    exit(1);
}
$pdo->prepare('UPDATE app_user SET password_hash = ? WHERE user_id = ?')
    ->execute([password_hash($pw, PASSWORD_DEFAULT), $u['user_id']]);
echo "Password set for $email.\n";
