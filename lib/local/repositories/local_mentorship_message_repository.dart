// Conditional export: Use web repository on web, Isar repository on mobile
export 'local_mentorship_message_repository_web.dart' if (dart.library.io) 'local_mentorship_message_repository_mobile.dart';
