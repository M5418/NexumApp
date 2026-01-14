// Conditional export: Use web-safe model on web, Isar model on mobile
export 'book_lite_web.dart' if (dart.library.io) 'book_lite.dart';
