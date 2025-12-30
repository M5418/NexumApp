import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

import 'podcasts_home_page.dart' show Podcast;
import 'add_to_playlist_sheet.dart';

class PlayerPage extends StatefulWidget {
  final Podcast podcast;
  const PlayerPage({super.key, required this.podcast});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final _player = AudioPlayer();
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;

  bool _loading = true;
  String? _error;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    _sendProgress();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    final url = (widget.podcast.audioUrl ?? '').trim();
    if (url.isEmpty) {
      setState(() {
        _error = 'No audio available';
        _loading = false;
      });
      return;
    }

    try {
      // Try restoring progress
      try {
        // Placeholder: progress will be handled elsewhere
        final d = <String, dynamic>{};
        final p = d['progress'];
        if (p != null) {
          final lastPos = int.tryParse((p['last_position_sec'] ?? 0).toString()) ?? 0;
          if (lastPos > 0) _position = Duration(seconds: lastPos);
          final total = int.tryParse((p['duration_sec'] ?? 0).toString()) ?? 0;
          if (total > 0) _duration = Duration(seconds: total);
        }
      } catch (_) {}

      await _player.setUrl(url);
      
      // Get duration from player, or use podcast's durationSec as fallback
      final playerDuration = _player.duration;
      if (playerDuration != null && playerDuration.inSeconds > 0) {
        _duration = playerDuration;
      } else if (widget.podcast.durationSec != null && widget.podcast.durationSec! > 0) {
        _duration = Duration(seconds: widget.podcast.durationSec!);
      }
      
      if (_position > Duration.zero) {
        await _player.seek(_position);
      }

      _posSub = _player.positionStream.listen((pos) {
        if (mounted) {
          setState(() => _position = pos);
        }
      });
      
      _stateSub = _player.playerStateStream.listen((_) {
        if (mounted) setState(() {});
      });
      
      // Listen to duration changes (for streaming)
      _player.durationStream.listen((duration) {
        if (mounted && duration != null && duration.inSeconds > 0) {
          setState(() => _duration = duration);
        }
      });

      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load audio: $e';
      });
    }
  }

  Future<void> _togglePlayPause() async {
    if (_player.playerState.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
    _sendProgress();
  }

  Future<void> _seekTo(double seconds) async {
    final clamped = seconds.clamp(0, (_duration.inSeconds.toDouble()).clamp(1, 1e9));
    final pos = Duration(seconds: clamped.round());
    await _player.seek(pos);
    setState(() => _position = pos);
    _sendProgress();
  }

  Future<void> _changeSpeed() async {
    if (_playbackSpeed == 1.0) {
      _playbackSpeed = 1.25;
    } else if (_playbackSpeed == 1.25) {
      _playbackSpeed = 1.5;
    } else if (_playbackSpeed == 1.5) {
      _playbackSpeed = 2.0;
    } else {
      _playbackSpeed = 1.0;
    }
    await _player.setSpeed(_playbackSpeed);
    setState(() {});
  }

  void _sendProgress() {
    if (_position.inSeconds <= 0) return;
    // Placeholder: progress tracking will be handled elsewhere
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 1000;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

    // Desktop: limit cover width to 300px
    final coverMaxWidth = isWide ? 300.0 : double.infinity;

    final playing = _player.playerState.playing;

    return Scaffold(
      backgroundColor: bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.black : Colors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
                  ),
                  Expanded(
                    child: Text(
                      'Now Playing',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBFAE01).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFBFAE01).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.podcasts, size: 14, color: Color(0xFFBFAE01)),
                        const SizedBox(width: 4),
                        Text(
                          'AUDIO',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFBFAE01),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01)))
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.inter()))
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: coverMaxWidth),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: (widget.podcast.coverUrl ?? '').isNotEmpty
                                  ? Image.network(
                                      widget.podcast.coverUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                                        child: const Center(child: Icon(Icons.podcasts, color: Color(0xFFBFAE01), size: 64)),
                                      ),
                                    )
                                  : Container(
                                      color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                                      child: const Center(child: Icon(Icons.podcasts, color: Color(0xFFBFAE01), size: 64)),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.podcast.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.podcast.author ?? 'Unknown',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF666666)),
                      ),
                      const SizedBox(height: 32),

                      // Progress bar with audio_video_progress_bar
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: ProgressBar(
                          progress: _position,
                          total: _duration,
                          buffered: _duration,
                          onSeek: (duration) => _player.seek(duration),
                          barHeight: 8,
                          baseBarColor: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0),
                          progressBarColor: const Color(0xFFBFAE01),
                          bufferedBarColor: const Color(0xFFBFAE01).withValues(alpha: 0.3),
                          thumbColor: const Color(0xFFBFAE01),
                          thumbRadius: 10,
                          thumbGlowRadius: 24,
                          thumbGlowColor: const Color(0xFFBFAE01).withValues(alpha: 0.2),
                          timeLabelLocation: TimeLabelLocation.below,
                          timeLabelType: TimeLabelType.totalTime,
                          timeLabelTextStyle: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFBFAE01),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Controls with modern buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Speed control (Circle)
                          GestureDetector(
                            onTap: _changeSpeed,
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '${_playbackSpeed}x',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFBFAE01),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Rewind 10s (Circle)
                          GestureDetector(
                            onTap: () => _seekTo((_position.inSeconds - 10).clamp(0, _duration.inSeconds).toDouble()),
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.replay_10,
                                size: 28,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),

                          const SizedBox(width: 20),

                          // Play/Pause button with gradient (25px radius)
                          GestureDetector(
                            onTap: _togglePlayPause,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFD4C100), Color(0xFFBFAE01)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFBFAE01).withValues(alpha: 0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Icon(
                                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 36,
                              ),
                            ),
                          ),

                          const SizedBox(width: 20),

                          // Forward 10s (Circle)
                          GestureDetector(
                            onTap: () => _seekTo((_position.inSeconds + 10).clamp(0, _duration.inSeconds).toDouble()),
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.forward_10,
                                size: 28,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // Add to Playlist (Circle)
                          GestureDetector(
                            onTap: () => showAddToPlaylistSheet(context, widget.podcast),
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.playlist_add,
                                size: 28,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}