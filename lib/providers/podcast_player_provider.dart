import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';

import '../services/audio_handler.dart';
import '../podcasts/podcasts_home_page.dart' show Podcast;

/// Global state provider for podcast playback
/// Tracks currently playing podcast and playback state across all pages
class PodcastPlayerProvider extends ChangeNotifier {
  static final PodcastPlayerProvider _instance = PodcastPlayerProvider._internal();
  factory PodcastPlayerProvider() => _instance;
  PodcastPlayerProvider._internal();

  PodcastAudioHandler? _audioHandler;
  StreamSubscription<PlaybackState>? _playbackSub;
  StreamSubscription<MediaItem?>? _mediaSub;

  // Current podcast being played
  Podcast? _currentPodcast;
  Podcast? get currentPodcast => _currentPodcast;

  // Playback state
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Duration _position = Duration.zero;
  Duration get position => _position;

  Duration _duration = Duration.zero;
  Duration get duration => _duration;

  double _speed = 1.0;
  double get speed => _speed;

  String? _error;
  String? get error => _error;

  bool get hasActivePodcast => _currentPodcast != null;

  /// Initialize the audio handler (call once at app start)
  Future<void> init() async {
    if (_audioHandler != null) return;

    try {
      _audioHandler = await PodcastAudioService.init();
      _setupListeners();
    } catch (e) {
      debugPrint('❌ [PodcastPlayerProvider] Failed to init: $e');
    }
  }

  void _setupListeners() {
    _playbackSub?.cancel();
    _mediaSub?.cancel();

    _playbackSub = _audioHandler!.playbackState.listen((state) {
      _position = state.position;
      _isPlaying = state.playing;
      _speed = state.speed;
      _isLoading = state.processingState == AudioProcessingState.loading ||
          state.processingState == AudioProcessingState.buffering;
      notifyListeners();
    });

    _mediaSub = _audioHandler!.mediaItem.listen((item) {
      if (item != null && item.duration != null) {
        _duration = item.duration!;
        notifyListeners();
      }
    });
  }

  /// Play a podcast
  Future<void> play(Podcast podcast) async {
    if (_audioHandler == null) {
      await init();
    }

    final url = (podcast.audioUrl ?? '').trim();
    if (url.isEmpty) {
      _error = 'No audio available';
      notifyListeners();
      return;
    }

    _currentPodcast = podcast;
    _isLoading = true;
    _error = null;
    _duration = Duration(seconds: podcast.durationSec ?? 0);
    notifyListeners();

    try {
      await _audioHandler!.loadAndPlay(
        id: podcast.id,
        title: podcast.title,
        artist: podcast.author ?? 'Unknown',
        audioUrl: url,
        artUri: podcast.coverUrl,
      );
      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to play: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_audioHandler == null) return;

    if (_isPlaying) {
      await _audioHandler!.pause();
    } else {
      await _audioHandler!.play();
    }
  }

  /// Pause playback
  Future<void> pause() async {
    await _audioHandler?.pause();
  }

  /// Resume playback
  Future<void> resume() async {
    await _audioHandler?.play();
  }

  /// Stop playback and clear current podcast
  Future<void> stop() async {
    await _audioHandler?.stop();
    _currentPodcast = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _isPlaying = false;
    notifyListeners();
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    await _audioHandler?.seek(position);
  }

  /// Skip forward 30 seconds
  Future<void> skipForward() async {
    await _audioHandler?.fastForward();
  }

  /// Skip backward 10 seconds
  Future<void> skipBackward() async {
    await _audioHandler?.rewind();
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    await _audioHandler?.setSpeed(speed);
    _speed = speed;
    notifyListeners();
  }

  @override
  void dispose() {
    _playbackSub?.cancel();
    _mediaSub?.cancel();
    super.dispose();
  }
}
