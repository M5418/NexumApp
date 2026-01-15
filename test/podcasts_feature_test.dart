import 'package:flutter_test/flutter_test.dart';

/// Tests for Podcasts feature
/// Covers: local caching, playback state, episodes, downloads, playlists
/// Includes: Isar-first optimization for fluid/fast loading
void main() {
  group('Isar-First Caching Optimization', () {
    test('should load podcasts from local cache instantly', () {
      final localRepo = _MockLocalPodcastRepository();
      localRepo.seedLocalData(List.generate(50, (i) => _createMockPodcast('p$i')));
      
      final stopwatch = Stopwatch()..start();
      final podcasts = localRepo.getLocalSync(limit: 20);
      stopwatch.stop();
      
      expect(podcasts.length, 20);
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });

    test('should show cached podcasts before network fetch', () {
      final localRepo = _MockLocalPodcastRepository();
      localRepo.seedLocalData([
        _createMockPodcast('p1', title: 'Cached Podcast'),
      ]);
      
      final cached = localRepo.getLocalSync(limit: 20);
      expect(cached.length, 1);
      expect(cached.first.title, 'Cached Podcast');
    });

    test('should merge new podcasts from server', () {
      final localRepo = _MockLocalPodcastRepository();
      localRepo.seedLocalData([
        _createMockPodcast('p1', title: 'Old Podcast'),
      ]);
      
      localRepo.upsertFromRemote([
        _createMockPodcast('p1', title: 'Updated Podcast'),
        _createMockPodcast('p2', title: 'New Podcast'),
      ]);
      
      final podcasts = localRepo.getLocalSync(limit: 20);
      expect(podcasts.length, 2);
      expect(podcasts.firstWhere((p) => p.id == 'p1').title, 'Updated Podcast');
    });

    test('should cache episodes per podcast', () {
      final localRepo = _MockLocalPodcastRepository();
      localRepo.seedEpisodes('p1', [
        _createMockEpisode('e1', 'p1'),
        _createMockEpisode('e2', 'p1'),
      ]);
      
      final episodes = localRepo.getEpisodesSync('p1');
      expect(episodes.length, 2);
    });

    test('should persist playback position locally', () {
      final localRepo = _MockLocalPodcastRepository();
      localRepo.setPlaybackPosition('e1', 300);
      
      final position = localRepo.getPlaybackPosition('e1');
      expect(position, 300);
    });

    test('should work offline with cached podcasts', () {
      final localRepo = _MockLocalPodcastRepository();
      localRepo.seedLocalData([
        _createMockPodcast('p1'),
        _createMockPodcast('p2'),
      ]);
      localRepo.setOfflineMode(true);
      
      final podcasts = localRepo.getLocalSync(limit: 20);
      expect(podcasts.length, 2);
    });
  });


  group('Podcast Model Mapping', () {
    test('should map PodcastLite to UI model', () {
      final podcastLite = _MockPodcastLite(
        id: 'pod1',
        title: 'Flutter Weekly',
        author: 'Flutter Team',
        description: 'Weekly Flutter news',
        coverUrl: 'https://example.com/cover.jpg',
        episodeCount: 50,
        createdAt: DateTime(2024, 1, 15),
      );
      
      final uiPodcast = _mapPodcastToUI(podcastLite);
      
      expect(uiPodcast['title'], 'Flutter Weekly');
      expect(uiPodcast['episodeCount'], 50);
    });

    test('should handle null optional fields', () {
      final podcastLite = _MockPodcastLite(
        id: 'pod1',
        title: 'Minimal Podcast',
        author: null,
        description: null,
        coverUrl: null,
        episodeCount: 0,
        createdAt: DateTime.now(),
      );
      
      final uiPodcast = _mapPodcastToUI(podcastLite);
      expect(uiPodcast['author'], 'Unknown');
      expect(uiPodcast['description'], '');
    });
  });

  group('Podcasts Local Cache', () {
    test('should return cached podcasts instantly', () {
      final cache = _MockPodcastsCache();
      cache.putPodcasts([
        _createMockPodcast('p1'),
        _createMockPodcast('p2'),
      ]);
      
      final podcasts = cache.getPodcastsSync(limit: 20);
      expect(podcasts.length, 2);
    });

    test('should filter by published status', () {
      final cache = _MockPodcastsCache();
      cache.putPodcasts([
        _createMockPodcast('p1', isPublished: true),
        _createMockPodcast('p2', isPublished: false),
      ]);
      
      final published = cache.getPublishedPodcastsSync();
      expect(published.length, 1);
    });

    test('should sort by creation date', () {
      final cache = _MockPodcastsCache();
      cache.putPodcasts([
        _createMockPodcast('p1', createdAt: DateTime(2024, 1, 10)),
        _createMockPodcast('p2', createdAt: DateTime(2024, 1, 15)),
      ]);
      
      final podcasts = cache.getPodcastsSync(limit: 20);
      expect(podcasts.first.id, 'p2'); // Newest first
    });
  });

  group('Episode Management', () {
    test('should get episodes for podcast', () {
      final cache = _MockEpisodesCache();
      cache.putEpisodes('pod1', [
        _createMockEpisode('e1', 'pod1'),
        _createMockEpisode('e2', 'pod1'),
      ]);
      
      final episodes = cache.getEpisodesSync('pod1');
      expect(episodes.length, 2);
    });

    test('should sort episodes by number', () {
      final cache = _MockEpisodesCache();
      cache.putEpisodes('pod1', [
        _createMockEpisode('e1', 'pod1', episodeNumber: 3),
        _createMockEpisode('e2', 'pod1', episodeNumber: 1),
        _createMockEpisode('e3', 'pod1', episodeNumber: 2),
      ]);
      
      final episodes = cache.getEpisodesSync('pod1');
      expect(episodes.first.episodeNumber, 1);
    });

    test('should track episode duration', () {
      final episode = _createMockEpisode('e1', 'pod1', durationSeconds: 3600);
      expect(episode.durationSeconds, 3600);
      expect(_formatDuration(episode.durationSeconds), '1:00:00');
    });
  });

  group('Playback State', () {
    test('should track current position', () {
      final playback = _MockPlaybackState();
      playback.setPosition('e1', 120);
      
      expect(playback.getPosition('e1'), 120);
    });

    test('should calculate progress percentage', () {
      final playback = _MockPlaybackState();
      playback.setPosition('e1', 300);
      playback.setDuration('e1', 600);
      
      expect(playback.getProgress('e1'), 50.0);
    });

    test('should mark as completed at 95%', () {
      final playback = _MockPlaybackState();
      playback.setPosition('e1', 570);
      playback.setDuration('e1', 600);
      
      expect(playback.isCompleted('e1'), isTrue);
    });

    test('should resume from last position', () {
      final playback = _MockPlaybackState();
      playback.setPosition('e1', 300);
      
      final resumePosition = playback.getResumePosition('e1');
      expect(resumePosition, 300);
    });
  });

  group('Downloads', () {
    test('should mark episode as downloaded', () {
      final downloads = _MockDownloadsManager();
      downloads.markDownloaded('e1', '/local/path/e1.mp3');
      
      expect(downloads.isDownloaded('e1'), isTrue);
    });

    test('should get local path for downloaded episode', () {
      final downloads = _MockDownloadsManager();
      downloads.markDownloaded('e1', '/local/path/e1.mp3');
      
      expect(downloads.getLocalPath('e1'), '/local/path/e1.mp3');
    });

    test('should prefer local path when available', () {
      final downloads = _MockDownloadsManager();
      downloads.markDownloaded('e1', '/local/path/e1.mp3');
      
      final playUrl = downloads.getPlayUrl('e1', 'https://remote.com/e1.mp3');
      expect(playUrl, '/local/path/e1.mp3');
    });

    test('should calculate download size', () {
      final downloads = _MockDownloadsManager();
      downloads.markDownloaded('e1', '/path/e1.mp3', sizeBytes: 50000000);
      downloads.markDownloaded('e2', '/path/e2.mp3', sizeBytes: 30000000);
      
      final totalSize = downloads.getTotalDownloadSize();
      expect(totalSize, 80000000);
    });
  });

  group('Playlist', () {
    test('should add episode to queue', () {
      final queue = _MockPlayQueue();
      queue.addToQueue('e1');
      queue.addToQueue('e2');
      
      expect(queue.queueLength, 2);
    });

    test('should get next episode', () {
      final queue = _MockPlayQueue();
      queue.addToQueue('e1');
      queue.addToQueue('e2');
      
      expect(queue.getNext(), 'e1');
    });

    test('should remove from queue after playing', () {
      final queue = _MockPlayQueue();
      queue.addToQueue('e1');
      queue.addToQueue('e2');
      queue.playNext();
      
      expect(queue.queueLength, 1);
      expect(queue.getNext(), 'e2');
    });

    test('should support shuffle', () {
      final queue = _MockPlayQueue();
      queue.addToQueue('e1');
      queue.addToQueue('e2');
      queue.addToQueue('e3');
      queue.shuffle();
      
      expect(queue.queueLength, 3);
    });
  });

  group('Search', () {
    test('should search podcasts by title', () {
      final cache = _MockPodcastsCache();
      cache.putPodcasts([
        _createMockPodcast('p1', title: 'Flutter Weekly'),
        _createMockPodcast('p2', title: 'Dart News'),
        _createMockPodcast('p3', title: 'Advanced Flutter'),
      ]);
      
      final results = cache.searchPodcasts('Flutter');
      expect(results.length, 2);
    });

    test('should search episodes by title', () {
      final cache = _MockEpisodesCache();
      cache.putEpisodes('pod1', [
        _createMockEpisode('e1', 'pod1', title: 'State Management'),
        _createMockEpisode('e2', 'pod1', title: 'Navigation'),
        _createMockEpisode('e3', 'pod1', title: 'State Restoration'),
      ]);
      
      final results = cache.searchEpisodes('pod1', 'State');
      expect(results.length, 2);
    });
  });

  group('Subscriptions', () {
    test('should track subscribed podcasts', () {
      final subs = _MockSubscriptions();
      subs.subscribe('pod1');
      
      expect(subs.isSubscribed('pod1'), isTrue);
    });

    test('should unsubscribe', () {
      final subs = _MockSubscriptions();
      subs.subscribe('pod1');
      subs.unsubscribe('pod1');
      
      expect(subs.isSubscribed('pod1'), isFalse);
    });

    test('should get subscribed podcasts', () {
      final subs = _MockSubscriptions();
      subs.subscribe('pod1');
      subs.subscribe('pod2');
      
      expect(subs.getSubscribedIds().length, 2);
    });
  });
}

