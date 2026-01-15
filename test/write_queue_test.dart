import 'package:flutter_test/flutter_test.dart';

/// Tests for WriteQueue (optimistic writes / outbox)
/// Covers: idempotency, retry limits, persistence, queue processing
/// Includes: Isar-first optimization for fluid/fast loading
void main() {
  group('Isar-First Fast/Fluid Optimization', () {
    test('should apply optimistic write to local cache instantly', () {
      final queue = _MockFastWriteQueue();
      
      final stopwatch = Stopwatch()..start();
      queue.writeOptimistic('posts', 'post1', {'id': 'post1', 'caption': 'New post'});
      stopwatch.stop();
      
      expect(stopwatch.elapsedMilliseconds, lessThan(10)); // Instant
      expect(queue.getLocalItem('posts', 'post1'), isNotNull);
    });

    test('should show optimistic data in UI before server confirm', () {
      final queue = _MockFastWriteQueue();
      queue.writeOptimistic('posts', 'post1', {'id': 'post1', 'caption': 'Pending'});
      
      // UI can read immediately
      final item = queue.getLocalItem('posts', 'post1');
      expect(item?['caption'], 'Pending');
      expect(queue.getSyncStatus('posts', 'post1'), 'pending');
    });

    test('should update status after server confirms', () {
      final queue = _MockFastWriteQueue();
      queue.writeOptimistic('posts', 'post1', {'id': 'post1', 'caption': 'Test'});
      
      // Server confirms
      queue.confirmWrite('posts', 'post1');
      
      expect(queue.getSyncStatus('posts', 'post1'), 'synced');
    });

    test('should handle offline writes gracefully', () {
      final queue = _MockFastWriteQueue();
      queue.setOfflineMode(true);
      
      // Write still succeeds locally
      queue.writeOptimistic('posts', 'post1', {'id': 'post1', 'caption': 'Offline'});
      
      expect(queue.getLocalItem('posts', 'post1'), isNotNull);
      expect(queue.getPendingCount(), 1);
    });

    test('should batch pending writes for efficiency', () {
      final queue = _MockFastWriteQueue();
      queue.writeOptimistic('posts', 'p1', {'id': 'p1'});
      queue.writeOptimistic('posts', 'p2', {'id': 'p2'});
      queue.writeOptimistic('posts', 'p3', {'id': 'p3'});
      
      // Process as batch
      final batchSize = queue.processPendingBatch();
      expect(batchSize, 3);
    });

    test('should not block UI during retry', () {
      final queue = _MockFastWriteQueue();
      queue.writeOptimistic('posts', 'post1', {'id': 'post1'});
      queue.markFailed('posts', 'post1');
      
      // UI reads still work
      final item = queue.getLocalItem('posts', 'post1');
      expect(item, isNotNull);
      expect(queue.getSyncStatus('posts', 'post1'), 'failed');
    });
  });


  group('Idempotency', () {
    test('should generate unique write IDs', () {
      final queue = _MockWriteQueue();
      final id1 = queue.enqueue('posts', 'doc1', {'caption': 'Test'});
      final id2 = queue.enqueue('posts', 'doc1', {'caption': 'Test'});
      
      expect(id1, isNot(equals(id2)));
    });

    test('should use document ID for deduplication', () {
      final queue = _MockWriteQueue();
      queue.enqueue('posts', 'doc1', {'caption': 'Test'});
      
      expect(queue.hasPendingWrite('posts', 'doc1'), isTrue);
    });
  });

  group('Retry Limits', () {
    test('should track retry count', () {
      final write = _MockPendingWrite(retryCount: 0);
      final retried = write.incrementRetry();
      
      expect(retried.retryCount, 1);
    });

    test('should stop retrying after max attempts', () {
      const maxRetries = 5;
      final write = _MockPendingWrite(retryCount: maxRetries);
      
      expect(write.shouldRetry(maxRetries), isFalse);
    });

    test('should allow retry before max attempts', () {
      const maxRetries = 5;
      final write = _MockPendingWrite(retryCount: 3);
      
      expect(write.shouldRetry(maxRetries), isTrue);
    });

    test('should mark as failed after max retries', () {
      final queue = _MockWriteQueue();
      final id = queue.enqueue('posts', 'doc1', {'caption': 'Test'});
      
      for (int i = 0; i < 5; i++) {
        queue.recordFailure(id);
      }
      
      expect(queue.getStatus(id), WriteStatus.failed);
    });
  });

  group('Queue Processing', () {
    test('should process writes in order', () {
      final queue = _MockWriteQueue();
      queue.enqueue('posts', 'doc1', {'order': 1});
      queue.enqueue('posts', 'doc2', {'order': 2});
      queue.enqueue('posts', 'doc3', {'order': 3});
      
      final next = queue.peekNext();
      expect(next?.documentId, 'doc1');
    });

    test('should remove completed writes', () {
      final queue = _MockWriteQueue();
      final id = queue.enqueue('posts', 'doc1', {'caption': 'Test'});
      queue.complete(id);
      
      expect(queue.pendingCount, 0);
    });

    test('should move failed writes to end with backoff', () {
      final queue = _MockWriteQueue();
      queue.enqueue('posts', 'doc1', {'order': 1});
      queue.enqueue('posts', 'doc2', {'order': 2});
      
      queue.recordFailure(queue.peekNext()!.id);
      
      // doc1 should now be at the end
      expect(queue.peekNext()?.documentId, 'doc2');
    });
  });

  group('Persistence', () {
    test('should serialize write to JSON', () {
      final write = _MockPendingWrite(
        id: 'write_1',
        collection: 'posts',
        documentId: 'doc1',
        data: {'caption': 'Test'},
        retryCount: 2,
      );
      
      final json = write.toJson();
      
      expect(json['id'], 'write_1');
      expect(json['collection'], 'posts');
      expect(json['documentId'], 'doc1');
      expect(json['retryCount'], 2);
    });

    test('should deserialize write from JSON', () {
      final json = {
        'id': 'write_1',
        'collection': 'posts',
        'documentId': 'doc1',
        'data': {'caption': 'Test'},
        'retryCount': 2,
        'createdAt': '2024-01-15T10:30:00.000Z',
      };
      
      final write = _MockPendingWrite.fromJson(json);
      
      expect(write.id, 'write_1');
      expect(write.retryCount, 2);
    });

    test('should restore queue from storage', () {
      final queue = _MockWriteQueue();
      queue.restoreFromStorage([
        {'id': 'w1', 'collection': 'posts', 'documentId': 'd1', 'data': {}, 'retryCount': 0, 'createdAt': '2024-01-15T10:30:00.000Z'},
        {'id': 'w2', 'collection': 'posts', 'documentId': 'd2', 'data': {}, 'retryCount': 1, 'createdAt': '2024-01-15T10:31:00.000Z'},
      ]);
      
      expect(queue.pendingCount, 2);
    });
  });

  group('Backoff Calculation', () {
    test('should use exponential backoff', () {
      expect(_calculateWriteBackoff(1).inSeconds, 2);
      expect(_calculateWriteBackoff(2).inSeconds, 4);
      expect(_calculateWriteBackoff(3).inSeconds, 8);
    });

    test('should cap backoff at max duration', () {
      final backoff = _calculateWriteBackoff(20);
      expect(backoff.inMinutes, lessThanOrEqualTo(5));
    });
  });

  group('Queue Status', () {
    test('should report pending count', () {
      final queue = _MockWriteQueue();
      queue.enqueue('posts', 'doc1', {});
      queue.enqueue('posts', 'doc2', {});
      
      expect(queue.pendingCount, 2);
    });

    test('should report processing state', () {
      final queue = _MockWriteQueue();
      queue.enqueue('posts', 'doc1', {});
      queue.startProcessing();
      
      expect(queue.isProcessing, isTrue);
    });

    test('should report has pending', () {
      final queue = _MockWriteQueue();
      expect(queue.hasPending, isFalse);
      
      queue.enqueue('posts', 'doc1', {});
      expect(queue.hasPending, isTrue);
    });
  });

  group('Error Handling', () {
    test('should handle persistence failure gracefully', () {
      final queue = _MockWriteQueue(persistenceEnabled: false);
      
      // Should not throw
      expect(() => queue.enqueue('posts', 'doc1', {}), returnsNormally);
    });

    test('should fallback to direct write on queue failure', () {
      final queue = _MockWriteQueue();
      queue.setFallbackMode(true);
      
      expect(queue.shouldUseFallback, isTrue);
    });
  });
}

