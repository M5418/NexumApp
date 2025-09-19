import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'podcast_models.dart';

class PlayerPage extends StatefulWidget {
  final Episode episode;
  const PlayerPage({super.key, required this.episode});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class PodcastAudioController {
  PodcastAudioController(this._player);
  final AudioPlayer _player;

  // Prepare the source but do not autoplay.
  Future<void> prepareUrl(String url) async {
    await _player.setUrl(url);
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();

  // Convenience for switching sources while ensuring only one is playing.
  Future<void> playUrl(String url) async {
    await _player.stop();
    await _player.setUrl(url);
    await _player.play();
  }

  // Streams
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> dispose() => _player.dispose();
}

class _PlayerPageState extends State<PlayerPage> {
  late final PodcastAudioController ctrl;
  Duration _pos = Duration.zero;
  Duration _dur = const Duration(seconds: 1);
  bool _playing = false;

  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
    } catch (e) {
      // Non-fatal if session config fails
      debugPrint('AudioSession config error: $e');
    }

    ctrl = PodcastAudioController(AudioPlayer());

    // Prepare the episode without autoplay
    await ctrl.prepareUrl(widget.episode.audioUrl);

    // Listen to streams
    _posSub = ctrl.positionStream.listen((d) {
      if (mounted) {
        setState(() => _pos = d);
      }
    });
    _durSub = ctrl.durationStream.listen((d) {
      if (mounted) {
        setState(() => _dur = d ?? const Duration(seconds: 1));
      }
    });
    _stateSub = ctrl.playerStateStream.listen((s) {
      final playing = s.playing;
      if (mounted) {
        setState(() => _playing = playing);
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    // Ignore unawaited future
    ctrl.dispose();
    super.dispose();
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
        title: Text(
          'Episode',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: Column(
        children: [
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 260,
              height: 260,
              child: CachedNetworkImage(
                imageUrl: widget.episode.coverUrl,
                fit: BoxFit.cover,
                memCacheWidth: 520,
                memCacheHeight: 520,
                placeholder: (context, url) => Container(
                  color: isDark
                      ? const Color(0xFF111111)
                      : const Color(0xFFEAEAEA),
                ),
                errorWidget: (context, url, error) => Container(
                  color: isDark
                      ? const Color(0xFF111111)
                      : const Color(0xFFEAEAEA),
                  child: const Center(
                    child: Icon(
                      Icons.podcasts,
                      color: Color(0xFFBFAE01),
                      size: 42,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.episode.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: _pos.inMilliseconds
                        .clamp(0, _dur.inMilliseconds)
                        .toDouble(),
                    max: (_dur.inMilliseconds == 0 ? 1 : _dur.inMilliseconds)
                        .toDouble(),
                    onChanged: (v) {
                      ctrl.seek(Duration(milliseconds: v.toInt()));
                    },
                    activeColor: const Color(0xFFBFAE01),
                    inactiveColor: const Color(0xFFCCCCCC),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    children: [
                      Text(
                        _fmt(_pos),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF666666),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _fmt(_dur),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _roundButton(
                      icon: Icons.replay_10,
                      onTap: () {
                        final back = _pos - const Duration(seconds: 10);
                        final target = back < Duration.zero
                            ? Duration.zero
                            : back;
                        ctrl.seek(target);
                      },
                    ),
                    const SizedBox(width: 20),
                    _roundButton(
                      icon: _playing ? Icons.pause : Icons.play_arrow,
                      size: 62,
                      onTap: () async {
                        if (_playing) {
                          await ctrl.pause();
                        } else {
                          await ctrl.play();
                        }
                      },
                      isPrimary: true,
                    ),
                    const SizedBox(width: 20),
                    _roundButton(
                      icon: Icons.forward_10,
                      onTap: () {
                        ctrl.seek(_pos + const Duration(seconds: 10));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 48,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFFBFAE01) : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 26),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: isPrimary ? Colors.black : Colors.black),
      ),
    );
  }

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$mm:$ss';
  }
}