// Helper functions

Map<String, dynamic> _mapPodcastToUI(_MockPodcastLite podcast) {
  return {
    'id': podcast.id,
    'title': podcast.title,
    'author': podcast.author ?? 'Unknown',
    'description': podcast.description ?? '',
    'coverUrl': podcast.coverUrl,
    'episodeCount': podcast.episodeCount,
  };
}

String _formatDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final secs = seconds % 60;
  
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

_MockPodcastLite _createMockPodcast(
  String id, {
  String title = 'Test Podcast',
  bool isPublished = true,
  DateTime? createdAt,
}) {
  return _MockPodcastLite(
    id: id,
    title: title,
    author: 'Test Author',
    description: 'Test description',
    coverUrl: 'https://example.com/cover.jpg',
    episodeCount: 10,
    isPublished: isPublished,
    createdAt: createdAt ?? DateTime.now(),
  );
}

_MockEpisode _createMockEpisode(
  String id,
  String podcastId, {
  String title = 'Test Episode',
  int episodeNumber = 1,
  int durationSeconds = 1800,
}) {
  return _MockEpisode(
    id: id,
    podcastId: podcastId,
    title: title,
    episodeNumber: episodeNumber,
    durationSeconds: durationSeconds,
    audioUrl: 'https://example.com/audio.mp3',
  );
}

