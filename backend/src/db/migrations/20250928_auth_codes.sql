-- 20250928_auth_codes.sql
-- Stores 5-digit verification codes for sensitive auth actions

CREATE TABLE IF NOT EXISTS auth_verification_codes (
  id              VARCHAR(12) NOT NULL PRIMARY KEY,
  user_id         VARCHAR(12) NOT NULL,
  purpose         ENUM('change_password','change_email') NOT NULL,
  code            CHAR(5) NOT NULL,
  sent_to         VARCHAR(255) NOT NULL,
  new_email       VARCHAR(255) NULL,
  new_password_hash VARCHAR(255) NULL,
  attempts        INT NOT NULL DEFAULT 0,
  consumed        TINYINT(1) NOT NULL DEFAULT 0,
  expires_at      TIMESTAMP NOT NULL,
  created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT avc_fk_user FOREIGN KEY (user_id) REFERENCES users (id),
  INDEX avc_user_purpose (user_id, purpose, consumed, expires_at),
  INDEX avc_code (code),
  INDEX avc_expires (expires_at)
) ENGINE=InnoDB;