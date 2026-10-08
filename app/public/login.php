<?php
declare(strict_types=1);
require __DIR__ . '/../src/bootstrap.php';

if (!empty($_SESSION['uid'])) {
    redirect('index.php');
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    csrf_check();
    $email    = strtolower(trim((string)($_POST['email'] ?? '')));
    $password = (string)($_POST['password'] ?? '');

    $st = db()->prepare(
        'SELECT user_id, password_hash, is_active FROM app_user WHERE email = ?'
    );
    $st->execute([$email]);
    $row = $st->fetch();

    // Always run a hash check so unknown emails and wrong passwords take the same time.
    $hash = $row['password_hash'] ?? password_hash('not-a-real-password', PASSWORD_DEFAULT);
    $ok   = $row && $row['password_hash'] !== null && password_verify($password, $hash) && $row['is_active'];

    if ($ok) {
        session_regenerate_id(true);
        $_SESSION['uid'] = (int)$row['user_id'];
        if (password_needs_rehash($hash, PASSWORD_DEFAULT)) {
            db()->prepare('UPDATE app_user SET password_hash = ? WHERE user_id = ?')
                ->execute([password_hash($password, PASSWORD_DEFAULT), $row['user_id']]);
        }
        redirect('index.php');
    }
    usleep(500000); // slow down password guessing
    flash('error', 'Incorrect email or password, or the account is not active.');
    redirect('login.php');
}

page_header('Sign in');
?>
<h1>Sign in</h1>
<form method="post" action="login.php" class="card narrow">
    <?= csrf_field() ?>
    <label>Email
        <input type="email" name="email" required autofocus autocomplete="username">
    </label>
    <label>Password
        <input type="password" name="password" required autocomplete="current-password">
    </label>
    <button type="submit" class="btn">Sign in</button>
</form>
<?php page_footer();
