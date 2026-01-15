import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Scheduler for background sync operations.
/// Triggers sync without hurting scroll performance.
/// 
/// Production hardening:
/// - In-flight guards per module
/// - Exponential backoff on repeated failures
/// - Scroll-aware (pauses during scroll)
/// - Emergency safe mode support
class SyncScheduler with WidgetsBindingObserver {
  static final SyncScheduler _instance = SyncScheduler._internal();
  factory SyncScheduler() => _instance;
  SyncScheduler._internal();

  bool _initialized = false;
  Timer? _periodicTimer;
  bool _emergencySafeMode = false;

  /// Callbacks for each module's sync
  final Map<String, Future<void> Function()> _syncCallbacks = {};

  /// In-flight guards to prevent concurrent syncs
  final Set<String> _inFlightSyncs = {};

  /// Scrolling state per module (pause sync while scrolling)
  final Map<String, bool> _isScrolling = {};

  /// Debounce timers
  final Map<String, Timer?> _debounceTimers = {};

  /// Failure counts for exponential backoff
  final Map<String, int> _failureCounts = {};

  /// Next allowed sync time per module (for backoff)
  final Map<String, DateTime> _nextAllowedSync = {};

  /// Periodic sync interval
  static const Duration _periodicInterval = Duration(minutes: 3);

  /// Debounce duration
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  /// Max consecutive failures before long backoff
  static const int _maxFailures = 5;

  /// Base backoff duration (doubles with each failure)
  static const Duration _baseBackoff = Duration(seconds: 30);

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Check for emergency safe mode
    await _checkEmergencySafeMode();

    // Listen for app lifecycle
    WidgetsBinding.instance.addObserver(this);

    // Start periodic sync (only if not in safe mode)
    if (!_emergencySafeMode) {
      _periodicTimer = Timer.periodic(_periodicInterval, (_) {
        _triggerAllSyncs(reason: 'periodic');
      });
    }

