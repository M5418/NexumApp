import 'package:cloud_firestore/cloud_firestore.dart';

enum LiveStreamStatus {
  scheduled,
  live,
  ended,
  cancelled,
}

class LiveStreamModel {
  final String id;
  final String hostId;
  final String hostName;
  final String hostAvatarUrl;
  final String title;
  final String description;
  final String? thumbnailUrl;
  final String? thumbUrl; // Small thumbnail for fast feed loading
  final LiveStreamStatus status;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int viewerCount;
  final int peakViewerCount;
  final int totalViews;
  final int reactionCount;
  final int messageCount;
  final bool isPrivate;
  final bool isRecording;
  final String? recordingUrl;
  final List<String> invitedUserIds;
  final List<String> bannedUserIds;
  final String? streamKey;
  final String? streamUrl;

  LiveStreamModel({
    required this.id,
    required this.hostId,
    required this.hostName,
    required this.hostAvatarUrl,
    required this.title,
    required this.description,
    this.thumbnailUrl,
    this.thumbUrl,
    required this.status,
    required this.createdAt,
    this.scheduledAt,
    this.startedAt,
    this.endedAt,
    this.viewerCount = 0,
    this.peakViewerCount = 0,
    this.totalViews = 0,
    this.reactionCount = 0,
    this.messageCount = 0,
    this.isPrivate = false,
    this.isRecording = false,
    this.recordingUrl,
    this.invitedUserIds = const [],
    this.bannedUserIds = const [],
    this.streamKey,
    this.streamUrl,
  });

