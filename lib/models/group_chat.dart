import 'package:cloud_firestore/cloud_firestore.dart';

/// Group member roles
enum GroupRole { admin, member }

/// Group member model
class GroupMember {
  final String odId;
  final String name;
  final String? avatarUrl;
  final GroupRole role;
  final DateTime joinedAt;
  final String? addedBy;

  GroupMember({
    required this.odId,
    required this.name,
    this.avatarUrl,
    required this.role,
    required this.joinedAt,
    this.addedBy,
  });

  bool get isAdmin => role == GroupRole.admin;

  Map<String, dynamic> toMap() {
    return {
      'userId': odId,
      'name': name,
      'avatarUrl': avatarUrl,
      'role': role == GroupRole.admin ? 'admin' : 'member',
      'joinedAt': Timestamp.fromDate(joinedAt),
      'addedBy': addedBy,
    };
  }

  factory GroupMember.fromMap(Map<String, dynamic> map) {
    return GroupMember(
      odId: map['userId'] ?? '',
      name: map['name'] ?? '',
      avatarUrl: map['avatarUrl'],
      role: map['role'] == 'admin' ? GroupRole.admin : GroupRole.member,
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      addedBy: map['addedBy'],
    );
  }
}

/// Group chat model
class GroupChat {
  final String id;
  final String name;
  final String? description;
  final String? avatarUrl;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> memberIds;
  final List<String> adminIds;
  final String? lastMessageText;
  final String? lastMessageType;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final String? lastMessageSenderName;
  final Map<String, int> unreadCounts;
  final Map<String, bool> mutedBy;
  final bool onlyAdminsCanSend;
  final bool onlyAdminsCanEditInfo;

  static const int maxMembers = 200;

  GroupChat({
    required this.id,
    required this.name,
    this.description,
    this.avatarUrl,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.memberIds,
    required this.adminIds,
    this.lastMessageText,
    this.lastMessageType,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.lastMessageSenderName,
    this.unreadCounts = const {},
    this.mutedBy = const {},
    this.onlyAdminsCanSend = false,
    this.onlyAdminsCanEditInfo = true,
  });

  bool isAdmin(String odId) => adminIds.contains(odId);
  bool isMember(String odId) => memberIds.contains(odId);
  bool isMuted(String odId) => mutedBy[odId] == true;
  int getUnreadCount(String odId) => unreadCounts[odId] ?? 0;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'avatarUrl': avatarUrl,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'memberIds': memberIds,
      'adminIds': adminIds,
      'lastMessageText': lastMessageText,
      'lastMessageType': lastMessageType,
      'lastMessageAt': lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageSenderName': lastMessageSenderName,
      'unreadCounts': unreadCounts,
      'mutedBy': mutedBy,
      'onlyAdminsCanSend': onlyAdminsCanSend,
      'onlyAdminsCanEditInfo': onlyAdminsCanEditInfo,
    };
  }

  factory GroupChat.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return GroupChat(
      id: doc.id,
      name: data['name'] ?? 'Group',
      description: data['description'],
      avatarUrl: data['avatarUrl'],
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      memberIds: List<String>.from(data['memberIds'] ?? []),
      adminIds: List<String>.from(data['adminIds'] ?? []),
      lastMessageText: data['lastMessageText'],
      lastMessageType: data['lastMessageType'],
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastMessageSenderId: data['lastMessageSenderId'],
      lastMessageSenderName: data['lastMessageSenderName'],
      unreadCounts: Map<String, int>.from(
        (data['unreadCounts'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0),
        ),
      ),
      mutedBy: Map<String, bool>.from(data['mutedBy'] ?? {}),
      onlyAdminsCanSend: data['onlyAdminsCanSend'] ?? false,
      onlyAdminsCanEditInfo: data['onlyAdminsCanEditInfo'] ?? true,
    );
  }

  GroupChat copyWith({
    String? id,
    String? name,
    String? description,
    String? avatarUrl,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? memberIds,
    List<String>? adminIds,
    String? lastMessageText,
    String? lastMessageType,
    DateTime? lastMessageAt,
    String? lastMessageSenderId,
    String? lastMessageSenderName,
    Map<String, int>? unreadCounts,
    Map<String, bool>? mutedBy,
    bool? onlyAdminsCanSend,
    bool? onlyAdminsCanEditInfo,
  }) {
    return GroupChat(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      memberIds: memberIds ?? this.memberIds,
      adminIds: adminIds ?? this.adminIds,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageSenderName: lastMessageSenderName ?? this.lastMessageSenderName,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      mutedBy: mutedBy ?? this.mutedBy,
      onlyAdminsCanSend: onlyAdminsCanSend ?? this.onlyAdminsCanSend,
      onlyAdminsCanEditInfo: onlyAdminsCanEditInfo ?? this.onlyAdminsCanEditInfo,
    );
  }
}

/// Group message model (extends regular message with group-specific fields)
class GroupMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final String type; // text, image, video, voice, file
  final List<Map<String, dynamic>> attachments;
  final DateTime createdAt;
  final String? replyToId;
  final String? replyToSenderName;
  final String? replyToContent;
  final String? replyToType;
  final Map<String, String> reactions; // odId -> emoji
  final List<String> readBy;
  final bool isDeleted;
  final String? deletedBy;
  final bool isSending; // For optimistic UI - true while uploading

  GroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    required this.type,
    this.attachments = const [],
    required this.createdAt,
    this.replyToId,
    this.replyToSenderName,
    this.replyToContent,
    this.replyToType,
    this.reactions = const {},
    this.readBy = const [],
    this.isDeleted = false,
    this.deletedBy,
    this.isSending = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'content': content,
      'type': type,
      'attachments': attachments,
      'createdAt': Timestamp.fromDate(createdAt),
      'replyToId': replyToId,
      'replyToSenderName': replyToSenderName,
      'replyToContent': replyToContent,
      'replyToType': replyToType,
      'reactions': reactions,
      'readBy': readBy,
      'isDeleted': isDeleted,
      'deletedBy': deletedBy,
    };
  }

  factory GroupMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return GroupMessage(
      id: doc.id,
      groupId: data['groupId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'User',
      senderAvatar: data['senderAvatar'],
      content: data['content'] ?? '',
      type: data['type'] ?? 'text',
      attachments: List<Map<String, dynamic>>.from(data['attachments'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      replyToId: data['replyToId'],
      replyToSenderName: data['replyToSenderName'],
      replyToContent: data['replyToContent'],
      replyToType: data['replyToType'],
      reactions: Map<String, String>.from(data['reactions'] ?? {}),
      readBy: List<String>.from(data['readBy'] ?? []),
      isDeleted: data['isDeleted'] ?? false,
      deletedBy: data['deletedBy'],
    );
  }

  GroupMessage copyWith({
    String? id,
    String? groupId,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    String? content,
    String? type,
    List<Map<String, dynamic>>? attachments,
    DateTime? createdAt,
    String? replyToId,
    String? replyToSenderName,
    String? replyToContent,
    String? replyToType,
    Map<String, String>? reactions,
    List<String>? readBy,
    bool? isDeleted,
    String? deletedBy,
  }) {
    return GroupMessage(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      content: content ?? this.content,
      type: type ?? this.type,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      replyToId: replyToId ?? this.replyToId,
      replyToSenderName: replyToSenderName ?? this.replyToSenderName,
      replyToContent: replyToContent ?? this.replyToContent,
      replyToType: replyToType ?? this.replyToType,
      reactions: reactions ?? this.reactions,
      readBy: readBy ?? this.readBy,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedBy: deletedBy ?? this.deletedBy,
    );
  }
}
