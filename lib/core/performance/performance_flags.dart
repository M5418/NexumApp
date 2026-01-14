import 'dart:convert';

/// Performance mode levels
enum PerfMode {
  normal,
  lite,
  ultra;

  static PerfMode fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'lite':
        return PerfMode.lite;
      case 'ultra':
        return PerfMode.ultra;
      default:
        return PerfMode.normal;
    }
  }
}

/// Media quality hint levels
enum MediaQualityHint {
  high,
  balanced,
  low;

  static MediaQualityHint fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'high':
        return MediaQualityHint.high;
      case 'low':
        return MediaQualityHint.low;
      default:
        return MediaQualityHint.balanced;
    }
  }
}

/// Immutable performance flags model that controls app behavior without UI redesign.
/// Used by both Remote Config and Local Adaptive systems.
class PerformanceFlags {
  final PerfMode perfMode;
  final bool videoAutoplayEnabled;
  final int videoWarmPlayersCount;
  final int videoPreloadCount;
  final int feedPageSize;
  final int chatPageSize;
  final bool enableRealtimeListenersForLists;
  final MediaQualityHint mediaQualityHint;
  final bool thumbnailsOnlyUntilFocused;
  final int maxConcurrentMediaDownloads;
  final bool allowBackgroundPrefetch;

  const PerformanceFlags({
    this.perfMode = PerfMode.normal,
    this.videoAutoplayEnabled = true,
    this.videoWarmPlayersCount = 1,
    this.videoPreloadCount = 1,
    this.feedPageSize = 10,
    this.chatPageSize = 30,
    this.enableRealtimeListenersForLists = true,
    this.mediaQualityHint = MediaQualityHint.high,
    this.thumbnailsOnlyUntilFocused = false,
    this.maxConcurrentMediaDownloads = 3,
    this.allowBackgroundPrefetch = true,
  });

  /// Default flags for normal mode
  static const PerformanceFlags normalDefaults = PerformanceFlags(
    perfMode: PerfMode.normal,
    videoAutoplayEnabled: true,
    videoWarmPlayersCount: 1,
    videoPreloadCount: 1,
    feedPageSize: 10,
    chatPageSize: 30,
    enableRealtimeListenersForLists: true,
    mediaQualityHint: MediaQualityHint.high,
    thumbnailsOnlyUntilFocused: false,
    maxConcurrentMediaDownloads: 3,
    allowBackgroundPrefetch: true,
  );

  /// Default flags for lite mode (reduced resource usage)
  static const PerformanceFlags liteDefaults = PerformanceFlags(
    perfMode: PerfMode.lite,
    videoAutoplayEnabled: false,
    videoWarmPlayersCount: 0,
    videoPreloadCount: 0,
    feedPageSize: 6,
    chatPageSize: 20,
    enableRealtimeListenersForLists: false,
    mediaQualityHint: MediaQualityHint.balanced,
    thumbnailsOnlyUntilFocused: true,
    maxConcurrentMediaDownloads: 1,
    allowBackgroundPrefetch: false,
  );

  /// Default flags for ultra mode (maximum performance, minimal features)
  static const PerformanceFlags ultraDefaults = PerformanceFlags(
    perfMode: PerfMode.ultra,
    videoAutoplayEnabled: false,
    videoWarmPlayersCount: 0,
    videoPreloadCount: 0,
    feedPageSize: 5,
    chatPageSize: 15,
    enableRealtimeListenersForLists: false,
    mediaQualityHint: MediaQualityHint.low,
    thumbnailsOnlyUntilFocused: true,
    maxConcurrentMediaDownloads: 1,
    allowBackgroundPrefetch: false,
  );

  /// Get defaults for a specific mode
  static PerformanceFlags defaultsForMode(PerfMode mode) {
    switch (mode) {
      case PerfMode.lite:
        return liteDefaults;
      case PerfMode.ultra:
        return ultraDefaults;
      case PerfMode.normal:
        return normalDefaults;
    }
  }