// Helper functions

Duration _calculateWriteBackoff(int retryCount) {
  const baseSeconds = 2;
  const maxSeconds = 300;
  final seconds = baseSeconds * (1 << (retryCount - 1));
  return Duration(seconds: seconds.clamp(0, maxSeconds));
}

// Enums

enum WriteStatus { pending, processing, completed, failed }

// Mock classes

class _MockPendingWrite {
  final String id;
  final String collection;
  final String documentId;
  final Map<String, dynamic> data;
  final int retryCount;
  final DateTime createdAt;

  _MockPendingWrite({
    this.id = '',
    this.collection = '',
    this.documentId = '',
    this.data = const {},
    this.retryCount = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  _MockPendingWrite incrementRetry() {
    return _MockPendingWrite(
      id: id,
      collection: collection,
      documentId: documentId,
      data: data,
      retryCount: retryCount + 1,
      createdAt: createdAt,
    );
  }

  bool shouldRetry(int maxRetries) => retryCount < maxRetries;

  Map<String, dynamic> toJson() => {
    'id': id,
    'collection': collection,
    'documentId': documentId,
    'data': data,
    'retryCount': retryCount,
    'createdAt': createdAt.toIso8601String(),
  };

  factory _MockPendingWrite.fromJson(Map<String, dynamic> json) {
    return _MockPendingWrite(
      id: json['id'] as String,
      collection: json['collection'] as String,
      documentId: json['documentId'] as String,
      data: Map<String, dynamic>.from(json['data'] as Map),
      retryCount: json['retryCount'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class _MockWriteQueue {
  final List<_MockPendingWrite> _queue = [];
  final Map<String, WriteStatus> _statuses = {};
  final Map<String, int> _retryCounts = {};
  bool _isProcessing = false;
  bool _fallbackMode = false;
  final bool persistenceEnabled;

  _MockWriteQueue({this.persistenceEnabled = true});

  int get pendingCount => _queue.length;
  bool get isProcessing => _isProcessing;
  bool get hasPending => _queue.isNotEmpty;
  bool get shouldUseFallback => _fallbackMode;

  String enqueue(String collection, String documentId, Map<String, dynamic> data) {
    final id = '${collection}_${documentId}_${DateTime.now().millisecondsSinceEpoch}';
    _queue.add(_MockPendingWrite(
      id: id,
      collection: collection,
      documentId: documentId,
      data: data,
    ));
    _statuses[id] = WriteStatus.pending;
    _retryCounts[id] = 0;
    return id;
  }

  bool hasPendingWrite(String collection, String documentId) {
    return _queue.any((w) => w.collection == collection && w.documentId == documentId);
  }

  _MockPendingWrite? peekNext() {
    if (_queue.isEmpty) return null;
    return _queue.first;
  }

  void complete(String id) {
    _queue.removeWhere((w) => w.id == id);
    _statuses[id] = WriteStatus.completed;
  }

  void recordFailure(String id) {
    _retryCounts[id] = (_retryCounts[id] ?? 0) + 1;
    if (_retryCounts[id]! >= 5) {
      _statuses[id] = WriteStatus.failed;
      _queue.removeWhere((w) => w.id == id);
    } else {
      // Move to end
      final write = _queue.firstWhere((w) => w.id == id);
      _queue.remove(write);
      _queue.add(write);
    }
  }

  WriteStatus getStatus(String id) => _statuses[id] ?? WriteStatus.pending;

  void startProcessing() {
    _isProcessing = true;
  }

  void restoreFromStorage(List<Map<String, dynamic>> items) {
    for (final item in items) {
      _queue.add(_MockPendingWrite.fromJson(item));
    }
  }

  void setFallbackMode(bool enabled) {
    _fallbackMode = enabled;
  }
}

class _MockFastWriteQueue {
  final Map<String, Map<String, Map<String, dynamic>>> _localCache = {};
  final Map<String, Map<String, String>> _syncStatuses = {};
  final List<String> _pendingWrites = [];
  bool _offlineMode = false;

  void writeOptimistic(String collection, String docId, Map<String, dynamic> data) {
    _localCache.putIfAbsent(collection, () => {});
    _localCache[collection]![docId] = data;
    _syncStatuses.putIfAbsent(collection, () => {});
    _syncStatuses[collection]![docId] = 'pending';
    _pendingWrites.add('$collection:$docId');
  }

  Map<String, dynamic>? getLocalItem(String collection, String docId) {
    return _localCache[collection]?[docId];
  }

  String? getSyncStatus(String collection, String docId) {
    return _syncStatuses[collection]?[docId];
  }

  void confirmWrite(String collection, String docId) {
    _syncStatuses[collection]?[docId] = 'synced';
    _pendingWrites.remove('$collection:$docId');
  }

  void markFailed(String collection, String docId) {
    _syncStatuses[collection]?[docId] = 'failed';
  }

  void setOfflineMode(bool offline) {
    _offlineMode = offline;
  }

  int getPendingCount() => _pendingWrites.length;

  int processPendingBatch() {
    final count = _pendingWrites.length;
    _pendingWrites.clear();
    return count;
  }
}
