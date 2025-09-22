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
        content TEXT NULL,
        repost_of VARCHAR(12) NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        CONSTRAINT posts_fk_user FOREIGN KEY (user_id) REFERENCES users (id),
        CONSTRAINT posts_fk_repost FOREIGN KEY (repost_of) REFERENCES posts (id) ON DELETE SET NULL,
        INDEX posts_user_id (user_id),
        INDEX posts_repost_of (repost_of),
        INDEX posts_created_at (created_at)
      )`,
      `CREATE TABLE IF NOT EXISTS post_media (
        id VARCHAR(12) NOT NULL PRIMARY KEY,
        post_id VARCHAR(12) NOT NULL,
        media_type VARCHAR(10) NOT NULL,
        upload_id VARCHAR(12) NULL,
        s3_key VARCHAR(512) NULL,
        url TEXT NULL,
        position INT DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        CONSTRAINT post_media_fk_post FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE,
        CONSTRAINT post_media_fk_upload FOREIGN KEY (upload_id) REFERENCES uploads (id),
        INDEX post_media_post_id (post_id)
      )`,
      `CREATE TABLE IF NOT EXISTS post_likes (
        post_id VARCHAR(12) NOT NULL,
        user_id VARCHAR(12) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (post_id, user_id),
        CONSTRAINT post_likes_fk_post FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE,
        CONSTRAINT post_likes_fk_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        INDEX post_likes_user_id (user_id)
      )`,
      `CREATE TABLE IF NOT EXISTS post_bookmarks (
        post_id VARCHAR(12) NOT NULL,
        user_id VARCHAR(12) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (post_id, user_id),
        CONSTRAINT post_bookmarks_fk_post FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE,
        CONSTRAINT post_bookmarks_fk_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        INDEX post_bookmarks_user_id (user_id)
      )`,
      `CREATE TABLE IF NOT EXISTS post_shares (
        post_id VARCHAR(12) NOT NULL,
        user_id VARCHAR(12) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (post_id, user_id),
        CONSTRAINT post_shares_fk_post FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE,
        CONSTRAINT post_shares_fk_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        INDEX post_shares_user_id (user_id)
      )`,
      `CREATE TABLE IF NOT EXISTS post_comments (
        id VARCHAR(12) NOT NULL PRIMARY KEY,
        post_id VARCHAR(12) NOT NULL,
        user_id VARCHAR(12) NOT NULL,
        content TEXT NOT NULL,
        parent_comment_id VARCHAR(12) NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        CONSTRAINT post_comments_fk_post FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE,
        CONSTRAINT post_comments_fk_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
        CONSTRAINT post_comments_fk_parent FOREIGN KEY (parent_comment_id) REFERENCES post_comments (id) ON DELETE SET NULL,
        INDEX post_comments_post_id (post_id),
        INDEX post_comments_user_id (user_id)
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
