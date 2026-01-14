import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'performance_flags.dart';

/// Controller for local runtime performance adaptation.
/// Monitors jank, latency, and network conditions to compute adaptive overrides.
class LocalPerformanceController {
  static final LocalPerformanceController _instance = LocalPerformanceController._internal();
  factory LocalPerformanceController() => _instance;
  LocalPerformanceController._internal();

  bool _initialized = false;
  Timer? _evaluationTimer;

  /// Current local override flags (notifies listeners on change)
  final ValueNotifier<PerformanceFlags> localOverrides = 
      ValueNotifier<PerformanceFlags>(PerformanceFlags.normalDefaults);

  /// Stream of local override changes
  Stream<PerformanceFlags> get localOverridesStream => _overridesController.stream;
  final StreamController<PerformanceFlags> _overridesController = 
      StreamController<PerformanceFlags>.broadcast();

  // Rolling metrics storage
  final Queue<_FrameMetric> _frameMetrics = Queue();
  final Queue<_LatencyMetric> _feedLoadMetrics = Queue();
  final Queue<_LatencyMetric> _chatLoadMetrics = Queue();
  final Queue<_LatencyMetric> _videoInitMetrics = Queue();

  // Configuration
  static const int _maxMetricsCount = 100;
  static const Duration _evaluationInterval = Duration(seconds: 5);
  static const Duration _metricsWindow = Duration(seconds: 30);

  // Thresholds for downshifting
  static const double _jankRateThreshold = 0.15; // 15% janky frames
  static const int _feedLoadP95ThresholdMs = 2000; // 2 seconds
  static const int _chatLoadP95ThresholdMs = 1500;
  static const int _videoInitP95ThresholdMs = 3000;

  // Hysteresis counters (require sustained signals)
  int _consecutiveBadEvaluations = 0;
  int _consecutiveGoodEvaluations = 0;
  static const int _downshiftThreshold = 3; // 3 bad evaluations to downshift
  static const int _upshiftThreshold = 6; // 6 good evaluations to restore

  // Current adaptive state
  bool _isInLiteMode = false;

  /// Initialize the controller and start monitoring
  void init() {
    if (_initialized) return;
    _initialized = true;

    // Start frame timing monitoring
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);

    // Start periodic evaluation
    _evaluationTimer = Timer.periodic(_evaluationInterval, (_) => _evaluate());

