import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path/path.dart' as path;

/// Service for compressing images and videos with high quality settings
/// Reduces file size while maintaining visual quality for faster uploads
class MediaCompressionService {
  static final MediaCompressionService _instance = MediaCompressionService._internal();
  factory MediaCompressionService() => _instance;
  MediaCompressionService._internal();

  /// Compress image with high quality settings
  /// Quality: 92 (excellent quality, minor compression)
  /// Returns compressed bytes or original if compression fails
  Future<Uint8List?> compressImage({
    required String filePath,
    int quality = 92,
    int minWidth = 1920,
    int minHeight = 1920,
  }) async {
    try {
      debugPrint('🖼️ Compressing image: $filePath');
      final originalFile = File(filePath);
      final originalSize = await originalFile.length();
      debugPrint('   Original size: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // Get file extension
      final ext = path.extension(filePath).toLowerCase();
      final format = _getImageFormat(ext);

      // Compress image
      final result = await FlutterImageCompress.compressWithFile(
        filePath,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
        format: format,
        autoCorrectionAngle: true,
        keepExif: false, // Remove EXIF data to reduce size
      );

      if (result == null) {
        debugPrint('   ⚠️ Compression returned null, using original');
        return await originalFile.readAsBytes();
      }

      final compressedSize = result.length;
      final reduction = ((originalSize - compressedSize) / originalSize * 100);
      debugPrint('   ✅ Compressed size: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB');
      debugPrint('   📉 Size reduction: ${reduction.toStringAsFixed(1)}%');

      return result;
    } catch (e) {
      debugPrint('❌ Image compression error: $e');
      // Return original file on error
      try {
        return await File(filePath).readAsBytes();
      } catch (_) {
        return null;
      }
    }
  }

  /// Compress image from bytes
  Future<Uint8List?> compressImageBytes({
    required Uint8List bytes,
    required String filename,
    int quality = 92,
    int minWidth = 1920,
    int minHeight = 1920,
  }) async {
    try {
      debugPrint('🖼️ Compressing image from bytes: $filename');
      final originalSize = bytes.length;
      debugPrint('   Original size: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // Get file extension
      final ext = path.extension(filename).toLowerCase();
      final format = _getImageFormat(ext);

      // Compress image
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
        format: format,
        autoCorrectionAngle: true,
        keepExif: false,
      );

      final compressedSize = result.length;
      final reduction = ((originalSize - compressedSize) / originalSize * 100);
      debugPrint('   ✅ Compressed size: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB');
      debugPrint('   📉 Size reduction: ${reduction.toStringAsFixed(1)}%');

      return result;
    } catch (e) {
      debugPrint('❌ Image compression error: $e');
      return bytes; // Return original on error
    }
  }

  /// Compress video with optimized settings for speed
  /// Quality: VideoQuality.MediumQuality (faster than HighestQuality)
  /// Returns compressed file or original if compression fails/not needed
  Future<File?> compressVideo({
    required String filePath,
    VideoQuality quality = VideoQuality.MediumQuality,
  }) async {
    try {
      debugPrint('🎥 Compressing video: $filePath');
      final originalFile = File(filePath);
      final originalSize = await originalFile.length();
      debugPrint('   Original size: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');

      // Skip compression for small videos (< 20MB) - increased threshold for speed
      if (originalSize < 20 * 1024 * 1024) {
        debugPrint('   ⏭️ Video is small (<20MB), skipping compression');
        return originalFile;
      }

      // Show compression progress
      VideoCompress.compressProgress$.subscribe((progress) {
        debugPrint('   📊 Compression progress: ${progress.toStringAsFixed(1)}%');
      });

      // Compress video with faster settings
      final info = await VideoCompress.compressVideo(
        filePath,
        quality: quality, // Default to MediumQuality for faster compression
        deleteOrigin: false, // Keep original file
        includeAudio: true,
        frameRate: 30, // Limit to 30fps for faster processing
      );

      if (info == null || info.file == null) {
        debugPrint('   ⚠️ Compression returned null, using original');
        return originalFile;
      }

      final compressedSize = await info.file!.length();
      final reduction = ((originalSize - compressedSize) / originalSize * 100);
      debugPrint('   ✅ Compressed size: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)} MB');
      debugPrint('   📉 Size reduction: ${reduction.toStringAsFixed(1)}%');
      debugPrint('   ⏱️ Duration: ${info.duration?.toStringAsFixed(1)}s');

      return info.file!;
    } catch (e) {
      debugPrint('❌ Video compression error: $e');
      // Return original file on error
      return File(filePath);
    }
  }

  /// Get image format from file extension
  CompressFormat _getImageFormat(String ext) {
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return CompressFormat.jpeg;
      case '.png':
        return CompressFormat.png;
      case '.heic':
        return CompressFormat.heic;
      case '.webp':
        return CompressFormat.webp;
      default:
        return CompressFormat.jpeg; // Default to JPEG
    }
  }

