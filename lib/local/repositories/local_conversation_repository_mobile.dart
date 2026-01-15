import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:isar/isar.dart';
import '../isar_db.dart';
import '../local_store.dart';
import '../models/conversation_lite.dart';
import '../sync/sync_cursor_store.dart';
import '../web/web_local_store.dart';

export '../models/conversation_lite.dart';

/// Local-first repository for Conversations.
/// Reads from Isar (mobile) or Hive (web) instantly, syncs with Firestore in background.
class LocalConversationRepository {
  static final LocalConversationRepository _instance = LocalConversationRepository._internal();
  factory LocalConversationRepository() => _instance;
  LocalConversationRepository._internal();

  final firestore.FirebaseFirestore _db = firestore.FirebaseFirestore.instance;
  final SyncCursorStore _cursorStore = SyncCursorStore();

  static const String _module = 'conversations';
  static const int _syncBatchSize = 50;

  /// Watch local conversations (instant UI binding)
  Stream<List<ConversationLite>> watchLocal({int limit = 50}) {
    final db = isarDB.instance;
    if (db == null) {
      return Stream.value([]);
    }

    return db.conversationLites
        .where()
        .sortByLastMessageAtDesc()
        .limit(limit)
        .watch(fireImmediately: true);
  }

  /// Get local conversations synchronously
  /// Uses Isar on mobile, Hive on web
  List<ConversationLite> getLocalSync({int limit = 50}) {
    // WEB: Use Hive via WebLocalStore
    if (isHiveSupported && webLocalStore.isAvailable) {
      final maps = webLocalStore.getConversationsSync(limit: limit);
      if (maps.isNotEmpty) {
        _debugLog('🌐 [Web] Loaded ${maps.length} conversations from Hive');
        return maps.map((m) => ConversationLite.fromMap(m)).toList();
      }
    }
    
    // MOBILE: Use Isar
    final db = isarDB.instance;
    if (db == null) return [];

    return db.conversationLites
        .where()
        .sortByLastMessageAtDesc()
        .limit(limit)
        .findAllSync();
  }

  /// Get a single conversation by ID
  ConversationLite? getConversationSync(String convId) {
    final db = isarDB.instance;
    if (db == null) return null;

    return db.conversationLites.filter().idEqualTo(convId).findFirstSync();
  }

  /// Sync remote conversations (delta sync)
  Future<void> syncRemote() async {
    if (!isIsarSupported) return;

    final db = isarDB.instance;
    if (db == null) return;

    final userId = fb.FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await _cursorStore.init();

    try {
      final lastSync = _cursorStore.getLastSyncTime(_module);
      _debugLog('🔄 Syncing conversations since: $lastSync');

      firestore.QuerySnapshot<Map<String, dynamic>> snapshot;

      if (lastSync != null) {
        snapshot = await _db.collection('conversations')
            .where('memberIds', arrayContains: userId)
            .where('updatedAt', isGreaterThan: firestore.Timestamp.fromDate(lastSync))
            .orderBy('updatedAt')
            .limit(_syncBatchSize)
            .get();
      } else {
        snapshot = await _db.collection('conversations')
            .where('memberIds', arrayContains: userId)
            .orderBy('lastMessageAt', descending: true)
            .limit(_syncBatchSize)
            .get();
      }

      if (snapshot.docs.isEmpty) {
        _debugLog('✅ Conversations already up to date');
        return;
      }

      final conversations = <ConversationLite>[];
      DateTime? latestUpdate;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final conv = ConversationLite.fromFirestore(doc.id, data);
        conversations.add(conv);

        final updatedAt = conv.updatedAt ?? conv.lastMessageAt;
        if (updatedAt != null && (latestUpdate == null || updatedAt.isAfter(latestUpdate))) {
          latestUpdate = updatedAt;
        }
      }

      await db.writeTxn(() async {
        await db.conversationLites.putAll(conversations);
      });

      if (latestUpdate != null) {
        await _cursorStore.setLastSyncTime(_module, latestUpdate);
      }

      _debugLog('✅ Synced ${conversations.length} conversations');
    } catch (e) {
      _debugLog('❌ Conversation sync failed: $e');
    }
  }

  /// Update conversation locally (for new message preview)
  Future<void> updateLastMessage({
    required String convId,
    required String text,
    required String type,
    required String senderId,
    required DateTime timestamp,
  }) async {
    final db = isarDB.instance;
    if (db == null) return;

    var conv = db.conversationLites.filter().idEqualTo(convId).findFirstSync();
    final convToSave = conv ?? (ConversationLite()
        ..id = convId
        ..localUpdatedAt = DateTime.now());

    convToSave.lastMessageText = text;
    convToSave.lastMessageType = type;
    convToSave.lastMessageSenderId = senderId;
    convToSave.lastMessageAt = timestamp;
    convToSave.localUpdatedAt = DateTime.now();

    await db.writeTxn(() async {
      await db.conversationLites.put(convToSave);
    });
  }

  /// Update unread count locally
  Future<void> updateUnreadCount(String convId, int count) async {
    final db = isarDB.instance;
    if (db == null) return;

    final conv = db.conversationLites.filter().idEqualTo(convId).findFirstSync();
    if (conv == null) return;

    conv.unreadCount = count;
    conv.localUpdatedAt = DateTime.now();

    await db.writeTxn(() async {
      await db.conversationLites.put(conv);
    });
  }

  /// Get total unread count
  int getTotalUnreadCount() {
    final db = isarDB.instance;
    if (db == null) return 0;

    final conversations = db.conversationLites.where().findAllSync();
    return conversations.fold(0, (sum, conv) => sum + conv.unreadCount);
  }

  /// Get conversation count
  int getLocalCount() {
    final db = isarDB.instance;
    if (db == null) return 0;
    return db.conversationLites.countSync();
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[LocalConvRepo] $message');
    }
  }
}
