import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Optimized cache configuration for better app performance
class CacheConfig {
  /// Configure Flutter's image cache
  static void configureImageCache() {
    // Increase image cache size (default is only 1000 images / 100MB)
    PaintingBinding.instance.imageCache.maximumSize = 500; // More images
    PaintingBinding.instance.imageCache.maximumSizeBytes = 200 * 1024 * 1024; // 200MB
  }

  /// Custom cache manager with longer duration
  static final customCacheManager = CacheManager(
    Config(
      'nexum_cache',
      stalePeriod: const Duration(days: 7), // Keep files for 7 days
      maxNrOfCacheObjects: 500, // Up to 500 files
      repo: JsonCacheInfoRepository(databaseName: 'nexum_cache'),
      fileService: HttpFileService(),
    ),
  );
}
