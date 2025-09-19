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
  final String userName;
  final String userAvatarUrl;
  final String? actionType;

  const RepostedBy({
    required this.userName,
    required this.userAvatarUrl,
    this.actionType,
  });
}

class Post {
  final String id;
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

  const Post({
    required this.id,
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
  });

  Post copyWith({
    String? id,
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
  }) {
    return Post(
      id: id ?? this.id,
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
    );
  }
}
