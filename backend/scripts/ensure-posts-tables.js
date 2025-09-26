import 'dotenv/config';
import mysql from 'mysql2/promise';

async function ensurePostsTables() {
  let conn;
  try {
    conn = await mysql.createConnection(process.env.DATABASE_URL);
    console.log('Connected to database:', (await conn.query('SELECT DATABASE() db'))[0][0].db);

    const stmts = [
      `CREATE TABLE IF NOT EXISTS posts (
        id VARCHAR(12) NOT NULL PRIMARY KEY,
        user_id VARCHAR(12) NOT NULL,
        post_type ENUM('text', 'text_photo', 'text_video') NOT NULL DEFAULT 'text',
        content TEXT NULL,
        image_url TEXT NULL,
        image_urls JSON NULL,
        video_url TEXT NULL,
        liked_by JSON NULL,
        shared_by JSON NULL,
        bookmarked_by JSON NULL,
        reposted_by JSON NULL,
        likes_count INT DEFAULT 0,
        shares_count INT DEFAULT 0,
        bookmarks_count INT DEFAULT 0,
        reposts_count INT DEFAULT 0,
        comments_count INT DEFAULT 0,
        repost_of VARCHAR(12) NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        CONSTRAINT posts_fk_user FOREIGN KEY (user_id) REFERENCES users (id),
        CONSTRAINT posts_fk_repost FOREIGN KEY (repost_of) REFERENCES posts (id) ON DELETE SET NULL,
        INDEX posts_user_id (user_id),
        INDEX posts_created_at (created_at),
        INDEX posts_repost_of (repost_of)
      )`,
      `CREATE TABLE IF NOT EXISTS post_comments (
        id VARCHAR(12) NOT NULL PRIMARY KEY,
        post_id VARCHAR(12) NOT NULL,
        user_id VARCHAR(12) NOT NULL,
        content TEXT NOT NULL,
        liked_by JSON NULL,
        likes_count INT DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        CONSTRAINT post_comments_fk_post FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE,
        CONSTRAINT post_comments_fk_user FOREIGN KEY (user_id) REFERENCES users (id),
        INDEX post_comments_post_id (post_id),
        INDEX post_comments_user_id (user_id),
        INDEX post_comments_created_at (created_at)
      )`,
      `CREATE TABLE IF NOT EXISTS post_comment_replies (
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
        CONSTRAINT pcr_fk_post         FOREIGN KEY (post_id)        REFERENCES posts (id) ON DELETE CASCADE,
        CONSTRAINT pcr_fk_comment      FOREIGN KEY (comment_id)     REFERENCES post_comments (id) ON DELETE CASCADE,
        CONSTRAINT pcr_fk_parent_reply FOREIGN KEY (parent_reply_id) REFERENCES post_comment_replies (id) ON DELETE CASCADE,
        CONSTRAINT pcr_fk_user         FOREIGN KEY (user_id)        REFERENCES users (id),
        INDEX pcr_post_id (post_id),
        INDEX pcr_comment_id (comment_id),
        INDEX pcr_parent_reply_id (parent_reply_id),
        INDEX pcr_user_id (user_id),
        INDEX pcr_created_at (created_at)
      )`,
    ];

    for (const s of stmts) {
      try {
        await conn.query(s);
        console.log('Executed:', s.split('\n')[0]);
      } catch (e) {
        console.error('Failed executing statement:', e.message);
        throw e;
      }
    }

    const [posts] = await conn.query("SHOW TABLES LIKE 'posts'");
    console.log('postsExists:', posts.length > 0);
    console.log('✅ Posts tables ensured');
  } catch (e) {
    console.error('❌ ensure-posts-tables failed:', e);
    process.exit(1);
  } finally {
    if (conn) await conn.end();
  }
}

ensurePostsTables();