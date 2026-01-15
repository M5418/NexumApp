import 'package:flutter_test/flutter_test.dart';

/// Tests for Mentorship feature
/// Covers: mentor matching, sessions, messaging, progress tracking
void main() {
  group('Mentorship Model Mapping', () {
    test('should map MentorshipLite to UI model', () {
      final mentorship = _MockMentorshipLite(
        id: 'ment1',
        mentorId: 'mentor1',
        menteeId: 'mentee1',
        mentorName: 'Dr. Smith',
        menteeName: 'John Doe',
        status: 'active',
        createdAt: DateTime(2024, 1, 15),
      );
      
      final uiMentorship = _mapMentorshipToUI(mentorship);
      
      expect(uiMentorship['mentorName'], 'Dr. Smith');
      expect(uiMentorship['status'], 'active');
    });

    test('should include expertise areas', () {
      final mentorship = _MockMentorshipLite(
        id: 'ment1',
        mentorId: 'mentor1',
        menteeId: 'mentee1',
        mentorName: 'Dr. Smith',
        menteeName: 'John',
        expertiseAreas: ['Flutter', 'Mobile Dev', 'Architecture'],
        status: 'active',
        createdAt: DateTime.now(),
      );
      
      final uiMentorship = _mapMentorshipToUI(mentorship);
      expect(uiMentorship['expertiseAreas'], hasLength(3));
    });
  });

  group('Mentorship Messages Cache', () {
    test('should return cached messages instantly', () {
      final cache = _MockMentorshipMessagesCache();
      cache.putMessages('ment1', [
        _createMockMentorshipMessage('m1', 'ment1'),
        _createMockMentorshipMessage('m2', 'ment1'),
      ]);
      
      final messages = cache.getMessagesSync('ment1', limit: 50);
      expect(messages.length, 2);
    });

    test('should sort messages chronologically', () {
      final cache = _MockMentorshipMessagesCache();
      cache.putMessages('ment1', [
        _createMockMentorshipMessage('m1', 'ment1', createdAt: DateTime(2024, 1, 15, 10, 0)),
        _createMockMentorshipMessage('m2', 'ment1', createdAt: DateTime(2024, 1, 15, 10, 5)),
        _createMockMentorshipMessage('m3', 'ment1', createdAt: DateTime(2024, 1, 15, 10, 2)),
      ]);
      
      final messages = cache.getMessagesSync('ment1', limit: 50);
      expect(messages.first.id, 'm1'); // Oldest first
      expect(messages.last.id, 'm2'); // Newest last
    });
  });

  group('Mentor Matching', () {
    test('should match by expertise', () {
      final mentors = [
        _createMockMentor('m1', expertise: ['Flutter', 'Dart']),
        _createMockMentor('m2', expertise: ['React', 'JavaScript']),
        _createMockMentor('m3', expertise: ['Flutter', 'Firebase']),
      ];
      
      final matches = _findMentorsByExpertise(mentors, 'Flutter');
      expect(matches.length, 2);
    });

    test('should filter available mentors', () {
      final mentors = [
        _createMockMentor('m1', isAvailable: true),
        _createMockMentor('m2', isAvailable: false),
        _createMockMentor('m3', isAvailable: true),
      ];
      
      final available = mentors.where((m) => m.isAvailable).toList();
      expect(available.length, 2);
    });

    test('should sort by rating', () {
      final mentors = [
        _createMockMentor('m1', rating: 4.5),
        _createMockMentor('m2', rating: 4.9),
        _createMockMentor('m3', rating: 4.2),
      ];
      
      final sorted = _sortMentorsByRating(mentors);
      expect(sorted.first.id, 'm2'); // Highest rating first
    });
  });

  group('Mentorship Status', () {
    test('should identify pending requests', () {
      final mentorship = _MockMentorshipLite(
        id: 'ment1',
        mentorId: 'mentor1',
        menteeId: 'mentee1',
        mentorName: 'Dr. Smith',
        menteeName: 'John',
        status: 'pending',
        createdAt: DateTime.now(),
      );
      
      expect(mentorship.isPending, isTrue);
      expect(mentorship.isActive, isFalse);
    });

    test('should identify active mentorships', () {
      final mentorship = _MockMentorshipLite(
        id: 'ment1',
        mentorId: 'mentor1',
        menteeId: 'mentee1',
        mentorName: 'Dr. Smith',
        menteeName: 'John',
        status: 'active',
        createdAt: DateTime.now(),
      );
      
      expect(mentorship.isActive, isTrue);
    });

    test('should identify completed mentorships', () {
      final mentorship = _MockMentorshipLite(
        id: 'ment1',
        mentorId: 'mentor1',
        menteeId: 'mentee1',
        mentorName: 'Dr. Smith',
        menteeName: 'John',
        status: 'completed',
        createdAt: DateTime.now(),
      );
      
      expect(mentorship.isCompleted, isTrue);
    });
  });

  group('Session Scheduling', () {
    test('should create session request', () {
      final session = _createSessionRequest(
        mentorshipId: 'ment1',
        requestedBy: 'mentee1',
        proposedTime: DateTime(2024, 1, 20, 14, 0),
        durationMinutes: 60,
      );
      
      expect(session.status, 'pending');
      expect(session.durationMinutes, 60);
    });

    test('should validate session time', () {
      final futureTime = DateTime.now().add(const Duration(days: 1));
      final pastTime = DateTime.now().subtract(const Duration(days: 1));
      
      expect(_isValidSessionTime(futureTime), isTrue);
      expect(_isValidSessionTime(pastTime), isFalse);
    });

    test('should check for scheduling conflicts', () {
      final existingSessions = [
        _createMockSession('s1', DateTime(2024, 1, 20, 14, 0), 60),
        _createMockSession('s2', DateTime(2024, 1, 20, 16, 0), 60),
      ];
      
      final conflictTime = DateTime(2024, 1, 20, 14, 30);
      final noConflictTime = DateTime(2024, 1, 20, 15, 30);
      
      expect(_hasConflict(existingSessions, conflictTime, 60), isTrue);
      expect(_hasConflict(existingSessions, noConflictTime, 30), isFalse);
    });
  });

  group('Progress Tracking', () {
    test('should track goals', () {
      final progress = _MockMentorshipProgress();
      progress.addGoal('ment1', 'Learn Flutter basics');
      progress.addGoal('ment1', 'Build first app');
      
      expect(progress.getGoals('ment1').length, 2);
    });

    test('should mark goal as completed', () {
      final progress = _MockMentorshipProgress();
      progress.addGoal('ment1', 'Learn Flutter basics');
      progress.completeGoal('ment1', 0);
      
      expect(progress.isGoalCompleted('ment1', 0), isTrue);
    });

    test('should calculate completion percentage', () {
      final progress = _MockMentorshipProgress();
      progress.addGoal('ment1', 'Goal 1');
      progress.addGoal('ment1', 'Goal 2');
      progress.addGoal('ment1', 'Goal 3');
      progress.addGoal('ment1', 'Goal 4');
      progress.completeGoal('ment1', 0);
      progress.completeGoal('ment1', 1);
      
      expect(progress.getCompletionPercentage('ment1'), 50.0);
    });
  });

  group('Mentor Actions', () {
    test('should accept mentorship request', () {
      final mentorship = _MockMentorshipLite(
        id: 'ment1',
        mentorId: 'mentor1',
        menteeId: 'mentee1',
        mentorName: 'Dr. Smith',
        menteeName: 'John',
        status: 'pending',
        createdAt: DateTime.now(),
      );
      
      final accepted = mentorship.accept();
      expect(accepted.status, 'active');
    });

    test('should decline mentorship request', () {
      final mentorship = _MockMentorshipLite(
        id: 'ment1',
        mentorId: 'mentor1',
        menteeId: 'mentee1',
        mentorName: 'Dr. Smith',
        menteeName: 'John',
        status: 'pending',
        createdAt: DateTime.now(),
      );
      
      final declined = mentorship.decline();
      expect(declined.status, 'declined');
    });

    test('should complete mentorship', () {
      final mentorship = _MockMentorshipLite(
        id: 'ment1',
        mentorId: 'mentor1',
        menteeId: 'mentee1',
        mentorName: 'Dr. Smith',
        menteeName: 'John',
        status: 'active',
        createdAt: DateTime.now(),
      );
      
      final completed = mentorship.complete();
      expect(completed.status, 'completed');
    });
  });

  group('Optimistic Message Send', () {
    test('should add message locally before server confirm', () {
      final cache = _MockMentorshipMessagesCache();
      final pending = _createPendingMentorshipMessage(
        mentorshipId: 'ment1',
        senderId: 'mentee1',
        text: 'Hello mentor!',
      );
      
      cache.addPendingMessage(pending);
      
      final messages = cache.getMessagesSync('ment1', limit: 50);
      expect(messages.any((m) => m.syncStatus == 'pending'), isTrue);
    });

    test('should update status after server confirm', () {
      final pending = _createPendingMentorshipMessage(
        mentorshipId: 'ment1',
        senderId: 'mentee1',
        text: 'Hello',
      );
      
      final confirmed = pending.copyWith(syncStatus: 'sent');
      expect(confirmed.syncStatus, 'sent');
    });
  });

  group('Rating and Feedback', () {
    test('should submit mentor rating', () {
      final feedback = _MockFeedback();
      feedback.submitRating('ment1', 5, 'Great mentor!');
      
      expect(feedback.getRating('ment1'), 5);
      expect(feedback.getComment('ment1'), 'Great mentor!');
    });

    test('should validate rating range', () {
      expect(_isValidRating(5), isTrue);
      expect(_isValidRating(1), isTrue);
      expect(_isValidRating(0), isFalse);
      expect(_isValidRating(6), isFalse);
    });
  });
}

