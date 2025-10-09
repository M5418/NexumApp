import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Utilities for handling server timestamps:
/// - Parse server timestamps as UTC
/// - Convert to local for display
/// - Produce relative labels ("just now", "5m", etc.)
class TimeUtils {
  // Register long and short English locales once.
  static final bool _initialized = _initLocales();

  static bool _initLocales() {
    timeago.setLocaleMessages('en', timeago.EnMessages());
    timeago.setLocaleMessages('en_short', timeago.EnShortMessages());
    return true;
  }

  /// Parse a server timestamp and return a local DateTime for display.
  ///
  /// Accepts:
  /// - ISO strings (with or without 'Z' / timezone offset)
  /// - 'YYYY-MM-DD HH:mm:ss' (treated as UTC)
  /// - int epoch seconds or milliseconds
  static DateTime parseToLocal(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }

    if (value is DateTime) {
      // If already DateTime, respect its timezone and convert to local.
      return value.toLocal();
    }

    if (value is int) {
      // Heuristic: seconds vs milliseconds
      // < 10^12 => seconds; otherwise milliseconds
      final isSeconds = value.abs() < 1000000000000;
      final utc = isSeconds
          ? DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true)
          : DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
      return utc.toLocal();
    }

    if (value is String) {
      var s = value.trim();

      // If it's already ISO with 'T'
      if (!s.contains('T')) {
        // Convert 'YYYY-MM-DD HH:mm:ss' -> 'YYYY-MM-DDTHH:mm:ss'
        s = s.replaceFirst(' ', 'T');
      }

      // Ensure we treat as UTC if no explicit TZ provided
      final hasTz = RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(s);
      if (!hasTz) {
        s = '${s}Z';
      }

      // Parse as UTC, then convert to local for display.
      final utc = DateTime.parse(s).toUtc();
      return utc.toLocal();
    }

    // Fallback
    return DateTime.now();
  }

  /// Relative time label, e.g., "just now", "5m".
  /// For concise format, pass locale: 'en_short'.
  static String relativeLabel(
    dynamic value, {
    String locale = 'en',
    bool allowFromNow = true,
  }) {
    // Ensure initialization is referenced so it runs.
    if (!_initialized) {
      // no-op
    }
    final dtLocal = parseToLocal(value);
    return timeago.format(dtLocal, locale: locale, allowFromNow: allowFromNow);
  }

  /// Local clock string, e.g., "3:41 PM, Oct 9".
  static String localClock(
    dynamic value, {
    String pattern = 'h:mm a, MMM d',
    String? locale,
  }) {
    final dtLocal = parseToLocal(value);
    return DateFormat(pattern, locale).format(dtLocal);
  }
}