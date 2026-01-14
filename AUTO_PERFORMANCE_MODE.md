# Auto Performance Mode

Automatic performance adaptation system that ensures ultra-fluid UX across all app modules by dynamically adjusting behavior based on backend configuration and runtime signals.

## Overview

The system provides two adaptive mechanisms:

1. **Backend-driven adaptation (Option A)**: Firebase Remote Config controls global performance flags
2. **In-app local adaptation (Option B)**: Runtime monitoring detects jank/latency and auto-downshifts

Both systems work together with a **merging priority**: Remote flags define the ceiling, local overrides can only downshift (normal→lite), never upshift beyond remote.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    PerformanceCoordinator                    │
│  (Merges remote + local flags, exposes EffectiveFlags)      │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│   RemoteConfigService   │     │ LocalPerformanceController│
│  (Firebase Remote Config)│     │  (Jank/latency detection) │
└─────────────────────────┘     └─────────────────────────┘
              │                               │
              ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│  Cloud Function         │     │  Frame Timing Callbacks  │
│  (Telemetry Aggregator) │     │  (WidgetsBinding)        │
└─────────────────────────┘     └─────────────────────────┘
```

## Performance Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| `normal` | Full features, autoplay, prefetch | Good network/device |
| `lite` | Reduced features, no autoplay | Degraded performance detected |
| `ultra` | Minimal features, emergency | Severe issues or kill switch |

## PerformanceFlags Model

```dart
PerformanceFlags(
  perfMode: PerfMode.normal,           // normal | lite | ultra
  videoAutoplayEnabled: true,          // Auto-play videos
  videoWarmPlayersCount: 1,            // Pre-initialized players (0-2)
  videoPreloadCount: 1,                // Videos to preload ahead (0-3)
  feedPageSize: 10,                    // Posts per page (3-20)
  chatPageSize: 30,                    // Messages per page (10-50)
  enableRealtimeListenersForLists: true, // Real-time updates for lists
  mediaQualityHint: MediaQualityHint.high, // high | balanced | low
  thumbnailsOnlyUntilFocused: false,   // Show thumbnails until tap
  maxConcurrentMediaDownloads: 3,      // Parallel downloads (1-5)
  allowBackgroundPrefetch: true,       // Prefetch next page
)
```

## Firebase Console Setup

### 1. Enable Remote Config

1. Go to Firebase Console → Remote Config
2. Create the following parameters:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `perf_mode_global` | String | `normal` | Global performance mode |
| `perf_flags_json` | String | `""` | Full flags JSON (preferred) |
| `kill_switch_video_autoplay` | Boolean | `false` | Emergency disable autoplay |
| `kill_switch_prefetch` | Boolean | `false` | Emergency disable prefetch |
| `perf_feed_page_size` | Number | `10` | Override feed page size |
| `perf_chat_page_size` | Number | `30` | Override chat page size |
| `emergency_safe_mode` | Boolean | `false` | Force ultra mode immediately |

### 2. Example perf_flags_json Value

```json
{
  "perfMode": "lite",
  "videoAutoplayEnabled": false,
  "videoWarmPlayersCount": 0,
  "videoPreloadCount": 0,
  "feedPageSize": 6,
  "chatPageSize": 20,
  "enableRealtimeListenersForLists": false,
  "mediaQualityHint": "balanced",
  "thumbnailsOnlyUntilFocused": true,
  "maxConcurrentMediaDownloads": 1,
  "allowBackgroundPrefetch": false
}
```

### 3. Deploy Cloud Function

```bash
cd functions
npm install
firebase deploy --only functions:aggregatePerfTelemetry,functions:triggerPerfAggregation,functions:forcePerformanceMode
```

### 4. Set Up Cloud Scheduler

The `aggregatePerfTelemetry` function runs every 15 minutes automatically via Cloud Scheduler (configured in the function).

### 5. Firestore Collections

The system uses these collections (auto-created):

| Collection | Purpose |
|------------|---------|
| `perf_telemetry` | App-uploaded performance metrics |
| `perf_aggregations` | Aggregation results for monitoring |
| `perf_config_state` | Current mode state and cooldowns |
| `perf_events` | Custom performance events |

## How It Works

### Backend-Driven Adaptation

1. App initializes → `RemoteConfigService.init()` sets local defaults
2. Background fetch retrieves Remote Config (non-blocking)
3. On config update, flags are parsed and validated
4. Kill switches override individual flags for emergencies
5. Cloud Function monitors `perf_telemetry` every 15 minutes
6. If degraded metrics detected → auto-switches to `lite` mode
7. If metrics recover for 1+ hour → restores `normal` mode

### Local Adaptation

1. `LocalPerformanceController.init()` starts frame timing monitoring
2. Modules record load times: `recordFeedLoadTime()`, `recordChatLoadTime()`, etc.
3. Every 5 seconds, controller evaluates rolling metrics:
   - Jank rate (% of frames > 16ms)
   - P95 latencies for feed, chat, video
4. If thresholds exceeded for 3 consecutive checks → downshift to lite
5. If metrics good for 6 consecutive checks → restore (within remote ceiling)

### Merging Priority

```dart
EffectiveFlags = RemoteFlags.mergeWithLocalOverride(LocalOverrides)
```

- Remote flags define the **ceiling**
- Local can only **downshift** (e.g., normal→lite)
- Local cannot **upshift** beyond remote
- Safe bounds enforced for all int values

## Usage in Code

### Access Effective Flags

```dart
// Get current flags
final flags = PerformanceCoordinator().flags;

