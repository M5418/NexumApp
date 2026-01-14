import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'local_store.dart';
import 'models/post_lite.dart';
import 'models/profile_lite.dart';
import 'models/conversation_lite.dart';
import 'models/message_lite.dart';
import 'models/podcast_lite.dart';
import 'models/book_lite.dart';
import 'models/community_post_lite.dart';

/// Singleton Isar database manager for mobile platforms.
/// Provides instant local reads for ultra-fluid UI.
class IsarDB implements LocalStore {
  static final IsarDB _instance = IsarDB._internal();
  factory IsarDB() => _instance;
  IsarDB._internal();

  Isar? _isar;
  bool _initialized = false;

  /// Get the Isar instance (null on web or if not initialized)
  Isar? get instance => _isar;

  @override
  bool get isAvailable => _initialized && _isar != null;

  @override
  Future<void> init() async {
    if (_initialized) return;
    if (!isIsarSupported) {
      _debugLog('⚠️ Isar not supported on web, skipping init');
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      
      _isar = await Isar.open(
        [
          PostLiteSchema,
          ProfileLiteSchema,
          ConversationLiteSchema,
          MessageLiteSchema,
          PodcastLiteSchema,
          BookLiteSchema,
          CommunityPostLiteSchema,
        ],
        directory: dir.path,
        name: 'nexum_local',
        inspector: kDebugMode,
      );

      _initialized = true;
      _debugLog('✅ Isar database initialized at ${dir.path}');
    } catch (e) {
      _debugLog('❌ Isar init failed: $e');
      // Don't crash - app will fall back to Firestore-only
    }
  }

  @override
  Future<void> close() async {
    if (_isar != null) {
      await _isar?.close();
      _isar = null;
      _initialized = false;
      _debugLog('🔒 Isar database closed');
    }
  }

  /// Clear all local data (for logout/reset)
  Future<void> clearAll() async {
    final db = _isar;
    if (db == null) return;

    await db.writeTxn(() async {
      await db.postLites.clear();
      await db.profileLites.clear();
      await db.conversationLites.clear();
      await db.messageLites.clear();
      await db.podcastLites.clear();
      await db.bookLites.clear();
      await db.communityPostLites.clear();
    });
    _debugLog('🗑️ All local data cleared');
  }

  /// Get database statistics for debugging
  Map<String, int> getStats() {
    final db = _isar;
    if (db == null) return {};

    return {
      'posts': db.postLites.countSync(),
      'profiles': db.profileLites.countSync(),
      'conversations': db.conversationLites.countSync(),
      'messages': db.messageLites.countSync(),
      'podcasts': db.podcastLites.countSync(),
      'books': db.bookLites.countSync(),
      'communityPosts': db.communityPostLites.countSync(),
    };
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[IsarDB] $message');
    }
  }
}

/// Global accessor for Isar database
IsarDB get isarDB => IsarDB();
