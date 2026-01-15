import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../repositories/firebase/firebase_notification_repository.dart';
import '../repositories/interfaces/notification_repository.dart';

/// Provider for real-time notification state across the app
class NotificationProvider extends ChangeNotifier {
  final FirebaseNotificationRepository _repo = FirebaseNotificationRepository();
  
  int _unreadCount = 0;
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  
  StreamSubscription<int>? _unreadCountSub;
  StreamSubscription<List<NotificationModel>>? _notificationsSub;
  
  int get unreadCount => _unreadCount;
  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  NotificationProvider() {
    _init();
  }
  
  void _init() {
    final user = fb.FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('📭 [NotificationProvider] No user logged in');
      return;
    }
    
    debugPrint('📬 [NotificationProvider] Initializing for user: ${user.uid}');
    _subscribeToUnreadCount();
    _subscribeToNotifications();
  }
  
  void _subscribeToUnreadCount() {
    _unreadCountSub?.cancel();
    _unreadCountSub = _repo.unreadCountStream().listen(
      (count) {
        debugPrint('📬 [NotificationProvider] Unread count: $count');
        _unreadCount = count;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('❌ [NotificationProvider] Unread count error: $e');
      },
    );
  }
  
  void _subscribeToNotifications() {
    _isLoading = true;
    notifyListeners();
    
    _notificationsSub?.cancel();
    _notificationsSub = _repo.notificationsStream(limit: 50).listen(
      (list) {
        debugPrint('📬 [NotificationProvider] Received ${list.length} notifications');
        _notifications = list;
        _isLoading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('❌ [NotificationProvider] Notifications error: $e');
        _error = 'Failed to load notifications';
        _isLoading = false;
        notifyListeners();
      },
    );
  }
  
  /// Refresh subscriptions (call after login/logout)
  void refresh() {
    debugPrint('🔄 [NotificationProvider] Refreshing...');
    _unreadCountSub?.cancel();
    _notificationsSub?.cancel();
    _init();
  }
  
  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _repo.markAsRead(notificationId);
      // Update local state immediately for responsiveness
      final idx = _notifications.indexWhere((n) => n.id == notificationId);
      if (idx != -1 && !_notifications[idx].isRead) {
        _notifications[idx] = NotificationModel(
          id: _notifications[idx].id,
          userId: _notifications[idx].userId,
          type: _notifications[idx].type,
          title: _notifications[idx].title,
          body: _notifications[idx].body,
          refId: _notifications[idx].refId,
          isRead: true,
          data: _notifications[idx].data,
          createdAt: _notifications[idx].createdAt,
        );
        if (_unreadCount > 0) _unreadCount--;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ [NotificationProvider] Mark as read error: $e');
    }
  }
  
  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      await _repo.markAllAsRead();
      // Update local state immediately
      _notifications = _notifications.map((n) => NotificationModel(
        id: n.id,
        userId: n.userId,
        type: n.type,
        title: n.title,
        body: n.body,
        refId: n.refId,
        isRead: true,
        data: n.data,
        createdAt: n.createdAt,
      )).toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [NotificationProvider] Mark all as read error: $e');
    }
  }
  
  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _repo.deleteNotification(notificationId);
      // Update local state immediately
      final wasUnread = _notifications.any((n) => n.id == notificationId && !n.isRead);
      _notifications.removeWhere((n) => n.id == notificationId);
      if (wasUnread && _unreadCount > 0) _unreadCount--;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [NotificationProvider] Delete error: $e');
    }
  }
  
  @override
  void dispose() {
    _unreadCountSub?.cancel();
    _notificationsSub?.cancel();
    super.dispose();
  }
}
