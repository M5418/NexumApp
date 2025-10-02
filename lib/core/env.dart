// File: lib/core/env.dart
import 'package:flutter/foundation.dart' show kReleaseMode;

// Defaults: prod in release, dev in debug/profile.
// Override anytime with:
//   --dart-define=API_BASE=https://api.nexum-connects.com
//   --dart-define=API_BASE=http://localhost:3000
const String kDefaultApiBaseProd = 'https://api.nexum-connects.com';
const String kDefaultApiBaseDev  = 'http://localhost:3000';

const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE',
  defaultValue: kReleaseMode ? kDefaultApiBaseProd : kDefaultApiBaseDev,
);