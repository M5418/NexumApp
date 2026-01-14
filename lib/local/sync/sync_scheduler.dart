import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Scheduler for background sync operations.
/// Triggers sync without hurting scroll performance.
class SyncScheduler with WidgetsBindingObserver {
  static final SyncScheduler _instance = SyncScheduler._internal();
  factory SyncScheduler() => _instance;
  SyncScheduler._internal();

  bool _initialized = false;
  Timer? _periodicTimer;

  /// Callbacks for each module's sync
  final Map<String, Future<void> Function()> _syncCallbacks = {};

  /// In-flight guards to prevent concurrent syncs
  final Set<String> _inFlightSyncs = {};

  /// Scrolling state per module (pause sync while scrolling)
  final Map<String, bool> _isScrolling = {};

  /// Debounce timers
  final Map<String, Timer?> _debounceTimers = {};

  /// Periodic sync interval
  static const Duration _periodicInterval = Duration(minutes: 3);

  /// Debounce duration
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  void init() {
    if (_initialized) return;
    _initialized = true;

    // Listen for app lifecycle
    WidgetsBinding.instance.addObserver(this);

    // Start periodic sync
    _periodicTimer = Timer.periodic(_periodicInterval, (_) {
      _triggerAllSyncs(reason: 'periodic');
    });

    _debugLog('✅ SyncScheduler initialized');
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
    } catch (e) {
      _debugLog('❌ Failed $module sync: $e');
    } finally {
      _inFlightSyncs.remove(module);
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
