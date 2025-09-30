-- File: backend/src/db/migrations/20250928_kyc_file_urls.sql
-- Lines: 1-18
-- Adds URL columns for uploaded files on KYC (front, back, selfie)
ALTER TABLE kyc_verifications
  ADD COLUMN front_url TEXT NULL AFTER uploaded_file_names,
  ADD COLUMN back_url TEXT NULL AFTER front_url,
  ADD COLUMN selfie_url TEXT NULL AFTER back_url;