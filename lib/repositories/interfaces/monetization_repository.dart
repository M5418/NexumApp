import '../models/monetization_models.dart';

abstract class MonetizationRepository {
  // ============ Monetization Profile ============
  
  /// Get user's monetization profile
  Future<MonetizationProfile?> getMonetizationProfile(String userId);
  
  /// Create or update monetization profile
  Future<void> updateMonetizationProfile(MonetizationProfile profile);
  
  /// Check and update eligibility requirements
  Future<void> checkEligibilityRequirements(String userId);
  
  /// Stream monetization profile changes
  Stream<MonetizationProfile?> monetizationProfileStream(String userId);
  
  // ============ Earnings ============
  
  /// Get earnings summary for user
  Future<EarningsSummary> getEarningsSummary(String userId);
  
  /// Get earnings for a specific period
  Future<List<Earning>> getEarnings({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int limit = 100,
  });
  
  /// Record an earning
  Future<void> recordEarning(Earning earning);
  
  /// Stream earnings summary
  Stream<EarningsSummary> earningsSummaryStream(String userId);
  
  // ============ Payouts ============
  
  /// Request a payout
  Future<String> requestPayout({
    required String userId,
    required double amount,
    required String method,
  });
  
  /// Get payout history
  Future<List<Payout>> getPayouts(String userId, {int limit = 50});
  
  /// Update payout status (admin)
  Future<void> updatePayoutStatus(String payoutId, String status, {String? transactionId, String? failureReason});
  
  // ============ Premium Subscriptions ============
  
  /// Get user's active subscription
  Future<PremiumSubscription?> getActiveSubscription(String userId);
  
  /// Create subscription
  Future<String> createSubscription(PremiumSubscription subscription);
  
  /// Cancel subscription
  Future<void> cancelSubscription(String subscriptionId);
  
  /// Check if user is premium
  Future<bool> isPremiumUser(String userId);
  
  /// Stream premium status
  Stream<bool> premiumStatusStream(String userId);
  
  // ============ Content Analytics ============
  
  /// Get content monetization stats
  Future<List<ContentMonetizationStats>> getContentStats({
    required String userId,
    String? contentType,
    DateTime? startDate,
    DateTime? endDate,
    String sortBy = 'totalEarnings',
    int limit = 50,
  });
  
  /// Update content stats (called when engagement happens)
  Future<void> updateContentStats({
    required String contentId,
    required String contentType,
    required String userId,
    int? impressions,
    int? likes,
    int? comments,
    int? shares,
    int? bookmarks,
    double? earnings,
  });
  
  /// Get revenue trend data
  Future<Map<String, double>> getRevenueTrend({
    required String userId,
    required int days,
  });
}
