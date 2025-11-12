import 'post.dart';
import 'comment.dart';

class PostDetail {
  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatarUrl;
  final DateTime createdAt;
  final String text;
  final MediaType mediaType;
  final List<String> imageUrls;
  final String? videoUrl;
  final PostCounts counts;
  final ReactionType? userReaction;
  final bool isBookmarked;
  final List<Comment> comments;

  PostDetail({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.createdAt,
    required this.text,
    required this.mediaType,
    this.imageUrls = const [],
    this.videoUrl,
    required this.counts,
    this.userReaction,
    this.isBookmarked = false,
    this.comments = const [],
  });
}
