import 'package:dio/dio.dart';
import '../core/api_client.dart';

class MentorUser {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? profession;
  final bool isOnline;
  MentorUser({required this.id, required this.name, this.avatarUrl, this.profession, this.isOnline = false});
  factory MentorUser.fromJson(Map<String, dynamic> json) => MentorUser(
        id: (json['id'] ?? json['user_id'] ?? '').toString(),
        name: (json['name'] ?? 'User').toString(),
        avatarUrl: json['avatarUrl']?.toString(),
        profession: json['profession']?.toString(),
        isOnline: (json['isOnline'] ?? json['is_online'] ?? false) == true,
      );
}

class MentorshipConversationSummary {
  final String id;
  final String mentorUserId;
  final MentorUser mentor;
  final String? lastMessageType;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool muted;
  final bool lastFromCurrentUser;
  final bool? lastRead;
  MentorshipConversationSummary({
    required this.id,
    required this.mentorUserId,
    required this.mentor,
    this.lastMessageType,
    this.lastMessageText,
    this.lastMessageAt,
    required this.unreadCount,
    required this.muted,
    required this.lastFromCurrentUser,
    this.lastRead,
  });
  factory MentorshipConversationSummary.fromJson(Map<String, dynamic> json) {
    DateTime? dt(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
    return MentorshipConversationSummary(
      id: (json['id'] ?? '').toString(),
      mentorUserId: (json['mentor_user_id'] ?? json['other_user_id'] ?? '').toString(),
      mentor: MentorUser.fromJson(Map<String, dynamic>.from(json['mentor'] ?? json['other_user'] ?? {})),
      lastMessageType: json['last_message_type']?.toString(),
      lastMessageText: json['last_message_text']?.toString(),
      lastMessageAt: dt(json['last_message_at']),
      unreadCount: int.tryParse((json['unread_count'] ?? 0).toString()) ?? 0,
      muted: (json['muted'] == true) || (json['muted'] == 1),
      lastFromCurrentUser: (json['last_from_current_user'] == true) || (json['last_from_current_user'] == 1),
      lastRead: json['last_read'] == null ? null : (json['last_read'] == true || json['last_read'] == 1),
    );
  }
}

class MentorshipFieldDto {
  final String id;
  final String name;
  final String icon;
  final String? description;
  final int mentorCount;
  MentorshipFieldDto({required this.id, required this.name, required this.icon, this.description, required this.mentorCount});
  factory MentorshipFieldDto.fromJson(Map<String, dynamic> j) => MentorshipFieldDto(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        icon: (j['icon'] ?? '').toString(),
        description: j['description']?.toString(),
        mentorCount: int.tryParse((j['mentor_count'] ?? 0).toString()) ?? 0,
      );
}

class MentorProfileDto {
  final String id;
  final String name;
  final String? avatar;
  final String profession;
  final String company;
  final List<String> expertise;
  final double rating;
  final int reviewCount;
  final String bio;
  final bool isOnline;
  final String location;
  final int yearsExperience;
  MentorProfileDto({
    required this.id,
    required this.name,
    this.avatar,
    required this.profession,
    required this.company,
    required this.expertise,
    required this.rating,
    required this.reviewCount,
    required this.bio,
    required this.isOnline,
    required this.location,
    required this.yearsExperience,
  });
  factory MentorProfileDto.fromJson(Map<String, dynamic> j) => MentorProfileDto(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? 'User').toString(),
        avatar: j['avatar']?.toString(),
        profession: (j['profession'] ?? '').toString(),
        company: (j['company'] ?? '').toString(),
        expertise: (j['expertise'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
        rating: double.tryParse((j['rating'] ?? 0).toString()) ?? 0.0,
        reviewCount: int.tryParse((j['reviewCount'] ?? 0).toString()) ?? 0,
        bio: (j['bio'] ?? '').toString(),
        isOnline: (j['isOnline'] ?? false) == true,
        location: (j['location'] ?? '').toString(),
        yearsExperience: int.tryParse((j['yearsExperience'] ?? 0).toString()) ?? 0,
      );
}

class MentorshipSessionDto {
  final String id;
  final String mentorId;
  final String mentorName;
  final String? mentorAvatar;
  final DateTime scheduledAt;
  final int durationMinutes;
  final String topic;
  final String status; // scheduled, in_progress, completed, cancelled
  final String? meetingLink;
  MentorshipSessionDto({
    required this.id,
    required this.mentorId,
    required this.mentorName,
    this.mentorAvatar,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.topic,
    required this.status,
    this.meetingLink,
  });
  factory MentorshipSessionDto.fromJson(Map<String, dynamic> j) => MentorshipSessionDto(
        id: (j['id'] ?? '').toString(),
        mentorId: (j['mentor_id'] ?? '').toString(),
        mentorName: (j['mentor_name'] ?? 'Mentor').toString(),
        mentorAvatar: j['mentor_avatar']?.toString(),
        scheduledAt: DateTime.tryParse(j['scheduled_at']?.toString() ?? '') ?? DateTime.now(),
        durationMinutes: int.tryParse((j['duration_minutes'] ?? 30).toString()) ?? 30,
        topic: (j['topic'] ?? '').toString(),
        status: (j['status'] ?? 'scheduled').toString(),
        meetingLink: j['meeting_link']?.toString(),
      );
}

class MentorshipApi {
  final Dio _dio = ApiClient().dio;

