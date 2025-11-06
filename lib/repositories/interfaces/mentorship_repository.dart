import 'dart:async';

// Model classes
class MentorModel {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? profession;
  final String? company;
  final List<String> expertise;
  final double rating;
  final int reviewCount;
  final String bio;
  final bool isOnline;
  final String location;
  final int yearsExperience;
  
  MentorModel({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.profession,
    this.company,
    required this.expertise,
    required this.rating,
    required this.reviewCount,
    required this.bio,
    required this.isOnline,
    required this.location,
    required this.yearsExperience,
  });
}

class MentorshipConversationModel {
  final String id;
  final String mentorId;
  final String studentId;
  final String? lastMessageType;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool muted;
  final MentorModel? mentor;
  
  MentorshipConversationModel({
    required this.id,
    required this.mentorId,
    required this.studentId,
    this.lastMessageType,
    this.lastMessageText,
    this.lastMessageAt,
    required this.unreadCount,
    required this.muted,
    this.mentor,
  });
}

class MentorshipFieldModel {
  final String id;
  final String name;
  final String icon;
  final String? description;
  final int mentorCount;
  
  MentorshipFieldModel({
    required this.id,
    required this.name,
    required this.icon,
    this.description,
    required this.mentorCount,
  });
}

class MentorshipRequestModel {
  final String id;
  final String mentorId;
  final String studentId;
  final String message;
  final String status; // pending, accepted, rejected
  final DateTime createdAt;
  final DateTime? respondedAt;
  
  MentorshipRequestModel({
    required this.id,
    required this.mentorId,
    required this.studentId,
    required this.message,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });
}

// Repository interface
abstract class MentorshipRepository {
  // Mentor management
  Future<List<MentorModel>> listMentors({String? fieldId, int limit = 20});
  Future<MentorModel?> getMentor(String mentorId);
  Future<List<MentorModel>> searchMentors(String query);
  Future<List<MentorModel>> getMyMentors();
  
  // Fields/Categories
  Future<List<MentorshipFieldModel>> listFields();
  Future<MentorshipFieldModel?> getField(String fieldId);
  
  // Conversations
  Future<List<MentorshipConversationModel>> listConversations();
  Future<String> createConversationWithMentor(String mentorId);
  Future<void> markConversationRead(String conversationId);
  Future<void> muteConversation(String conversationId);
  Future<void> unmuteConversation(String conversationId);
  Future<void> deleteConversation(String conversationId);
  
  // Mentorship requests
  Future<MentorshipRequestModel> sendRequest({
    required String mentorId,
    required String message,
  });
  Future<List<MentorshipRequestModel>> listMyRequests();
  Future<List<MentorshipRequestModel>> listReceivedRequests(); // For mentors
  Future<void> acceptRequest(String requestId);
  Future<void> rejectRequest(String requestId);
  
  // Real-time streams
  Stream<List<MentorshipConversationModel>> conversationsStream();
  Stream<List<MentorshipRequestModel>> requestsStream();
}
