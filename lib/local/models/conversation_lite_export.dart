// Conditional export: Use web-safe model on web, Isar model on mobile
export 'conversation_lite_web.dart' if (dart.library.io) 'conversation_lite.dart';
