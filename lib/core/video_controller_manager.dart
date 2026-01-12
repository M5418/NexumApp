import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart';

/// Global manager for video controllers to enable seamless playback
/// across different pages (e.g., home feed -> post page)
class VideoControllerManager {
  static final VideoControllerManager _instance = VideoControllerManager._internal();
  factory VideoControllerManager() => _instance;
  VideoControllerManager._internal();

  // Cache of video controllers by URL
  final Map<String, _CachedController> _controllers = {};
  
  // Maximum number of controllers to keep in cache
  static const int _maxCacheSize = 5;

  /// Get or create a controller for the given video URL
  /// If a controller already exists and is initialized, it will be reused
  Future<VideoPlayerController> getController(String videoUrl) async {
    // Check if we already have a controller for this URL
    if (_controllers.containsKey(videoUrl)) {
      final cached = _controllers[videoUrl]!;
      cached.lastAccessed = DateTime.now();
      cached.refCount++;
      return cached.controller;
    }

    // Create new controller
    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    
    // Initialize it
    await controller.initialize();
    controller.setLooping(true);
    
    // Cache it
    _controllers[videoUrl] = _CachedController(
      controller: controller,
      lastAccessed: DateTime.now(),
      refCount: 1,
    );
    
    // Cleanup old controllers if cache is too large
    _cleanupIfNeeded();
    
    return controller;
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
      cached.controller.dispose();
    }
    _controllers.clear();
  }

  /// Preload a video controller in the background
  void preload(String videoUrl) {
    if (_controllers.containsKey(videoUrl)) return;
    
    // Create and initialize in background
    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    controller.initialize().then((_) {
      if (!_controllers.containsKey(videoUrl)) {
        controller.setLooping(true);
        _controllers[videoUrl] = _CachedController(
          controller: controller,
          lastAccessed: DateTime.now(),
          refCount: 0,
        );
        _cleanupIfNeeded();
      } else {
        // Already added by another call, dispose this one
        controller.dispose();
      }
    }).catchError((e) {
      debugPrint('Failed to preload video: $e');
      controller.dispose();
    });
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
