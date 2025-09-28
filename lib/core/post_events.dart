import 'dart:async';
import '../models/post.dart';

class PostUpdateEvent {
  final String originalPostId;
  final PostCounts counts;
  final ReactionType? userReaction;
  final bool? isBookmarked;

  PostUpdateEvent({
    required this.originalPostId,
    required this.counts,
    this.userReaction,
    this.isBookmarked,
  });
}

class PostEvents {
  PostEvents._();

  static final StreamController<PostUpdateEvent> _controller =
      StreamController<PostUpdateEvent>.broadcast();

  static Stream<PostUpdateEvent> get stream => _controller.stream;

  static void emit(PostUpdateEvent event) {
    _controller.add(event);
  }
}