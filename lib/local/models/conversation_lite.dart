import 'package:isar/isar.dart';
import '../utils/hash_utils.dart';

part 'conversation_lite.g.dart';

/// Lightweight conversation model for local Isar storage.
@collection
class ConversationLite {
  Id get isarId => fastHash(id);

  @Index(unique: true)
  late String id;

  /// Member user IDs
  List<String> memberIds = [];

  /// Other user info (for 1:1 chats)
  String? otherUserId;
  String? otherUserName;
  String? otherUserPhotoUrl;

  /// Last message preview
  String? lastMessageText;
  String? lastMessageType;
  DateTime? lastMessageAt;
  String? lastMessageSenderId;

  int unreadCount = 0;
  bool muted = false;

  @Index()
  DateTime? updatedAt;

  @Index()
  late DateTime localUpdatedAt;

  String syncStatus = 'synced';

  ConversationLite();

  factory ConversationLite.fromFirestore(String docId, Map<String, dynamic> data) {
    final conv = ConversationLite()
      ..id = docId
      ..otherUserId = data['otherUserId'] as String?
      ..lastMessageText = data['lastMessageText'] as String?
      ..lastMessageType = data['lastMessageType'] as String?
      ..lastMessageAt = _parseTimestamp(data['lastMessageAt'])
      ..lastMessageSenderId = data['lastMessageSenderId'] as String?
      ..unreadCount = _safeInt(data['unreadCount'])
      ..muted = data['muted'] == true
      ..updatedAt = _parseTimestamp(data['updatedAt'])
      ..localUpdatedAt = DateTime.now()
      ..syncStatus = 'synced';

    // Parse member IDs
    final members = data['memberIds'];
    if (members is List) {
      conv.memberIds = members.map((e) => e.toString()).toList();
    }

    // Parse other user info from nested object
    final otherUser = data['otherUser'];
    if (otherUser is Map) {
      conv.otherUserName = otherUser['name'] as String?;
      conv.otherUserPhotoUrl = otherUser['avatarUrl'] as String?;
    }

    return conv;
  }

  /// Create from a simple Map (for Hive/web storage)
  factory ConversationLite.fromMap(Map<String, dynamic> data) {
    final conv = ConversationLite()
      ..id = data['id'] as String? ?? ''
      ..otherUserId = data['otherUserId'] as String?
      ..otherUserName = data['otherUserName'] as String?
      ..otherUserPhotoUrl = data['otherUserPhotoUrl'] as String?
      ..lastMessageText = data['lastMessageText'] as String?
      ..lastMessageType = data['lastMessageType'] as String?
      ..lastMessageSenderId = data['lastMessageSenderId'] as String?
      ..unreadCount = _safeInt(data['unreadCount'])
      ..muted = data['muted'] as bool? ?? false
      ..syncStatus = data['syncStatus'] as String? ?? 'synced';

    final memberIds = data['memberIds'];
    if (memberIds is List) {
      conv.memberIds = memberIds.map((e) => e.toString()).toList();
    }

    conv.lastMessageAt = _parseMapTimestamp(data['lastMessageAt']);
    conv.updatedAt = _parseMapTimestamp(data['updatedAt']);
    final localUpdated = _parseMapTimestamp(data['localUpdatedAt']);
    if (localUpdated != null) {
      conv.localUpdatedAt = localUpdated;
    }

    return conv;
  }

  static DateTime? _parseMapTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  Map<String, dynamic> toDisplayMap() {
    return {
      'id': id,
      'memberIds': memberIds,
      'otherUserId': otherUserId,
      'otherUserName': otherUserName,
      'otherUserPhotoUrl': otherUserPhotoUrl,
      'lastMessageText': lastMessageText,
      'lastMessageType': lastMessageType,
      'lastMessageAt': lastMessageAt,
      'unreadCount': unreadCount,
      'muted': muted,
    };
  }

  static int _safeInt(dynamic value) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is double) return value.toInt().clamp(0, 999999999);
    return 0;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      final seconds = (value as dynamic).seconds as int?;
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    } catch (_) {}
    return null;
  }
}

