-- Upgrade an existing v2 database to v3 WITHOUT losing data.
-- v3 change: French is added as a third language (decision 2026-10-14).
--   Content is now 2 sections x 3 languages x 2 reading levels = 12 rows per building.
--
-- Run as root, from the repo root in Command Prompt:
--   C:\xampp\mysql\bin\mysql.exe -u root --default-character-set=utf8mb4 < db\migrate_v2_to_v3.sql
-- (or paste into phpMyAdmin's SQL tab with interpretive_cms selected).
-- Safe to run more than once.
USE interpretive_cms;
SET NAMES utf8mb4;

INSERT IGNORE INTO language (code, name) VALUES ('fr', 'French');

-- Check: should list en, es, fr
SELECT language_id, code, name FROM language ORDER BY language_id;
