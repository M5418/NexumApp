import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';

import 'models/post_detail.dart';
import 'models/comment.dart';
import 'models/post.dart';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'repositories/firebase/firebase_post_repository.dart';
import 'repositories/interfaces/comment_repository.dart';
import 'repositories/firebase/firebase_comment_repository.dart';
import 'repositories/firebase/firebase_user_repository.dart';

import 'widgets/media_carousel.dart';
import 'widgets/auto_play_video.dart';
import 'widgets/post_options_menu.dart';
import 'widgets/share_bottom_sheet.dart';
import 'widgets/comment_bottom_sheet.dart';
import 'core/time_utils.dart';
import 'repositories/firebase/firebase_translate_repository.dart';
import 'core/i18n/language_provider.dart';

class CommunityPostPage extends StatefulWidget {
  // Community context is required
  final String communityId;

  // Prefer passing the full post to avoid extra fetches
  final Post? post;
  // Fallback: accept postId (will fetch via community endpoints if provided)
  final String? postId;

  const CommunityPostPage({
    super.key,
    required this.communityId,
    this.post,
    this.postId,
  }) : assert(
          post != null || postId != null,
          'Either post or postId must be provided',
        );

  @override
  State<CommunityPostPage> createState() => _CommunityPostPageState();
}

class _CommunityPostPageState extends State<CommunityPostPage> {
  bool _showTranslation = false;
  String? _translatedText;
  String? _lastUgcCode;

  // Post data (mapped to PostDetail to preserve existing UI structure)
  PostDetail? _post;

  // Local toggles derived from _post
  bool _isLiked = false;
  bool _isBookmarked = false;

  // Comments
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _loadingPost = false;
  bool _loadingComments = false;

  // Current user for CommentBottomSheet
  String? _currentUserId;

  final FirebasePostRepository _postRepo = FirebasePostRepository();
  final FirebaseCommentRepository _commentRepo = FirebaseCommentRepository();
  final FirebaseUserRepository _userRepo = FirebaseUserRepository();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final code = Provider.of<LanguageProvider>(context).ugcTargetCode;
    if (code != _lastUgcCode) {
      _lastUgcCode = code;
      if (_showTranslation && _post != null) {
        final text = _post!.text.trim();
        if (text.isNotEmpty) {
          _retranslateCurrentPost(code);
        }
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _loadCurrentUserId();
    if (widget.post != null) {
      // Map provided Post into PostDetail and load comments
      _applyPost(widget.post!);
      await _loadComments();
    } else {
      // Fallback: fetch by id from community API
      await _loadPostById();
      if (_post != null) {
        await _loadComments();
      }
    }
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final id = fb.FirebaseAuth.instance.currentUser?.uid;
      if (!mounted) return;
      setState(() {
        _currentUserId = id?.toString();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentUserId = null;
      });
    }
  }

  void _applyPost(Post p) {
    final detail = PostDetail(
      id: p.id,
      authorId: '',
      authorName: p.userName,
      authorAvatarUrl: p.userAvatarUrl,
      createdAt: p.createdAt,
      text: p.text,
      mediaType: p.mediaType,
      imageUrls: p.imageUrls,
      videoUrl: p.videoUrl,
      counts: p.counts,
      userReaction: p.userReaction,
      isBookmarked: p.isBookmarked,
      comments: const [], // comments are loaded separately
    );
    setState(() {
      _post = detail;
      _isLiked = detail.userReaction != null;
      _isBookmarked = detail.isBookmarked;
    });
  }