    _debugLog('✅ LocalPerformanceController initialized');
  }

  /// Record a frame timing callback
  void _onFrameTimings(List<FrameTiming> timings) {
    final now = DateTime.now();
    for (final timing in timings) {
      final buildDuration = timing.buildDuration.inMilliseconds;
      final rasterDuration = timing.rasterDuration.inMilliseconds;
      final totalDuration = timing.totalSpan.inMilliseconds;
      
      // A frame is "janky" if it takes more than 16ms (60fps target)
      final isJanky = totalDuration > 16;

      _frameMetrics.add(_FrameMetric(
        timestamp: now,
        buildMs: buildDuration,
        rasterMs: rasterDuration,
        totalMs: totalDuration,
        isJanky: isJanky,
      ));

      // Trim old metrics
      _trimMetrics(_frameMetrics);
    }
  }

  /// Record feed load latency
  void recordFeedLoadTime(int milliseconds) {
    _feedLoadMetrics.add(_LatencyMetric(
      timestamp: DateTime.now(),
      durationMs: milliseconds,
    ));
    _trimMetrics(_feedLoadMetrics);
    _debugLog('📊 Feed load: ${milliseconds}ms');
  }

  /// Record chat load latency
  void recordChatLoadTime(int milliseconds) {
    _chatLoadMetrics.add(_LatencyMetric(
      timestamp: DateTime.now(),
      durationMs: milliseconds,
    ));
    _trimMetrics(_chatLoadMetrics);
    _debugLog('📊 Chat load: ${milliseconds}ms');
  }

  /// Record video init latency
  void recordVideoInitTime(int milliseconds) {
    _videoInitMetrics.add(_LatencyMetric(
      timestamp: DateTime.now(),
      durationMs: milliseconds,
    ));
    _trimMetrics(_videoInitMetrics);
    _debugLog('📊 Video init: ${milliseconds}ms');
  }

  void _trimMetrics<T extends _TimestampedMetric>(Queue<T> queue) {
    while (queue.length > _maxMetricsCount) {
      queue.removeFirst();
    }
    // Also remove metrics outside the time window
    final cutoff = DateTime.now().subtract(_metricsWindow);
    while (queue.isNotEmpty && queue.first.timestamp.isBefore(cutoff)) {
      queue.removeFirst();
    }
  }

  /// Evaluate current metrics and adjust local overrides
  void _evaluate() {
    final jankRate = _calculateJankRate();
    final feedP95 = _calculateP95(_feedLoadMetrics);
    final chatP95 = _calculateP95(_chatLoadMetrics);
    final videoP95 = _calculateP95(_videoInitMetrics);

    // Determine if current state is "bad"
    final isBad = jankRate > _jankRateThreshold ||
        feedP95 > _feedLoadP95ThresholdMs ||
        chatP95 > _chatLoadP95ThresholdMs ||
        videoP95 > _videoInitP95ThresholdMs;

    if (isBad) {
      _consecutiveBadEvaluations++;
      _consecutiveGoodEvaluations = 0;

      if (_consecutiveBadEvaluations >= _downshiftThreshold && !_isInLiteMode) {
        _downshift(jankRate, feedP95, chatP95, videoP95);
      }
    } else {
      _consecutiveGoodEvaluations++;
      _consecutiveBadEvaluations = 0;

      if (_consecutiveGoodEvaluations >= _upshiftThreshold && _isInLiteMode) {
        _upshift();
      }
    }

    if (kDebugMode && (_frameMetrics.isNotEmpty || _feedLoadMetrics.isNotEmpty)) {
      _debugLog('📈 Eval: jank=${(jankRate * 100).toStringAsFixed(1)}%, '
          'feedP95=${feedP95}ms, chatP95=${chatP95}ms, videoP95=${videoP95}ms, '
          'bad=$_consecutiveBadEvaluations, good=$_consecutiveGoodEvaluations');
    }
  }

  double _calculateJankRate() {
    if (_frameMetrics.isEmpty) return 0.0;
    final jankyCount = _frameMetrics.where((m) => m.isJanky).length;
    return jankyCount / _frameMetrics.length;
  }

  int _calculateP95<T extends _LatencyMetric>(Queue<T> metrics) {
    if (metrics.isEmpty) return 0;
    final sorted = metrics.map((m) => m.durationMs).toList()..sort();
    final index = ((sorted.length - 1) * 0.95).floor();
    return sorted[index];
  }

  void _downshift(double jankRate, int feedP95, int chatP95, int videoP95) {
    _isInLiteMode = true;
    _debugLog('⬇️ Downshifting to lite mode');

    // Determine specific overrides based on what's slow
    bool disableVideo = videoP95 > _videoInitP95ThresholdMs || jankRate > _jankRateThreshold;
    bool disablePrefetch = feedP95 > _feedLoadP95ThresholdMs;
    int feedPageSize = feedP95 > _feedLoadP95ThresholdMs ? 6 : 10;
    int chatPageSize = chatP95 > _chatLoadP95ThresholdMs ? 20 : 30;

    final overrides = PerformanceFlags(
      perfMode: PerfMode.lite,
      videoAutoplayEnabled: !disableVideo,
      videoWarmPlayersCount: disableVideo ? 0 : 1,
      videoPreloadCount: disableVideo ? 0 : 1,
      feedPageSize: feedPageSize,
      chatPageSize: chatPageSize,
      enableRealtimeListenersForLists: false,
      mediaQualityHint: MediaQualityHint.balanced,
      thumbnailsOnlyUntilFocused: disableVideo,
      maxConcurrentMediaDownloads: 1,
      allowBackgroundPrefetch: !disablePrefetch,
    );

    _updateOverrides(overrides);
  }

  void _upshift() {
    _isInLiteMode = false;
    _debugLog('⬆️ Upshifting to normal mode');

    _updateOverrides(PerformanceFlags.normalDefaults);
  }

  void _updateOverrides(PerformanceFlags overrides) {
    if (localOverrides.value != overrides) {
      localOverrides.value = overrides;
      _overridesController.add(overrides);
    }
  }

  /// Get current health metrics for debugging
  HealthMetrics getHealthMetrics() {
    return HealthMetrics(
      jankRate: _calculateJankRate(),
      feedLoadP95Ms: _calculateP95(_feedLoadMetrics),
      chatLoadP95Ms: _calculateP95(_chatLoadMetrics),
      videoInitP95Ms: _calculateP95(_videoInitMetrics),
      frameMetricsCount: _frameMetrics.length,
      isInLiteMode: _isInLiteMode,
      consecutiveBadEvaluations: _consecutiveBadEvaluations,
      consecutiveGoodEvaluations: _consecutiveGoodEvaluations,
    );
  }

  /// Force a specific mode (for testing/debugging)
  void forceMode(PerfMode mode) {
    if (mode == PerfMode.normal) {
      _upshift();
    } else {
      _isInLiteMode = true;
      _updateOverrides(PerformanceFlags.defaultsForMode(mode));
    }
  }

  /// Reset to normal mode
  void reset() {
    _consecutiveBadEvaluations = 0;
    _consecutiveGoodEvaluations = 0;
    _isInLiteMode = false;
    _frameMetrics.clear();
    _feedLoadMetrics.clear();
    _chatLoadMetrics.clear();
    _videoInitMetrics.clear();
    _updateOverrides(PerformanceFlags.normalDefaults);
    _debugLog('🔄 LocalPerformanceController reset');
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[LocalPerf] $message');
    }
  }

  void dispose() {
    _evaluationTimer?.cancel();
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    _overridesController.close();
  }
}

