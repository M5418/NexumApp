// Conditional export: Use web repository on web, Isar repository on mobile
export 'local_book_repository_web.dart' if (dart.library.io) 'local_book_repository_mobile.dart';
