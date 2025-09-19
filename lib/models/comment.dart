class Comment {
  final String id;
  final String userId;
  final String userName;
  final String userAvatarUrl;
  final String text;
  final DateTime createdAt;
  final int likesCount;
  final bool isLikedByUser;
  final List<Comment> replies;
  final String? parentCommentId;
  final bool isPinned;
  final bool isCreator; // If comment is from the video creator

  const Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatarUrl,
    required this.text,
    required this.createdAt,
    required this.likesCount,
    required this.isLikedByUser,
    required this.replies,
    this.parentCommentId,
    this.isPinned = false,
    this.isCreator = false,
  });

  Comment copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatarUrl,
    String? text,
    DateTime? createdAt,
    int? likesCount,
    bool? isLikedByUser,
    List<Comment>? replies,
    String? parentCommentId,
    bool? isPinned,
    bool? isCreator,
  }) {
    return Comment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      isLikedByUser: isLikedByUser ?? this.isLikedByUser,
      replies: replies ?? this.replies,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      isPinned: isPinned ?? this.isPinned,
      isCreator: isCreator ?? this.isCreator,
    );
  }
}