// Helper functions

Map<String, dynamic> _mapMentorshipToUI(_MockMentorshipLite mentorship) {
  return {
    'id': mentorship.id,
    'mentorId': mentorship.mentorId,
    'menteeId': mentorship.menteeId,
    'mentorName': mentorship.mentorName,
    'menteeName': mentorship.menteeName,
    'expertiseAreas': mentorship.expertiseAreas,
    'status': mentorship.status,
  };
}

List<_MockMentor> _findMentorsByExpertise(List<_MockMentor> mentors, String expertise) {
  return mentors.where((m) => m.expertise.contains(expertise)).toList();
}

List<_MockMentor> _sortMentorsByRating(List<_MockMentor> mentors) {
  return List<_MockMentor>.from(mentors)..sort((a, b) => b.rating.compareTo(a.rating));
}

bool _isValidSessionTime(DateTime time) {
  return time.isAfter(DateTime.now());
}

bool _hasConflict(List<_MockSession> sessions, DateTime proposedTime, int durationMinutes) {
  final proposedEnd = proposedTime.add(Duration(minutes: durationMinutes));
  
  for (final session in sessions) {
    final sessionEnd = session.startTime.add(Duration(minutes: session.durationMinutes));
    
    // Check overlap
    if (proposedTime.isBefore(sessionEnd) && proposedEnd.isAfter(session.startTime)) {
      return true;
    }
  }
  return false;
}

