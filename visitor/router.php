<?php
// Router for PHP's built-in web server (development and demos only).
// Run from the repo root:
//   C:\xampp\php\php.exe -S localhost:8081 -t visitor\public visitor\router.php
//
//   /api/...        -> the public JSON API (visitor/public/api.php)
//   /v/<token>      -> redirect to guided_viewing.html?token=<token>  (the URL in each QR code)
//   anything else   -> static files from visitor/public (Will's pages)

$path = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/';

if (preg_match('#^/api(/|$)#', $path)) {
    require __DIR__ . '/public/api.php';
    return true;
}

if (preg_match('#^/v/([0-9A-Fa-f-]{36})/?$#', $path, $m)) {
    header('Location: /guided_viewing.html?token=' . strtolower($m[1]), true, 302);
    return true;
}

// Never serve dotfiles (.htaccess etc.).
if (preg_match('#/\.#', $path)) {
    http_response_code(404);
    return true;
}

return false; // let the built-in server serve the static file
