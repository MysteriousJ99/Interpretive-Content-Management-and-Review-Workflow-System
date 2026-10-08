-- Seed content load for interpretive_cms (schema v1)
-- Fill in every <PLACEHOLDER>, then run this whole file once on a freshly loaded database.
--
-- Rules this script follows (the database enforces them):
--   * New content always starts as 'draft'.
--   * Content is supplied by the Client (Patrick Wright); the Team only loads it.
--   * Real approval and publishing should be done through the review workflow
--     (WBS 3.2.3). The optional block at the bottom promotes everything to
--     'published' for TESTING ONLY.
--
-- Text rules:
--   * An apostrophe inside text must be doubled:  Founders'' Hall  (not Founders' Hall)
--   * Save this file as UTF-8 so Spanish accents (a, e, i, o, u, n with marks) load correctly.
--   * Load with:  mysql -u root --default-character-set=utf8mb4 < seed_content.sql

USE interpretive_cms;
SET NAMES utf8mb4;

-- Who is loading: the first administrator account in app_user
SET @admin := (SELECT user_id FROM app_user WHERE role_id = 3 ORDER BY user_id LIMIT 1);

-- 1. The two buildings
INSERT INTO location (name, created_by) VALUES
  ('<BUILDING 1 NAME>', @admin),
  ('<BUILDING 2 NAME>', @admin);

-- 2. One stable QR token per building (never changes after this)
INSERT INTO location_code (location_id, token)
SELECT location_id, UUID() FROM location
WHERE location_id NOT IN (SELECT location_id FROM location_code);

-- 3. The content: 2 buildings x 2 sections x 2 languages x 2 reading levels = 16 rows
--    Codes: section = building_history | name_history
--           lang    = en | es
--           lvl     = college | simplified
INSERT INTO location_content
  (location_id, section_type_id, language_id, audience_id, heading, body, author_id)
SELECT l.location_id, s.section_type_id, g.language_id, a.audience_id,
       v.heading, v.body, @admin
FROM (
  SELECT '<BUILDING 1 NAME>' AS loc, 'building_history' AS sec, 'en' AS lang, 'college' AS lvl,
         'History of the building' AS heading, '<PASTE EN college-level TEXT: building history>' AS body
  UNION ALL SELECT '<BUILDING 1 NAME>', 'building_history', 'en', 'simplified', 'History of the building', '<PASTE EN simplified TEXT: building history>'
  UNION ALL SELECT '<BUILDING 1 NAME>', 'building_history', 'es', 'college', 'Historia del edificio', '<PASTE ES college-level TEXT: building history>'
  UNION ALL SELECT '<BUILDING 1 NAME>', 'building_history', 'es', 'simplified', 'Historia del edificio', '<PASTE ES simplified TEXT: building history>'
  UNION ALL SELECT '<BUILDING 1 NAME>', 'name_history', 'en', 'college', 'History of the name', '<PASTE EN college-level TEXT: name history>'
  UNION ALL SELECT '<BUILDING 1 NAME>', 'name_history', 'en', 'simplified', 'History of the name', '<PASTE EN simplified TEXT: name history>'
  UNION ALL SELECT '<BUILDING 1 NAME>', 'name_history', 'es', 'college', 'Historia del nombre', '<PASTE ES college-level TEXT: name history>'
  UNION ALL SELECT '<BUILDING 1 NAME>', 'name_history', 'es', 'simplified', 'Historia del nombre', '<PASTE ES simplified TEXT: name history>'
  UNION ALL SELECT '<BUILDING 2 NAME>', 'building_history', 'en', 'college', 'History of the building', '<PASTE EN college-level TEXT: building history>'
  UNION ALL SELECT '<BUILDING 2 NAME>', 'building_history', 'en', 'simplified', 'History of the building', '<PASTE EN simplified TEXT: building history>'
  UNION ALL SELECT '<BUILDING 2 NAME>', 'building_history', 'es', 'college', 'Historia del edificio', '<PASTE ES college-level TEXT: building history>'
  UNION ALL SELECT '<BUILDING 2 NAME>', 'building_history', 'es', 'simplified', 'Historia del edificio', '<PASTE ES simplified TEXT: building history>'
  UNION ALL SELECT '<BUILDING 2 NAME>', 'name_history', 'en', 'college', 'History of the name', '<PASTE EN college-level TEXT: name history>'
  UNION ALL SELECT '<BUILDING 2 NAME>', 'name_history', 'en', 'simplified', 'History of the name', '<PASTE EN simplified TEXT: name history>'
  UNION ALL SELECT '<BUILDING 2 NAME>', 'name_history', 'es', 'college', 'Historia del nombre', '<PASTE ES college-level TEXT: name history>'
  UNION ALL SELECT '<BUILDING 2 NAME>', 'name_history', 'es', 'simplified', 'Historia del nombre', '<PASTE ES simplified TEXT: name history>'
) v
JOIN location       l ON l.name = v.loc
JOIN section_type   s ON s.code = v.sec
JOIN language       g ON g.code = v.lang
JOIN audience_level a ON a.code = v.lvl;

-- 4. Record the load in the audit history (so every row has a starting entry)
INSERT INTO audit_event (content_id, actor_id, action, to_status, detail)
SELECT content_id, @admin, 'created', 'draft', 'Seed load'
FROM location_content
WHERE content_id NOT IN (SELECT content_id FROM audit_event);

-- 5. Check: should show 16 rows, all draft
SELECT status, COUNT(*) AS n FROM location_content GROUP BY status;

-- ---------------------------------------------------------------
-- OPTIONAL, FOR TESTING ONLY: push everything through the workflow so the
-- public view has data. Remove the leading "-- " to run. For the real demo,
-- leave content as drafts and approve/publish it through the workflow instead.
-- ---------------------------------------------------------------
-- UPDATE location_content SET status = 'in_review' WHERE status = 'draft';
-- INSERT INTO audit_event (content_id, actor_id, action, from_status, to_status, detail)
--   SELECT content_id, @admin, 'submitted', 'draft', 'in_review', 'Test promotion' FROM location_content WHERE status = 'in_review';
-- UPDATE location_content SET status = 'approved', approved_by = @admin WHERE status = 'in_review';
-- INSERT INTO audit_event (content_id, actor_id, action, from_status, to_status, detail)
--   SELECT content_id, @admin, 'approved', 'in_review', 'approved', 'Test promotion' FROM location_content WHERE status = 'approved';
-- UPDATE location_content SET status = 'published' WHERE status = 'approved';
-- INSERT INTO audit_event (content_id, actor_id, action, from_status, to_status, detail)
--   SELECT content_id, @admin, 'published', 'approved', 'published', 'Test promotion' FROM location_content WHERE status = 'published';
-- SELECT COUNT(*) AS public_rows FROM v_published_content;
