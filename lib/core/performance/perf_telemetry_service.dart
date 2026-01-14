import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'dart:io' show Platform;
import 'local_performance_controller.dart';

/// Service for writing anonymized performance telemetry to Firestore.
/// Used by Cloud Functions to aggregate and adjust Remote Config.
/// 
/// Privacy: No PII, no content, no message text, no file names.
/// Only anonymized performance metrics.
class PerfTelemetryService {
  static final PerfTelemetryService _instance = PerfTelemetryService._internal();
  factory PerfTelemetryService() => _instance;
  PerfTelemetryService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final LocalPerformanceController _localController = LocalPerformanceController();
  
  Timer? _uploadTimer;
  bool _initialized = false;
  String? _sessionId;
  String? _platform;
  String? _appVersion;

  // Upload interval (don't upload too frequently)
  static const Duration _uploadInterval = Duration(minutes: 5);

  /// Initialize telemetry service
  Future<void> init({String? appVersion}) async {
    if (_initialized) return;
    _initialized = true;

    _appVersion = appVersion ?? '1.0.0';
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _platform = _getPlatform();

    // Start periodic upload
    _uploadTimer = Timer.periodic(_uploadInterval, (_) => _uploadTelemetry());

    _debugLog('✅ PerfTelemetryService initialized');
  }

  String _getPlatform() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isWindows) return 'windows';
      if (Platform.isLinux) return 'linux';
    } catch (_) {
      // Platform not available
    }
    return 'unknown';
  }

  /// Upload current telemetry snapshot to Firestore
  Future<void> _uploadTelemetry() async {
    try {
      final health = _localController.getHealthMetrics();
      
      // Only upload if we have meaningful data
      if (health.frameMetricsCount < 10) {
        _debugLog('⏭️ Skipping telemetry upload - insufficient data');
        return;
      }

      // Get anonymized user segment (optional, for A/B testing)
      final userId = fb.FirebaseAuth.instance.currentUser?.uid;
      final userSegment = userId != null 
          ? userId.hashCode.abs() % 100 // 0-99 segment bucket
          : null;

      final telemetry = {
        'sessionId': _sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'appVersion': _appVersion,
        'platform': _platform,
        'userSegment': userSegment, // Anonymized bucket, not actual ID
        'metrics': {
          'jankRate': health.jankRate,
          'feedLoadP95Ms': health.feedLoadP95Ms,
          'chatLoadP95Ms': health.chatLoadP95Ms,
          'videoInitP95Ms': health.videoInitP95Ms,
          'frameMetricsCount': health.frameMetricsCount,
          'isInLiteMode': health.isInLiteMode,
        },
      };

      await _db.collection('perf_telemetry').add(telemetry);
      _debugLog('📤 Telemetry uploaded: jank=${(health.jankRate * 100).toStringAsFixed(1)}%');
    } catch (e) {
      _debugLog('⚠️ Telemetry upload failed: $e');
      // Don't crash on telemetry failure
    }
  }

  /// Force upload current telemetry (for testing)
  Future<void> forceUpload() async {
    await _uploadTelemetry();
  }

  /// Record a specific event (for custom tracking)
  Future<void> recordEvent(String eventName, Map<String, dynamic> data) async {
    try {
      await _db.collection('perf_events').add({
        'sessionId': _sessionId,
        'timestamp': FieldValue.serverTimestamp(),
        'platform': _platform,
        'event': eventName,
        'data': data,
      });
    } catch (e) {
      _debugLog('⚠️ Event recording failed: $e');
    }
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[PerfTelemetry] $message');
    }
  }

  void dispose() {
    _uploadTimer?.cancel();
  }
}
