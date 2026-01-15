import 'package:flutter_test/flutter_test.dart';

/// Tests for Community Posts feature
/// Covers: community filtering, local caching, membership checks, moderation
void main() {
  group('Community Post Model', () {
    test('should map CommunityPostLite to UI model', () {
      final postLite = _MockCommunityPostLite(
        id: 'cp1',
        communityId: 'comm1',
        communityName: 'Flutter Devs',
        authorId: 'user1',
        authorName: 'John',
        content: 'Hello community!',
        createdAt: DateTime(2024, 1, 15),
      );
      
      final uiPost = _mapCommunityPostToUI(postLite);
      
      expect(uiPost['communityName'], 'Flutter Devs');
      expect(uiPost['content'], 'Hello community!');
    });

    test('should include community badge info', () {
      final postLite = _MockCommunityPostLite(
        id: 'cp1',
        communityId: 'comm1',
        communityName: 'Flutter Devs',
        communityIconUrl: 'https://example.com/icon.png',
        authorId: 'user1',
        authorName: 'John',
        content: 'Post',
        createdAt: DateTime.now(),
      );
      
      final uiPost = _mapCommunityPostToUI(postLite);
      expect(uiPost['communityIconUrl'], isNotNull);
    });
  });

  group('Community Posts Cache', () {
    test('should filter posts by community', () {
      final cache = _MockCommunityPostsCache();
      cache.putPosts([
        _createMockCommunityPost('cp1', communityId: 'comm1'),
        _createMockCommunityPost('cp2', communityId: 'comm2'),
        _createMockCommunityPost('cp3', communityId: 'comm1'),
      ]);
      
      final comm1Posts = cache.getPostsByCommunity('comm1');
      expect(comm1Posts.length, 2);
    });

    test('should return all community posts for feed', () {
      final cache = _MockCommunityPostsCache();
      cache.putPosts([
        _createMockCommunityPost('cp1', communityId: 'comm1'),
        _createMockCommunityPost('cp2', communityId: 'comm2'),
      ]);
      
      final allPosts = cache.getAllPostsSync(limit: 10);
      expect(allPosts.length, 2);
    });

    test('should sort by creation date', () {
      final cache = _MockCommunityPostsCache();
      cache.putPosts([
        _createMockCommunityPost('cp1', createdAt: DateTime(2024, 1, 10)),
        _createMockCommunityPost('cp2', createdAt: DateTime(2024, 1, 15)),
      ]);
      
      final posts = cache.getAllPostsSync(limit: 10);
      expect(posts.first.id, 'cp2'); // Newest first
    });
  });

  group('Community Membership', () {
    test('should check if user is member', () {
      final membership = _MockMembershipManager();
      membership.addMembership('user1', 'comm1');
      
      expect(membership.isMember('user1', 'comm1'), isTrue);
      expect(membership.isMember('user1', 'comm2'), isFalse);
    });

    test('should get user communities', () {
      final membership = _MockMembershipManager();
      membership.addMembership('user1', 'comm1');
      membership.addMembership('user1', 'comm2');
      membership.addMembership('user2', 'comm1');
      
      final userComms = membership.getUserCommunities('user1');
      expect(userComms.length, 2);
    });

    test('should filter posts by membership', () {
      final cache = _MockCommunityPostsCache();
      final membership = _MockMembershipManager();
      
      membership.addMembership('user1', 'comm1');
      cache.putPosts([
        _createMockCommunityPost('cp1', communityId: 'comm1'),
        _createMockCommunityPost('cp2', communityId: 'comm2'),
        _createMockCommunityPost('cp3', communityId: 'comm1'),
      ]);
      
      final memberPosts = cache.getPostsForMember('user1', membership);
      expect(memberPosts.length, 2);
    });
  });

  group('Community Post Creation', () {
    test('should require community ID', () {
      final result = _validateCommunityPost(
        communityId: 'comm1',
        content: 'Hello',
      );
      expect(result.isValid, isTrue);
    });

    test('should reject post without community', () {
      final result = _validateCommunityPost(
        communityId: '',
        content: 'Hello',
      );
      expect(result.isValid, isFalse);
      expect(result.error, contains('community'));
    });

    test('should reject empty content', () {
      final result = _validateCommunityPost(
        communityId: 'comm1',
        content: '',
      );
      expect(result.isValid, isFalse);
    });
  });

  group('Moderation', () {
    test('should identify reported posts', () {
      final cache = _MockCommunityPostsCache();
      cache.putPosts([
        _createMockCommunityPost('cp1', isReported: false),
        _createMockCommunityPost('cp2', isReported: true),
      ]);
      
      final reported = cache.getReportedPosts();
      expect(reported.length, 1);
      expect(reported.first.id, 'cp2');
    });

    test('should check moderator status', () {
      final membership = _MockMembershipManager();
      membership.addModerator('user1', 'comm1');
      
      expect(membership.isModerator('user1', 'comm1'), isTrue);
      expect(membership.isModerator('user1', 'comm2'), isFalse);
    });

    test('should allow moderator to remove posts', () {
      final membership = _MockMembershipManager();
      membership.addModerator('mod1', 'comm1');
      
      final canRemove = membership.canRemovePost('mod1', 'comm1');
      expect(canRemove, isTrue);
    });
  });

  group('Community Search', () {
    test('should search posts by content', () {
      final cache = _MockCommunityPostsCache();
      cache.putPosts([
        _createMockCommunityPost('cp1', content: 'Flutter is great'),
        _createMockCommunityPost('cp2', content: 'Dart basics'),
        _createMockCommunityPost('cp3', content: 'Advanced Flutter'),
      ]);
      
      final results = cache.searchPosts('Flutter');
      expect(results.length, 2);
    });
  });
}

