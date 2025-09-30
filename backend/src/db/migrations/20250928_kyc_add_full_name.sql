-- File: backend/src/db/migrations/20250928_kyc_add_full_name.sql
-- Lines: 1-10
-- Adds user full name on KYC rows
ALTER TABLE kyc_verifications
  ADD COLUMN full_name VARCHAR(150) NULL AFTER user_id;