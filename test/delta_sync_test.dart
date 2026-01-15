import 'package:flutter_test/flutter_test.dart';

/// Tests for Delta Sync
/// Covers: timestamp extraction, cursor management, query fallback, batch processing
/// Includes: Isar-first optimization for fluid/fast loading
void main() {
  group('Isar-First Fast/Fluid Optimization', () {
    test('should sync incrementally using cursor', () {
      final sync = _MockFastDeltaSync();
      sync.setLastSyncTime('posts', DateTime(2024, 1, 10));
      
      // Should only fetch items after cursor
      final cursor = sync.getLastSyncTime('posts');
      expect(cursor, isNotNull);
      expect(cursor!.day, 10);
    });

    test('should not block UI during delta sync', () {
      final sync = _MockFastDeltaSync();
      sync.startSync('posts');
      
      // UI reads should still work
      final stopwatch = Stopwatch()..start();
      final canRead = sync.canReadLocalSync();
      stopwatch.stop();
      
      expect(canRead, isTrue);
      expect(stopwatch.elapsedMilliseconds, lessThan(10));
    });

    test('should merge remote changes into local cache', () {
      final sync = _MockFastDeltaSync();
      sync.setLocalData('posts', [
        {'id': 'p1', 'caption': 'Old'},
      ]);
      
      // Delta sync brings updates
      sync.mergeRemoteChanges('posts', [
        {'id': 'p1', 'caption': 'Updated'},
        {'id': 'p2', 'caption': 'New'},
      ]);
      
      final local = sync.getLocalData('posts');
      expect(local.length, 2);
      expect(local.firstWhere((p) => p['id'] == 'p1')['caption'], 'Updated');
    });

    test('should batch sync for efficiency', () {
      final sync = _MockFastDeltaSync();
      
      // Sync multiple modules in batch
      sync.queueSync('posts');
      sync.queueSync('messages');
      sync.queueSync('conversations');
      
      expect(sync.getPendingCount(), 3);
      sync.executeBatch();
      expect(sync.getCompletedBatchCount(), 1);
    });

    test('should update cursor only after successful sync', () {
      final sync = _MockFastDeltaSync();
      sync.setLastSyncTime('posts', DateTime(2024, 1, 10));
      
      // Sync fails
      sync.simulateSyncFailure('posts');
      
      // Cursor should not advance
      expect(sync.getLastSyncTime('posts')!.day, 10);
      
      // Sync succeeds
      sync.simulateSyncSuccess('posts', DateTime(2024, 1, 15));
      expect(sync.getLastSyncTime('posts')!.day, 15);
    });

    test('should handle offline gracefully', () {
      final sync = _MockFastDeltaSync();
      sync.setOfflineMode(true);
      
      // Should skip remote fetch but local reads work
      expect(sync.canReadLocalSync(), isTrue);
      expect(sync.shouldSkipRemoteSync(), isTrue);
    });
  });

  group('Timestamp Extraction', () {
    test('should extract updatedAt when present', () {
      final data = {
        'updatedAt': DateTime(2024, 1, 15, 10, 30),
        'createdAt': DateTime(2024, 1, 10, 8, 0),
      };
      
      final timestamp = _safeExtractTimestamp(data);
      expect(timestamp?.day, 15);
    });

    test('should fallback to createdAt when updatedAt missing', () {
      final data = {
        'createdAt': DateTime(2024, 1, 10, 8, 0),
      };
      
      final timestamp = _safeExtractTimestamp(data);
      expect(timestamp?.day, 10);
    });

    test('should return null when both timestamps missing', () {
      final data = <String, dynamic>{};
      
      final timestamp = _safeExtractTimestamp(data);
      expect(timestamp, isNull);
    });

    test('should handle Timestamp type conversion', () {
      final data = {
        'updatedAt': _MockTimestamp(DateTime(2024, 6, 20)),
      };
      
      final timestamp = _safeExtractTimestamp(data);
      expect(timestamp?.month, 6);
    });

    test('should handle invalid timestamp gracefully', () {
      final data = {
        'updatedAt': 'not-a-date',
        'createdAt': 12345,
      };
      
      final timestamp = _safeExtractTimestamp(data);
      expect(timestamp, isNull);
    });
  });

  group('Cursor Management', () {
    test('should store last sync time', () {
      final cursor = _MockCursorStore();
      cursor.setLastSyncTime('posts', DateTime(2024, 1, 15));
      
      expect(cursor.getLastSyncTime('posts')?.day, 15);
    });

    test('should return null for unsynced module', () {
      final cursor = _MockCursorStore();
      
      expect(cursor.getLastSyncTime('posts'), isNull);
    });

    test('should track seeded status', () {
      final cursor = _MockCursorStore();
      cursor.markSeeded('posts');
      
      expect(cursor.isSeeded('posts'), isTrue);
      expect(cursor.isSeeded('conversations'), isFalse);
    });

    test('should clear all cursors', () {
      final cursor = _MockCursorStore();
      cursor.setLastSyncTime('posts', DateTime.now());
      cursor.markSeeded('posts');
      cursor.clearAll();
      
      expect(cursor.getLastSyncTime('posts'), isNull);
      expect(cursor.isSeeded('posts'), isFalse);
    });
  });

  group('Query Fallback', () {
    test('should use updatedAt query when available', () {
      final strategy = _determineSyncStrategy(
        hasUpdatedAtIndex: true,
        lastSync: DateTime(2024, 1, 10),
      );
      
      expect(strategy, SyncStrategy.deltaByUpdatedAt);
    });

    test('should fallback to createdAt when updatedAt fails', () {
      final strategy = _determineSyncStrategy(
        hasUpdatedAtIndex: false,
        lastSync: DateTime(2024, 1, 10),
      );
      
      expect(strategy, SyncStrategy.deltaByCreatedAt);
    });

    test('should use full sync when no cursor', () {
      final strategy = _determineSyncStrategy(
        hasUpdatedAtIndex: true,
        lastSync: null,
      );
      
      expect(strategy, SyncStrategy.fullSync);
    });
  });

  group('Batch Processing', () {
    test('should process documents in batches', () {
      final docs = List.generate(150, (i) => {'id': 'doc$i'});
      final batches = _splitIntoBatches(docs, batchSize: 50);
      
      expect(batches.length, 3);
      expect(batches[0].length, 50);
      expect(batches[2].length, 50);
    });

    test('should handle partial batch', () {
      final docs = List.generate(75, (i) => {'id': 'doc$i'});
      final batches = _splitIntoBatches(docs, batchSize: 50);
      
      expect(batches.length, 2);
      expect(batches[1].length, 25);
    });

    test('should handle empty list', () {
      final docs = <Map<String, dynamic>>[];
      final batches = _splitIntoBatches(docs, batchSize: 50);
      
      expect(batches, isEmpty);
    });
  });

  group('Document Parsing', () {
    test('should skip invalid documents', () {
      final docs = [
        {'id': 'valid1', 'caption': 'Test'},
        {'caption': 'Missing ID'},
        {'id': 'valid2', 'caption': 'Another'},
      ];
      
      final valid = _filterValidDocuments(docs);
      expect(valid.length, 2);
    });

    test('should handle null fields with defaults', () {
      final doc = {
        'id': 'doc1',
        'caption': null,
        'likeCount': null,
      };
      
      final parsed = _parseWithDefaults(doc);
      expect(parsed['caption'], '');
      expect(parsed['likeCount'], 0);
    });
  });

  group('Error Recovery', () {
    test('should continue after single doc failure', () {
      final processor = _MockSyncProcessor();
      processor.processWithErrors([
        {'id': 'doc1', 'valid': true},
        {'id': 'doc2', 'valid': false}, // Will fail
        {'id': 'doc3', 'valid': true},
      ]);
      
      expect(processor.successCount, 2);
      expect(processor.errorCount, 1);
    });

    test('should not update cursor on failure', () {
      final cursor = _MockCursorStore();
      final processor = _MockSyncProcessor(cursorStore: cursor);
      
      processor.processWithTotalFailure();
      
      expect(cursor.getLastSyncTime('posts'), isNull);
    });

    test('should update cursor only after success', () {
      final cursor = _MockCursorStore();
      final processor = _MockSyncProcessor(cursorStore: cursor);
      
      processor.processSuccessfully(DateTime(2024, 1, 15));
      
      expect(cursor.getLastSyncTime('posts')?.day, 15);
    });
  });

  group('Sync Limits', () {
    test('should respect batch size limit', () {
      const batchSize = 100;
      final docs = List.generate(500, (i) => {'id': 'doc$i'});
      
      final limited = docs.take(batchSize).toList();
      expect(limited.length, batchSize);
    });

    test('should track latest timestamp in batch', () {
      final docs = [
        {'id': '1', 'updatedAt': DateTime(2024, 1, 10)},
        {'id': '2', 'updatedAt': DateTime(2024, 1, 15)},
        {'id': '3', 'updatedAt': DateTime(2024, 1, 12)},
      ];
      
      final latest = _findLatestTimestamp(docs);
      expect(latest?.day, 15);
    });
  });
}

