import 'package:cloud_firestore/cloud_firestore.dart';

enum BookmarkType { post, podcast, book }

class BookmarkModel {
  final String id;
  final String userId;
  final BookmarkType type;
  final String itemId; // post ID, podcast ID, or book ID
  final DateTime createdAt;
  
  // Denormalized data for quick display
  final String? title;
  final String? coverUrl;
  final String? authorName;
  final String? description;

  BookmarkModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.itemId,
    required this.createdAt,
    this.title,
    this.coverUrl,
    this.authorName,
    this.description,
  });

  factory BookmarkModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return BookmarkModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: BookmarkType.values.firstWhere(
        (t) => t.name == data['type'],
        orElse: () => BookmarkType.post,
      ),
      itemId: data['itemId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      title: data['title'],
      coverUrl: data['coverUrl'],
      authorName: data['authorName'],
      description: data['description'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type.name,
      'itemId': itemId,
      'createdAt': FieldValue.serverTimestamp(),
      if (title != null) 'title': title,
      if (coverUrl != null) 'coverUrl': coverUrl,
      if (authorName != null) 'authorName': authorName,
      if (description != null) 'description': description,
    };
  }
}
