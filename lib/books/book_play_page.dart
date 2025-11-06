import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'books_home_page.dart' show Book;
import '../repositories/interfaces/book_repository.dart';

class BookPlayPage extends StatefulWidget {
  final Book book;
  const BookPlayPage({super.key, required this.book});

  @override
  State<BookPlayPage> createState() => _BookPlayPageState();
}

class _BookPlayPageState extends State<BookPlayPage> {
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
    _sendProgress(); // try to persist last position
    super.dispose();
  }

  Future<void> _initPlayer() async {
    final url = (widget.book.audioUrl ?? '').trim();
    if (url.isEmpty) {
      setState(() {
        _error = 'No audio available for this book';
        _loading = false;
      });
      return;
    }

    try {
      // Fetch last progress and seek if available
      try {
        final bookRepo = context.read<BookRepository>();
        final progress = await bookRepo.getProgress(widget.book.id);
        if (progress != null) {
          if (progress.audioProgress != null) {
            _position = progress.audioProgress!;
          }
          // Use book's audio duration if available
          if (widget.book.audioDurationSec != null) {
            _duration = Duration(seconds: widget.book.audioDurationSec!);
          }
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
        setState(() {
          _position = pos;
        });
      });
      _stateSub = _player.playerStateStream.listen((state) {
        if (mounted) setState(() {});
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
    setState(() {
      _position = pos;
    });
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
      final bookRepo = context.read<BookRepository>();
      await bookRepo.updateProgress(
        bookId: widget.book.id,
        audioProgress: _position,
      );
    } catch (_) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width >= 1000;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

    // Make the cover smaller on desktop (right panel) but keep full-width on mobile
    final coverMaxWidth = isWide ? 250.0 : double.infinity;

    final playing = _player.playerState.playing;
    final totalSeconds = (_duration.inSeconds <= 0 ? 1 : _duration.inSeconds).toDouble();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Now Playing',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        ],
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
                              child: (widget.book.coverUrl ?? '').isNotEmpty
                                  ? Image.network(
                                      widget.book.coverUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                                        child: const Center(
                                          child: Icon(Icons.menu_book_outlined, color: Color(0xFFBFAE01), size: 64),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: isDark ? const Color(0xFF111111) : const Color(0xFFEAEAEA),
                                      child: const Center(
                                        child: Icon(Icons.menu_book_outlined, color: Color(0xFFBFAE01), size: 64),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        widget.book.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.book.author ?? 'Unknown',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF666666)),
                      ),
                      const SizedBox(height: 32),

                      // Progress bar
                      Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFFBFAE01),
                              inactiveTrackColor: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
                              thumbColor: const Color(0xFFBFAE01),
                              overlayColor: const Color(0xFFBFAE01).withValues(alpha: 0.2),
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
                                Text(
                                  _formatDuration(_position),
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF666666)),
                                ),
                                Text(
                                  _formatDuration(_duration),
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF666666)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Speed control
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
                                      color: Colors.black.withValues(alpha: 0.13),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '${_playbackSpeed}x',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Previous 15s
                          IconButton(
                            onPressed: () => _seekTo((_position.inSeconds - 15).clamp(0, _duration.inSeconds).toDouble()),
                            icon: const Icon(Icons.replay_10, size: 32),
                            color: isDark ? Colors.white : Colors.black,
                          ),

                          // Play/Pause
                          GestureDetector(
                            onTap: _togglePlayPause,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(color: Color(0xFFBFAE01), shape: BoxShape.circle),
                              child: Icon(playing ? Icons.pause : Icons.play_arrow, color: Colors.black, size: 32),
                            ),
                          ),

                          // Forward 15s
                          IconButton(
                            onPressed: () => _seekTo((_position.inSeconds + 15).clamp(0, _duration.inSeconds).toDouble()),
                            icon: const Icon(Icons.forward_10, size: 32),
                            color: isDark ? Colors.white : Colors.black,
                          ),

                          // Bookmark placeholder
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.bookmark_border, size: 28),
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ],
                      ),

                      const Spacer(),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(onPressed: () {}, icon: const Icon(Icons.timer_outlined), color: isDark ? Colors.white : Colors.black),
                          IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined), color: isDark ? Colors.white : Colors.black),
                          IconButton(onPressed: () {}, icon: const Icon(Icons.playlist_play_outlined), color: isDark ? Colors.white : Colors.black),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}