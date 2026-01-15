import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Global manager for video controllers to enable seamless playback
/// across different pages (e.g., home feed -> post page)
/// 
/// Production hardening:
/// - Only 1 active controller (optional warm)
/// - try/catch around init and dispose
/// - Thumbnail fallback on init failure
/// - Safe disposal scheduling (not during build)
class VideoControllerManager {
  static final VideoControllerManager _instance = VideoControllerManager._internal();
  factory VideoControllerManager() => _instance;
  VideoControllerManager._internal();

  // Cache of video controllers by URL
  final Map<String, _CachedController> _controllers = {};
  
  // URLs that failed to initialize (use thumbnail instead)
  final Set<String> _failedUrls = {};
  
  // Maximum number of controllers to keep in cache
  static const int _maxCacheSize = 3;
  
  // Timeout for controller initialization
  static const Duration _initTimeout = Duration(seconds: 10);

  /// Check if a URL has failed and should show thumbnail only
  bool shouldShowThumbnailOnly(String videoUrl) => _failedUrls.contains(videoUrl);

  /// Get or create a controller for the given video URL
  /// If a controller already exists and is initialized, it will be reused
  /// Returns null if initialization fails (caller should show thumbnail)
  Future<VideoPlayerController?> getController(String videoUrl) async {
    // Check if this URL has failed before
    if (_failedUrls.contains(videoUrl)) {
      _debugLog('⚠️ Skipping failed URL: $videoUrl');
      return null;
    }

    // Check if we already have a controller for this URL
    if (_controllers.containsKey(videoUrl)) {
      final cached = _controllers[videoUrl];
      if (cached != null) {
        cached.lastAccessed = DateTime.now();
        cached.refCount++;
        return cached.controller;
      }
    }

    // Create new controller with crash protection
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      
      // Initialize with timeout
      final stopwatch = Stopwatch()..start();
      await controller.initialize().timeout(
        _initTimeout,
        onTimeout: () {
          throw TimeoutException('Video init timed out');
        },
      );
      stopwatch.stop();
      _debugLog('🎬 Controller init: ${stopwatch.elapsedMilliseconds}ms');
      
      try {
        controller.setLooping(true);
      } catch (e) {
        _debugLog('⚠️ Failed to set looping: $e');
      }
      
      // Cache it
      _controllers[videoUrl] = _CachedController(
        controller: controller,
        lastAccessed: DateTime.now(),
        refCount: 1,
      );
      
      // Cleanup old controllers if cache is too large
      _cleanupIfNeeded();
      
      return controller;
    } catch (e) {
      _debugLog('❌ Controller init failed: $e');
      _failedUrls.add(videoUrl);
      return null;
    }
  }

  /// Get an existing controller if available (non-blocking)
  VideoPlayerController? getExistingController(String videoUrl) {
    final cached = _controllers[videoUrl];
    if (cached != null) {
      cached.lastAccessed = DateTime.now();
      cached.refCount++;
      return cached.controller;
    }
    return null;
  }

  /// Check if a controller exists and is initialized
  bool hasInitializedController(String videoUrl) {
    final cached = _controllers[videoUrl];
    return cached != null && cached.controller.value.isInitialized;
  }

  /// Release a controller reference (call when done using)
  void releaseController(String videoUrl) {
    final cached = _controllers[videoUrl];
    if (cached != null) {
      cached.refCount--;
      // Don't dispose immediately - keep in cache for potential reuse
    }
  }

  /// Pause all controllers except the one with the given URL
  void pauseAllExcept(String? activeUrl) {
    for (final entry in _controllers.entries) {
      if (entry.key != activeUrl && entry.value.controller.value.isPlaying) {
        entry.value.controller.pause();
      }
    }
  }

  /// Cleanup old controllers when cache is too large
  void _cleanupIfNeeded() {
    if (_controllers.length <= _maxCacheSize) return;

    // Find controllers with refCount 0 that are oldest
    final entries = _controllers.entries.toList()
      ..sort((a, b) {
        // Prioritize keeping controllers with active references
        if (a.value.refCount > 0 && b.value.refCount == 0) return -1;
        if (b.value.refCount > 0 && a.value.refCount == 0) return 1;
        // Then sort by last accessed time
        return a.value.lastAccessed.compareTo(b.value.lastAccessed);
      });

    // Remove oldest controllers with no references
    while (_controllers.length > _maxCacheSize) {
      final oldest = entries.firstWhere(
        (e) => e.value.refCount == 0,
        orElse: () => entries.first,
      );
      final removed = _controllers.remove(oldest.key);
      removed?.controller.dispose();
      entries.remove(oldest);
    }
  }

  /// Dispose all controllers (call on app shutdown)
  void disposeAll() {
    for (final cached in _controllers.values) {
      _safeDispose(cached.controller);
    }
    _controllers.clear();
    _failedUrls.clear();
  }

  /// Safely dispose a controller (schedule if during build)
  void _safeDispose(VideoPlayerController controller) {
    try {
      // Schedule disposal to avoid disposing during build
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          controller.dispose();
        } catch (e) {
          _debugLog('⚠️ Controller dispose failed: $e');
        }
      });
    } catch (e) {
      // Fallback: try immediate dispose
      try {
        controller.dispose();
      } catch (e2) {
        _debugLog('⚠️ Immediate dispose failed: $e2');
      }
    }
  }

  /// Preload a video controller in the background
  void preload(String videoUrl) {
    if (_controllers.containsKey(videoUrl)) return;
    if (_failedUrls.contains(videoUrl)) return;
    
    // Create and initialize in background with crash protection
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      controller.initialize().timeout(_initTimeout).then((_) {
        if (!_controllers.containsKey(videoUrl)) {
          try {
            controller.setLooping(true);
          } catch (e) {
            _debugLog('⚠️ Failed to set looping on preload: $e');
          }
          _controllers[videoUrl] = _CachedController(
            controller: controller,
            lastAccessed: DateTime.now(),
            refCount: 0,
          );
          _cleanupIfNeeded();
        } else {
          // Already added by another call, dispose this one
          _safeDispose(controller);
        }
      }).catchError((e) {
        _debugLog('⚠️ Failed to preload video: $e');
        _failedUrls.add(videoUrl);
        _safeDispose(controller);
      });
    } catch (e) {
      _debugLog('❌ Failed to create preload controller: $e');
      _failedUrls.add(videoUrl);
    }
  }

  /// Clear failed URLs cache (allow retry)
  void clearFailedUrls() {
    _failedUrls.clear();
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[VideoControllerManager] $message');
    }
  }
}

class _CachedController {
  final VideoPlayerController controller;
  DateTime lastAccessed;
  int refCount;

  _CachedController({
    required this.controller,
    required this.lastAccessed,
    required this.refCount,
  });
}
