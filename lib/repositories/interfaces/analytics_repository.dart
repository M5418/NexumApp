import 'dart:async';

abstract class AnalyticsRepository {
  // Get user analytics with real-time updates
  Stream<UserAnalytics> userAnalyticsStream({required String uid, required Period period});
  
  // Get performance metrics
  Future<PerformanceMetrics> getPerformanceMetrics({
    required String uid,
    required Period period,
  });
  
  // Get activity timeline
  Future<List<ActivityData>> getActivityTimeline({
    required String uid,
    required Period period,
  });
  
  // Get followers overview by location
  Future<Map<String, LocationData>> getFollowersOverview({required String uid});
  
  // Get post activity calendar
  Future<Map<String, int>> getPostActivityCalendar({
    required String uid,
    required Period period,
  });
  
  // Get top posts
  Future<List<TopPostData>> getTopPosts({
    required String uid,
    required int limit,
    required SortBy sortBy,
  });
  
  // Real-time updates on post changes
  Stream<PerformanceMetrics> performanceMetricsStream({
    required String uid,
    required Period period,
  });
}

enum Period { weekly, monthly, yearly }
enum SortBy { views, likes, comments, shares }

class UserAnalytics {
  final PerformanceMetrics performance;
  final List<ActivityData> activityTimeline;
  final Map<String, LocationData> followersOverview;
  final Map<String, int> postActivityCalendar;
  final List<TopPostData> topPosts;
  final DateTime lastUpdated;

  UserAnalytics({
    required this.performance,
    required this.activityTimeline,
    required this.followersOverview,
    required this.postActivityCalendar,
    required this.topPosts,
    required this.lastUpdated,
  });
}

class PerformanceMetrics {
  final int totalViews;
  final int totalComments;
  final int totalLikes;
  final int totalShares;
  final double viewsChange; // percentage change
  final double commentsChange;
  final double likesChange;
  final double sharesChange;

  PerformanceMetrics({
    required this.totalViews,
    required this.totalComments,
    required this.totalLikes,
    required this.totalShares,
    this.viewsChange = 0.0,
    this.commentsChange = 0.0,
    this.likesChange = 0.0,
    this.sharesChange = 0.0,
  });
}

class ActivityData {
  final DateTime date;
  final int views;
  final int likes;
  final int comments;
  final int posts;

  ActivityData({
    required this.date,
    required this.views,
    required this.likes,
    required this.comments,
    required this.posts,
  });
}

class LocationData {
  final String country;
  final String flag;
  final int count;
  final double percentage;

  LocationData({
    required this.country,
    required this.flag,
    required this.count,
    required this.percentage,
  });
}

class TopPostData {
  final String postId;
  final String text;
  final List<String> mediaUrls;
  final int views;
  final int likes;
  final int comments;
  final int shares;
  final DateTime createdAt;

  TopPostData({
    required this.postId,
    required this.text,
    required this.mediaUrls,
    required this.views,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.createdAt,
  });
}
