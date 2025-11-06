import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../interfaces/conversation_repository.dart';

class FirebaseConversationRepository implements ConversationRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _convs => _db.collection('conversations');

  String _pairKey(String a, String b) {
    if (a.compareTo(b) <= 0) return '${a}_$b';
    return '${b}_$a';
  }

  Future<Map<String, dynamic>?> _getUserProfile(String uid) async {
    try {
      final d = await _db.collection('users').doc(uid).get();
      return d.data();
    } catch (_) {
      return null;
    }
  }

  ConversationSummaryModel _fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String currentUid,
  ) {
    final d = doc.data() ?? {};
    final participants = List<String>.from((d['participants'] as List?)?.map((e) => e.toString()) ?? const []);
    final otherId = participants.firstWhere((p) => p != currentUid, orElse: () => '');
    final other = Map<String, dynamic>.from((d['participantDetails'] ?? const {})[otherId] ?? {});

    String? mapLastType(String? s) {
      if (s == null) return null;
      switch (s) {
        case 'text':
        case 'image':
        case 'video':
        case 'voice':
        case 'file':
          return s;
        default:
          return 'text';
      }
    }

    final unread = Map<String, dynamic>.from(d['unread'] ?? {});
    final muted = Map<String, dynamic>.from(d['muted'] ?? {});

    return ConversationSummaryModel(
      id: doc.id,
      otherUserId: otherId,
      otherUser: ConversationUserSummary(
        id: otherId,
        name: (other['displayName'] ?? other['name'] ?? other['username'] ?? other['email'] ?? 'User').toString(),
        username: (other['username'] ?? '').toString(),
        avatarUrl: (other['avatarUrl'] ?? '').toString().isNotEmpty ? other['avatarUrl'].toString() : null,
      ),
      lastMessageType: mapLastType(d['lastMessageType']?.toString()),
      lastMessageText: d['lastMessageText']?.toString(),
      lastMessageAt: (d['lastMessageAt'] as Timestamp?)?.toDate(),
      unreadCount: int.tryParse((unread[currentUid] ?? 0).toString()) ?? 0,
      muted: (muted[currentUid] == true),
      lastFromCurrentUser: (d['lastFromUserId']?.toString() == currentUid),
      lastRead: null,
    );
  }

  @override
  Future<List<ConversationSummaryModel>> list({int limit = 50}) async {
    final u = _auth.currentUser;
    if (u == null) return [];
    final q = await _convs
        .where('participants', arrayContains: u.uid)
        .orderBy('lastMessageAt', descending: true)
        .limit(limit)
        .get();

    final items = <ConversationSummaryModel>[];
    for (final d in q.docs) {
      items.add(_fromDoc(d, u.uid));
    }
    return items;
  }

  @override
  Future<String> createOrGet(String otherUserId) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('not_authenticated');
    final key = _pairKey(u.uid, otherUserId);

    final existing = await _convs.where('pairKey', isEqualTo: key).limit(1).get();
    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    // Create new conversation
    final myProf = await _getUserProfile(u.uid);
    final otherProf = await _getUserProfile(otherUserId);

    final data = {
      'pairKey': key,
      'participants': [u.uid, otherUserId],
      'participantDetails': {
        u.uid: myProf ?? {},
        otherUserId: otherProf ?? {},
      },
      'lastMessageType': null,
      'lastMessageText': null,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastFromUserId': null,
      'unread': {u.uid: 0, otherUserId: 0},
      'muted': {u.uid: false, otherUserId: false},
      'deletedFor': {u.uid: false, otherUserId: false},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final ref = await _convs.add(data);
    return ref.id;
  }

  @override
  Future<void> markRead(String conversationId) async {
    final u = _auth.currentUser;
    if (u == null) return;

    final convRef = _convs.doc(conversationId);
    // reset unread counter for me
    await convRef.update({'unread.${u.uid}': 0, 'updatedAt': FieldValue.serverTimestamp()});

    // best-effort mark recent messages as read (avoid inequality constraints)
    final msgs = await convRef
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    final batch = _db.batch();
    for (final m in msgs.docs) {
      final md = m.data();
      if ((md['senderId'] ?? '') != u.uid) {
        batch.update(m.reference, {
          'readBy': FieldValue.arrayUnion([u.uid]),
        });
      }
    }
    await batch.commit();
  }

  @override
  Future<void> mute(String conversationId) async {
    final u = _auth.currentUser;
    if (u == null) return;
    await _convs.doc(conversationId).update({'muted.${u.uid}': true, 'updatedAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> unmute(String conversationId) async {
    final u = _auth.currentUser;
    if (u == null) return;
    await _convs.doc(conversationId).update({'muted.${u.uid}': false, 'updatedAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<void> delete(String conversationId) async {
    final u = _auth.currentUser;
    if (u == null) return;
    await _convs.doc(conversationId).update({'deletedFor.${u.uid}': true, 'updatedAt': FieldValue.serverTimestamp()});
  }

  @override
  Future<String?> checkConversationExists(String otherUserId) async {
    final u = _auth.currentUser;
    if (u == null) return null;
    final key = _pairKey(u.uid, otherUserId);
    final existing = await _convs.where('pairKey', isEqualTo: key).limit(1).get();
    if (existing.docs.isNotEmpty) return existing.docs.first.id;
    return null;
  }
}
