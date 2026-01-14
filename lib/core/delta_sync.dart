import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Delta sync utility for efficient Firestore synchronization.
/// Tracks last sync timestamps per collection and fetches only changes.
class DeltaSync {
  static final DeltaSync _instance = DeltaSync._internal();
  factory DeltaSync() => _instance;
  DeltaSync._internal();

  SharedPreferences? _prefs;
  final Map<String, DateTime> _lastSyncTimes = {};

  static const String _keyPrefix = 'delta_sync_';

  /// Initialize delta sync (call once at app startup)
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSyncTimes();
    _debugLog('✅ DeltaSync initialized');
  }

  void _loadSyncTimes() {
    if (_prefs == null) return;
    final prefs = _prefs;
    if (prefs == null) return;
    final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
    for (final key in keys) {
      final collection = key.substring(_keyPrefix.length);
      final timestamp = prefs.getString(key);
      if (timestamp != null) {
        _lastSyncTimes[collection] = DateTime.parse(timestamp);
      }
    }
  }

  /// Get the last sync time for a collection
  DateTime? getLastSyncTime(String collection) {
    return _lastSyncTimes[collection];
  }

  /// Update the last sync time for a collection
  Future<void> updateSyncTime(String collection, DateTime time) async {
    _lastSyncTimes[collection] = time;
    await _prefs?.setString('$_keyPrefix$collection', time.toIso8601String());
  }

  /// Build a Firestore query that fetches only documents updated since last sync.
  /// Returns null if no previous sync (full fetch needed).
  /// 
  /// Usage:
  /// ```dart
  /// final deltaQuery = DeltaSync().buildDeltaQuery(
  ///   baseQuery: _posts.orderBy('createdAt', descending: true),
  ///   collection: 'posts',
  ///   timestampField: 'updatedAt',
  /// );
  /// if (deltaQuery != null) {
  ///   // Fetch only changes
  ///   final snap = await deltaQuery.get();
  /// } else {
  ///   // Full fetch needed
  ///   final snap = await baseQuery.get();
  /// }
  /// ```
  Query<Map<String, dynamic>>? buildDeltaQuery({
    required Query<Map<String, dynamic>> baseQuery,
    required String collection,
    String timestampField = 'updatedAt',
  }) {
    final lastSync = _lastSyncTimes[collection];
    if (lastSync == null) {
      _debugLog('📥 [$collection] No previous sync, full fetch needed');
      return null;
    }

    _debugLog('📥 [$collection] Delta sync since ${lastSync.toIso8601String()}');
    return baseQuery.where(
      timestampField,
      isGreaterThan: Timestamp.fromDate(lastSync),
    );
  }

  /// Process a batch of documents and update sync time.
  /// Call this after successfully fetching and processing documents.
  Future<void> markSynced(
    String collection,
    List<DocumentSnapshot> docs, {
    String timestampField = 'updatedAt',
  }) async {
    if (docs.isEmpty) return;

    // Find the latest timestamp in the batch
    DateTime? latestTime;
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;

      final timestamp = data[timestampField];
      DateTime? docTime;
      if (timestamp is Timestamp) {
        docTime = timestamp.toDate();
      } else if (timestamp is String) {
        docTime = DateTime.tryParse(timestamp);
      }

      if (docTime != null && (latestTime == null || docTime.isAfter(latestTime))) {
        latestTime = docTime;
      }
    }

    if (latestTime != null) {
      await updateSyncTime(collection, latestTime);
      _debugLog('✅ [$collection] Synced ${docs.length} docs, latest: ${latestTime.toIso8601String()}');
    }
  }

  /// Reset sync time for a collection (forces full refresh)
  Future<void> resetCollection(String collection) async {
    _lastSyncTimes.remove(collection);
    await _prefs?.remove('$_keyPrefix$collection');
    _debugLog('🔄 [$collection] Sync time reset');
  }

  /// Reset all sync times
  Future<void> resetAll() async {
    for (final collection in _lastSyncTimes.keys.toList()) {
      await _prefs?.remove('$_keyPrefix$collection');
    }
    _lastSyncTimes.clear();
    _debugLog('🔄 All sync times reset');
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[DeltaSync] $message');
    }
  }
}

/// Extension for easier delta sync on Firestore queries
extension DeltaSyncQuery on Query<Map<String, dynamic>> {
  /// Apply delta sync filter if available
  Query<Map<String, dynamic>> withDeltaSync(
    String collection, {
    String timestampField = 'updatedAt',
  }) {
    final deltaQuery = DeltaSync().buildDeltaQuery(
      baseQuery: this,
      collection: collection,
      timestampField: timestampField,
    );
    return deltaQuery ?? this;
  }
}
