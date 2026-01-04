import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:flutter/widgets.dart' show RouteSettings;

/// Centralized analytics service for tracking screen views and events.
/// Uses Firebase Analytics (GA4) under the hood.
/// 
/// IMPORTANT: No PII (email, phone, names) should ever be sent in events.
/// NOTE: Analytics is disabled on web due to measurement ID fetch issues.
class AnalyticsService {
  AnalyticsService._internal();
  static final AnalyticsService _instance = AnalyticsService._internal();
  static AnalyticsService get instance => _instance;

  // Skip analytics on web to avoid crashes
  FirebaseAnalytics? get _analytics => kIsWeb ? null : FirebaseAnalytics.instance;

  /// Debug toggle: when true, prints each logged event to console.
  bool debugLogging = kDebugMode;

  /// Returns the FirebaseAnalyticsObserver for use in MaterialApp.navigatorObservers.
  /// Returns null on web since analytics is disabled.
  FirebaseAnalyticsObserver? get observer => _analytics != null 
      ? FirebaseAnalyticsObserver(
          analytics: _analytics!,
          nameExtractor: _extractScreenName,
        )
      : null;

  /// Extracts a clean screen name from route settings.
  /// Falls back to 'Unknown' if route name is null or empty.
  String _extractScreenName(RouteSettings settings) {
    final name = settings.name;
    if (name == null || name.isEmpty) {
      return 'Unknown';
    }
    // Remove leading slash if present
    return name.startsWith('/') ? name.substring(1) : name;
  }

  /// Logs a screen view event.
  /// 
  /// [screenName] - The name of the screen (e.g., 'home_feed', 'profile').
  /// [screenClass] - Optional class name for the screen widget.
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    if (debugLogging) {
      debugPrint('📊 Analytics: screen_view → $screenName (class: ${screenClass ?? 'N/A'})');
    }

    try {
      await _analytics?.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
    } catch (e) {
      if (debugLogging) {
        debugPrint('⚠️ Analytics error (screen_view): $e');
      }
    }
  }

  /// Logs a custom event with optional parameters.
  /// 
  /// [name] - Event name (must be alphanumeric with underscores, max 40 chars).
  /// [parameters] - Optional map of parameters (no PII allowed).
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (debugLogging) {
      debugPrint('📊 Analytics: event → $name ${parameters ?? {}}');
    }

    try {
      await _analytics?.logEvent(
        name: name,
        parameters: parameters,
      );
    } catch (e) {
      if (debugLogging) {
        debugPrint('⚠️ Analytics error (event): $e');
      }
    }
  }

  /// Sets the current screen for analytics (useful for manual tracking).
  /// Prefer using logScreenView for explicit screen tracking.
  Future<void> setCurrentScreen({
    required String screenName,
    String? screenClass,
  }) async {
    await logScreenView(screenName: screenName, screenClass: screenClass);
  }

  /// Sets a user property (non-PII only).
  /// 
  /// [name] - Property name (max 24 chars, alphanumeric + underscores).
  /// [value] - Property value (max 36 chars).
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    if (debugLogging) {
      debugPrint('📊 Analytics: user_property → $name = $value');
    }

    try {
      await _analytics?.setUserProperty(name: name, value: value);
    } catch (e) {
      if (debugLogging) {
        debugPrint('⚠️ Analytics error (user_property): $e');
      }
    }
  }

  /// Sets the user ID for analytics (use anonymized ID only, no PII).
  Future<void> setUserId(String? userId) async {
    if (debugLogging) {
      debugPrint('📊 Analytics: user_id → ${userId ?? 'null'}');
    }

    try {
      await _analytics?.setUserId(id: userId);
    } catch (e) {
      if (debugLogging) {
        debugPrint('⚠️ Analytics error (user_id): $e');
      }
    }
  }

  /// Enables or disables analytics collection.
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    if (debugLogging) {
      debugPrint('📊 Analytics: collection ${enabled ? 'ENABLED' : 'DISABLED'}');
    }

    try {
      await _analytics?.setAnalyticsCollectionEnabled(enabled);
    } catch (e) {
      if (debugLogging) {
        debugPrint('⚠️ Analytics error (setEnabled): $e');
      }
    }
  }
}