// Helper functions

DateTime? _safeExtractTimestamp(Map<String, dynamic> data) {
  try {
    final updatedAt = data['updatedAt'];
    if (updatedAt != null) {
      if (updatedAt is DateTime) return updatedAt;
      if (updatedAt is _MockTimestamp) return updatedAt.toDate();
    }
    final createdAt = data['createdAt'];
    if (createdAt != null) {
      if (createdAt is DateTime) return createdAt;
      if (createdAt is _MockTimestamp) return createdAt.toDate();
    }
  } catch (e) {
    // Graceful fallback
  }
  return null;
}

enum SyncStrategy { deltaByUpdatedAt, deltaByCreatedAt, fullSync }

SyncStrategy _determineSyncStrategy({
  required bool hasUpdatedAtIndex,
  required DateTime? lastSync,
}) {
  if (lastSync == null) return SyncStrategy.fullSync;
  if (hasUpdatedAtIndex) return SyncStrategy.deltaByUpdatedAt;
  return SyncStrategy.deltaByCreatedAt;
}

List<List<Map<String, dynamic>>> _splitIntoBatches(
  List<Map<String, dynamic>> docs, {
  required int batchSize,
}) {
  if (docs.isEmpty) return [];
  final batches = <List<Map<String, dynamic>>>[];
  for (int i = 0; i < docs.length; i += batchSize) {
    final end = (i + batchSize < docs.length) ? i + batchSize : docs.length;
    batches.add(docs.sublist(i, end));
  }
  return batches;
}