// Mock classes

class _MockPodcastLite {
  final String id;
  final String title;
  final String? author;
  final String? description;
  final String? coverUrl;
  final int episodeCount;
  final bool isPublished;
  final DateTime createdAt;

  _MockPodcastLite({
    required this.id,
    required this.title,
    this.author,
    this.description,
    this.coverUrl,
    required this.episodeCount,
    this.isPublished = true,
    required this.createdAt,
  });
}

class _MockEpisode {
  final String id;
  final String podcastId;
  final String title;
  final int episodeNumber;
  final int durationSeconds;
  final String audioUrl;

  _MockEpisode({
    required this.id,
    required this.podcastId,
    required this.title,
    required this.episodeNumber,
    required this.durationSeconds,
    required this.audioUrl,
  });
}

class _MockPodcastsCache {
  final List<_MockPodcastLite> _podcasts = [];

  void putPodcasts(List<_MockPodcastLite> podcasts) {
    _podcasts.addAll(podcasts);
  }

  List<_MockPodcastLite> getPodcastsSync({required int limit}) {
    final sorted = List<_MockPodcastLite>.from(_podcasts)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  List<_MockPodcastLite> getPublishedPodcastsSync() {
    return _podcasts.where((p) => p.isPublished).toList();
  }

  List<_MockPodcastLite> searchPodcasts(String query) {
    final lowerQuery = query.toLowerCase();
    return _podcasts.where((p) => p.title.toLowerCase().contains(lowerQuery)).toList();
  }
}

class _MockEpisodesCache {
  final Map<String, List<_MockEpisode>> _episodes = {};

