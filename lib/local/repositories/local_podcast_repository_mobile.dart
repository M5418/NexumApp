import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:isar/isar.dart';
import '../isar_db.dart';
import '../local_store.dart';
import '../models/podcast_lite.dart';
import '../sync/sync_cursor_store.dart';
import '../web/web_local_store.dart';

export '../models/podcast_lite.dart';

/// Local-first repository for Podcasts.
class LocalPodcastRepository {
  static final LocalPodcastRepository _instance = LocalPodcastRepository._internal();
  factory LocalPodcastRepository() => _instance;
  LocalPodcastRepository._internal();

  final firestore.FirebaseFirestore _db = firestore.FirebaseFirestore.instance;
  final SyncCursorStore _cursorStore = SyncCursorStore();

  static const String _module = 'podcasts';
  static const int _syncBatchSize = 50;

  /// Watch local podcasts (instant UI binding)
  Stream<List<PodcastLite>> watchLocal({int limit = 50, String? category}) {
    final db = isarDB.instance;
    if (db == null) return Stream.value([]);

    if (category != null) {
      return db.podcastLites
          .filter()
          .categoryEqualTo(category)
          .sortByCreatedAtDesc()
          .limit(limit)
          .watch(fireImmediately: true);
    }

    return db.podcastLites
        .where()
        .sortByCreatedAtDesc()
        .limit(limit)
        .watch(fireImmediately: true);
  }

  /// Get local podcasts synchronously
  /// Uses Isar on mobile, Hive on web
  List<PodcastLite> getLocalSync({int limit = 50, String? category}) {
    // WEB: Use Hive via WebLocalStore
    if (isHiveSupported && webLocalStore.isAvailable) {
      final maps = webLocalStore.getPodcastsSync(limit: limit, category: category);
      if (maps.isNotEmpty) {
        _debugLog('🌐 [Web] Loaded ${maps.length} podcasts from Hive');
        return maps.map((m) => PodcastLite.fromMap(m)).toList();
      }
    }
    
    // MOBILE: Use Isar
    final db = isarDB.instance;
    if (db == null) return [];

    if (category != null) {
      return db.podcastLites
          .filter()
          .categoryEqualTo(category)
          .sortByCreatedAtDesc()
          .limit(limit)
          .findAllSync();
    }

    return db.podcastLites
        .where()
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAllSync();
  }

  /// Get a single podcast by ID
  PodcastLite? getPodcastSync(String podcastId) {
    final db = isarDB.instance;
    if (db == null) return null;
    return db.podcastLites.filter().idEqualTo(podcastId).findFirstSync();
  }

  /// Sync remote podcasts (delta sync)
  Future<void> syncRemote() async {
    if (!isIsarSupported) return;

    final db = isarDB.instance;
    if (db == null) return;

    await _cursorStore.init();

    try {
      final lastSync = _cursorStore.getLastSyncTime(_module);
      _debugLog('🔄 Syncing podcasts since: $lastSync');

      firestore.QuerySnapshot<Map<String, dynamic>> snapshot;

      if (lastSync != null) {
        snapshot = await _db.collection('podcasts')
            .where('updatedAt', isGreaterThan: firestore.Timestamp.fromDate(lastSync))
            .orderBy('updatedAt')
            .limit(_syncBatchSize)
            .get();
      } else {
        snapshot = await _db.collection('podcasts')
            .where('isPublished', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(_syncBatchSize)
            .get();
      }

      if (snapshot.docs.isEmpty) {
        _debugLog('✅ Podcasts already up to date');
        return;
      }

      final podcasts = <PodcastLite>[];
      DateTime? latestUpdate;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final podcast = PodcastLite.fromFirestore(doc.id, data);
        podcasts.add(podcast);

        final updatedAt = podcast.updatedAt ?? podcast.createdAt;
        if (updatedAt != null && (latestUpdate == null || updatedAt.isAfter(latestUpdate))) {
          latestUpdate = updatedAt;
        }
      }

      await db.writeTxn(() async {
        await db.podcastLites.putAll(podcasts);
      });

      if (latestUpdate != null) {
        await _cursorStore.setLastSyncTime(_module, latestUpdate);
      }

      _debugLog('✅ Synced ${podcasts.length} podcasts');
    } catch (e) {
      _debugLog('❌ Podcast sync failed: $e');
    }
  }

  /// Get podcast count
  int getLocalCount() {
    final db = isarDB.instance;
    if (db == null) return 0;
    return db.podcastLites.countSync();
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[LocalPodcastRepo] $message');
    }
  }
}
