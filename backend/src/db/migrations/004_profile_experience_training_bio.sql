-- Add new profile fields for experience, training, and bio
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS professional_experiences JSON NULL;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS trainings JSON NULL;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS bio TEXT NULL;
