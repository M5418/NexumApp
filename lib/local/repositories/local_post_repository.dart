import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:isar/isar.dart';
import '../isar_db.dart';
import '../local_store.dart';
import '../models/post_lite.dart';
import '../sync/sync_cursor_store.dart';
import '../web/web_local_store.dart';

/// Local-first repository for Posts.
/// Reads from Isar (mobile) or Hive (web) instantly, syncs with Firestore in background.
class LocalPostRepository {
  static final LocalPostRepository _instance = LocalPostRepository._internal();
  factory LocalPostRepository() => _instance;
  LocalPostRepository._internal();

  final firestore.FirebaseFirestore _db = firestore.FirebaseFirestore.instance;
  final SyncCursorStore _cursorStore = SyncCursorStore();

  static const String _module = 'posts';
  static const int _syncBatchSize = 50;

  /// Watch local posts (instant UI binding)
  Stream<List<PostLite>> watchLocal({
    int limit = 20,
    String? communityId,
  }) {
    final db = isarDB.instance;
    if (db == null) {
      _debugLog('⚠️ Isar not available, returning empty stream');
      return Stream.value([]);
    }

    if (communityId != null) {
      // Filter by community
      return db.postLites
          .filter()
          .communityIdEqualTo(communityId)
          .sortByCreatedAtDesc()
          .limit(limit)
          .watch(fireImmediately: true);
    }

    // All posts (feed)
    return db.postLites
        .where()
        .sortByCreatedAtDesc()
        .limit(limit)
        .watch(fireImmediately: true);
  }

  /// Get local posts synchronously (for initial render)
  /// Uses Isar on mobile, Hive on web
  List<PostLite> getLocalSync({int limit = 20, String? communityId}) {
    // WEB: Use Hive via WebLocalStore
    if (isHiveSupported && webLocalStore.isAvailable) {
      final maps = webLocalStore.getPostsSync(limit: limit, communityId: communityId);
      if (maps.isNotEmpty) {
        _debugLog('🌐 [Web] Loaded ${maps.length} posts from Hive');
        return maps.map((m) => PostLite.fromMap(m)).toList();
      }
    }
    
    // MOBILE: Use Isar
    final db = isarDB.instance;
    if (db == null) return [];

    if (communityId != null) {
      return db.postLites
          .filter()
          .communityIdEqualTo(communityId)
          .sortByCreatedAtDesc()
          .limit(limit)
          .findAllSync();
    }

    return db.postLites
        .where()
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAllSync();
  }

  /// Get a single post by ID
  PostLite? getPostSync(String postId) {
    final db = isarDB.instance;
    if (db == null) return null;

    return db.postLites.filter().idEqualTo(postId).findFirstSync();
  }

