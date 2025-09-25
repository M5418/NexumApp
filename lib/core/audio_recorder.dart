import 'dart:io';
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
        _currentRecordingPath = 'voice_$ts.m4a';
        await _recorder.start(
          const rec.RecordConfig(
            encoder: rec.AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _currentRecordingPath!,
        );
        return _currentRecordingPath;
      }

      final directory = Directory.systemTemp;
      _currentRecordingPath = '${directory.path}/voice_$ts.m4a';

      await _recorder.start(
        const rec.RecordConfig(
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

      if (kIsWeb || path == null || _recordingStartTime == null) {
        _currentRecordingPath = null;
        _recordingStartTime = null;
        return null;
      }

      final file = File(path);
      if (!await file.exists()) return null;

      final duration = DateTime.now().difference(_recordingStartTime!);
      final fileSize = await file.length();

      return VoiceRecordingResult(
        filePath: path,
        duration: duration,
        fileSize: fileSize,
      );
    } catch (e) {
      debugPrint('❌ AudioRecorder: Failed to stop recording: $e');
      return null;
    } finally {
      _currentRecordingPath = null;
      _recordingStartTime = null;
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
      _currentRecordingPath = null;
      _recordingStartTime = null;
    }
  }

  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  Future<String?> uploadVoiceFile(String filePath) async {
    try {
      if (kIsWeb) {
        debugPrint('⚠️ AudioRecorder: uploadVoiceFile is not supported on Web');
        return null;
      }

      final file = File(filePath);
      if (!await file.exists()) return null;

      final profileApi = ProfileApi();
      final url = await profileApi.uploadFile(file);

      // Clean up temp file after upload
      await file.delete();

      return url;
    } catch (e) {
      debugPrint('❌ AudioRecorder: Failed to upload voice file: $e');
      return null;
    }
  }

  void dispose() {
    _recorder.dispose();
  }
}

class VoiceRecordingResult {
  final String filePath;
  final Duration duration;
  final int fileSize;

  VoiceRecordingResult({
    required this.filePath,
    required this.duration,
    required this.fileSize,
  });
}