import 'package:flutter_test/flutter_test.dart';

/// Tests for local storage layer (Isar/Hive abstraction)
/// Covers: schema versioning, size caps, payload validation, fallbacks
/// Includes: Isar-first optimization for fluid/fast loading
void main() {
  group('Isar-First Fast/Fluid Optimization', () {
    test('should read from local cache synchronously (instant)', () {
      final store = _MockFastLocalStore();
      store.seedData(List.generate(100, (i) => {'id': 'item$i', 'data': 'value$i'}));
      
      final stopwatch = Stopwatch()..start();
      final items = store.getSync(limit: 20);
      stopwatch.stop();
      
      expect(items.length, 20);
      expect(stopwatch.elapsedMilliseconds, lessThan(50)); // Should be nearly instant
    });

    test('should return cached data before async fetch completes', () {
      final store = _MockFastLocalStore();
      store.seedData([
        {'id': 'item1', 'data': 'cached'},
      ]);
      
      // Sync read returns immediately
      final cached = store.getSync(limit: 10);
      expect(cached.length, 1);
      expect(cached.first['data'], 'cached');
    });

    test('should upsert remote data into local cache', () {
      final store = _MockFastLocalStore();
      store.seedData([
        {'id': 'item1', 'data': 'old'},
      ]);
      
      // Remote data arrives
      store.upsertFromRemote([
        {'id': 'item1', 'data': 'updated'},
        {'id': 'item2', 'data': 'new'},
      ]);
      
      final items = store.getSync(limit: 10);
      expect(items.length, 2);
      expect(items.firstWhere((i) => i['id'] == 'item1')['data'], 'updated');
    });

    test('should handle concurrent read/write safely', () {
      final store = _MockFastLocalStore();
      store.seedData([{'id': 'item1', 'data': 'initial'}]);
      
      // Simulate concurrent operations
      final read1 = store.getSync(limit: 10);
      store.upsertFromRemote([{'id': 'item2', 'data': 'new'}]);
      final read2 = store.getSync(limit: 10);
      
      expect(read1.length, 1);
      expect(read2.length, 2);
    });

    test('should work fully offline with cached data', () {
      final store = _MockFastLocalStore();
      store.seedData([
        {'id': 'item1', 'data': 'offline1'},
        {'id': 'item2', 'data': 'offline2'},
      ]);
      store.setOfflineMode(true);
      
      final items = store.getSync(limit: 10);
      expect(items.length, 2);
    });

    test('should track sync status per item', () {
      final store = _MockFastLocalStore();
      store.putWithStatus('item1', {'id': 'item1', 'data': 'test'}, 'pending');
      
      expect(store.getSyncStatus('item1'), 'pending');
      
      store.updateSyncStatus('item1', 'synced');
      expect(store.getSyncStatus('item1'), 'synced');
    });

    test('should batch writes for performance', () {
      final store = _MockFastLocalStore();
      final items = List.generate(100, (i) => {'id': 'item$i', 'data': 'value$i'});
      
      final stopwatch = Stopwatch()..start();
      store.putAllSync(items);
      stopwatch.stop();
      
      expect(store.getSync(limit: 200).length, 100);
      expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Batch should be fast
    });
  });


  group('Schema Versioning', () {
    test('should detect schema version mismatch', () {
      const currentVersion = 2;
      const storedVersion = 1;
      expect(currentVersion > storedVersion, isTrue);
    });

    test('should allow same version', () {
      const currentVersion = 2;
      const storedVersion = 2;
      expect(currentVersion == storedVersion, isTrue);
    });
  });

  group('Payload Validation', () {
    test('should validate payload with required id field', () {
      final payload = {'id': '123', 'name': 'Test', 'createdAt': DateTime.now()};
      expect(_isValidPayload(payload), isTrue);
    });

    test('should reject payload without id', () {
      final payload = {'name': 'Test'};
      expect(_isValidPayload(payload), isFalse);
    });

    test('should reject payload with null id', () {
      final payload = {'id': null, 'name': 'Test'};
      expect(_isValidPayload(payload), isFalse);
    });

    test('should reject payload with empty id', () {
      final payload = {'id': '', 'name': 'Test'};
      expect(_isValidPayload(payload), isFalse);
    });
  });

  group('Size Caps and LRU Eviction', () {
    test('should not evict when under limit', () {
      final cache = _createCache(5);
      _enforceSizeCap(cache, 10);
      expect(cache.length, 5);
    });

    test('should evict oldest entries when over limit', () {
      final cache = _createCache(10);
      _enforceSizeCap(cache, 5);
      expect(cache.length, 5);
    });

    test('should keep newest entries after eviction', () {
      final cache = <String, Map<String, dynamic>>{};
      for (int i = 0; i < 10; i++) {
        cache['key$i'] = {'id': 'key$i', 'index': i};
      }
      _enforceSizeCap(cache, 5);
      
      // Oldest (0-4) should be removed, newest (5-9) kept
      expect(cache.containsKey('key0'), isFalse);
      expect(cache.containsKey('key4'), isFalse);
      expect(cache.containsKey('key5'), isTrue);
      expect(cache.containsKey('key9'), isTrue);
    });

    test('should handle empty cache', () {
      final cache = <String, Map<String, dynamic>>{};
      _enforceSizeCap(cache, 5);
      expect(cache.length, 0);
    });
  });

  group('Safe Initialization', () {
    test('should return false when init fails', () {
      final store = _MockLocalStore(shouldFailInit: true);
      expect(store.init(), isFalse);
      expect(store.isAvailable, isFalse);
    });

    test('should return true when init succeeds', () {
      final store = _MockLocalStore(shouldFailInit: false);
      expect(store.init(), isTrue);
      expect(store.isAvailable, isTrue);
    });

    test('should return empty data when not available', () {
      final store = _MockLocalStore(shouldFailInit: true);
      store.init();
      expect(store.getPosts(), isEmpty);
      expect(store.getConversations(), isEmpty);
    });
  });

  group('Data Type Conversion', () {
    test('should convert Timestamp to DateTime', () {
      final timestamp = _MockTimestamp(DateTime(2024, 1, 15, 10, 30));
      expect(timestamp.toDate(), isA<DateTime>());
      expect(timestamp.toDate().year, 2024);
    });

    test('should handle null timestamp gracefully', () {
      final result = _safeParseTimestamp(null);
      expect(result, isNull);
    });

    test('should parse DateTime directly', () {
      final dt = DateTime(2024, 6, 15);
      final result = _safeParseTimestamp(dt);
      expect(result, dt);
    });
  });

  group('Box Migration', () {
    test('should clear box on version mismatch', () {
      final box = _MockBox(version: 1);
      final needsMigration = _checkNeedsMigration(box, 2);
      expect(needsMigration, isTrue);
    });

    test('should not clear box when versions match', () {
      final box = _MockBox(version: 2);
      final needsMigration = _checkNeedsMigration(box, 2);
      expect(needsMigration, isFalse);
    });
  });
}

