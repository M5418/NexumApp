-- Adds feed preference flags to profiles table
-- Run against your MySQL DB, e.g.:
--   mysql -h <host> -u <user> -p <db_name> < backend/sql/20250929_add_profile_feed_prefs.sql

ALTER TABLE profiles
  ADD COLUMN show_reposts TINYINT(1) NULL DEFAULT 1 AFTER cover_photo_url,
  ADD COLUMN show_suggested_posts TINYINT(1) NULL DEFAULT 1 AFTER show_reposts,
  ADD COLUMN prioritize_interests TINYINT(1) NULL DEFAULT 1 AFTER show_suggested_posts;

-- Optional: backfill existing NULLs to defaults
UPDATE profiles
  SET 
    show_reposts = COALESCE(show_reposts, 1),
    show_suggested_posts = COALESCE(show_suggested_posts, 1),
    prioritize_interests = COALESCE(prioritize_interests, 1);

-- Verification queries (manual):
-- SELECT show_reposts, show_suggested_posts, prioritize_interests FROM profiles LIMIT 5;

-- Notes:
-- - The API endpoints already read/write these fields:
--     PATCH /api/profile     -> accepts booleans
--     GET   /api/profile/me  -> returns fields
--     GET   /api/profile/:id -> returns fields
-- - Flutter FeedPreferencesPage writes changes immediately on toggle and supports Save/Reset.
-- - HomeFeedPage filters locally by these preferences using hashtags in post text.

-- Rollback (manual):
-- ALTER TABLE profiles DROP COLUMN prioritize_interests, DROP COLUMN show_suggested_posts, DROP COLUMN show_reposts;