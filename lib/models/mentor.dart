class Mentor {
  final String id;
  final String name;
  final String avatar;
  final String profession;
  final String company;
  final List<String> expertise;
  final double rating;
  final int reviewCount;
  final String bio;
  final bool isOnline;
  final String location;
  final int yearsExperience;

  Mentor({
    required this.id,
    required this.name,
    required this.avatar,
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
}

class MentorshipSession {
  final String id;
  final String mentorId;
  final String mentorName;
  final String mentorAvatar;
  final DateTime scheduledTime;
  final Duration duration;
  final String topic;
  final SessionStatus status;
  final String? meetingLink;

  MentorshipSession({
    required this.id,
    required this.mentorId,
    required this.mentorName,
    required this.mentorAvatar,
    required this.scheduledTime,
    required this.duration,
    required this.topic,
    required this.status,
    this.meetingLink,
  });
}

enum SessionStatus { scheduled, inProgress, completed, cancelled }

class ProfessionalField {
  final String id;
  final String name;
  final String icon;
  final int mentorCount;

  ProfessionalField({
    required this.id,
    required this.name,
    required this.icon,
    required this.mentorCount,
  });
}
