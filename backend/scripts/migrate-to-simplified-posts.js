import 'dotenv/config';
import mysql from 'mysql2/promise';

async function migrateToSimplifiedPosts() {
  let conn;
  try {
    conn = await mysql.createConnection(process.env.DATABASE_URL);
    console.log('Connected to database');

    // Step 1: Check which tables exist
    console.log('🔍 Checking existing tables...');
    const [tables] = await conn.query("SHOW TABLES");
    const tableNames = tables.map(t => Object.values(t)[0]);
    
    const hasPostMedia = tableNames.includes('post_media');
    const hasPostLikes = tableNames.includes('post_likes');
    const hasPostBookmarks = tableNames.includes('post_bookmarks');
    const hasPostShares = tableNames.includes('post_shares');
    const hasPostComments = tableNames.includes('post_comments');
    
    console.log('Existing tables:', {
      post_media: hasPostMedia,
      post_likes: hasPostLikes,
      post_bookmarks: hasPostBookmarks,
      post_shares: hasPostShares,
      post_comments: hasPostComments
    });

    // Step 2: Backup existing posts data
    console.log('📦 Backing up existing posts data...');
    
    // Build dynamic query based on existing tables
    let selectQuery = 'SELECT p.*';
    let fromQuery = 'FROM posts p';
    let groupByQuery = 'GROUP BY p.id';
    
    if (hasPostMedia) {
      selectQuery += ', GROUP_CONCAT(DISTINCT pm.media_type) as media_types, GROUP_CONCAT(DISTINCT pm.url) as media_urls';
      fromQuery += ' LEFT JOIN post_media pm ON p.id = pm.post_id';
    } else {
      selectQuery += ', NULL as media_types, NULL as media_urls';
    }
    
    if (hasPostLikes) {
      selectQuery += ', GROUP_CONCAT(DISTINCT pl.user_id) as liked_by_users, COUNT(DISTINCT pl.user_id) as likes_count';
      fromQuery += ' LEFT JOIN post_likes pl ON p.id = pl.post_id';
    } else {
      selectQuery += ', NULL as liked_by_users, 0 as likes_count';
    }
    
    if (hasPostBookmarks) {
      selectQuery += ', GROUP_CONCAT(DISTINCT pb.user_id) as bookmarked_by_users, COUNT(DISTINCT pb.user_id) as bookmarks_count';
      fromQuery += ' LEFT JOIN post_bookmarks pb ON p.id = pb.post_id';
    } else {
      selectQuery += ', NULL as bookmarked_by_users, 0 as bookmarks_count';
    }
    
    if (hasPostShares) {
      selectQuery += ', GROUP_CONCAT(DISTINCT ps.user_id) as shared_by_users, COUNT(DISTINCT ps.user_id) as shares_count';
      fromQuery += ' LEFT JOIN post_shares ps ON p.id = ps.post_id';
    } else {
      selectQuery += ', NULL as shared_by_users, 0 as shares_count';
    }
    
    if (hasPostComments) {
      selectQuery += ', COUNT(DISTINCT pc.id) as comments_count';
      fromQuery += ' LEFT JOIN post_comments pc ON p.id = pc.post_id';
    } else {
      selectQuery += ', 0 as comments_count';
    }

    const fullQuery = `${selectQuery} ${fromQuery} ${groupByQuery}`;
    console.log('Executing query:', fullQuery);
    
    const [existingPosts] = await conn.query(fullQuery);
    console.log(`Found ${existingPosts.length} posts to migrate`);

    // Step 2.5: Backup comments data if it exists
    let existingComments = [];
    if (hasPostComments) {
      console.log('📦 Backing up comments data...');
      const [comments] = await conn.query('SELECT * FROM post_comments');
      existingComments = comments;
      console.log(`Found ${existingComments.length} comments to migrate`);
    }

    // Step 3: Apply new schema
    console.log('🔄 Applying new schema...');
    
    // Disable foreign key checks temporarily
    await conn.query('SET FOREIGN_KEY_CHECKS = 0');
    
    // Drop interaction tables if they exist
    if (hasPostLikes) await conn.query('DROP TABLE IF EXISTS post_likes');
    if (hasPostBookmarks) await conn.query('DROP TABLE IF EXISTS post_bookmarks');
    if (hasPostShares) await conn.query('DROP TABLE IF EXISTS post_shares');
    if (hasPostMedia) await conn.query('DROP TABLE IF EXISTS post_media');
    
    // Drop comments table if it exists (we'll recreate it)
    if (hasPostComments) await conn.query('DROP TABLE IF EXISTS post_comments');

    // Drop and recreate posts table
    await conn.query('DROP TABLE IF EXISTS posts');
    await conn.query(`
      CREATE TABLE posts (
        id VARCHAR(12) NOT NULL PRIMARY KEY,
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
      )
    `);

    // Recreate post_comments table with new schema
    await conn.query(`
      CREATE TABLE post_comments (
        id VARCHAR(12) NOT NULL PRIMARY KEY,
        post_id VARCHAR(12) NOT NULL,
        user_id VARCHAR(12) NOT NULL,
        content TEXT NOT NULL,
        liked_by JSON NULL,
        likes_count INT DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        
        -- Foreign keys
        CONSTRAINT post_comments_fk_post FOREIGN KEY (post_id) REFERENCES posts (id) ON DELETE CASCADE,
        CONSTRAINT post_comments_fk_user FOREIGN KEY (user_id) REFERENCES users (id),
        
        -- Indexes
        INDEX post_comments_post_id (post_id),
        INDEX post_comments_user_id (user_id),
        INDEX post_comments_created_at (created_at)
      )
    `);

    // Re-enable foreign key checks
    await conn.query('SET FOREIGN_KEY_CHECKS = 1');

    console.log('✅ New schema applied');

    // Step 4: Migrate posts data
    console.log('📊 Migrating posts data...');
    
    for (const post of existingPosts) {
      // Determine post type and media
      let postType = 'text';
      let imageUrl = null;
      let imageUrls = null;
      let videoUrl = null;

      if (post.media_types && post.media_urls) {
        const types = post.media_types.split(',');
        const urls = post.media_urls.split(',');
        
        if (types.includes('video')) {
          postType = 'text_video';
          videoUrl = urls.find((url, i) => types[i] === 'video');
        } else if (types.includes('image')) {
          const imageUrlsList = urls.filter((url, i) => types[i] === 'image');
          if (imageUrlsList.length > 1) {
            postType = 'text_photo';
            imageUrls = JSON.stringify(imageUrlsList);
          } else if (imageUrlsList.length === 1) {
            postType = 'text_photo';
            imageUrl = imageUrlsList[0];
          }
        }
      }

      // Prepare interaction arrays
      const likedBy = post.liked_by_users ? 
        JSON.stringify(post.liked_by_users.split(',').filter(Boolean)) : 
        JSON.stringify([]);
      
      const bookmarkedBy = post.bookmarked_by_users ? 
        JSON.stringify(post.bookmarked_by_users.split(',').filter(Boolean)) : 
        JSON.stringify([]);
      
      const sharedBy = post.shared_by_users ? 
        JSON.stringify(post.shared_by_users.split(',').filter(Boolean)) : 
        JSON.stringify([]);

      // Insert migrated post
      await conn.query(`
        INSERT INTO posts (
          id, user_id, post_type, content, image_url, image_urls, video_url,
          liked_by, shared_by, bookmarked_by, reposted_by,
          likes_count, shares_count, bookmarks_count, reposts_count, comments_count,
          repost_of, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `, [
        post.id,
        post.user_id,
        postType,
        post.content,
        imageUrl,
        imageUrls,
        videoUrl,
        likedBy,
        sharedBy,
        bookmarkedBy,
        JSON.stringify([]), // reposted_by - empty for now
        post.likes_count || 0,
        post.shares_count || 0,
        post.bookmarks_count || 0,
        0, // reposts_count
        post.comments_count || 0,
        post.repost_of,
        post.created_at,
        post.updated_at
      ]);
    }

    console.log(`✅ Migrated ${existingPosts.length} posts`);

    // Step 5: Migrate comments data
    if (existingComments.length > 0) {
      console.log('📊 Migrating comments data...');
      
      for (const comment of existingComments) {
        await conn.query(`
          INSERT INTO post_comments (
            id, post_id, user_id, content, liked_by, likes_count, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `, [
          comment.id,
          comment.post_id,
          comment.user_id,
          comment.content,
          JSON.stringify([]), // liked_by - empty for now
          0, // likes_count
          comment.created_at,
          comment.updated_at
        ]);
      }
      
      console.log(`✅ Migrated ${existingComments.length} comments`);
    }

    console.log('\n🎉 Migration completed successfully!');
    console.log('\nNext steps:');
    console.log('1. Run: npx prisma db pull && npm run prisma:generate');
    console.log('2. Update server.js to use the new posts-simplified.js route');
    console.log('3. Update Flutter PostsApi to work with new schema');

  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  } finally {
    if (conn) await conn.end();
  }
}

migrateToSimplifiedPosts();
