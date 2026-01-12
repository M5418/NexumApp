import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

class AutoPlayVideo extends StatefulWidget {
  final String videoUrl;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap; // Callback when video is tapped (e.g., navigate to post)

  // Global mute controller: toggling this will mute/unmute ALL AutoPlayVideo instances
  static final ValueNotifier<bool> muteNotifier = ValueNotifier<bool>(true);
  static bool get isMuted => muteNotifier.value;
  static void setMuted(bool muted) => muteNotifier.value = muted;
  static void toggleGlobalMute() => setMuted(!isMuted);

  // Global "currently playing" tracker (only one should play at any time)
  static final ValueNotifier<String?> playingNotifier =
      ValueNotifier<String?>(null);
  static String? get currentPlayerId => playingNotifier.value;
  static void setCurrentPlayer(String? id) => playingNotifier.value = id;
  static void ensureCurrent(String id) {
    if (playingNotifier.value != id) {
      playingNotifier.value = id;
    }
  }

  const AutoPlayVideo({
    super.key,
    required this.videoUrl,
    required this.width,
    required this.height,
    this.borderRadius,
    this.onTap,
  });

  @override
  State<AutoPlayVideo> createState() => _AutoPlayVideoState();
}

class _AutoPlayVideoState extends State<AutoPlayVideo> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isVisible = false;

  // Stable id for this instance during runtime
  late final String _id = UniqueKey().toString();

  late VoidCallback _muteListener;
  late VoidCallback _playingListener;

  @override
  void initState() {
    super.initState();
    _initializeVideo();

    // Listen to global mute changes and apply to this controller
    _muteListener = () {
      if (!mounted) return;
      _applyMute();
      setState(() {});
    };
    AutoPlayVideo.muteNotifier.addListener(_muteListener);

    // Listen to the global "who is allowed to play" updates
    _playingListener = () {
      if (!mounted) return;
      _syncWithGlobalPlaying();
      setState(() {});
    };
    AutoPlayVideo.playingNotifier.addListener(_playingListener);
  }

  void _initializeVideo() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          setState(() {
            _isInitialized = true;
          });
          _controller.setLooping(true);
          _controller.setVolume(AutoPlayVideo.isMuted ? 0.0 : 1.0);

          // If this is visible on init, request to become the current player.
          if (_isVisible) {
            AutoPlayVideo.ensureCurrent(_id);
          } else {
            _controller.pause();
          }
        })
        .catchError((error) {
          debugPrint('Video initialization error: $error');
        });
  }

  void _applyMute() {
    if (_isInitialized) {
      _controller.setVolume(AutoPlayVideo.isMuted ? 0.0 : 1.0);
    }
  }

  void _syncWithGlobalPlaying() {
    if (!_isInitialized) return;
    final current = AutoPlayVideo.currentPlayerId;

    if (current == _id) {
      // I am the chosen one. Play only if visible; otherwise keep paused.
      if (_isVisible) {
        if (!_controller.value.isPlaying) {
          _controller.play();
        }
      } else {
        if (_controller.value.isPlaying) {
          _controller.pause();
        }
      }
    } else {
      // Not the chosen one: ensure paused.
      if (_controller.value.isPlaying) {
        _controller.pause();
      }
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return; // Check if widget is still mounted
    
    final nowVisible = info.visibleFraction >= 0.5;
    if (_isVisible != nowVisible) {
      if (!mounted) return; // Double-check before setState
      setState(() {
        _isVisible = nowVisible;
      });
    }

    if (!_isInitialized) return;

    if (nowVisible) {
      // Claim the player slot for this instance.
      AutoPlayVideo.ensureCurrent(_id);
    } else {
      // No longer visible: pause and release the slot if this was current.
      if (_controller.value.isPlaying) {
        _controller.pause();
      }
      if (AutoPlayVideo.currentPlayerId == _id) {
        AutoPlayVideo.setCurrentPlayer(null);
      }
    }
  }

  void _toggleGlobalMute() {
    AutoPlayVideo.toggleGlobalMute(); // this updates ALL feed videos
  }

  void _onTapTogglePlayPause() {
    if (!_isInitialized) return;

    if (_controller.value.isPlaying) {
      _controller.pause();
      // If I was the current player, release the slot.
      if (AutoPlayVideo.currentPlayerId == _id) {
        AutoPlayVideo.setCurrentPlayer(null);
      }
    } else {
      // Request to be the current player (this will pause others).
      AutoPlayVideo.ensureCurrent(_id);
    }
  }

  @override
  void dispose() {
    AutoPlayVideo.muteNotifier.removeListener(_muteListener);
    AutoPlayVideo.playingNotifier.removeListener(_playingListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: _onVisibilityChanged,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(0),
          color: Colors.black,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (_isInitialized)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              )
            else
              Container(
                color: const Color(0xFF666666).withValues(alpha: 51),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFBFAE01),
                    ),
                  ),
                ),
              ),

            // Tap overlay - navigate to post if onTap provided, otherwise toggle play/pause
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onTap ?? _onTapTogglePlayPause,
                child: Container(color: Colors.transparent),
              ),
            ),

            // Global Mute/Unmute button (affects ALL AutoPlayVideo instances)
            Positioned(
              bottom: 12,
              right: 12,
              child: GestureDetector(
                onTap: _toggleGlobalMute,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 128),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    AutoPlayVideo.isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}