import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/interest_domains.dart';

/// Service to sync user interests with community memberships
/// Each interest domain has its own community
class CommunityInterestSyncService {
  static final CommunityInterestSyncService _instance = CommunityInterestSyncService._internal();
  factory CommunityInterestSyncService() => _instance;
  CommunityInterestSyncService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Ensure all interest-based communities exist in Firestore
  /// Call this once on app initialization or first run
  Future<void> initializeInterestCommunities() async {
    print('🏘️  Initializing interest-based communities...');
    
    final batch = _db.batch();
    int created = 0;
    int existing = 0;

    for (final interest in interestDomains) {
      final communityId = _getCommunityIdForInterest(interest);
      final communityRef = _db.collection('communities').doc(communityId);
      
      // Check if community already exists
      final snapshot = await communityRef.get();
      
      if (!snapshot.exists) {
        // Create community for this interest
        batch.set(communityRef, {
          'name': interest,
          'bio': 'A community for $interest enthusiasts',
          'avatarUrl': '', // You can add default avatars later
          'coverUrl': '',
          'interestDomain': interest, // Link back to interest
          'memberCount': 0,
          'postsCount': 0,
          'unreadPosts': 0,
          'friendsInCommon': '+0',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        created++;
      } else {
        existing++;
      }
    }

    if (created > 0) {
      await batch.commit();
      print('✅ Created $created new communities');
    }
    
    print('✅ Interest communities initialized: $created created, $existing existing');
  }

  /// Sync user's interests with community memberships
  /// - Add memberships for new interests
  /// - Remove memberships for removed interests
  Future<void> syncUserInterests(List<String> newInterests) async {
    final user = _auth.currentUser;
    if (user == null) {
      print('⚠️  No authenticated user for community sync');
      return;
    }

    // CRITICAL: Ensure communities exist before syncing memberships
    await initializeInterestCommunities();

    print('🔄 Syncing interests to communities for user ${user.uid}');
    print('   New interests: ${newInterests.length} items');

    // Get user's current interests from Firestore (to find what changed)
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final currentInterests = List<String>.from(userDoc.data()?['interest_domains'] ?? []);
    
    print('   Current interests: ${currentInterests.length} items');

    // Find interests to add and remove
    final interestsToAdd = newInterests.where((i) => !currentInterests.contains(i)).toList();
    final interestsToRemove = currentInterests.where((i) => !newInterests.contains(i)).toList();

    print('   To add: ${interestsToAdd.length}');
    print('   To remove: ${interestsToRemove.length}');

    final batch = _db.batch();

    // Add user to new communities
    for (final interest in interestsToAdd) {
      final communityId = _getCommunityIdForInterest(interest);
      final memberRef = _db
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(user.uid);

      batch.set(memberRef, {
        'userId': user.uid,
        'uid': user.uid, // Both fields for backward compatibility
        'displayName': user.displayName ?? user.email ?? 'User',
        'email': user.email,
        'avatarUrl': user.photoURL ?? '',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // Increment member count (use set with merge to handle edge cases)
      final communityRef = _db.collection('communities').doc(communityId);
      batch.set(communityRef, {
        'memberCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('   ➕ Adding to: $interest');
    }

    // Remove user from old communities
    for (final interest in interestsToRemove) {
      final communityId = _getCommunityIdForInterest(interest);
      final memberRef = _db
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(user.uid);

      batch.delete(memberRef);

      // Decrement member count (use set with merge)
      final communityRef = _db.collection('communities').doc(communityId);
      batch.set(communityRef, {
        'memberCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      print('   ➖ Removing from: $interest');
    }

    if (interestsToAdd.isNotEmpty || interestsToRemove.isNotEmpty) {
      try {
        await batch.commit();
        print('✅ Community memberships synced successfully');
        
        // Verify memberships were created
        for (final interest in interestsToAdd) {
          final communityId = _getCommunityIdForInterest(interest);
          final memberDoc = await _db
              .collection('communities')
              .doc(communityId)
              .collection('members')
              .doc(user.uid)
              .get();
          
          if (memberDoc.exists) {
            print('   ✅ Verified membership: $interest');
          } else {
            print('   ⚠️  Membership not found after sync: $interest');
          }
        }
      } catch (e) {
        print('❌ Failed to sync communities: $e');
        rethrow;
      }
    } else {
      print('ℹ️  No changes to community memberships');
    }
  }

  /// Convert interest name to a safe community ID
  String _getCommunityIdForInterest(String interest) {
    // Create a consistent, URL-safe ID from the interest name
    return interest
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), ''); // Remove leading/trailing dashes
  }

  /// Get community ID for a given interest (public helper)
  String getCommunityIdForInterest(String interest) {
    return _getCommunityIdForInterest(interest);
  }
}
