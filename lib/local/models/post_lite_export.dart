// Conditional export: Use web-safe model on web, Isar model on mobile
export 'post_lite_web.dart' if (dart.library.io) 'post_lite.dart';
