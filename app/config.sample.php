<?php
// Copy this file to config.php and fill in the values.
// config.php holds a database password and is git-ignored. Never commit it.
return [
    'app_name' => 'Interpretive Content Manager',
    'db' => [
        'host' => '127.0.0.1',
        'port' => 3306,
        'name' => 'interpretive_cms',
        'user' => 'cms_admin_app',      // the limited staff-app account, NOT root
        'pass' => 'ChangeMe_admin1',
    ],
];
