import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../interfaces/monetization_repository.dart';
import '../models/monetization_models.dart';

class FirebaseMonetizationRepository implements MonetizationRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _monetizationProfiles =>
      _db.collection('monetization_profiles');
  CollectionReference<Map<String, dynamic>> get _earnings =>
      _db.collection('earnings');
  CollectionReference<Map<String, dynamic>> get _payouts =>
      _db.collection('payouts');
  CollectionReference<Map<String, dynamic>> get _subscriptions =>
      _db.collection('premium_subscriptions');
  CollectionReference<Map<String, dynamic>> get _earningsSummaries =>
      _db.collection('earnings_summaries');
  CollectionReference<Map<String, dynamic>> get _contentStats =>
      _db.collection('content_monetization_stats');
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  // ============ Monetization Profile ============

  @override
  Future<MonetizationProfile?> getMonetizationProfile(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final doc = await _monetizationProfiles.doc(userId).get();
      if (!doc.exists) return null;
      return MonetizationProfile.fromDoc(doc);
    } catch (e) {
      debugPrint('❌ Error getting monetization profile: $e');
      return null;
    }
  }

  @override
  Future<void> updateMonetizationProfile(MonetizationProfile profile) async {
    try {
      await _monetizationProfiles.doc(profile.userId).set(
        profile.toMap(),
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('❌ Error updating monetization profile: $e');
      rethrow;
    }
  }

  @override
  Future<void> checkEligibilityRequirements(String userId) async {
    if (userId.isEmpty) return;
    try {
      // Get user data
      final userDoc = await _users.doc(userId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final followersCount = userData['followersCount'] ?? 0;
      final postsCount = userData['postsCount'] ?? 0;

      // Check requirements
      final hasMinFollowers = followersCount >= 1000; // Example: 1000 followers
      final hasMinPosts = postsCount >= 10; // Example: 10 posts
      
      // Check KYC (would need to query kyc_requests)
      // For now, assume false
      final isKycVerified = false;
      
      // Check 2FA (would need to check auth settings)
      // For now, assume true if user exists
      final has2FA = true;

      final isEligible = hasMinFollowers && hasMinPosts && has2FA;

      // Update profile
      await _monetizationProfiles.doc(userId).set({
        'userId': userId,
        'hasMinFollowers': hasMinFollowers,
        'hasMinPosts': hasMinPosts,
        'isKycVerified': isKycVerified,
        'has2FA': has2FA,
        'isEligible': isEligible,
        'eligibleSince': isEligible ? FieldValue.serverTimestamp() : null,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('❌ Error checking eligibility: $e');
    }
  }

  @override
  Stream<MonetizationProfile?> monetizationProfileStream(String userId) {
    if (userId.isEmpty) return Stream.value(null);
    return _monetizationProfiles.doc(userId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return MonetizationProfile.fromDoc(doc);
    });
  }

  // ============ Earnings ============

  @override
  Future<EarningsSummary> getEarningsSummary(String userId) async {
    if (userId.isEmpty) {
      return EarningsSummary(userId: '', lastUpdated: DateTime.now());
    }
    try {
      final doc = await _earningsSummaries.doc(userId).get();
      if (doc.exists) {
        return EarningsSummary.fromDoc(doc);
      }

      // Calculate from scratch if summary doesn't exist
      final now = DateTime.now();
      final firstOfMonth = DateTime(now.year, now.month, 1);

      final allEarnings = await _earnings
          .where('userId', isEqualTo: userId)
          .get();

      double thisMonth = 0.0;
      double pending = 0.0;
      double lifetime = 0.0;

      for (final doc in allEarnings.docs) {
        final earning = Earning.fromDoc(doc);
        lifetime += earning.amount;
        
        if (earning.status == 'pending' || earning.status == 'processing') {
          pending += earning.amount;
        }
        
        if (earning.earnedAt.isAfter(firstOfMonth)) {
          thisMonth += earning.amount;
        }
      }

      final summary = EarningsSummary(
        userId: userId,
        thisMonth: thisMonth,
        pending: pending,
        lifetime: lifetime,
        lastUpdated: DateTime.now(),
      );

      // Save for future use
      await _earningsSummaries.doc(userId).set(summary.toMap());

      return summary;
    } catch (e) {
      debugPrint('❌ Error getting earnings summary: $e');
      return EarningsSummary(
        userId: userId,
        lastUpdated: DateTime.now(),
      );
    }
  }

  @override
  Future<List<Earning>> getEarnings({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    int limit = 100,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _earnings
          .where('userId', isEqualTo: userId)
          .orderBy('earnedAt', descending: true)
          .limit(limit);

      if (startDate != null) {
        query = query.where('earnedAt', isGreaterThanOrEqualTo: startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.where('earnedAt', isLessThanOrEqualTo: endDate.toIso8601String());
      }

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => Earning.fromDoc(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error getting earnings: $e');
      return [];
    }
  }

  @override
  Future<void> recordEarning(Earning earning) async {
    try {
      final docRef = _earnings.doc();
      final earningWithId = Earning(
        id: docRef.id,
        userId: earning.userId,
        contentId: earning.contentId,
        contentType: earning.contentType,
        source: earning.source,
        amount: earning.amount,
        status: earning.status,
        earnedAt: earning.earnedAt,
      );

      await docRef.set(earningWithId.toMap());
      
      // Note: Don't update earnings summary here - the current user may not have
      // permission to read another user's summary. Summaries are calculated
      // on-demand when the owner views their monetization page.
    } catch (e) {
      debugPrint('❌ Error recording earning: $e');
      rethrow;
    }
  }

  Future<void> _updateEarningsSummary(String userId) async {
    try {
      await getEarningsSummary(userId); // This recalculates and saves
    } catch (e) {
      debugPrint('❌ Error updating earnings summary: $e');
    }
  }

  @override
  Stream<EarningsSummary> earningsSummaryStream(String userId) {
    if (userId.isEmpty) {
      return Stream.value(EarningsSummary(userId: '', lastUpdated: DateTime.now()));
    }
    return _earningsSummaries.doc(userId).snapshots().handleError((error) {
      debugPrint('⚠️ earningsSummaryStream error (non-critical): $error');
      // Return empty summary on error - don't crash
    }).map((doc) {
      if (doc.exists) {
        return EarningsSummary.fromDoc(doc);
      }
      return EarningsSummary(userId: userId, lastUpdated: DateTime.now());
    });
  }

  // ============ Payouts ============

  @override
  Future<String> requestPayout({
    required String userId,
    required double amount,
    required String method,
  }) async {
    try {
      final docRef = _payouts.doc();
      final payout = Payout(
        id: docRef.id,
        userId: userId,
        amount: amount,
        method: method,
        status: 'requested',
        requestedAt: DateTime.now(),
      );

      await docRef.set(payout.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error requesting payout: $e');
      rethrow;
    }
  }

  @override
  Future<List<Payout>> getPayouts(String userId, {int limit = 50}) async {
    try {
      final snapshot = await _payouts
          .where('userId', isEqualTo: userId)
          .orderBy('requestedAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => Payout.fromDoc(doc)).toList();
    } catch (e) {
      debugPrint('❌ Error getting payouts: $e');
      return [];
    }
  }

  @override
  Future<void> updatePayoutStatus(
    String payoutId,
    String status, {
    String? transactionId,
    String? failureReason,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status == 'completed') {
        updates['completedAt'] = FieldValue.serverTimestamp();
      }

      if (transactionId != null) {
        updates['transactionId'] = transactionId;
      }

      if (failureReason != null) {
        updates['failureReason'] = failureReason;
      }

      await _payouts.doc(payoutId).update(updates);
    } catch (e) {
      debugPrint('❌ Error updating payout status: $e');
      rethrow;
    }
  }

  // ============ Premium Subscriptions ============

  @override
  Future<PremiumSubscription?> getActiveSubscription(String userId) async {
    try {
      final snapshot = await _subscriptions
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final sub = PremiumSubscription.fromDoc(snapshot.docs.first);
      return sub.isActive ? sub : null;
    } catch (e) {
      debugPrint('❌ Error getting active subscription: $e');
      return null;
    }
  }

  @override
  Future<String> createSubscription(PremiumSubscription subscription) async {
    try {
      final docRef = _subscriptions.doc();
      final subWithId = PremiumSubscription(
        id: docRef.id,
        userId: subscription.userId,
        planType: subscription.planType,
        amount: subscription.amount,
        status: subscription.status,
        startDate: subscription.startDate,
        endDate: subscription.endDate,
        nextBillingDate: subscription.nextBillingDate,
        paymentMethod: subscription.paymentMethod,
        subscriptionId: subscription.subscriptionId,
        autoRenew: subscription.autoRenew,
      );

      await docRef.set(subWithId.toMap());

      // Update user's premium status
      await _users.doc(subscription.userId).update({
        'isPremium': true,
        'premiumSince': FieldValue.serverTimestamp(),
      });

      return docRef.id;
    } catch (e) {
      debugPrint('❌ Error creating subscription: $e');
      rethrow;
    }
  }

  @override
  Future<void> cancelSubscription(String subscriptionId) async {
    try {
      final doc = await _subscriptions.doc(subscriptionId).get();
      if (!doc.exists) return;

      final sub = PremiumSubscription.fromDoc(doc);

      await _subscriptions.doc(subscriptionId).update({
        'status': 'cancelled',
        'autoRenew': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update user's premium status
      await _users.doc(sub.userId).update({
        'isPremium': false,
      });
    } catch (e) {
      debugPrint('❌ Error cancelling subscription: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isPremiumUser(String userId) async {
    if (userId.isEmpty) return false;
    try {
      final userDoc = await _users.doc(userId).get();
      if (!userDoc.exists) return false;
      
      final data = userDoc.data()!;
      return data['isPremium'] ?? false;
    } catch (e) {
      debugPrint('❌ Error checking premium status: $e');
      return false;
    }
  }

  @override
  Stream<bool> premiumStatusStream(String userId) {
    if (userId.isEmpty) return Stream.value(false);
    return _users.doc(userId).snapshots().map((doc) {
      if (!doc.exists) return false;
      final data = doc.data()!;
      return data['isPremium'] ?? false;
    });
  }

  // ============ Content Analytics ============

  @override
  Future<List<ContentMonetizationStats>> getContentStats({
    required String userId,
    String? contentType,
    DateTime? startDate,
    DateTime? endDate,
    String sortBy = 'totalEarnings',
    int limit = 50,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _contentStats
          .where('userId', isEqualTo: userId);

      if (contentType != null) {
        query = query.where('contentType', isEqualTo: contentType);
      }

      // Apply sorting
      final validSortFields = ['totalEarnings', 'impressions', 'likes', 'comments', 'shares'];
      final sortField = validSortFields.contains(sortBy) ? sortBy : 'totalEarnings';
      
      query = query.orderBy(sortField, descending: true).limit(limit);

      final snapshot = await query.get();
      List<ContentMonetizationStats> stats = snapshot.docs
          .map((doc) => ContentMonetizationStats.fromDoc(doc))
          .toList();

      // Filter by date if needed (client-side since Firestore has limitations)
      if (startDate != null) {
        stats = stats.where((s) => s.createdAt.isAfter(startDate)).toList();
      }
      if (endDate != null) {
        stats = stats.where((s) => s.createdAt.isBefore(endDate)).toList();
      }

      return stats;
    } catch (e) {
      debugPrint('❌ Error getting content stats: $e');
      // Fallback: try without ordering
      try {
        final snapshot = await _contentStats
            .where('userId', isEqualTo: userId)
            .limit(limit)
            .get();
        return snapshot.docs
            .map((doc) => ContentMonetizationStats.fromDoc(doc))
            .toList();
      } catch (fallbackError) {
        debugPrint('❌ Fallback also failed: $fallbackError');
        return [];
      }
    }
  }

  @override
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
  }) async {
    // Validate IDs to prevent Firestore crash with empty document references
    if (contentId.isEmpty || userId.isEmpty) {
      debugPrint('⚠️ updateContentStats: skipping - empty contentId or userId');
      return;
    }
    
    try {
      final docRef = _contentStats.doc(contentId);
      final doc = await docRef.get();

      if (doc.exists) {
        // Update existing stats
        final updates = <String, dynamic>{
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        if (impressions != null) updates['impressions'] = FieldValue.increment(impressions);
        if (likes != null) updates['likes'] = FieldValue.increment(likes);
        if (comments != null) updates['comments'] = FieldValue.increment(comments);
        if (shares != null) updates['shares'] = FieldValue.increment(shares);
        if (bookmarks != null) updates['bookmarks'] = FieldValue.increment(bookmarks);
        if (earnings != null) updates['totalEarnings'] = FieldValue.increment(earnings);

        await docRef.update(updates);
      } else {
        // Create new stats
        final stats = ContentMonetizationStats(
          contentId: contentId,
          contentType: contentType,
          userId: userId,
          impressions: impressions ?? 0,
          likes: likes ?? 0,
          comments: comments ?? 0,
          shares: shares ?? 0,
          bookmarks: bookmarks ?? 0,
          totalEarnings: earnings ?? 0.0,
          createdAt: DateTime.now(),
          lastUpdated: DateTime.now(),
        );

        await docRef.set(stats.toMap());
      }
    } catch (e) {
      debugPrint('❌ Error updating content stats: $e');
    }
  }

  @override
  Future<Map<String, double>> getRevenueTrend({
    required String userId,
    required int days,
  }) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));
      
      final earnings = await _earnings
          .where('userId', isEqualTo: userId)
          .where('earnedAt', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .orderBy('earnedAt')
          .get();

      // Group by date
      final Map<String, double> trend = {};
      
      for (final doc in earnings.docs) {
        final earning = Earning.fromDoc(doc);
        final dateKey = '${earning.earnedAt.year}-${earning.earnedAt.month.toString().padLeft(2, '0')}-${earning.earnedAt.day.toString().padLeft(2, '0')}';
        trend[dateKey] = (trend[dateKey] ?? 0.0) + earning.amount;
      }

      return trend;
    } catch (e) {
      debugPrint('❌ Error getting revenue trend: $e');
      return {};
    }
  }
}
