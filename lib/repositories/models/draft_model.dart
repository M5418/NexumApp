import 'package:cloud_firestore/cloud_firestore.dart';

enum DraftType { post, podcast }

class DraftModel {
  final String id;
  final String userId;
  final DraftType type;
  final String title;
  final String body; // For posts or description for podcasts
  final List<String> mediaUrls;
  final List<String>? taggedUsers; // For posts
  final List<String>? communities; // For posts
  final String? coverUrl; // For podcasts
  final String? audioUrl; // For podcasts
  final String? category; // For podcasts
  final DateTime createdAt;
  final DateTime updatedAt;

  DraftModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.mediaUrls = const [],
    this.taggedUsers,
    this.communities,
    this.coverUrl,
    this.audioUrl,
    this.category,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DraftModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return DraftModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: DraftType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => DraftType.post,
      ),
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      mediaUrls: (data['mediaUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      taggedUsers: (data['taggedUsers'] as List<dynamic>?)?.cast<String>(),
      communities: (data['communities'] as List<dynamic>?)?.cast<String>(),
      coverUrl: data['coverUrl'],
      audioUrl: data['audioUrl'],
      category: data['category'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.name,
      'title': title,
      'body': body,
      'mediaUrls': mediaUrls,
      if (taggedUsers != null) 'taggedUsers': taggedUsers,
      if (communities != null) 'communities': communities,
      if (coverUrl != null) 'coverUrl': coverUrl,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (category != null) 'category': category,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
