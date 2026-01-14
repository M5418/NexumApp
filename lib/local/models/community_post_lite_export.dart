// Conditional export: Use web-safe model on web, Isar model on mobile
export 'community_post_lite_web.dart' if (dart.library.io) 'community_post_lite.dart';
