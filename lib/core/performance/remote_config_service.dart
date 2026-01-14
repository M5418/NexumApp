import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'performance_flags.dart';

/// Service for Firebase Remote Config integration.
/// Fetches performance flags from backend and exposes them via ValueNotifier.
class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  FirebaseRemoteConfig? _remoteConfig;
  bool _initialized = false;

  /// Current remote flags (notifies listeners on change)
  final ValueNotifier<PerformanceFlags> remoteFlags = 
      ValueNotifier<PerformanceFlags>(PerformanceFlags.normalDefaults);

  /// Stream of remote flags changes
  Stream<PerformanceFlags> get remoteFlagsStream => _flagsController.stream;
  final StreamController<PerformanceFlags> _flagsController = 
      StreamController<PerformanceFlags>.broadcast();

  /// Whether remote config has been successfully fetched at least once
  bool get hasRemoteData => _initialized && _lastFetchSuccess;
  bool _lastFetchSuccess = false;

  // Remote Config parameter keys
  static const String _keyPerfModeGlobal = 'perf_mode_global';
  static const String _keyPerfFlagsJson = 'perf_flags_json';
  static const String _keyKillSwitchVideoAutoplay = 'kill_switch_video_autoplay';
  static const String _keyKillSwitchPrefetch = 'kill_switch_prefetch';
  static const String _keyPerfFeedPageSize = 'perf_feed_page_size';
  static const String _keyPerfChatPageSize = 'perf_chat_page_size';
  static const String _keyEmergencySafeMode = 'emergency_safe_mode';

  /// Initialize Remote Config with local defaults.
  /// Does NOT block on network fetch - returns immediately with defaults.
  Future<void> init() async {
    if (_initialized) return;

    try {
      _remoteConfig = FirebaseRemoteConfig.instance;
      final config = _remoteConfig;
      if (config == null) return;

      // Set fetch settings
      await config.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode 
            ? const Duration(minutes: 1)  // Shorter for debug
            : const Duration(minutes: 15), // Production
      ));

      // Set local defaults (app works offline with these)
      await config.setDefaults({
        _keyPerfModeGlobal: 'normal',
        _keyPerfFlagsJson: '',
        _keyKillSwitchVideoAutoplay: false,
        _keyKillSwitchPrefetch: false,
        _keyPerfFeedPageSize: 10,
        _keyPerfChatPageSize: 30,
        _keyEmergencySafeMode: false,
      });

      _initialized = true;
      _debugLog('✅ RemoteConfigService initialized with defaults');

      // Fetch in background (non-blocking)
      _fetchAndActivate();

      // Listen for real-time updates (if available)
      config.onConfigUpdated.listen((event) {
        _debugLog('📡 Remote Config updated: ${event.updatedKeys}');
        _activateAndParse();
      });

    } catch (e) {
      _debugLog('⚠️ RemoteConfigService init failed: $e');
      // Continue with defaults - don't crash
    }
  }

  /// Fetch and activate remote config (non-blocking)
  Future<void> _fetchAndActivate() async {
    try {
      final config = _remoteConfig;
      if (config == null) return;

      final activated = await config.fetchAndActivate();
      _lastFetchSuccess = true;
      _debugLog('📡 Remote Config fetched, activated: $activated');
      _parseAndNotify();
    } catch (e) {
      _debugLog('⚠️ Remote Config fetch failed: $e');
      // Keep using defaults
    }
  }

  /// Activate cached config and parse
  Future<void> _activateAndParse() async {
    try {
      final config = _remoteConfig;
      if (config == null) return;

      await config.activate();
      _parseAndNotify();
    } catch (e) {
      _debugLog('⚠️ Remote Config activate failed: $e');
    }
  }

  /// Parse remote config values and notify listeners
  void _parseAndNotify() {
    final config = _remoteConfig;
    if (config == null) return;

    try {
      // Check emergency safe mode first
      final emergencySafeMode = config.getBool(_keyEmergencySafeMode);
      if (emergencySafeMode) {
        _debugLog('🚨 Emergency safe mode enabled - using ultra defaults');
        _updateFlags(PerformanceFlags.ultraDefaults);
        return;
      }

      // Try to parse full JSON flags first (preferred)
      final flagsJson = config.getString(_keyPerfFlagsJson);
      PerformanceFlags flags;
      
      if (flagsJson.isNotEmpty) {
        flags = PerformanceFlags.fromJsonString(flagsJson);
        _debugLog('📋 Parsed flags from JSON: ${flags.perfMode.name}');
      } else {
        // Fall back to individual parameters
        final modeStr = config.getString(_keyPerfModeGlobal);
        final mode = PerfMode.fromString(modeStr);
        flags = PerformanceFlags.defaultsForMode(mode);
        _debugLog('📋 Using mode defaults: ${mode.name}');
      }

      // Apply kill switches (emergency overrides)
      final killVideoAutoplay = config.getBool(_keyKillSwitchVideoAutoplay);
      final killPrefetch = config.getBool(_keyKillSwitchPrefetch);
      final feedPageSize = config.getInt(_keyPerfFeedPageSize);
      final chatPageSize = config.getInt(_keyPerfChatPageSize);

      if (killVideoAutoplay || killPrefetch || feedPageSize > 0 || chatPageSize > 0) {
        flags = flags.copyWith(
          videoAutoplayEnabled: killVideoAutoplay ? false : flags.videoAutoplayEnabled,
          allowBackgroundPrefetch: killPrefetch ? false : flags.allowBackgroundPrefetch,
          feedPageSize: feedPageSize > 0 ? feedPageSize.clamp(3, 20) : flags.feedPageSize,
          chatPageSize: chatPageSize > 0 ? chatPageSize.clamp(10, 50) : flags.chatPageSize,
        );
        _debugLog('🔧 Applied kill switches/overrides');
      }

      _updateFlags(flags);
    } catch (e) {
      _debugLog('⚠️ Remote Config parse error: $e');
      // Keep current flags on parse error
    }
  }

  void _updateFlags(PerformanceFlags flags) {
    if (remoteFlags.value != flags) {
      remoteFlags.value = flags;
      _flagsController.add(flags);
      _debugLog('🎯 Remote flags updated: ${flags.perfMode.name}');
    }
  }

  /// Force refresh from server (call sparingly)
  Future<void> forceRefresh() async {
    final config = _remoteConfig;
    if (config == null) return;

    try {
      await config.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: Duration.zero, // Force fetch
      ));
      await _fetchAndActivate();
      
      // Restore normal interval
      await config.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode 
            ? const Duration(minutes: 1)
            : const Duration(minutes: 15),
      ));
    } catch (e) {
      _debugLog('⚠️ Force refresh failed: $e');
    }
  }

  /// Get current value of a specific parameter (for debugging)
  String getStringValue(String key) {
    return _remoteConfig?.getString(key) ?? '';
  }

  bool getBoolValue(String key) {
    return _remoteConfig?.getBool(key) ?? false;
  }

  int getIntValue(String key) {
    return _remoteConfig?.getInt(key) ?? 0;
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[RemoteConfig] $message');
    }
  }

  void dispose() {
    _flagsController.close();
  }
}
