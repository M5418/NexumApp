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
    NotificationType toType(String? s) {
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
      type: toType(d['type']),
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
    final snap = await _col(u.uid)
        .where('isRead', isEqualTo: false)
        .limit(500)
        .get();
    return snap.size;
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
    final snap = await _col(u.uid)
        .where('isRead', isEqualTo: false)
        .limit(500)
        .get();
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
  Future<void> createNotification({required String userId, required NotificationType type, required String title, required String body, String? fromUserId, String? refId, Map<String, dynamic>? data}) async {
    // Check if the recipient has muted the sender
    if (fromUserId != null && fromUserId.isNotEmpty) {
      try {
        // Check if userId has muted fromUserId
        final snapshot = await _db.collection('mutes')
            .where('mutedByUid', isEqualTo: userId)
            .where('mutedUid', isEqualTo: fromUserId)
            .limit(1)
            .get();
        
        if (snapshot.docs.isNotEmpty) {
          // User has muted the sender, don't create notification
          return;
        }
      } catch (e) {
        // If mute check fails, proceed with notification creation
      }
    }
    
    await _db.collection('users').doc(userId).collection('notifications').add({
      'userId': userId,
      'type': type.toString().split('.').last,
      'title': title,
      'body': body,
      'fromUserId': fromUserId,
      'refId': refId,
      'data': data,
      'isRead': false,
      'createdAt': Timestamp.now(),
    });
  }

  @override
  Stream<List<NotificationModel>> notificationsStream({int limit = 50}) async* {
    final u = _auth.currentUser;
    if (u == null) {
      yield [];
      return;
    }
    
    // Get blocked users once
    Set<String> blockedUserIds = {};
    try {
      final blockSnapshot = await _db.collection('blocks')
          .where('blockedByUid', isEqualTo: u.uid)
          .get();
      blockedUserIds = blockSnapshot.docs
          .map((doc) => (doc.data()['blockedUid'] as String?) ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (e) {
      // Ignore error, proceed without filtering
    }
    
    await for (final snapshot in _col(u.uid).orderBy('createdAt', descending: true).limit(limit).snapshots()) {
      final notifications = snapshot.docs.map(_fromDoc).toList();
      // Filter out notifications from blocked users
      final filtered = notifications.where((notif) {
        final fromId = notif.data?['fromUserId'] as String?;
        if (fromId == null || fromId.isEmpty) return true;
        return !blockedUserIds.contains(fromId);
      }).toList();
      yield filtered;
    }
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
