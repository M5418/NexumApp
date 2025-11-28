import 'package:cloud_firestore/cloud_firestore.dart';

/// User's monetization eligibility and settings
class MonetizationProfile {
  final String userId;
  final bool isEligible;
  final bool isContentMonetized;
  final bool isAdsEnabled;
  final bool isSponsorshipsEnabled;
  final String? payoutMethod; // 'stripe', 'paypal', etc.
  final String? payoutAccountId;
  final DateTime? eligibleSince;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Requirements status
  final bool hasMinFollowers;
  final bool hasMinPosts;
  final bool isKycVerified;
  final bool has2FA;

  MonetizationProfile({
    required this.userId,
    this.isEligible = false,
    this.isContentMonetized = false,
    this.isAdsEnabled = false,
    this.isSponsorshipsEnabled = false,
    this.payoutMethod,
    this.payoutAccountId,
    this.eligibleSince,
    required this.createdAt,
    required this.updatedAt,
    this.hasMinFollowers = false,
    this.hasMinPosts = false,
    this.isKycVerified = false,
    this.has2FA = false,
  });

  factory MonetizationProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    DateTime? ts(v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }
    
    return MonetizationProfile(
      userId: doc.id,
      isEligible: d['isEligible'] ?? false,
      isContentMonetized: d['isContentMonetized'] ?? false,
      isAdsEnabled: d['isAdsEnabled'] ?? false,
      isSponsorshipsEnabled: d['isSponsorshipsEnabled'] ?? false,
      payoutMethod: d['payoutMethod'],
      payoutAccountId: d['payoutAccountId'],
      eligibleSince: ts(d['eligibleSince']),
      createdAt: ts(d['createdAt']) ?? DateTime.now(),
      updatedAt: ts(d['updatedAt']) ?? DateTime.now(),
      hasMinFollowers: d['hasMinFollowers'] ?? false,
      hasMinPosts: d['hasMinPosts'] ?? false,
      isKycVerified: d['isKycVerified'] ?? false,
      has2FA: d['has2FA'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'isEligible': isEligible,
      'isContentMonetized': isContentMonetized,
      'isAdsEnabled': isAdsEnabled,
      'isSponsorshipsEnabled': isSponsorshipsEnabled,
      'payoutMethod': payoutMethod,
      'payoutAccountId': payoutAccountId,
      'eligibleSince': eligibleSince?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'hasMinFollowers': hasMinFollowers,
      'hasMinPosts': hasMinPosts,
      'isKycVerified': isKycVerified,
      'has2FA': has2FA,
    };
  }
}

/// Earnings record for a specific content item or period
class Earning {
  final String id;
  final String userId;
  final String? contentId; // post/podcast/book ID
  final String? contentType; // 'post', 'podcast', 'book'
  final String source; // 'ads', 'subscription', 'sponsorship', 'tip'
  final double amount; // USD
  final String status; // 'pending', 'processing', 'paid', 'failed'
  final DateTime earnedAt;
  final DateTime? paidAt;
  final String? transactionId;

  Earning({
    required this.id,
    required this.userId,
    this.contentId,
    this.contentType,
    required this.source,
    required this.amount,
    this.status = 'pending',
    required this.earnedAt,
    this.paidAt,
    this.transactionId,
  });

  factory Earning.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    DateTime? ts(v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }
    
    return Earning(
      id: doc.id,
      userId: d['userId'] ?? '',
      contentId: d['contentId'],
      contentType: d['contentType'],
      source: d['source'] ?? 'ads',
      amount: (d['amount'] ?? 0).toDouble(),
      status: d['status'] ?? 'pending',
      earnedAt: ts(d['earnedAt']) ?? DateTime.now(),
      paidAt: ts(d['paidAt']),
      transactionId: d['transactionId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'contentId': contentId,
      'contentType': contentType,
      'source': source,
      'amount': amount,
      'status': status,
      'earnedAt': earnedAt.toIso8601String(),
      'paidAt': paidAt?.toIso8601String(),
      'transactionId': transactionId,
    };
  }
}

/// Payout request/record
class Payout {
  final String id;
  final String userId;
  final double amount; // USD
  final String method; // 'stripe', 'paypal'
  final String status; // 'requested', 'processing', 'completed', 'failed'
  final DateTime requestedAt;
  final DateTime? completedAt;
  final String? transactionId;
  final String? failureReason;

  Payout({
    required this.id,
    required this.userId,
    required this.amount,
    required this.method,
    this.status = 'requested',
    required this.requestedAt,
    this.completedAt,
    this.transactionId,
    this.failureReason,
  });

  factory Payout.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    DateTime? ts(v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }
    
