// Stub file for ConversationLite on web platform

class ConversationLite {
  String id = '';
  List<String> memberIds = [];
  String? otherUserId;
  String? otherUserName;
  String? otherUserPhotoUrl;
  String? lastMessageText;
  String? lastMessageType;
  String? lastMessageSenderId;
  DateTime? lastMessageAt;
  int unreadCount = 0;
  bool muted = false;
  DateTime? updatedAt;
  DateTime localUpdatedAt = DateTime.now();
  String syncStatus = 'synced';

  ConversationLite();

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

    conv.lastMessageAt = _parseTimestamp(data['lastMessageAt']);
    conv.updatedAt = _parseTimestamp(data['updatedAt']);

    return conv;
  }

  static int _safeInt(dynamic value) {
    if (value is int) return value < 0 ? 0 : value;
    if (value is double) return value.toInt().clamp(0, 999999999);
    return 0;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
