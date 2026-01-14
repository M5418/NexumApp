// Isar Local-First Data Layer - Barrel export file
//
// Provides instant local reads via Isar (mobile) with Firestore as source of truth.
// Web falls back to Firestore cache-only behavior.

export 'local_store.dart';
export 'isar_db.dart';

// Models
export 'models/post_lite.dart';
export 'models/profile_lite.dart';
export 'models/conversation_lite.dart';
export 'models/message_lite.dart';
export 'models/podcast_lite.dart';
export 'models/book_lite.dart';
export 'models/community_post_lite.dart';

// Sync infrastructure
export 'sync/sync_cursor_store.dart';
export 'sync/sync_scheduler.dart';
export 'sync/initial_seeder.dart';

// Local-first repositories
export 'repositories/local_post_repository.dart';
export 'repositories/local_profile_repository.dart';
export 'repositories/local_conversation_repository.dart';
export 'repositories/local_message_repository.dart';
export 'repositories/local_podcast_repository.dart';
export 'repositories/local_book_repository.dart';
export 'repositories/local_community_post_repository.dart';

// Web-specific (Hive)
export 'web/web_local_store.dart';
export 'web/web_cache_warmer.dart';
