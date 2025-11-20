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
  /// Call this ONCE on app initialization - creates ALL communities upfront
  Future<void> initializeInterestCommunities() async {
    // Check if ALL expected communities exist
    final existingCommunitiesSnapshot = await _db.collection('communities').get();
    final existingCount = existingCommunitiesSnapshot.docs.length;
    
    if (existingCount >= interestDomains.length) {
      return; // All communities already created, skip
    }
    
    final batch = _db.batch();

    for (final interest in interestDomains) {
      final communityId = _getCommunityIdForInterest(interest);
      final communityRef = _db.collection('communities').doc(communityId);
      
      // Create community for this interest (set, not update - ensures it's created)
      batch.set(communityRef, {
        'name': interest,
        'bio': 'A community for $interest enthusiasts. Connect with like-minded people, share ideas, and discover new content.',
        'avatarUrl': '',
        'coverUrl': '',
        'interestDomain': interest,
        'memberCount': 0,
        'postsCount': 0,
        'unreadPosts': 0,
        'friendsInCommon': '+0',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // Merge to avoid overwriting if exists
    }

    await batch.commit();
  }

  /// Sync user's interests with community memberships
  /// - Add memberships for new interests (JOIN existing communities)
  /// - Remove memberships for removed interests (LEAVE existing communities)
  /// NOTE: This must be called BEFORE updating the user profile!
  /// Pass both old and new interests to properly detect changes.
  Future<void> syncUserInterests(List<String> newInterests, {List<String>? oldInterests}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    // Get current interests from parameter or fetch from Firestore
    List<String> currentInterests = oldInterests ?? [];
    
    if (currentInterests.isEmpty) {
      // Fetch from Firestore if not provided
      final userDoc = await _db.collection('users').doc(user.uid).get();
      final userData = userDoc.data();
      
      if (userData != null) {
        if (userData.containsKey('interest_domains')) {
          currentInterests = List<String>.from(userData['interest_domains'] ?? []);
        } else if (userData.containsKey('interestDomains')) {
          currentInterests = List<String>.from(userData['interestDomains'] ?? []);
        }
      }
    }
    
    // Find interests to add and remove
    final interestsToAdd = newInterests.where((i) => !currentInterests.contains(i)).toList();
    final interestsToRemove = currentInterests.where((i) => !newInterests.contains(i)).toList();

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
    }

    if (interestsToAdd.isNotEmpty || interestsToRemove.isNotEmpty) {
      try {
        await batch.commit();
      } catch (e) {
        rethrow;
      }
    }
  }

  /// Convert interest name to community ID (lowercase with hyphens)
  /// Must handle special characters properly for Firestore document IDs
  String _getCommunityIdForInterest(String interest) {
    return interest
        .toLowerCase()
        .replaceAll(' & ', '-and-')  // "Arts & Culture" → "arts-and-culture"
        .replaceAll('&', '-and-')    // Handle standalone &
        .replaceAll('/', '-')         // "UI/UX" → "ui-ux" (critical for Firestore!)
        .replaceAll(' ', '-')         // Spaces to hyphens
        .replaceAll('(', '')          // Remove parentheses
        .replaceAll(')', '')
        .replaceAll(',', '')          // Remove commas
        .replaceAll("'", '')          // Remove apostrophes
        .replaceAll(RegExp(r'-+'), '-'); // Multiple hyphens → single hyphen
  }

  /// Get community ID for a given interest (public helper)
  String getCommunityIdForInterest(String interest) {
    return _getCommunityIdForInterest(interest);
  }
}
