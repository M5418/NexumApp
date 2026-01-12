import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_trimmer/video_trimmer.dart';
import 'package:provider/provider.dart';

import '../core/i18n/language_provider.dart';

/// A page that allows users to trim videos to a maximum of 30 seconds for stories.
/// Returns the trimmed video file path or null if cancelled.
class StoryVideoTrimmerPage extends StatefulWidget {
  final File videoFile;
  final Duration maxDuration;

  const StoryVideoTrimmerPage({
    super.key,
    required this.videoFile,
    this.maxDuration = const Duration(seconds: 30),
  });

  @override
  State<StoryVideoTrimmerPage> createState() => _StoryVideoTrimmerPageState();
}

class _StoryVideoTrimmerPageState extends State<StoryVideoTrimmerPage> {
  final Trimmer _trimmer = Trimmer();
  
  double _startValue = 0.0;
  double _endValue = 0.0;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _isSaving = false;
  
  Duration _videoDuration = Duration.zero;
  Duration _selectedDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    try {
      await _trimmer.loadVideo(videoFile: widget.videoFile);
      
      // Get video duration
      final videoPlayer = _trimmer.videoPlayerController;
      if (videoPlayer != null) {
        _videoDuration = videoPlayer.value.duration;
        
        // Set initial end value to max 30 seconds
        final maxMs = widget.maxDuration.inMilliseconds.toDouble();
        final videoMs = _videoDuration.inMilliseconds.toDouble();
        _endValue = videoMs > maxMs ? maxMs : videoMs;
        _selectedDuration = Duration(milliseconds: _endValue.toInt());
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading video for trimming: $e');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _trimmer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return '$m:$s';
  }

  Future<void> _saveVideo() async {
    if (_isSaving) return;
    
    setState(() => _isSaving = true);
    
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(lang.t('story.trimming_video'), style: GoogleFonts.inter()),
        backgroundColor: const Color(0xFFBFAE01),
      ),
    );

    try {
      await _trimmer.saveTrimmedVideo(
        startValue: _startValue,
        endValue: _endValue,
        onSave: (outputPath) {
          if (!mounted) return;
          
          setState(() => _isSaving = false);
          
          if (outputPath != null) {
            Navigator.pop(context, outputPath);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(lang.t('story.trim_failed'), style: GoogleFonts.inter()),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${lang.t('story.trim_failed')}: $e', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    
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
          if (!_isLoading && !_isSaving)
            TextButton(
              onPressed: _saveVideo,
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
                        aspectRatio: 9 / 16,
                        child: Container(
                          color: Colors.black,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoViewer(trimmer: _trimmer),
                              
                              // Play/Pause button overlay
                              GestureDetector(
                                onTap: () async {
                                  final playing = await _trimmer.videoPlaybackControl(
                                    startValue: _startValue,
                                    endValue: _endValue,
                                  );
                                  setState(() => _isPlaying = playing);
                                },
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
                  ),
                  
                  // Duration info
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        Text(
                          '${lang.t('story.selected')}: ${_formatDuration(_selectedDuration)}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${lang.t('story.max_duration')}: ${_formatDuration(widget.maxDuration)}',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF666666),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Trimmer timeline
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TrimViewer(
                      trimmer: _trimmer,
                      viewerHeight: 60,
                      viewerWidth: MediaQuery.of(context).size.width - 32,
                      maxVideoLength: widget.maxDuration,
                      onChangeStart: (value) {
                        setState(() {
                          _startValue = value;
                          _selectedDuration = Duration(
                            milliseconds: (_endValue - _startValue).toInt(),
                          );
                        });
                      },
                      onChangeEnd: (value) {
                        setState(() {
                          _endValue = value;
                          _selectedDuration = Duration(
                            milliseconds: (_endValue - _startValue).toInt(),
                          );
                        });
                      },
                      onChangePlaybackState: (value) {
                        setState(() => _isPlaying = value);
                      },
                      editorProperties: TrimEditorProperties(
                        borderPaintColor: const Color(0xFFBFAE01),
                        borderWidth: 4,
                        borderRadius: 8,
                        circlePaintColor: const Color(0xFFBFAE01),
                      ),
                      areaProperties: TrimAreaProperties.edgeBlur(
                        thumbnailQuality: 25,
                      ),
                    ),
                  ),
                  
                  // Time markers
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(Duration(milliseconds: _startValue.toInt())),
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          _formatDuration(Duration(milliseconds: _endValue.toInt())),
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
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
                              lang.t('story.trim_instructions'),
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