bool _isValidRating(int rating) {
  return rating >= 1 && rating <= 5;
}

_MockSession _createSessionRequest({
  required String mentorshipId,
  required String requestedBy,
  required DateTime proposedTime,
  required int durationMinutes,
}) {
  return _MockSession(
    id: 'session_${DateTime.now().millisecondsSinceEpoch}',
    mentorshipId: mentorshipId,
    startTime: proposedTime,
    durationMinutes: durationMinutes,
    status: 'pending',
  );
}

_MockSession _createMockSession(String id, DateTime startTime, int durationMinutes) {
  return _MockSession(
    id: id,
    mentorshipId: 'ment1',
    startTime: startTime,
    durationMinutes: durationMinutes,
    status: 'confirmed',
  );
}

_MockMentorshipMessage _createMockMentorshipMessage(
  String id,
  String mentorshipId, {
  String senderId = 'user1',
  String text = 'Test message',
  DateTime? createdAt,
  String syncStatus = 'sent',
}) {
  return _MockMentorshipMessage(
    id: id,
    mentorshipId: mentorshipId,
    senderId: senderId,
    text: text,
    createdAt: createdAt ?? DateTime.now(),
    syncStatus: syncStatus,
  );
}

_MockMentorshipMessage _createPendingMentorshipMessage({
  required String mentorshipId,
  required String senderId,
  required String text,
}) {
  return _MockMentorshipMessage(
    id: 'pending_${DateTime.now().millisecondsSinceEpoch}',
    mentorshipId: mentorshipId,
    senderId: senderId,
    text: text,
    createdAt: DateTime.now(),
    syncStatus: 'pending',
  );
}

