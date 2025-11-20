import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'core/i18n/language_provider.dart';

class ImageSwipePage extends StatefulWidget {
  final List<String> mediaUrls;
  final int initialIndex;
  final bool isFromChat;

  const ImageSwipePage({
    super.key,
    required this.mediaUrls,
    this.initialIndex = 0,
    this.isFromChat = false,
  });

  @override
  State<ImageSwipePage> createState() => _ImageSwipePageState();
}

class _ImageSwipePageState extends State<ImageSwipePage> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _precacheNeighbors();
  }

  void _showActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _buildActionItem(Icons.download, Provider.of<LanguageProvider>(context, listen: false).t('image.save_to_photos'), () {
                Navigator.pop(context);
                _saveImage();
              }),
              _buildActionItem(Icons.share, Provider.of<LanguageProvider>(context, listen: false).t('image.share'), () {
                Navigator.pop(context);
                _shareImage();
              }),
              _buildActionItem(Icons.report, Provider.of<LanguageProvider>(context, listen: false).t('image.report'), () {
                Navigator.pop(context);
                _reportImage();
              }),
              _buildActionItem(Icons.delete, Provider.of<LanguageProvider>(context, listen: false).t('image.delete'), () {
                Navigator.pop(context);
                _deleteImage();
              }, isDestructive: true),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : Colors.black87),
      title: Text(
        title,
        style: GoogleFonts.inter(
          color: isDestructive ? Colors.red : Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  void _saveImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(Provider.of<LanguageProvider>(context, listen: false).t('image.saved'), style: GoogleFonts.inter()),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _shareImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(Provider.of<LanguageProvider>(context, listen: false).t('image.share_functionality'), style: GoogleFonts.inter()),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _reportImage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(Provider.of<LanguageProvider>(context, listen: false).t('image.reported'), style: GoogleFonts.inter()),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _deleteImage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Provider.of<LanguageProvider>(context, listen: false).t('image.delete_title'), style: GoogleFonts.inter()),
        content: Text(
          Provider.of<LanguageProvider>(context, listen: false).t('image.delete_confirm'),
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(Provider.of<LanguageProvider>(context, listen: false).t('image.cancel'), style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(Provider.of<LanguageProvider>(context, listen: false).t('image.deleted'), style: GoogleFonts.inter()),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: Text(Provider.of<LanguageProvider>(context, listen: false).t('image.delete'), style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white),
            onPressed: _showActionSheet,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main image/video viewer
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: widget.mediaUrls.length,
            itemBuilder: (context, index) {
              final mediaUrl = widget.mediaUrls[index];
              final isVideo = _isVideoUrl(mediaUrl);
              if (isVideo) {
                return Center(
                  child: _RemoteVideoViewer(url: mediaUrl),
                );
              }
              return SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Image.network(
                    mediaUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(Icons.error, color: Colors.white, size: 64),
                      );
                    },
                  ),
                ),
              );
            },
          ),

          // Page indicators
          if (widget.mediaUrls.length > 1)
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      widget.mediaUrls.length,
                      (index) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _currentIndex
                              ? Colors.white
                              : Colors.white.withValues(alpha: 128),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Bottom action buttons
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBottomActionButton(Icons.favorite_border, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        Provider.of<LanguageProvider>(context, listen: false).t('image.added_favorites'),
                        style: GoogleFonts.inter(),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }),
                _buildBottomActionButton(Icons.download, _saveImage),
                _buildBottomActionButton(Icons.share, _shareImage),
                _buildBottomActionButton(Icons.reply, () {
                  Navigator.pop(context, {
                    'action': 'reply',
                    'mediaUrl': widget.mediaUrls[_currentIndex],
                  });
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 128),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.mp4') || lower.contains('.mov') || lower.contains('.webm') || lower.contains('.mkv') || lower.contains('.avi')) {
      return true;
    }
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : uri.path;
      final name = Uri.decodeComponent(last).toLowerCase();
      return name.endsWith('.mp4') || name.endsWith('.mov') || name.endsWith('.webm') || name.endsWith('.mkv') || name.endsWith('.avi');
    }
    return false;
  }

  void _precacheNeighbors() {
    // Preload images for smoother swiping. Videos are skipped.
    final prev = _currentIndex - 1;
    final next = _currentIndex + 1;
    for (final i in [prev, next]) {
      if (i >= 0 && i < widget.mediaUrls.length) {
        final url = widget.mediaUrls[i];
        if (!_isVideoUrl(url)) {
          // ignore: discarded_futures
          precacheImage(NetworkImage(url), context);
        }
      }
    }
  }
}

class _RemoteVideoViewer extends StatefulWidget {
  final String url;

  const _RemoteVideoViewer({required this.url});

  @override
  State<_RemoteVideoViewer> createState() => _RemoteVideoViewerState();
}

class _RemoteVideoViewerState extends State<_RemoteVideoViewer> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _showOverlay = true;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant _RemoteVideoViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _disposeController();
      _init();
    }
  }

  Future<void> _init() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await _controller!.initialize();
      _controller!.setLooping(true);
      await _controller!.setVolume(_muted ? 0.0 : 1.0);
      setState(() {
        _initialized = true;
      });
    } catch (_) {}
  }

  void _disposeController() {
    try {
      _controller?.dispose();
    } catch (_) {}
    _controller = null;
    _initialized = false;
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _togglePlay() {
    if (!_initialized || _controller == null) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() {
      _showOverlay = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showOverlay = false);
    });
  }

  Future<void> _toggleMute() async {
    if (_controller == null) return;
    setState(() => _muted = !_muted);
    await _controller!.setVolume(_muted ? 0.0 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _initialized
        ? (_controller!.value.aspectRatio == 0 ? (9 / 16) : _controller!.value.aspectRatio)
        : (9 / 16);

    return AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        children: [
          Container(
            color: Colors.black,
            child: _initialized && _controller != null
                ? VideoPlayer(_controller!)
                : const Center(child: CircularProgressIndicator()),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _togglePlay,
                child: AnimatedOpacity(
                  opacity: _showOverlay || !(_controller?.value.isPlaying ?? false) ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    color: Colors.black26,
                    child: Center(
                      child: Icon(
                        (_controller?.value.isPlaying ?? false)
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        color: Colors.white,
                        size: 72,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_initialized && _controller != null)
            Positioned(
              top: 8,
              right: 8,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _toggleMute,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    _muted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          if (_initialized && _controller != null)
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                children: [
                  VideoProgressIndicator(
                    _controller!,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Color(0xFF007AFF),
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