/// Base class for timestamped metrics
abstract class _TimestampedMetric {
  DateTime get timestamp;
}

/// Frame timing metric
class _FrameMetric implements _TimestampedMetric {
  @override
  final DateTime timestamp;
  final int buildMs;
  final int rasterMs;
  final int totalMs;
  final bool isJanky;

  _FrameMetric({
    required this.timestamp,
    required this.buildMs,
    required this.rasterMs,
    required this.totalMs,
    required this.isJanky,
  });
}

/// Latency metric for various operations
class _LatencyMetric implements _TimestampedMetric {
  @override
  final DateTime timestamp;
  final int durationMs;

  _LatencyMetric({
    required this.timestamp,
    required this.durationMs,
  });
}

/// Health metrics snapshot for debugging
class HealthMetrics {
  final double jankRate;
  final int feedLoadP95Ms;
  final int chatLoadP95Ms;
  final int videoInitP95Ms;
  final int frameMetricsCount;
  final bool isInLiteMode;
  final int consecutiveBadEvaluations;
  final int consecutiveGoodEvaluations;

  HealthMetrics({
    required this.jankRate,
    required this.feedLoadP95Ms,
    required this.chatLoadP95Ms,
    required this.videoInitP95Ms,
    required this.frameMetricsCount,
    required this.isInLiteMode,
    required this.consecutiveBadEvaluations,
    required this.consecutiveGoodEvaluations,
  });

  @override
  String toString() {
    return 'HealthMetrics(jank: ${(jankRate * 100).toStringAsFixed(1)}%, '
        'feedP95: ${feedLoadP95Ms}ms, chatP95: ${chatLoadP95Ms}ms, '
        'videoP95: ${videoInitP95Ms}ms, lite: $isInLiteMode)';
  }
}
