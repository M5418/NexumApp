import 'package:cloud_firestore/cloud_firestore.dart';

/// Media thumbnail for feed display (no HD loading needed)
class MediaThumb {
  final String type; // 'image' or 'video'
  final String thumbUrl;
  final double? aspectRatio;
  
  const MediaThumb({
    required this.type,
    required this.thumbUrl,
    this.aspectRatio,
  });
  
  factory MediaThumb.fromMap(Map<String, dynamic> map) {
    return MediaThumb(
      type: map['type'] ?? 'image',
      thumbUrl: map['thumbUrl'] ?? map['url'] ?? '',
      aspectRatio: (map['aspectRatio'] as num?)?.toDouble(),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'thumbUrl': thumbUrl,
      if (aspectRatio != null) 'aspectRatio': aspectRatio,
    };
  }
}

class PostModel {
  final String id;
  final String authorId;
  final String text;
  final List<String> mediaUrls;
  final PostSummary summary;
  final String? repostOf;
  final String? communityId;  // Community context for post
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // Denormalized author data for fast feed rendering (no N+1 queries)
  final String? authorName;
  final String? authorAvatarUrl;
  
  // Media thumbnails for feed (thumb only, no HD)
  final List<MediaThumb> mediaThumbs;
  
  // For pagination
  final DocumentSnapshot? snapshot;
  
  PostModel({
    required this.id,
    required this.authorId,
    required this.text,
    this.mediaUrls = const [],
    required this.summary,
    this.repostOf,
    this.communityId,
    required this.createdAt,
    this.updatedAt,
    this.authorName,
    this.authorAvatarUrl,
    this.mediaThumbs = const [],
    this.snapshot,
  });
  
  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse mediaThumbs if available
    List<MediaThumb> thumbs = [];
    if (data['mediaThumbs'] != null && data['mediaThumbs'] is List) {
      thumbs = (data['mediaThumbs'] as List)
          .map((t) => MediaThumb.fromMap(Map<String, dynamic>.from(t)))
          .toList();
    }
    
    return PostModel(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      text: data['text'] ?? '',
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      summary: PostSummary.fromMap(data['summary'] ?? {}),
      repostOf: data['repostOf'],
      communityId: data['communityId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      authorName: data['authorName'],
      authorAvatarUrl: data['authorAvatarUrl'],
      mediaThumbs: thumbs,
      snapshot: doc,
    );
  }
  
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'authorId': authorId,
      'text': text,
      'mediaUrls': mediaUrls,
      'summary': summary.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
    if (repostOf != null) map['repostOf'] = repostOf!;
    if (communityId != null) map['communityId'] = communityId!;
    if (updatedAt != null) map['updatedAt'] = Timestamp.fromDate(updatedAt!);
    if (authorName != null) map['authorName'] = authorName!;
    if (authorAvatarUrl != null) map['authorAvatarUrl'] = authorAvatarUrl!;
    if (mediaThumbs.isNotEmpty) {
      map['mediaThumbs'] = mediaThumbs.map((t) => t.toMap()).toList();
    }
    return map;
  }
  
  PostModel copyWith({
    String? id,
    String? authorId,
    String? text,
    List<String>? mediaUrls,
    PostSummary? summary,
    String? repostOf,
    String? communityId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? authorName,
    String? authorAvatarUrl,
    List<MediaThumb>? mediaThumbs,
    DocumentSnapshot? snapshot,
  }) {
    return PostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      text: text ?? this.text,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      summary: summary ?? this.summary,
      repostOf: repostOf ?? this.repostOf,
      communityId: communityId ?? this.communityId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      authorName: authorName ?? this.authorName,
      authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
      mediaThumbs: mediaThumbs ?? this.mediaThumbs,
      snapshot: snapshot ?? this.snapshot,
    );
  }
}

class PostSummary {
  final int likes;
  final int comments;
  final int shares;
  final int reposts;
  final int bookmarks;
  
  PostSummary({
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.reposts = 0,
    this.bookmarks = 0,
  });
  
  factory PostSummary.fromMap(Map<String, dynamic> map) {
    return PostSummary(
      likes: map['likes'] ?? 0,
      comments: map['comments'] ?? 0,
      shares: map['shares'] ?? 0,
      reposts: map['reposts'] ?? 0,
      bookmarks: map['bookmarks'] ?? 0,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'reposts': reposts,
      'bookmarks': bookmarks,
    };
  }
  
  PostSummary copyWith({
    int? likes,
    int? comments,
    int? shares,
    int? reposts,
    int? bookmarks,
  }) {
    return PostSummary(
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      reposts: reposts ?? this.reposts,
      bookmarks: bookmarks ?? this.bookmarks,
    );
  }
}
