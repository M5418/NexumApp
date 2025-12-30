import 'dart:async';

// Model classes
class PodcastModel {
  final String id;
  final String title;
  final String? author;
  final String? authorId;
  final String? description;
  final String? coverUrl;
  final String? coverThumbUrl; // Small thumbnail for fast list loading
  final String? audioUrl;
  final int? durationSec;
  final String? language;
  final String? category;
  final List<String> tags;
  final bool isPublished;
  final int playCount;
  final int likeCount;
  final double rating;
  final int reviewCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isLiked;
  final bool isBookmarked;
  final bool isSubscribed;
  
  PodcastModel({
    required this.id,
    required this.title,
    this.author,
    this.authorId,
    this.description,
    this.coverUrl,
    this.coverThumbUrl,
    this.audioUrl,
    this.durationSec,
    this.language,
    this.category,
    required this.tags,
    required this.isPublished,
    required this.playCount,
    required this.likeCount,
    required this.rating,
    required this.reviewCount,
    required this.createdAt,
    required this.updatedAt,
    required this.isLiked,
    required this.isBookmarked,
    required this.isSubscribed,
  });
}

class PodcastCategoryModel {
  final String id;
  final String name;
  final String? icon;
  final String? description;
  final int podcastCount;
  
  PodcastCategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.description,
    required this.podcastCount,
  });
}

class PodcastEpisodeModel {
  final String id;
  final String podcastId;
  final String title;
  final String? description;
  final String audioUrl;
  final int durationSec;
  final int episodeNumber;
  final DateTime publishedAt;
  final int playCount;
  final bool isPlayed;
  
  PodcastEpisodeModel({
    required this.id,
    required this.podcastId,
    required this.title,
    this.description,
    required this.audioUrl,
    required this.durationSec,
    required this.episodeNumber,
    required this.publishedAt,
    required this.playCount,
    required this.isPlayed,
  });
}

class PodcastProgressModel {
  final String podcastId;
  final String? episodeId;
  final String userId;
  final Duration currentPosition;
  final Duration totalDuration;
  final double progressPercent;
  final DateTime lastPlayedAt;
  
  PodcastProgressModel({
    required this.podcastId,
    this.episodeId,
    required this.userId,
    required this.currentPosition,
    required this.totalDuration,
    required this.progressPercent,
    required this.lastPlayedAt,
  });
}

// Repository interface
abstract class PodcastRepository {
  // Podcast CRUD
  Future<List<PodcastModel>> listPodcasts({
    int page = 1,
    int limit = 20,
    String? authorId,
    String? category,
    String? query,
    bool? isPublished,
    bool mine = false,
  });
  
  Future<PodcastModel?> getPodcast(String podcastId);
  
  Future<String> createPodcast({
    required String title,
    String? author,
    String? description,
    String? coverUrl,
    String? coverThumbUrl,
    String? audioUrl,
    int? durationSec,
    String? language,
    String? category,
    List<String>? tags,
    bool isPublished = false,
  });
  
  Future<void> updatePodcast(
    String podcastId, {
    String? title,
    String? author,
    String? description,
    String? coverUrl,
    String? audioUrl,
    int? durationSec,
    String? language,
    String? category,
    List<String>? tags,
    bool? isPublished,
  });
  
  Future<void> deletePodcast(String podcastId);
  
  // Episodes (for series podcasts)
  Future<List<PodcastEpisodeModel>> getEpisodes(String podcastId);
  Future<String> createEpisode({
    required String podcastId,
    required String title,
    String? description,
    required String audioUrl,
    required int durationSec,
  });
  Future<void> deleteEpisode(String episodeId);
  
  // Podcast interactions
  Future<void> likePodcast(String podcastId);
  Future<void> unlikePodcast(String podcastId);
  Future<void> bookmarkPodcast(String podcastId);
  Future<void> unbookmarkPodcast(String podcastId);
  Future<void> subscribeToPodcast(String podcastId);
  Future<void> unsubscribeFromPodcast(String podcastId);
  
  // Play tracking
  Future<void> recordPlay(String podcastId, {String? episodeId});
  Future<PodcastProgressModel?> getProgress(String podcastId, {String? episodeId});
  Future<void> updateProgress({
    required String podcastId,
    String? episodeId,
    required Duration currentPosition,
  });
  
  // Categories
  Future<List<PodcastCategoryModel>> getCategories();
  
  // Search and recommendations
  Future<List<PodcastModel>> searchPodcasts(String query);
  Future<List<PodcastModel>> getTrending();
  Future<List<PodcastModel>> getRecommendations();
  Future<List<PodcastModel>> getBookmarkedPodcasts();
  Future<List<PodcastModel>> getSubscribedPodcasts();
  Future<List<PodcastModel>> getRecentlyPlayed();
  
  // Real-time streams
  Stream<PodcastModel?> podcastStream(String podcastId);
  Stream<PodcastProgressModel?> progressStream(String podcastId, {String? episodeId});
  Stream<List<PodcastModel>> subscribedPodcastsStream();
}
