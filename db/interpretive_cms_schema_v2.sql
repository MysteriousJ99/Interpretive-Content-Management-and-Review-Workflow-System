-- Interpretive Content Management and Review Workflow System
-- Schema v2 (Sprint 2) -- supersedes v1
-- Target: XAMPP MariaDB (MySQL-compatible), InnoDB, utf8mb4
--
-- Decisions captured in this version:
--   * Roles: viewer (read-only), editor (add/update/archive), administrator (approve/publish/manage)
--   * All new content starts as 'draft'; only an administrator can approve it
--   * Audience levels: college-level reading, simplified reading (reduced terminology)
--   * Sections: history of the building, history of the name
--   * Languages: English, Spanish
--   * "Remove" = archive. Archived content stays visible to editors/administrators
--     but is never visible to the public (it is not in v_published_content)
--   * Hard deletes of content are blocked; audit history is append-only
--
-- v2 changes: app_user.password_hash (the PHP app signs users in with PHP's built-in
--             password_hash()/password_verify()) and a new append-only table
--             user_admin_log that records account and role changes.

CREATE DATABASE IF NOT EXISTS interpretive_cms
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE interpretive_cms;

-- ---------------------------------------------------------------
-- Lookup tables
-- ---------------------------------------------------------------
CREATE TABLE language (
  language_id   TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code          VARCHAR(10) NOT NULL UNIQUE,        -- 'en', 'es'
  name          VARCHAR(50) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE audience_level (
  audience_id   TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code          VARCHAR(20) NOT NULL UNIQUE,        -- 'college', 'simplified'
  label         VARCHAR(80) NOT NULL,
  sort_order    TINYINT UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE section_type (
  section_type_id TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code            VARCHAR(40) NOT NULL UNIQUE,      -- 'building_history', 'name_history'
  label           VARCHAR(80) NOT NULL,
  sort_order      TINYINT UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB;

CREATE TABLE role (
  role_id       TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name          ENUM('viewer','editor','administrator') NOT NULL UNIQUE
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- Users (placeholder for framework auth). One role per user.
-- ---------------------------------------------------------------
CREATE TABLE app_user (
  user_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email         VARCHAR(255) NOT NULL UNIQUE,
  display_name  VARCHAR(100) NOT NULL,
  role_id       TINYINT UNSIGNED NOT NULL,
  password_hash VARCHAR(255) NULL,                  -- NULL = cannot sign in until a password is set
  is_active     TINYINT(1) NOT NULL DEFAULT 1,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (role_id) REFERENCES role(role_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- Locations (buildings) and their stable QR tokens
-- ---------------------------------------------------------------
CREATE TABLE location (
  location_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(150) NOT NULL,
  created_by    INT UNSIGNED NOT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (created_by) REFERENCES app_user(user_id)
) ENGINE=InnoDB;

CREATE TABLE location_code (
  location_id   INT UNSIGNED PRIMARY KEY,
  token         CHAR(36) NOT NULL UNIQUE,           -- UUID encoded in the QR code
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (location_id) REFERENCES location(location_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- Content: one row per building x section x language x audience level
-- 2 buildings x 2 sections x 2 languages x 2 audiences = 16 rows
-- ---------------------------------------------------------------
CREATE TABLE location_content (
  content_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  location_id     INT UNSIGNED     NOT NULL,
  section_type_id TINYINT UNSIGNED NOT NULL,
  language_id     TINYINT UNSIGNED NOT NULL,
  audience_id     TINYINT UNSIGNED NOT NULL,
  heading         VARCHAR(200) NOT NULL,            -- translated section heading
  body            MEDIUMTEXT   NOT NULL,
  status          ENUM('draft','in_review','approved','published','archived')
                  NOT NULL DEFAULT 'draft',
  author_id       INT UNSIGNED NOT NULL,
  approved_by     INT UNSIGNED NULL,
  approved_at     DATETIME NULL,
  published_at    DATETIME NULL,
  archived_at     DATETIME NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_content (location_id, section_type_id, language_id, audience_id),
  FOREIGN KEY (location_id)     REFERENCES location(location_id),
  FOREIGN KEY (section_type_id) REFERENCES section_type(section_type_id),
  FOREIGN KEY (language_id)     REFERENCES language(language_id),
  FOREIGN KEY (audience_id)     REFERENCES audience_level(audience_id),
  FOREIGN KEY (author_id)       REFERENCES app_user(user_id),
  FOREIGN KEY (approved_by)     REFERENCES app_user(user_id)
) ENGINE=InnoDB;

CREATE TABLE review_comment (
  comment_id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  content_id    INT UNSIGNED NOT NULL,
  reviewer_id   INT UNSIGNED NOT NULL,
  decision      ENUM('comment','return_for_revision','approve') NOT NULL,
  comment_text  TEXT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (content_id)  REFERENCES location_content(content_id),
  FOREIGN KEY (reviewer_id) REFERENCES app_user(user_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- Append-only audit history
-- ---------------------------------------------------------------
CREATE TABLE audit_event (
  event_id      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  content_id    INT UNSIGNED NOT NULL,
  actor_id      INT UNSIGNED NOT NULL,
  action        ENUM('created','edited','submitted','returned','approved',
                     'published','archived','restored') NOT NULL,
  from_status   ENUM('draft','in_review','approved','published','archived') NULL,
  to_status     ENUM('draft','in_review','approved','published','archived') NULL,
  occurred_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  detail        VARCHAR(500) NULL,
  KEY idx_audit_content (content_id, occurred_at),
  FOREIGN KEY (content_id) REFERENCES location_content(content_id),
  FOREIGN KEY (actor_id)   REFERENCES app_user(user_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- Append-only log of account and role changes (who gave/removed which role)
-- ---------------------------------------------------------------
CREATE TABLE user_admin_log (
  log_id          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  actor_id        INT UNSIGNED NOT NULL,
  target_user_id  INT UNSIGNED NOT NULL,
  action          ENUM('created','role_changed','activated','deactivated','password_reset') NOT NULL,
  from_role       ENUM('viewer','editor','administrator') NULL,
  to_role         ENUM('viewer','editor','administrator') NULL,
  occurred_at     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  detail          VARCHAR(500) NULL,
  KEY idx_user_log_target (target_user_id, occurred_at),
  FOREIGN KEY (actor_id)       REFERENCES app_user(user_id),
  FOREIGN KEY (target_user_id) REFERENCES app_user(user_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- Triggers: enforce the rules in the database, not just app code
-- ---------------------------------------------------------------
DELIMITER $$

-- Audit history is append-only
CREATE TRIGGER audit_event_no_update BEFORE UPDATE ON audit_event
FOR EACH ROW BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'audit_event is append-only';
END$$
CREATE TRIGGER audit_event_no_delete BEFORE DELETE ON audit_event
FOR EACH ROW BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'audit_event is append-only';
END$$
CREATE TRIGGER user_admin_log_no_update BEFORE UPDATE ON user_admin_log
FOR EACH ROW BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'user_admin_log is append-only';
END$$
CREATE TRIGGER user_admin_log_no_delete BEFORE DELETE ON user_admin_log
FOR EACH ROW BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'user_admin_log is append-only';
END$$

-- Content is never hard-deleted; archive it instead
CREATE TRIGGER content_no_delete BEFORE DELETE ON location_content
FOR EACH ROW BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Content cannot be deleted; set status to archived';
END$$

-- New content must always start as a draft
CREATE TRIGGER content_before_insert BEFORE INSERT ON location_content
FOR EACH ROW BEGIN
  IF NEW.status <> 'draft' THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'New content must start as draft';
  END IF;
  SET NEW.approved_by = NULL, NEW.approved_at = NULL,
      NEW.published_at = NULL, NEW.archived_at = NULL;
END$$

-- Fixed workflow: draft -> in_review -> approved (administrator only) -> published
-- Any state can be archived; archived can only be restored to draft.
CREATE TRIGGER content_before_update BEFORE UPDATE ON location_content
FOR EACH ROW BEGIN
  DECLARE v_role VARCHAR(20);

  IF NEW.status = OLD.status THEN
    -- Approved/published text cannot be changed in place; send it back to draft first
    IF OLD.status IN ('approved','published')
       AND (NEW.heading <> OLD.heading OR NEW.body <> OLD.body) THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Approved/published content cannot be edited; move it back to draft first';
    END IF;
  ELSE
    IF NOT (
         (OLD.status = 'draft'     AND NEW.status IN ('in_review','archived'))
      OR (OLD.status = 'in_review' AND NEW.status IN ('draft','approved','archived'))
      OR (OLD.status = 'approved'  AND NEW.status IN ('draft','published','archived'))
      OR (OLD.status = 'published' AND NEW.status IN ('draft','archived'))
      OR (OLD.status = 'archived'  AND NEW.status = 'draft')
    ) THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Illegal status transition';
    END IF;

    IF NEW.status = 'approved' THEN
      SELECT r.name INTO v_role
        FROM app_user u JOIN role r ON r.role_id = u.role_id
       WHERE u.user_id = NEW.approved_by;
      IF v_role IS NULL OR v_role <> 'administrator' THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT = 'Only an administrator can approve content';
      END IF;
      SET NEW.approved_at = CURRENT_TIMESTAMP;
    END IF;

    IF NEW.status = 'published' THEN
      SET NEW.published_at = CURRENT_TIMESTAMP;
    END IF;

    IF NEW.status = 'archived' THEN
      SET NEW.archived_at = CURRENT_TIMESTAMP;
    END IF;

    IF NEW.status = 'draft' THEN
      SET NEW.approved_by = NULL, NEW.approved_at = NULL,
          NEW.published_at = NULL, NEW.archived_at = NULL;
    END IF;
  END IF;
END$$

DELIMITER ;

-- ---------------------------------------------------------------
-- Public retrieval: ONLY published content is visible here.
-- Drafts, in-review, approved-but-unpublished and archived rows are excluded.
-- The public API's DB account gets SELECT on this view and nothing else.
-- ---------------------------------------------------------------
CREATE VIEW v_published_content AS
SELECT lc.token,
       l.location_id,
       l.name       AS location_name,
       st.code      AS section_code,
       st.sort_order AS section_order,
       lg.code      AS language_code,
       au.code      AS audience_code,
       c.heading,
       c.body,
       c.published_at
FROM location_content c
JOIN location       l  ON l.location_id       = c.location_id
JOIN location_code  lc ON lc.location_id      = c.location_id
JOIN section_type   st ON st.section_type_id  = c.section_type_id
JOIN language       lg ON lg.language_id      = c.language_id
JOIN audience_level au ON au.audience_id      = c.audience_id
WHERE c.status = 'published';

-- ---------------------------------------------------------------
-- Least-privilege DB accounts (run after the schema; change the passwords)
-- ---------------------------------------------------------------
-- CREATE USER 'cms_admin_app'@'localhost' IDENTIFIED BY 'CHANGE_ME';
-- GRANT SELECT, INSERT, UPDATE ON interpretive_cms.* TO 'cms_admin_app'@'localhost';
--   (no DELETE anywhere; audit_event is also protected by triggers)
--
-- CREATE USER 'cms_public_api'@'localhost' IDENTIFIED BY 'CHANGE_ME';
-- GRANT SELECT ON interpretive_cms.v_published_content TO 'cms_public_api'@'localhost';

-- ---------------------------------------------------------------
-- Seed lookups
-- ---------------------------------------------------------------
INSERT INTO role (name) VALUES ('viewer'), ('editor'), ('administrator');

INSERT INTO language (code, name) VALUES ('en','English'), ('es','Spanish');

INSERT INTO audience_level (code, label, sort_order) VALUES
  ('college',    'College-level reading',                         1),
  ('simplified', 'Simplified reading (reduced terminology)',      2);

INSERT INTO section_type (code, label, sort_order) VALUES
  ('building_history', 'History of the building', 1),
  ('name_history',     'History of the name',     2);