  /// Parse from JSON string safely
  static PerformanceFlags fromJsonString(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) {
      return normalDefaults;
    }
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      return fromMap(map);
    } catch (_) {
      return normalDefaults;
    }
  }

  /// Parse from Map safely with defaults
  static PerformanceFlags fromMap(Map<String, dynamic>? map) {
    if (map == null) return normalDefaults;

    final mode = PerfMode.fromString(map['perfMode'] as String?);
    final defaults = defaultsForMode(mode);

    return PerformanceFlags(
      perfMode: mode,
      videoAutoplayEnabled: _safeBool(map['videoAutoplayEnabled'], defaults.videoAutoplayEnabled),
      videoWarmPlayersCount: _safeInt(map['videoWarmPlayersCount'], defaults.videoWarmPlayersCount, min: 0, max: 2),
      videoPreloadCount: _safeInt(map['videoPreloadCount'], defaults.videoPreloadCount, min: 0, max: 3),
      feedPageSize: _safeInt(map['feedPageSize'], defaults.feedPageSize, min: 3, max: 20),
      chatPageSize: _safeInt(map['chatPageSize'], defaults.chatPageSize, min: 10, max: 50),
      enableRealtimeListenersForLists: _safeBool(map['enableRealtimeListenersForLists'], defaults.enableRealtimeListenersForLists),
      mediaQualityHint: MediaQualityHint.fromString(map['mediaQualityHint'] as String?),
      thumbnailsOnlyUntilFocused: _safeBool(map['thumbnailsOnlyUntilFocused'], defaults.thumbnailsOnlyUntilFocused),
      maxConcurrentMediaDownloads: _safeInt(map['maxConcurrentMediaDownloads'], defaults.maxConcurrentMediaDownloads, min: 1, max: 5),
      allowBackgroundPrefetch: _safeBool(map['allowBackgroundPrefetch'], defaults.allowBackgroundPrefetch),
    );
  }

  /// Convert to Map
  Map<String, dynamic> toMap() {
    return {
      'perfMode': perfMode.name,
      'videoAutoplayEnabled': videoAutoplayEnabled,
      'videoWarmPlayersCount': videoWarmPlayersCount,
      'videoPreloadCount': videoPreloadCount,
      'feedPageSize': feedPageSize,
      'chatPageSize': chatPageSize,
      'enableRealtimeListenersForLists': enableRealtimeListenersForLists,
      'mediaQualityHint': mediaQualityHint.name,
      'thumbnailsOnlyUntilFocused': thumbnailsOnlyUntilFocused,
      'maxConcurrentMediaDownloads': maxConcurrentMediaDownloads,
      'allowBackgroundPrefetch': allowBackgroundPrefetch,
    };
  }

  /// Convert to JSON string
  String toJsonString() => jsonEncode(toMap());

  /// Create a copy with modified values
  PerformanceFlags copyWith({
    PerfMode? perfMode,
    bool? videoAutoplayEnabled,
    int? videoWarmPlayersCount,
    int? videoPreloadCount,
    int? feedPageSize,
    int? chatPageSize,
    bool? enableRealtimeListenersForLists,
    MediaQualityHint? mediaQualityHint,
    bool? thumbnailsOnlyUntilFocused,
    int? maxConcurrentMediaDownloads,
    bool? allowBackgroundPrefetch,
  }) {
    return PerformanceFlags(
      perfMode: perfMode ?? this.perfMode,
      videoAutoplayEnabled: videoAutoplayEnabled ?? this.videoAutoplayEnabled,
      videoWarmPlayersCount: videoWarmPlayersCount ?? this.videoWarmPlayersCount,
      videoPreloadCount: videoPreloadCount ?? this.videoPreloadCount,
      feedPageSize: feedPageSize ?? this.feedPageSize,
      chatPageSize: chatPageSize ?? this.chatPageSize,
      enableRealtimeListenersForLists: enableRealtimeListenersForLists ?? this.enableRealtimeListenersForLists,
      mediaQualityHint: mediaQualityHint ?? this.mediaQualityHint,
      thumbnailsOnlyUntilFocused: thumbnailsOnlyUntilFocused ?? this.thumbnailsOnlyUntilFocused,
      maxConcurrentMediaDownloads: maxConcurrentMediaDownloads ?? this.maxConcurrentMediaDownloads,
      allowBackgroundPrefetch: allowBackgroundPrefetch ?? this.allowBackgroundPrefetch,
    );
  }

  /// Merge with another flags object, taking the more restrictive value.
  /// Used for local overrides that can only downshift, not upshift.
  PerformanceFlags mergeWithLocalOverride(PerformanceFlags localOverride) {
    return PerformanceFlags(
      // Take the more restrictive mode
      perfMode: _moreRestrictiveMode(perfMode, localOverride.perfMode),
      // Disable if either disables
      videoAutoplayEnabled: videoAutoplayEnabled && localOverride.videoAutoplayEnabled,
      // Take the lower value
      videoWarmPlayersCount: _min(videoWarmPlayersCount, localOverride.videoWarmPlayersCount),
      videoPreloadCount: _min(videoPreloadCount, localOverride.videoPreloadCount),
      feedPageSize: _min(feedPageSize, localOverride.feedPageSize),
      chatPageSize: _min(chatPageSize, localOverride.chatPageSize),
      // Disable if either disables
      enableRealtimeListenersForLists: enableRealtimeListenersForLists && localOverride.enableRealtimeListenersForLists,
      // Take the lower quality
      mediaQualityHint: _lowerQuality(mediaQualityHint, localOverride.mediaQualityHint),
      // Enable if either enables (more restrictive)
      thumbnailsOnlyUntilFocused: thumbnailsOnlyUntilFocused || localOverride.thumbnailsOnlyUntilFocused,
      // Take the lower value
      maxConcurrentMediaDownloads: _min(maxConcurrentMediaDownloads, localOverride.maxConcurrentMediaDownloads),
      // Disable if either disables
      allowBackgroundPrefetch: allowBackgroundPrefetch && localOverride.allowBackgroundPrefetch,
    );
  }

  // Helper: safe bool parsing
  static bool _safeBool(dynamic value, bool defaultValue) {
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is int) return value != 0;
    return defaultValue;
  }

  // Helper: safe int parsing with bounds
  static int _safeInt(dynamic value, int defaultValue, {int min = 0, int max = 100}) {
    int result = defaultValue;
    if (value is int) {
      result = value;
    } else if (value is double) {
      result = value.toInt();
    } else if (value is String) {
      result = int.tryParse(value) ?? defaultValue;
    }
    return result.clamp(min, max);
  }

  // Helper: get more restrictive mode
  static PerfMode _moreRestrictiveMode(PerfMode a, PerfMode b) {
    const order = [PerfMode.normal, PerfMode.lite, PerfMode.ultra];
    final indexA = order.indexOf(a);
    final indexB = order.indexOf(b);
    return order[indexA > indexB ? indexA : indexB];
  }

  // Helper: get lower quality
  static MediaQualityHint _lowerQuality(MediaQualityHint a, MediaQualityHint b) {
    const order = [MediaQualityHint.high, MediaQualityHint.balanced, MediaQualityHint.low];
    final indexA = order.indexOf(a);
    final indexB = order.indexOf(b);
    return order[indexA > indexB ? indexA : indexB];
  }

  // Helper: min of two ints
  static int _min(int a, int b) => a < b ? a : b;

  @override
  String toString() {
    return 'PerformanceFlags(mode: ${perfMode.name}, autoplay: $videoAutoplayEnabled, '
        'warm: $videoWarmPlayersCount, preload: $videoPreloadCount, feedPage: $feedPageSize)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PerformanceFlags &&
        other.perfMode == perfMode &&
        other.videoAutoplayEnabled == videoAutoplayEnabled &&
        other.videoWarmPlayersCount == videoWarmPlayersCount &&
        other.videoPreloadCount == videoPreloadCount &&
        other.feedPageSize == feedPageSize &&
        other.chatPageSize == chatPageSize &&
        other.enableRealtimeListenersForLists == enableRealtimeListenersForLists &&
        other.mediaQualityHint == mediaQualityHint &&
        other.thumbnailsOnlyUntilFocused == thumbnailsOnlyUntilFocused &&
        other.maxConcurrentMediaDownloads == maxConcurrentMediaDownloads &&
        other.allowBackgroundPrefetch == allowBackgroundPrefetch;
  }

  @override
  int get hashCode {
    return Object.hash(
      perfMode,
      videoAutoplayEnabled,
      videoWarmPlayersCount,
      videoPreloadCount,
      feedPageSize,
      chatPageSize,
      enableRealtimeListenersForLists,
      mediaQualityHint,
      thumbnailsOnlyUntilFocused,
      maxConcurrentMediaDownloads,
      allowBackgroundPrefetch,
    );
  }
}
