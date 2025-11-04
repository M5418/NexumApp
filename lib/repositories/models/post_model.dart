import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String id;
  final String authorId;
  final String text;
  final List<String> mediaUrls;
  final PostSummary summary;
  final String? repostOf;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  // For pagination
  final DocumentSnapshot? snapshot;
  
  PostModel({
    required this.id,
    required this.authorId,
    required this.text,
    this.mediaUrls = const [],
    required this.summary,
    this.repostOf,
    required this.createdAt,
    this.updatedAt,
    this.snapshot,
  });
  
  factory PostModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PostModel(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      text: data['text'] ?? '',
      mediaUrls: List<String>.from(data['mediaUrls'] ?? []),
      summary: PostSummary.fromMap(data['summary'] ?? {}),
      repostOf: data['repostOf'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      snapshot: doc,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'text': text,
      'mediaUrls': mediaUrls,
      'summary': summary.toMap(),
      'repostOf': repostOf,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }
  
  PostModel copyWith({
    String? id,
    String? authorId,
    String? text,
    List<String>? mediaUrls,
    PostSummary? summary,
    String? repostOf,
    DateTime? createdAt,
    DateTime? updatedAt,
    DocumentSnapshot? snapshot,
  }) {
    return PostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      text: text ?? this.text,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      summary: summary ?? this.summary,
      repostOf: repostOf ?? this.repostOf,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
