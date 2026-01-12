enum MediaType { none, image, images, video }

enum ReactionType { diamond, like, heart, wow }

class PostCounts {
  final int likes;
  final int comments;
  final int shares;
  final int reposts;
  final int bookmarks;

  const PostCounts({
    required this.likes,
    required this.comments,
    required this.shares,
    required this.reposts,
    required this.bookmarks,
  });
}

class RepostedBy {
  final String? userId;
  final String userName;
  final String userAvatarUrl;
  final String? actionType;

  const RepostedBy({
    this.userId,
    required this.userName,
    required this.userAvatarUrl,
    this.actionType,
  });
}

/// Tagged user info for display
class TaggedUser {
  final String id;
  final String name;
  final String? avatarUrl;

  const TaggedUser({
    required this.id,
    required this.name,
    this.avatarUrl,
  });
}

class Post {
  final String id;
  final String authorId;
  final String userName;
  final String userAvatarUrl;
  final DateTime createdAt;
  final String text;
  final MediaType mediaType;
  final List<String> imageUrls;
  final String? videoUrl;
  final PostCounts counts;
  final ReactionType? userReaction;
  final bool isBookmarked;
  final bool isRepost;
  final RepostedBy? repostedBy;
  final String? originalPostId;
  final List<TaggedUser> taggedUsers;

  const Post({
    required this.id,
    required this.authorId,
    required this.userName,
    required this.userAvatarUrl,
    required this.createdAt,
    required this.text,
    required this.mediaType,
    required this.imageUrls,
    this.videoUrl,
    required this.counts,
    this.userReaction,
    required this.isBookmarked,
    required this.isRepost,
    this.repostedBy,
    this.originalPostId,
    this.taggedUsers = const [],
  });

  Post copyWith({
    String? id,
    String? authorId,
    String? userName,
    String? userAvatarUrl,
    DateTime? createdAt,
    String? text,
    MediaType? mediaType,
    List<String>? imageUrls,
    String? videoUrl,
    PostCounts? counts,
    ReactionType? userReaction,
    bool? isBookmarked,
    bool? isRepost,
    RepostedBy? repostedBy,
    String? originalPostId,
    List<TaggedUser>? taggedUsers,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      createdAt: createdAt ?? this.createdAt,
      text: text ?? this.text,
      mediaType: mediaType ?? this.mediaType,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      counts: counts ?? this.counts,
      userReaction: userReaction ?? this.userReaction,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isRepost: isRepost ?? this.isRepost,
      repostedBy: repostedBy ?? this.repostedBy,
      originalPostId: originalPostId ?? this.originalPostId,
      taggedUsers: taggedUsers ?? this.taggedUsers,
    );
    }
}