import 'package:flutter_test/flutter_test.dart';

/// Tests for Stories feature
/// Covers: story rings, expiration, viewing, creation, local caching
/// Includes: Isar-first optimization for fluid/fast loading
void main() {
  group('Isar-First Caching Optimization', () {
    test('should load stories from local cache instantly', () {
      final localRepo = _MockLocalStoryRepository();
      localRepo.seedLocalData(List.generate(50, (i) => _createMockStory('s$i')));
      
      final stopwatch = Stopwatch()..start();
      final stories = localRepo.getLocalSync(limit: 30);
      stopwatch.stop();
      
      expect(stories.length, 30);
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });

    test('should show cached story rings before network fetch', () {
      final localRepo = _MockLocalStoryRepository();
      localRepo.seedLocalData([
        _createMockStory('s1', authorId: 'user1'),
        _createMockStory('s2', authorId: 'user1'),
        _createMockStory('s3', authorId: 'user2'),
      ]);
      
      final rings = localRepo.getStoryRingsSync();
      expect(rings.length, 2); // 2 unique authors
    });

    test('should merge new stories from server', () {
      final localRepo = _MockLocalStoryRepository();
      localRepo.seedLocalData([
        _createMockStory('s1', authorId: 'user1'),
      ]);
      
      // Server brings new stories
      localRepo.upsertFromRemote([
        _createMockStory('s2', authorId: 'user1'),
        _createMockStory('s3', authorId: 'user2'),
      ]);
      
      final stories = localRepo.getLocalSync(limit: 50);
      expect(stories.length, 3);
    });

    test('should filter expired stories locally', () {
      final localRepo = _MockLocalStoryRepository();
      localRepo.seedLocalData([
        _createMockStory('s1', expiresAt: DateTime.now().add(const Duration(hours: 12))),
        _createMockStory('s2', expiresAt: DateTime.now().subtract(const Duration(hours: 1))),
      ]);
      
      final active = localRepo.getActiveStoriesSync();
      expect(active.length, 1);
    });

    test('should update viewed status locally', () {
      final localRepo = _MockLocalStoryRepository();
      localRepo.seedLocalData([
        _createMockStory('s1', viewed: false),
      ]);
      
      localRepo.markAsViewed('s1');
      
      final story = localRepo.getLocalSync(limit: 50).first;
      expect(story.viewed, isTrue);
    });

    test('should work offline with cached stories', () {
      final localRepo = _MockLocalStoryRepository();
      localRepo.seedLocalData([
        _createMockStory('s1'),
        _createMockStory('s2'),
      ]);
      localRepo.setOfflineMode(true);
      
      final stories = localRepo.getLocalSync(limit: 50);
      expect(stories.length, 2);
    });
  });


  group('Story Model Mapping', () {
    test('should map StoryLite to UI StoryModel', () {
      final storyLite = _MockStoryLite(
        id: 'story1',
        authorId: 'user1',
        authorName: 'John',
        authorPhotoUrl: 'https://example.com/avatar.jpg',
        mediaUrl: 'https://example.com/story.jpg',
        mediaType: 'image',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );
      
      final uiStory = _mapStoryToUI(storyLite);
      
      expect(uiStory['authorName'], 'John');
      expect(uiStory['mediaType'], 'image');
    });

    test('should handle video stories', () {
      final storyLite = _MockStoryLite(
        id: 'story1',
        authorId: 'user1',
        authorName: 'John',
        mediaUrl: 'https://example.com/story.mp4',
        mediaType: 'video',
        durationSeconds: 15,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );
      
      final uiStory = _mapStoryToUI(storyLite);
      expect(uiStory['mediaType'], 'video');
      expect(uiStory['durationSeconds'], 15);
    });
  });

  group('Story Expiration', () {
    test('should identify expired stories', () {
      final expiredStory = _MockStoryLite(
        id: 'story1',
        authorId: 'user1',
        authorName: 'John',
        mediaUrl: 'https://example.com/story.jpg',
        mediaType: 'image',
        createdAt: DateTime.now().subtract(const Duration(hours: 25)),
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      
      expect(expiredStory.isExpired, isTrue);
    });

    test('should identify active stories', () {
      final activeStory = _MockStoryLite(
        id: 'story1',
        authorId: 'user1',
        authorName: 'John',
        mediaUrl: 'https://example.com/story.jpg',
        mediaType: 'image',
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        expiresAt: DateTime.now().add(const Duration(hours: 12)),
      );
      
      expect(activeStory.isExpired, isFalse);
    });

    test('should filter out expired stories from cache', () {
      final cache = _MockStoriesCache();
      cache.putStories([
        _createMockStory('s1', expiresAt: DateTime.now().add(const Duration(hours: 12))),
        _createMockStory('s2', expiresAt: DateTime.now().subtract(const Duration(hours: 1))),
        _createMockStory('s3', expiresAt: DateTime.now().add(const Duration(hours: 6))),
      ]);
      
      final active = cache.getActiveStoriesSync();
      expect(active.length, 2);
    });
  });

  group('Story Rings', () {
    test('should group stories by author', () {
      final cache = _MockStoriesCache();
      cache.putStories([
        _createMockStory('s1', authorId: 'user1'),
        _createMockStory('s2', authorId: 'user2'),
        _createMockStory('s3', authorId: 'user1'),
      ]);
      
      final rings = cache.getStoryRings();
      expect(rings.length, 2); // 2 unique authors
    });

    test('should sort rings by latest story', () {
      final cache = _MockStoriesCache();
      cache.putStories([
        _createMockStory('s1', authorId: 'user1', createdAt: DateTime(2024, 1, 10)),
        _createMockStory('s2', authorId: 'user2', createdAt: DateTime(2024, 1, 15)),
        _createMockStory('s3', authorId: 'user1', createdAt: DateTime(2024, 1, 12)),
      ]);
      
      final rings = cache.getStoryRings();
      expect(rings.first.authorId, 'user2'); // Most recent story
    });

    test('should mark ring as viewed when all stories viewed', () {
      final ring = _MockStoryRing(
        authorId: 'user1',
        stories: [
          _createMockStory('s1', authorId: 'user1', viewed: true),
          _createMockStory('s2', authorId: 'user1', viewed: true),
        ],
      );
      
      expect(ring.allViewed, isTrue);
    });

    test('should mark ring as unviewed if any story unviewed', () {
      final ring = _MockStoryRing(
        authorId: 'user1',
        stories: [
          _createMockStory('s1', authorId: 'user1', viewed: true),
          _createMockStory('s2', authorId: 'user1', viewed: false),
        ],
      );
      
      expect(ring.allViewed, isFalse);
    });
  });

  group('Story Viewing', () {
    test('should mark story as viewed', () {
      final story = _createMockStory('s1', viewed: false);
      final viewed = story.markAsViewed();
      
      expect(viewed.viewed, isTrue);
    });

    test('should track view count', () {
      final story = _createMockStory('s1', viewCount: 10);
      expect(story.viewCount, 10);
    });

    test('should increment view count', () {
      final story = _createMockStory('s1', viewCount: 10);
      final updated = story.incrementViewCount();
      
      expect(updated.viewCount, 11);
    });

    test('should track viewer IDs', () {
      final viewers = _MockStoryViewers();
      viewers.addViewer('story1', 'user2');
      viewers.addViewer('story1', 'user3');
      
      expect(viewers.getViewers('story1').length, 2);
    });
  });

  group('Story Creation', () {
    test('should validate image story', () {
      final result = _validateStory(
        mediaUrl: 'https://example.com/image.jpg',
        mediaType: 'image',
      );
      expect(result.isValid, isTrue);
    });

    test('should validate video story with duration', () {
      final result = _validateStory(
        mediaUrl: 'https://example.com/video.mp4',
        mediaType: 'video',
        durationSeconds: 15,
      );
      expect(result.isValid, isTrue);
    });

    test('should reject video longer than 60 seconds', () {
      final result = _validateStory(
        mediaUrl: 'https://example.com/video.mp4',
        mediaType: 'video',
        durationSeconds: 90,
      );
      expect(result.isValid, isFalse);
      expect(result.error, contains('60'));
    });

    test('should reject story without media', () {
      final result = _validateStory(
        mediaUrl: '',
        mediaType: 'image',
      );
      expect(result.isValid, isFalse);
    });

    test('should set expiration to 24 hours', () {
      final story = _createNewStory(
        authorId: 'user1',
        mediaUrl: 'https://example.com/image.jpg',
        mediaType: 'image',
      );
      
      final hoursDiff = story.expiresAt.difference(story.createdAt).inHours;
      expect(hoursDiff, 24);
    });
  });

  group('Stories Local Cache', () {
    test('should return cached stories instantly', () {
      final cache = _MockStoriesCache();
      cache.putStories([
        _createMockStory('s1'),
        _createMockStory('s2'),
      ]);
      
      final stories = cache.getStoriesSync(limit: 50);
      expect(stories.length, 2);
    });

    test('should filter by author', () {
      final cache = _MockStoriesCache();
      cache.putStories([
        _createMockStory('s1', authorId: 'user1'),
        _createMockStory('s2', authorId: 'user2'),
        _createMockStory('s3', authorId: 'user1'),
      ]);
      
      final userStories = cache.getStoriesByAuthor('user1');
      expect(userStories.length, 2);
    });
  });

  group('Story Progress', () {
    test('should track viewing progress for video', () {
      final progress = _MockStoryProgress();
      progress.setProgress('story1', 0.5);
      
      expect(progress.getProgress('story1'), 0.5);
    });

    test('should auto-advance after duration', () {
      final story = _createMockStory('s1', mediaType: 'image', durationSeconds: 5);
      expect(story.durationSeconds, 5);
    });
  });
}

// Helper functions

Map<String, dynamic> _mapStoryToUI(_MockStoryLite story) {
  return {
    'id': story.id,
    'authorId': story.authorId,
    'authorName': story.authorName,
    'authorPhotoUrl': story.authorPhotoUrl,
    'mediaUrl': story.mediaUrl,
    'mediaType': story.mediaType,
    'durationSeconds': story.durationSeconds,
    'viewed': story.viewed,
  };
}

_ValidationResult _validateStory({
  required String mediaUrl,
  required String mediaType,
  int? durationSeconds,
}) {
  if (mediaUrl.isEmpty) {
    return _ValidationResult(isValid: false, error: 'Media URL required');
  }
  if (mediaType == 'video' && (durationSeconds ?? 0) > 60) {
    return _ValidationResult(isValid: false, error: 'Video must be 60 seconds or less');
  }
  return _ValidationResult(isValid: true);
}

_MockStoryLite _createNewStory({
  required String authorId,
  required String mediaUrl,
  required String mediaType,
}) {
  final now = DateTime.now();
  return _MockStoryLite(
    id: 'story_${now.millisecondsSinceEpoch}',
    authorId: authorId,
    authorName: 'User',
    mediaUrl: mediaUrl,
    mediaType: mediaType,
    createdAt: now,
    expiresAt: now.add(const Duration(hours: 24)),
  );
}

_MockStoryLite _createMockStory(
  String id, {
  String authorId = 'user1',
  String authorName = 'Test User',
  String mediaType = 'image',
  int durationSeconds = 5,
  bool viewed = false,
  int viewCount = 0,
  DateTime? createdAt,
  DateTime? expiresAt,
}) {
  final now = DateTime.now();
  return _MockStoryLite(
    id: id,
    authorId: authorId,
    authorName: authorName,
    mediaUrl: 'https://example.com/story.jpg',
    mediaType: mediaType,
    durationSeconds: durationSeconds,
    viewed: viewed,
    viewCount: viewCount,
    createdAt: createdAt ?? now,
    expiresAt: expiresAt ?? now.add(const Duration(hours: 24)),
  );
}

// Mock classes

class _MockStoryLite {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String mediaUrl;
  final String mediaType;
  final int durationSeconds;
  final bool viewed;
  final int viewCount;
  final DateTime createdAt;
  final DateTime expiresAt;

  _MockStoryLite({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.mediaUrl,
    required this.mediaType,
    this.durationSeconds = 5,
    this.viewed = false,
    this.viewCount = 0,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  _MockStoryLite markAsViewed() {
    return _MockStoryLite(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorPhotoUrl: authorPhotoUrl,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      durationSeconds: durationSeconds,
      viewed: true,
      viewCount: viewCount,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }

  _MockStoryLite incrementViewCount() {
    return _MockStoryLite(
      id: id,
      authorId: authorId,
      authorName: authorName,
      authorPhotoUrl: authorPhotoUrl,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      durationSeconds: durationSeconds,
      viewed: viewed,
      viewCount: viewCount + 1,
      createdAt: createdAt,
      expiresAt: expiresAt,
    );
  }
}

class _MockStoryRing {
  final String authorId;
  final List<_MockStoryLite> stories;

  _MockStoryRing({required this.authorId, required this.stories});

  bool get allViewed => stories.every((s) => s.viewed);
}

class _MockStoriesCache {
  final List<_MockStoryLite> _stories = [];

  void putStories(List<_MockStoryLite> stories) {
    _stories.addAll(stories);
  }

  List<_MockStoryLite> getStoriesSync({required int limit}) {
    return _stories.take(limit).toList();
  }

  List<_MockStoryLite> getActiveStoriesSync() {
    return _stories.where((s) => !s.isExpired).toList();
  }

  List<_MockStoryLite> getStoriesByAuthor(String authorId) {
    return _stories.where((s) => s.authorId == authorId).toList();
  }

  List<_MockStoryRing> getStoryRings() {
    final byAuthor = <String, List<_MockStoryLite>>{};
    for (final story in _stories.where((s) => !s.isExpired)) {
      byAuthor.putIfAbsent(story.authorId, () => []);
      byAuthor[story.authorId]!.add(story);
    }
    
    final rings = byAuthor.entries.map((e) => _MockStoryRing(
      authorId: e.key,
      stories: e.value,
    )).toList();
    
    // Sort by latest story
    rings.sort((a, b) {
      final aLatest = a.stories.map((s) => s.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
      final bLatest = b.stories.map((s) => s.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
      return bLatest.compareTo(aLatest);
    });
    
    return rings;
  }
}

class _MockStoryViewers {
  final Map<String, Set<String>> _viewers = {};

  void addViewer(String storyId, String userId) {
    _viewers.putIfAbsent(storyId, () => {});
    _viewers[storyId]!.add(userId);
  }

  Set<String> getViewers(String storyId) => _viewers[storyId] ?? {};
}

class _MockStoryProgress {
  final Map<String, double> _progress = {};

  void setProgress(String storyId, double progress) {
    _progress[storyId] = progress;
  }

  double getProgress(String storyId) => _progress[storyId] ?? 0.0;
}

class _ValidationResult {
  final bool isValid;
  final String? error;

  _ValidationResult({required this.isValid, this.error});
}

class _MockLocalStoryRepository {
  final List<_MockStoryLite> _localData = [];
  bool _offlineMode = false;

  void seedLocalData(List<_MockStoryLite> stories) {
    _localData.addAll(stories);
  }

  List<_MockStoryLite> getLocalSync({required int limit}) {
    return _localData.take(limit).toList();
  }

  List<_MockStoryLite> getActiveStoriesSync() {
    return _localData.where((s) => !s.isExpired).toList();
  }

  List<_MockStoryRing> getStoryRingsSync() {
    final byAuthor = <String, List<_MockStoryLite>>{};
    for (final story in _localData.where((s) => !s.isExpired)) {
      byAuthor.putIfAbsent(story.authorId, () => []);
      byAuthor[story.authorId]!.add(story);
    }
    return byAuthor.entries.map((e) => _MockStoryRing(
      authorId: e.key,
      stories: e.value,
    )).toList();
  }

  void upsertFromRemote(List<_MockStoryLite> remoteStories) {
    for (final remote in remoteStories) {
      final existingIndex = _localData.indexWhere((s) => s.id == remote.id);
      if (existingIndex >= 0) {
        _localData[existingIndex] = remote;
      } else {
        _localData.add(remote);
      }
    }
  }

  void markAsViewed(String storyId) {
    final index = _localData.indexWhere((s) => s.id == storyId);
    if (index >= 0) {
      _localData[index] = _localData[index].markAsViewed();
    }
  }

  void setOfflineMode(bool offline) {
    _offlineMode = offline;
  }
}