  /// Cancel ongoing video compression
  void cancelVideoCompression() {
    try {
      VideoCompress.cancelCompression();
    } catch (e) {
      debugPrint('Error canceling compression: $e');
    }
  }

  /// Delete temporary compressed video
  Future<void> deleteCompressedVideo(String path) async {
    try {
      await VideoCompress.deleteAllCache();
    } catch (e) {
      debugPrint('Error deleting compressed video: $e');
    }
  }

  /// Check if file is an image
  static bool isImage(String filename) {
    final ext = path.extension(filename).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.bmp'].contains(ext);
  }

  /// Check if file is a video
  static bool isVideo(String filename) {
    final ext = path.extension(filename).toLowerCase();
    return ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v'].contains(ext);
  }

  /// Get optimal compression quality based on file size
  /// Larger files get slightly more compression
  int getOptimalImageQuality(int fileSizeBytes) {
    if (fileSizeBytes < 1024 * 1024) {
      // < 1MB: no compression needed
      return 95;
    } else if (fileSizeBytes < 5 * 1024 * 1024) {
      // 1-5MB: light compression
      return 92;
    } else if (fileSizeBytes < 10 * 1024 * 1024) {
      // 5-10MB: moderate compression
      return 88;
    } else {
      // > 10MB: higher compression
      return 85;
    }
  }

  /// Get optimal video quality based on file size
  VideoQuality getOptimalVideoQuality(int fileSizeBytes) {
    if (fileSizeBytes < 50 * 1024 * 1024) {
      // < 50MB: highest quality
      return VideoQuality.HighestQuality;
    } else if (fileSizeBytes < 100 * 1024 * 1024) {
      // 50-100MB: high quality
      return VideoQuality.HighestQuality;
    } else {
      // > 100MB: default quality (still good)
      return VideoQuality.DefaultQuality;
    }
  }

  /// Generate small thumbnail for feed display (400px, 60% quality)
  /// Much smaller than full image for fast feed loading
  Future<Uint8List?> generateFeedThumbnail({
    required String filePath,
    int maxSize = 400,
    int quality = 60,
  }) async {
    try {
      final ext = path.extension(filePath).toLowerCase();
      final format = _getImageFormat(ext);

      final result = await FlutterImageCompress.compressWithFile(
        filePath,
        quality: quality,
        minWidth: maxSize,
        minHeight: maxSize,
        format: format,
        autoCorrectionAngle: true,
        keepExif: false,
      );

      return result;
    } catch (e) {
      debugPrint('❌ Thumbnail generation error: $e');
      return null;
    }
  }

  /// Generate small thumbnail from bytes for feed display
  Future<Uint8List?> generateFeedThumbnailFromBytes({
    required Uint8List bytes,
    required String filename,
    int maxSize = 400,
    int quality = 60,
  }) async {
    try {
      final ext = path.extension(filename).toLowerCase();
      final format = _getImageFormat(ext);

      final result = await FlutterImageCompress.compressWithList(
        bytes,
        quality: quality,
        minWidth: maxSize,
        minHeight: maxSize,
        format: format,
        autoCorrectionAngle: true,
        keepExif: false,
      );

      return result;
    } catch (e) {
      debugPrint('❌ Thumbnail generation error: $e');
      return null;
    }
  }
}
