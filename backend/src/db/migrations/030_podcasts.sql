-- Podcasts core tables
CREATE TABLE IF NOT EXISTS podcasts (
  id                  VARCHAR(12) NOT NULL,
  created_by_user_id  VARCHAR(12) NOT NULL,
  title               VARCHAR(255) NOT NULL,
  author_name         VARCHAR(255) NULL,
  description         TEXT NULL,
  cover_url           TEXT NULL,
  audio_url           TEXT NULL,
  duration_sec        INT NULL,
  language            VARCHAR(32) NULL,
  category            VARCHAR(64) NULL,
  tags                JSON NULL,
  liked_by            JSON NULL,
  likes_count         INT DEFAULT 0,
  favorites_count     INT DEFAULT 0,
  plays_count         INT DEFAULT 0,
  is_published        TINYINT(1) DEFAULT 0,
  created_at          TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY podcasts_user (created_by_user_id),
  KEY podcasts_created_at (created_at),
  KEY podcasts_category (category),
  CONSTRAINT podcasts_fk_user FOREIGN KEY (created_by_user_id) REFERENCES users(id) ON DELETE NO ACTION ON UPDATE NO ACTION
);

CREATE TABLE IF NOT EXISTS podcast_favorites (
  user_id     VARCHAR(12) NOT NULL,
  podcast_id  VARCHAR(12) NOT NULL,
  created_at  TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, podcast_id),
  KEY pf_podcast (podcast_id),
  CONSTRAINT pf_fk_user    FOREIGN KEY (user_id)    REFERENCES users(id)    ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT pf_fk_podcast FOREIGN KEY (podcast_id) REFERENCES podcasts(id) ON DELETE CASCADE ON UPDATE NO ACTION
);

CREATE TABLE IF NOT EXISTS podcast_progress (
  user_id           VARCHAR(12) NOT NULL,
  podcast_id        VARCHAR(12) NOT NULL,
  last_position_sec INT DEFAULT 0,
  duration_sec      INT DEFAULT NULL,
  finished_audio    TINYINT(1) DEFAULT 0,
  created_at        TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at        TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, podcast_id),
  KEY pp_podcast (podcast_id),
  CONSTRAINT pp_fk_user    FOREIGN KEY (user_id)    REFERENCES users(id)    ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT pp_fk_podcast FOREIGN KEY (podcast_id) REFERENCES podcasts(id) ON DELETE CASCADE ON UPDATE NO ACTION
);

-- Playlists (user-owned)
CREATE TABLE IF NOT EXISTS playlists (
  id          VARCHAR(12) NOT NULL,
  user_id     VARCHAR(12) NOT NULL,
  name        VARCHAR(255) NOT NULL,
  is_private  TINYINT(1) DEFAULT 0,
  created_at  TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY playlists_user (user_id),
  CONSTRAINT playlists_fk_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE NO ACTION
);

-- Playlist items (podcasts)
CREATE TABLE IF NOT EXISTS playlist_items (
  playlist_id  VARCHAR(12) NOT NULL,
  podcast_id   VARCHAR(12) NOT NULL,
  added_at     TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (playlist_id, podcast_id),
  KEY pi_podcast (podcast_id),
  CONSTRAINT pi_fk_playlist FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE ON UPDATE NO ACTION,
  CONSTRAINT pi_fk_podcast  FOREIGN KEY (podcast_id)  REFERENCES podcasts(id)  ON DELETE CASCADE ON UPDATE NO ACTION
);