  Future<List<MentorshipConversationSummary>> listConversations() async {
    final res = await _dio.get('/api/mentorship/conversations');
    final map = Map<String, dynamic>.from(res.data);
    final data = Map<String, dynamic>.from(map['data'] ?? {});
    return (data['conversations'] as List<dynamic>? ?? [])
        .map((e) => MentorshipConversationSummary.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> markConversationRead(String conversationId) async {
    await _dio.post('/api/mentorship/conversations/$conversationId/mark-read');
  }
  
  Future<String> ensureConversationWithMentor(String mentorUserId) async {
    final res = await _dio.post('/api/mentorship/conversations', data: {'mentor_user_id': mentorUserId});
    final map = Map<String, dynamic>.from(res.data);
    final data = Map<String, dynamic>.from(map['data'] ?? {});
    final conv = Map<String, dynamic>.from(data['conversation'] ?? {});
    return (conv['id'] ?? '').toString();
  }

  Future<List<MentorshipFieldDto>> listFields() async {
    final res = await _dio.get('/api/mentorship/fields');
    final map = Map<String, dynamic>.from(res.data);
    final data = Map<String, dynamic>.from(map['data'] ?? {});
    return (data['fields'] as List<dynamic>? ?? [])
        .map((e) => MentorshipFieldDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> createRequest({required String fieldId, required String message}) async {
    await _dio.post('/api/mentorship/requests', data: {'field_id': fieldId, 'message': message});
  }

  Future<List<MentorProfileDto>> listMyMentors() async {
    final res = await _dio.get('/api/mentorship/mentors');
    final map = Map<String, dynamic>.from(res.data);
    final data = Map<String, dynamic>.from(map['data'] ?? {});
    return (data['mentors'] as List<dynamic>? ?? [])
        .map((e) => MentorProfileDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<MentorshipSessionDto>> listSessions(String status) async {
    final res = await _dio.get('/api/mentorship/sessions', queryParameters: {'status': status});
    final map = Map<String, dynamic>.from(res.data);
    final data = Map<String, dynamic>.from(map['data'] ?? {});
    return (data['sessions'] as List<dynamic>? ?? [])
        .map((e) => MentorshipSessionDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<String> createSession({
    required String mentorUserId,
    required DateTime scheduledAt,
    required int durationMinutes,
    required String topic,
    String? meetingLink,
  }) async {
    final res = await _dio.post('/api/mentorship/sessions', data: {
      'mentor_user_id': mentorUserId,
      'scheduled_at': scheduledAt.toIso8601String(),
      'duration_minutes': durationMinutes,
      'topic': topic,
      if (meetingLink != null) 'meeting_link': meetingLink,
    });
    final map = Map<String, dynamic>.from(res.data);
    final data = Map<String, dynamic>.from(map['data'] ?? {});
    final s = Map<String, dynamic>.from(data['session'] ?? {});
    return (s['id'] ?? '').toString();
  }

  Future<void> updateSessionStatus({required String sessionId, required String status}) async {
    await _dio.patch('/api/mentorship/sessions/$sessionId/status', data: {'status': status});
  }

  Future<void> reviewSession({required String sessionId, required int rating, String? comment}) async {
    await _dio.post('/api/mentorship/sessions/$sessionId/reviews', data: {'rating': rating, if (comment != null) 'comment': comment});
  }
}