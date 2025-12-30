// lib/core/audio_recorder_web.dart
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html; // Web-only
import 'package:flutter/foundation.dart' show debugPrint;
import 'profile_api.dart';

class AudioRecorder {
  static final AudioRecorder _instance = AudioRecorder._internal();
  factory AudioRecorder() => _instance;
  AudioRecorder._internal();

  html.MediaStream? _mediaStream;
  html.MediaRecorder? _recorder;
  final List<html.Blob> _chunks = [];
  html.EventListener? _onDataHandler;

  DateTime? _startTime;
  Uint8List? _lastBytes;
  bool _permissionGranted = false;
  String _currentExtension = 'webm';

  Future<bool> hasPermission() async {
    try {
      debugPrint('🎤 Requesting microphone permission (Web)...');
      
      // Request mic stream - this triggers browser permission prompt
      _mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({
        'audio': true,
      });
      
      final ok = _mediaStream != null;
      if (!ok) {
        debugPrint('❌ Web mic permission denied or unavailable');
        return false;
      }
      debugPrint('✅ Web mic permission granted');
      _permissionGranted = true;
      
      // Immediately stop tracks; they'll be reacquired at startRecording
      for (final t in _mediaStream!.getTracks()) {
        t.stop();
      }
      _mediaStream = null;
      return true;
    } catch (e) {
      debugPrint('❌ Web permission check failed: $e');
      return false;
    }
  }

  Future<String?> startRecording() async {
    try {
      // Check if MediaDevices API is available
      if (html.window.navigator.mediaDevices == null) {
        throw Exception('MediaDevices API not available. Recording requires HTTPS or localhost.');
      }

      final permitted = _permissionGranted ? true : await hasPermission();
      if (!permitted) {
        throw Exception('Microphone permission denied. Please allow microphone access in your browser.');
      }

      // Acquire a fresh audio stream
      _mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({
        'audio': true,
      });
      if (_mediaStream == null) {
        throw Exception('Failed to acquire media stream from browser');
      }

      // Try formats in order of cross-platform compatibility:
      // 1. MP4/AAC - works on iOS, Android, Safari, and most browsers
      // 2. WebM/Opus - works on Chrome, Firefox, Android
      // 3. WebM - fallback
      String mime = 'audio/webm';
      String ext = 'webm';
      
      // Preferred: MP4 with AAC (best iOS compatibility)
      if (html.MediaRecorder.isTypeSupported('audio/mp4')) {
        mime = 'audio/mp4';
        ext = 'm4a';
      } else if (html.MediaRecorder.isTypeSupported('audio/mp4;codecs=mp4a.40.2')) {
        mime = 'audio/mp4;codecs=mp4a.40.2';
        ext = 'm4a';
      } else if (html.MediaRecorder.isTypeSupported('audio/aac')) {
        mime = 'audio/aac';
        ext = 'aac';
      } else if (html.MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) {
        mime = 'audio/webm;codecs=opus';
        ext = 'webm';
      }
      
      _currentExtension = ext;

      debugPrint('✅ Web recording using MIME: $mime (extension: $ext)');

      _chunks.clear();
      _lastBytes = null;

      _recorder = html.MediaRecorder(_mediaStream!, {'mimeType': mime});

      // Wait for 'start' event
      final startCompleter = Completer<void>();
      void onStartHandler(html.Event _) {
        if (!startCompleter.isCompleted) startCompleter.complete();
        _recorder?.removeEventListener('start', onStartHandler);
      }
      _recorder!.addEventListener('start', onStartHandler);

      // Collect chunks on 'dataavailable'
      _onDataHandler = (html.Event e) {
        try {
          final dynamic de = e;
          final data = (de as dynamic).data as html.Blob?;
          if (data != null) {
            _chunks.add(data);
            debugPrint('🔊 Web received audio chunk: ${data.size} bytes');
          }
        } catch (err) {
          debugPrint('⚠️ Web dataavailable parse error: $err');
        }
      };
      _recorder!.addEventListener('dataavailable', _onDataHandler!);

      // Request chunks every 1 second to ensure dataavailable fires reliably
      _recorder!.start(1000);
      await startCompleter.future;

      _startTime = DateTime.now();
      debugPrint('✅ AudioRecorder(Web): Recording started successfully');
      return 'web'; // placeholder
    } catch (e) {
      debugPrint('❌ AudioRecorder(Web): Failed to start recording: $e');
      _cleanup();
      rethrow;
    }
  }

