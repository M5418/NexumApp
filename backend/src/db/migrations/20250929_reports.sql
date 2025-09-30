-- File: backend/src/db/migrations/20250929_reports.sql
-- Adds users.is_admin and creates reports table

-- 1) Add admin flag to users (run once; migration runner will only apply this file once)
ALTER TABLE users
  ADD COLUMN is_admin TINYINT(1) NOT NULL DEFAULT 0 AFTER password_hash;

-- 2) Create reports table
CREATE TABLE IF NOT EXISTS reports (
  id VARCHAR(12) NOT NULL PRIMARY KEY,
  reporter_user_id VARCHAR(12) NOT NULL,
  target_type ENUM('post','story','user') NOT NULL,
  target_id VARCHAR(12) NOT NULL,
  target_owner_user_id VARCHAR(12) NULL,
  cause VARCHAR(64) NOT NULL,
  description TEXT NULL,
  -- denormalized snapshots for quick review
  reporter_full_name VARCHAR(150) NULL,
  reporter_username VARCHAR(100) NULL,
  target_full_name VARCHAR(150) NULL,
  target_username VARCHAR(100) NULL,
  status ENUM('pending','approved','rejected','ignored') NOT NULL DEFAULT 'pending',
  admin_user_id VARCHAR(12) NULL,
  admin_decision_text TEXT NULL,
  decided_at TIMESTAMP NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX reports_reporter (reporter_user_id, created_at),
  INDEX reports_target (target_type, target_id, created_at),
  INDEX reports_status (status, created_at)
);