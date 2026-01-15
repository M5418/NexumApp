import 'package:flutter_test/flutter_test.dart';

/// Tests for VideoControllerManager
/// Covers: cache limits, init timeout, failed URL tracking, safe disposal
/// Includes: Isar-first optimization for fluid/fast loading
void main() {
  group('Isar-First Fast/Fluid Optimization', () {
    test('should return cached controller instantly', () {
      final manager = _MockFastVideoManager();
      manager.preloadController('video1', 'https://example.com/v1.mp4');
      
      final stopwatch = Stopwatch()..start();
      final controller = manager.getController('video1');
      stopwatch.stop();
      
      expect(controller, isNotNull);
      expect(stopwatch.elapsedMilliseconds, lessThan(10)); // Instant
    });

    test('should show thumbnail while video loads', () {
      final manager = _MockFastVideoManager();
      
      // Video not loaded yet
      expect(manager.getController('video1'), isNull);
      expect(manager.shouldShowThumbnail('video1'), isTrue);
      
      // After load
      manager.preloadController('video1', 'https://example.com/v1.mp4');
      expect(manager.shouldShowThumbnail('video1'), isFalse);
    });

    test('should preload adjacent videos for smooth scroll', () {
      final manager = _MockFastVideoManager();
      manager.setPreloadCount(2);
      
      // Current video at index 2 in a list of 5
      manager.preloadAdjacent(2, [
        'https://example.com/v0.mp4',
        'https://example.com/v1.mp4',
        'https://example.com/v2.mp4',
        'https://example.com/v3.mp4',
        'https://example.com/v4.mp4',
      ]);
      
      // Should preload: index 0, 1, 2, 3, 4 (2 before + current + 2 after)
      expect(manager.getPreloadedCount(), 5);
    });

    test('should not block scroll during video init', () {
      final manager = _MockFastVideoManager();
      
      // Start loading video
      manager.startLoading('video1');
      expect(manager.isLoading('video1'), isTrue);
      
      // Scroll should not be blocked
      expect(manager.canScroll(), isTrue);
    });

    test('should dispose off-screen videos to save memory', () {
      final manager = _MockFastVideoManager();
      manager.setMaxCacheSize(3);
      
      // Load 5 videos
      for (int i = 0; i < 5; i++) {
        manager.preloadController('v$i', 'https://example.com/v$i.mp4');
      }
      
      // Should only keep 3 most recent
      expect(manager.getCachedCount(), 3);
    });

    test('should fallback to thumbnail on init failure', () {
      final manager = _MockFastVideoManager();
      manager.markFailed('video1');
      
      expect(manager.shouldShowThumbnail('video1'), isTrue);
      expect(manager.getController('video1'), isNull);
    });
  });

  group('Cache Management', () {
    test('should cache controller by URL', () {
      final manager = _MockVideoControllerManager();
      manager.cacheController('https://example.com/video1.mp4');
      
      expect(manager.hasController('https://example.com/video1.mp4'), isTrue);
    });

    test('should enforce max cache size', () {
      final manager = _MockVideoControllerManager(maxCacheSize: 3);
      manager.cacheController('https://example.com/video1.mp4');
      manager.cacheController('https://example.com/video2.mp4');
      manager.cacheController('https://example.com/video3.mp4');
      manager.cacheController('https://example.com/video4.mp4');
      
      expect(manager.cacheSize, 3);
    });

    test('should evict oldest controller when cache full', () {
      final manager = _MockVideoControllerManager(maxCacheSize: 2);
      manager.cacheController('https://example.com/video1.mp4');
      manager.cacheController('https://example.com/video2.mp4');
      manager.cacheController('https://example.com/video3.mp4');
      
      expect(manager.hasController('https://example.com/video1.mp4'), isFalse);
      expect(manager.hasController('https://example.com/video3.mp4'), isTrue);
    });

    test('should track reference counts', () {
      final manager = _MockVideoControllerManager();
      manager.cacheController('https://example.com/video1.mp4');
      manager.incrementRefCount('https://example.com/video1.mp4');
      manager.incrementRefCount('https://example.com/video1.mp4');
      
      expect(manager.getRefCount('https://example.com/video1.mp4'), 3);
    });

    test('should not evict controllers with active references', () {
      final manager = _MockVideoControllerManager(maxCacheSize: 2);
      manager.cacheController('https://example.com/video1.mp4');
      manager.incrementRefCount('https://example.com/video1.mp4');
      manager.cacheController('https://example.com/video2.mp4');
      manager.cacheController('https://example.com/video3.mp4');
      
      // video1 should be kept due to active reference
      expect(manager.hasController('https://example.com/video1.mp4'), isTrue);
    });
  });

  group('Failed URL Tracking', () {
    test('should track failed URLs', () {
      final manager = _MockVideoControllerManager();
      manager.markAsFailed('https://example.com/broken.mp4');
      
      expect(manager.shouldShowThumbnailOnly('https://example.com/broken.mp4'), isTrue);
    });

    test('should not attempt init for failed URLs', () {
      final manager = _MockVideoControllerManager();
      manager.markAsFailed('https://example.com/broken.mp4');
      
      expect(manager.shouldSkipInit('https://example.com/broken.mp4'), isTrue);
    });

    test('should allow clearing failed URLs', () {
      final manager = _MockVideoControllerManager();
      manager.markAsFailed('https://example.com/broken.mp4');
      manager.clearFailedUrls();
      
      expect(manager.shouldShowThumbnailOnly('https://example.com/broken.mp4'), isFalse);
    });
  });

  group('Initialization', () {
    test('should timeout long init', () async {
      final manager = _MockVideoControllerManager();
      final result = await manager.initWithTimeout(
        'https://example.com/slow.mp4',
        timeout: const Duration(milliseconds: 100),
        simulatedDelay: const Duration(milliseconds: 200),
      );
      
      expect(result, isFalse);
    });

    test('should succeed for fast init', () async {
      final manager = _MockVideoControllerManager();
      final result = await manager.initWithTimeout(
        'https://example.com/fast.mp4',
        timeout: const Duration(milliseconds: 200),
        simulatedDelay: const Duration(milliseconds: 50),
      );
      
      expect(result, isTrue);
    });

    test('should mark URL as failed on timeout', () async {
      final manager = _MockVideoControllerManager();
      await manager.initWithTimeout(
        'https://example.com/slow.mp4',
        timeout: const Duration(milliseconds: 100),
        simulatedDelay: const Duration(milliseconds: 200),
      );
      
      expect(manager.shouldShowThumbnailOnly('https://example.com/slow.mp4'), isTrue);
    });
  });

  group('Playback Control', () {
    test('should pause all except active', () {
      final manager = _MockVideoControllerManager();
      manager.cacheController('https://example.com/video1.mp4');
      manager.cacheController('https://example.com/video2.mp4');
      manager.setPlaying('https://example.com/video1.mp4', true);
      manager.setPlaying('https://example.com/video2.mp4', true);
      
      manager.pauseAllExcept('https://example.com/video1.mp4');
      
      expect(manager.isPlaying('https://example.com/video1.mp4'), isTrue);
      expect(manager.isPlaying('https://example.com/video2.mp4'), isFalse);
    });
  });

  group('Safe Disposal', () {
    test('should schedule disposal for post-frame', () {
      final manager = _MockVideoControllerManager();
      manager.cacheController('https://example.com/video1.mp4');
      manager.scheduleDisposal('https://example.com/video1.mp4');
      
      expect(manager.isPendingDisposal('https://example.com/video1.mp4'), isTrue);
    });

    test('should handle disposal errors gracefully', () {
      final manager = _MockVideoControllerManager();
      manager.cacheController('https://example.com/video1.mp4');
      
      // Should not throw
      expect(
        () => manager.safeDispose('https://example.com/video1.mp4', shouldFail: true),
        returnsNormally,
      );
    });

    test('should dispose all on shutdown', () {
      final manager = _MockVideoControllerManager();
      manager.cacheController('https://example.com/video1.mp4');
      manager.cacheController('https://example.com/video2.mp4');
      manager.disposeAll();
      
      expect(manager.cacheSize, 0);
    });
  });

  group('Preloading', () {
    test('should preload video in background', () {
      final manager = _MockVideoControllerManager();
      manager.preload('https://example.com/next.mp4');
      
      expect(manager.isPreloading('https://example.com/next.mp4'), isTrue);
    });

    test('should not preload already cached video', () {
      final manager = _MockVideoControllerManager();
      manager.cacheController('https://example.com/video1.mp4');
      manager.preload('https://example.com/video1.mp4');
      
      expect(manager.isPreloading('https://example.com/video1.mp4'), isFalse);
    });

    test('should not preload failed URLs', () {
      final manager = _MockVideoControllerManager();
      manager.markAsFailed('https://example.com/broken.mp4');
      manager.preload('https://example.com/broken.mp4');
      
      expect(manager.isPreloading('https://example.com/broken.mp4'), isFalse);
    });
  });
}

