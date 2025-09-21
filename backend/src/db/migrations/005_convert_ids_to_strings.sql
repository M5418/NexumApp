-- Migration 005: Convert all IDs from BigInt to VARCHAR(12) strings
-- This migration will backup existing data and recreate tables with string IDs

-- Step 1: Create backup tables
CREATE TABLE users_backup AS SELECT * FROM users;
CREATE TABLE profiles_backup AS SELECT * FROM profiles;
CREATE TABLE connections_backup AS SELECT * FROM connections;
CREATE TABLE uploads_backup AS SELECT * FROM uploads;

-- Step 2: Drop foreign key constraints
ALTER TABLE profiles DROP FOREIGN KEY fk_profiles_user;
ALTER TABLE connections DROP FOREIGN KEY connections_ibfk_1;
ALTER TABLE connections DROP FOREIGN KEY connections_ibfk_2;
ALTER TABLE uploads DROP FOREIGN KEY uploads_ibfk_1;

-- Step 3: Drop and recreate tables with new schema
DROP TABLE connections;
DROP TABLE uploads;
DROP TABLE profiles;
DROP TABLE users;

-- Step 4: Create users table with VARCHAR ID
CREATE TABLE users (
  id VARCHAR(12) NOT NULL PRIMARY KEY,
  email VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX email (email)
);

-- Step 5: Create profiles table with VARCHAR IDs
CREATE TABLE profiles (
  id VARCHAR(12) NOT NULL PRIMARY KEY,
  user_id VARCHAR(12) NOT NULL UNIQUE,
  first_name VARCHAR(100) NULL,
  last_name VARCHAR(100) NULL,
  username VARCHAR(100) NULL UNIQUE,
  birthday DATE NULL,
  gender VARCHAR(50) NULL,
  status VARCHAR(50) NULL,
  interest_domains JSON NULL,
  street VARCHAR(255) NULL,
  city VARCHAR(100) NULL,
  state VARCHAR(100) NULL,
  postal_code VARCHAR(20) NULL,
  country VARCHAR(100) NULL,
  profile_photo_url TEXT NULL,
  cover_photo_url TEXT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  professional_experiences JSON NULL,
  trainings JSON NULL,
  bio TEXT NULL,
  CONSTRAINT fk_profiles_user FOREIGN KEY (user_id) REFERENCES users (id),
  INDEX user_id (user_id),
  INDEX username (username)
);

-- Step 6: Create uploads table with VARCHAR IDs
CREATE TABLE uploads (
  id VARCHAR(12) NOT NULL PRIMARY KEY,
  user_id VARCHAR(12) NULL,
  s3_key VARCHAR(512) NOT NULL,
  url TEXT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uploads_ibfk_1 FOREIGN KEY (user_id) REFERENCES users (id),
  INDEX user_id (user_id)
);

-- Step 7: Create connections table with VARCHAR IDs
CREATE TABLE connections (
  from_user_id VARCHAR(12) NOT NULL,
  to_user_id VARCHAR(12) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (from_user_id, to_user_id),
  CONSTRAINT connections_ibfk_1 FOREIGN KEY (from_user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT connections_ibfk_2 FOREIGN KEY (to_user_id) REFERENCES users (id) ON DELETE CASCADE,
  INDEX to_user_id (to_user_id)
);

-- Note: Data migration will be handled by a separate Node.js script
-- since we need to generate new 12-character alphanumeric IDs
-- The backup tables contain the original data for reference
