-- File: backend/src/db/migrations/20250928_kyc_verifications.sql
-- Lines: 1-52
-- Creates the KYC table with user_id VARCHAR(12) to exactly match users.id to avoid MySQL error 3780
CREATE TABLE IF NOT EXISTS kyc_verifications (
  id VARCHAR(12) NOT NULL,
  user_id VARCHAR(12) NOT NULL,
  document_type VARCHAR(50) NOT NULL,
  document_number VARCHAR(100) NOT NULL,
  issue_place VARCHAR(100) NULL,
  issue_date DATE NULL,
  expiry_date DATE NULL,
  country VARCHAR(100) NULL,
  city_of_birth VARCHAR(100) NULL,
  address VARCHAR(255) NULL,
  uploaded_file_names JSON NULL,
  status ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  is_approved BOOLEAN NOT NULL DEFAULT FALSE,
  is_rejected BOOLEAN NOT NULL DEFAULT FALSE,
  admin_notes TEXT NULL,
  reviewed_by VARCHAR(12) NULL,
  reviewed_at TIMESTAMP NULL,
  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY kyc_unique_user (user_id),
  INDEX kyc_user_id (user_id),
  CONSTRAINT kyc_fk_user FOREIGN KEY (user_id)
    REFERENCES users(id)
    ON DELETE CASCADE
    ON UPDATE NO ACTION
) ENGINE=InnoDB;