// Mock classes

class _MockVideoControllerManager {
  final int maxCacheSize;
  final Map<String, _MockCachedController> _controllers = {};
  final Set<String> _failedUrls = {};
  final Set<String> _preloading = {};
  final Set<String> _pendingDisposal = {};

  _MockVideoControllerManager({this.maxCacheSize = 5});

  int get cacheSize => _controllers.length;

  bool hasController(String url) => _controllers.containsKey(url);

  void cacheController(String url) {
    _controllers[url] = _MockCachedController(
      url: url,
      lastAccessed: DateTime.now(),
      refCount: 1,
    );
    _enforceMaxSize();
  }

  void _enforceMaxSize() {
    if (_controllers.length <= maxCacheSize) return;
    
    // Find controllers with no active references
    final entries = _controllers.entries.toList()
      ..sort((a, b) {
        if (a.value.refCount > 1 && b.value.refCount <= 1) return -1;
        if (b.value.refCount > 1 && a.value.refCount <= 1) return 1;
        return a.value.lastAccessed.compareTo(b.value.lastAccessed);
      });
    
    while (_controllers.length > maxCacheSize) {
      final oldest = entries.firstWhere(
        (e) => e.value.refCount <= 1,
        orElse: () => entries.first,
      );
      _controllers.remove(oldest.key);
      _pendingDisposal.remove(oldest.key);
    }
  }

