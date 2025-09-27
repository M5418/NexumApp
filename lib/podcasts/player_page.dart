import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

import 'podcasts_home_page.dart' show Podcast;
import 'podcasts_api.dart';

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
  Duration _duration = const Duration(seconds: 1);
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
        final api = PodcastsApi.create();
        final res = await api.getProgress(widget.podcast.id);
        final data = Map<String, dynamic>.from(res);
        final d = Map<String, dynamic>.from(data['data'] ?? {});
        final p = d['progress'];
        if (p != null) {
          final lastPos = int.tryParse((p['last_position_sec'] ?? 0).toString()) ?? 0;
          if (lastPos > 0) _position = Duration(seconds: lastPos);
          final total = int.tryParse((p['duration_sec'] ?? 0).toString()) ?? 0;
          if (total > 0) _duration = Duration(seconds: total);
        }
      } catch (_) {}

      await _player.setUrl(url);
      if (_duration.inSeconds <= 1) {
        _duration = _player.duration ?? _duration;
      }
      if (_position > Duration.zero) {
        await _player.seek(_position);
      }

      _posSub = _player.positionStream.listen((pos) {
        setState(() => _position = pos);
      });
      _stateSub = _player.playerStateStream.listen((_) => mounted ? setState(() {}) : null);

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

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final secs = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _sendProgress() async {
    try {
      final api = PodcastsApi.create();
      await api.updateAudioProgress(
        id: widget.podcast.id,
        positionSec: _position.inSeconds,
        durationSec: _duration.inSeconds > 0 ? _duration.inSeconds : null,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

    final playing = _player.playerState.playing;
    final totalSeconds = (_duration.inSeconds <= 0 ? 1 : _duration.inSeconds).toDouble();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text('Now Playing', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01)))
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.inter()))
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      ClipRRect(
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
                      const SizedBox(height: 32),
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
                      const SizedBox(height: 40),

                      // Progress bar
                      Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFFBFAE01),
                              inactiveTrackColor: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                              thumbColor: const Color(0xFFBFAE01),
                              overlayColor: const Color(0xFFBFAE01).withValues(alpha: 51),
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            ),
                            child: Slider(
                              value: _position.inSeconds.clamp(0, totalSeconds.toInt()).toDouble(),
                              max: totalSeconds,
                              onChanged: (v) => _seekTo(v),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDuration(_position), style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF666666))),
                                Text(_formatDuration(_duration), style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF666666))),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          GestureDetector(
                            onTap: _changeSpeed,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  if (!isDark)
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 33),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '${_playbackSpeed}x',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black),
                                ),
                              ),
                            ),
                          ),

                          IconButton(
                            onPressed: () => _seekTo((_position.inSeconds - 15).clamp(0, _duration.inSeconds).toDouble()),
                            icon: const Icon(Icons.replay_10, size: 32),
                            color: isDark ? Colors.white : Colors.black,
                          ),

                          GestureDetector(
                            onTap: _togglePlayPause,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(color: Color(0xFFBFAE01), shape: BoxShape.circle),
                              child: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 32),
                            ),
                          ),

                          IconButton(
                            onPressed: () => _seekTo((_position.inSeconds + 15).clamp(0, _duration.inSeconds).toDouble()),
                            icon: const Icon(Icons.forward_10, size: 32),
                            color: isDark ? Colors.white : Colors.black,
                          ),

                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.bookmark_border, size: 28),
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}