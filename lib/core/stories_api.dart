import 'package:dio/dio.dart';
import 'api_client.dart';

class StoryRing {
  final String userId;
  final String name;
  final String username;
  final String? avatarUrl;
  final bool hasUnseen;
  final DateTime lastStoryAt;
  final String? thumbnailUrl;
  final int storyCount;

  StoryRing({
    required this.userId,
    required this.name,
    required this.username,
    this.avatarUrl,
    required this.hasUnseen,
    required this.lastStoryAt,
    this.thumbnailUrl,
    required this.storyCount,
  });

  factory StoryRing.fromJson(Map<String, dynamic> json) {
    return StoryRing(
      userId: json['user_id'] as String,
      name: json['name'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      hasUnseen: json['has_unseen'] as bool,
      lastStoryAt: DateTime.parse(json['last_story_at'] as String),
      thumbnailUrl: json['thumbnail_url'] as String?,
      storyCount: json['story_count'] as int,
    );
  }
}

class StoryUser {
  final String id;
  final String name;
  final String username;
  final String? avatarUrl;

  StoryUser({
    required this.id,
    required this.name,
    required this.username,
    this.avatarUrl,
  });

  factory StoryUser.fromJson(Map<String, dynamic> json) {
    return StoryUser(
      id: json['id'] as String,
      name: json['name'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}

class StoryItem {
  final String id;
  final String mediaType;
  final String? mediaUrl;
  final String? textContent;
  final String? backgroundColor;
  final String? audioUrl;
  final String? audioTitle;
  final String? thumbnailUrl;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool viewed;

  StoryItem({
    required this.id,
    required this.mediaType,
    this.mediaUrl,
    this.textContent,
    this.backgroundColor,
    this.audioUrl,
    this.audioTitle,
    this.thumbnailUrl,
    required this.createdAt,
    required this.expiresAt,
    required this.viewed,
  });

  factory StoryItem.fromJson(Map<String, dynamic> json) {
    return StoryItem(
      id: json['id'] as String,
      mediaType: json['media_type'] as String,
      mediaUrl: json['media_url'] as String?,
      textContent: json['text_content'] as String?,
      backgroundColor: json['background_color'] as String?,
      audioUrl: json['audio_url'] as String?,
      audioTitle: json['audio_title'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      viewed: json['viewed'] as bool,
    );
  }
}

class UserStoriesResponse {
  final StoryUser user;
  final List<StoryItem> items;

  UserStoriesResponse({
    required this.user,
    required this.items,
  });

  factory UserStoriesResponse.fromJson(Map<String, dynamic> json) {
    return UserStoriesResponse(
      user: StoryUser.fromJson(json['user'] as Map<String, dynamic>),
      items: (json['items'] as List)
          .map((item) => StoryItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StoriesApi {
  final Dio _dio = ApiClient().dio;

  Future<List<StoryRing>> getRings() async {
    try {
      final response = await _dio.get('/api/stories/rings');
      final data = response.data['data'] as Map<String, dynamic>;
      final rings = data['rings'] as List;
      return rings
          .map((ring) => StoryRing.fromJson(ring as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('🔴 StoriesApi.getRings error: $e');
      rethrow;
    }
  }

  Future<UserStoriesResponse> getUserStories(String userId) async {
    try {
      final response = await _dio.get('/api/stories/$userId');
      final data = response.data['data'] as Map<String, dynamic>;
      return UserStoriesResponse.fromJson(data);
    } catch (e) {
      print('🔴 StoriesApi.getUserStories error: $e');
      rethrow;
    }
  }

  Future<void> markStoryViewed(String storyId) async {
    try {
      await _dio.post('/api/stories/$storyId/view');
    } catch (e) {
      print('🔴 StoriesApi.markStoryViewed error: $e');
      rethrow;
    }
  }

  Future<String> replyToStory(String storyId, String text) async {
    try {
      final response =
          await _dio.post('/api/stories/$storyId/reply', data: {'text': text});
      final data = response.data['data'] as Map<String, dynamic>;
      return data['conversation_id'] as String;
    } catch (e) {
      print('🔴 StoriesApi.replyToStory error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createStory({
    required String mediaType,
    String? mediaUrl,
    String? textContent,
    String? backgroundColor,
    String? thumbnailUrl,
    String? audioUrl,
    String? audioTitle,
    String privacy = 'public',
  }) async {
    try {
      final payload = <String, dynamic>{
        'media_type': mediaType,
        'privacy': privacy,
      };

      if (mediaType == 'text') {
        payload['text_content'] = textContent;
        if (backgroundColor != null) {
          payload['background_color'] = backgroundColor;
        }
      } else {
        payload['media_url'] = mediaUrl;
        if (thumbnailUrl != null) payload['thumbnail_url'] = thumbnailUrl;
        if (mediaType == 'image') {
          if (audioUrl != null) payload['audio_url'] = audioUrl;
          if (audioTitle != null) payload['audio_title'] = audioTitle;
        }
      }

      final response = await _dio.post('/api/stories', data: payload);
      return response.data['data'] as Map<String, dynamic>;
    } catch (e) {
      print('🔴 StoriesApi.createStory error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> createStoriesBatch(
      List<Map<String, dynamic>> items) async {
    try {
      final response =
          await _dio.post('/api/stories/batch', data: {'items': items});
      final data = response.data['data'] as Map<String, dynamic>;
      return (data['stories'] as List).cast<Map<String, dynamic>>();
    } catch (e) {
      print('🔴 StoriesApi.createStoriesBatch error: $e');
      rethrow;
    }
  }

  Future<void> deleteStory(String storyId) async {
    try {
      await _dio.delete('/api/stories/$storyId');
    } catch (e) {
      print('🔴 StoriesApi.deleteStory error: $e');
      rethrow;
    }
  }

  Future<void> muteUserStories(String userId) async {
    try {
      await _dio.post('/api/stories/mute/$userId');
    } catch (e) {
      print('🔴 StoriesApi.muteUserStories error: $e');
      rethrow;
    }
  }

  Future<void> unmuteUserStories(String userId) async {
    try {
      await _dio.post('/api/stories/unmute/$userId');
    } catch (e) {
      print('🔴 StoriesApi.unmuteUserStories error: $e');
      rethrow;
    }
  }
}
