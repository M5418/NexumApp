import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

class CustomVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final bool isLiked;
  final VoidCallback? onLike;
  final VoidCallback? onUnlike;

  // New: startMuted and callback
  final bool startMuted;
  final ValueChanged<bool>? onMuteChanged;
  
  // Long press callback (for reactions in video scroll)
  final VoidCallback? onLongPressCallback;

  const CustomVideoPlayer({
    super.key,
    required this.videoUrl,
    this.isLiked = false,
    this.onLike,
    this.onUnlike,
    this.startMuted = false,
    this.onMuteChanged,
    this.onLongPressCallback,
  });

  @override
  State<CustomVideoPlayer> createState() => CustomVideoPlayerState();
}

class CustomVideoPlayerState extends State<CustomVideoPlayer>
    with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _showSpeedOptions = false;
  double _currentSpeed = 1.0;
  bool _showLikeAnimation = false;
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;

  // New: mute state
  late bool _isMuted;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.startMuted;
    _initializeVideo();
    _likeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _likeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _likeAnimationController,
        curve: Curves.elasticOut,
      ),
    );
  }

  void _initializeVideo() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller!.initialize().then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _controller!.setLooping(true);
        _controller!.setVolume(_isMuted ? 0.0 : 1.0); // apply mute on init
        _controller!.play();
        _controller!.addListener(_videoListener);
      }
    });
  }

  void _videoListener() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    _likeAnimationController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller != null && _isInitialized) {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
    }
  }

  // Public method to toggle play/pause from parent widget
  void togglePlayPause() {
    _togglePlayPause();
  }

  // New: mute toggle
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _controller?.setVolume(_isMuted ? 0.0 : 1.0);
    widget.onMuteChanged?.call(_isMuted);
  }

  void _handleDoubleTap() {
    setState(() {
      _showLikeAnimation = true;
    });
    _likeAnimationController.forward().then((_) {
      _likeAnimationController.reset();
      setState(() {
        _showLikeAnimation = false;
      });
    });

    if (widget.isLiked) {
      widget.onUnlike?.call();
    } else {
      widget.onLike?.call();
    }
  }

  void _handleLongPress() {
    // If external callback provided (e.g., for reactions), use that
    if (widget.onLongPressCallback != null) {
      widget.onLongPressCallback!();
      return;
    }
    
    // Otherwise show speed options
    setState(() {
      _showSpeedOptions = true;
    });
    // Hide speed options after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showSpeedOptions = false;
        });
      }
    });
  }

  void _changeSpeed(double speed) {
    setState(() {
      _currentSpeed = speed;
      _showSpeedOptions = false;
    });
    _controller?.setPlaybackSpeed(speed);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Video player
        GestureDetector(
          onTap: _togglePlayPause,
          onDoubleTap: _handleDoubleTap,
          onLongPress: _handleLongPress,
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),
        ),

        // Progress bar overlay - show when paused
        if (!_controller!.value.isPlaying)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
              padding: const EdgeInsets.only(bottom: 20),
              child: buildProgressBar(),
            ),
          ),

        // Play/Pause indicator
        if (!_controller!.value.isPlaying)
          Center(
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(128),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
          ),

        // New: Mute/Unmute button
        Positioned(
          top: 16,
          right: 16,
          child: GestureDetector(
            onTap: _toggleMute,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(153),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isMuted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),

        // Like animation
        if (_showLikeAnimation)
          Center(
            child: AnimatedBuilder(
              animation: _likeAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _likeAnimation.value,
                  child: Icon(
                    Icons.favorite,
                    color: Colors.red.withAlpha(
                      (1.0 - _likeAnimation.value).toInt(),
                    ),
                    size: 100,
                  ),
                );
              },
            ),
          ),

        // Speed options
        if (_showSpeedOptions)
          Positioned(
            top: 50,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(179),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    'Speed',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...([0.5, 1.0, 1.25, 1.5, 2.0].map((speed) {
                    return GestureDetector(
                      onTap: () => _changeSpeed(speed),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: _currentSpeed == speed
                              ? const Color(0xFFBFAE01)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${speed}x',
                          style: GoogleFonts.inter(
                            color: _currentSpeed == speed
                                ? Colors.black
                                : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList()),
                ],
              ),
            ),
          ),

        // Current speed indicator
        if (_currentSpeed != 1.0)
          Positioned(
            top: 20,
            right: 60,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(128),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentSpeed}x',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget buildProgressBar() {
    if (!_isInitialized || _controller == null) {
      return const SizedBox.shrink();
    }

    final position = _controller!.value.position;
    final duration = _controller!.value.duration;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ProgressBar(
        progress: position,
        total: duration,
        buffered: duration,
        onSeek: (newPosition) => _controller!.seekTo(newPosition),
        barHeight: 4,
        baseBarColor: Colors.white.withAlpha(77),
        progressBarColor: const Color(0xFFBFAE01),
        bufferedBarColor: const Color(0xFFBFAE01).withValues(alpha: 0.3),
        thumbColor: const Color(0xFFBFAE01),
        thumbRadius: 6,
        thumbGlowRadius: 16,
        thumbGlowColor: const Color(0xFFBFAE01).withValues(alpha: 0.3),
        timeLabelLocation: TimeLabelLocation.sides,
        timeLabelType: TimeLabelType.totalTime,
        timeLabelTextStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}