  /// Sync remote posts (delta sync)
  Future<void> syncRemote() async {
    if (!isIsarSupported) return;

    final db = isarDB.instance;
    if (db == null) return;

    await _cursorStore.init();

    try {
      final lastSync = _cursorStore.getLastSyncTime(_module);
      _debugLog('🔄 Syncing posts since: $lastSync');

      firestore.QuerySnapshot<Map<String, dynamic>> snapshot;
      
      if (lastSync != null) {
        // Delta sync: fetch only updated docs
        snapshot = await _db.collection('posts')
            .where('updatedAt', isGreaterThan: firestore.Timestamp.fromDate(lastSync))
            .orderBy('updatedAt')
            .limit(_syncBatchSize)
            .get();
      } else {
        // Full sync: fetch by createdAt (backward compatible)
        snapshot = await _db.collection('posts')
            .orderBy('createdAt', descending: true)
            .limit(_syncBatchSize)
            .get();
      }

      if (snapshot.docs.isEmpty) {
        _debugLog('✅ Posts already up to date');
        return;
      }

      final posts = <PostLite>[];
      DateTime? latestUpdate;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final post = PostLite.fromFirestore(doc.id, data);
        posts.add(post);

        final updatedAt = post.updatedAt ?? post.createdAt;
        if (latestUpdate == null || updatedAt.isAfter(latestUpdate)) {
          latestUpdate = updatedAt;
        }
      }

      // Batch upsert to Isar
      await db.writeTxn(() async {
        await db.postLites.putAll(posts);
      });

      // Update cursor
      if (latestUpdate != null) {
        await _cursorStore.setLastSyncTime(_module, latestUpdate);
      }

      _debugLog('✅ Synced ${posts.length} posts');
    } catch (e) {
      _debugLog('❌ Post sync failed: $e');
    }
  }

  /// Optimistic create: write to Isar immediately, queue Firestore write
  Future<PostLite> createPostOptimistic({
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    String? caption,
    List<String>? mediaUrls,
    List<String>? mediaThumbUrls,
    List<String>? mediaTypes,
    String? communityId,
  }) async {
    final db = isarDB.instance;
    if (db == null) {
      throw Exception('Isar not available');
    }

    // Generate client-side ID for idempotency
    final postId = _db.collection('posts').doc().id;

    final post = PostLite()
      ..id = postId
      ..authorId = authorId
      ..authorName = authorName
      ..authorPhotoUrl = authorPhotoUrl
      ..caption = caption
      ..mediaUrls = mediaUrls ?? []
      ..mediaThumbUrls = mediaThumbUrls ?? []
      ..mediaTypes = mediaTypes ?? []
      ..communityId = communityId
      ..createdAt = DateTime.now()
      ..localUpdatedAt = DateTime.now()
      ..syncStatus = 'pending';

    // Write to Isar immediately
    await db.writeTxn(() async {
      await db.postLites.put(post);
    });

    _debugLog('📝 Created optimistic post: $postId');

    // Queue Firestore write (handled by WriteQueue)
    // The caller should enqueue this to WriteQueue

    return post;
  }

  /// Update post sync status after Firestore write
  Future<void> updateSyncStatus(String postId, String status) async {
    final db = isarDB.instance;
    if (db == null) return;

    final post = db.postLites.filter().idEqualTo(postId).findFirstSync();
    if (post == null) return;

    post.syncStatus = status;
    post.localUpdatedAt = DateTime.now();

    await db.writeTxn(() async {
      await db.postLites.put(post);
    });

    _debugLog('📝 Updated post $postId status: $status');
  }

  /// Update post counts locally (optimistic)
  Future<void> updateCountsOptimistic(
    String postId, {
    int? likeCount,
    int? commentCount,
    int? shareCount,
    int? bookmarkCount,
  }) async {
    final db = isarDB.instance;
    if (db == null) return;

    final post = db.postLites.filter().idEqualTo(postId).findFirstSync();
    if (post == null) return;

    if (likeCount != null) post.likeCount = likeCount;
    if (commentCount != null) post.commentCount = commentCount;
    if (shareCount != null) post.shareCount = shareCount;
    if (bookmarkCount != null) post.bookmarkCount = bookmarkCount;
    post.localUpdatedAt = DateTime.now();

    await db.writeTxn(() async {
      await db.postLites.put(post);
    });
  }

  /// Delete post locally
  Future<void> deleteLocal(String postId) async {
    final db = isarDB.instance;
    if (db == null) return;

    await db.writeTxn(() async {
      await db.postLites.filter().idEqualTo(postId).deleteFirst();
    });

    _debugLog('🗑️ Deleted local post: $postId');
  }

  /// Get pending posts (for retry/outbox display)
  List<PostLite> getPendingPosts() {
    final db = isarDB.instance;
    if (db == null) return [];

    return db.postLites
        .filter()
        .syncStatusEqualTo('pending')
        .or()
        .syncStatusEqualTo('failed')
        .findAllSync();
  }

  /// Get post count
  int getLocalCount() {
    final db = isarDB.instance;
    if (db == null) return 0;
    return db.postLites.countSync();
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[LocalPostRepo] $message');
    }
  }
}
