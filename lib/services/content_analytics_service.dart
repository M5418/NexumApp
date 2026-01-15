import 'package:flutter/foundation.dart';
import '../repositories/interfaces/monetization_repository.dart';
import '../repositories/models/monetization_models.dart';

/// Service for tracking content analytics and monetization metrics
class ContentAnalyticsService {
  final MonetizationRepository _monetizationRepo;

  // CPM rates per content type (USD per 1000 impressions)
  static const double postCpm = 2.50;
  static const double podcastCpm = 5.00;
  static const double bookCpm = 3.00;

  // Engagement value multipliers for earnings calculation
  static const double likeValue = 0.01;
  static const double commentValue = 0.05;
  static const double shareValue = 0.10;
  static const double bookmarkValue = 0.02;

  ContentAnalyticsService(this._monetizationRepo);

  /// Get CPM rate for content type
  double _getCPMRate(String contentType) {
    switch (contentType.toLowerCase()) {
      case 'podcast':
        return podcastCpm;
      case 'book':
        return bookCpm;
      case 'post':
      default:
        return postCpm;
    }
  }

  /// Calculate earnings from impressions using CPM
  double _calculateCPMEarnings(int impressions, String contentType) {
    final cpm = _getCPMRate(contentType);
    return (impressions / 1000.0) * cpm;
  }

  /// Calculate earnings from engagement
  double _calculateEngagementEarnings({
    int likes = 0,
    int comments = 0,
    int shares = 0,
    int bookmarks = 0,
  }) {
    return (likes * likeValue) +
        (comments * commentValue) +
        (shares * shareValue) +
        (bookmarks * bookmarkValue);
  }

  /// Track a view/impression for content
  Future<void> trackView({
    required String contentId,
    required String contentType,
    required String userId,
  }) async {
    // Validate IDs to prevent Firestore crash
    if (contentId.isEmpty || userId.isEmpty) {
      debugPrint('⚠️ trackView: skipping - empty contentId or userId');
      return;
    }
    try {
      // Update impressions count
      await _monetizationRepo.updateContentStats(
        contentId: contentId,
        contentType: contentType,
        userId: userId,
        impressions: 1,
      );

      // Calculate and record CPM earnings from this impression
      final cpmEarnings = _calculateCPMEarnings(1, contentType);
      if (cpmEarnings > 0) {
        await _recordEarnings(
          contentId: contentId,
          contentType: contentType,
          userId: userId,
          amount: cpmEarnings,
          source: 'ads',
        );
      }

      debugPrint('📊 Tracked view for $contentType $contentId');
    } catch (e) {
      debugPrint('❌ Error tracking view: $e');
    }
  }

  /// Track a like
  Future<void> trackLike({
    required String contentId,
    required String contentType,
    required String userId,
  }) async {
    try {
      await _monetizationRepo.updateContentStats(
        contentId: contentId,
        contentType: contentType,
        userId: userId,
        likes: 1,
      );

      // Record engagement earnings
      await _recordEarnings(
        contentId: contentId,
        contentType: contentType,
        userId: userId,
        amount: likeValue,
        source: 'engagement',
      );

      debugPrint('👍 Tracked like for $contentType $contentId');
    } catch (e) {
      debugPrint('❌ Error tracking like: $e');
    }
  }

  /// Track a comment
  Future<void> trackComment({
    required String contentId,
    required String contentType,
    required String userId,
  }) async {
    try {
      await _monetizationRepo.updateContentStats(
        contentId: contentId,
        contentType: contentType,
        userId: userId,
        comments: 1,
      );

      // Record engagement earnings
      await _recordEarnings(
        contentId: contentId,
        contentType: contentType,
        userId: userId,
        amount: commentValue,
        source: 'engagement',
      );

      debugPrint('💬 Tracked comment for $contentType $contentId');
    } catch (e) {
      debugPrint('❌ Error tracking comment: $e');
    }
  }

  /// Track a share
  Future<void> trackShare({
    required String contentId,
    required String contentType,
    required String userId,
  }) async {
    try {
      await _monetizationRepo.updateContentStats(
        contentId: contentId,
        contentType: contentType,
        userId: userId,
        shares: 1,
      );

      // Record engagement earnings
      await _recordEarnings(
        contentId: contentId,
        contentType: contentType,
        userId: userId,
        amount: shareValue,
        source: 'engagement',
      );

      debugPrint('🔗 Tracked share for $contentType $contentId');
    } catch (e) {
      debugPrint('❌ Error tracking share: $e');
    }
  }

