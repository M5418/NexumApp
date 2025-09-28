import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:intl/intl.dart';

import 'api_client.dart';

class AppNotification {
  final String id;
  final String type;
  final bool isRead;
  final DateTime createdAt;

  final String actorId;
  final String actorName;
  final String actorUsername; // includes leading @ if provided
  final String? actorAvatarUrl;

  final String actionText;
  final String? previewText;
  final String? previewImageUrl;

  // 'post' | 'community_post' | 'invitation' | 'conversation' | 'user_profile' | 'none'
  final String navigateType;
  final Map<String, dynamic> navigateParams;

  AppNotification({
    required this.id,
    required this.type,
    required this.isRead,
    required this.createdAt,
    required this.actorId,
    required this.actorName,
    required this.actorUsername,
    required this.actorAvatarUrl,
    required this.actionText,
    required this.previewText,
    required this.previewImageUrl,
    required this.navigateType,
    required this.navigateParams,
  });

  factory AppNotification.fromMap(Map<String, dynamic> m) {
    final actor = Map<String, dynamic>.from(m['actor'] ?? {});
    final navigate = Map<String, dynamic>.from(m['navigate'] ?? {});
    final parsedCreated = _parseDate(m['created_at']).toLocal(); // ensure LOCAL
    return AppNotification(
      id: (m['id'] ?? '').toString(),
      type: (m['type'] ?? '').toString(),
      isRead: (m['is_read'] ?? false) == true,
      createdAt: parsedCreated,
      actorId: (actor['id'] ?? '').toString(),
      actorName: (actor['name'] ?? 'User').toString(),
      actorUsername: (actor['username'] ?? '@user').toString(),
      actorAvatarUrl: (actor['avatarUrl']?.toString().isNotEmpty ?? false)
          ? actor['avatarUrl'].toString()
          : null,
      actionText: (m['action_text'] ?? 'did something').toString(),
      previewText: (m['preview_text']?.toString().isNotEmpty ?? false)
          ? m['preview_text'].toString()
          : null,
      previewImageUrl: (m['preview_image_url']?.toString().isNotEmpty ?? false)
          ? m['preview_image_url'].toString()
          : null,
      navigateType: (navigate['type'] ?? 'none').toString(),
      navigateParams: Map<String, dynamic>.from(navigate['params'] ?? const {}),
    );
  }

  // Compact relative label in LOCAL time: 'Just now', '5min ago', '3hr ago', 'Yesterday', '3d ago', or date.
  String timeLabel({DateTime? now}) {
    final n = (now ?? DateTime.now()).toLocal();
    final dt = createdAt.toLocal();

    final diff = n.difference(dt);
    final seconds = diff.inSeconds.abs();
    if (seconds < 45) return 'Just now';

    final minutes = diff.inMinutes.abs();
    if (minutes < 60) return '${minutes}min ago';

    final hours = diff.inHours.abs();
    if (hours < 24) return '${hours}hr ago';

    final days = diff.inDays.abs();
    if (days == 1) return 'Yesterday';
    if (days < 7) return '${days}d ago';

    return DateFormat('d MMM yyyy').format(dt);
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    final s = v.toString();

    // ISO-8601 (e.g., '2025-09-28T01:42:15.000Z' or with offset)
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;

    // Common MySQL DATETIME/TIMESTAMP string without timezone: treat as LOCAL clock time
    final m = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,3}))?$',
    ).firstMatch(s);
    if (m != null) {
      final year = int.parse(m.group(1)!);
      final month = int.parse(m.group(2)!);
      final day = int.parse(m.group(3)!);
      final hour = int.parse(m.group(4)!);
      final minute = int.parse(m.group(5)!);
      final second = int.parse(m.group(6)!);
      final ms = int.tryParse(m.group(7) ?? '0') ?? 0;
      return DateTime(year, month, day, hour, minute, second, ms); // local
    }
    return DateTime.now();
  }
}

class NotificationsApi {
  final Dio _dio = ApiClient().dio;

  Future<List<AppNotification>> list({int limit = 20, int offset = 0}) async {
    debugPrint('🔔 NotificationsApi.list(limit=$limit, offset=$offset)');
    final res = await _dio.get(
      '/api/notifications',
      queryParameters: {'limit': limit, 'offset': offset},
    );

    final body = Map<String, dynamic>.from(res.data ?? {});
    final data = Map<String, dynamic>.from(body['data'] ?? body);

    final List<dynamic> raw = data['notifications'] as List<dynamic>? ?? const [];
    return raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .map(AppNotification.fromMap)
        .toList();
  }

  Future<void> markRead(String id) async {
    await _dio.post('/api/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _dio.post('/api/notifications/read-all');
  }

  // Unread notifications count with graceful fallback.
  Future<int> unreadCount() async {
    try {
      final res = await _dio.get('/api/notifications/unread-count');
      final body = Map<String, dynamic>.from(res.data ?? {});
      final data = Map<String, dynamic>.from(body['data'] ?? body);
      final dynamic raw = data['unread'] ?? data['count'] ?? data['unread_count'] ?? 0;
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw) ?? 0;
      return 0;
    } catch (_) {
      try {
        // Fallback: sample a page and count locally
        final items = await list(limit: 50, offset: 0);
        return items.where((n) => !n.isRead).length;
      } catch (__) {
        return 0;
      }
    }
  }
}