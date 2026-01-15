import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:isar/isar.dart';
import '../isar_db.dart';
import '../local_store.dart';
import '../models/mentorship_message_lite.dart';
import '../sync/sync_cursor_store.dart';

export '../models/mentorship_message_lite.dart';

/// Local-first repository for Mentorship Messages.
class LocalMentorshipMessageRepository {
  static final LocalMentorshipMessageRepository _instance = LocalMentorshipMessageRepository._internal();
  factory LocalMentorshipMessageRepository() => _instance;
  LocalMentorshipMessageRepository._internal();

  final firestore.FirebaseFirestore _db = firestore.FirebaseFirestore.instance;
  final SyncCursorStore _cursorStore = SyncCursorStore();

  static const int _syncBatchSize = 100;

  /// Watch local messages for a mentorship conversation
  Stream<List<MentorshipMessageLite>> watchLocal(String conversationId, {int limit = 50}) {
    final db = isarDB.instance;
    if (db == null) return Stream.value([]);

    return db.mentorshipMessageLites
        .filter()
        .conversationIdEqualTo(conversationId)
        .sortByCreatedAtDesc()
        .limit(limit)
        .watch(fireImmediately: true);
  }

  /// Get local messages synchronously
  List<MentorshipMessageLite> getLocalSync(String conversationId, {int limit = 50}) {
    final db = isarDB.instance;
    if (db == null) return [];

    return db.mentorshipMessageLites
        .filter()
        .conversationIdEqualTo(conversationId)
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAllSync();
  }

  /// Sync remote messages for a mentorship conversation
  Future<void> syncConversation(String conversationId) async {
    if (!isIsarSupported) return;

    final db = isarDB.instance;
    if (db == null) return;

    await _cursorStore.init();

    final cursorKey = 'mentorship_messages_$conversationId';

    try {
      final lastSync = _cursorStore.getLastSyncTime(cursorKey);
      _debugLog('🔄 Syncing mentorship messages for $conversationId since: $lastSync');

      firestore.QuerySnapshot<Map<String, dynamic>> snapshot;

      if (lastSync != null) {
        snapshot = await _db.collection('mentorship_conversations')
            .doc(conversationId)
            .collection('messages')
            .where('createdAt', isGreaterThan: firestore.Timestamp.fromDate(lastSync))
            .orderBy('createdAt')
            .limit(_syncBatchSize)
            .get();
      } else {
        snapshot = await _db.collection('mentorship_conversations')
            .doc(conversationId)
            .collection('messages')
            .orderBy('createdAt', descending: true)
            .limit(_syncBatchSize)
            .get();
      }

      if (snapshot.docs.isEmpty) {
        _debugLog('✅ Mentorship messages already up to date');
        return;
      }

      final messages = <MentorshipMessageLite>[];
      DateTime? latestUpdate;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final msg = MentorshipMessageLite.fromFirestore(doc.id, data, conversationId);
        messages.add(msg);

        if (latestUpdate == null || msg.createdAt.isAfter(latestUpdate)) {
          latestUpdate = msg.createdAt;
        }
      }

      await db.writeTxn(() async {
        await db.mentorshipMessageLites.putAll(messages);
      });

      if (latestUpdate != null) {
        await _cursorStore.setLastSyncTime(cursorKey, latestUpdate);
      }

      _debugLog('✅ Synced ${messages.length} mentorship messages');
    } catch (e) {
      _debugLog('❌ Mentorship message sync failed: $e');
    }
  }

  /// Create a pending message (optimistic write)
  Future<MentorshipMessageLite> createPendingMessage({
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

    final messageId = _db.collection('mentorship_conversations')
        .doc(conversationId)
        .collection('messages')
        .doc()
        .id;

    final message = MentorshipMessageLite.pending(
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
      await db.mentorshipMessageLites.put(message);
    });

    _debugLog('📝 Created pending mentorship message: $messageId');
    return message;
  }

  /// Update message sync status
  Future<void> updateSyncStatus(String messageId, String status, {String? mediaUrl}) async {
    final db = isarDB.instance;
    if (db == null) return;

    final msg = db.mentorshipMessageLites.filter().idEqualTo(messageId).findFirstSync();
    if (msg == null) return;

    msg.syncStatus = status;
    msg.localUpdatedAt = DateTime.now();
    if (mediaUrl != null) {
      msg.mediaUrl = mediaUrl;
    }

    await db.writeTxn(() async {
      await db.mentorshipMessageLites.put(msg);
    });
  }

  /// Get message count for a conversation
  int getLocalCount(String conversationId) {
    final db = isarDB.instance;
    if (db == null) return 0;
    return db.mentorshipMessageLites
        .filter()
        .conversationIdEqualTo(conversationId)
        .countSync();
  }

  void _debugLog(String message) {
    if (kDebugMode) {
      debugPrint('[LocalMentorshipMsgRepo] $message');
    }
  }
}
