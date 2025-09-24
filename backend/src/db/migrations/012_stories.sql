-- Migration 012: Stories schema (image/video/text stories)

DROP TABLE IF EXISTS story_mutes;
DROP TABLE IF EXISTS story_views;
DROP TABLE IF EXISTS stories;

CREATE TABLE stories (
  id VARCHAR(12) NOT NULL PRIMARY KEY,
  user_id VARCHAR(12) NOT NULL,
  media_type ENUM('image','video','text') NOT NULL,
  media_url TEXT NULL,
  text_content TEXT NULL,
  background_color VARCHAR(9) NULL, -- e.g. #RRGGBB or #RRGGBBAA
  audio_url TEXT NULL,
  audio_title VARCHAR(200) NULL,
  thumbnail_url TEXT NULL,
  privacy ENUM('public','followers','close_friends') NOT NULL DEFAULT 'public',
  viewers_count INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP NOT NULL,
  CONSTRAINT stories_fk_user FOREIGN KEY (user_id) REFERENCES users (id),
  INDEX stories_user_id (user_id),
  INDEX stories_created_at (created_at),
  INDEX stories_expires_at (expires_at)
);

CREATE TABLE story_views (
  story_id VARCHAR(12) NOT NULL,
  viewer_id VARCHAR(12) NOT NULL,
  viewed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (story_id, viewer_id),
  CONSTRAINT story_views_fk_story FOREIGN KEY (story_id) REFERENCES stories (id) ON DELETE CASCADE,
  CONSTRAINT story_views_fk_user FOREIGN KEY (viewer_id) REFERENCES users (id),
  INDEX story_views_viewer (viewer_id, viewed_at)
);

CREATE TABLE story_mutes (
  muter_id VARCHAR(12) NOT NULL,
  target_user_id VARCHAR(12) NOT NULL,
  muted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (muter_id, target_user_id),
  CONSTRAINT story_mutes_fk_muter FOREIGN KEY (muter_id) REFERENCES users (id),
  CONSTRAINT story_mutes_fk_target FOREIGN KEY (target_user_id) REFERENCES users (id)
);
