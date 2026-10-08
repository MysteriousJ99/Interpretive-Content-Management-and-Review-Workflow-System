-- Upgrade an existing v1 database to v2 WITHOUT losing data.
-- Run as root (phpMyAdmin SQL tab with interpretive_cms selected, or the mysql command line).
USE interpretive_cms;

ALTER TABLE app_user
  ADD COLUMN password_hash VARCHAR(255) NULL AFTER role_id;

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

DELIMITER $$
CREATE TRIGGER user_admin_log_no_update BEFORE UPDATE ON user_admin_log
FOR EACH ROW BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'user_admin_log is append-only';
END$$
CREATE TRIGGER user_admin_log_no_delete BEFORE DELETE ON user_admin_log
FOR EACH ROW BEGIN
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'user_admin_log is append-only';
END$$
DELIMITER ;
