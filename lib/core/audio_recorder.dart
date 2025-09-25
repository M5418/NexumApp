import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart' as rec;
import 'profile_api.dart';

class AudioRecorder {
  static final AudioRecorder _instance = AudioRecorder._internal();
  factory AudioRecorder() => _instance;
  AudioRecorder._internal();

  final rec.AudioRecorder _recorder = rec.AudioRecorder();

  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  // Web-only: stream and buffer for recorded bytes
  StreamSubscription<List<int>>? _webSub;
  BytesBuilder? _webBytes;
  Uint8List? _lastWebBytes; // retained after stop() for upload

  Future<bool> hasPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  Future<String?> startRecording() async {
    try {
      if (!await hasPermission()) {
        throw Exception('Microphone permission denied');
      }

      _recordingStartTime = DateTime.now();
      final ts = DateTime.now().millisecondsSinceEpoch;

      if (kIsWeb) {
        // On Web, record to a stream (opus/webm) and accumulate bytes
        _webBytes = BytesBuilder();
        final stream = await _recorder.startStream(
          rec.RecordConfig(
            encoder: rec.AudioEncoder.opus,
            bitRate: 128000,
            sampleRate: 48000,
          ),
        );
        _webSub = stream.listen((chunk) {
          try {
            _webBytes?.add(chunk);
          } catch (e) {
            debugPrint('❌ Web audio buffer error: $e');
          }
        });
        _currentRecordingPath = 'web'; // placeholder, not used
        return _currentRecordingPath;
      }

      // Mobile/desktop: write to temp .m4a file
      final directory = Directory.systemTemp;
      _currentRecordingPath = '${directory.path}/voice_$ts.m4a';

      await _recorder.start(
        rec.RecordConfig(
          encoder: rec.AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );

      return _currentRecordingPath;
    } catch (e) {
      debugPrint('❌ AudioRecorder: Failed to start recording: $e');
      return null;
    }
  }

  Future<VoiceRecordingResult?> stopRecording() async {
    try {
      final path = await _recorder.stop();

      if (_recordingStartTime == null) {
        _cleanupAfterStop();
        return null;
      }

      if (kIsWeb) {
        // Finalize web stream and produce a bytes-based result
        try {
          await _webSub?.cancel();
        } catch (_) {}
        _webSub = null;

        final bytes = _webBytes?.takeBytes();
        _webBytes = null;
        _lastWebBytes = bytes;

        final duration = DateTime.now().difference(_recordingStartTime!);

        _cleanupAfterStop();

        if (bytes == null || bytes.isEmpty) {
          return null;
        }

        return VoiceRecordingResult(
          filePath: null,
          duration: duration,
          fileSize: bytes.length,
          fileExtension: 'webm',
        );
      }

      // Mobile/desktop path
      if (path == null) {
        _cleanupAfterStop();
        return null;
      }

      final file = File(path);
      if (!await file.exists()) {
        _cleanupAfterStop();
        return null;
      }

      final duration = DateTime.now().difference(_recordingStartTime!);
      final fileSize = await file.length();

      _cleanupAfterStop();

      return VoiceRecordingResult(
        filePath: path,
        duration: duration,
        fileSize: fileSize,
        fileExtension: 'm4a',
      );
    } catch (e) {
      debugPrint('❌ AudioRecorder: Failed to stop recording: $e');
      _cleanupAfterStop();
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      await _recorder.stop();
      if (!kIsWeb && _currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('❌ AudioRecorder: Failed to cancel recording: $e');
    } finally {
      _cleanupAfterStop();
      _webBytes = null;
      _lastWebBytes = null;
      try {
        await _webSub?.cancel();
      } catch (_) {}
      _webSub = null;
    }
  }

  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  // Uploads the last recorded audio. On web, ignores filePath and uploads the captured bytes as .webm
  Future<String?> uploadVoiceFile(String? filePath) async {
    try {
      final profileApi = ProfileApi();

      if (kIsWeb) {
        final bytes = _lastWebBytes;
        _lastWebBytes = null; // clear after use
        if (bytes == null || bytes.isEmpty) {
          debugPrint('⚠️ AudioRecorder: No web bytes to upload');
          return null;
        }
        return await profileApi.uploadBytes(bytes, ext: 'webm');
      }

      if (filePath == null) return null;

      final file = File(filePath);
      if (!await file.exists()) return null;

      final url = await profileApi.uploadFile(file);

      // Clean up temp file after upload
      try {
        await file.delete();
      } catch (_) {}

      return url;
    } catch (e) {
      debugPrint('❌ AudioRecorder: Failed to upload voice file: $e');
      return null;
    }
  }

  void dispose() {
    _recorder.dispose();
    try {
      _webSub?.cancel();
    } catch (_) {}
  }

  void _cleanupAfterStop() {
    _currentRecordingPath = null;
    _recordingStartTime = null;
  }
}

class VoiceRecordingResult {
  final String? filePath; // mobile/desktop
  final Duration duration;
  final int fileSize;
  final String fileExtension; // e.g. 'm4a' or 'webm'

  VoiceRecordingResult({
    required this.filePath,
    required this.duration,
    required this.fileSize,
    required this.fileExtension,
  });
}