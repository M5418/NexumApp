import '../models/mentor.dart';

class MentorshipData {
  static List<ProfessionalField> getProfessionalFields() {
    return [
      ProfessionalField(id: '1', name: 'FINANCE', icon: '💰', mentorCount: 45),
      ProfessionalField(id: '2', name: 'BUSINESS', icon: '💼', mentorCount: 67),
      ProfessionalField(id: '3', name: 'TECH', icon: '💻', mentorCount: 89),
      ProfessionalField(
        id: '4',
        name: 'MARKETING',
        icon: '📈',
        mentorCount: 34,
      ),
    ];
  }

  static List<Mentor> getMentors() {
    return [
      Mentor(
        id: '1',
        name: 'John Chen',
        avatar:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
        profession: 'Senior Investment Analyst',
        company: 'Goldman Sachs',
        expertise: [
          'Investment Strategy',
          'Portfolio Management',
          'Risk Analysis',
        ],
        rating: 4.9,
        reviewCount: 127,
        bio:
            'Experienced investment professional with 15+ years in financial markets.',
        isOnline: true,
        location: 'New York, NY',
        yearsExperience: 15,
      ),
      Mentor(
        id: '2',
        name: 'Sarah Kim',
        avatar:
            'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=150&h=150&fit=crop&crop=face',
        profession: 'Tech Entrepreneur',
        company: 'TechStart Inc.',
        expertise: ['Startup Strategy', 'Product Development', 'Team Building'],
        rating: 4.8,
        reviewCount: 89,
        bio:
            'Founded 3 successful startups, passionate about helping new entrepreneurs.',
        isOnline: false,
        location: 'San Francisco, CA',
        yearsExperience: 12,
      ),
      Mentor(
        id: '3',
        name: 'David Wilson',
        avatar:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
        profession: 'Marketing Director',
        company: 'Brand Solutions',
        expertise: ['Digital Marketing', 'Brand Strategy', 'Growth Hacking'],
        rating: 4.7,
        reviewCount: 156,
        bio:
            'Marketing expert who has scaled multiple brands from startup to IPO.',
        isOnline: true,
        location: 'Austin, TX',
        yearsExperience: 10,
      ),
      Mentor(
        id: '4',
        name: 'Emily Rodriguez',
        avatar:
            'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face',
        profession: 'Business Consultant',
        company: 'Strategy Partners',
        expertise: ['Business Strategy', 'Operations', 'Leadership'],
        rating: 4.9,
        reviewCount: 203,
        bio:
            'Former McKinsey consultant helping businesses optimize operations.',
        isOnline: true,
        location: 'Chicago, IL',
        yearsExperience: 18,
      ),
    ];
  }

  static List<MentorshipSession> getUpcomingSessions() {
    return [
      MentorshipSession(
        id: '1',
        mentorId: '1',
        mentorName: 'John Chen',
        mentorAvatar:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
        scheduledTime: DateTime.now().add(const Duration(days: 2, hours: 14)),
        duration: const Duration(hours: 1),
        topic: 'Portfolio Review & Strategy',
        status: SessionStatus.scheduled,
        meetingLink: 'https://meet.nexum.com/session/abc123',
      ),
      MentorshipSession(
        id: '2',
        mentorId: '3',
        mentorName: 'David Wilson',
        mentorAvatar:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
        scheduledTime: DateTime.now().add(const Duration(days: 5, hours: 10)),
        duration: const Duration(minutes: 45),
        topic: 'Marketing Campaign Planning',
        status: SessionStatus.scheduled,
        meetingLink: 'https://meet.nexum.com/session/def456',
      ),
    ];
  }

  static List<Mentor> getMyMentors() {
    return getMentors().take(3).toList();
  }
}
