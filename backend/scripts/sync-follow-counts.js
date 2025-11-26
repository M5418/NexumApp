/**
 * Sync follower/following counts for all users
 * Run this script once to initialize counts for existing users
 * 
 * SETUP:
 * 1. Download service account key from Firebase Console:
 *    Project Settings > Service Accounts > Generate New Private Key
 * 2. Save as backend/firebase-admin-key.json (gitignored)
 * 3. Run: node scripts/sync-follow-counts.js
 * 
 * OR: The counts will sync naturally as users follow/unfollow.
 *     New follows will initialize counts automatically.
 */

import admin from 'firebase-admin';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Initialize Firebase Admin
if (!admin.apps.length) {
  try {
    // Try to load service account key
    const serviceAccount = JSON.parse(
      readFileSync(join(__dirname, '../firebase-admin-key.json'), 'utf8')
    );
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    console.log('✅ Firebase Admin initialized with service account');
  } catch (error) {
    console.error('❌ Could not load firebase-admin-key.json');
    console.error('💡 Please download your service account key from:');
    console.error('   Firebase Console > Project Settings > Service Accounts');
    console.error('   Save it as: backend/firebase-admin-key.json');
    console.error('');
    console.error('📝 Note: Counts will sync automatically as users follow/unfollow.');
    console.error('   This script is optional for initializing existing users.');
    process.exit(1);
  }
}

const db = admin.firestore();

async function syncFollowCounts() {
  console.log('🔄 Starting follow counts sync...');
  
  try {
    // Get all users
    const usersSnapshot = await db.collection('users').get();
    console.log(`📊 Found ${usersSnapshot.size} users`);
    
    // Get all follow relationships
    const followsSnapshot = await db.collection('follows').get();
    console.log(`📊 Found ${followsSnapshot.size} follow relationships`);
    
    // Build count maps
    const followerCounts = {}; // userId -> count of people following them
    const followingCounts = {}; // userId -> count of people they follow
    
    followsSnapshot.forEach(doc => {
      const data = doc.data();
      const followerId = data.followerId;
      const followedId = data.followedId;
      
      // Increment follower count for followedId
      followerCounts[followedId] = (followerCounts[followedId] || 0) + 1;
      
      // Increment following count for followerId
      followingCounts[followerId] = (followingCounts[followerId] || 0) + 1;
    });
    
    console.log('📝 Updating user documents...');
    
    // Update all users with their counts
    const batch = db.batch();
    let updateCount = 0;
    
    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const followersCount = followerCounts[userId] || 0;
      const followingCount = followingCounts[userId] || 0;
      
      batch.set(userDoc.ref, {
        followersCount,
        followingCount,
      }, { merge: true });
      
      updateCount++;
      
      // Commit batch every 500 operations
      if (updateCount % 500 === 0) {
        await batch.commit();
        console.log(`✅ Updated ${updateCount} users...`);
      }
    }
    
    // Commit remaining operations
    if (updateCount % 500 !== 0) {
      await batch.commit();
    }
    
    console.log(`✅ Successfully updated ${updateCount} users`);
    console.log('🎉 Follow counts sync completed!');
    
  } catch (error) {
    console.error('❌ Error syncing follow counts:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

// Run the sync
syncFollowCounts();