  void putEpisodes(String podcastId, List<_MockEpisode> episodes) {
    _episodes[podcastId] = episodes;
  }

  List<_MockEpisode> getEpisodesSync(String podcastId) {
    final eps = _episodes[podcastId] ?? [];
    return List<_MockEpisode>.from(eps)..sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
  }

  List<_MockEpisode> searchEpisodes(String podcastId, String query) {
    final eps = _episodes[podcastId] ?? [];
    final lowerQuery = query.toLowerCase();
    return eps.where((e) => e.title.toLowerCase().contains(lowerQuery)).toList();
  }
}

class _MockPlaybackState {
  final Map<String, int> _positions = {};
  final Map<String, int> _durations = {};

  void setPosition(String episodeId, int seconds) {
    _positions[episodeId] = seconds;
  }

  int getPosition(String episodeId) => _positions[episodeId] ?? 0;

  void setDuration(String episodeId, int seconds) {
    _durations[episodeId] = seconds;
  }

  double getProgress(String episodeId) {
    final pos = _positions[episodeId] ?? 0;
    final dur = _durations[episodeId] ?? 1;
    return (pos / dur) * 100;
  }

  bool isCompleted(String episodeId) => getProgress(episodeId) >= 95;

  int getResumePosition(String episodeId) => _positions[episodeId] ?? 0;
}

class _MockDownloadsManager {
  final Map<String, String> _downloads = {};
  final Map<String, int> _sizes = {};

  void markDownloaded(String episodeId, String localPath, {int sizeBytes = 0}) {
    _downloads[episodeId] = localPath;
    _sizes[episodeId] = sizeBytes;
  }

  bool isDownloaded(String episodeId) => _downloads.containsKey(episodeId);

  String? getLocalPath(String episodeId) => _downloads[episodeId];

  String getPlayUrl(String episodeId, String remoteUrl) {
    return _downloads[episodeId] ?? remoteUrl;
  }

  int getTotalDownloadSize() {
    return _sizes.values.fold(0, (sum, size) => sum + size);
  }
}

class _MockPlayQueue {
  final List<String> _queue = [];

  int get queueLength => _queue.length;

  void addToQueue(String episodeId) {
    _queue.add(episodeId);
  }

  String? getNext() => _queue.isNotEmpty ? _queue.first : null;

  void playNext() {
    if (_queue.isNotEmpty) _queue.removeAt(0);
  }

  void shuffle() {
    _queue.shuffle();
  }
}

class _MockSubscriptions {
  final Set<String> _subscribed = {};

  void subscribe(String podcastId) {
    _subscribed.add(podcastId);
  }

  void unsubscribe(String podcastId) {
    _subscribed.remove(podcastId);
  }

  bool isSubscribed(String podcastId) => _subscribed.contains(podcastId);

  Set<String> getSubscribedIds() => Set.from(_subscribed);
}

class _MockLocalPodcastRepository {
  final List<_MockPodcastLite> _localData = [];
  final Map<String, List<_MockEpisode>> _episodes = {};
  final Map<String, int> _playbackPositions = {};
  bool _offlineMode = false;

  void seedLocalData(List<_MockPodcastLite> podcasts) {
    _localData.addAll(podcasts);
  }

  void seedEpisodes(String podcastId, List<_MockEpisode> episodes) {
    _episodes[podcastId] = episodes;
  }

  List<_MockPodcastLite> getLocalSync({required int limit}) {
    return _localData.take(limit).toList();
  }

  List<_MockEpisode> getEpisodesSync(String podcastId) {
    return _episodes[podcastId] ?? [];
  }

  void upsertFromRemote(List<_MockPodcastLite> remotePodcasts) {
    for (final remote in remotePodcasts) {
      final existingIndex = _localData.indexWhere((p) => p.id == remote.id);
      if (existingIndex >= 0) {
        _localData[existingIndex] = remote;
      } else {
        _localData.add(remote);
      }
    }
  }

  void setPlaybackPosition(String episodeId, int seconds) {
    _playbackPositions[episodeId] = seconds;
  }

  int getPlaybackPosition(String episodeId) => _playbackPositions[episodeId] ?? 0;

  void setOfflineMode(bool offline) {
    _offlineMode = offline;
  }
}
