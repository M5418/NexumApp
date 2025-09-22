import 'dotenv/config';
import mysql from 'mysql2/promise';

async function checkPosts() {
  let conn;
  try {
    conn = await mysql.createConnection(process.env.DATABASE_URL);
    console.log('Connected to database');

    // Check posts
    const [posts] = await conn.query('SELECT * FROM posts ORDER BY created_at DESC');
    console.log(`\n📊 Found ${posts.length} posts:`);
    
    posts.forEach((post, i) => {
      console.log(`\nPost ${i + 1}:`);
      console.log(`  ID: ${post.id}`);
      console.log(`  User ID: ${post.user_id}`);
      console.log(`  Content: ${post.content?.substring(0, 100)}...`);
      console.log(`  Post Type: ${post.post_type}`);
      console.log(`  Image URL: ${post.image_url}`);
      console.log(`  Image URLs: ${post.image_urls}`);
      console.log(`  Video URL: ${post.video_url}`);
      console.log(`  Liked By: ${post.liked_by}`);
      console.log(`  Likes Count: ${post.likes_count}`);
      console.log(`  Created: ${post.created_at}`);
    });

    // Check profiles
    const [profiles] = await conn.query('SELECT user_id, first_name, last_name, username FROM profiles');
    console.log(`\n👤 Found ${profiles.length} profiles:`);
    
    profiles.forEach((profile, i) => {
      console.log(`\nProfile ${i + 1}:`);
      console.log(`  User ID: ${profile.user_id}`);
      console.log(`  Name: ${profile.first_name} ${profile.last_name}`);
      console.log(`  Username: ${profile.username}`);
    });

  } catch (error) {
    console.error('❌ Error:', error);
  } finally {
    if (conn) await conn.end();
  }
}

checkPosts();
