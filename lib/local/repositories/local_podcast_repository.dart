// Conditional export: Use web repository on web, Isar repository on mobile
export 'local_podcast_repository_web.dart' if (dart.library.io) 'local_podcast_repository_mobile.dart';
