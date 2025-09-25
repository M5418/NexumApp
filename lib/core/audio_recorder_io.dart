// lib/core/audio_recorder_io.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
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

  Future<bool> hasPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    final result = await Permission.microphone.request();
    return result.isGranted;
  }

  Future<String?> startRecording() async {
    try {
      if (!await hasPermission()) {
        throw Exception('Microphone permission denied by OS');
      }

      _recordingStartTime = DateTime.now();
      final ts = DateTime.now().millisecondsSinceEpoch;

      final directory = Directory.systemTemp;
      _currentRecordingPath = '${directory.path}/voice_$ts.m4a';

      await _recorder.start(
        rec.RecordConfig(
          encoder: rec.AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );

      return _currentRecordingPath;
    } catch (e) {
      debugPrint('❌ AudioRecorder(IO): Failed to start recording: $e');
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
      debugPrint('❌ AudioRecorder(IO): Failed to stop recording: $e');
      _cleanupAfterStop();
      return null;
    }
  }

  Future<void> cancelRecording() async {
    try {
      await _recorder.stop();
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      debugPrint('❌ AudioRecorder(IO): Failed to cancel recording: $e');
    } finally {
      _cleanupAfterStop();
    }
  }

  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  Future<String?> uploadVoiceFile(String? filePath) async {
    try {
      if (filePath == null) return null;

      final file = File(filePath);
      if (!await file.exists()) return null;

      final profileApi = ProfileApi();
      final url = await profileApi.uploadFile(file);

      try {
        await file.delete();
      } catch (_) {}

      return url;
    } catch (e) {
      debugPrint('❌ AudioRecorder(IO): Failed to upload voice file: $e');
      return null;
    }
  }

  void dispose() {
    _recorder.dispose();
  }

  void _cleanupAfterStop() {
    _currentRecordingPath = null;
    _recordingStartTime = null;
  }
}

class VoiceRecordingResult {
  final String? filePath; // path on IO
  final Duration duration;
  final int fileSize;
  final String fileExtension; // 'm4a'

  VoiceRecordingResult({
    required this.filePath,
    required this.duration,
    required this.fileSize,
    required this.fileExtension,
  });
}