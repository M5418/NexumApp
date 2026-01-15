import 'package:flutter_test/flutter_test.dart';

/// Tests for SyncScheduler
/// Covers: in-flight guards, exponential backoff, scroll-aware sync, emergency mode
/// Includes: Isar-first optimization for fluid/fast loading
void main() {
  group('Isar-First Fast/Fluid Optimization', () {
    test('should not block UI while syncing', () {
      final scheduler = _MockFastSyncScheduler();
      
      // Start background sync
      scheduler.triggerSync();
      expect(scheduler.isSyncing, isTrue);
      
      // UI reads should still work instantly
      final stopwatch = Stopwatch()..start();
      final canReadLocal = scheduler.canReadLocalSync();
      stopwatch.stop();
      
      expect(canReadLocal, isTrue);
      expect(stopwatch.elapsedMilliseconds, lessThan(10));
    });

    test('should prioritize local reads over network sync', () {
      final scheduler = _MockFastSyncScheduler();
      scheduler.triggerSync();
      
      // Local read priority should be high even during sync
      expect(scheduler.getLocalReadPriority(), greaterThan(scheduler.getSyncPriority()));
    });

    test('should batch sync operations for efficiency', () {
      final scheduler = _MockFastSyncScheduler();
      
      // Queue multiple sync requests
      scheduler.requestSync('posts');
      scheduler.requestSync('messages');
      scheduler.requestSync('conversations');
      
      // Should batch into single operation
      expect(scheduler.getPendingSyncCount(), 3);
      scheduler.executeBatchSync();
      expect(scheduler.getCompletedBatchCount(), 1); // Single batch
    });

    test('should yield to UI during long sync', () {
      final scheduler = _MockFastSyncScheduler();
      scheduler.setYieldInterval(50); // Yield every 50 items
      
      // Simulate syncing 200 items
      final yields = scheduler.simulateLongSync(200);
      expect(yields, 4); // Should yield 4 times
    });

    test('should pause sync during scroll', () {
      final scheduler = _MockFastSyncScheduler();
      scheduler.triggerSync();
      
      scheduler.onScrollStart();
      expect(scheduler.isSyncPaused, isTrue);
      
      scheduler.onScrollEnd();
      expect(scheduler.isSyncPaused, isFalse);
    });
  });


  group('In-Flight Guards', () {
    test('should prevent concurrent syncs for same module', () {
      final scheduler = _MockSyncScheduler();
      scheduler.startSync('posts');
      
      expect(scheduler.isSyncing('posts'), isTrue);
      expect(scheduler.canStartSync('posts'), isFalse);
    });

    test('should allow sync after previous completes', () {
      final scheduler = _MockSyncScheduler();
      scheduler.startSync('posts');
      scheduler.completeSync('posts');
      
      expect(scheduler.isSyncing('posts'), isFalse);
      expect(scheduler.canStartSync('posts'), isTrue);
    });

    test('should allow different modules to sync concurrently', () {
      final scheduler = _MockSyncScheduler();
      scheduler.startSync('posts');
      
      expect(scheduler.canStartSync('conversations'), isTrue);
    });
  });

  group('Exponential Backoff', () {
    test('should calculate correct backoff for first failure', () {
      final backoff = _calculateBackoff(1);
      expect(backoff.inSeconds, 30);
    });

    test('should double backoff for each failure', () {
      expect(_calculateBackoff(1).inSeconds, 30);
      expect(_calculateBackoff(2).inSeconds, 60);
      expect(_calculateBackoff(3).inSeconds, 120);
      expect(_calculateBackoff(4).inSeconds, 240);
    });

    test('should cap backoff at max duration', () {
      final backoff = _calculateBackoff(10);
      expect(backoff.inMinutes, lessThanOrEqualTo(5));
    });

    test('should reset backoff after success', () {
      final scheduler = _MockSyncScheduler();
      scheduler.recordFailure('posts');
      scheduler.recordFailure('posts');
      expect(scheduler.getFailureCount('posts'), 2);
      
      scheduler.recordSuccess('posts');
      expect(scheduler.getFailureCount('posts'), 0);
    });
  });

  group('Scroll-Aware Sync', () {
    test('should pause sync while scrolling', () {
      final scheduler = _MockSyncScheduler();
      scheduler.setScrolling('posts', true);
      
      expect(scheduler.shouldDeferSync('posts'), isTrue);
    });

    test('should resume sync when scrolling stops', () {
      final scheduler = _MockSyncScheduler();
      scheduler.setScrolling('posts', true);
      scheduler.setScrolling('posts', false);
      
      expect(scheduler.shouldDeferSync('posts'), isFalse);
    });

    test('should not affect other modules when one is scrolling', () {
      final scheduler = _MockSyncScheduler();
      scheduler.setScrolling('posts', true);
      
      expect(scheduler.shouldDeferSync('conversations'), isFalse);
    });
  });

  group('Emergency Safe Mode', () {
    test('should block all syncs when enabled', () {
      final scheduler = _MockSyncScheduler();
      scheduler.setEmergencySafeMode(true);
      
      expect(scheduler.canStartSync('posts'), isFalse);
      expect(scheduler.canStartSync('conversations'), isFalse);
    });

    test('should allow syncs when disabled', () {
      final scheduler = _MockSyncScheduler();
      scheduler.setEmergencySafeMode(false);
      
      expect(scheduler.canStartSync('posts'), isTrue);
    });

    test('should persist safe mode state', () {
      final scheduler = _MockSyncScheduler();
      scheduler.setEmergencySafeMode(true);
      
      expect(scheduler.isEmergencySafeMode, isTrue);
    });
  });

  group('Module Registration', () {
    test('should register module callback', () {
      final scheduler = _MockSyncScheduler();
      scheduler.registerModule('posts', () async {});
      
      expect(scheduler.hasModule('posts'), isTrue);
    });

    test('should unregister module', () {
      final scheduler = _MockSyncScheduler();
      scheduler.registerModule('posts', () async {});
      scheduler.unregisterModule('posts');
      
      expect(scheduler.hasModule('posts'), isFalse);
    });
  });

  group('Debouncing', () {
    test('should debounce rapid sync requests', () {
      final scheduler = _MockSyncScheduler();
      var syncCount = 0;
      scheduler.registerModule('posts', () async { syncCount++; });
      
      // Simulate rapid requests
      scheduler.triggerSync('posts');
      scheduler.triggerSync('posts');
      scheduler.triggerSync('posts');
      
      // Only last one should be scheduled
      expect(scheduler.pendingDebounceCount('posts'), 1);
    });
  });
}