// Or use convenience getters
final pageSize = PerformanceCoordinator().feedPageSize;
final autoplay = PerformanceCoordinator().videoAutoplayEnabled;

// Or use global accessor
final flags = perfFlags;
```

### Record Performance Metrics

```dart
// Record feed load time
final stopwatch = Stopwatch()..start();
await loadFeed();
stopwatch.stop();
PerformanceCoordinator().recordFeedLoadTime(stopwatch.elapsedMilliseconds);

// Record chat load time
PerformanceCoordinator().recordChatLoadTime(milliseconds);

// Record video init time
PerformanceCoordinator().recordVideoInitTime(milliseconds);
```

### Listen for Changes

```dart
// ValueNotifier
PerformanceCoordinator().effectiveFlags.addListener(() {
  final flags = PerformanceCoordinator().flags;
  // React to flag changes
});

// Stream
PerformanceCoordinator().effectiveFlagsStream.listen((flags) {
  // React to flag changes
});
```

## Debug Overlay

In debug builds, wrap your app with `PerfDebugOverlay`:

```dart
PerfDebugOverlay(
  child: MaterialApp(...),
)
```

Shows:
- Current performance mode (green/orange/red indicator)
- Jank rate, P95 latencies
- Active flags (autoplay, prefetch, etc.)
- Reset/Force Lite buttons

## Testing

Run tests:

```bash
flutter test test/performance_flags_test.dart
```

Tests cover:
- JSON parsing with invalid/malformed input
- Safe bounds clamping
- Mode merging priority
- Round-trip serialization

## Emergency Procedures

### Force Lite Mode Immediately

**Option 1: Firebase Console**
1. Go to Remote Config
2. Set `emergency_safe_mode` = `true`
3. Publish changes

**Option 2: Cloud Function**
```bash
curl -X POST https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/forcePerformanceMode \
  -H "Content-Type: application/json" \
  -d '{"mode": "lite"}'
```

### Restore Normal Mode

```bash
curl -X POST https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/forcePerformanceMode \
  -H "Content-Type: application/json" \
  -d '{"mode": "normal"}'
```

## Files

| File | Purpose |
|------|---------|
| `lib/core/performance/performance_flags.dart` | Immutable flags model |
| `lib/core/performance/remote_config_service.dart` | Firebase Remote Config |
| `lib/core/performance/local_performance_controller.dart` | Runtime monitoring |
| `lib/core/performance/performance_coordinator.dart` | Merges flags, exposes API |
| `lib/core/performance/perf_telemetry_service.dart` | Uploads metrics to Firestore |
| `lib/core/performance/perf_debug_overlay.dart` | Debug UI overlay |
| `functions/perf-telemetry-aggregator.js` | Cloud Function for auto-adaptation |
| `test/performance_flags_test.dart` | Unit tests |

## Safety Guarantees

1. **Never blocks first frame**: All init is non-blocking
2. **Safe defaults**: Works offline with bundled defaults
3. **No crashes on bad data**: All parsing is defensive
4. **No null assertions**: Strict null-safety throughout
5. **Hysteresis**: Requires sustained signals to change mode
6. **Cooldowns**: Prevents mode flapping
7. **Remote ceiling**: Local can only downshift, not upshift
