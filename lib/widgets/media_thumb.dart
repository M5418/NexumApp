import 'package:flutter/material.dart';
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
    if (imageUrl != null && imageUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[300],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) =>
            Container(color: Colors.grey[300], child: const Icon(Icons.error)),
      );
    }

    // Placeholder for local images or no image
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.image, size: 40, color: Colors.grey),
      ),
    );
  }

  Widget _buildVideoContent() {
    if (videoThumbnailUrl != null && videoThumbnailUrl!.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: videoThumbnailUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[300],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) =>
            Container(color: Colors.grey[300], child: const Icon(Icons.error)),
      );
    }

    // Placeholder for local videos or no thumbnail
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.videocam, size: 40, color: Colors.grey),
      ),
    );
  }
}
