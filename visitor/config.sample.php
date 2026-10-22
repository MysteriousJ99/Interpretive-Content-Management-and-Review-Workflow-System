<?php
// Copy this file to visitor/config.php and fill it in.
// config.php can hold a database password and is git-ignored. Never commit it.
return [
    // 'database' = read published content from MySQL (normal use)
    // 'mock'     = read visitor/mock/published_content.json instead; no MySQL needed
    //              (front-end work only; same tokens and text as db/dev_test_data.sql)
    'mode' => 'database',

    'db' => [
        'host' => '127.0.0.1',
        'port' => 3306,
        'name' => 'interpretive_cms',
        'user' => 'cms_public_api',     // SELECT on v_published_content ONLY. Never root, never cms_admin_app.
        'pass' => 'ChangeMe_public1',
    ],
];
