import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../interfaces/analytics_repository.dart';

class FirebaseAnalyticsRepository implements AnalyticsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DateTime _getStartDate(Period period) {
    final now = DateTime.now();
    switch (period) {
      case Period.weekly:
        return now.subtract(const Duration(days: 7));
      case Period.monthly:
        return now.subtract(const Duration(days: 30));
      case Period.yearly:
        return now.subtract(const Duration(days: 365));
    }
  }

  DateTime _getPreviousStartDate(Period period) {
    final now = DateTime.now();
    switch (period) {
      case Period.weekly:
        return now.subtract(const Duration(days: 14));
      case Period.monthly:
        return now.subtract(const Duration(days: 60));
      case Period.yearly:
        return now.subtract(const Duration(days: 730));
    }
  }

  @override
  Stream<UserAnalytics> userAnalyticsStream({
    required String uid,
    required Period period,
  }) async* {
    // This stream will emit whenever any relevant data changes
    await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
      final performance = await getPerformanceMetrics(uid: uid, period: period);
      final activityTimeline = await getActivityTimeline(uid: uid, period: period);
      final followersOverview = await getFollowersOverview(uid: uid);
      final postActivityCalendar = await getPostActivityCalendar(uid: uid, period: period);
      final topPosts = await getTopPosts(uid: uid, limit: 5, sortBy: SortBy.views);

      yield UserAnalytics(
        performance: performance,
        activityTimeline: activityTimeline,
        followersOverview: followersOverview,
        postActivityCalendar: postActivityCalendar,
        topPosts: topPosts,
        lastUpdated: DateTime.now(),
      );
    }
  }

  @override
  Stream<PerformanceMetrics> performanceMetricsStream({
    required String uid,
    required Period period,
  }) async* {
    // Real-time updates when posts change
    final startDate = _getStartDate(period);
    
    await for (final _ in _db
        .collection('posts')
        .where('authorId', isEqualTo: uid)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .snapshots()) {
      
      yield await getPerformanceMetrics(uid: uid, period: period);
    }
  }

  @override
  Future<PerformanceMetrics> getPerformanceMetrics({
    required String uid,
    required Period period,
  }) async {
    final startDate = _getStartDate(period);
    final previousStartDate = _getPreviousStartDate(period);

    // First check: how many total posts does this user have?
    final allUserPosts = await _db
        .collection('posts')
        .where('authorId', isEqualTo: uid)
        .get();
    
    // Get current period posts
    final currentPosts = await _db
        .collection('posts')
        .where('authorId', isEqualTo: uid)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .get();
    
    // If no posts in period, but user has posts, use all posts
    final postsToAnalyze = currentPosts.docs.isEmpty && allUserPosts.docs.isNotEmpty 
        ? allUserPosts 
        : currentPosts;

    // Get previous period posts for comparison
    final previousPosts = await _db
        .collection('posts')
        .where('authorId', isEqualTo: uid)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(previousStartDate))
        .where('createdAt', isLessThan: Timestamp.fromDate(startDate))
        .get();

    // Calculate current metrics
    int totalViews = 0, totalComments = 0, totalLikes = 0, totalShares = 0;
    for (final doc in postsToAnalyze.docs) {
      final summary = doc.data()['summary'] as Map<String, dynamic>?;
      if (summary != null) {
        totalViews += (summary['views'] as int?) ?? 0;
        totalComments += (summary['comments'] as int?) ?? 0;
        totalLikes += (summary['likes'] as int?) ?? 0;
        totalShares += (summary['reposts'] as int?) ?? 0;
      }
    }

    // Calculate previous metrics
    int prevViews = 0, prevComments = 0, prevLikes = 0, prevShares = 0;
    for (final doc in previousPosts.docs) {
      final summary = doc.data()['summary'] as Map<String, dynamic>?;
      if (summary != null) {
        prevViews += (summary['views'] as int?) ?? 0;
        prevComments += (summary['comments'] as int?) ?? 0;
        prevLikes += (summary['likes'] as int?) ?? 0;
        prevShares += (summary['reposts'] as int?) ?? 0;
      }
    }

    // Calculate percentage changes
    double calculateChange(int current, int previous) {
      if (previous == 0) return current > 0 ? 100.0 : 0.0;
      return ((current - previous) / previous) * 100;
    }

    return PerformanceMetrics(
      totalViews: totalViews,
      totalComments: totalComments,
      totalLikes: totalLikes,
      totalShares: totalShares,
      viewsChange: calculateChange(totalViews, prevViews),
      commentsChange: calculateChange(totalComments, prevComments),
      likesChange: calculateChange(totalLikes, prevLikes),
      sharesChange: calculateChange(totalShares, prevShares),
    );
  }

  @override
  Future<List<ActivityData>> getActivityTimeline({
    required String uid,
    required Period period,
  }) async {
    final startDate = _getStartDate(period);
    
    final posts = await _db
        .collection('posts')
        .where('authorId', isEqualTo: uid)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .get();

    // Group by day
    final Map<String, ActivityData> dailyActivity = {};
    
    for (final doc in posts.docs) {
      final data = doc.data();
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final dateKey = DateTime(createdAt.year, createdAt.month, createdAt.day).toIso8601String();
      
      final summary = data['summary'] as Map<String, dynamic>?;
      final views = (summary?['views'] as int?) ?? 0;
      final likes = (summary?['likes'] as int?) ?? 0;
      final comments = (summary?['comments'] as int?) ?? 0;

      if (dailyActivity.containsKey(dateKey)) {
        final existing = dailyActivity[dateKey]!;
        dailyActivity[dateKey] = ActivityData(
          date: existing.date,
          views: existing.views + views,
          likes: existing.likes + likes,
          comments: existing.comments + comments,
          posts: existing.posts + 1,
        );
      } else {
        dailyActivity[dateKey] = ActivityData(
          date: DateTime(createdAt.year, createdAt.month, createdAt.day),
          views: views,
          likes: likes,
          comments: comments,
          posts: 1,
        );
      }
    }

    final activityList = dailyActivity.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return activityList;
  }

  @override
  Future<Map<String, LocationData>> getFollowersOverview({required String uid}) async {
    // Get followers
    final followersSnapshot = await _db
        .collection('follows')
        .where('followingId', isEqualTo: uid)
        .get();

    if (followersSnapshot.docs.isEmpty) {
      return {};
    }

    // Get follower user profiles to extract location data
    final followerIds = followersSnapshot.docs.map((d) => d.data()['followerId'] as String).toList();
    
    // Batch get user profiles (in chunks of 10 due to Firestore 'in' query limit)
    final Map<String, int> locationCounts = {};
    
    for (int i = 0; i < followerIds.length; i += 10) {
      final chunk = followerIds.skip(i).take(10).toList();
      final usersSnapshot = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final userDoc in usersSnapshot.docs) {
        final country = userDoc.data()['country'] as String? ?? 'Unknown';
        locationCounts[country] = (locationCounts[country] ?? 0) + 1;
      }
    }

    final totalFollowers = followerIds.length;
    
    // Convert to LocationData and get top locations
    final Map<String, LocationData> result = {};
    final sortedEntries = locationCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Take top 5 locations
    for (final entry in sortedEntries.take(5)) {
      result[entry.key] = LocationData(
        country: entry.key,
        flag: _getCountryFlag(entry.key),
        count: entry.value,
        percentage: totalFollowers > 0 ? entry.value / totalFollowers : 0.0,
      );
    }

    return result;
  }

  String _getCountryFlag(String country) {
    final countryFlags = {
      'United States': '🇺🇸',
      'Canada': '🇨🇦',
      'United Kingdom': '🇬🇧',
      'France': '🇫🇷',
      'Germany': '🇩🇪',
      'Spain': '🇪🇸',
      'Italy': '🇮🇹',
      'Japan': '🇯🇵',
      'South Korea': '🇰🇷',
      'Brazil': '🇧🇷',
      'Mexico': '🇲🇽',
      'India': '🇮🇳',
      'Australia': '🇦🇺',
      'China': '🇨🇳',
      'Russia': '🇷🇺',
    };
    return countryFlags[country] ?? '🌍';
  }

  @override
  Future<Map<String, int>> getPostActivityCalendar({
    required String uid,
    required Period period,
  }) async {
    final startDate = _getStartDate(period);
    final posts = await _db
        .collection('posts')
        .where('authorId', isEqualTo: uid)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .get();

    final Map<String, int> calendar = {};
    
    for (final doc in posts.docs) {
      final createdAt = (doc.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final dateKey = DateTime(createdAt.year, createdAt.month, createdAt.day).toIso8601String();
      calendar[dateKey] = (calendar[dateKey] ?? 0) + 1;
    }

    return calendar;
  }

  @override
  Future<List<TopPostData>> getTopPosts({
    required String uid,
    required int limit,
    required SortBy sortBy,
  }) async {
    // Get all user posts (we'll sort in memory for better flexibility)
    final postsSnapshot = await _db
        .collection('posts')
        .where('authorId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(100) // Get last 100 posts
        .get();

    final List<TopPostData> topPosts = [];

    for (final doc in postsSnapshot.docs) {
      final data = doc.data();
      final summary = data['summary'] as Map<String, dynamic>?;
      
      topPosts.add(TopPostData(
        postId: doc.id,
        text: data['text'] as String? ?? '',
        mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
        views: (summary?['views'] as int?) ?? 0,
        likes: (summary?['likes'] as int?) ?? 0,
        comments: (summary?['comments'] as int?) ?? 0,
        shares: (summary?['reposts'] as int?) ?? 0,
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ));
    }

    // Sort based on criteria
    switch (sortBy) {
      case SortBy.views:
        topPosts.sort((a, b) => b.views.compareTo(a.views));
        break;
      case SortBy.likes:
        topPosts.sort((a, b) => b.likes.compareTo(a.likes));
        break;
      case SortBy.comments:
        topPosts.sort((a, b) => b.comments.compareTo(a.comments));
        break;
      case SortBy.shares:
        topPosts.sort((a, b) => b.shares.compareTo(a.shares));
        break;
    }

    return topPosts.take(limit).toList();
  }
}
