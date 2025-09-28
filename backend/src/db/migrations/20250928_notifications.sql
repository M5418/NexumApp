-- 20250928_notifications.sql
-- Core notifications table + tagging support on posts
-- Note: FKs are omitted deliberately to avoid charset/collation mismatches across existing tables.
-- We add useful indexes instead. We can add FKs later after normalizing collations.

SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE IF NOT EXISTS notifications (
  id VARCHAR(12) NOT NULL PRIMARY KEY,

  -- Recipient (who sees the notification)
  user_id VARCHAR(12) NOT NULL,

  -- Actor (who triggered the notification)
  actor_id VARCHAR(12) NULL,

  -- Event type
  type ENUM(
    'post_created',
    'community_post_created',
    'connection_received',
    'post_liked',
    'comment_added',
    'comment_liked',
    'community_post_liked',
    'community_comment_added',
    'community_comment_liked',
    'invitation_received',
    'invitation_accepted',
    'post_tagged',
    'community_post_tagged'
  ) NOT NULL,

  -- Target references (nullable depending on type)
  post_id VARCHAR(12) NULL,
  community_post_id VARCHAR(12) NULL,
  community_id VARCHAR(64) NULL,
  post_comment_id VARCHAR(12) NULL,
  community_comment_id VARCHAR(12) NULL,
  invitation_id VARCHAR(12) NULL,
  conversation_id VARCHAR(12) NULL,
  other_user_id VARCHAR(12) NULL,

  -- UI helpers (snapshots)
  preview_text TEXT NULL,
  preview_image_url TEXT NULL,

  -- Read status
  is_read TINYINT(1) NOT NULL DEFAULT 0,
  read_at TIMESTAMP NULL DEFAULT NULL,

  created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  -- Helpful indexes for query patterns
  INDEX notifications_user_created (user_id, created_at),
  INDEX notifications_user_unread  (user_id, is_read),
  INDEX notifications_type         (type),
  INDEX notifications_post         (post_id),
  INDEX notifications_comm_post    (community_post_id),
  INDEX notifications_invitation   (invitation_id),
  INDEX notifications_actor        (actor_id),
  INDEX notifications_other_user   (other_user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Tagging support on posts (global feed)
ALTER TABLE posts
  ADD COLUMN tagged_user_ids JSON NULL;

-- Tagging support on community posts
ALTER TABLE community_posts
  ADD COLUMN tagged_user_ids JSON NULL;

SET FOREIGN_KEY_CHECKS = 1;