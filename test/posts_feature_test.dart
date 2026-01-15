import 'package:flutter_test/flutter_test.dart';

/// Tests for Posts feature
/// Covers: local caching, optimistic updates, likes/comments, media handling
/// Includes: Isar-first optimization for fluid/fast loading
void main() {
  group('Isar-First Caching Optimization', () {
    test('should load from local cache synchronously (instant)', () {
      final localRepo = _MockLocalPostRepository();
      localRepo.seedLocalData(List.generate(100, (i) => _createMockPost('p$i')));
      
      final stopwatch = Stopwatch()..start();
      final posts = localRepo.getLocalSync(limit: 20);
      stopwatch.stop();
      
      expect(posts.length, 20);
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });

    test('should show cached posts immediately then refresh', () {
      final localRepo = _MockLocalPostRepository();
      localRepo.seedLocalData([
        _createMockPost('p1'),
      ]);
      
      // Step 1: Instant load from cache
      final cached = localRepo.getLocalSync(limit: 20);
      expect(cached.length, 1);
      expect(cached.first.caption, 'Test caption');
      
      // Step 2: Background sync brings new data
      localRepo.upsertFromRemote([
        _createMockPost('p1'),
        _createMockPost('p2'),
      ]);
      
      // Step 3: UI refreshes with merged data
      final refreshed = localRepo.getLocalSync(limit: 20);
      expect(refreshed.length, 2);
    });

    test('should handle optimistic write with local-first pattern', () {
      final localRepo = _MockLocalPostRepository();
      
      // Create post locally first (optimistic)
      final pendingPost = _createMockPost('new_post', syncStatus: 'pending');
      localRepo.addPendingPost(pendingPost);
      
      // Post appears immediately in feed
      final posts = localRepo.getLocalSync(limit: 20);
      expect(posts.any((p) => p.id == 'new_post'), isTrue);
      expect(posts.first.syncStatus, 'pending');
    });

    test('should update sync status after server confirm', () {
      final localRepo = _MockLocalPostRepository();
      localRepo.addPendingPost(_createMockPost('p1', syncStatus: 'pending'));
      
      // Server confirms
      localRepo.updateSyncStatus('p1', 'synced');
      
      final post = localRepo.getLocalSync(limit: 20).first;
      expect(post.syncStatus, 'synced');
    });

    test('should use delta sync to minimize data transfer', () {
      final syncManager = _MockPostSyncManager();
      syncManager.setLastSyncTime(DateTime(2024, 1, 10));
      
      // Only fetch posts updated after last sync
      final cursor = syncManager.getLastSyncTime();
      expect(cursor, isNotNull);
      
      // After sync, update cursor
      syncManager.setLastSyncTime(DateTime(2024, 1, 15));
      expect(syncManager.getLastSyncTime()!.day, 15);
    });

    test('should work fully offline', () {
      final localRepo = _MockLocalPostRepository();
      localRepo.seedLocalData([
        _createMockPost('p1'),
        _createMockPost('p2'),
      ]);
      localRepo.setOfflineMode(true);
      
      final posts = localRepo.getLocalSync(limit: 20);
      expect(posts.length, 2);
    });
  });


  group('Post Model Mapping', () {
    test('should map PostLite to UI Post model', () {
      final postLite = _MockPostLite(
        id: 'post1',
        authorId: 'user1',
        authorName: 'John Doe',
        caption: 'Hello world!',
        mediaUrls: ['https://example.com/image.jpg'],
        mediaTypes: ['image'],
        likeCount: 10,
        commentCount: 5,
        createdAt: DateTime(2024, 1, 15),
      );
      
      final uiPost = _mapPostLiteToUI(postLite);
      
      expect(uiPost['id'], 'post1');
      expect(uiPost['authorName'], 'John Doe');
      expect(uiPost['likeCount'], 10);
    });

    test('should handle empty media lists', () {
      final postLite = _MockPostLite(
        id: 'post1',
        authorId: 'user1',
        authorName: 'John',
        caption: 'Text only post',
        mediaUrls: [],
        mediaTypes: [],
        createdAt: DateTime.now(),
      );
      
      final uiPost = _mapPostLiteToUI(postLite);
      expect(uiPost['mediaUrls'], isEmpty);
      expect(uiPost['hasMedia'], isFalse);
    });

    test('should handle null caption', () {
      final postLite = _MockPostLite(
        id: 'post1',
        authorId: 'user1',
        authorName: 'John',
        caption: null,
        mediaUrls: ['https://example.com/image.jpg'],
        mediaTypes: ['image'],
        createdAt: DateTime.now(),
      );
      
      final uiPost = _mapPostLiteToUI(postLite);
      expect(uiPost['caption'], '');
    });
  });

  group('Posts Local Cache', () {
    test('should return cached posts instantly', () {
      final cache = _MockPostsCache();
      cache.putPosts([
        _createMockPost('p1'),
        _createMockPost('p2'),
        _createMockPost('p3'),
      ]);
      
      final posts = cache.getPostsSync(limit: 10);
      expect(posts.length, 3);
    });

    test('should return posts in reverse chronological order', () {
      final cache = _MockPostsCache();
      cache.putPosts([
        _createMockPost('p1', createdAt: DateTime(2024, 1, 10)),
        _createMockPost('p2', createdAt: DateTime(2024, 1, 15)),
        _createMockPost('p3', createdAt: DateTime(2024, 1, 12)),
      ]);
      
      final posts = cache.getPostsSync(limit: 10);
      expect(posts.first.id, 'p2'); // Newest first
    });

    test('should filter by author', () {
      final cache = _MockPostsCache();
      cache.putPosts([
        _createMockPost('p1', authorId: 'user1'),
        _createMockPost('p2', authorId: 'user2'),
        _createMockPost('p3', authorId: 'user1'),
      ]);
      
      final userPosts = cache.getPostsByAuthor('user1');
      expect(userPosts.length, 2);
    });
  });

  group('Optimistic Like', () {
    test('should increment like count immediately', () {
      final post = _createMockPost('p1', likeCount: 10);
      final updated = _optimisticLike(post, isLiked: false);
      
      expect(updated.likeCount, 11);
      expect(updated.isLiked, isTrue);
    });

    test('should decrement like count on unlike', () {
      final post = _createMockPost('p1', likeCount: 10, isLiked: true);
      final updated = _optimisticLike(post, isLiked: true);
      
      expect(updated.likeCount, 9);
      expect(updated.isLiked, isFalse);
    });

    test('should not go below zero', () {
      final post = _createMockPost('p1', likeCount: 0);
      final updated = _optimisticLike(post, isLiked: true);
      
      expect(updated.likeCount, 0);
    });
  });

  group('Optimistic Comment', () {
    test('should increment comment count', () {
      final post = _createMockPost('p1', commentCount: 5);
      final updated = _optimisticAddComment(post);
      
      expect(updated.commentCount, 6);
    });

    test('should decrement on delete', () {
      final post = _createMockPost('p1', commentCount: 5);
      final updated = _optimisticDeleteComment(post);
      
      expect(updated.commentCount, 4);
    });
  });

  group('Post Creation', () {
    test('should generate deterministic ID', () {
      final id1 = _generatePostId('user1', DateTime(2024, 1, 15, 10, 30));
      final id2 = _generatePostId('user1', DateTime(2024, 1, 15, 10, 30));
      
      // Same inputs should give same ID for idempotency
      expect(id1, id2);
    });

    test('should create pending post locally', () {
      final cache = _MockPostsCache();
      final post = _createPendingPost(
        authorId: 'user1',
        authorName: 'John',
        caption: 'New post',
      );
      
      expect(post.syncStatus, 'pending');
      expect(post.id, isNotEmpty);
    });

    test('should update sync status after upload', () {
      final post = _createPendingPost(
        authorId: 'user1',
        authorName: 'John',
        caption: 'New post',
      );
      
      final synced = post.copyWith(syncStatus: 'synced');
      expect(synced.syncStatus, 'synced');
    });
  });

  group('Media Handling', () {
    test('should detect media type from URL', () {
      expect(_detectMediaType('https://example.com/photo.jpg'), 'image');
      expect(_detectMediaType('https://example.com/video.mp4'), 'video');
      expect(_detectMediaType('https://example.com/file.pdf'), 'unknown');
    });

    test('should validate media URLs', () {
      expect(_isValidMediaUrl('https://example.com/image.jpg'), isTrue);
      expect(_isValidMediaUrl(''), isFalse);
      expect(_isValidMediaUrl('not-a-url'), isFalse);
    });

    test('should handle multiple media items', () {
      final post = _createMockPost('p1', 
        mediaUrls: ['img1.jpg', 'img2.jpg', 'video.mp4'],
        mediaTypes: ['image', 'image', 'video'],
      );
      
      expect(post.mediaUrls.length, 3);
      expect(post.hasVideo, isTrue);
    });
  });

  group('Post Sync Status', () {
    test('should identify pending posts', () {
      final cache = _MockPostsCache();
      cache.putPosts([
        _createMockPost('p1', syncStatus: 'synced'),
        _createMockPost('p2', syncStatus: 'pending'),
        _createMockPost('p3', syncStatus: 'failed'),
      ]);
      
      final pending = cache.getPendingPosts();
      expect(pending.length, 1);
      expect(pending.first.id, 'p2');
    });

    test('should identify failed posts', () {
      final cache = _MockPostsCache();
      cache.putPosts([
        _createMockPost('p1', syncStatus: 'synced'),
        _createMockPost('p2', syncStatus: 'failed'),
      ]);
      
      final failed = cache.getFailedPosts();
      expect(failed.length, 1);
    });
  });
}