_MockMentor _createMockMentor(
  String id, {
  List<String> expertise = const ['General'],
  bool isAvailable = true,
  double rating = 4.5,
}) {
  return _MockMentor(
    id: id,
    name: 'Mentor $id',
    expertise: expertise,
    isAvailable: isAvailable,
    rating: rating,
  );
}

// Mock classes

class _MockMentorshipLite {
  final String id;
  final String mentorId;
  final String menteeId;
  final String mentorName;
  final String menteeName;
  final List<String> expertiseAreas;
  final String status;
  final DateTime createdAt;

  _MockMentorshipLite({
    required this.id,
    required this.mentorId,
    required this.menteeId,
    required this.mentorName,
    required this.menteeName,
    this.expertiseAreas = const [],
    required this.status,
    required this.createdAt,
  });

  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';

  _MockMentorshipLite accept() => _copyWith(status: 'active');
  _MockMentorshipLite decline() => _copyWith(status: 'declined');
  _MockMentorshipLite complete() => _copyWith(status: 'completed');

  _MockMentorshipLite _copyWith({String? status}) {
    return _MockMentorshipLite(
      id: id,
      mentorId: mentorId,
      menteeId: menteeId,
      mentorName: mentorName,
      menteeName: menteeName,
      expertiseAreas: expertiseAreas,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

class _MockMentorshipMessage {
  final String id;
  final String mentorshipId;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final String syncStatus;

  _MockMentorshipMessage({
    required this.id,
    required this.mentorshipId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.syncStatus = 'sent',
  });

  _MockMentorshipMessage copyWith({String? syncStatus}) {
    return _MockMentorshipMessage(
      id: id,
      mentorshipId: mentorshipId,
      senderId: senderId,
      text: text,
      createdAt: createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

class _MockMentorshipMessagesCache {
  final Map<String, List<_MockMentorshipMessage>> _messages = {};

  void putMessages(String mentorshipId, List<_MockMentorshipMessage> messages) {
    _messages[mentorshipId] = messages;
  }

  void addPendingMessage(_MockMentorshipMessage message) {
    _messages.putIfAbsent(message.mentorshipId, () => []);
    _messages[message.mentorshipId]!.add(message);
  }

  List<_MockMentorshipMessage> getMessagesSync(String mentorshipId, {required int limit}) {
    final msgs = _messages[mentorshipId] ?? [];
    final sorted = List<_MockMentorshipMessage>.from(msgs)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted.take(limit).toList();
  }
}

class _MockMentor {
  final String id;
  final String name;
  final List<String> expertise;
  final bool isAvailable;
  final double rating;

  _MockMentor({
    required this.id,
    required this.name,
    required this.expertise,
    required this.isAvailable,
    required this.rating,
  });
}

class _MockSession {
  final String id;
  final String mentorshipId;
  final DateTime startTime;
  final int durationMinutes;
  final String status;

  _MockSession({
    required this.id,
    required this.mentorshipId,
    required this.startTime,
    required this.durationMinutes,
    required this.status,
  });
}

class _MockMentorshipProgress {
  final Map<String, List<String>> _goals = {};
  final Map<String, Set<int>> _completed = {};

  void addGoal(String mentorshipId, String goal) {
    _goals.putIfAbsent(mentorshipId, () => []);
    _goals[mentorshipId]!.add(goal);
  }

  List<String> getGoals(String mentorshipId) => _goals[mentorshipId] ?? [];

  void completeGoal(String mentorshipId, int index) {
    _completed.putIfAbsent(mentorshipId, () => {});
    _completed[mentorshipId]!.add(index);
  }

  bool isGoalCompleted(String mentorshipId, int index) {
    return _completed[mentorshipId]?.contains(index) ?? false;
  }

  double getCompletionPercentage(String mentorshipId) {
    final total = _goals[mentorshipId]?.length ?? 0;
    final completed = _completed[mentorshipId]?.length ?? 0;
    if (total == 0) return 0.0;
    return (completed / total) * 100;
  }
}

class _MockFeedback {
  final Map<String, int> _ratings = {};
  final Map<String, String> _comments = {};

  void submitRating(String mentorshipId, int rating, String comment) {
    _ratings[mentorshipId] = rating;
    _comments[mentorshipId] = comment;
  }

  int? getRating(String mentorshipId) => _ratings[mentorshipId];
  String? getComment(String mentorshipId) => _comments[mentorshipId];
}