  factory LiveStreamModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LiveStreamModel(
      id: doc.id,
      hostId: data['hostId'] ?? '',
      hostName: data['hostName'] ?? '',
      hostAvatarUrl: data['hostAvatarUrl'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      thumbnailUrl: data['thumbnailUrl'],
      thumbUrl: data['thumbUrl'],
      status: _parseStatus(data['status']),
      createdAt: _parseDateTime(data['createdAt']) ?? DateTime.now(),
      scheduledAt: _parseDateTime(data['scheduledAt']),
      startedAt: _parseDateTime(data['startedAt']),
      endedAt: _parseDateTime(data['endedAt']),
      viewerCount: data['viewerCount'] ?? 0,
      peakViewerCount: data['peakViewerCount'] ?? 0,
      totalViews: data['totalViews'] ?? 0,
      reactionCount: data['reactionCount'] ?? 0,
      messageCount: data['messageCount'] ?? 0,
      isPrivate: data['isPrivate'] ?? false,
      isRecording: data['isRecording'] ?? false,
      recordingUrl: data['recordingUrl'],
      invitedUserIds: List<String>.from(data['invitedUserIds'] ?? []),
      bannedUserIds: List<String>.from(data['bannedUserIds'] ?? []),
      streamKey: data['streamKey'],
      streamUrl: data['streamUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'hostId': hostId,
      'hostName': hostName,
      'hostAvatarUrl': hostAvatarUrl,
      'title': title,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'scheduledAt': scheduledAt != null ? Timestamp.fromDate(scheduledAt!) : null,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'viewerCount': viewerCount,
      'peakViewerCount': peakViewerCount,
      'totalViews': totalViews,
      'reactionCount': reactionCount,
      'messageCount': messageCount,
      'isPrivate': isPrivate,
      'isRecording': isRecording,
      'recordingUrl': recordingUrl,
      'invitedUserIds': invitedUserIds,
      'bannedUserIds': bannedUserIds,
      'streamKey': streamKey,
      'streamUrl': streamUrl,
    };
  }

  LiveStreamModel copyWith({
    String? id,
    String? hostId,
    String? hostName,
    String? hostAvatarUrl,
    String? title,
    String? description,
    String? thumbnailUrl,
    LiveStreamStatus? status,
    DateTime? createdAt,
    DateTime? scheduledAt,
    DateTime? startedAt,
    DateTime? endedAt,
    int? viewerCount,
    int? peakViewerCount,
    int? totalViews,
    int? reactionCount,
    int? messageCount,
    bool? isPrivate,
    bool? isRecording,
    String? recordingUrl,
    List<String>? invitedUserIds,
    List<String>? bannedUserIds,
    String? streamKey,
    String? streamUrl,
  }) {
    return LiveStreamModel(
      id: id ?? this.id,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      hostAvatarUrl: hostAvatarUrl ?? this.hostAvatarUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      viewerCount: viewerCount ?? this.viewerCount,
      peakViewerCount: peakViewerCount ?? this.peakViewerCount,
      totalViews: totalViews ?? this.totalViews,
      reactionCount: reactionCount ?? this.reactionCount,
      messageCount: messageCount ?? this.messageCount,
      isPrivate: isPrivate ?? this.isPrivate,
      isRecording: isRecording ?? this.isRecording,
      recordingUrl: recordingUrl ?? this.recordingUrl,
      invitedUserIds: invitedUserIds ?? this.invitedUserIds,
      bannedUserIds: bannedUserIds ?? this.bannedUserIds,
      streamKey: streamKey ?? this.streamKey,
      streamUrl: streamUrl ?? this.streamUrl,
    );
  }

  static LiveStreamStatus _parseStatus(String? status) {
    switch (status) {
      case 'scheduled':
        return LiveStreamStatus.scheduled;
      case 'live':
        return LiveStreamStatus.live;
      case 'ended':
        return LiveStreamStatus.ended;
      case 'cancelled':
        return LiveStreamStatus.cancelled;
      default:
        return LiveStreamStatus.scheduled;
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool get isLive => status == LiveStreamStatus.live;
  bool get isScheduled => status == LiveStreamStatus.scheduled;
  bool get hasEnded => status == LiveStreamStatus.ended;
  bool get isCancelled => status == LiveStreamStatus.cancelled;

  String get durationString {
    if (startedAt == null) return '';
    final end = endedAt ?? DateTime.now();
    final duration = end.difference(startedAt!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}

class LiveStreamChatMessage {
  final String id;
  final String streamId;
  final String senderId;
  final String senderName;
  final String senderAvatarUrl;
  final String message;
  final DateTime sentAt;
  final bool isHost;
  final bool isModerator;
  final bool isPinned;

  LiveStreamChatMessage({
    required this.id,
    required this.streamId,
    required this.senderId,
    required this.senderName,
    required this.senderAvatarUrl,
    required this.message,
    required this.sentAt,
    this.isHost = false,
    this.isModerator = false,
    this.isPinned = false,
  });

  factory LiveStreamChatMessage.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LiveStreamChatMessage(
      id: doc.id,
      streamId: data['streamId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderAvatarUrl: data['senderAvatarUrl'] ?? '',
      message: data['message'] ?? '',
      sentAt: LiveStreamModel._parseDateTime(data['sentAt']) ?? DateTime.now(),
      isHost: data['isHost'] ?? false,
      isModerator: data['isModerator'] ?? false,
      isPinned: data['isPinned'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'streamId': streamId,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatarUrl': senderAvatarUrl,
      'message': message,
      'sentAt': Timestamp.fromDate(sentAt),
      'isHost': isHost,
      'isModerator': isModerator,
      'isPinned': isPinned,
    };
  }
}

class LiveStreamReaction {
  final String id;
  final String streamId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  LiveStreamReaction({
    required this.id,
    required this.streamId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  factory LiveStreamReaction.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LiveStreamReaction(
      id: doc.id,
      streamId: data['streamId'] ?? '',
      userId: data['userId'] ?? '',
      emoji: data['emoji'] ?? '❤️',
      createdAt: LiveStreamModel._parseDateTime(data['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'streamId': streamId,
      'userId': userId,
      'emoji': emoji,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class LiveStreamViewer {
  final String id;
  final String streamId;
  final String userId;
  final String userName;
  final String userAvatarUrl;
  final DateTime joinedAt;
  final bool isMuted;
  final bool isModerator;

  LiveStreamViewer({
    required this.id,
    required this.streamId,
    required this.userId,
    required this.userName,
    required this.userAvatarUrl,
    required this.joinedAt,
    this.isMuted = false,
    this.isModerator = false,
  });

  factory LiveStreamViewer.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LiveStreamViewer(
      id: doc.id,
      streamId: data['streamId'] ?? '',
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userAvatarUrl: data['userAvatarUrl'] ?? '',
      joinedAt: LiveStreamModel._parseDateTime(data['joinedAt']) ?? DateTime.now(),
      isMuted: data['isMuted'] ?? false,
      isModerator: data['isModerator'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'streamId': streamId,
      'userId': userId,
      'userName': userName,
      'userAvatarUrl': userAvatarUrl,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'isMuted': isMuted,
      'isModerator': isModerator,
    };
  }
}