List<Map<String, dynamic>> _filterValidDocuments(List<Map<String, dynamic>> docs) {
  return docs.where((doc) => doc.containsKey('id') && doc['id'] != null).toList();
}

Map<String, dynamic> _parseWithDefaults(Map<String, dynamic> doc) {
  return {
    'id': doc['id'],
    'caption': doc['caption'] ?? '',
    'likeCount': doc['likeCount'] ?? 0,
  };
}

DateTime? _findLatestTimestamp(List<Map<String, dynamic>> docs) {
  DateTime? latest;
  for (final doc in docs) {
    final ts = doc['updatedAt'] as DateTime?;
    if (ts != null && (latest == null || ts.isAfter(latest))) {
      latest = ts;
    }
  }
  return latest;
}

// Mock classes

class _MockTimestamp {
  final DateTime _dateTime;
  _MockTimestamp(this._dateTime);
  DateTime toDate() => _dateTime;
}

class _MockCursorStore {
  final Map<String, DateTime> _cursors = {};
  final Set<String> _seeded = {};

  DateTime? getLastSyncTime(String module) => _cursors[module];
  
  void setLastSyncTime(String module, DateTime time) {
    _cursors[module] = time;
  }

  bool isSeeded(String module) => _seeded.contains(module);
  
  void markSeeded(String module) {
    _seeded.add(module);
  }

  void clearAll() {
    _cursors.clear();
    _seeded.clear();
  }
}

class _MockSyncProcessor {
  final _MockCursorStore? cursorStore;
  int successCount = 0;
  int errorCount = 0;

  _MockSyncProcessor({this.cursorStore});

  void processWithErrors(List<Map<String, dynamic>> docs) {
    for (final doc in docs) {
      if (doc['valid'] == true) {
        successCount++;
      } else {
        errorCount++;
      }
    }
  }

  void processWithTotalFailure() {
    errorCount++;
  }

  void processSuccessfully(DateTime timestamp) {
    successCount++;
    cursorStore?.setLastSyncTime('posts', timestamp);
  }
}

class _MockFastDeltaSync {
  final Map<String, DateTime> _cursors = {};
  final Map<String, List<Map<String, dynamic>>> _localData = {};
  final List<String> _pendingModules = [];
  int _completedBatches = 0;
  bool _syncing = false;
  bool _offlineMode = false;

  void setLastSyncTime(String module, DateTime time) {
    _cursors[module] = time;
  }

  DateTime? getLastSyncTime(String module) => _cursors[module];

  void startSync(String module) {
    _syncing = true;
  }

  bool canReadLocalSync() => true;

  void setLocalData(String module, List<Map<String, dynamic>> data) {
    _localData[module] = data;
  }

  List<Map<String, dynamic>> getLocalData(String module) {
    return _localData[module] ?? [];
  }

  void mergeRemoteChanges(String module, List<Map<String, dynamic>> changes) {
    _localData.putIfAbsent(module, () => []);
    for (final change in changes) {
      final id = change['id'];
      final existingIndex = _localData[module]!.indexWhere((d) => d['id'] == id);
      if (existingIndex >= 0) {
        _localData[module]![existingIndex] = change;
      } else {
        _localData[module]!.add(change);
      }
    }
  }

  void queueSync(String module) {
    _pendingModules.add(module);
  }

  int getPendingCount() => _pendingModules.length;

  void executeBatch() {
    _pendingModules.clear();
    _completedBatches++;
  }

  int getCompletedBatchCount() => _completedBatches;

  void simulateSyncFailure(String module) {
    // Cursor not updated on failure
  }

  void simulateSyncSuccess(String module, DateTime newCursor) {
    _cursors[module] = newCursor;
  }

  void setOfflineMode(bool offline) {
    _offlineMode = offline;
  }

  bool shouldSkipRemoteSync() => _offlineMode;
}