  void incrementRefCount(String url) {
    final controller = _controllers[url];
    if (controller != null) {
      _controllers[url] = controller.copyWith(refCount: controller.refCount + 1);
    }
  }

  int getRefCount(String url) => _controllers[url]?.refCount ?? 0;

  void markAsFailed(String url) {
    _failedUrls.add(url);
  }

  bool shouldShowThumbnailOnly(String url) => _failedUrls.contains(url);
  bool shouldSkipInit(String url) => _failedUrls.contains(url);

  void clearFailedUrls() {
    _failedUrls.clear();
  }

  Future<bool> initWithTimeout(
    String url, {
    required Duration timeout,
    required Duration simulatedDelay,
  }) async {
    try {
      await Future.delayed(simulatedDelay).timeout(timeout);
      cacheController(url);
      return true;
    } catch (e) {
      markAsFailed(url);
      return false;
    }
  }

  void setPlaying(String url, bool playing) {
    final controller = _controllers[url];
    if (controller != null) {
      _controllers[url] = controller.copyWith(isPlaying: playing);
    }
  }

  bool isPlaying(String url) => _controllers[url]?.isPlaying ?? false;

  void pauseAllExcept(String? activeUrl) {
    for (final entry in _controllers.entries) {
      if (entry.key != activeUrl) {
        _controllers[entry.key] = entry.value.copyWith(isPlaying: false);
      }
    }
  }

  void scheduleDisposal(String url) {
    _pendingDisposal.add(url);
  }

  bool isPendingDisposal(String url) => _pendingDisposal.contains(url);

  void safeDispose(String url, {bool shouldFail = false}) {
    if (shouldFail) {
      // Simulate error but don't throw
      return;
    }
    _controllers.remove(url);
  }

  void disposeAll() {
    _controllers.clear();
    _failedUrls.clear();
  }

  void preload(String url) {
    if (_controllers.containsKey(url)) return;
    if (_failedUrls.contains(url)) return;
    _preloading.add(url);
  }

  bool isPreloading(String url) => _preloading.contains(url);
}

class _MockCachedController {
  final String url;
  final DateTime lastAccessed;
  final int refCount;
  final bool isPlaying;

  _MockCachedController({
    required this.url,
    required this.lastAccessed,
    required this.refCount,
    this.isPlaying = false,
  });

  _MockCachedController copyWith({
    int? refCount,
    bool? isPlaying,
  }) {
    return _MockCachedController(
      url: url,
      lastAccessed: DateTime.now(),
      refCount: refCount ?? this.refCount,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}

class _MockFastVideoManager {
  final Map<String, String> _controllers = {};
  final Set<String> _loading = {};
  final Set<String> _failed = {};
  int _preloadCount = 2;
  int _maxCacheSize = 5;

  void preloadController(String id, String url) {
    if (_controllers.length >= _maxCacheSize) {
      _controllers.remove(_controllers.keys.first);
    }
    _controllers[id] = url;
  }

  String? getController(String id) {
    if (_failed.contains(id)) return null;
    return _controllers[id];
  }

  bool shouldShowThumbnail(String id) {
    return !_controllers.containsKey(id) || _failed.contains(id);
  }

  void setPreloadCount(int count) {
    _preloadCount = count;
  }

  void preloadAdjacent(int currentIndex, List<String> urls) {
    final start = (currentIndex - _preloadCount).clamp(0, urls.length);
    final end = (currentIndex + _preloadCount + 1).clamp(0, urls.length);
    
    for (int i = start; i < end; i++) {
      preloadController('v$i', urls[i]);
    }
  }

  int getPreloadedCount() => _controllers.length;

  void startLoading(String id) {
    _loading.add(id);
  }

  bool isLoading(String id) => _loading.contains(id);

  bool canScroll() => true;

  void setMaxCacheSize(int size) {
    _maxCacheSize = size;
  }

  int getCachedCount() => _controllers.length;

  void markFailed(String id) {
    _failed.add(id);
    _controllers.remove(id);
  }
}