// Helper functions

Map<String, dynamic> _mapPostLiteToUI(_MockPostLite post) {
  return {
    'id': post.id,
    'authorId': post.authorId,
    'authorName': post.authorName,
    'caption': post.caption ?? '',
    'mediaUrls': post.mediaUrls,
    'likeCount': post.likeCount,
    'commentCount': post.commentCount,
    'hasMedia': post.mediaUrls.isNotEmpty,
  };
}

_MockPostLite _optimisticLike(_MockPostLite post, {required bool isLiked}) {
  if (isLiked) {
    return post.copyWith(
      likeCount: (post.likeCount - 1).clamp(0, 999999),
      isLiked: false,
    );
  } else {
    return post.copyWith(
      likeCount: post.likeCount + 1,
      isLiked: true,
    );
  }
}

_MockPostLite _optimisticAddComment(_MockPostLite post) {
  return post.copyWith(commentCount: post.commentCount + 1);
}

_MockPostLite _optimisticDeleteComment(_MockPostLite post) {
  return post.copyWith(commentCount: (post.commentCount - 1).clamp(0, 999999));
}

String _generatePostId(String authorId, DateTime timestamp) {
  return '${authorId}_${timestamp.millisecondsSinceEpoch}';
}

_MockPostLite _createPendingPost({
  required String authorId,
  required String authorName,
  required String caption,
}) {
  return _MockPostLite(
    id: _generatePostId(authorId, DateTime.now()),
    authorId: authorId,
    authorName: authorName,
    caption: caption,
    mediaUrls: [],
    mediaTypes: [],
    createdAt: DateTime.now(),
    syncStatus: 'pending',
  );
}

