import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';

import '../core/i18n/language_provider.dart';

/// Web-friendly video trimmer that uses video_player and a custom range selector.
/// Returns a map with 'startMs' and 'endMs' for the selected trim range.
class StoryVideoTrimmerWebPage extends StatefulWidget {
  final String videoUrl;
  final Duration videoDuration;
  final Duration maxDuration;

  const StoryVideoTrimmerWebPage({
    super.key,
    required this.videoUrl,
    required this.videoDuration,
    this.maxDuration = const Duration(seconds: 30),
  });

  @override
  State<StoryVideoTrimmerWebPage> createState() => _StoryVideoTrimmerWebPageState();
}

class _StoryVideoTrimmerWebPageState extends State<StoryVideoTrimmerWebPage> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _isPlaying = false;
  
  double _startValue = 0.0; // Start position in milliseconds
  double _endValue = 30000.0; // End position in milliseconds (default 30s)
  double _currentPosition = 0.0;
  
  @override
  void initState() {
    super.initState();
    _initVideo();
  }
  
  Future<void> _initVideo() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller = controller;
    
    try {
      await controller.initialize();
      
      // Set end value to min of video duration or max duration
      final videoMs = controller.value.duration.inMilliseconds.toDouble();
      final maxMs = widget.maxDuration.inMilliseconds.toDouble();
      _endValue = videoMs > maxMs ? maxMs : videoMs;
      
      // Listen to position updates
      controller.addListener(_onVideoUpdate);
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
  
  void _onVideoUpdate() {
    if (!mounted || _controller == null) return;
    
    final position = _controller!.value.position.inMilliseconds.toDouble();
    setState(() {
      _currentPosition = position;
      _isPlaying = _controller!.value.isPlaying;
    });
    
    // Loop within selected range
    if (position >= _endValue) {
      _controller!.seekTo(Duration(milliseconds: _startValue.toInt()));
    }
  }
  
  @override
  void dispose() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    super.dispose();
  }
  
  String _formatDuration(double ms) {
    final d = Duration(milliseconds: ms.toInt());
    String two(int n) => n.toString().padLeft(2, '0');
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return '$m:$s';
  }
  
  void _togglePlayPause() {
    if (_controller == null) return;
    
    if (_isPlaying) {
      _controller!.pause();
    } else {
      // Start from selection start if at end
      if (_currentPosition >= _endValue || _currentPosition < _startValue) {
        _controller!.seekTo(Duration(milliseconds: _startValue.toInt()));
      }
      _controller!.play();
    }
  }
  
  void _onStartChanged(double value) {
    setState(() {
      _startValue = value;
      // Ensure end is at least startValue + some minimum
      if (_endValue - _startValue > widget.maxDuration.inMilliseconds) {
        _endValue = _startValue + widget.maxDuration.inMilliseconds;
      }
      if (_endValue <= _startValue) {
        _endValue = _startValue + 1000; // At least 1 second
      }
    });
    _controller?.seekTo(Duration(milliseconds: _startValue.toInt()));
  }
  
  void _onEndChanged(double value) {
    setState(() {
      _endValue = value;
      // Ensure selection doesn't exceed max duration
      if (_endValue - _startValue > widget.maxDuration.inMilliseconds) {
        _startValue = _endValue - widget.maxDuration.inMilliseconds;
        if (_startValue < 0) _startValue = 0;
      }
      if (_endValue <= _startValue) {
        _startValue = _endValue - 1000;
        if (_startValue < 0) _startValue = 0;
      }
    });
  }
  
  void _onDone() {
    Navigator.pop(context, {
      'startMs': _startValue.toInt(),
      'endMs': _endValue.toInt(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    final videoMs = _controller?.value.duration.inMilliseconds.toDouble() ?? widget.videoDuration.inMilliseconds.toDouble();
    final selectedDuration = Duration(milliseconds: (_endValue - _startValue).toInt());
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.t('story.trim_video'),
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _onDone,
              child: Text(
                lang.t('story.done'),
                style: GoogleFonts.inter(
                  color: const Color(0xFFBFAE01),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFBFAE01)),
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  // Video preview
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _controller?.value.aspectRatio ?? 9 / 16,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(_controller!),
                            
                            // Play/Pause button overlay
                            GestureDetector(
                              onTap: _togglePlayPause,
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Duration info
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        Text(
                          '${lang.t('story.selected')}: ${_formatDuration(selectedDuration.inMilliseconds.toDouble())}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${lang.t('story.max_duration')}: ${_formatDuration(widget.maxDuration.inMilliseconds.toDouble())}',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF666666),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Custom range slider for trimming
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // Visual timeline with selection
                        Container(
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFF333333),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            children: [
                              // Selected range highlight
                              Positioned(
                                left: ((_startValue / videoMs) * (MediaQuery.of(context).size.width - 32)).clamp(0.0, MediaQuery.of(context).size.width - 32),
                                right: ((1 - _endValue / videoMs) * (MediaQuery.of(context).size.width - 32)).clamp(0.0, MediaQuery.of(context).size.width - 32),
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFBFAE01).withValues(alpha: 0.3),
                                    border: Border.all(color: const Color(0xFFBFAE01), width: 3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              
                              // Current position indicator
                              if (_currentPosition >= _startValue && _currentPosition <= _endValue)
                                Positioned(
                                  left: ((_currentPosition / videoMs) * (MediaQuery.of(context).size.width - 32)).clamp(0.0, MediaQuery.of(context).size.width - 34),
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 2,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Start slider
                        Row(
                          children: [
                            SizedBox(
                              width: 50,
                              child: Text(
                                lang.t('story.start'),
                                style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: const Color(0xFFBFAE01),
                                  inactiveTrackColor: const Color(0xFF444444),
                                  thumbColor: const Color(0xFFBFAE01),
                                  overlayColor: const Color(0xFFBFAE01).withValues(alpha: 0.2),
                                ),
                                child: Slider(
                                  value: _startValue,
                                  min: 0,
                                  max: videoMs - 1000, // Leave at least 1s for selection
                                  onChanged: _onStartChanged,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 50,
                              child: Text(
                                _formatDuration(_startValue),
                                style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                        
                        // End slider
                        Row(
                          children: [
                            SizedBox(
                              width: 50,
                              child: Text(
                                lang.t('story.end'),
                                style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                              ),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: const Color(0xFFBFAE01),
                                  inactiveTrackColor: const Color(0xFF444444),
                                  thumbColor: const Color(0xFFBFAE01),
                                  overlayColor: const Color(0xFFBFAE01).withValues(alpha: 0.2),
                                ),
                                child: Slider(
                                  value: _endValue,
                                  min: 1000, // At least 1s
                                  max: videoMs,
                                  onChanged: _onEndChanged,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 50,
                              child: Text(
                                _formatDuration(_endValue),
                                style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Instructions
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBFAE01).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Color(0xFFBFAE01),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              lang.t('story.trim_instructions_web'),
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
