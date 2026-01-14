import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'web_local_store.dart';

/// Warms the web local cache by prefetching data from Firestore.
/// Called at app start/login to seed Hive with latest data.
class WebCacheWarmer {
  static final WebCacheWarmer _instance = WebCacheWarmer._internal();
  factory WebCacheWarmer() => _instance;
  WebCacheWarmer._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isWarming = false;

  /// Seed limits
  static const int _postsLimit = 100;
  static const int _conversationsLimit = 50;
  static const int _messagesPerConvLimit = 30;
  static const int _podcastsLimit = 50;
  static const int _booksLimit = 50;

  /// Warm the cache with latest data from Firestore
  Future<void> warmCache() async {
    if (_isWarming) {
      _debugLog('⏭️ Cache warming already in progress');
      return;
    }

    if (!webLocalStore.isAvailable) {
      _debugLog('⏭️ WebLocalStore not available, skipping warm');
      return;
    }

    _isWarming = true;
    _debugLog('🔥 Starting cache warm...');

    final stopwatch = Stopwatch()..start();

    try {
      // Warm all modules in parallel
      await Future.wait([
        _warmPosts(),
        _warmProfile(),
        _warmConversations(),
        _warmPodcasts(),
        _warmBooks(),
      ]);

      stopwatch.stop();
      _debugLog('✅ Cache warm complete in ${stopwatch.elapsedMilliseconds}ms');
      _debugLog('📊 Stats: ${webLocalStore.getStats()}');
    } catch (e) {
      _debugLog('❌ Cache warm failed: $e');
    } finally {
      _isWarming = false;
    }
  }

  Future<void> _warmPosts() async {
    try {
      final snapshot = await _db.collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(_postsLimit)
          .get();

      if (snapshot.docs.isEmpty) return;

      final posts = snapshot.docs.map((doc) {
        final data = doc.data();
        return _postToMap(doc.id, data);
      }).toList();

      await webLocalStore.putPosts(posts);
      _debugLog('📝 Warmed ${posts.length} posts');
    } catch (e) {
      _debugLog('⚠️ Failed to warm posts: $e');
    }
  }

