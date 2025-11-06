import 'dart:async';

// Model classes
class StoryModel {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String mediaType; // image, video, text, audio
  final String? mediaUrl;
  final String? textContent;
  final String? backgroundColor;
  final String? audioUrl;
  final String? audioTitle;
  final String? thumbnailUrl;
  final int durationSec;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool viewed;
  final int viewsCount;
  final bool liked;
  final int likesCount;
  final int commentsCount;
  final List<String> viewerIds;
  final List<String> mentionedUserIds;
  
  StoryModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.mediaType,
    this.mediaUrl,
    this.textContent,
    this.backgroundColor,
    this.audioUrl,
    this.audioTitle,
    this.thumbnailUrl,
    required this.durationSec,
    required this.createdAt,
    required this.expiresAt,
    required this.viewed,
    required this.viewsCount,
    required this.liked,
    required this.likesCount,
    required this.commentsCount,
    required this.viewerIds,
    required this.mentionedUserIds,
  });
}

class StoryRingModel {
  final String userId;
  final String userName;
  final String? userAvatar;
  final bool hasUnseen;
  final DateTime lastStoryAt;
  final String? thumbnailUrl;
  final int storyCount;
  final List<StoryModel> stories;
  
  StoryRingModel({
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.hasUnseen,
    required this.lastStoryAt,
    this.thumbnailUrl,
    required this.storyCount,
    required this.stories,
  });
}

class StoryViewerModel {
  final String userId;
  final String userName;
  final String? userAvatar;
  final DateTime viewedAt;
  final bool liked;
  final String? reaction;
  
  StoryViewerModel({
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.viewedAt,
    required this.liked,
    this.reaction,
  });
}

class StoryReplyModel {
  final String id;
  final String storyId;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String message;
  final DateTime createdAt;
  
  StoryReplyModel({
    required this.id,
    required this.storyId,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.message,
    required this.createdAt,
  });
}

// Repository interface
abstract class StoryRepository {
  // Story CRUD
  Future<String> createStory({
    required String mediaType,
    String? mediaUrl,
    String? textContent,
    String? backgroundColor,
    String? audioUrl,
    String? audioTitle,
    String? thumbnailUrl,
    int durationSec = 5,
    List<String>? mentionedUserIds,
  });
  
  Future<void> deleteStory(String storyId);
  
  // Fetch stories
  Future<List<StoryRingModel>> getStoryRings();
  Future<List<StoryModel>> getUserStories(String userId);
  Future<List<StoryModel>> getMyStories();
  Future<StoryModel?> getStory(String storyId);
  
  // Story interactions
  Future<void> viewStory(String storyId);
  Future<void> likeStory(String storyId);
  Future<void> unlikeStory(String storyId);
  Future<void> reactToStory(String storyId, String reaction);
  
  // Story replies
  Future<void> replyToStory({
    required String storyId,
    required String message,
  });
  Future<List<StoryReplyModel>> getStoryReplies(String storyId);
  
  // Story viewers
  Future<List<StoryViewerModel>> getStoryViewers(String storyId);
  
  // Story settings
  Future<void> muteUserStories(String userId);
  Future<void> unmuteUserStories(String userId);
  Future<void> hideStory(String storyId, String userId);
  
  // Archive and highlights
  Future<List<StoryModel>> getArchivedStories();
  Future<void> archiveStory(String storyId);
  Future<void> unarchiveStory(String storyId);
  Future<void> addToHighlight(String storyId, String highlightId);
  Future<void> removeFromHighlight(String storyId, String highlightId);
  
  // Story cleanup (remove expired stories)
  Future<void> cleanupExpiredStories();
  
  // Real-time streams
  Stream<List<StoryRingModel>> storyRingsStream();
  Stream<List<StoryModel>> userStoriesStream(String userId);
  Stream<List<StoryViewerModel>> storyViewersStream(String storyId);
  Stream<List<StoryReplyModel>> storyRepliesStream(String storyId);
}
