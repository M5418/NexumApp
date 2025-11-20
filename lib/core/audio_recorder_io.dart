// lib/core/audio_recorder_io.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart' as rec;
import 'package:device_info_plus/device_info_plus.dart';

class AudioRecorder {
  static final AudioRecorder _instance = AudioRecorder._internal();
  factory AudioRecorder() => _instance;
  AudioRecorder._internal();

  final rec.AudioRecorder _recorder = rec.AudioRecorder();

  String? _currentRecordingPath;
  DateTime? _recordingStartTime;

  Future<bool> hasPermission() async {
    // Check if running on iOS Simulator (doesn't support microphone)
    if (Platform.isIOS && kDebugMode) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final iosInfo = await deviceInfo.iosInfo;
        if (!iosInfo.isPhysicalDevice) {
          debugPrint('⚠️ Running on iOS Simulator - microphone not supported');
          debugPrint('   Voice recording will not work on simulator');
          return false; // Don't open settings, just return false
        }
      } catch (e) {
        debugPrint('⚠️ Could not detect if simulator: $e');
      }
    }
    
    final status = await Permission.microphone.status;
    
    // Already granted
    if (status.isGranted) {
      debugPrint('✅ Microphone permission already granted');
      return true;
    }
    
    // Request permission - this shows the iOS system dialog on FIRST USE
    // Add timeout to prevent freezing on simulator
    debugPrint('🎤 Requesting microphone permission...');
    PermissionStatus result;
    try {
      result = await Permission.microphone.request().timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          debugPrint('⚠️ Permission request timed out');
          return PermissionStatus.denied;
        },
      );
    } catch (e) {
      debugPrint('❌ Permission request error: $e');
      return false;
    }
    
    if (result.isGranted) {
      debugPrint('✅ Microphone permission granted');
      return true;
    } else if (result.isPermanentlyDenied) {
      // Only open settings if user has permanently denied (denied multiple times)
      debugPrint('⚠️ Microphone permission permanently denied. User needs to enable in Settings.');
      // Don't call openAppSettings on timeout/simulator
      return false;
    } else {
      // User denied once - just return false, don't open settings
      debugPrint('❌ Microphone permission denied by user');
      return false;
    }
  }

  Future<String?> startRecording() async {
    try {
      if (!await hasPermission()) {
        // Check if simulator
        if (Platform.isIOS && kDebugMode) {
          try {
            final deviceInfo = DeviceInfoPlugin();
            final iosInfo = await deviceInfo.iosInfo;
            if (!iosInfo.isPhysicalDevice) {
              throw Exception('Voice recording is not supported on iOS Simulator. Please test on a real device.');
            }
          } catch (_) {}
        }
        throw Exception('Microphone permission denied. Please enable microphone access in Settings.');
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

      debugPrint('✅ AudioRecorder(IO): Recording started successfully');
      return _currentRecordingPath;
    } catch (e) {
      debugPrint('❌ AudioRecorder(IO): Failed to start recording: $e');
      rethrow; // Let caller handle the error with user feedback
    }
  }

  Future<VoiceRecordingResult?> stopRecording() async {
    try {
      final path = await _recorder.stop();

      if (_recordingStartTime == null) {
        _cleanupAfterStop();
        throw Exception('Recording was not started properly');
      }

      if (path == null) {
        _cleanupAfterStop();
        throw Exception('Failed to save recording');
      }

      final file = File(path);
      if (!await file.exists()) {
        _cleanupAfterStop();
        throw Exception('Recording file not found');
      }

      final duration = DateTime.now().difference(_recordingStartTime!);
      final fileSize = await file.length();

      if (fileSize == 0) {
        _cleanupAfterStop();
        throw Exception('Recording is empty');
      }

      _cleanupAfterStop();

      debugPrint('✅ AudioRecorder(IO): Recording stopped successfully (${duration.inSeconds}s, $fileSize bytes)');
      return VoiceRecordingResult(
        filePath: path,
        duration: duration,
        fileSize: fileSize,
        fileExtension: 'm4a',
      );
    } catch (e) {
      debugPrint('❌ AudioRecorder(IO): Failed to stop recording: $e');
      _cleanupAfterStop();
      rethrow;
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