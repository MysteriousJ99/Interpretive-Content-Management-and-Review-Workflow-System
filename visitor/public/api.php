<?php
declare(strict_types=1);

// Front controller for /api/v1/... (see docs/api.md).
// Built-in PHP server: visitor/router.php sends /api/* here.
// Apache: visitor/public/.htaccess rewrites /api/* here.

require __DIR__ . '/../src/public_api.php';

$configFile = __DIR__ . '/../config.php';
$config = is_file($configFile) ? require $configFile : null;

handle_api_request(
    $_SERVER['REQUEST_METHOD'] ?? 'GET',
    parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/',
    $_GET,
    is_array($config) ? $config : null
);
