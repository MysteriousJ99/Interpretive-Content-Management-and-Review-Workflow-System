-- TEST DATA for development only. Never run this on the production database.
-- Generated together with visitor/mock/published_content.json (same tokens and text).
--
-- Needs schema v3 (French). Load with, from the repo root:
--   C:\xampp\mysql\bin\mysql.exe -u root --default-character-set=utf8mb4 < db\dev_test_data.sql
-- Safe to run more than once.
--
-- What it creates (all names start with [TEST]):
--   * [TEST] Building A: all 12 rows published (en/es/fr x college/simplified x 2 sections)
--   * [TEST] Building B: published, except es/simplified, which is ARCHIVED
--       -> the API must not offer es/simplified for B (404 with the "available" list)
--   * [TEST] Building C (never public): drafts, one approved-but-unpublished, one archived
--       -> the API must act as if C does not exist (404, not in the list)
-- Rows go through the real workflow (draft -> in_review -> approved by an administrator
-- -> published) so the triggers are exercised and every step is in audit_event.
-- Test rows cannot be deleted later (by design). Archive them in the admin app instead.

USE interpretive_cms;
SET NAMES utf8mb4;

-- 0. A dev administrator to own the test rows, only if the database has no administrator yet.
--    It has no password, so nobody can sign in with it.
INSERT INTO app_user (email, display_name, role_id, password_hash)
SELECT 'dev-admin@example.invalid', 'Dev Admin (test data)', r.role_id, NULL
FROM role r
WHERE r.name = 'administrator'
  AND NOT EXISTS (SELECT 1 FROM app_user u JOIN role r2 ON r2.role_id = u.role_id WHERE r2.name = 'administrator');

SET @admin := (SELECT u.user_id FROM app_user u JOIN role r ON r.role_id = u.role_id
               WHERE r.name = 'administrator' ORDER BY u.user_id LIMIT 1);

-- 1. Buildings and fixed QR tokens (fixed so the mock data and real data match)
INSERT INTO location (name, created_by)
SELECT v.name, @admin FROM (
  SELECT '[TEST] Building A' AS name UNION ALL SELECT '[TEST] Building B' UNION ALL SELECT '[TEST] Building C (never public)'
) v
WHERE NOT EXISTS (SELECT 1 FROM location l WHERE l.name = v.name);

INSERT IGNORE INTO location_code (location_id, token)
SELECT l.location_id, v.token FROM location l JOIN (
  SELECT '[TEST] Building A' AS name, '6f1d2c3b-4a5e-4f60-8a7b-0c1d2e3f4a01' AS token
  UNION ALL SELECT '[TEST] Building B', '6f1d2c3b-4a5e-4f60-8a7b-0c1d2e3f4a02'
  UNION ALL SELECT '[TEST] Building C (never public)', '6f1d2c3b-4a5e-4f60-8a7b-0c1d2e3f4a03'
) v ON v.name = l.name;

-- 2. Content: 3 buildings x 2 sections x 3 languages x 2 reading levels = 36 rows, all draft
CREATE TEMPORARY TABLE tmp_test_content (
  loc VARCHAR(150), sec VARCHAR(40), lang VARCHAR(10), lvl VARCHAR(20),
  heading VARCHAR(200), body MEDIUMTEXT
) DEFAULT CHARSET = utf8mb4 COLLATE utf8mb4_unicode_ci;

