import 'dart:async';

abstract class NotificationRepository {
  // Get notifications (paginated)
  Future<List<NotificationModel>> getNotifications({
    int limit = 20,
    NotificationModel? lastNotification,
  });
  
  // Get unread count
  Future<int> getUnreadCount();
  
  // Mark notification as read
  Future<void> markAsRead(String notificationId);
  
  // Mark all as read
  Future<void> markAllAsRead();
  
  // Delete notification
  Future<void> deleteNotification(String notificationId);
  
  // Create notification (usually done server-side)
  Future<void> createNotification({
    required String userId,
    required NotificationType type,
    required String title,
    required String body,
    String? refId,
    Map<String, dynamic>? data,
  });
  
  // Real-time notification stream
  Stream<List<NotificationModel>> notificationsStream({int limit = 50});
  
  // Real-time unread count stream
  Stream<int> unreadCountStream();
  
  // FCM token management
  Future<void> subscribeTopic(String topic);
  Future<void> unsubscribeTopic(String topic);
}

enum NotificationType {
  like,
  comment,
  follow,
  mention,
  repost,
  system,
}

class NotificationModel {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final String? refId;
  final bool isRead;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  
  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.refId,
    this.isRead = false,
    this.data,
    required this.createdAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.toString().split('.').last,
      'title': title,
      'body': body,
      'refId': refId,
      'isRead': isRead,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
