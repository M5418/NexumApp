import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'books_home_page.dart' show Book;

class BookPlayPage extends StatefulWidget {
  final Book book;
  const BookPlayPage({super.key, required this.book});

  @override
  State<BookPlayPage> createState() => _BookPlayPageState();
}

class _BookPlayPageState extends State<BookPlayPage> {
  bool _isPlaying = false;
  double _currentPosition = 0.0;
  double _totalDuration = 1.0;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    // Simulate total duration based on reading minutes
    _totalDuration = widget.book.readingMinutes * 60.0; // Convert to seconds
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
  }

  void _seekTo(double position) {
    setState(() {
      _currentPosition = position;
    });
  }

  void _changeSpeed() {
    setState(() {
      if (_playbackSpeed == 1.0) {
        _playbackSpeed = 1.25;
      } else if (_playbackSpeed == 1.25) {
        _playbackSpeed = 1.5;
      } else if (_playbackSpeed == 1.5) {
        _playbackSpeed = 2.0;
      } else {
        _playbackSpeed = 1.0;
      }
    });
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);

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
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Book cover
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.network(
                  widget.book.coverUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: isDark
                        ? const Color(0xFF111111)
                        : const Color(0xFFEAEAEA),
                    child: const Center(
                      child: Icon(
                        Icons.menu_book_outlined,
                        color: Color(0xFFBFAE01),
                        size: 64,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Book info
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
              widget.book.author,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: const Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 40),

            // Progress bar
            Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFFBFAE01),
                    inactiveTrackColor: isDark
                        ? const Color(0xFF333333)
                        : const Color(0xFFE0E0E0),
                    thumbColor: const Color(0xFFBFAE01),
                    overlayColor: const Color(0xFFBFAE01).withValues(alpha: 51),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8,
                    ),
                  ),
                  child: Slider(
                    value: _currentPosition,
                    max: _totalDuration,
                    onChanged: _seekTo,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_currentPosition),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF666666),
                        ),
                      ),
                      Text(
                        _formatDuration(_totalDuration),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF666666),
                        ),
                      ),
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
                            color: Colors.black.withValues(alpha: 33),
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
                  onPressed: () {
                    _seekTo((_currentPosition - 15).clamp(0, _totalDuration));
                  },
                  icon: const Icon(Icons.replay_10, size: 32),
                  color: isDark ? Colors.white : Colors.black,
                ),

                // Play/Pause
                GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFFBFAE01),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.black,
                      size: 32,
                    ),
                  ),
                ),

                // Forward 15s
                IconButton(
                  onPressed: () {
                    _seekTo((_currentPosition + 15).clamp(0, _totalDuration));
                  },
                  icon: const Icon(Icons.forward_10, size: 32),
                  color: isDark ? Colors.white : Colors.black,
                ),

                // Bookmark
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.bookmark_border, size: 28),
                  color: isDark ? Colors.white : Colors.black,
                ),
              ],
            ),

            const Spacer(),

            // Additional controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.timer_outlined),
                  color: isDark ? Colors.white : Colors.black,
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.share_outlined),
                  color: isDark ? Colors.white : Colors.black,
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.playlist_play_outlined),
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
