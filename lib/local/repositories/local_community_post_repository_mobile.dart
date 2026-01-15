import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:isar/isar.dart';
import '../isar_db.dart';
import '../local_store.dart';
import '../models/community_post_lite.dart';
import '../sync/sync_cursor_store.dart';

export '../models/community_post_lite.dart';

/// Local-first repository for Community Posts.
class LocalCommunityPostRepository {
  static final LocalCommunityPostRepository _instance = LocalCommunityPostRepository._internal();
  factory LocalCommunityPostRepository() => _instance;
  LocalCommunityPostRepository._internal();

  final firestore.FirebaseFirestore _db = firestore.FirebaseFirestore.instance;
  final SyncCursorStore _cursorStore = SyncCursorStore();

  static const String _module = 'community_posts';
  static const int _syncBatchSize = 50;

  /// Watch local community posts (instant UI binding)
  Stream<List<CommunityPostLite>> watchLocal(String communityId, {int limit = 20}) {
    final db = isarDB.instance;
    if (db == null) return Stream.value([]);

    return db.communityPostLites
        .filter()
        .communityIdEqualTo(communityId)
        .sortByCreatedAtDesc()
        .limit(limit)
        .watch(fireImmediately: true);
  }

  /// Get local community posts synchronously
  List<CommunityPostLite> getLocalSync(String communityId, {int limit = 20}) {
    final db = isarDB.instance;
    if (db == null) return [];

    return db.communityPostLites
        .filter()
        .communityIdEqualTo(communityId)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAllSync();
  }

  /// Get a single post by ID
  CommunityPostLite? getPostSync(String postId) {
    final db = isarDB.instance;
    if (db == null) return null;
    return db.communityPostLites.filter().idEqualTo(postId).findFirstSync();
  }

  /// Sync remote community posts for a specific community
  Future<void> syncCommunity(String communityId) async {
    if (!isIsarSupported) return;

    final db = isarDB.instance;
    if (db == null) return;

    await _cursorStore.init();

    final cursorKey = '${_module}_$communityId';

    try {
      final lastSync = _cursorStore.getLastSyncTime(cursorKey);
      _debugLog('🔄 Syncing community posts for $communityId since: $lastSync');

      firestore.QuerySnapshot<Map<String, dynamic>> snapshot;

      if (lastSync != null) {
        snapshot = await _db.collection('posts')
            .where('communityId', isEqualTo: communityId)
            .where('updatedAt', isGreaterThan: firestore.Timestamp.fromDate(lastSync))
            .orderBy('updatedAt')
            .limit(_syncBatchSize)
            .get();
      } else {
        snapshot = await _db.collection('posts')
            .where('communityId', isEqualTo: communityId)
            .orderBy('createdAt', descending: true)
            .limit(_syncBatchSize)
            .get();
      }

      if (snapshot.docs.isEmpty) {
        _debugLog('✅ Community posts already up to date');
        return;
      }

      final posts = <CommunityPostLite>[];
      DateTime? latestUpdate;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final post = CommunityPostLite.fromFirestore(doc.id, data);
        posts.add(post);

        final updatedAt = post.updatedAt ?? post.createdAt;
        if (latestUpdate == null || updatedAt.isAfter(latestUpdate)) {
          latestUpdate = updatedAt;
        }
      }

      await db.writeTxn(() async {
        await db.communityPostLites.putAll(posts);
      });

      if (latestUpdate != null) {
        await _cursorStore.setLastSyncTime(cursorKey, latestUpdate);
      }

      _debugLog('✅ Synced ${posts.length} community posts');
    } catch (e) {
      _debugLog('❌ Community post sync failed: $e');
    }
  }

  /// Update post counts locally
  Future<void> updateCountsOptimistic(
    String postId, {
    int? likeCount,
    int? commentCount,
    int? shareCount,
    int? bookmarkCount,
  }) async {
    final db = isarDB.instance;
    if (db == null) return;

    final post = db.communityPostLites.filter().idEqualTo(postId).findFirstSync();
    if (post == null) return;

    if (likeCount != null) post.likeCount = likeCount;
    if (commentCount != null) post.commentCount = commentCount;
    if (shareCount != null) post.shareCount = shareCount;
    if (bookmarkCount != null) post.bookmarkCount = bookmarkCount;
    post.localUpdatedAt = DateTime.now();

    await db.writeTxn(() async {
      await db.communityPostLites.put(post);
    });
  }

  /// Get post count for a community
  int getLocalCount(String communityId) {
    final db = isarDB.instance;
    if (db == null) return 0;
    return db.communityPostLites
        .filter()
        .communityIdEqualTo(communityId)
        .countSync();
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[LocalCommunityPostRepo] $message');
    }
  }
}
