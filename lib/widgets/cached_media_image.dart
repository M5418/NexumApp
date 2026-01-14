import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/media_cache_manager.dart';

/// Optimized cached image widget using shared cache manager.
/// Use this instead of CachedNetworkImage directly for consistent caching.
class CachedMediaImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final Color? color;
  final BlendMode? colorBlendMode;
  final int? memCacheWidth;
  final int? memCacheHeight;

  const CachedMediaImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.color,
    this.colorBlendMode,
    this.memCacheWidth,
    this.memCacheHeight,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return errorWidget ?? _defaultError();
    }

    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: MediaCacheManager.images,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      color: color,
      colorBlendMode: colorBlendMode,
      placeholder: (context, url) => placeholder ?? _defaultPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _defaultError(),
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: const Duration(milliseconds: 150),
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _defaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[800],
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
          ),
        ),
      ),
    );
  }

  Widget _defaultError() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[900],
      child: const Icon(
        Icons.broken_image_outlined,
        color: Colors.white38,
        size: 24,
      ),
    );
  }
}

/// Avatar-specific cached image with circular clipping
class CachedAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Widget? placeholder;
  final Color? backgroundColor;

  const CachedAvatar({
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.placeholder,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl ?? '';
    final size = radius * 2;

    if (url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: backgroundColor ?? Colors.grey[700],
        child: placeholder ?? Icon(
          Icons.person,
          size: radius,
          color: Colors.white54,
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        cacheManager: MediaCacheManager.images,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: (size * 2).toInt(), // 2x for retina
        memCacheHeight: (size * 2).toInt(),
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor ?? Colors.grey[700],
          child: const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
            ),
          ),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: backgroundColor ?? Colors.grey[700],
          child: placeholder ?? Icon(
            Icons.person,
            size: radius,
            color: Colors.white54,
          ),
        ),
        fadeInDuration: const Duration(milliseconds: 100),
        fadeOutDuration: const Duration(milliseconds: 100),
      ),
    );
  }
}

/// Thumbnail image optimized for feed lists (smaller cache size)
class CachedThumbnail extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const CachedThumbnail({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: Colors.grey[900],
      );
    }

    Widget image = CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: MediaCacheManager.images,
      width: width,
      height: height,
      fit: fit,
      // Limit memory cache size for thumbnails
      memCacheWidth: 400,
      memCacheHeight: 400,
      placeholder: (context, url) => Container(
        width: width,
        height: height,
        color: Colors.grey[800],
      ),
      errorWidget: (context, url, error) => Container(
        width: width,
        height: height,
        color: Colors.grey[900],
        child: const Icon(Icons.broken_image_outlined, color: Colors.white38),
      ),
      fadeInDuration: const Duration(milliseconds: 100),
      fadeOutDuration: const Duration(milliseconds: 100),
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }
}
