import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

/// Service to handle push notification navigation and display
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final _navigationController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotificationTap => _navigationController.stream;

  bool _isInitialized = false;

  /// Initialize push notification listeners
  Future<void> initialize() async {
    if (_isInitialized || kIsWeb) return;
    _isInitialized = true;

    try {
      // Handle notification that opened the app from terminated state
      // Add timeout to prevent freeze on TestFlight/production
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('⚠️ getInitialMessage timed out');
          return null;
        },
      );
      if (initialMessage != null) {
        debugPrint('📱 App opened from notification: ${initialMessage.data}');
        _handleNotificationTap(initialMessage);
      }

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('📱 Notification tapped (background): ${message.data}');
        _handleNotificationTap(message);
      });

      // Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📱 Foreground notification: ${message.notification?.title}');
        _handleForegroundNotification(message);
      });

      debugPrint('✅ Push notification service initialized');
    } catch (e) {
      debugPrint('⚠️ Push notification init error: $e');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    _navigationController.add(data);
  }

  void _handleForegroundNotification(RemoteMessage message) {
    // Foreground notifications are shown as in-app banners by the system
    // We can optionally show a custom snackbar or overlay here
    debugPrint('Foreground notification received: ${message.notification?.title}');
  }

  /// Navigate based on notification data
  static void navigateToScreen(BuildContext context, Map<String, dynamic> data) {
    final type = data['type'] as String?;
    
    switch (type) {
      case 'message':
        final conversationId = data['conversationId'] as String?;
        if (conversationId != null) {
          Navigator.pushNamed(context, '/chat', arguments: {'conversationId': conversationId});
        }
        break;
        
      case 'post':
      case 'like':
      case 'comment':
      case 'comment_reply':
      case 'like_on_comment':
      case 'repost':
      case 'mention':
        final postId = data['postId'] as String?;
        if (postId != null) {
          Navigator.pushNamed(context, '/post', arguments: {'postId': postId});
        }
        break;
        
      case 'connection':
      case 'connection_request':
      case 'follow':
      case 'new_connection':
        final userId = data['userId'] as String? ?? data['fromUserId'] as String?;
        if (userId != null) {
          Navigator.pushNamed(context, '/profile', arguments: {'userId': userId});
        }
        break;
        
      case 'invitation':
      case 'invitation_received':
      case 'invitation_accepted':
        Navigator.pushNamed(context, '/invitations');
        break;
        
      case 'new_podcast':
        final podcastId = data['podcastId'] as String?;
        if (podcastId != null) {
          Navigator.pushNamed(context, '/podcast', arguments: {'podcastId': podcastId});
        }
        break;
        
      case 'new_book':
        final bookId = data['bookId'] as String?;
        if (bookId != null) {
          Navigator.pushNamed(context, '/book', arguments: {'bookId': bookId});
        }
        break;
        
      case 'added_to_group':
        final groupId = data['groupId'] as String?;
        if (groupId != null) {
          Navigator.pushNamed(context, '/group', arguments: {'groupId': groupId});
        }
        break;
        
      case 'notification':
      default:
        Navigator.pushNamed(context, '/notifications');
        break;
    }
  }

  void dispose() {
    _navigationController.close();
  }
}
