-- Migration 008: Simplified Posts Schema
-- Drop separate interaction tables and consolidate into posts table with JSON columns

-- Drop existing interaction tables
DROP TABLE IF EXISTS post_likes;
DROP TABLE IF EXISTS post_bookmarks;
DROP TABLE IF EXISTS post_shares;
DROP TABLE IF EXISTS post_media;

-- Drop and recreate posts table with new structure
DROP TABLE IF EXISTS posts;
CREATE TABLE posts (
  id VARCHAR(12) NOT NULL PRIMARY KEY,
  user_id VARCHAR(12) NOT NULL,
  post_type ENUM('text', 'text_photo', 'text_video') NOT NULL DEFAULT 'text',
  content TEXT NULL,
  
  -- Media content
  image_url TEXT NULL,
  image_urls JSON NULL,  -- Array of image URLs for multiple images
  video_url TEXT NULL,
  
  -- Interaction lists (JSON arrays of user IDs)
  liked_by JSON NULL,     -- ["user1", "user2", ...]
  shared_by JSON NULL,    -- ["user1", "user2", ...]
  bookmarked_by JSON NULL, -- ["user1", "user2", ...]
  reposted_by JSON NULL,  -- ["user1", "user2", ...]
  
  -- Interaction counts (computed from JSON arrays)
  likes_count INT DEFAULT 0,
  shares_count INT DEFAULT 0,
  bookmarks_count INT DEFAULT 0,
  reposts_count INT DEFAULT 0,
  comments_count INT DEFAULT 0,
  
  -- Repost reference
  repost_of VARCHAR(12) NULL,
  
  -- Timestamps
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  
  -- Foreign keys
  CONSTRAINT posts_fk_user FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT posts_fk_repost FOREIGN KEY (repost_of) REFERENCES posts (id) ON DELETE SET NULL,
  
  -- Indexes
  INDEX posts_user_id (user_id),
  INDEX posts_created_at (created_at),
  INDEX posts_repost_of (repost_of)
);

-- Update post_comments table to include likes
ALTER TABLE post_comments 
ADD COLUMN liked_by JSON NULL AFTER content,
ADD COLUMN likes_count INT DEFAULT 0 AFTER liked_by;