INSERT INTO tmp_test_content (loc, sec, lang, lvl, heading, body) VALUES
  ('[TEST] Building A', 'building_history', 'en', 'college', 'History of the building', '[TEST DATA] Placeholder college-level text about the history of the building for [TEST] Building A.

Second paragraph. Replace all test data with the Client''s approved text before the demo.'),
  ('[TEST] Building A', 'building_history', 'en', 'simplified', 'History of the building', '[TEST DATA] Placeholder simplified text about the history of the building for [TEST] Building A.

Second paragraph. Replace all test data with the Client''s approved text before the demo.'),
  ('[TEST] Building A', 'building_history', 'es', 'college', 'Historia del edificio', '[DATOS DE PRUEBA] Texto de nivel universitario de ejemplo sobre la historia del edificio de [TEST] Building A.

Segundo párrafo. Reemplace los datos de prueba con el texto aprobado por el cliente antes de la demostración.'),
  ('[TEST] Building A', 'building_history', 'es', 'simplified', 'Historia del edificio', '[DATOS DE PRUEBA] Texto simplificado de ejemplo sobre la historia del edificio de [TEST] Building A.

Segundo párrafo. Reemplace los datos de prueba con el texto aprobado por el cliente antes de la demostración.'),
  ('[TEST] Building A', 'building_history', 'fr', 'college', 'Histoire du bâtiment', '[DONNÉES DE TEST] Texte de niveau universitaire d''exemple sur l''histoire du bâtiment de [TEST] Building A.

Deuxième paragraphe. Remplacez les données de test par le texte approuvé par le client avant la démonstration.'),
  ('[TEST] Building A', 'building_history', 'fr', 'simplified', 'Histoire du bâtiment', '[DONNÉES DE TEST] Texte simplifié d''exemple sur l''histoire du bâtiment de [TEST] Building A.

Deuxième paragraphe. Remplacez les données de test par le texte approuvé par le client avant la démonstration.'),
  ('[TEST] Building A', 'name_history', 'en', 'college', 'History of the name', '[TEST DATA] Placeholder college-level text about the history of its name for [TEST] Building A.

Second paragraph. Replace all test data with the Client''s approved text before the demo.'),
  ('[TEST] Building A', 'name_history', 'en', 'simplified', 'History of the name', '[TEST DATA] Placeholder simplified text about the history of its name for [TEST] Building A.

Second paragraph. Replace all test data with the Client''s approved text before the demo.'),
  ('[TEST] Building A', 'name_history', 'es', 'college', 'Historia del nombre', '[DATOS DE PRUEBA] Texto de nivel universitario de ejemplo sobre la historia de su nombre de [TEST] Building A.

Segundo párrafo. Reemplace los datos de prueba con el texto aprobado por el cliente antes de la demostración.'),
  ('[TEST] Building A', 'name_history', 'es', 'simplified', 'Historia del nombre', '[DATOS DE PRUEBA] Texto simplificado de ejemplo sobre la historia de su nombre de [TEST] Building A.

Segundo párrafo. Reemplace los datos de prueba con el texto aprobado por el cliente antes de la demostración.'),
  ('[TEST] Building A', 'name_history', 'fr', 'college', 'Histoire du nom', '[DONNÉES DE TEST] Texte de niveau universitaire d''exemple sur l''histoire de son nom de [TEST] Building A.

Deuxième paragraphe. Remplacez les données de test par le texte approuvé par le client avant la démonstration.'),
  ('[TEST] Building A', 'name_history', 'fr', 'simplified', 'Histoire du nom', '[DONNÉES DE TEST] Texte simplifié d''exemple sur l''histoire de son nom de [TEST] Building A.

Deuxième paragraphe. Remplacez les données de test par le texte approuvé par le client avant la démonstration.'),
  ('[TEST] Building B', 'building_history', 'en', 'college', 'History of the building', '[TEST DATA] Placeholder college-level text about the history of the building for [TEST] Building B.

Second paragraph. Replace all test data with the Client''s approved text before the demo.'),
  ('[TEST] Building B', 'building_history', 'en', 'simplified', 'History of the building', '[TEST DATA] Placeholder simplified text about the history of the building for [TEST] Building B.

Second paragraph. Replace all test data with the Client''s approved text before the demo.'),
  ('[TEST] Building B', 'building_history', 'es', 'college', 'Historia del edificio', '[DATOS DE PRUEBA] Texto de nivel universitario de ejemplo sobre la historia del edificio de [TEST] Building B.

Segundo párrafo. Reemplace los datos de prueba con el texto aprobado por el cliente antes de la demostración.'),
  ('[TEST] Building B', 'building_history', 'es', 'simplified', 'Historia del edificio', '[DATOS DE PRUEBA] Texto simplificado de ejemplo sobre la historia del edificio de [TEST] Building B.

Segundo párrafo. Reemplace los datos de prueba con el texto aprobado por el cliente antes de la demostración.'),
  ('[TEST] Building B', 'building_history', 'fr', 'college', 'Histoire du bâtiment', '[DONNÉES DE TEST] Texte de niveau universitaire d''exemple sur l''histoire du bâtiment de [TEST] Building B.

Deuxième paragraphe. Remplacez les données de test par le texte approuvé par le client avant la démonstration.'),
  ('[TEST] Building B', 'building_history', 'fr', 'simplified', 'Histoire du bâtiment', '[DONNÉES DE TEST] Texte simplifié d''exemple sur l''histoire du bâtiment de [TEST] Building B.

Deuxième paragraphe. Remplacez les données de test par le texte approuvé par le client avant la démonstration.'),
  ('[TEST] Building B', 'name_history', 'en', 'college', 'History of the name', '[TEST DATA] Placeholder college-level text about the history of its name for [TEST] Building B.

Second paragraph. Replace all test data with the Client''s approved text before the demo.'),
  ('[TEST] Building B', 'name_history', 'en', 'simplified', 'History of the name', '[TEST DATA] Placeholder simplified text about the history of its name for [TEST] Building B.

Second paragraph. Replace all test data with the Client''s approved text before the demo.'),
  ('[TEST] Building B', 'name_history', 'es', 'college', 'Historia del nombre', '[DATOS DE PRUEBA] Texto de nivel universitario de ejemplo sobre la historia de su nombre de [TEST] Building B.

Segundo párrafo. Reemplace los datos de prueba con el texto aprobado por el cliente antes de la demostración.'),
  ('[TEST] Building B', 'name_history', 'es', 'simplified', 'Historia del nombre', '[DATOS DE PRUEBA] Texto simplificado de ejemplo sobre la historia de su nombre de [TEST] Building B.

Segundo párrafo. Reemplace los datos de prueba con el texto aprobado por el cliente antes de la demostración.'),
  ('[TEST] Building B', 'name_history', 'fr', 'college', 'Histoire du nom', '[DONNÉES DE TEST] Texte de niveau universitaire d''exemple sur l''histoire de son nom de [TEST] Building B.

Deuxième paragraphe. Remplacez les données de test par le texte approuvé par le client avant la démonstration.'),
  ('[TEST] Building B', 'name_history', 'fr', 'simplified', 'Histoire du nom', '[DONNÉES DE TEST] Texte simplifié d''exemple sur l''histoire de son nom de [TEST] Building B.

Deuxième paragraphe. Remplacez les données de test par le texte approuvé par le client avant la démonstration.'),
  ('[TEST] Building C (never public)', 'building_history', 'en', 'college', 'History of the building', '[TEST DATA] Placeholder college-level text about the history of the building for [TEST] Building C (never public).

Second paragraph. Replace all test data with the Client''s approved text before the demo.'),
  ('[TEST] Building C (never public)', 'building_history', 'en', 'simplified', 'History of the building', '[TEST DATA] Placeholder simplified text about the history of the building for [TEST] Building C (never public).

Second paragraph. Replace all test data with the Client''s approved text before the demo.'),
  ('[TEST] Building C (never public)', 'building_history', 'es', 'college', 'Historia del edificio', '[DATOS DE PRUEBA] Texto de nivel universitario de ejemplo sobre la historia del edificio de [TEST] Building C (never public).

Segundo párrafo. Reemplace los datos de prueba con el texto aprobado por el cliente antes de la demostración.'),
  ('[TEST] Building C (never public)', 'building_history', 'es', 'simplified', 'Historia del edificio', '[DATOS DE PRUEBA] Texto simplificado de ejemplo sobre la historia del edificio de [TEST] Building C (never public).

Segundo párrafo. Reemplace los datos de prueba con el texto aprobado por el cliente antes de la demostración.'),
  ('[TEST] Building C (never public)', 'building_history', 'fr', 'college', 'Histoire du bâtiment', '[DONNÉES DE TEST] Texte de niveau universitaire d''exemple sur l''histoire du bâtiment de [TEST] Building C (never public).

Deuxième paragraphe. Remplacez les données de test par le texte approuvé par le client avant la démonstration.'),
  ('[TEST] Building C (never public)', 'building_history', 'fr', 'simplified', 'Histoire du bâtiment', '[DONNÉES DE TEST] Texte simplifié d''exemple sur l''histoire du bâtiment de [TEST] Building C (never public).

Deuxième paragraphe. Remplacez les données de test par le texte approuvé par le client avant la démonstration.'),
  ('[TEST] Building C (never public)', 'name_history', 'en', 'college', 'History of the name', '[TEST DATA] Placeholder college-level text about the history of its name for [TEST] Building C (never public).

Second paragraph. Replace all test data with the Client''s approved text before the demo.'),
  ('[TEST] Building C (never public)', 'name_history', 'en', 'simplified', 'History of the name', '[TEST DATA] Placeholder simplified text about the history of its name for [TEST] Building C (never public).

Second paragraph. Replace all test data with the Client''s approved text before the demo.'),
  ('[TEST] Building C (never public)', 'name_history', 'es', 'college', 'Historia del nombre', '[DATOS DE PRUEBA] Texto de nivel universitario de ejemplo sobre la historia de su nombre de [TEST] Building C (never public).

Segundo párrafo. Reemplace los datos de prueba con el texto aprobado por el cliente antes de la demostración.'),
  ('[TEST] Building C (never public)', 'name_history', 'es', 'simplified', 'Historia del nombre', '[DATOS DE PRUEBA] Texto simplificado de ejemplo sobre la historia de su nombre de [TEST] Building C (never public).

Segundo párrafo. Reemplace los datos de prueba con el texto aprobado por el cliente antes de la demostración.'),
  ('[TEST] Building C (never public)', 'name_history', 'fr', 'college', 'Histoire du nom', '[DONNÉES DE TEST] Texte de niveau universitaire d''exemple sur l''histoire de son nom de [TEST] Building C (never public).

Deuxième paragraphe. Remplacez les données de test par le texte approuvé par le client avant la démonstration.'),
  ('[TEST] Building C (never public)', 'name_history', 'fr', 'simplified', 'Histoire du nom', '[DONNÉES DE TEST] Texte simplifié d''exemple sur l''histoire de son nom de [TEST] Building C (never public).

Deuxième paragraphe. Remplacez les données de test par le texte approuvé par le client avant la démonstration.');

INSERT IGNORE INTO location_content
  (location_id, section_type_id, language_id, audience_id, heading, body, author_id)
SELECT l.location_id, s.section_type_id, g.language_id, a.audience_id, t.heading, t.body, @admin
FROM tmp_test_content t
JOIN location       l ON l.name = t.loc
JOIN section_type   s ON s.code = t.sec
JOIN language       g ON g.code = t.lang
JOIN audience_level a ON a.code = t.lvl;

DROP TEMPORARY TABLE tmp_test_content;

-- Helper set: the test rows only
CREATE TEMPORARY TABLE tmp_ids (content_id INT UNSIGNED PRIMARY KEY, loc VARCHAR(150), lang VARCHAR(10), lvl VARCHAR(20), sec VARCHAR(40));
INSERT INTO tmp_ids
SELECT c.content_id, l.name, g.code, a.code, s.code
FROM location_content c
JOIN location l ON l.location_id = c.location_id
JOIN language g ON g.language_id = c.language_id
JOIN audience_level a ON a.audience_id = c.audience_id
JOIN section_type s ON s.section_type_id = c.section_type_id
WHERE l.name IN ('[TEST] Building A', '[TEST] Building B', '[TEST] Building C (never public)');

INSERT INTO audit_event (content_id, actor_id, action, to_status, detail)
SELECT t.content_id, @admin, 'created', 'draft', 'Test data load'
FROM tmp_ids t
WHERE NOT EXISTS (SELECT 1 FROM audit_event e WHERE e.content_id = t.content_id AND e.action = 'created');

-- 3. Buildings A and B (and one row of C): draft -> in_review -> approved
UPDATE location_content c JOIN tmp_ids t ON t.content_id = c.content_id
   SET c.status = 'in_review'
 WHERE c.status = 'draft'
   AND (t.loc IN ('[TEST] Building A', '[TEST] Building B')
        OR (t.loc = '[TEST] Building C (never public)' AND t.lang = 'en' AND t.lvl = 'college' AND t.sec = 'building_history'));

INSERT INTO audit_event (content_id, actor_id, action, from_status, to_status, detail)
SELECT t.content_id, @admin, 'submitted', 'draft', 'in_review', 'Test data load'
FROM tmp_ids t JOIN location_content c ON c.content_id = t.content_id
WHERE c.status IN ('in_review', 'approved', 'published', 'archived')
  AND (t.loc IN ('[TEST] Building A', '[TEST] Building B') OR (t.lang = 'en' AND t.lvl = 'college' AND t.sec = 'building_history'))
  AND NOT EXISTS (SELECT 1 FROM audit_event e WHERE e.content_id = t.content_id AND e.action = 'submitted');

UPDATE location_content c JOIN tmp_ids t ON t.content_id = c.content_id
   SET c.status = 'approved', c.approved_by = @admin
 WHERE c.status = 'in_review';

INSERT INTO audit_event (content_id, actor_id, action, from_status, to_status, detail)
SELECT t.content_id, @admin, 'approved', 'in_review', 'approved', 'Test data load'
FROM tmp_ids t JOIN location_content c ON c.content_id = t.content_id
WHERE c.status IN ('approved', 'published', 'archived')
  AND (t.loc IN ('[TEST] Building A', '[TEST] Building B') OR (t.lang = 'en' AND t.lvl = 'college' AND t.sec = 'building_history'))
  AND NOT EXISTS (SELECT 1 FROM audit_event e WHERE e.content_id = t.content_id AND e.action = 'approved');

-- 4. Publish A and B only (C's approved row stays approved-but-unpublished)
UPDATE location_content c JOIN tmp_ids t ON t.content_id = c.content_id
   SET c.status = 'published'
 WHERE c.status = 'approved' AND t.loc IN ('[TEST] Building A', '[TEST] Building B');

INSERT INTO audit_event (content_id, actor_id, action, from_status, to_status, detail)
SELECT t.content_id, @admin, 'published', 'approved', 'published', 'Test data load'
FROM tmp_ids t JOIN location_content c ON c.content_id = t.content_id
WHERE c.status IN ('published', 'archived') AND t.loc IN ('[TEST] Building A', '[TEST] Building B')
  AND NOT EXISTS (SELECT 1 FROM audit_event e WHERE e.content_id = t.content_id AND e.action = 'published');

-- 5. Archive: B's es/simplified rows, and one of C's drafts
UPDATE location_content c JOIN tmp_ids t ON t.content_id = c.content_id
   SET c.status = 'archived'
 WHERE (t.loc = '[TEST] Building B' AND t.lang = 'es' AND t.lvl = 'simplified' AND c.status = 'published')
    OR (t.loc = '[TEST] Building C (never public)' AND t.lang = 'fr' AND t.lvl = 'simplified' AND t.sec = 'name_history' AND c.status = 'draft');

INSERT INTO audit_event (content_id, actor_id, action, from_status, to_status, detail)
SELECT t.content_id, @admin, 'archived',
       CASE WHEN t.loc = '[TEST] Building B' THEN 'published' ELSE 'draft' END, 'archived', 'Test data load'
FROM tmp_ids t JOIN location_content c ON c.content_id = t.content_id
WHERE c.status = 'archived'
  AND NOT EXISTS (SELECT 1 FROM audit_event e WHERE e.content_id = t.content_id AND e.action = 'archived');

DROP TEMPORARY TABLE tmp_ids;

-- 6. Checks
--   Expected: A published 12; B published 10, archived 2; C draft 10, approved 1, archived 1
SELECT l.name, c.status, COUNT(*) AS n
FROM location_content c JOIN location l ON l.location_id = c.location_id
WHERE l.name IN ('[TEST] Building A', '[TEST] Building B', '[TEST] Building C (never public)')
GROUP BY l.name, c.status ORDER BY l.name, c.status;
--   Expected: 22 public test rows
SELECT COUNT(*) AS public_test_rows FROM v_published_content WHERE location_name IN ('[TEST] Building A', '[TEST] Building B', '[TEST] Building C (never public)');
