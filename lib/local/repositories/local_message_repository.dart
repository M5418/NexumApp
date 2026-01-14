import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:isar/isar.dart';
import '../isar_db.dart';
import '../local_store.dart';
import '../models/message_lite.dart';
import '../sync/sync_cursor_store.dart';

/// Local-first repository for Chat Messages.
class LocalMessageRepository {
  static final LocalMessageRepository _instance = LocalMessageRepository._internal();
  factory LocalMessageRepository() => _instance;
  LocalMessageRepository._internal();

  final firestore.FirebaseFirestore _db = firestore.FirebaseFirestore.instance;
  final SyncCursorStore _cursorStore = SyncCursorStore();

  static const int _syncBatchSize = 100;

  /// Watch local messages for a conversation (instant UI binding)
  Stream<List<MessageLite>> watchLocal(String conversationId, {int limit = 50}) {
    final db = isarDB.instance;
    if (db == null) return Stream.value([]);

    return db.messageLites
        .filter()
        .conversationIdEqualTo(conversationId)
        .sortByCreatedAtDesc()
        .limit(limit)
        .watch(fireImmediately: true);
  }

  /// Get local messages synchronously
  List<MessageLite> getLocalSync(String conversationId, {int limit = 50}) {
    final db = isarDB.instance;
    if (db == null) return [];

    return db.messageLites
        .filter()
        .conversationIdEqualTo(conversationId)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAllSync();
  }

  /// Get a single message by ID
  MessageLite? getMessageSync(String messageId) {
    final db = isarDB.instance;
    if (db == null) return null;
    return db.messageLites.filter().idEqualTo(messageId).findFirstSync();
  }

  /// Sync remote messages for a conversation
  Future<void> syncConversation(String conversationId) async {
    if (!isIsarSupported) return;

    final db = isarDB.instance;
    if (db == null) return;

    await _cursorStore.init();

    final cursorKey = 'messages_$conversationId';

    try {
      final lastSync = _cursorStore.getLastSyncTime(cursorKey);
      _debugLog('🔄 Syncing messages for $conversationId since: $lastSync');

      firestore.QuerySnapshot<Map<String, dynamic>> snapshot;

      if (lastSync != null) {
        snapshot = await _db.collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .where('createdAt', isGreaterThan: firestore.Timestamp.fromDate(lastSync))
            .orderBy('createdAt')
            .limit(_syncBatchSize)
            .get();
      } else {
        snapshot = await _db.collection('conversations')
            .doc(conversationId)
            .collection('messages')
            .orderBy('createdAt', descending: true)
            .limit(_syncBatchSize)
            .get();
      }

      if (snapshot.docs.isEmpty) {
        _debugLog('✅ Messages already up to date');
        return;
      }

      final messages = <MessageLite>[];
      DateTime? latestUpdate;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final msg = MessageLite.fromFirestore(doc.id, data, conversationId);
        messages.add(msg);

        if (latestUpdate == null || msg.createdAt.isAfter(latestUpdate)) {
          latestUpdate = msg.createdAt;
        }
      }

      await db.writeTxn(() async {
        await db.messageLites.putAll(messages);
      });

      if (latestUpdate != null) {
        await _cursorStore.setLastSyncTime(cursorKey, latestUpdate);
      }

      _debugLog('✅ Synced ${messages.length} messages');
    } catch (e) {
      _debugLog('❌ Message sync failed: $e');
    }
  }

  /// Create a pending message (optimistic write)
  Future<MessageLite> createPendingMessage({
    required String conversationId,
    required String senderId,
    required String type,
    String? text,
    String? localMediaPath,
    String? fileName,
    int? fileSize,
    int? voiceDurationSeconds,
  }) async {
    final db = isarDB.instance;
    if (db == null) {
      throw Exception('Isar not available');
    }

    // Generate client-side ID
    final messageId = _db.collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .doc()
        .id;

    final message = MessageLite.pending(
      id: messageId,
      conversationId: conversationId,
      senderId: senderId,
      type: type,
      text: text,
      localMediaPath: localMediaPath,
      fileName: fileName,
      fileSize: fileSize,
      voiceDurationSeconds: voiceDurationSeconds,
    );

    await db.writeTxn(() async {
      await db.messageLites.put(message);
    });

    _debugLog('📝 Created pending message: $messageId');
    return message;
  }

  /// Update message sync status
  Future<void> updateSyncStatus(String messageId, String status, {String? mediaUrl}) async {
    final db = isarDB.instance;
    if (db == null) return;

    final msg = db.messageLites.filter().idEqualTo(messageId).findFirstSync();
    if (msg == null) return;

    msg.syncStatus = status;
    msg.localUpdatedAt = DateTime.now();
    if (mediaUrl != null) {
      msg.mediaUrl = mediaUrl;
    }

    await db.writeTxn(() async {
      await db.messageLites.put(msg);
    });

    _debugLog('📝 Updated message $messageId status: $status');
  }

  /// Get pending messages for retry
  List<MessageLite> getPendingMessages(String conversationId) {
    final db = isarDB.instance;
    if (db == null) return [];

    return db.messageLites
        .filter()
        .conversationIdEqualTo(conversationId)
        .and()
        .group((q) => q
            .syncStatusEqualTo('pending')
            .or()
            .syncStatusEqualTo('failed'))
        .findAllSync();
  }

  /// Delete local message
  Future<void> deleteLocal(String messageId) async {
    final db = isarDB.instance;
    if (db == null) return;

    await db.writeTxn(() async {
      await db.messageLites.filter().idEqualTo(messageId).deleteFirst();
    });
  }

  /// Get message count for a conversation
  int getLocalCount(String conversationId) {
    final db = isarDB.instance;
    if (db == null) return 0;
    return db.messageLites
        .filter()
        .conversationIdEqualTo(conversationId)
        .countSync();
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[LocalMessageRepo] $message');
    }
  }
}
