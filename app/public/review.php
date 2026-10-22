<?php
declare(strict_types=1);
require __DIR__ . '/../src/bootstrap.php';

$user = require_role('administrator');

$items = db()->query(
    "SELECT c.status, c.updated_at, c.location_id, c.section_type_id, c.language_id, c.audience_id,
            l.name AS loc_name, s.label AS sec_label, g.name AS lang_name, a.label AS aud_label,
            u.display_name AS author
       FROM location_content c
       JOIN location l ON l.location_id = c.location_id
       JOIN section_type s ON s.section_type_id = c.section_type_id
       JOIN language g ON g.language_id = c.language_id
       JOIN audience_level a ON a.audience_id = c.audience_id
       JOIN app_user u ON u.user_id = c.author_id
      WHERE c.status IN ('in_review', 'approved')
      ORDER BY FIELD(c.status, 'in_review', 'approved'), c.updated_at"
)->fetchAll();

page_header('Review queue', $user);
echo '<h1>Review queue</h1>';
echo '<p class="muted">Content waiting for your decision. In review: approve it or return it with a comment. Approved: publish it.</p>';

if (!$items) {
    echo '<p>Nothing is waiting for review.</p>';
} else {
    echo '<div class="table-scroll"><table class="grid"><thead><tr><th>Status</th><th>Building</th><th>Section</th><th>Language</th><th>Reading level</th><th>Author</th><th>Updated</th><th></th></tr></thead><tbody>';
    foreach ($items as $i) {
        $url = 'content.php?loc=' . $i['location_id'] . '&sec=' . $i['section_type_id'] . '&lang=' . $i['language_id'] . '&aud=' . $i['audience_id'];
        echo '<tr><td>' . status_badge($i['status']) . '</td><td>' . e($i['loc_name']) . '</td><td>' . e($i['sec_label'])
           . '</td><td>' . e($i['lang_name']) . '</td><td>' . e($i['aud_label']) . '</td><td>' . e($i['author'])
           . '</td><td>' . e($i['updated_at']) . '</td><td><a class="btn btn-small" href="' . e($url) . '">Open</a></td></tr>';
    }
    echo '</tbody></table></div>';
}
page_footer();
