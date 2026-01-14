// Conditional export: Use web-safe model on web, Isar model on mobile
export 'podcast_lite_web.dart' if (dart.library.io) 'podcast_lite.dart';
