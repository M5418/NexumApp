// backend/scripts/create-community-posts-tables.js
import 'dotenv/config';
import mysql from 'mysql2/promise';

async function run() {
  let conn;
  try {
    conn = await mysql.createConnection(process.env.DATABASE_URL);
    console.log('Connected to database');

    // Ensure JSON support and FK checks handling
    await conn.query('SET FOREIGN_KEY_CHECKS = 0');

    // community_posts: identical to posts + community_id
    await conn.query(`
      CREATE TABLE IF NOT EXISTS community_posts (
        id VARCHAR(12) NOT NULL PRIMARY KEY,
        community_id VARCHAR(64) NOT NULL,
        user_id VARCHAR(12) NOT NULL,
        post_type ENUM('text', 'text_photo', 'text_video') NOT NULL DEFAULT 'text',
        content TEXT NULL,

        -- Media content
        image_url TEXT NULL,
        image_urls JSON NULL,
        video_url TEXT NULL,

        -- Interaction lists (JSON arrays of user IDs)
        liked_by JSON NULL,
        shared_by JSON NULL,
        bookmarked_by JSON NULL,
        reposted_by JSON NULL,

        -- Interaction counts
        likes_count INT DEFAULT 0,
        shares_count INT DEFAULT 0,
        bookmarks_count INT DEFAULT 0,
        reposts_count INT DEFAULT 0,
        comments_count INT DEFAULT 0,

        -- Repost reference (to a community_posts id)
        repost_of VARCHAR(12) NULL,

        -- Timestamps
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

        -- Foreign keys
        CONSTRAINT community_posts_fk_user FOREIGN KEY (user_id) REFERENCES users (id),
        CONSTRAINT community_posts_fk_repost FOREIGN KEY (repost_of) REFERENCES community_posts (id) ON DELETE SET NULL,

        -- Indexes
        INDEX community_posts_community_id (community_id),
        INDEX community_posts_created_at (created_at),
        INDEX community_posts_user_id (user_id),
        INDEX community_posts_repost_of (repost_of),
        INDEX community_posts_community_created (community_id, created_at)
      )
    `);

    // Top-level comments for community posts
    await conn.query(`
      CREATE TABLE IF NOT EXISTS community_post_comments (
        id VARCHAR(12) NOT NULL PRIMARY KEY,
        post_id VARCHAR(12) NOT NULL,
        user_id VARCHAR(12) NOT NULL,
        content TEXT NOT NULL,
        liked_by JSON NULL,
        likes_count INT DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

        CONSTRAINT community_post_comments_fk_post
          FOREIGN KEY (post_id) REFERENCES community_posts (id) ON DELETE CASCADE,
        CONSTRAINT community_post_comments_fk_user
          FOREIGN KEY (user_id) REFERENCES users (id),

        INDEX community_post_comments_post_id (post_id),
        INDEX community_post_comments_user_id (user_id),
        INDEX community_post_comments_created_at (created_at)
      )
    `);

    // Nested replies (tree) for community post comments
    await conn.query(`
      CREATE TABLE IF NOT EXISTS community_post_comment_replies (
        id VARCHAR(12) NOT NULL PRIMARY KEY,
        post_id VARCHAR(12) NOT NULL,
        comment_id VARCHAR(12) NOT NULL,
        parent_reply_id VARCHAR(12) NULL,
        user_id VARCHAR(12) NOT NULL,
        content TEXT NOT NULL,
        liked_by JSON NULL,
        likes_count INT DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

        CONSTRAINT community_post_comment_replies_fk_post
          FOREIGN KEY (post_id) REFERENCES community_posts (id) ON DELETE CASCADE,
        CONSTRAINT community_post_comment_replies_fk_comment
          FOREIGN KEY (comment_id) REFERENCES community_post_comments (id) ON DELETE CASCADE,
        CONSTRAINT community_post_comment_replies_fk_parent
          FOREIGN KEY (parent_reply_id) REFERENCES community_post_comment_replies (id) ON DELETE CASCADE,
        CONSTRAINT community_post_comment_replies_fk_user
          FOREIGN KEY (user_id) REFERENCES users (id),

        INDEX community_post_comment_replies_post_id (post_id),
        INDEX community_post_comment_replies_comment_id (comment_id),
        INDEX community_post_comment_replies_parent (parent_reply_id),
        INDEX community_post_comment_replies_user_id (user_id),
        INDEX community_post_comment_replies_created_at (created_at)
      )
    `);

    // Snapshot table for reposts (just like post_reposts but per-community)
    await conn.query(`
      CREATE TABLE IF NOT EXISTS community_post_reposts (
        id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        original_post_id VARCHAR(12) NOT NULL,
        reposted_by_user_id VARCHAR(12) NOT NULL,

        -- Reposter snapshot
        reposter_name VARCHAR(255) NULL,
        reposter_username VARCHAR(255) NULL,
        reposter_avatar_url TEXT NULL,

        -- Original author snapshot
        original_author_id VARCHAR(12) NULL,
        original_author_name VARCHAR(255) NULL,
        original_author_username VARCHAR(255) NULL,
        original_author_avatar_url TEXT NULL,

        -- Original content snapshot
        original_content TEXT NULL,
        original_post_type VARCHAR(32) NULL,
        original_image_url TEXT NULL,
        original_image_urls JSON NULL,
        original_video_url TEXT NULL,

        -- Original counts snapshot
        original_likes_count INT DEFAULT 0,
        original_comments_count INT DEFAULT 0,
        original_shares_count INT DEFAULT 0,
        original_reposts_count INT DEFAULT 0,
        original_bookmarks_count INT DEFAULT 0,

        UNIQUE KEY community_post_reposts_unique (original_post_id, reposted_by_user_id),
        INDEX community_post_reposts_original (original_post_id),
        INDEX community_post_reposts_reposter (reposted_by_user_id)
      )
    `);

    await conn.query('SET FOREIGN_KEY_CHECKS = 1');
    console.log('✅ Community posts tables are ready.');
  } catch (err) {
    console.error('❌ Failed to create community posts tables:', err);
    process.exit(1);
  } finally {
    if (conn) await conn.end();
  }
}

run();