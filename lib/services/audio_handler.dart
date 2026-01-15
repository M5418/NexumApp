import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Audio handler for background playback with lock screen controls
class PodcastAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  
  // Current media item info
  MediaItem? _currentMediaItem;

  PodcastAudioHandler() {
    _init();
  }

  void _init() {
    // Broadcast player state changes
    _player.playbackEventStream.listen((event) {
      _broadcastState();
    });

    // Broadcast duration changes
    _player.durationStream.listen((duration) {
      if (duration != null && _currentMediaItem != null) {
        _currentMediaItem = _currentMediaItem!.copyWith(duration: duration);
        mediaItem.add(_currentMediaItem);
      }
    });

    // Broadcast position changes
    _player.positionStream.listen((position) {
      playbackState.add(playbackState.value.copyWith(
        updatePosition: position,
      ));
    });

    // Handle completion
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        stop();
      }
    });
  }

  AudioPlayer get player => _player;

  /// Load and play a podcast - optimized for fast startup
  Future<void> loadAndPlay({
    required String id,
    required String title,
    required String artist,
    required String audioUrl,
    String? artUri,
    Duration? startPosition,
  }) async {
    _currentMediaItem = MediaItem(
      id: id,
      title: title,
      artist: artist,
      artUri: artUri != null ? Uri.parse(artUri) : null,
      duration: Duration.zero,
    );
    
    mediaItem.add(_currentMediaItem);
    
    try {
      // FAST: Use preload mode - starts playing while still buffering
      final duration = await _player.setUrl(
        audioUrl,
        preload: true, // Preload for instant playback
      );
      
      // Update duration immediately if available
      if (duration != null) {
        _currentMediaItem = _currentMediaItem!.copyWith(duration: duration);
        mediaItem.add(_currentMediaItem);
      }
      
      // Seek to start position if provided (non-blocking)
      if (startPosition != null && startPosition > Duration.zero) {
        _player.seek(startPosition); // Don't await - let it seek while playing
      }
      
      // Start playing immediately - don't wait for full buffer
      play(); // Don't await - returns instantly
    } catch (e) {
      // Handle error
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.error,
      ));
    }
  }

  void _broadcastState() {
    final playing = _player.playing;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.rewind,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: _mapProcessingState(_player.processingState),
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    ));
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> fastForward() => _player.seek(_player.position + const Duration(seconds: 30));

  @override
  Future<void> rewind() => _player.seek(_player.position - const Duration(seconds: 10));

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  Future<void> dispose() async {
    await _player.dispose();
  }
}

/// Singleton to manage the audio handler
class PodcastAudioService {
  static PodcastAudioHandler? _handler;
  static bool _initialized = false;

  static Future<PodcastAudioHandler> init() async {
    if (!_initialized) {
      _handler = await AudioService.init(
        builder: () => PodcastAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.nexum.app.audio',
          androidNotificationChannelName: 'Nexum Audio',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );
      _initialized = true;
    }
    return _handler!;
  }

  static PodcastAudioHandler? get handler => _handler;
  
  static bool get isInitialized => _initialized;
}