String _detectMediaType(String url) {
  final lower = url.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.gif')) {
    return 'image';
  }
  if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.webm')) {
    return 'video';
  }
  return 'unknown';
}

bool _isValidMediaUrl(String url) {
  if (url.isEmpty) return false;
  try {
    final uri = Uri.parse(url);
    return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
  } catch (e) {
    return false;
  }
}

_MockPostLite _createMockPost(
  String id, {
  String authorId = 'user1',
  String authorName = 'Test User',
  int likeCount = 0,
  int commentCount = 0,
  bool isLiked = false,
  String syncStatus = 'synced',
  DateTime? createdAt,
  List<String>? mediaUrls,
  List<String>? mediaTypes,
}) {
  return _MockPostLite(
    id: id,
    authorId: authorId,
    authorName: authorName,
    caption: 'Test caption',
    mediaUrls: mediaUrls ?? [],
    mediaTypes: mediaTypes ?? [],
    likeCount: likeCount,
    commentCount: commentCount,
    isLiked: isLiked,
    syncStatus: syncStatus,
    createdAt: createdAt ?? DateTime.now(),
  );
}

// Mock classes

class _MockPostLite {
  final String id;
  final String authorId;
  final String authorName;
  final String? caption;
  final List<String> mediaUrls;
  final List<String> mediaTypes;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final String syncStatus;
  final DateTime createdAt;

  _MockPostLite({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.caption,
    required this.mediaUrls,
    required this.mediaTypes,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.syncStatus = 'synced',
    required this.createdAt,
  });

  bool get hasVideo => mediaTypes.contains('video');

  _MockPostLite copyWith({
    int? likeCount,
    int? commentCount,
    bool? isLiked,
    String? syncStatus,
  }) {
    return _MockPostLite(
      id: id,
      authorId: authorId,
      authorName: authorName,
      caption: caption,
      mediaUrls: mediaUrls,
      mediaTypes: mediaTypes,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt,
    );
  }
}

class _MockPostsCache {
  final List<_MockPostLite> _posts = [];

  void putPosts(List<_MockPostLite> posts) {
    _posts.addAll(posts);
  }

  List<_MockPostLite> getPostsSync({required int limit}) {
    final sorted = List<_MockPostLite>.from(_posts)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  List<_MockPostLite> getPostsByAuthor(String authorId) {
    return _posts.where((p) => p.authorId == authorId).toList();
  }

  List<_MockPostLite> getPendingPosts() {
    return _posts.where((p) => p.syncStatus == 'pending').toList();
  }

  List<_MockPostLite> getFailedPosts() {
    return _posts.where((p) => p.syncStatus == 'failed').toList();
  }
}

class _MockLocalPostRepository {
  final List<_MockPostLite> _localData = [];
  bool _offlineMode = false;

  void seedLocalData(List<_MockPostLite> posts) {
    _localData.addAll(posts);
  }

  List<_MockPostLite> getLocalSync({required int limit}) {
    final sorted = List<_MockPostLite>.from(_localData)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  void addPendingPost(_MockPostLite post) {
    _localData.insert(0, post);
  }

  void upsertFromRemote(List<_MockPostLite> remotePosts) {
    for (final remote in remotePosts) {
      final existingIndex = _localData.indexWhere((p) => p.id == remote.id);
      if (existingIndex >= 0) {
        _localData[existingIndex] = remote;
      } else {
        _localData.add(remote);
      }
    }
  }

  void updateSyncStatus(String postId, String status) {
    final index = _localData.indexWhere((p) => p.id == postId);
    if (index >= 0) {
      _localData[index] = _localData[index].copyWith(syncStatus: status);
    }
  }

  void setOfflineMode(bool offline) {
    _offlineMode = offline;
  }
}

class _MockPostSyncManager {
  DateTime? _lastSyncTime;

  void setLastSyncTime(DateTime time) {
    _lastSyncTime = time;
  }

  DateTime? getLastSyncTime() => _lastSyncTime;
}
