/**
 * One-time migration script to denormalize author data into existing posts
 * 
 * Run with: node scripts/migrate_posts_denormalize.js
 * 
 * Prerequisites:
 * 1. npm install firebase-admin
 * 2. Download service account key from Firebase Console
 * 3. Set GOOGLE_APPLICATION_CREDENTIALS environment variable
 * 
 * Usage:
 * export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccountKey.json"
 * node scripts/migrate_posts_denormalize.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

const db = admin.firestore();

async function migratePost(postDoc) {
  const data = postDoc.data();
  
  // Skip if already has denormalized data
  if (data.authorName && data.authorAvatarUrl !== undefined) {
    console.log(`⏭️  Skipping ${postDoc.id} - already migrated`);
    return false;
  }
  
  const authorId = data.authorId;
  if (!authorId) {
    console.log(`⚠️  Skipping ${postDoc.id} - no authorId`);
    return false;
  }
  
  try {
    // Fetch author profile
    const userDoc = await db.collection('users').doc(authorId).get();
    if (!userDoc.exists) {
      console.log(`⚠️  Skipping ${postDoc.id} - author ${authorId} not found`);
      return false;
    }
    
    const user = userDoc.data();
    
    // Build author name
    const fn = (user.firstName || '').trim();
    const ln = (user.lastName || '').trim();
    let authorName = '';
    if (fn || ln) {
      authorName = `${fn} ${ln}`.trim();
    } else {
      authorName = user.displayName || user.username || 'User';
    }
    
    const authorAvatarUrl = user.avatarUrl || '';
    
    // Build media thumbs from mediaUrls
    const mediaUrls = data.mediaUrls || [];
    const mediaThumbs = mediaUrls.map(url => {
      const lower = url.toLowerCase();
      const isVideo = lower.includes('.mp4') || lower.includes('.mov') || lower.includes('.webm');
      return {
        type: isVideo ? 'video' : 'image',
        thumbUrl: url,
      };
    });
    
    // Update post with denormalized data
    await postDoc.ref.update({
      authorName,
      authorAvatarUrl,
      mediaThumbs,
    });
    
    console.log(`✅ Migrated ${postDoc.id} - ${authorName}`);
    return true;
  } catch (error) {
    console.error(`❌ Error migrating ${postDoc.id}:`, error.message);
    return false;
  }
}

async function migratePosts() {
  console.log('🚀 Starting post migration...\n');
  
  let migrated = 0;
  let skipped = 0;
  let errors = 0;
  
  // Process posts collection
  console.log('📦 Processing posts collection...');
  const postsSnapshot = await db.collection('posts').get();
  
  for (const doc of postsSnapshot.docs) {
    const result = await migratePost(doc);
    if (result === true) migrated++;
    else if (result === false) skipped++;
    else errors++;
  }
  
  // Process community_posts collection
  console.log('\n📦 Processing community_posts collection...');
  const communityPostsSnapshot = await db.collection('community_posts').get();
  
  for (const doc of communityPostsSnapshot.docs) {
    const result = await migratePost(doc);
    if (result === true) migrated++;
    else if (result === false) skipped++;
    else errors++;
  }
  
  console.log('\n📊 Migration complete!');
  console.log(`   ✅ Migrated: ${migrated}`);
  console.log(`   ⏭️  Skipped: ${skipped}`);
  console.log(`   ❌ Errors: ${errors}`);
}

migratePosts().catch(console.error);
