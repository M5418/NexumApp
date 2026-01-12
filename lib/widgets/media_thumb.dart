import 'dart:io' show File;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

enum MediaType { image, video }

class MediaThumb extends StatefulWidget {
  final String? imageUrl;
  final String? videoThumbnailUrl;
  final String? videoPath; // Local video path for preview
  final MediaType type;
  final VoidCallback? onRemove;
  final double width;
  final double height;
  final double borderRadius;

  const MediaThumb({
    super.key,
    this.imageUrl,
    this.videoThumbnailUrl,
    this.videoPath,
    required this.type,
    this.onRemove,
    this.width = 120,
    this.height = 160,
    this.borderRadius = 16,
  });

  @override
  State<MediaThumb> createState() => _MediaThumbState();
}

class _MediaThumbState extends State<MediaThumb> {
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideoIfNeeded();
  }

  @override
  void didUpdateWidget(MediaThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPath != widget.videoPath) {
      _disposeVideo();
      _initVideoIfNeeded();
    }
  }

  void _initVideoIfNeeded() {
    debugPrint('🎬 MediaThumb._initVideoIfNeeded: type=${widget.type}, videoPath=${widget.videoPath}, thumbnailUrl=${widget.videoThumbnailUrl}');
    
    // Init video player for video type with path
    if (widget.type == MediaType.video && 
        widget.videoPath != null && 
        widget.videoPath!.isNotEmpty) {
      
      final path = widget.videoPath!;
      debugPrint('🎬 Initializing video player for: $path');
      
      // Handle web blob URLs
      if (kIsWeb && (path.startsWith('blob:') || path.startsWith('http'))) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(path))
          ..initialize().then((_) {
            debugPrint('✅ Video player initialized successfully (web)');
            if (mounted) {
              setState(() => _videoInitialized = true);
            }
          }).catchError((e) {
            debugPrint('⚠️ Video preview init failed (web): $e');
          });
      } 
      // Handle mobile local files
      else if (!kIsWeb) {
        final file = File(path);
        if (!file.existsSync()) {
          debugPrint('⚠️ Video file does not exist: $path');
          return;
        }
        _videoController = VideoPlayerController.file(file)
          ..initialize().then((_) {
            debugPrint('✅ Video player initialized successfully (mobile)');
            if (mounted) {
              setState(() => _videoInitialized = true);
            }
          }).catchError((e) {
            debugPrint('⚠️ Video preview init failed (mobile): $e');
          });
      }
    }
  }

  void _disposeVideo() {
    _videoController?.dispose();
    _videoController = null;
    _videoInitialized = false;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        color: Colors.grey[200],
      ),
      child: Stack(
        children: [
          // Media content
          ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: widget.type == MediaType.image
                  ? _buildImageContent()
                  : _buildVideoContent(),
            ),
          ),

          // Video play overlay
          if (widget.type == MediaType.video)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  color: Colors.black.withValues(alpha: 0.3),
                ),
                child: const Center(
                  child: Icon(Icons.play_arrow, color: Colors.white, size: 40),
                ),
              ),
            ),

          // Remove button
          if (widget.onRemove != null)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: widget.onRemove,
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
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      final url = widget.imageUrl!;
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
    // Always try video player preview first for local videos (most reliable)
    if (_videoInitialized && _videoController != null) {
      return _buildVideoPlayerPreview();
    }
    
    // Try thumbnail URL while video is loading
    if (widget.videoThumbnailUrl != null && widget.videoThumbnailUrl!.isNotEmpty) {
      final url = widget.videoThumbnailUrl!;
      
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
      
      // Handle local file paths (mobile) - thumbnail image
      if (!kIsWeb) {
        final file = File(url);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => _buildPlaceholder(),
          );
        }
      }
    }

    // Fallback to placeholder
    return _buildPlaceholder();
  }

  Widget _buildVideoPlayerPreview() {
    // Show video player first frame if initialized
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: _videoController!.value.size.width,
        height: _videoController!.value.size.height,
        child: VideoPlayer(_videoController!),
      ),
    );
  }

  Widget _buildPlaceholder() {
    // Placeholder for no/unsupported thumbnail - show video icon with dark background
    return Container(
      color: const Color(0xFF2C2C2E),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'Video',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}