<?php
declare(strict_types=1);

function status_label(string $status): string
{
    return [
        'draft'     => 'Draft',
        'in_review' => 'In review',
        'approved'  => 'Approved',
        'published' => 'Published',
        'archived'  => 'Archived',
    ][$status] ?? $status;
}

function status_badge(string $status): string
{
    return '<span class="badge badge-' . e($status) . '">' . e(status_label($status)) . '</span>';
}

function page_header(string $title, ?array $user = null): void
{
    global $CONFIG;
    echo '<!doctype html><html lang="en"><head><meta charset="utf-8">'
       . '<meta name="viewport" content="width=device-width, initial-scale=1">'
       . '<title>' . e($title) . ' | ' . e($CONFIG['app_name']) . '</title>'
       . '<link rel="stylesheet" href="style.css"></head><body>';

    echo '<header class="topbar"><div class="topbar-inner">';
    echo '<a class="brand" href="index.php">' . e($CONFIG['app_name']) . '</a>';
    if ($user) {
        echo '<nav>';
        echo '<a href="index.php">Dashboard</a>';
        if ($user['role'] === 'administrator') {
            echo '<a href="review.php">Review queue</a>';
            echo '<a href="users.php">Users</a>';
        }
        echo '</nav>';
        echo '<form class="signout" method="post" action="logout.php">' . csrf_field()
           . '<span class="who">' . e($user['display_name']) . ' (' . e($user['role']) . ')</span>'
           . '<button type="submit" class="link-button">Sign out</button></form>';
    }
    echo '</div></header><main class="wrap">';

    foreach ($_SESSION['flash'] ?? [] as [$type, $msg]) {
        echo '<div class="flash flash-' . e($type) . '" role="status">' . e($msg) . '</div>';
    }
    unset($_SESSION['flash']);
}

function page_footer(): void
{
    echo '</main></body></html>';
}

function render_error(string $message, int $code = 400): never
{
    http_response_code($code);
    $user = null;
    if (!empty($_SESSION['uid'])) {
        try {
            $user = require_login();
        } catch (Throwable $t) {
            $user = null;
        }
    }
    page_header('Error', $user);
    echo '<h1>' . ($code === 403 ? 'Not allowed' : ($code === 404 ? 'Not found' : 'Problem')) . '</h1>';
    echo '<p>' . e($message) . '</p><p><a href="index.php">Back to the dashboard</a></p>';
    page_footer();
    exit;
}
