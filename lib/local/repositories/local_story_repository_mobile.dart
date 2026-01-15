import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:isar/isar.dart';
import '../isar_db.dart';
import '../local_store.dart';
import '../models/story_lite.dart';
import '../sync/sync_cursor_store.dart';

export '../models/story_lite.dart';

/// Local-first repository for Stories.
class LocalStoryRepository {
  static final LocalStoryRepository _instance = LocalStoryRepository._internal();
  factory LocalStoryRepository() => _instance;
  LocalStoryRepository._internal();

  final firestore.FirebaseFirestore _db = firestore.FirebaseFirestore.instance;
  final SyncCursorStore _cursorStore = SyncCursorStore();

  static const String _module = 'stories';
  static const int _syncBatchSize = 50;

  /// Watch local stories (instant UI binding)
  Stream<List<StoryLite>> watchLocal({int limit = 50}) {
    final db = isarDB.instance;
    if (db == null) return Stream.value([]);

    final now = DateTime.now();
    return db.storyLites
        .filter()
        .expiresAtGreaterThan(now)
        .sortByCreatedAtDesc()
        .limit(limit)
        .watch(fireImmediately: true);
  }

  /// Get local stories synchronously (non-expired only)
  List<StoryLite> getLocalSync({int limit = 50}) {
    final db = isarDB.instance;
    if (db == null) return [];

    final now = DateTime.now();
    return db.storyLites
        .filter()
        .expiresAtGreaterThan(now)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAllSync();
  }

  /// Get stories by author
  List<StoryLite> getByAuthorSync(String authorId, {int limit = 20}) {
    final db = isarDB.instance;
    if (db == null) return [];

    final now = DateTime.now();
    return db.storyLites
        .filter()
        .authorIdEqualTo(authorId)
        .and()
        .expiresAtGreaterThan(now)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAllSync();
  }

  /// Sync remote stories
  Future<void> syncRemote() async {
    if (!isIsarSupported) return;

    final db = isarDB.instance;
    if (db == null) return;

    await _cursorStore.init();

    try {
      final lastSync = _cursorStore.getLastSyncTime(_module);
      _debugLog('🔄 Syncing stories since: $lastSync');

      // Only fetch non-expired stories (created in last 24 hours)
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));

      firestore.QuerySnapshot<Map<String, dynamic>> snapshot;

      if (lastSync != null && lastSync.isAfter(cutoff)) {
        snapshot = await _db.collection('stories')
            .where('createdAt', isGreaterThan: firestore.Timestamp.fromDate(lastSync))
            .orderBy('createdAt', descending: true)
            .limit(_syncBatchSize)
            .get();
      } else {
        snapshot = await _db.collection('stories')
            .where('createdAt', isGreaterThan: firestore.Timestamp.fromDate(cutoff))
            .orderBy('createdAt', descending: true)
            .limit(_syncBatchSize)
            .get();
      }

      if (snapshot.docs.isEmpty) {
        _debugLog('✅ Stories already up to date');
        return;
      }

      final stories = <StoryLite>[];
      DateTime? latestUpdate;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final story = StoryLite.fromFirestore(doc.id, data);
        stories.add(story);

        if (latestUpdate == null || story.createdAt.isAfter(latestUpdate)) {
          latestUpdate = story.createdAt;
        }
      }

      await db.writeTxn(() async {
        await db.storyLites.putAll(stories);
      });

      if (latestUpdate != null) {
        await _cursorStore.setLastSyncTime(_module, latestUpdate);
      }

      _debugLog('✅ Synced ${stories.length} stories');

      // Clean up expired stories
      await _cleanupExpired();
    } catch (e) {
      _debugLog('❌ Story sync failed: $e');
    }
  }

  /// Mark story as viewed
  Future<void> markViewed(String storyId) async {
    final db = isarDB.instance;
    if (db == null) return;

    final story = db.storyLites.filter().idEqualTo(storyId).findFirstSync();
    if (story == null) return;

    story.viewed = true;
    story.localUpdatedAt = DateTime.now();

    await db.writeTxn(() async {
      await db.storyLites.put(story);
    });
  }

  /// Clean up expired stories
  Future<void> _cleanupExpired() async {
    final db = isarDB.instance;
    if (db == null) return;

    final now = DateTime.now();
    await db.writeTxn(() async {
      await db.storyLites.filter().expiresAtLessThan(now).deleteAll();
    });

    _debugLog('🧹 Cleaned up expired stories');
  }

  /// Get story count
  int getLocalCount() {
    final db = isarDB.instance;
    if (db == null) return 0;
    final now = DateTime.now();
    return db.storyLites.filter().expiresAtGreaterThan(now).countSync();
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[LocalStoryRepo] $message');
    }
  }
}