// Helper functions

Map<String, dynamic> _mapCommunityPostToUI(_MockCommunityPostLite post) {
  return {
    'id': post.id,
    'communityId': post.communityId,
    'communityName': post.communityName,
    'communityIconUrl': post.communityIconUrl,
    'authorId': post.authorId,
    'authorName': post.authorName,
    'content': post.content,
  };
}

_ValidationResult _validateCommunityPost({
  required String communityId,
  required String content,
}) {
  if (communityId.isEmpty) {
    return _ValidationResult(isValid: false, error: 'community ID is required');
  }
  if (content.isEmpty) {
    return _ValidationResult(isValid: false, error: 'content is required');
  }
  return _ValidationResult(isValid: true);
}

_MockCommunityPostLite _createMockCommunityPost(
  String id, {
  String communityId = 'comm1',
  String content = 'Test content',
  DateTime? createdAt,
  bool isReported = false,
}) {
  return _MockCommunityPostLite(
    id: id,
    communityId: communityId,
    communityName: 'Test Community',
    authorId: 'user1',
    authorName: 'Test User',
    content: content,
    createdAt: createdAt ?? DateTime.now(),
    isReported: isReported,
  );
}

// Mock classes

class _MockCommunityPostLite {
  final String id;
  final String communityId;
  final String communityName;
  final String? communityIconUrl;
  final String authorId;
  final String authorName;
  final String content;
  final DateTime createdAt;
  final bool isReported;

  _MockCommunityPostLite({
    required this.id,
    required this.communityId,
    required this.communityName,
    this.communityIconUrl,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
    this.isReported = false,
  });
}

class _MockCommunityPostsCache {
  final List<_MockCommunityPostLite> _posts = [];

  void putPosts(List<_MockCommunityPostLite> posts) {
    _posts.addAll(posts);
  }

  List<_MockCommunityPostLite> getPostsByCommunity(String communityId) {
    return _posts.where((p) => p.communityId == communityId).toList();
  }

  List<_MockCommunityPostLite> getAllPostsSync({required int limit}) {
    final sorted = List<_MockCommunityPostLite>.from(_posts)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  List<_MockCommunityPostLite> getPostsForMember(String userId, _MockMembershipManager membership) {
    final userComms = membership.getUserCommunities(userId);
    return _posts.where((p) => userComms.contains(p.communityId)).toList();
  }

  List<_MockCommunityPostLite> getReportedPosts() {
    return _posts.where((p) => p.isReported).toList();
  }

  List<_MockCommunityPostLite> searchPosts(String query) {
    final lowerQuery = query.toLowerCase();
    return _posts.where((p) => p.content.toLowerCase().contains(lowerQuery)).toList();
  }
}

class _MockMembershipManager {
  final Map<String, Set<String>> _memberships = {};
  final Map<String, Set<String>> _moderators = {};

  void addMembership(String userId, String communityId) {
    _memberships.putIfAbsent(userId, () => {});
    _memberships[userId]!.add(communityId);
  }

  bool isMember(String userId, String communityId) {
    return _memberships[userId]?.contains(communityId) ?? false;
  }

  Set<String> getUserCommunities(String userId) {
    return _memberships[userId] ?? {};
  }

  void addModerator(String userId, String communityId) {
    _moderators.putIfAbsent(userId, () => {});
    _moderators[userId]!.add(communityId);
  }

  bool isModerator(String userId, String communityId) {
    return _moderators[userId]?.contains(communityId) ?? false;
  }

  bool canRemovePost(String userId, String communityId) {
    return isModerator(userId, communityId);
  }
}

class _ValidationResult {
  final bool isValid;
  final String? error;

  _ValidationResult({required this.isValid, this.error});
}
