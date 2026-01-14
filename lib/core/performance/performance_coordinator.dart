import 'dart:async';
import 'package:flutter/foundation.dart';
import 'performance_flags.dart';
import 'remote_config_service.dart';
import 'local_performance_controller.dart';

/// Coordinator that merges Remote Config flags with Local Adaptive overrides.
/// Exposes the effective flags that should be used throughout the app.
/// 
/// Merging priority:
/// - Remote flags define the ceiling
/// - Local overrides can only downshift (normal->lite), not upshift beyond remote
class PerformanceCoordinator {
  static final PerformanceCoordinator _instance = PerformanceCoordinator._internal();
  factory PerformanceCoordinator() => _instance;
  PerformanceCoordinator._internal();

  final RemoteConfigService _remoteConfig = RemoteConfigService();
  final LocalPerformanceController _localController = LocalPerformanceController();

  bool _initialized = false;

  /// Current effective flags (notifies listeners on change)
  final ValueNotifier<PerformanceFlags> effectiveFlags = 
      ValueNotifier<PerformanceFlags>(PerformanceFlags.normalDefaults);

  /// Stream of effective flags changes
  Stream<PerformanceFlags> get effectiveFlagsStream => _flagsController.stream;
  final StreamController<PerformanceFlags> _flagsController = 
      StreamController<PerformanceFlags>.broadcast();

  /// Initialize the coordinator (call once at app startup)
  /// Does NOT block on network - returns immediately with defaults
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Initialize both services (non-blocking)
    await _remoteConfig.init();
    _localController.init();

    // Listen for changes from both sources
    _remoteConfig.remoteFlags.addListener(_onFlagsChanged);
    _localController.localOverrides.addListener(_onFlagsChanged);

    // Compute initial effective flags
    _computeEffectiveFlags();

    _debugLog('✅ PerformanceCoordinator initialized');
  }

  void _onFlagsChanged() {
    _computeEffectiveFlags();
  }

  void _computeEffectiveFlags() {
    final remote = _remoteConfig.remoteFlags.value;
    final local = _localController.localOverrides.value;

    // Merge: remote is ceiling, local can only downshift
    final effective = remote.mergeWithLocalOverride(local);

    if (effectiveFlags.value != effective) {
      effectiveFlags.value = effective;
      _flagsController.add(effective);
      _debugLog('🎯 Effective flags: ${effective.perfMode.name} '
          '(remote: ${remote.perfMode.name}, local: ${local.perfMode.name})');
    }
  }

  /// Get current effective flags (synchronous)
  PerformanceFlags get flags => effectiveFlags.value;

  /// Convenience getters for common flags
  bool get videoAutoplayEnabled => flags.videoAutoplayEnabled;
  int get videoWarmPlayersCount => flags.videoWarmPlayersCount;
  int get videoPreloadCount => flags.videoPreloadCount;
  int get feedPageSize => flags.feedPageSize;
  int get chatPageSize => flags.chatPageSize;
  bool get enableRealtimeListenersForLists => flags.enableRealtimeListenersForLists;
  MediaQualityHint get mediaQualityHint => flags.mediaQualityHint;
  bool get thumbnailsOnlyUntilFocused => flags.thumbnailsOnlyUntilFocused;
  int get maxConcurrentMediaDownloads => flags.maxConcurrentMediaDownloads;
  bool get allowBackgroundPrefetch => flags.allowBackgroundPrefetch;
  PerfMode get perfMode => flags.perfMode;
  bool get isLiteMode => flags.perfMode == PerfMode.lite || flags.perfMode == PerfMode.ultra;

  /// Record performance metrics (delegates to local controller)
  void recordFeedLoadTime(int milliseconds) {
    _localController.recordFeedLoadTime(milliseconds);
  }

  void recordChatLoadTime(int milliseconds) {
    _localController.recordChatLoadTime(milliseconds);
  }

  void recordVideoInitTime(int milliseconds) {
    _localController.recordVideoInitTime(milliseconds);
  }

  /// Get health metrics for debugging
  HealthMetrics getHealthMetrics() {
    return _localController.getHealthMetrics();
  }

  /// Force refresh remote config
  Future<void> forceRefreshRemote() async {
    await _remoteConfig.forceRefresh();
  }

  /// Force a specific local mode (for testing)
  void forceLocalMode(PerfMode mode) {
    _localController.forceMode(mode);
  }

  /// Reset local adaptations
  void resetLocalAdaptations() {
    _localController.reset();
  }

  /// Get debug info
  Map<String, dynamic> getDebugInfo() {
    final health = _localController.getHealthMetrics();
    return {
      'effectiveMode': flags.perfMode.name,
      'remoteMode': _remoteConfig.remoteFlags.value.perfMode.name,
      'localMode': _localController.localOverrides.value.perfMode.name,
      'hasRemoteData': _remoteConfig.hasRemoteData,
      'jankRate': '${(health.jankRate * 100).toStringAsFixed(1)}%',
      'feedP95Ms': health.feedLoadP95Ms,
      'chatP95Ms': health.chatLoadP95Ms,
      'videoP95Ms': health.videoInitP95Ms,
      'isInLiteMode': health.isInLiteMode,
      'videoAutoplay': flags.videoAutoplayEnabled,
      'feedPageSize': flags.feedPageSize,
      'prefetchEnabled': flags.allowBackgroundPrefetch,
    };
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[PerfCoord] $message');
    }
  }

  void dispose() {
    _remoteConfig.remoteFlags.removeListener(_onFlagsChanged);
    _localController.localOverrides.removeListener(_onFlagsChanged);
    _flagsController.close();
    _remoteConfig.dispose();
    _localController.dispose();
  }
}

/// Global accessor for performance flags (convenience)
PerformanceFlags get perfFlags => PerformanceCoordinator().flags;
