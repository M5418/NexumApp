import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:provider/provider.dart';
import 'books_home_page.dart' show Book;
import '../repositories/interfaces/book_repository.dart';
import '../core/i18n/language_provider.dart';

class BookPlayPage extends StatefulWidget {
  final Book book;
  const BookPlayPage({super.key, required this.book});

  @override
  State<BookPlayPage> createState() => _BookPlayPageState();
}

class _BookPlayPageState extends State<BookPlayPage> {
  final _player = AudioPlayer();
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
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
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    _sendProgress(); // try to persist last position
    super.dispose();
  }

  Future<void> _initPlayer() async {
    final url = (widget.book.audioUrl ?? '').trim();
    if (url.isEmpty) {
      setState(() {
        _error = Provider.of<LanguageProvider>(context, listen: false).t('books.no_audio');
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
      
      // Listen to duration stream - this is key for getting the real duration
      _durSub = _player.durationStream.listen((dur) {
        if (dur != null && dur.inSeconds > 0 && mounted) {
          setState(() {
            _duration = dur;
          });
        }
      });
      
      // Get initial duration if available
      final initialDuration = _player.duration;
      if (initialDuration != null && initialDuration.inSeconds > 0) {
        _duration = initialDuration;
      }
      
      if (_position > Duration.zero) {
        await _player.seek(_position);
      }

      _posSub = _player.positionStream.listen((pos) {
        if (mounted) {
          setState(() {
            _position = pos;
          });
        }
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
        _error = '${Provider.of<LanguageProvider>(context, listen: false).t('books.failed_load_audio')}: $e';
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

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Text(
          Provider.of<LanguageProvider>(context, listen: false).t('books.now_playing'),
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.playlist_play_outlined)),
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
                        widget.book.author ?? Provider.of<LanguageProvider>(context, listen: false).t('common.unknown'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 16, color: const Color(0xFF666666)),
                      ),
                      // Push content down
                      const Spacer(),

                      // Progress bar (light/dark mode aware)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isDark ? null : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ProgressBar(
                          progress: _position,
                          total: _duration,
                          buffered: _duration,
                          onSeek: (duration) {
                            _player.seek(duration);
                            _sendProgress();
                          },
                          barHeight: 4,
                          baseBarColor: isDark 
                              ? Colors.white.withAlpha(77) 
                              : Colors.black.withAlpha(30),
                          progressBarColor: const Color(0xFFBFAE01),
                          bufferedBarColor: const Color(0xFFBFAE01).withValues(alpha: 0.3),
                          thumbColor: const Color(0xFFBFAE01),
                          thumbRadius: 6,
                          thumbGlowRadius: 16,
                          thumbGlowColor: const Color(0xFFBFAE01).withValues(alpha: 0.3),
                          timeLabelLocation: TimeLabelLocation.sides,
                          timeLabelType: TimeLabelType.totalTime,
                          timeLabelTextStyle: GoogleFonts.inter(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }
}