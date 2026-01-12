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

/// Event for comment like/unlike sync across the app
class CommentLikeEvent {
  final String commentId;
  final bool isLiked;
  final int likesCount;

  CommentLikeEvent({
    required this.commentId,
    required this.isLiked,
    required this.likesCount,
  });
}

class CommentEvents {
  CommentEvents._();

  static final StreamController<CommentLikeEvent> _controller =
      StreamController<CommentLikeEvent>.broadcast();

  static Stream<CommentLikeEvent> get stream => _controller.stream;

  static void emitLike(CommentLikeEvent event) {
    _controller.add(event);
  }
}

/// Event for connection state sync across the app
class ConnectionEvent {
  final String targetUserId;
  final bool isConnected;

  ConnectionEvent({
    required this.targetUserId,
    required this.isConnected,
  });
}

class ConnectionEvents {
  ConnectionEvents._();

  static final StreamController<ConnectionEvent> _controller =
      StreamController<ConnectionEvent>.broadcast();

  static Stream<ConnectionEvent> get stream => _controller.stream;

  static void emit(ConnectionEvent event) {
    _controller.add(event);
  }
}