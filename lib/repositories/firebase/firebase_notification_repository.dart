import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_messaging/firebase_messaging.dart' as msg;
import '../interfaces/notification_repository.dart';

class FirebaseNotificationRepository implements NotificationRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final msg.FirebaseMessaging _messaging = msg.FirebaseMessaging.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) => _db.collection('users').doc(uid).collection('notifications');

  NotificationModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    NotificationType _toType(String? s) {
      switch (s) {
        case 'like':
          return NotificationType.like;
        case 'comment':
          return NotificationType.comment;
        case 'follow':
          return NotificationType.follow;
        case 'mention':
          return NotificationType.mention;
        case 'repost':
          return NotificationType.repost;
        default:
          return NotificationType.system;
      }
    }

    return NotificationModel(
      id: doc.id,
      userId: d['userId'] ?? '',
      type: _toType(d['type']),
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      refId: d['refId'],
      isRead: d['isRead'] ?? false,
      data: (d['data'] as Map?)?.cast<String, dynamic>(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  @override
  Future<List<NotificationModel>> getNotifications({int limit = 20, NotificationModel? lastNotification}) async {
    final u = _auth.currentUser;
    if (u == null) return [];
    Query<Map<String, dynamic>> q = _col(u.uid).orderBy('createdAt', descending: true).limit(limit);
    if (lastNotification != null) {
      q = q.startAfter([Timestamp.fromDate(lastNotification.createdAt)]);
    }
    final snap = await q.get();
    return snap.docs.map(_fromDoc).toList();
  }

  @override
  Future<int> getUnreadCount() async {
    final u = _auth.currentUser;
    if (u == null) return 0;
    final agg = await _col(u.uid).where('isRead', isEqualTo: false).count().get();
    final c = agg.count;
    return c is int ? c : (c ?? 0);
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    final u = _auth.currentUser;
    if (u == null) return;
    await _col(u.uid).doc(notificationId).update({'isRead': true});
  }

  @override
  Future<void> markAllAsRead() async {
    final u = _auth.currentUser;
    if (u == null) return;
    final snap = await _col(u.uid).where('isRead', isEqualTo: false).limit(500).get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {'isRead': true});
    }
    await batch.commit();
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    final u = _auth.currentUser;
    if (u == null) return;
    await _col(u.uid).doc(notificationId).delete();
  }

  @override
  Future<void> createNotification({required String userId, required NotificationType type, required String title, required String body, String? refId, Map<String, dynamic>? data}) async {
    await _db.collection('users').doc(userId).collection('notifications').add({
      'userId': userId,
      'type': type.toString().split('.').last,
      'title': title,
      'body': body,
      'refId': refId,
      'data': data,
      'isRead': false,
      'createdAt': Timestamp.now(),
    });
  }

  @override
  Stream<List<NotificationModel>> notificationsStream({int limit = 50}) {
    final u = _auth.currentUser;
    if (u == null) return const Stream.empty();
    return _col(u.uid).orderBy('createdAt', descending: true).limit(limit).snapshots().map((s) => s.docs.map(_fromDoc).toList());
  }

  @override
  Stream<int> unreadCountStream() {
    final u = _auth.currentUser;
    if (u == null) return const Stream.empty();
    return _col(u.uid).where('isRead', isEqualTo: false).snapshots().map((s) => s.docs.length);
  }

  @override
  Future<void> subscribeTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  @override
  Future<void> unsubscribeTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}