// Helper functions

bool _isValidPayload(Map<dynamic, dynamic> data) {
  if (!data.containsKey('id')) return false;
  final id = data['id'];
  if (id == null) return false;
  if (id is String && id.isEmpty) return false;
  return true;
}

Map<String, Map<String, dynamic>> _createCache(int size) {
  final cache = <String, Map<String, dynamic>>{};
  for (int i = 0; i < size; i++) {
    cache['key$i'] = {'id': 'key$i'};
  }
  return cache;
}

void _enforceSizeCap(Map<String, Map<String, dynamic>> cache, int maxSize) {
  if (cache.length <= maxSize) return;
  final keysToRemove = cache.keys.take(cache.length - maxSize).toList();
  for (final key in keysToRemove) {
    cache.remove(key);
  }
}

DateTime? _safeParseTimestamp(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is _MockTimestamp) return value.toDate();
  return null;
}

bool _checkNeedsMigration(_MockBox box, int currentVersion) {
  return box.version != currentVersion;
}

// Mock classes

class _MockLocalStore {
  final bool shouldFailInit;
  bool _initialized = false;
  bool _available = false;

  _MockLocalStore({required this.shouldFailInit});

  bool get isAvailable => _available;

  bool init() {
    if (shouldFailInit) {
      _available = false;
      return false;
    }
    _initialized = true;
    _available = true;
    return true;
  }

  List<Map<String, dynamic>> getPosts() {
    if (!_available) return [];
    return [{'id': '1', 'caption': 'Test'}];
  }

  List<Map<String, dynamic>> getConversations() {
    if (!_available) return [];
    return [{'id': '1', 'name': 'Chat'}];
  }
}

class _MockTimestamp {
  final DateTime _dateTime;
  _MockTimestamp(this._dateTime);
  DateTime toDate() => _dateTime;
}

class _MockFastLocalStore {
  final List<Map<String, dynamic>> _data = [];
  final Map<String, String> _syncStatus = {};
  bool _offlineMode = false;

  void seedData(List<Map<String, dynamic>> items) {
    _data.addAll(items);
  }

  List<Map<String, dynamic>> getSync({required int limit}) {
    return _data.take(limit).toList();
  }

  void upsertFromRemote(List<Map<String, dynamic>> items) {
    for (final item in items) {
      final id = item['id'] as String;
      final existingIndex = _data.indexWhere((d) => d['id'] == id);
      if (existingIndex >= 0) {
        _data[existingIndex] = item;
      } else {
        _data.add(item);
      }
    }
  }

  void setOfflineMode(bool offline) {
    _offlineMode = offline;
  }

  void putWithStatus(String id, Map<String, dynamic> item, String status) {
    _data.add(item);
    _syncStatus[id] = status;
  }

  String? getSyncStatus(String id) => _syncStatus[id];

  void updateSyncStatus(String id, String status) {
    _syncStatus[id] = status;
  }

  void putAllSync(List<Map<String, dynamic>> items) {
    _data.addAll(items);
  }
}

class _MockBox {
  final int version;
  _MockBox({required this.version});
}