    _debugLog('✅ SyncScheduler initialized (safeMode: $_emergencySafeMode)');
  }

  /// Check if emergency safe mode is enabled
  Future<void> _checkEmergencySafeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _emergencySafeMode = prefs.getBool('emergency_safe_mode') ?? false;
      if (_emergencySafeMode) {
        _debugLog('⚠️ Emergency safe mode enabled - sync disabled');
      }
    } catch (e) {
      _debugLog('⚠️ Could not check safe mode: $e');
    }
  }

  /// Enable/disable emergency safe mode
  Future<void> setEmergencySafeMode(bool enabled) async {
    _emergencySafeMode = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('emergency_safe_mode', enabled);
      _debugLog('🚨 Emergency safe mode: $enabled');
      
      if (enabled) {
        _periodicTimer?.cancel();
        _periodicTimer = null;
      } else {
        _periodicTimer ??= Timer.periodic(_periodicInterval, (_) {
          _triggerAllSyncs(reason: 'periodic');
        });
      }
    } catch (e) {
      _debugLog('⚠️ Could not set safe mode: $e');
    }
  }

  /// Register a sync callback for a module
  void registerModule(String module, Future<void> Function() syncCallback) {
    _syncCallbacks[module] = syncCallback;
    _debugLog('📝 Registered sync for: $module');
  }

  /// Unregister a module
  void unregisterModule(String module) {
    _syncCallbacks.remove(module);
    _debounceTimers[module]?.cancel();
    _debounceTimers.remove(module);
    _isScrolling.remove(module);
    _debugLog('🗑️ Unregistered sync for: $module');
  }

  /// Trigger sync for a specific module (debounced)
  void triggerSync(String module, {String reason = 'manual'}) {
    // Cancel existing debounce
    _debounceTimers[module]?.cancel();

    // Debounce the sync
    _debounceTimers[module] = Timer(_debounceDuration, () {
      _executeSync(module, reason: reason);
    });
  }

  /// Trigger sync immediately (no debounce)
  Future<void> triggerSyncNow(String module, {String reason = 'immediate'}) async {
    _debounceTimers[module]?.cancel();
    await _executeSync(module, reason: reason);
  }

  /// Execute sync for a module
  Future<void> _executeSync(String module, {String reason = 'unknown'}) async {
    // Check emergency safe mode
    if (_emergencySafeMode) {
      _debugLog('🚨 Skipping $module sync (emergency safe mode)');
      return;
    }

    // Check if already in flight
    if (_inFlightSyncs.contains(module)) {
      _debugLog('⏭️ Skipping $module sync (already in flight)');
      return;
    }

    // Check if scrolling (pause heavy sync)
    if (_isScrolling[module] == true) {
      _debugLog('⏸️ Deferring $module sync (scrolling)');
      return;
    }

    // Check backoff
    final nextAllowed = _nextAllowedSync[module];
    if (nextAllowed != null && DateTime.now().isBefore(nextAllowed)) {
      _debugLog('⏳ Skipping $module sync (backoff until $nextAllowed)');
      return;
    }

    final callback = _syncCallbacks[module];
    if (callback == null) {
      _debugLog('⚠️ No sync callback for: $module');
      return;
    }

    _inFlightSyncs.add(module);
    _debugLog('🔄 Starting $module sync ($reason)');

    try {
      await callback();
      _debugLog('✅ Completed $module sync');
      // Reset failure count on success
      _failureCounts[module] = 0;
      _nextAllowedSync.remove(module);
    } catch (e) {
      _debugLog('❌ Failed $module sync: $e');
      // Apply exponential backoff
      _applyBackoff(module);
    } finally {
      _inFlightSyncs.remove(module);
    }
  }

  /// Apply exponential backoff after failure
  void _applyBackoff(String module) {
    final failures = (_failureCounts[module] ?? 0) + 1;
    _failureCounts[module] = failures;

    if (failures >= _maxFailures) {
      // Long backoff after max failures
      _nextAllowedSync[module] = DateTime.now().add(const Duration(minutes: 15));
      _debugLog('⚠️ $module hit max failures, backing off for 15 minutes');
    } else {
      // Exponential backoff: 30s, 60s, 120s, 240s...
      final backoffSeconds = _baseBackoff.inSeconds * (1 << (failures - 1));
      _nextAllowedSync[module] = DateTime.now().add(Duration(seconds: backoffSeconds));
      _debugLog('⏳ $module backoff: ${backoffSeconds}s (failure $failures)');
    }
  }

  /// Trigger sync for all registered modules
  void _triggerAllSyncs({String reason = 'all'}) {
    for (final module in _syncCallbacks.keys) {
      triggerSync(module, reason: reason);
    }
  }

  /// Mark a module as scrolling (pause sync)
  void setScrolling(String module, bool isScrolling) {
    _isScrolling[module] = isScrolling;
    
    // Resume sync when scrolling stops
    if (!isScrolling && _syncCallbacks.containsKey(module)) {
      triggerSync(module, reason: 'scroll_stopped');
    }
  }

  /// Check if a module is currently syncing
  bool isSyncing(String module) => _inFlightSyncs.contains(module);

  /// App lifecycle: trigger sync on resume
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _debugLog('📱 App resumed - triggering sync');
      _triggerAllSyncs(reason: 'app_resume');
    }
  }

  /// Trigger initial sync after first frame
  void triggerInitialSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _debugLog('🚀 First frame complete - triggering initial sync');
      _triggerAllSyncs(reason: 'initial');
    });
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[SyncScheduler] $message');
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _periodicTimer?.cancel();
    for (final timer in _debounceTimers.values) {
      timer?.cancel();
    }
    _debounceTimers.clear();
    _syncCallbacks.clear();
    _inFlightSyncs.clear();
    _isScrolling.clear();
  }
}
