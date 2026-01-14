// Conditional export: Use web repository on web, Isar repository on mobile
export 'local_community_post_repository_web.dart' if (dart.library.io) 'local_community_post_repository_mobile.dart';
