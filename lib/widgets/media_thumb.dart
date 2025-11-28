import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';

enum MediaType { image, video }

class MediaThumb extends StatelessWidget {
  final String? imageUrl;
  final String? videoThumbnailUrl;
  final MediaType type;
  final VoidCallback? onRemove;
  final double width;
  final double height;
  final double borderRadius;

  const MediaThumb({
    super.key,
    this.imageUrl,
    this.videoThumbnailUrl,
    required this.type,
    this.onRemove,
    this.width = 120,
    this.height = 160,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.grey[200],
      ),
      child: Stack(
        children: [
          // Media content
          ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: SizedBox(
              width: width,
              height: height,
              child: type == MediaType.image
                  ? _buildImageContent()
                  : _buildVideoContent(),
            ),
          ),

          // Video play overlay
          if (type == MediaType.video)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  color: Colors.black.withValues(alpha: 77),
                ),
                child: const Center(
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 40),
                ),
              ),
            ),

          // Remove button
          if (onRemove != null)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageContent() {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      final url = imageUrl!;
      if (url.startsWith('http')) {
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) =>
              Container(color: Colors.grey[300], child: const Icon(Icons.error)),
        );
      }

      // Web: allow blob: and data: URLs so previews work in Chrome
      if (kIsWeb && (url.startsWith('blob:') || url.startsWith('data:'))) {
        return Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(
            color: Colors.grey[300],
            child: const Icon(Icons.error),
          ),
        );
      }
    }

    // Placeholder for unsupported/local paths
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.image, size: 40, color: Colors.grey),
      ),
    );
  }

  Widget _buildVideoContent() {
    if (videoThumbnailUrl != null && videoThumbnailUrl!.isNotEmpty) {
      final url = videoThumbnailUrl!;
      
      // Handle HTTP URLs
      if (url.startsWith('http')) {
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (context, url, error) =>
              Container(color: Colors.grey[300], child: const Icon(Icons.error)),
        );
      }
      
      // Handle web blob/data URLs
      if (kIsWeb && (url.startsWith('blob:') || url.startsWith('data:'))) {
        return Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(
            color: Colors.grey[300],
            child: const Icon(Icons.error),
          ),
        );
      }
      
      // Handle local file paths (mobile)
      if (!kIsWeb) {
        try {
          return Image.file(
            File(url),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => Container(
              color: Colors.grey[300],
              child: const Icon(Icons.error),
            ),
          );
        } catch (e) {
          // If file access fails, show placeholder
        }
      }
    }

    // Placeholder for no/unsupported thumbnail
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.videocam, size: 40, color: Colors.grey),
      ),
    );
  }
}