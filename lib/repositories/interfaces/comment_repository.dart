import 'dart:async';

abstract class CommentRepository {
  // Create comment
  Future<String> createComment({
    required String postId,
    required String text,
    String? parentCommentId,
  });
  
  // Get comments for post (paginated)
  Future<List<CommentModel>> getComments({
    required String postId,
    int limit = 20,
    CommentModel? lastComment,
  });
  
  // Get single comment
  Future<CommentModel?> getComment(String commentId);
  
  // Update comment
  Future<void> updateComment({
    required String commentId,
    required String text,
  });
  
  // Delete comment
  Future<void> deleteComment(String commentId);
  
  // Like/unlike comment
  Future<void> likeComment(String commentId);
  Future<void> unlikeComment(String commentId);
  
  // Real-time comment stream for post
  Stream<List<CommentModel>> commentsStream({
    required String postId,
    int limit = 50,
  });
}

class CommentModel {
  final String id;
  final String postId;
  final String authorId;
  final String text;
  final String? parentCommentId;
  final int likesCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  
  CommentModel({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.text,
    this.parentCommentId,
    this.likesCount = 0,
    required this.createdAt,
    this.updatedAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'authorId': authorId,
      'text': text,
      'parentCommentId': parentCommentId,
      'likesCount': likesCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