  Future<void> _warmProfile() async {
    final userId = fb.FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (!doc.exists) return;

      final data = doc.data();
      if (data == null) return;

      await webLocalStore.putProfile(userId, _profileToMap(userId, data));
      _debugLog('👤 Warmed user profile');
    } catch (e) {
      _debugLog('⚠️ Failed to warm profile: $e');
    }
  }

  Future<void> _warmConversations() async {
    final userId = fb.FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final snapshot = await _db.collection('conversations')
          .where('memberIds', arrayContains: userId)
          .orderBy('lastMessageAt', descending: true)
          .limit(_conversationsLimit)
          .get();

      if (snapshot.docs.isEmpty) return;

      final convs = snapshot.docs.map((doc) {
        final data = doc.data();
        return _conversationToMap(doc.id, data);
      }).toList();

      await webLocalStore.putConversations(convs);
      _debugLog('💬 Warmed ${convs.length} conversations');

      // Warm messages for top conversations
      final topConvIds = convs.take(10).map((c) => c['id'] as String).toList();
      await _warmMessagesForConversations(topConvIds);
    } catch (e) {
      _debugLog('⚠️ Failed to warm conversations: $e');
    }
  }

  Future<void> _warmMessagesForConversations(List<String> convIds) async {
    for (final convId in convIds) {
      try {
        final snapshot = await _db.collection('conversations')
            .doc(convId)
            .collection('messages')
            .orderBy('createdAt', descending: true)
            .limit(_messagesPerConvLimit)
            .get();

        if (snapshot.docs.isEmpty) continue;

        final msgs = snapshot.docs.map((doc) {
          final data = doc.data();
          return _messageToMap(doc.id, convId, data);
        }).toList();

        await webLocalStore.putMessages(msgs);
      } catch (e) {
        _debugLog('⚠️ Failed to warm messages for $convId: $e');
      }
    }
    _debugLog('📨 Warmed messages for ${convIds.length} conversations');
  }

  Future<void> _warmPodcasts() async {
    try {
      final snapshot = await _db.collection('podcasts')
          .where('isPublished', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(_podcastsLimit)
          .get();

      if (snapshot.docs.isEmpty) return;

      final podcasts = snapshot.docs.map((doc) {
        final data = doc.data();
        return _podcastToMap(doc.id, data);
      }).toList();

      await webLocalStore.putPodcasts(podcasts);
      _debugLog('🎙️ Warmed ${podcasts.length} podcasts');
    } catch (e) {
      _debugLog('⚠️ Failed to warm podcasts: $e');
    }
  }

  Future<void> _warmBooks() async {
    try {
      final snapshot = await _db.collection('books')
          .where('isPublished', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(_booksLimit)
          .get();

      if (snapshot.docs.isEmpty) return;

      final books = snapshot.docs.map((doc) {
        final data = doc.data();
        return _bookToMap(doc.id, data);
      }).toList();

      await webLocalStore.putBooks(books);
      _debugLog('📚 Warmed ${books.length} books');
    } catch (e) {
      _debugLog('⚠️ Failed to warm books: $e');
    }
  }

  // ============================================
  // MAP CONVERTERS
  // ============================================

  Map<String, dynamic> _postToMap(String id, Map<String, dynamic> data) {
    return {
      'id': id,
      'authorId': data['authorId'] ?? '',
      'authorName': data['authorName'],
      'authorPhotoUrl': data['authorAvatarUrl'] ?? data['authorPhotoUrl'],
      'caption': data['caption'] ?? data['text'] ?? '',
      'mediaUrls': List<String>.from(data['mediaUrls'] ?? []),
      'mediaThumbUrls': List<String>.from(data['mediaThumbs'] ?? data['mediaThumbUrls'] ?? []),
      'mediaTypes': List<String>.from(data['mediaTypes'] ?? []),
      'communityId': data['communityId'],
      'likeCount': data['likeCount'] ?? data['likes'] ?? 0,
      'commentCount': data['commentCount'] ?? data['comments'] ?? 0,
      'shareCount': data['shareCount'] ?? data['shares'] ?? 0,
      'repostCount': data['repostCount'] ?? data['reposts'] ?? 0,
      'bookmarkCount': data['bookmarkCount'] ?? data['bookmarks'] ?? 0,
      'repostOf': data['repostOf'] ?? data['originalPostId'],
      'createdAt': _timestampToIso(data['createdAt']),
      'updatedAt': _timestampToIso(data['updatedAt']),
    };
  }

  Map<String, dynamic> _profileToMap(String uid, Map<String, dynamic> data) {
    return {
      'uid': uid,
      'displayName': data['displayName'] ?? data['name'] ?? '',
      'photoUrl': data['photoUrl'] ?? data['avatarUrl'] ?? '',
      'bio': data['bio'] ?? '',
      'followerCount': data['followerCount'] ?? data['followers'] ?? 0,
      'followingCount': data['followingCount'] ?? data['following'] ?? 0,
      'postCount': data['postCount'] ?? data['posts'] ?? 0,
      'isVerified': data['isVerified'] ?? false,
    };
  }

  Map<String, dynamic> _conversationToMap(String id, Map<String, dynamic> data) {
    final memberIds = List<String>.from(data['memberIds'] ?? []);
    final currentUserId = fb.FirebaseAuth.instance.currentUser?.uid;
    final otherUserId = memberIds.firstWhere(
      (m) => m != currentUserId,
      orElse: () => '',
    );

    return {
      'id': id,
      'memberIds': memberIds,
      'otherUserId': otherUserId,
      'otherUserName': data['otherUserName'] ?? data['memberNames']?[otherUserId],
      'otherUserPhotoUrl': data['otherUserPhotoUrl'] ?? data['memberPhotos']?[otherUserId],
      'lastMessageText': data['lastMessageText'] ?? data['lastMessage'],
      'lastMessageType': data['lastMessageType'] ?? 'text',
      'lastMessageSenderId': data['lastMessageSenderId'],
      'lastMessageAt': _timestampToIso(data['lastMessageAt']),
      'unreadCount': data['unreadCount'] ?? 0,
      'muted': data['muted'] ?? false,
    };
  }

  Map<String, dynamic> _messageToMap(String id, String conversationId, Map<String, dynamic> data) {
    return {
      'id': id,
      'conversationId': conversationId,
      'senderId': data['senderId'] ?? '',
      'type': data['type'] ?? 'text',
      'text': data['text'] ?? '',
      'mediaUrl': data['mediaUrl'],
      'fileName': data['fileName'],
      'fileSize': data['fileSize'],
      'voiceDurationSeconds': data['voiceDurationSeconds'],
      'isRead': data['isRead'] ?? false,
      'createdAt': _timestampToIso(data['createdAt']),
    };
  }

  Map<String, dynamic> _podcastToMap(String id, Map<String, dynamic> data) {
    return {
      'id': id,
      'title': data['title'] ?? '',
      'author': data['author'],
      'authorId': data['authorId'],
      'coverUrl': data['coverUrl'],
      'coverThumbUrl': data['coverThumbUrl'],
      'audioUrl': data['audioUrl'],
      'durationSeconds': data['durationSeconds'] ?? data['durationSec'],
      'language': data['language'],
      'category': data['category'],
      'description': data['description'],
      'createdAt': _timestampToIso(data['createdAt']),
    };
  }

  Map<String, dynamic> _bookToMap(String id, Map<String, dynamic> data) {
    return {
      'id': id,
      'title': data['title'] ?? '',
      'author': data['author'],
      'description': data['description'],
      'coverUrl': data['coverUrl'],
      'coverThumbUrl': data['coverThumbUrl'],
      'epubUrl': data['epubUrl'],
      'pdfUrl': data['pdfUrl'],
      'audioUrl': data['audioUrl'],
      'language': data['language'],
      'category': data['category'],
      'isPublished': data['isPublished'] ?? false,
      'createdAt': _timestampToIso(data['createdAt']),
    };
  }

  String? _timestampToIso(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return value.toString();
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[WebCacheWarmer] $message');
    }
  }
}
