import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../interfaces/story_repository.dart';

class FirebaseStoryRepository implements StoryRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _stories => _db.collection('stories');
  CollectionReference<Map<String, dynamic>> get _storyRings => _db.collection('story_rings');
  
  StoryModel _storyFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final uid = _auth.currentUser?.uid;
    
    final likes = List<String>.from(d['likes'] ?? []);
    final viewers = List<String>.from(d['viewers'] ?? []);
    
    return StoryModel(
      id: doc.id,
      userId: (d['userId'] ?? '').toString(),
      userName: (d['userName'] ?? '').toString(),
      userAvatar: d['userAvatar']?.toString(),
      mediaType: (d['mediaType'] ?? 'image').toString(),
      mediaUrl: d['mediaUrl']?.toString(),
      textContent: d['textContent']?.toString(),
      backgroundColor: d['backgroundColor']?.toString(),
      audioUrl: d['audioUrl']?.toString(),
      audioTitle: d['audioTitle']?.toString(),
      thumbnailUrl: d['thumbnailUrl']?.toString(),
      durationSec: (d['durationSec'] ?? 5).toInt(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (d['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(hours: 24)),
      viewed: uid != null && viewers.contains(uid),
      viewsCount: viewers.length,
      liked: uid != null && likes.contains(uid),
      likesCount: likes.length,
      commentsCount: (d['commentsCount'] ?? 0).toInt(),
      viewerIds: viewers,
      mentionedUserIds: List<String>.from(d['mentionedUserIds'] ?? []),
    );
  }

  @override
  Future<String> createStory({
    required String mediaType,
    String? mediaUrl,
    String? textContent,
    String? backgroundColor,
    String? audioUrl,
    String? audioTitle,
    String? thumbnailUrl,
    int durationSec = 5,
    List<String>? mentionedUserIds,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');
    
    // Get user data
    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    
    final now = DateTime.now();
    final data = {
      'userId': uid,
      'userName': userData['displayName'] ?? userData['username'] ?? 'User',
      'userAvatar': userData['avatarUrl'],
      'mediaType': mediaType,
      'mediaUrl': mediaUrl,
      'textContent': textContent,
      'backgroundColor': backgroundColor,
      'audioUrl': audioUrl,
      'audioTitle': audioTitle,
      'thumbnailUrl': thumbnailUrl,
      'durationSec': durationSec,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 24))),
      'viewers': [],
      'likes': [],
      'commentsCount': 0,
      'mentionedUserIds': mentionedUserIds ?? [],
    };
    
    final ref = await _stories.add(data);
    
    // Update or create story ring
    await _updateStoryRing(uid);
    
    return ref.id;
  }

  Future<void> _updateStoryRing(String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    final userData = userDoc.data() ?? {};
    
    // Get active stories count
    final now = DateTime.now();
    final activeStories = await _stories
        .where('userId', isEqualTo: userId)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('expiresAt')
        .orderBy('createdAt', descending: true)
        .get();
    
    if (activeStories.docs.isEmpty) {
      // Remove ring if no active stories
      await _storyRings.doc(userId).delete();
      return;
    }
    
    final lastStory = activeStories.docs.first.data();
    
    await _storyRings.doc(userId).set({
      'userId': userId,
      'userName': userData['displayName'] ?? userData['username'] ?? 'User',
      'userAvatar': userData['avatarUrl'],
      'lastStoryAt': lastStory['createdAt'],
      'thumbnailUrl': lastStory['thumbnailUrl'] ?? lastStory['mediaUrl'],
      'storyCount': activeStories.docs.length,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> deleteStory(String storyId) async {
    final doc = await _stories.doc(storyId).get();
    if (!doc.exists) return;
    
    final userId = doc.data()!['userId'].toString();
    
    await _stories.doc(storyId).delete();
    await _updateStoryRing(userId);
  }

  @override
  Future<List<StoryRingModel>> getStoryRings() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    
    // Get rings from followed users and self
    final snap = await _storyRings
        .orderBy('lastStoryAt', descending: true)
        .limit(50)
        .get();
    
    final rings = <StoryRingModel>[];
    
    for (final ringDoc in snap.docs) {
      final d = ringDoc.data();
      final userId = d['userId'].toString();
      
      // Get stories for this user
      final now = DateTime.now();
      final stories = await _stories
          .where('userId', isEqualTo: userId)
          .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
          .orderBy('expiresAt')
          .orderBy('createdAt', descending: true)
          .get();
      
      if (stories.docs.isNotEmpty) {
        final storyModels = stories.docs.map(_storyFromDoc).toList();
        
        rings.add(StoryRingModel(
          userId: userId,
          userName: (d['userName'] ?? '').toString(),
          userAvatar: d['userAvatar']?.toString(),
          hasUnseen: storyModels.any((s) => !s.viewed),
          lastStoryAt: (d['lastStoryAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          thumbnailUrl: d['thumbnailUrl']?.toString(),
          storyCount: storyModels.length,
          stories: storyModels,
        ));
      }
    }
    
    return rings;
  }

  @override
  Future<List<StoryModel>> getUserStories(String userId) async {
    final now = DateTime.now();
    final snap = await _stories
        .where('userId', isEqualTo: userId)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('expiresAt')
        .orderBy('createdAt', descending: true)
        .get();
    
    return snap.docs.map(_storyFromDoc).toList();
  }

  @override
  Future<List<StoryModel>> getMyStories() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    
    return getUserStories(uid);
  }

  @override
  Future<StoryModel?> getStory(String storyId) async {
    final doc = await _stories.doc(storyId).get();
    if (!doc.exists) return null;
    
    return _storyFromDoc(doc);
  }

  @override
  Future<void> viewStory(String storyId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _stories.doc(storyId).update({
      'viewers': FieldValue.arrayUnion([uid]),
    });
  }

  @override
  Future<void> likeStory(String storyId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _stories.doc(storyId).update({
      'likes': FieldValue.arrayUnion([uid]),
    });
  }

  @override
  Future<void> unlikeStory(String storyId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _stories.doc(storyId).update({
      'likes': FieldValue.arrayRemove([uid]),
    });
  }

  @override
  Future<void> reactToStory(String storyId, String reaction) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _stories.doc(storyId).collection('reactions').doc(uid).set({
      'userId': uid,
      'reaction': reaction,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> replyToStory({
    required String storyId,
    required String message,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    // Get user data
    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    
    await _stories.doc(storyId).collection('replies').add({
      'storyId': storyId,
      'userId': uid,
      'userName': userData['displayName'] ?? userData['username'] ?? 'User',
      'userAvatar': userData['avatarUrl'],
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Increment comment count
    await _stories.doc(storyId).update({
      'commentsCount': FieldValue.increment(1),
    });
  }

  @override
  Future<List<StoryReplyModel>> getStoryReplies(String storyId) async {
    final snap = await _stories
        .doc(storyId)
        .collection('replies')
        .orderBy('createdAt', descending: true)
        .get();
    
    return snap.docs.map((doc) {
      final d = doc.data();
      return StoryReplyModel(
        id: doc.id,
        storyId: storyId,
        userId: (d['userId'] ?? '').toString(),
        userName: (d['userName'] ?? '').toString(),
        userAvatar: d['userAvatar']?.toString(),
        message: (d['message'] ?? '').toString(),
        createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    }).toList();
  }

  @override
  Future<List<StoryViewerModel>> getStoryViewers(String storyId) async {
    final doc = await _stories.doc(storyId).get();
    if (!doc.exists) return [];
    
    final viewerIds = List<String>.from(doc.data()!['viewers'] ?? []);
    final viewers = <StoryViewerModel>[];
    
    for (final viewerId in viewerIds) {
      final userDoc = await _db.collection('users').doc(viewerId).get();
      if (userDoc.exists) {
        final userData = userDoc.data()!;
        
        // Check if liked
        final likes = List<String>.from(doc.data()!['likes'] ?? []);
        
        viewers.add(StoryViewerModel(
          userId: viewerId,
          userName: (userData['displayName'] ?? userData['username'] ?? 'User').toString(),
          userAvatar: userData['avatarUrl']?.toString(),
          viewedAt: DateTime.now(), // Simplified - would track actual view time
          liked: likes.contains(viewerId),
          reaction: null, // Would fetch from reactions subcollection
        ));
      }
    }
    
    return viewers;
  }

  @override
  Future<void> muteUserStories(String userId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _db.collection('user_settings').doc(uid).set({
      'mutedStories': FieldValue.arrayUnion([userId]),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> unmuteUserStories(String userId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _db.collection('user_settings').doc(uid).set({
      'mutedStories': FieldValue.arrayRemove([userId]),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> hideStory(String storyId, String userId) async {
    await _stories.doc(storyId).update({
      'hiddenFrom': FieldValue.arrayUnion([userId]),
    });
  }

  @override
  Future<List<StoryModel>> getArchivedStories() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    
    final snap = await _stories
        .where('userId', isEqualTo: uid)
        .where('archived', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    
    return snap.docs.map(_storyFromDoc).toList();
  }

  @override
  Future<void> archiveStory(String storyId) async {
    await _stories.doc(storyId).update({
      'archived': true,
      'archivedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> unarchiveStory(String storyId) async {
    await _stories.doc(storyId).update({
      'archived': false,
      'archivedAt': null,
    });
  }

  @override
  Future<void> addToHighlight(String storyId, String highlightId) async {
    await _db.collection('highlights').doc(highlightId).update({
      'storyIds': FieldValue.arrayUnion([storyId]),
    });
  }

  @override
  Future<void> removeFromHighlight(String storyId, String highlightId) async {
    await _db.collection('highlights').doc(highlightId).update({
      'storyIds': FieldValue.arrayRemove([storyId]),
    });
  }

  @override
  Future<void> cleanupExpiredStories() async {
    final now = DateTime.now();
    final expired = await _stories
        .where('expiresAt', isLessThan: Timestamp.fromDate(now))
        .get();
    
    final batch = _db.batch();
    final userIdsToUpdate = <String>{};
    
    for (final doc in expired.docs) {
      batch.delete(doc.reference);
      userIdsToUpdate.add(doc.data()['userId'].toString());
    }
    
    await batch.commit();
    
    // Update story rings for affected users
    for (final userId in userIdsToUpdate) {
      await _updateStoryRing(userId);
    }
  }

  // Streams
  @override
  Stream<List<StoryRingModel>> storyRingsStream() {
    return _storyRings
        .orderBy('lastStoryAt', descending: true)
        .limit(50)
        .snapshots()
        .asyncMap((snap) async {
      final rings = <StoryRingModel>[];
      
      for (final ringDoc in snap.docs) {
        final d = ringDoc.data();
        final userId = d['userId'].toString();
        
        // Get stories for this user
        final now = DateTime.now();
        final stories = await _stories
            .where('userId', isEqualTo: userId)
            .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
            .orderBy('expiresAt')
            .orderBy('createdAt', descending: true)
            .get();
        
        if (stories.docs.isNotEmpty) {
          final storyModels = stories.docs.map(_storyFromDoc).toList();
          
          rings.add(StoryRingModel(
            userId: userId,
            userName: (d['userName'] ?? '').toString(),
            userAvatar: d['userAvatar']?.toString(),
            hasUnseen: storyModels.any((s) => !s.viewed),
            lastStoryAt: (d['lastStoryAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            thumbnailUrl: d['thumbnailUrl']?.toString(),
            storyCount: storyModels.length,
            stories: storyModels,
          ));
        }
      }
      
      return rings;
    });
  }

  @override
  Stream<List<StoryModel>> userStoriesStream(String userId) {
    final now = DateTime.now();
    return _stories
        .where('userId', isEqualTo: userId)
        .where('expiresAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('expiresAt')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_storyFromDoc).toList());
  }

  @override
  Stream<List<StoryViewerModel>> storyViewersStream(String storyId) {
    return _stories.doc(storyId).snapshots().asyncMap((doc) async {
      if (!doc.exists) return [];
      
      final viewerIds = List<String>.from(doc.data()!['viewers'] ?? []);
      final viewers = <StoryViewerModel>[];
      
      for (final viewerId in viewerIds) {
        final userDoc = await _db.collection('users').doc(viewerId).get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          final likes = List<String>.from(doc.data()!['likes'] ?? []);
          
          viewers.add(StoryViewerModel(
            userId: viewerId,
            userName: (userData['displayName'] ?? userData['username'] ?? 'User').toString(),
            userAvatar: userData['avatarUrl']?.toString(),
            viewedAt: DateTime.now(),
            liked: likes.contains(viewerId),
            reaction: null,
          ));
        }
      }
      
      return viewers;
    });
  }

  @override
  Stream<List<StoryReplyModel>> storyRepliesStream(String storyId) {
    return _stories
        .doc(storyId)
        .collection('replies')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              return StoryReplyModel(
                id: doc.id,
                storyId: storyId,
                userId: (d['userId'] ?? '').toString(),
                userName: (d['userName'] ?? '').toString(),
                userAvatar: d['userAvatar']?.toString(),
                message: (d['message'] ?? '').toString(),
                createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              );
            }).toList());
  }
}