  Future<void> _loadPostById() async {
    if (widget.postId == null) return;
    setState(() {
      _loadingPost = true;
    });
    try {
      final model = await FirebasePostRepository().getPost(widget.postId!);
      final p = (model == null)
          ? null
          : Post(
              id: model.id,
              authorId: model.authorId,
              userName: '',
              userAvatarUrl: '',
              createdAt: model.createdAt,
              text: model.text,
              mediaType: model.mediaUrls.isEmpty
                  ? MediaType.none
                  : (model.mediaUrls.length == 1
                      ? MediaType.image
                      : MediaType.images),
              imageUrls: model.mediaUrls,
              videoUrl: null,
              counts: PostCounts(
                likes: model.summary.likes,
                comments: model.summary.comments,
                shares: model.summary.shares,
                reposts: model.summary.reposts,
                bookmarks: model.summary.bookmarks,
              ),
              userReaction: null,
              isBookmarked: false,
              isRepost:
                  (model.repostOf != null && model.repostOf!.isNotEmpty),
              repostedBy: null,
              originalPostId: model.repostOf,
            );
      if (p == null) {
        throw Exception('Post not found');
      }
      _applyPost(p);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Load post failed: ${_toError(e)}',
              style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() {
          _loadingPost = false;
        });
      }
    }
  }

  Future<void> _loadComments() async {
    if (_post == null) return;
    setState(() {
      _loadingComments = true;
    });
    try {
      await _commentRepo.getComments(postId: _post!.id, limit: 1);
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      // Keep UI, just notify
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Load comments failed: ${_toError(e)}',
              style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingComments = false;
        });
      }
    }
  }

  Future<void> _retranslateCurrentPost(String target) async {
    if (_post == null) return;
    final text = _post!.text.trim();
    if (text.isEmpty) return;
    try {
      final repo = FirebaseTranslateRepository();
      final translated = await repo.translateText(text, target);
      if (!mounted) return;
      setState(() {
        _translatedText = translated;
      });
    } catch (_) {}
  }

  Future<void> _toggleTranslation() async {
    if (_post == null) return;
    final text = _post!.text.trim();
    if (!_showTranslation && _translatedText == null && text.isNotEmpty) {
      try {
        final target = context.read<LanguageProvider>().ugcTargetCode;
        final repo = FirebaseTranslateRepository();
        final translated = await repo.translateText(text, target);
        if (!mounted) return;
        setState(() {
          _translatedText = translated;
          _lastUgcCode = target;
        });
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _showTranslation = !_showTranslation;
      });
    }
  }


  void _showPostOptions() {
    if (_post == null) return;
    PostOptionsMenu.show(
      context,
      authorName: _post!.authorName,
      postId: _post!.id,
      onReport: () {
        // Report handled elsewhere (UI only)
      },
      onMute: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_post!.authorName} muted',
                style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF666666),
          ),
        );
      },
      position: const Offset(16, 120),
    );
  }

  String _toError(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final reason = (data['error'] ?? data['message'] ?? data).toString();
        return 'HTTP ${code ?? 'error'}: $reason';
      }
      return 'HTTP ${code ?? 'error'}';
    }
    return e.toString();
  }

  // Actions

  Future<void> _toggleLike() async {
    if (_post == null) return;
    final postId = _post!.id;
    final original = _post!;
    final wasLiked = _isLiked;

    // Optimistic update
    final newLikes =
        (original.counts.likes + (wasLiked ? -1 : 1)).clamp(0, 1 << 30);
    final updatedCounts = PostCounts(
      likes: newLikes,
      comments: original.counts.comments,
      shares: original.counts.shares,
      reposts: original.counts.reposts,
      bookmarks: original.counts.bookmarks,
    );
    final updated = PostDetail(
      id: original.id,
      authorId: original.authorId,
      authorName: original.authorName,
      authorAvatarUrl: original.authorAvatarUrl,
      createdAt: original.createdAt,
      text: original.text,
      mediaType: original.mediaType,
      imageUrls: original.imageUrls,
      videoUrl: original.videoUrl,
      counts: updatedCounts,
      userReaction: wasLiked ? null : ReactionType.like,
      isBookmarked: original.isBookmarked,
      comments: original.comments,
    );

    setState(() {
      _post = updated;
      _isLiked = !wasLiked;
    });

    try {
      if (wasLiked) {
        await _postRepo.unlikePost(postId);
      } else {
        await _postRepo.likePost(postId);
      }
    } catch (e) {
      if (!mounted) return;
      // Revert on error
      setState(() {
        _post = original;
        _isLiked = wasLiked;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${wasLiked ? 'Unlike' : 'Like'} failed: ${_toError(e)}',
              style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _toggleBookmark() async {
    if (_post == null) return;
    final postId = _post!.id;
    final original = _post!;
    final willBookmark = !_isBookmarked;

    // Optimistic update
    final newBookmarks =
        (original.counts.bookmarks + (willBookmark ? 1 : -1)).clamp(0, 1 << 30);
    final updatedCounts = PostCounts(
      likes: original.counts.likes,
      comments: original.counts.comments,
      shares: original.counts.shares,
      reposts: original.counts.reposts,
      bookmarks: newBookmarks,
    );
    final updated = PostDetail(
      id: original.id,
      authorId: original.authorId,
      authorName: original.authorName,
      authorAvatarUrl: original.authorAvatarUrl,
      createdAt: original.createdAt,
      text: original.text,
      mediaType: original.mediaType,
      imageUrls: original.imageUrls,
      videoUrl: original.videoUrl,
      counts: updatedCounts,
      userReaction: original.userReaction,
      isBookmarked: willBookmark,
      comments: original.comments,
    );

    setState(() {
      _post = updated;
      _isBookmarked = willBookmark;
    });

    try {
      if (willBookmark) {
        await _postRepo.bookmarkPost(postId);
      } else {
        await _postRepo.unbookmarkPost(postId);
      }
    } catch (e) {
      if (!mounted) return;
      // Revert on error
      setState(() {
        _post = original;
        _isBookmarked = !willBookmark;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Bookmark failed: ${_toError(e)}', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showShareOptions() {
    ShareBottomSheet.show(
      context,
      onStories: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shared to Stories', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      },
      onCopyLink: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Link copied to clipboard', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF9E9E9E),
          ),
        );
      },
      onTelegram: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shared to Telegram', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF0088CC),
          ),
        );
      },
      onFacebook: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Shared to Facebook', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF1877F2),
          ),
        );
      },
      onMore: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('More share options', style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF666666),
          ),
        );
      },
      onSendToUsers: (selectedUsers, message) {
        final userNames = selectedUsers.map((user) => user.name).join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sent to $userNames${message.isNotEmpty ? ' with message: "$message"' : ''}',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xFFBFAE01),
          ),
        );
      },
    );
  }

  Future<void> _openCommentsSheet() async {
    if (_post == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    List<Comment> comments = [];
    try {
      comments = await _loadCommentsForPost(_post!.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Load comments failed: ${_toError(e)}', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (!mounted) return;

    CommentBottomSheet.show(
      context,
      postId: _post!.id,
      comments: comments,
      currentUserId: _currentUserId ?? '',
      isDarkMode: isDark,
      onAddComment: (text) async {
        try {
          await _commentRepo.createComment(postId: _post!.id, text: text);
          // Optimistically increment comments count
          final original = _post!;
          final updatedCounts = PostCounts(
            likes: original.counts.likes,
            comments: original.counts.comments + 1,
            shares: original.counts.shares,
            reposts: original.counts.reposts,
            bookmarks: original.counts.bookmarks,
          );
          setState(() {
            _post = PostDetail(
              id: original.id,
              authorId: original.authorId,
              authorName: original.authorName,
              authorAvatarUrl: original.authorAvatarUrl,
              createdAt: original.createdAt,
              text: original.text,
              mediaType: original.mediaType,
              imageUrls: original.imageUrls,
              videoUrl: original.videoUrl,
              counts: updatedCounts,
              userReaction: original.userReaction,
              isBookmarked: original.isBookmarked,
              comments: original.comments,
            );
          });
          await _loadComments();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Comment posted!', style: GoogleFonts.inter()),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Post comment failed: ${_toError(e)}',
                  style: GoogleFonts.inter()),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      onReplyToComment: (commentId, replyText) async {
        try {
          await _commentRepo.createComment(
              postId: _post!.id, text: replyText, parentCommentId: commentId);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reply posted!', style: GoogleFonts.inter()),
              backgroundColor: const Color(0xFF4CAF50),
            ),
          );
          await _loadComments();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Reply failed: ${_toError(e)}', style: GoogleFonts.inter()),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }

  Future<List<Comment>> _loadCommentsForPost(String postId) async {
    final list = await _commentRepo.getComments(postId: postId, limit: 200);
    final uids = list.map((m) => m.authorId).toSet().toList();
    final profiles = await _userRepo.getUsers(uids);
    final byId = {for (final p in profiles) p.uid: p};
    return list.map((m) {
      final u = byId[m.authorId];
      return Comment(
        id: m.id,
        userId: m.authorId,
        userName: (u?.displayName ?? u?.username ?? 'User'),
        userAvatarUrl: (u?.avatarUrl ?? ''),
        text: m.text,
        createdAt: m.createdAt,
        likesCount: m.likesCount,
        isLikedByUser: false,
        replies: const [],
        parentCommentId: m.parentCommentId,
      );
    }).toList();
  }

  Future<void> _submitComment() async {
    if (_post == null) return;
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    try {
      final commentRepo = context.read<CommentRepository>();
      await commentRepo.createComment(
        postId: _post!.id,
        text: text,
      );
      _commentController.clear();
      _commentFocusNode.unfocus();

      // Update UI: increment comments count and refresh
      final original = _post!;
      final updatedCounts = PostCounts(
        likes: original.counts.likes,
        comments: original.counts.comments + 1,
        shares: original.counts.shares,
        reposts: original.counts.reposts,
        bookmarks: original.counts.bookmarks,
      );
      setState(() {
        _post = PostDetail(
          id: original.id,
          authorId: original.authorId,
          authorName: original.authorName,
          authorAvatarUrl: original.authorAvatarUrl,
          createdAt: original.createdAt,
          text: original.text,
          mediaType: original.mediaType,
          imageUrls: original.imageUrls,
          videoUrl: original.videoUrl,
          counts: updatedCounts,
          userReaction: original.userReaction,
          isBookmarked: original.isBookmarked,
          comments: original.comments,
        );
      });
      await _loadComments();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Comment posted!', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to post comment: ${_toError(e)}',
              style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
    final surfaceColor = isDark ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0),
                            blurRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        size: 20,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),

                  // Title
                  Expanded(
                    child: Center(
                      child: Text(
                        'Post',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),

                  // More button
                  GestureDetector(
                    onTap: _showPostOptions,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0),
                            blurRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.more_horiz,
                        size: 18,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _loadingPost && _post == null
                  ? const Center(child: CircularProgressIndicator())
                  : (_post == null
                      ? const SizedBox.shrink()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0),
                                  blurRadius: 1,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Author info
                                  Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          image: DecorationImage(
                                            image: NetworkImage(
                                                _post!.authorAvatarUrl),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _post!.authorName,
                                              style: GoogleFonts.inter(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black,
                                              ),
                                            ),
                                            Text(
                                              TimeUtils.relativeLabel(_post!.createdAt, locale: 'en_short'),
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                color: const Color(0xFF666666),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  // Post text
                                  if (_post!.text.isNotEmpty) ...[
                                    Text(
                                      _showTranslation
                                          ? (_translatedText ?? _post!.text)
                                          : _post!.text,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Only show translate button if translation is enabled in settings
                                    if (context.watch<LanguageProvider>().postTranslationEnabled)
                                      GestureDetector(
                                        onTap: _toggleTranslation,
                                        child: Text(
                                          _showTranslation
                                              ? 'Show Original'
                                              : 'Translate',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: const Color(0xFFBFAE01),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 20),
                                  ],

                                  // Media content
                                  if (_post!.mediaType != MediaType.none) ...[
                                    if ((_post!.mediaType == MediaType.image ||
                                            _post!.mediaType ==
                                                MediaType.images) &&
                                        _post!.imageUrls.isNotEmpty)
                                      MediaCarousel(
                                        imageUrls: _post!.imageUrls,
                                        height: 650,
                                      ),
                                    if (_post!.mediaType == MediaType.video &&
                                        _post!.videoUrl != null)
                                      AutoPlayVideo(
                                        videoUrl: _post!.videoUrl!,
                                        width: double.infinity,
                                        height: 300,
                                        borderRadius:
                                            BorderRadius.circular(25),
                                      ),
                                    const SizedBox(height: 16),
                                  ],

                                  // Engagement bar
                                  Row(
                                    children: [
                                      // Like button
                                      GestureDetector(
                                        onTap: _toggleLike,
                                        child: Row(
                                          children: [
                                            Icon(
                                              _isLiked
                                                  ? Icons.thumb_up_alt
                                                  : Icons
                                                      .thumb_up_alt_outlined,
                                              size: 20,
                                              color: _isLiked
                                                  ? const Color(0xFFBFAE01)
                                                  : const Color(0xFF666666),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _post!.counts.likes.toString(),
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                color: const Color(0xFF666666),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 20),

                                      // Comment count (tap to open full sheet)
                                      GestureDetector(
                                        onTap: _openCommentsSheet,
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.chat_bubble_outline,
                                              size: 20,
                                              color: Color(0xFF666666),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _post!.counts.comments
                                                  .toString(),
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                color: const Color(0xFF666666),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 20),

                                      // Share button
                                      GestureDetector(
                                        onTap: _showShareOptions,
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.share_outlined,
                                              size: 20,
                                              color: Color(0xFF666666),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _post!.counts.shares.toString(),
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                color: const Color(0xFF666666),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 20),

                                      // Repost static (UI only)
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.repeat,
                                            size: 20,
                                            color: Color(0xFF666666),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _post!.counts.reposts.toString(),
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: const Color(0xFF666666),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const Spacer(),

                                      // Bookmark button
                                      GestureDetector(
                                        onTap: _toggleBookmark,
                                        child: Row(
                                          children: [
                                            Icon(
                                              _isBookmarked
                                                  ? Icons.bookmark
                                                  : Icons.bookmark_border,
                                              size: 20,
                                              color: _isBookmarked
                                                  ? const Color(0xFFBFAE01)
                                                  : const Color(0xFF666666),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _post!.counts.bookmarks
                                                  .toString(),
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                color: const Color(0xFF666666),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 16),

                                  if (_loadingComments)
                                    const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(12.0),
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )),
            ),

            // Bottom input for quick comment
            if (_post != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0),
                      blurRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          focusNode: _commentFocusNode,
                          decoration: InputDecoration(
                            hintText: 'Write a comment...',
                            hintStyle: GoogleFonts.inter(
                              color: const Color(0xFF666666),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: const Color(0xFF666666)
                                    .withValues(alpha: 51),
                                width: 0.6,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: (_) => _submitComment(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _submitComment,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: Color(0xFFBFAE01),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}