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

  DateTime? _startTime;
  Uint8List? _lastBytes;

  Future<bool> hasPermission() async {
    try {
      // Request mic stream to trigger browser permission prompt
      _mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({
        'audio': true,
      });
      final ok = _mediaStream != null;
      debugPrint('Web mic permission: $ok');
      if (!ok) return false;

      // Immediately stop tracks; they’ll be reacquired at startRecording
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
      final permitted = await hasPermission();
      if (!permitted) {
        throw Exception('Microphone permission denied by browser');
      }

      // Acquire a fresh audio stream
      _mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({
        'audio': true,
      });
      if (_mediaStream == null) {
        throw Exception('Failed to acquire media stream');
      }

      // Prefer opus in webm
      const mimeOpus = 'audio/webm;codecs=opus';
      final mime = html.MediaRecorder.isTypeSupported(mimeOpus)
          ? mimeOpus
          : 'audio/webm';

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
      void onDataHandler(html.Event e) {
        try {
          final dynamic de = e;
          final data = (de as dynamic).data as html.Blob?;
          if (data != null) {
            _chunks.add(data);
          }
        } catch (err) {
          debugPrint('⚠️ Web dataavailable parse error: $err');
        }
      }
      _recorder!.addEventListener('dataavailable', onDataHandler);

      _recorder!.start();
      await startCompleter.future;

      _startTime = DateTime.now();
      return 'web'; // placeholder
    } catch (e) {
      debugPrint('❌ AudioRecorder(Web): Failed to start recording: $e');
      return null;
    }
  }

  Future<VoiceRecordingResult?> stopRecording() async {
    try {
      if (_recorder == null) return null;

      // Wait for 'stop' event
      final stopped = Completer<void>();
      void onStopHandler(html.Event _) {
        if (!stopped.isCompleted) stopped.complete();
        _recorder?.removeEventListener('stop', onStopHandler);
      }
      _recorder!.addEventListener('stop', onStopHandler);

      _recorder!.stop();
      await stopped.future;

      // Build a single Blob from chunks
      final blob = html.Blob(_chunks, 'audio/webm');

      // Convert Blob -> bytes
      final reader = html.FileReader();
      final loadCompleter = Completer<void>();
      reader.onLoadEnd.listen((_) => loadCompleter.complete());
      reader.readAsArrayBuffer(blob);
      await loadCompleter.future;

      final buffer = reader.result as ByteBuffer;
      final bytes = Uint8List.view(buffer);
      _lastBytes = bytes;

      final duration = _startTime != null
          ? DateTime.now().difference(_startTime!)
          : const Duration(seconds: 0);

      _cleanup();

      if (bytes.isEmpty) return null;

      return VoiceRecordingResult(
        filePath: null,
        duration: duration,
        fileSize: bytes.length,
        fileExtension: 'webm',
      );
    } catch (e) {
      debugPrint('❌ AudioRecorder(Web): Failed to stop recording: $e');
      _cleanup();
      return null;
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
      _lastBytes = null;
      if (bytes == null || bytes.isEmpty) {
        debugPrint('⚠️ AudioRecorder(Web): No bytes to upload');
        return null;
      }
      final profileApi = ProfileApi();
      return await profileApi.uploadBytes(bytes, ext: 'webm');
    } catch (e) {
      debugPrint('❌ AudioRecorder(Web): Failed to upload voice file: $e');
      return null;
    }
  }

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