import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_store.dart';
import 'models/post_lite.dart';
import 'models/profile_lite.dart';
import 'models/conversation_lite.dart';
import 'models/message_lite.dart';
import 'models/podcast_lite.dart';
import 'models/book_lite.dart';
import 'models/community_post_lite.dart';
import 'models/story_lite.dart';
import 'models/mentorship_message_lite.dart';

/// Schema version for migration tracking.
/// Increment this when adding/removing/modifying Isar collections.
const int kIsarSchemaVersion = 2;

/// Singleton Isar database manager for mobile platforms.
/// Provides instant local reads for ultra-fluid UI.
/// 
/// Production hardening:
/// - Schema versioning with safe migration
/// - Automatic recovery from corruption
/// - Non-fatal error logging
class IsarDB implements LocalStore {
  static final IsarDB _instance = IsarDB._internal();
  factory IsarDB() => _instance;
  IsarDB._internal();

  Isar? _isar;
  bool _initialized = false;
  bool _recoveryAttempted = false;

  /// Get the Isar instance (null on web or if not initialized)
  Isar? get instance => _isar;

  @override
  bool get isAvailable => _initialized && _isar != null;

  /// All schemas in current version
  List<CollectionSchema<dynamic>> get _schemas => [
    PostLiteSchema,
    ProfileLiteSchema,
    ConversationLiteSchema,
    MessageLiteSchema,
    PodcastLiteSchema,
    BookLiteSchema,
    CommunityPostLiteSchema,
    StoryLiteSchema,
    MentorshipMessageLiteSchema,
  ];

  @override
  Future<void> init() async {
    if (_initialized) return;
    if (!isIsarSupported) {
      _debugLog('⚠️ Isar not supported on web, skipping init');
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      
      // Check schema version and handle migration
      final needsMigration = await _checkSchemaMigration();
      if (needsMigration) {
        await _performSafeMigration(dir.path);
      }
      
      _isar = await _openDatabase(dir.path);
      
      if (_isar != null) {
        _initialized = true;
        await _recordSchemaVersion();
        _debugLog('✅ Isar database initialized at ${dir.path}');
      }
    } catch (e, stack) {
      _logNonFatalError('Isar init failed', e, stack);
      
      // Attempt recovery if not already tried
      if (!_recoveryAttempted) {
        await _attemptRecovery();
      }
    }
  }

  /// Open database with error handling
  Future<Isar?> _openDatabase(String dirPath) async {
    try {
      return await Isar.open(
        _schemas,
        directory: dirPath,
        name: 'nexum_local',
        inspector: kDebugMode,
      );
    } catch (e, stack) {
      _logNonFatalError('Isar open failed', e, stack);
      return null;
    }
  }

  /// Check if schema migration is needed
  Future<bool> _checkSchemaMigration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedVersion = prefs.getInt('isar_schema_version') ?? 0;
      return storedVersion != kIsarSchemaVersion;
    } catch (e) {
      _debugLog('⚠️ Could not check schema version: $e');
      return false;
    }
  }

  /// Record current schema version after successful init
  Future<void> _recordSchemaVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('isar_schema_version', kIsarSchemaVersion);
    } catch (e) {
      _debugLog('⚠️ Could not record schema version: $e');
    }
  }

  /// Perform safe migration by clearing old data
  Future<void> _performSafeMigration(String dirPath) async {
    _debugLog('🔄 Schema migration needed, clearing old Isar data...');
    try {
      // Close any existing instance
      if (_isar != null) {
        await _isar?.close();
        _isar = null;
      }
      
      // Delete old database files
      final dbFile = File('$dirPath/nexum_local.isar');
      final lockFile = File('$dirPath/nexum_local.isar.lock');
      
      if (await dbFile.exists()) {
        await dbFile.delete();
        _debugLog('🗑️ Deleted old Isar database');
      }
      if (await lockFile.exists()) {
        await lockFile.delete();
      }
      
      _debugLog('✅ Schema migration complete');
    } catch (e, stack) {
      _logNonFatalError('Schema migration failed', e, stack);
    }
  }

  /// Attempt recovery from corruption
  Future<void> _attemptRecovery() async {
    _recoveryAttempted = true;
    _debugLog('🔧 Attempting Isar recovery...');
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      
      // Clear and recreate
      await _performSafeMigration(dir.path);
      
      // Try opening again
      _isar = await _openDatabase(dir.path);
      
      if (_isar != null) {
        _initialized = true;
        await _recordSchemaVersion();
        _debugLog('✅ Isar recovery successful');
      } else {
        _debugLog('❌ Isar recovery failed - falling back to Firestore-only');
      }
    } catch (e, stack) {
      _logNonFatalError('Isar recovery failed', e, stack);
    }
  }

  /// Log non-fatal error (for crash reporting integration)
  void _logNonFatalError(String message, Object error, StackTrace stack) {
    _debugLog('❌ $message: $error');
    // TODO: Integrate with Firebase Crashlytics or similar
    // FirebaseCrashlytics.instance.recordError(error, stack, reason: message);
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
      await db.storyLites.clear();
      await db.mentorshipMessageLites.clear();
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
      'stories': db.storyLites.countSync(),
      'mentorshipMessages': db.mentorshipMessageLites.countSync(),
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
