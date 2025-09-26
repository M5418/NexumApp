-- 014_books.sql

-- Books table stores metadata and media URLs (PDF + audio)
CREATE TABLE IF NOT EXISTS books (
  id                  VARCHAR(12) NOT NULL PRIMARY KEY,
  created_by_user_id  VARCHAR(12) NOT NULL,
  title               VARCHAR(255) NOT NULL,
  author_name         VARCHAR(255) NULL,
  description         TEXT NULL,
  cover_url           TEXT NULL,
  pdf_url             TEXT NULL,
  audio_url           TEXT NULL,

  -- Likes: list of user IDs (JSON) + count
  liked_by            JSON NULL,
  likes_count         INT NOT NULL DEFAULT 0,

  language            VARCHAR(32) NULL,
  category            VARCHAR(64) NULL,
  tags                JSON NULL,
  price               DECIMAL(10,2) NULL,
  is_published        TINYINT(1) NOT NULL DEFAULT 0,
  favorites_count     INT NOT NULL DEFAULT 0,
  reads_count         INT NOT NULL DEFAULT 0,
  plays_count         INT NOT NULL DEFAULT 0,
  reading_minutes     INT NULL,
  audio_duration_sec  INT NULL,
  created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT books_fk_created_by FOREIGN KEY (created_by_user_id) REFERENCES users (id),
  INDEX books_created_by (created_by_user_id),
  INDEX books_created_at (created_at),
  INDEX books_published (is_published)
);

-- Book favorites (per user)
CREATE TABLE IF NOT EXISTS book_favorites (
  user_id    VARCHAR(12) NOT NULL,
  book_id    VARCHAR(12) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, book_id),
  CONSTRAINT book_fav_fk_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT book_fav_fk_book FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE,
  INDEX book_fav_book (book_id)
);

-- Book progress per user (reading + audio)
CREATE TABLE IF NOT EXISTS book_progress (
  user_id                 VARCHAR(12) NOT NULL,
  book_id                 VARCHAR(12) NOT NULL,
  last_page               INT NULL,
  total_pages             INT NULL,
  last_audio_position_sec INT NULL,
  audio_duration_sec      INT NULL,
  finished_reading        TINYINT(1) NOT NULL DEFAULT 0,
  finished_audio          TINYINT(1) NOT NULL DEFAULT 0,
  created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, book_id),
  CONSTRAINT book_prog_fk_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT book_prog_fk_book FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE,
  INDEX book_prog_updated_at (updated_at)
);