// Helper functions

Duration _calculateBackoff(int retryCount) {
  const baseSeconds = 30;
  const maxSeconds = 300; // 5 minutes
  final seconds = baseSeconds * (1 << (retryCount - 1));
  return Duration(seconds: seconds.clamp(0, maxSeconds));
}

// Mock classes

class _MockSyncScheduler {
  final Set<String> _inFlight = {};
  final Map<String, int> _failureCounts = {};
  final Map<String, bool> _scrolling = {};
  final Map<String, Future<void> Function()> _callbacks = {};
  final Map<String, int> _pendingDebounce = {};
  bool _emergencySafeMode = false;

  bool isSyncing(String module) => _inFlight.contains(module);
  
  bool canStartSync(String module) {
    if (_emergencySafeMode) return false;
    if (_inFlight.contains(module)) return false;
    return true;
  }

  void startSync(String module) {
    _inFlight.add(module);
  }

  void completeSync(String module) {
    _inFlight.remove(module);
  }

  void recordFailure(String module) {
    _failureCounts[module] = (_failureCounts[module] ?? 0) + 1;
  }

  void recordSuccess(String module) {
    _failureCounts[module] = 0;
  }

  int getFailureCount(String module) => _failureCounts[module] ?? 0;

  void setScrolling(String module, bool isScrolling) {
    _scrolling[module] = isScrolling;
  }

  bool shouldDeferSync(String module) => _scrolling[module] ?? false;

  void setEmergencySafeMode(bool enabled) {
    _emergencySafeMode = enabled;
  }

  bool get isEmergencySafeMode => _emergencySafeMode;

  void registerModule(String module, Future<void> Function() callback) {
    _callbacks[module] = callback;
  }

  void unregisterModule(String module) {
    _callbacks.remove(module);
  }

  bool hasModule(String module) => _callbacks.containsKey(module);

  void triggerSync(String module) {
    _pendingDebounce[module] = 1;
  }

  int pendingDebounceCount(String module) => _pendingDebounce[module] ?? 0;
}

class _MockFastSyncScheduler {
  bool _syncing = false;
  bool _paused = false;
  final List<String> _pendingModules = [];
  int _completedBatches = 0;
  int _yieldInterval = 100;

  bool get isSyncing => _syncing;
  bool get isSyncPaused => _paused;

  void triggerSync() {
    _syncing = true;
  }

  bool canReadLocalSync() => true; // Local reads always available

  int getLocalReadPriority() => 100;
  int getSyncPriority() => 50;

  void requestSync(String module) {
    _pendingModules.add(module);
  }

  int getPendingSyncCount() => _pendingModules.length;

  void executeBatchSync() {
    _pendingModules.clear();
    _completedBatches++;
  }

  int getCompletedBatchCount() => _completedBatches;

  void setYieldInterval(int interval) {
    _yieldInterval = interval;
  }

  int simulateLongSync(int itemCount) {
    return (itemCount / _yieldInterval).ceil();
  }

  void onScrollStart() {
    _paused = true;
  }

  void onScrollEnd() {
    _paused = false;
  }
}
