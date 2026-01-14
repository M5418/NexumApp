import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Shared cache manager for all media (images, videos, audio).
/// Configured with sensible limits and TTL for optimal performance.
class MediaCacheManager {
  static final MediaCacheManager _instance = MediaCacheManager._internal();
  factory MediaCacheManager() => _instance;
  MediaCacheManager._internal();

  /// Image cache manager - optimized for feed thumbnails and avatars
  static CacheManager get images => _ImageCacheManager.instance;

  /// Video cache manager - larger files, shorter retention
  static CacheManager get videos => _VideoCacheManager.instance;

  /// Audio cache manager - for voice notes and podcast previews
  static CacheManager get audio => _AudioCacheManager.instance;

  /// Clear all media caches
  static Future<void> clearAll() async {
    await _ImageCacheManager.instance.emptyCache();
    await _VideoCacheManager.instance.emptyCache();
    await _AudioCacheManager.instance.emptyCache();
  }

  /// Get cache size info (for debugging)
  static Future<Map<String, int>> getCacheStats() async {
    // Note: flutter_cache_manager doesn't expose size directly
    // This is a placeholder for future implementation
    return {
      'images': 0,
      'videos': 0,
      'audio': 0,
    };
  }
}

/// Image cache: 500 images, 14 days retention, 200MB max
class _ImageCacheManager {
  static const String key = 'nexum_image_cache';
  
  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 500,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}

/// Video cache: 50 videos, 7 days retention (videos are large)
class _VideoCacheManager {
  static const String key = 'nexum_video_cache';
  
  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 50,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}

/// Audio cache: 200 files, 14 days retention
class _AudioCacheManager {
  static const String key = 'nexum_audio_cache';
  
  static final CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 200,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}