  /// Track a bookmark
  Future<void> trackBookmark({
    required String contentId,
    required String contentType,
    required String userId,
  }) async {
    try {
      await _monetizationRepo.updateContentStats(
        contentId: contentId,
        contentType: contentType,
        userId: userId,
        bookmarks: 1,
      );

      // Record engagement earnings
      await _recordEarnings(
        contentId: contentId,
        contentType: contentType,
        userId: userId,
        amount: bookmarkValue,
        source: 'engagement',
      );

      debugPrint('🔖 Tracked bookmark for $contentType $contentId');
    } catch (e) {
      debugPrint('❌ Error tracking bookmark: $e');
    }
  }

  /// Record earnings from content
  Future<void> _recordEarnings({
    required String contentId,
    required String contentType,
    required String userId,
    required double amount,
    required String source,
  }) async {
    if (contentId.isEmpty || userId.isEmpty) return;
    try {
      final earning = Earning(
        id: '', // Will be set by repo
        userId: userId,
        contentId: contentId,
        contentType: contentType,
        source: source,
        amount: amount,
        status: 'pending',
        earnedAt: DateTime.now(),
      );

      await _monetizationRepo.recordEarning(earning);

      // Also update the content stats earnings
      await _monetizationRepo.updateContentStats(
        contentId: contentId,
        contentType: contentType,
        userId: userId,
        earnings: amount,
      );
    } catch (e) {
      debugPrint('❌ Error recording earnings: $e');
    }
  }

  /// Initialize analytics for new content
  Future<void> initializeContentStats({
    required String contentId,
    required String contentType,
    required String userId,
  }) async {
    try {
      await _monetizationRepo.updateContentStats(
        contentId: contentId,
        contentType: contentType,
        userId: userId,
        impressions: 0,
        likes: 0,
        comments: 0,
        shares: 0,
        bookmarks: 0,
        earnings: 0.0,
      );
      debugPrint('✅ Initialized stats for $contentType $contentId');
    } catch (e) {
      debugPrint('❌ Error initializing content stats: $e');
    }
  }

  /// Batch update stats from existing post data
  Future<void> syncPostStats({
    required String postId,
    required String authorId,
    required int likesCount,
    required int commentsCount,
    required int sharesCount,
    required int bookmarksCount,
    required int viewsCount,
  }) async {
    try {
      // Calculate total earnings
      final cpmEarnings = _calculateCPMEarnings(viewsCount, 'post');
      final engagementEarnings = _calculateEngagementEarnings(
        likes: likesCount,
        comments: commentsCount,
        shares: sharesCount,
        bookmarks: bookmarksCount,
      );
      final totalEarnings = cpmEarnings + engagementEarnings;

      // Update all stats at once
      await _monetizationRepo.updateContentStats(
        contentId: postId,
        contentType: 'post',
        userId: authorId,
        impressions: viewsCount,
        likes: likesCount,
        comments: commentsCount,
        shares: sharesCount,
        bookmarks: bookmarksCount,
        earnings: totalEarnings,
      );

      debugPrint('✅ Synced stats for post $postId - \$$totalEarnings');
    } catch (e) {
      debugPrint('❌ Error syncing post stats: $e');
    }
  }

  /// Batch update stats from existing podcast data
  Future<void> syncPodcastStats({
    required String podcastId,
    required String authorId,
    required int likesCount,
    required int commentsCount,
    required int sharesCount,
    required int bookmarksCount,
    required int playsCount,
  }) async {
    try {
      // Calculate total earnings
      final cpmEarnings = _calculateCPMEarnings(playsCount, 'podcast');
      final engagementEarnings = _calculateEngagementEarnings(
        likes: likesCount,
        comments: commentsCount,
        shares: sharesCount,
        bookmarks: bookmarksCount,
      );
      final totalEarnings = cpmEarnings + engagementEarnings;

      // Update all stats at once
      await _monetizationRepo.updateContentStats(
        contentId: podcastId,
        contentType: 'podcast',
        userId: authorId,
        impressions: playsCount,
        likes: likesCount,
        comments: commentsCount,
        shares: sharesCount,
        bookmarks: bookmarksCount,
        earnings: totalEarnings,
      );

      debugPrint('✅ Synced stats for podcast $podcastId - \$$totalEarnings');
    } catch (e) {
      debugPrint('❌ Error syncing podcast stats: $e');
    }
  }
}
