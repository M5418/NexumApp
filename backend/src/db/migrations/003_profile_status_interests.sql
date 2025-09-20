-- Only add interest_domains column since status already exists
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS interest_domains JSON NULL;