    return Payout(
      id: doc.id,
      userId: d['userId'] ?? '',
      amount: (d['amount'] ?? 0).toDouble(),
      method: d['method'] ?? 'stripe',
      status: d['status'] ?? 'requested',
      requestedAt: ts(d['requestedAt']) ?? DateTime.now(),
      completedAt: ts(d['completedAt']),
      transactionId: d['transactionId'],
      failureReason: d['failureReason'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'amount': amount,
      'method': method,
      'status': status,
      'requestedAt': requestedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'transactionId': transactionId,
      'failureReason': failureReason,
    };
  }
}

/// Premium subscription record
class PremiumSubscription {
  final String id;
  final String userId;
  final String planType; // 'monthly', 'yearly'
  final double amount; // USD
  final String status; // 'active', 'cancelled', 'expired', 'payment_failed'
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? nextBillingDate;
  final String? paymentMethod;
  final String? subscriptionId; // Stripe/external subscription ID
  final bool autoRenew;

  PremiumSubscription({
    required this.id,
    required this.userId,
    required this.planType,
    required this.amount,
    this.status = 'active',
    required this.startDate,
    this.endDate,
    this.nextBillingDate,
    this.paymentMethod,
    this.subscriptionId,
    this.autoRenew = true,
  });

  factory PremiumSubscription.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    DateTime? ts(v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }
    
    return PremiumSubscription(
      id: doc.id,
      userId: d['userId'] ?? '',
      planType: d['planType'] ?? 'monthly',
      amount: (d['amount'] ?? 0).toDouble(),
      status: d['status'] ?? 'active',
      startDate: ts(d['startDate']) ?? DateTime.now(),
      endDate: ts(d['endDate']),
      nextBillingDate: ts(d['nextBillingDate']),
      paymentMethod: d['paymentMethod'],
      subscriptionId: d['subscriptionId'],
      autoRenew: d['autoRenew'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'planType': planType,
      'amount': amount,
      'status': status,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'nextBillingDate': nextBillingDate?.toIso8601String(),
      'paymentMethod': paymentMethod,
      'subscriptionId': subscriptionId,
      'autoRenew': autoRenew,
    };
  }

  bool get isActive => status == 'active' && (endDate == null || endDate!.isAfter(DateTime.now()));
}

/// Summary of earnings for quick access
class EarningsSummary {
  final String userId;
  final double thisMonth;
  final double pending;
  final double lifetime;
  final DateTime lastUpdated;

  EarningsSummary({
    required this.userId,
    this.thisMonth = 0.0,
    this.pending = 0.0,
    this.lifetime = 0.0,
    required this.lastUpdated,
  });

  factory EarningsSummary.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    DateTime? ts(v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }
    
    return EarningsSummary(
      userId: doc.id,
      thisMonth: (d['thisMonth'] ?? 0).toDouble(),
      pending: (d['pending'] ?? 0).toDouble(),
      lifetime: (d['lifetime'] ?? 0).toDouble(),
      lastUpdated: ts(d['lastUpdated']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'thisMonth': thisMonth,
      'pending': pending,
      'lifetime': lifetime,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

/// Content analytics for monetization
class ContentMonetizationStats {
  final String contentId;
  final String contentType;
  final String userId;
  final double totalEarnings;
  final int impressions;
  final int likes;
  final int comments;
  final int shares;
  final int bookmarks;
  final DateTime createdAt;
  final DateTime lastUpdated;

  ContentMonetizationStats({
    required this.contentId,
    required this.contentType,
    required this.userId,
    this.totalEarnings = 0.0,
    this.impressions = 0,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.bookmarks = 0,
    required this.createdAt,
    required this.lastUpdated,
  });

  factory ContentMonetizationStats.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    DateTime? ts(v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v);
      return null;
    }
    
    return ContentMonetizationStats(
      contentId: doc.id,
      contentType: d['contentType'] ?? 'post',
      userId: d['userId'] ?? '',
      totalEarnings: (d['totalEarnings'] ?? 0).toDouble(),
      impressions: d['impressions'] ?? 0,
      likes: d['likes'] ?? 0,
      comments: d['comments'] ?? 0,
      shares: d['shares'] ?? 0,
      bookmarks: d['bookmarks'] ?? 0,
      createdAt: ts(d['createdAt']) ?? DateTime.now(),
      lastUpdated: ts(d['lastUpdated']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'contentId': contentId,
      'contentType': contentType,
      'userId': userId,
      'totalEarnings': totalEarnings,
      'impressions': impressions,
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'bookmarks': bookmarks,
      'createdAt': createdAt.toIso8601String(),
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  int get totalEngagement => likes + comments + shares + bookmarks;
}
