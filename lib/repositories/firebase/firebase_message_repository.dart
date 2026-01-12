import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show debugPrint;
import '../interfaces/message_repository.dart';
import 'firebase_conversation_repository.dart';

class FirebaseMessageRepository implements MessageRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _conv(String id) => _db.collection('conversations').doc(id).collection('messages');

  AttachmentModel _attFrom(Map<String, dynamic> m) => AttachmentModel(
        id: (m['id'] ?? '').toString(),
        type: (m['type'] ?? 'text').toString(),
        url: (m['url'] ?? '').toString(),
        thumbnail: (m['thumbnail'] ?? m['thumbnailUrl'])?.toString(),
        durationSec: _toIntNullable(m['durationSec'] ?? m['duration_sec']),
        fileSize: _toIntNullable(m['fileSize'] ?? m['file_size']),
        fileName: (m['fileName'] ?? m['file_name'])?.toString(),
      );

  int? _toIntNullable(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  MessageRecordModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data() ?? {};
    
    // Safely parse attachments - handle web LegacyJavaScriptObject
    final attachmentsList = m['attachments'];
    final atts = <AttachmentModel>[];
    if (attachmentsList != null && attachmentsList is List) {
      for (final e in attachmentsList) {
        try {
          if (e is Map) {
            atts.add(_attFrom(Map<String, dynamic>.from(e)));
          } else if (e != null) {
            // Try to convert from dynamic (web compatibility)
            final map = Map<String, dynamic>.from(e as dynamic);
            atts.add(_attFrom(map));
          }
        } catch (_) {
          // Skip malformed attachment
        }
      }
    }
    
    // Safely parse replyTo - handle web LegacyJavaScriptObject
    Map<String, dynamic>? replyToMap;
    final replyToData = m['replyTo'];
    if (replyToData != null) {
      try {
        if (replyToData is Map) {
          replyToMap = Map<String, dynamic>.from(replyToData);
        }
      } catch (_) {
        // Skip malformed replyTo
      }
    }
    
    // Safely parse createdAt timestamp
    DateTime createdAt = DateTime.now();
    final createdAtData = m['createdAt'];
    if (createdAtData is Timestamp) {
      createdAt = createdAtData.toDate();
    } else if (createdAtData is DateTime) {
      createdAt = createdAtData;
    }
    
    return MessageRecordModel(
      id: d.id,
      conversationId: (m['conversationId'] ?? '').toString(),
      senderId: (m['senderId'] ?? '').toString(),
      receiverId: (m['receiverId'] ?? '').toString(),
      type: (m['type'] ?? 'text').toString(),
      text: (m['text'] ?? '').toString(),
      createdAt: createdAt,
      readAt: null,
      attachments: atts,
      myReaction: null,
      reaction: (m['latestReaction'] ?? '').toString().isEmpty ? null : (m['latestReaction'] ?? '').toString(),
      replyTo: replyToMap,
    );
  }

  Future<String> _ensureConversation(String? conversationId, String? otherUserId) async {
    if (conversationId != null && conversationId.isNotEmpty) return conversationId;
    if (otherUserId != null && otherUserId.isNotEmpty) {
      return FirebaseConversationRepository().createOrGet(otherUserId);
    }
    throw Exception('missing_target');
  }

  Future<String?> _otherParticipant(String conversationId) async {
    final doc = await _db.collection('conversations').doc(conversationId).get();
    final d = doc.data() ?? {};
    final parts = List<String>.from((d['participants'] as List?)?.map((e) => e.toString()) ?? const []);
    final me = _auth.currentUser?.uid;
    if (me == null) return null;
    for (final p in parts) {
      if (p != me) return p;
    }
    return null;
  }

  Future<void> _updateConversationSummary({
    required String conversationId,
    required String type,
    required String text,
  }) async {
    final me = _auth.currentUser?.uid;
    if (me == null) return;
    final other = await _otherParticipant(conversationId);
    final convRef = _db.collection('conversations').doc(conversationId);
    
    // Refresh current user's profile data in participantDetails
    try {
      final myProfile = await _db.collection('users').doc(me).get();
      if (myProfile.exists) {
        final data = myProfile.data() ?? {};
        await convRef.set({
          'participantDetails.$me': {
            'displayName': data['displayName'] ?? '',
            'firstName': data['firstName'] ?? '',
            'lastName': data['lastName'] ?? '',
            'name': data['displayName'] ?? data['firstName'] ?? data['username'] ?? '',
            'username': data['username'] ?? '',
            'avatarUrl': data['avatarUrl'] ?? '',
            'email': data['email'] ?? '',
          }
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('⚠️ Failed to update participant details: $e');
    }
    
    final updates = {
      'lastMessageType': type,
      'lastMessageText': text,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastFromUserId': me,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (other != null && other.isNotEmpty) {
      updates['unread.$other'] = FieldValue.increment(1);
    }
    await convRef.set(updates, SetOptions(merge: true));
  }

  @override
  Future<List<MessageRecordModel>> list(String conversationId, {int limit = 50}) async {
    final uid = _auth.currentUser?.uid;
    
    // Try server first for fresh data, fall back to cache if offline
    QuerySnapshot<Map<String, dynamic>>? snap;
    try {
      // IMPORTANT: Force server fetch to get latest messages with proper timestamps
      snap = await _conv(conversationId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get(const GetOptions(source: Source.server));
    } catch (_) {
      // Server unavailable, try cache
      try {
        snap = await _conv(conversationId)
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get(const GetOptions(source: Source.cache));
      } catch (e) {
        rethrow;
      }
    }
    
    // Filter out deleted messages
    final list = snap.docs
        .where((doc) {
          final data = doc.data();
          final deletedFor = data['deletedFor'] as Map?;
          final deletedForEveryone = data['deletedForEveryone'] as bool?;
          if (deletedForEveryone == true) return false;
          if (uid != null && deletedFor != null && deletedFor[uid] == true) return false;
          return true;
        })
        .map(_fromDoc)
        .toList();
    
    return list.reversed.toList();
  }

  /// FAST: Get messages from cache first (instant), returns cached data
  Future<List<MessageRecordModel>> listFromCache(String conversationId, {int limit = 50}) async {
    try {
      final uid = _auth.currentUser?.uid;
      final snap = await _conv(conversationId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get(const GetOptions(source: Source.cache));
      
      final list = snap.docs
          .where((doc) {
            final data = doc.data();
            final deletedFor = data['deletedFor'] as Map?;
            final deletedForEveryone = data['deletedForEveryone'] as bool?;
            if (deletedForEveryone == true) return false;
            if (uid != null && deletedFor != null && deletedFor[uid] == true) return false;
            return true;
          })
          .map(_fromDoc)
          .toList();
      
      return list.reversed.toList();
    } catch (_) {
      return []; // Cache miss
    }
  }

  @override
  Stream<List<MessageRecordModel>> messagesStream(String conversationId, {int limit = 50}) {
    final uid = _auth.currentUser?.uid;
    return _conv(conversationId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) {
          // Filter out messages deleted by current user or deleted for everyone
          final filtered = s.docs.where((doc) {
            final data = doc.data();
            final deletedFor = data['deletedFor'] as Map?;
            final deletedForEveryone = data['deletedForEveryone'] as bool?;
            
            // Hide if deleted for everyone
            if (deletedForEveryone == true) return false;
            
            // Hide if current user deleted it
            if (uid != null && deletedFor != null && deletedFor[uid] == true) {
              return false;
            }
            
            return true;
          }).map(_fromDoc).toList();
          
          return filtered.reversed.toList();
        });
  }

  @override
  Future<MessageRecordModel> sendText({String? conversationId, String? otherUserId, required String text, String? replyToMessageId}) async {
    debugPrint('💬 [MessageRepo] sendText called');
    debugPrint('💬 [MessageRepo] conversationId: $conversationId, otherUserId: $otherUserId');
    debugPrint('💬 [MessageRepo] text: $text');
    
    final convId = await _ensureConversation(conversationId, otherUserId);
    debugPrint('💬 [MessageRepo] Resolved conversationId: $convId');
    
    final me = _auth.currentUser?.uid;
    if (me == null) throw Exception('not_authenticated');
    
    final other = await _otherParticipant(convId);
    debugPrint('💬 [MessageRepo] senderId: $me, receiverId: $other');
    
    final data = {
      'conversationId': convId,
      'senderId': me,
      'receiverId': other ?? '',
      'type': 'text',
      'text': text,
      'attachments': [],
      'replyTo': null,
      'readBy': [me],
      'createdAt': FieldValue.serverTimestamp(),
      'deletedFor': {},
      'deletedForEveryone': false,
    };
    
    debugPrint('💬 [MessageRepo] Creating message document...');
    final ref = await _conv(convId).add(data);
    debugPrint('💬 [MessageRepo] Message created with ID: ${ref.id}');
    
    await _updateConversationSummary(conversationId: convId, type: 'text', text: text);
    debugPrint('💬 [MessageRepo] Conversation summary updated');
    
    final fresh = await ref.get();
    debugPrint('💬 [MessageRepo] Message retrieved: ${fresh.exists}');
    debugPrint('💬 [MessageRepo] Message data: ${fresh.data()}');
    
    return _fromDoc(fresh);
  }

  @override
  Future<MessageRecordModel> sendTextWithAttachments({String? conversationId, String? otherUserId, required String text, required List<Map<String, dynamic>> attachments, String? replyToMessageId}) async {
    final convId = await _ensureConversation(conversationId, otherUserId);
    final me = _auth.currentUser?.uid;
    if (me == null) throw Exception('not_authenticated');
    final other = await _otherParticipant(convId);
    final atts = attachments.where((a) => a.isNotEmpty).toList();
    String type = 'text';
    final types = atts.map((a) => (a['type'] ?? '').toString()).toList();
    if (types.contains('video')) {
      type = 'video';
    } else if (types.contains('image')) {
      type = 'image';
    } else if (types.contains('voice')) {
      type = 'voice';
    } else if (atts.isNotEmpty) {
      type = 'file';
    }

    final data = {
      'conversationId': convId,
      'senderId': me,
      'receiverId': other ?? '',
      'type': type,
      'text': text,
      'attachments': atts,
      'replyTo': null,
      'readBy': [me],
      'createdAt': FieldValue.serverTimestamp(),
      'deletedFor': {},
      'deletedForEveryone': false,
    };
    final ref = await _conv(convId).add(data);
    await _updateConversationSummary(conversationId: convId, type: type, text: text);
    final fresh = await ref.get();
    return _fromDoc(fresh);
  }

  @override
  Future<MessageRecordModel> sendVoice({String? conversationId, String? otherUserId, required String audioUrl, required int durationSec, required int fileSize, String? replyToMessageId}) async {
    final convId = await _ensureConversation(conversationId, otherUserId);
    final me = _auth.currentUser?.uid;
    if (me == null) throw Exception('not_authenticated');
    final other = await _otherParticipant(convId);
    // Determine file extension from URL
    String fileName = 'voice_message.m4a';
    if (audioUrl.toLowerCase().contains('.webm')) {
      fileName = 'voice_message.webm';
    } else if (audioUrl.toLowerCase().contains('.wav')) {
      fileName = 'voice_message.wav';
    } else if (audioUrl.toLowerCase().contains('.mp3')) {
      fileName = 'voice_message.mp3';
    }
    
    final att = {
      'type': 'voice',
      'url': audioUrl,
      'durationSec': durationSec,
      'fileSize': fileSize,
      'fileName': fileName,
    };
    final data = {
      'conversationId': convId,
      'senderId': me,
      'receiverId': other ?? '',
      'type': 'voice',
      'text': '',
      'attachments': [att],
      'replyTo': null,
      'readBy': [me],
      'createdAt': FieldValue.serverTimestamp(),
      'deletedFor': {},
      'deletedForEveryone': false,
    };
    final ref = await _conv(convId).add(data);
    await _updateConversationSummary(conversationId: convId, type: 'voice', text: '');
    final fresh = await ref.get();
    return _fromDoc(fresh);
  }

  @override
  Future<void> react(String messageId, String? emoji) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    // Reaction requires conversation; find message by collectionGroup
    final snap = await _db.collectionGroup('messages').where(FieldPath.documentId, isEqualTo: messageId).limit(1).get();
    if (snap.docs.isEmpty) return;
    final ref = snap.docs.first.reference;
    await ref.set({'reactions': {uid: emoji}, 'latestReaction': emoji ?? ''}, SetOptions(merge: true));
  }

  @override
  Future<void> deleteForMe(String messageId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final snap = await _db.collectionGroup('messages').where(FieldPath.documentId, isEqualTo: messageId).limit(1).get();
    if (snap.docs.isEmpty) return;
    final ref = snap.docs.first.reference;
    await ref.set({'deletedFor': {uid: true}}, SetOptions(merge: true));
  }

  @override
  Future<void> deleteForEveryone(String messageId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final snap = await _db.collectionGroup('messages').where(FieldPath.documentId, isEqualTo: messageId).limit(1).get();
    if (snap.docs.isEmpty) return;
    final ref = snap.docs.first.reference;
    final d = await ref.get();
    final data = d.data() ?? {};
    if (data['senderId'] != uid) return;
    await ref.set({'deletedForEveryone': true, 'text': '', 'attachments': []}, SetOptions(merge: true));
  }
}
