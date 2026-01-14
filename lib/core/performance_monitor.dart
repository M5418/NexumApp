import 'package:flutter/foundation.dart';
import 'package:firebase_performance/firebase_performance.dart';

/// Centralized performance monitoring for the app.
/// Provides traces for module loads, pagination, media fetches, and chat operations.
/// Debug-only timing logs are guarded to avoid production overhead.
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  FirebasePerformance? _performance;
  final Map<String, Trace> _activeTraces = {};
  final Map<String, Stopwatch> _debugTimers = {};

  /// Initialize performance monitoring (call once at app startup)
  Future<void> init() async {
    try {
      _performance = FirebasePerformance.instance;
      // Enable data collection (respects user consent settings)
      await _performance?.setPerformanceCollectionEnabled(true);
      _debugLog('✅ Performance monitoring initialized');
    } catch (e) {
      _debugLog('⚠️ Performance monitoring init failed: $e');
    }
  }

  // ============================================================
  // TRACE MANAGEMENT
  // ============================================================

  /// Start a named trace for a module operation
  Future<void> startTrace(String name) async {
    if (_performance == null) return;
    try {
      final perf = _performance;
      if (perf == null) return;
      final trace = perf.newTrace(name);
      await trace.start();
      _activeTraces[name] = trace;
      _startDebugTimer(name);
    } catch (e) {
      _debugLog('⚠️ Failed to start trace $name: $e');
    }
  }

  /// Stop a named trace and record metrics
  Future<void> stopTrace(String name, {Map<String, int>? metrics}) async {
    final trace = _activeTraces.remove(name);
    if (trace == null) return;
    
    try {
      // Add custom metrics if provided
      if (metrics != null) {
        for (final entry in metrics.entries) {
          trace.setMetric(entry.key, entry.value);
        }
      }
      await trace.stop();
      _stopDebugTimer(name);
    } catch (e) {
      _debugLog('⚠️ Failed to stop trace $name: $e');
    }
  }

  /// Add an attribute to an active trace
  void setTraceAttribute(String traceName, String key, String value) {
    final trace = _activeTraces[traceName];
    if (trace == null) return;
    try {
      trace.putAttribute(key, value);
    } catch (e) {
      _debugLog('⚠️ Failed to set attribute on $traceName: $e');
    }
  }

  /// Increment a metric on an active trace
  void incrementTraceMetric(String traceName, String metric, int value) {
    final trace = _activeTraces[traceName];
    if (trace == null) return;
    try {
      trace.incrementMetric(metric, value);
    } catch (e) {
      _debugLog('⚠️ Failed to increment metric on $traceName: $e');
    }
  }

  // ============================================================
  // MODULE-SPECIFIC TRACES
  // ============================================================

  /// Trace: Home feed initial load
  Future<void> startFeedLoad() => startTrace('feed_initial_load');
  Future<void> stopFeedLoad({int? postCount}) => stopTrace(
    'feed_initial_load',
    metrics: postCount != null ? {'post_count': postCount} : null,
  );

  /// Trace: Feed pagination
  Future<void> startFeedPagination() => startTrace('feed_pagination');
  Future<void> stopFeedPagination({int? postCount}) => stopTrace(
    'feed_pagination',
    metrics: postCount != null ? {'post_count': postCount} : null,
  );

  /// Trace: Video scroll page load
  Future<void> startVideoScrollLoad() => startTrace('video_scroll_load');
  Future<void> stopVideoScrollLoad({int? videoCount}) => stopTrace(
    'video_scroll_load',
    metrics: videoCount != null ? {'video_count': videoCount} : null,
  );

  /// Trace: Community posts load
  Future<void> startCommunityLoad(String communityId) async {
    await startTrace('community_posts_load');
    setTraceAttribute('community_posts_load', 'community_id', communityId);
  }
  Future<void> stopCommunityLoad({int? postCount}) => stopTrace(
    'community_posts_load',
    metrics: postCount != null ? {'post_count': postCount} : null,
  );

  /// Trace: Conversations list load
  Future<void> startConversationsLoad() => startTrace('conversations_load');
  Future<void> stopConversationsLoad({int? count}) => stopTrace(
    'conversations_load',
    metrics: count != null ? {'conversation_count': count} : null,
  );

  /// Trace: Chat messages load
  Future<void> startChatLoad(String conversationId) async {
    await startTrace('chat_messages_load');
    setTraceAttribute('chat_messages_load', 'conversation_id', conversationId);
  }
  Future<void> stopChatLoad({int? messageCount}) => stopTrace(
    'chat_messages_load',
    metrics: messageCount != null ? {'message_count': messageCount} : null,
  );

  /// Trace: Podcasts page load
  Future<void> startPodcastsLoad() => startTrace('podcasts_load');
  Future<void> stopPodcastsLoad({int? count}) => stopTrace(
    'podcasts_load',
    metrics: count != null ? {'podcast_count': count} : null,
  );

  /// Trace: Books page load
  Future<void> startBooksLoad() => startTrace('books_load');
  Future<void> stopBooksLoad({int? count}) => stopTrace(
    'books_load',
    metrics: count != null ? {'book_count': count} : null,
  );

  /// Trace: Profile page load
  Future<void> startProfileLoad() => startTrace('profile_load');
  Future<void> stopProfileLoad() => stopTrace('profile_load');

  /// Trace: Media fetch (images/videos)
  Future<void> startMediaFetch(String mediaType) async {
    await startTrace('media_fetch_$mediaType');
  }
  Future<void> stopMediaFetch(String mediaType, {int? sizeBytes}) => stopTrace(
    'media_fetch_$mediaType',
    metrics: sizeBytes != null ? {'size_bytes': sizeBytes} : null,
  );

  /// Trace: Auth/login flow
  Future<void> startAuthFlow() => startTrace('auth_flow');
  Future<void> stopAuthFlow({bool? success}) => stopTrace(
    'auth_flow',
    metrics: success != null ? {'success': success ? 1 : 0} : null,
  );

  // ============================================================
  // DEBUG TIMING (guarded, debug mode only)
  // ============================================================

  void _startDebugTimer(String name) {
    if (!kDebugMode) return;
    _debugTimers[name] = Stopwatch()..start();
  }

  void _stopDebugTimer(String name) {
    if (!kDebugMode) return;
    final timer = _debugTimers.remove(name);
    if (timer != null) {
      timer.stop();
      _debugLog('⏱️ [$name] ${timer.elapsedMilliseconds}ms');
    }
  }

  /// Manual debug timing for code blocks
  Stopwatch? debugStart(String label) {
    if (!kDebugMode) return null;
    _debugLog('⏱️ [$label] started');
    return Stopwatch()..start();
  }

  void debugStop(String label, Stopwatch? timer) {
    if (!kDebugMode || timer == null) return;
    timer.stop();
    _debugLog('⏱️ [$label] ${timer.elapsedMilliseconds}ms');
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  // ============================================================
  // HTTP METRIC TRACKING
  // ============================================================

  /// Create an HTTP metric for tracking network requests
  Future<HttpMetric?> createHttpMetric(String url, HttpMethod method) async {
    if (_performance == null) return null;
    try {
      final perf = _performance;
      if (perf == null) return null;
      return perf.newHttpMetric(url, method);
    } catch (e) {
      _debugLog('⚠️ Failed to create HTTP metric: $e');
      return null;
    }
  }
}

/// Convenience function for quick trace wrapping
Future<T> traceAsync<T>(String name, Future<T> Function() operation) async {
  final monitor = PerformanceMonitor();
  await monitor.startTrace(name);
  try {
    return await operation();
  } finally {
    await monitor.stopTrace(name);
  }
}
