-- Add new profile fields for experience, training, and bio
ALTER TABLE profiles ADD COLUMN professional_experiences JSON NULL;
ALTER TABLE profiles ADD COLUMN trainings JSON NULL;
ALTER TABLE profiles ADD COLUMN bio TEXT NULL;
