-- Interpretive Content Management and Review Workflow System
-- Draft schema v0 (Sprint 1 starting point -- for Will/Alex review before Wed client meeting)
-- Target: XAMPP MariaDB (MySQL-compatible), InnoDB, utf8mb4
-- NOTE: app_user/role tables are placeholders. SOW says "no custom-built authentication",
--       so replace them with whatever the chosen framework generates.

CREATE DATABASE IF NOT EXISTS interpretive_cms
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE interpretive_cms;

-- ---------------------------------------------------------------
-- Lookup tables (WBS 1.1.4: confirm languages & audience levels)
-- ---------------------------------------------------------------
CREATE TABLE language (
  language_id   TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code          VARCHAR(10)  NOT NULL UNIQUE,      -- e.g. 'en', 'es'
  name          VARCHAR(50)  NOT NULL
) ENGINE=InnoDB;

CREATE TABLE audience_level (
  audience_id   TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code          VARCHAR(20)  NOT NULL UNIQUE,      -- e.g. 'general', 'simple'
  label         VARCHAR(50)  NOT NULL,
  sort_order    TINYINT UNSIGNED NOT NULL DEFAULT 0
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- Users & roles (placeholder for framework auth)
-- ---------------------------------------------------------------
CREATE TABLE app_user (
  user_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email         VARCHAR(255) NOT NULL UNIQUE,
  display_name  VARCHAR(100) NOT NULL,
  is_active     TINYINT(1)   NOT NULL DEFAULT 1,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE role (
  role_id       TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name          ENUM('author','reviewer','administrator') NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE user_role (
  user_id       INT UNSIGNED     NOT NULL,
  role_id       TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (user_id, role_id),
  FOREIGN KEY (user_id) REFERENCES app_user(user_id),
  FOREIGN KEY (role_id) REFERENCES role(role_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- Locations and location codes (Success Steps 1 and 3)
-- ---------------------------------------------------------------
CREATE TABLE location (
  location_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(150) NOT NULL,
  description   TEXT NULL,                         -- internal/admin note, not visitor content
  created_by    INT UNSIGNED NOT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (created_by) REFERENCES app_user(user_id)
) ENGINE=InnoDB;

-- One stable code per location. The token is what the QR encodes; it never changes.
CREATE TABLE location_code (
  location_id   INT UNSIGNED PRIMARY KEY,
  token         CHAR(36) NOT NULL UNIQUE,          -- UUID
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (location_id) REFERENCES location(location_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- Content: one row per location x language x audience level
-- ---------------------------------------------------------------
CREATE TABLE content_variant (
  variant_id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  location_id   INT UNSIGNED     NOT NULL,
  language_id   TINYINT UNSIGNED NOT NULL,
  audience_id   TINYINT UNSIGNED NOT NULL,
  title         VARCHAR(200) NOT NULL,
  body          MEDIUMTEXT   NOT NULL,
  status        ENUM('draft','in_review','approved','published') NOT NULL DEFAULT 'draft',
  author_id     INT UNSIGNED NOT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  published_at  DATETIME NULL,
  UNIQUE KEY uq_variant (location_id, language_id, audience_id),
  FOREIGN KEY (location_id) REFERENCES location(location_id),
  FOREIGN KEY (language_id) REFERENCES language(language_id),
  FOREIGN KEY (audience_id) REFERENCES audience_level(audience_id),
  FOREIGN KEY (author_id)   REFERENCES app_user(user_id)
) ENGINE=InnoDB;

-- Reviewer comments and the return-for-revision path (WBS 1.2.1 / 2.3.4)
CREATE TABLE review_comment (
  comment_id    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  variant_id    INT UNSIGNED NOT NULL,
  reviewer_id   INT UNSIGNED NOT NULL,
  decision      ENUM('comment','return_for_revision','approve') NOT NULL,
  comment_text  TEXT NULL,
  created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (variant_id)  REFERENCES content_variant(variant_id),
  FOREIGN KEY (reviewer_id) REFERENCES app_user(user_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------
-- Append-only audit history (Success Step 6)
-- ---------------------------------------------------------------
CREATE TABLE audit_event (
  event_id      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  variant_id    INT UNSIGNED NOT NULL,
  actor_id      INT UNSIGNED NOT NULL,
  action        ENUM('created','edited','submitted','returned','approved','published') NOT NULL,
  from_status   ENUM('draft','in_review','approved','published') NULL,
  to_status     ENUM('draft','in_review','approved','published') NULL,
  occurred_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  detail        VARCHAR(500) NULL,
  KEY idx_audit_variant (variant_id, occurred_at),
  FOREIGN KEY (variant_id) REFERENCES content_variant(variant_id),
  FOREIGN KEY (actor_id)   REFERENCES app_user(user_id)
) ENGINE=InnoDB;

-- Enforce append-only in the database itself, not just in app code.
DELIMITER $$
CREATE TRIGGER audit_event_no_update BEFORE UPDATE ON audit_event
FOR EACH ROW BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'audit_event is append-only';
END$$
CREATE TRIGGER audit_event_no_delete BEFORE DELETE ON audit_event
FOR EACH ROW BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'audit_event is append-only';
END$$
DELIMITER ;

-- ---------------------------------------------------------------
-- Structural approval enforcement (Success Step 5)
-- The retrieval API connects as a DB user that can SELECT ONLY this view.
-- ---------------------------------------------------------------
CREATE VIEW v_published_content AS
SELECT lc.token, l.location_id, l.name AS location_name,
       lg.code AS language_code, au.code AS audience_code,
       cv.title, cv.body, cv.published_at
FROM content_variant cv
JOIN location       l  ON l.location_id  = cv.location_id
JOIN location_code  lc ON lc.location_id = cv.location_id
JOIN language       lg ON lg.language_id = cv.language_id
JOIN audience_level au ON au.audience_id = cv.audience_id
WHERE cv.status = 'published';

-- ---------------------------------------------------------------
-- Least-privilege DB accounts (create after schema; adjust passwords)
-- ---------------------------------------------------------------
-- CREATE USER 'cms_admin_app'@'localhost' IDENTIFIED BY 'CHANGE_ME';
-- GRANT SELECT, INSERT, UPDATE ON interpretive_cms.* TO 'cms_admin_app'@'localhost';
-- REVOKE UPDATE, DELETE ON interpretive_cms.audit_event FROM 'cms_admin_app'@'localhost';
--
-- CREATE USER 'cms_public_api'@'localhost' IDENTIFIED BY 'CHANGE_ME';
-- GRANT SELECT ON interpretive_cms.v_published_content TO 'cms_public_api'@'localhost';

-- ---------------------------------------------------------------
-- Seed lookups (confirm with Client per WBS 1.1.4)
-- ---------------------------------------------------------------
INSERT INTO language (code, name) VALUES ('en','English'), ('es','Spanish');
INSERT INTO audience_level (code, label, sort_order) VALUES
  ('general','General adult',1), ('simple','Simplified reading level',2);
INSERT INTO role (name) VALUES ('author'), ('reviewer'), ('administrator');
