import 'package:flutter_test/flutter_test.dart';
import 'package:nexum_app/core/performance/performance_flags.dart';

void main() {
  group('PerformanceFlags', () {
    group('fromJsonString', () {
      test('parses valid JSON correctly', () {
        const json = '''
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
        ''';

        final flags = PerformanceFlags.fromJsonString(json);

        expect(flags.perfMode, PerfMode.lite);
        expect(flags.videoAutoplayEnabled, false);
        expect(flags.videoWarmPlayersCount, 0);
        expect(flags.videoPreloadCount, 0);
        expect(flags.feedPageSize, 6);
        expect(flags.chatPageSize, 20);
        expect(flags.enableRealtimeListenersForLists, false);
        expect(flags.mediaQualityHint, MediaQualityHint.balanced);
        expect(flags.thumbnailsOnlyUntilFocused, true);
        expect(flags.maxConcurrentMediaDownloads, 1);
        expect(flags.allowBackgroundPrefetch, false);
      });

      test('returns normalDefaults for null input', () {
        final flags = PerformanceFlags.fromJsonString(null);
        expect(flags, PerformanceFlags.normalDefaults);
      });

      test('returns normalDefaults for empty string', () {
        final flags = PerformanceFlags.fromJsonString('');
        expect(flags, PerformanceFlags.normalDefaults);
      });

      test('returns normalDefaults for invalid JSON', () {
        final flags = PerformanceFlags.fromJsonString('not valid json');
        expect(flags, PerformanceFlags.normalDefaults);
      });

      test('returns normalDefaults for malformed JSON', () {
        final flags = PerformanceFlags.fromJsonString('{"perfMode": }');
        expect(flags, PerformanceFlags.normalDefaults);
      });
    });

    group('fromMap', () {
      test('parses valid map correctly', () {
        final map = {
          'perfMode': 'ultra',
          'videoAutoplayEnabled': false,
          'feedPageSize': 5,
        };

        final flags = PerformanceFlags.fromMap(map);

        expect(flags.perfMode, PerfMode.ultra);
        expect(flags.videoAutoplayEnabled, false);
        expect(flags.feedPageSize, 5);
      });

      test('returns normalDefaults for null map', () {
        final flags = PerformanceFlags.fromMap(null);
        expect(flags, PerformanceFlags.normalDefaults);
      });

      test('clamps feedPageSize to valid range', () {
        final tooSmall = PerformanceFlags.fromMap({'feedPageSize': 1});
        expect(tooSmall.feedPageSize, 3); // min is 3

        final tooLarge = PerformanceFlags.fromMap({'feedPageSize': 100});
        expect(tooLarge.feedPageSize, 20); // max is 20
      });

      test('clamps videoPreloadCount to valid range', () {
        final tooSmall = PerformanceFlags.fromMap({'videoPreloadCount': -5});
        expect(tooSmall.videoPreloadCount, 0); // min is 0

        final tooLarge = PerformanceFlags.fromMap({'videoPreloadCount': 10});
        expect(tooLarge.videoPreloadCount, 3); // max is 3
      });

      test('handles string boolean values', () {
        final flags = PerformanceFlags.fromMap({
          'videoAutoplayEnabled': 'true',
          'allowBackgroundPrefetch': 'false',
        });

        expect(flags.videoAutoplayEnabled, true);
        expect(flags.allowBackgroundPrefetch, false);
      });

      test('handles int boolean values', () {
        final flags = PerformanceFlags.fromMap({
          'videoAutoplayEnabled': 1,
          'allowBackgroundPrefetch': 0,
        });

        expect(flags.videoAutoplayEnabled, true);
        expect(flags.allowBackgroundPrefetch, false);
      });

      test('handles string int values', () {
        final flags = PerformanceFlags.fromMap({
          'feedPageSize': '8',
          'chatPageSize': '25',
        });

        expect(flags.feedPageSize, 8);
        expect(flags.chatPageSize, 25);
      });
    });

    group('PerfMode.fromString', () {
      test('parses normal', () {
        expect(PerfMode.fromString('normal'), PerfMode.normal);
        expect(PerfMode.fromString('NORMAL'), PerfMode.normal);
        expect(PerfMode.fromString('Normal'), PerfMode.normal);
      });

      test('parses lite', () {
        expect(PerfMode.fromString('lite'), PerfMode.lite);
        expect(PerfMode.fromString('LITE'), PerfMode.lite);
      });

      test('parses ultra', () {
        expect(PerfMode.fromString('ultra'), PerfMode.ultra);
        expect(PerfMode.fromString('ULTRA'), PerfMode.ultra);
      });

      test('defaults to normal for unknown values', () {
        expect(PerfMode.fromString('unknown'), PerfMode.normal);
        expect(PerfMode.fromString(''), PerfMode.normal);
        expect(PerfMode.fromString(null), PerfMode.normal);
      });
    });

    group('MediaQualityHint.fromString', () {
      test('parses high', () {
        expect(MediaQualityHint.fromString('high'), MediaQualityHint.high);
      });

      test('parses balanced', () {
        expect(MediaQualityHint.fromString('balanced'), MediaQualityHint.balanced);
      });

      test('parses low', () {
        expect(MediaQualityHint.fromString('low'), MediaQualityHint.low);
      });

      test('defaults to balanced for unknown values', () {
        expect(MediaQualityHint.fromString('unknown'), MediaQualityHint.balanced);
        expect(MediaQualityHint.fromString(null), MediaQualityHint.balanced);
      });
    });

    group('mergeWithLocalOverride', () {
      test('takes more restrictive mode', () {
        final remote = PerformanceFlags.normalDefaults;
        final local = PerformanceFlags.liteDefaults;

        final merged = remote.mergeWithLocalOverride(local);

        expect(merged.perfMode, PerfMode.lite);
      });

      test('disables autoplay if either disables', () {
        final remote = PerformanceFlags(videoAutoplayEnabled: true);
        final local = PerformanceFlags(videoAutoplayEnabled: false);

        final merged = remote.mergeWithLocalOverride(local);

        expect(merged.videoAutoplayEnabled, false);
      });

      test('takes lower page size', () {
        final remote = PerformanceFlags(feedPageSize: 10);
        final local = PerformanceFlags(feedPageSize: 6);

        final merged = remote.mergeWithLocalOverride(local);

        expect(merged.feedPageSize, 6);
      });

      test('takes lower preload count', () {
        final remote = PerformanceFlags(videoPreloadCount: 2);
        final local = PerformanceFlags(videoPreloadCount: 0);

        final merged = remote.mergeWithLocalOverride(local);

        expect(merged.videoPreloadCount, 0);
      });

      test('enables thumbnailsOnlyUntilFocused if either enables', () {
        final remote = PerformanceFlags(thumbnailsOnlyUntilFocused: false);
        final local = PerformanceFlags(thumbnailsOnlyUntilFocused: true);

        final merged = remote.mergeWithLocalOverride(local);

        expect(merged.thumbnailsOnlyUntilFocused, true);
      });

      test('takes lower media quality', () {
        final remote = PerformanceFlags(mediaQualityHint: MediaQualityHint.high);
        final local = PerformanceFlags(mediaQualityHint: MediaQualityHint.low);

        final merged = remote.mergeWithLocalOverride(local);

        expect(merged.mediaQualityHint, MediaQualityHint.low);
      });

      test('local cannot upshift beyond remote ceiling', () {
        final remote = PerformanceFlags.liteDefaults;
        final local = PerformanceFlags.normalDefaults;

        final merged = remote.mergeWithLocalOverride(local);

        // Should still be lite because remote is the ceiling
        expect(merged.perfMode, PerfMode.lite);
        expect(merged.feedPageSize, 6); // lite's page size
      });
    });

    group('defaultsForMode', () {
      test('returns normalDefaults for normal mode', () {
        final flags = PerformanceFlags.defaultsForMode(PerfMode.normal);
        expect(flags.perfMode, PerfMode.normal);
        expect(flags.videoAutoplayEnabled, true);
        expect(flags.feedPageSize, 10);
      });

      test('returns liteDefaults for lite mode', () {
        final flags = PerformanceFlags.defaultsForMode(PerfMode.lite);
        expect(flags.perfMode, PerfMode.lite);
        expect(flags.videoAutoplayEnabled, false);
        expect(flags.feedPageSize, 6);
      });

      test('returns ultraDefaults for ultra mode', () {
        final flags = PerformanceFlags.defaultsForMode(PerfMode.ultra);
        expect(flags.perfMode, PerfMode.ultra);
        expect(flags.videoAutoplayEnabled, false);
        expect(flags.feedPageSize, 5);
      });
    });

    group('toMap and toJsonString', () {
      test('round-trips correctly', () {
        final original = PerformanceFlags(
          perfMode: PerfMode.lite,
          videoAutoplayEnabled: false,
          feedPageSize: 7,
          mediaQualityHint: MediaQualityHint.low,
        );

        final json = original.toJsonString();
        final restored = PerformanceFlags.fromJsonString(json);

        expect(restored.perfMode, original.perfMode);
        expect(restored.videoAutoplayEnabled, original.videoAutoplayEnabled);
        expect(restored.feedPageSize, original.feedPageSize);
        expect(restored.mediaQualityHint, original.mediaQualityHint);
      });
    });

    group('copyWith', () {
      test('creates copy with modified values', () {
        final original = PerformanceFlags.normalDefaults;
        final modified = original.copyWith(
          perfMode: PerfMode.lite,
          feedPageSize: 5,
        );

        expect(modified.perfMode, PerfMode.lite);
        expect(modified.feedPageSize, 5);
        expect(modified.videoAutoplayEnabled, original.videoAutoplayEnabled);
      });

      test('preserves unmodified values', () {
        final original = PerformanceFlags(
          perfMode: PerfMode.lite,
          videoAutoplayEnabled: false,
          feedPageSize: 6,
        );
        final modified = original.copyWith(feedPageSize: 8);

        expect(modified.perfMode, PerfMode.lite);
        expect(modified.videoAutoplayEnabled, false);
        expect(modified.feedPageSize, 8);
      });
    });

    group('equality', () {
      test('equal flags are equal', () {
        final a = PerformanceFlags.normalDefaults;
        final b = PerformanceFlags.normalDefaults;

        expect(a == b, true);
        expect(a.hashCode, b.hashCode);
      });

      test('different flags are not equal', () {
        final a = PerformanceFlags.normalDefaults;
        final b = PerformanceFlags.liteDefaults;

        expect(a == b, false);
      });
    });
  });
}