  Future<VoiceRecordingResult?> stopRecording() async {
    try {
      if (_recorder == null) {
        throw Exception('No active recording to stop');
      }

      // Wait for 'stop' event
      final stopped = Completer<void>();
      void onStopHandler(html.Event _) {
        if (!stopped.isCompleted) stopped.complete();
        _recorder?.removeEventListener('stop', onStopHandler);
      }
      _recorder!.addEventListener('stop', onStopHandler);

      // Stop and remove listeners
      _recorder!.stop();
      if (_onDataHandler != null) {
        try { _recorder!.removeEventListener('dataavailable', _onDataHandler!); } catch (_) {}
        _onDataHandler = null;
      }
      await stopped.future;

      if (_chunks.isEmpty) {
        _cleanup();
        throw Exception('No audio data recorded');
      }

      debugPrint('🔊 Web collected ${_chunks.length} audio chunks');

      // Build a single Blob from chunks
      final blob = html.Blob(_chunks, 'audio/webm');

      if (blob.size == 0) {
        _cleanup();
        throw Exception('Recorded audio is empty');
      }

      debugPrint('🔊 Web blob size: ${blob.size} bytes');

      // Convert Blob -> bytes
      final reader = html.FileReader();

      // MOD: use onLoad instead of onLoadEnd for more robust completion
      final loadCompleter = Completer<void>();
      void onReaderLoad(html.Event _) {
        if (!loadCompleter.isCompleted) loadCompleter.complete();
      }
      void onReaderError(html.Event e) {
        if (!loadCompleter.isCompleted) {
          loadCompleter.completeError(StateError('FileReader error: $e'));
        }
      }
      reader.onLoad.listen(onReaderLoad);
      reader.onError.listen(onReaderError);

      reader.readAsArrayBuffer(blob);
      await loadCompleter.future;

      // MOD: Handle both ByteBuffer and Uint8List results from FileReader
      final result = reader.result;
      late final Uint8List bytes;
      if (result == null) {
        throw StateError('FileReader.result is null');
      } else if (result is ByteBuffer) {
        bytes = Uint8List.view(result);
      } else if (result is Uint8List) {
        bytes = result;
      } else if (result is List<int>) {
        bytes = Uint8List.fromList(result);
      } else {
        throw StateError('Unexpected FileReader.result type: ${result.runtimeType}');
      }

      if (bytes.isEmpty) {
        _cleanup();
        throw Exception('Converted audio bytes are empty');
      }

      _lastBytes = bytes;

      final duration = _startTime != null
          ? DateTime.now().difference(_startTime!)
          : const Duration(seconds: 0);

      _cleanup();

      debugPrint('✅ AudioRecorder(Web): Recording stopped successfully (${duration.inSeconds}s, ${bytes.length} bytes)');

      return VoiceRecordingResult(
        filePath: null,
        duration: duration,
        fileSize: bytes.length,
        fileExtension: _currentExtension,
      );
    } catch (e) {
      debugPrint('❌ AudioRecorder(Web): Failed to stop recording: $e');
      _cleanup();
      rethrow;
    }
  }

  Future<void> cancelRecording() async {
    try {
      _recorder?.stop();
    } catch (_) {}
    _cleanup();
  }

  Future<bool> isRecording() async {
    return _recorder != null && _recorder!.state == 'recording';
  }

  Future<String?> uploadVoiceFile(String? filePath) async {
    try {
      final bytes = _lastBytes;
      final ext = _currentExtension;
      _lastBytes = null;
      if (bytes == null || bytes.isEmpty) {
        debugPrint('⚠️ AudioRecorder(Web): No bytes to upload');
        return null;
      }
      final profileApi = ProfileApi();
      debugPrint('📤 Uploading voice file with extension: $ext');
      return await profileApi.uploadBytes(bytes, ext: ext);
    } catch (e) {
      debugPrint('❌ AudioRecorder(Web): Failed to upload voice file: $e');
      return null;
    }
  }
  
  /// Get recorded bytes for manual upload (used by chat_page)
  Future<Uint8List?> takeRecordedBytes() async {
    final bytes = _lastBytes;
    _lastBytes = null;
    return bytes;
  }
  
  /// Get the file extension for the last recording
  String get currentExtension => _currentExtension;

  void dispose() {
    try {
      _recorder?.stop();
    } catch (_) {}
    _cleanup();
  }

  void _cleanup() {
    _recorder = null;
    _startTime = null;
    _chunks.clear();
    _onDataHandler = null;
    try {
      _mediaStream?.getTracks().forEach((t) => t.stop());
    } catch (_) {}
    _mediaStream = null;
  }
}

class VoiceRecordingResult {
  final String? filePath; // unused on Web
  final Duration duration;
  final int fileSize;
  final String fileExtension; // 'webm'

  VoiceRecordingResult({
    required this.filePath,
    required this.duration,
    required this.fileSize,
    required this.fileExtension,
  });
}