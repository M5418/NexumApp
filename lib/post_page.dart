import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';

import 'models/post_detail.dart';
import 'models/comment.dart';
import 'models/post.dart';

import 'core/posts_api.dart';
import 'core/auth_api.dart';

import 'widgets/media_carousel.dart';
import 'widgets/auto_play_video.dart';
import 'widgets/comment_thread.dart';
import 'widgets/animated_navbar.dart';
import 'widgets/post_options_menu.dart';
import 'widgets/share_bottom_sheet.dart';
import 'widgets/comment_bottom_sheet.dart';
import 'core/time_utils.dart';
import 'package:provider/provider.dart';
import 'core/i18n/language_provider.dart';
import 'core/translate_api.dart';

class PostPage extends StatefulWidget {
  final Post? post;
  final String? postId;

  const PostPage({super.key, this.post, this.postId})
      : assert(post != null || postId != null,
            'Either post or postId must be provided');

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  bool _showTranslation = false;
  String? _translatedText;

  PostDetail? _post;

  bool _isLiked = false;
  bool _isBookmarked = false;

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  List<Comment> _comments = [];
  bool _loadingPost = false;
  bool _loadingComments = false;

  String? _currentUserId;

  String? _lastUgcCode;

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
      _applyPost(widget.post!);
      await _loadComments();
    } else {
      await _loadPostById();
      if (_post != null) {
        await _loadComments();
      }
    }
  }

  bool _isDesktopLayout(BuildContext context) {
    if (kIsWeb) {
      return MediaQuery.of(context).size.width >= 1000;
    }
    final p = Theme.of(context).platform;
    return p == TargetPlatform.windows ||
        p == TargetPlatform.macOS ||
        p == TargetPlatform.linux;
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final res = await AuthApi().me();
      final id =
          (res['ok'] == true && res['data'] != null) ? res['data']['id'] : null;
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
      comments: const [],
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
      final posts = await PostsApi().listFeed(limit: 50, offset: 0);
      final found = posts.firstWhere(
        (p) => p.id == widget.postId,
        orElse: () =>
            posts.isNotEmpty ? posts.first : throw Exception('Post not found'),
      );
      _applyPost(found);
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
      final list = await PostsApi().listComments(_post!.id);
      if (!mounted) return;
      setState(() {
        _comments = list;
      });
    } catch (e) {
      if (!mounted) return;
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
      final out = await TranslateApi().translateTexts([text], target);
      if (!mounted) return;
      setState(() {
        _translatedText = out.isNotEmpty ? out.first : text;
      });
    } catch (_) {}
  }

  Future<void> _toggleTranslation() async {
    if (_post == null) return;
    final text = _post!.text.trim();
    if (!_showTranslation && _translatedText == null && text.isNotEmpty) {
      try {
        final target = context.read<LanguageProvider>().ugcTargetCode;
        final out = await TranslateApi().translateTexts([text], target);
        if (!mounted) return;
        setState(() {
          _translatedText = out.isNotEmpty ? out.first : text;
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
      onReport: () {},
      onMute: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${_post!.authorName} muted', style: GoogleFonts.inter()),
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
        await PostsApi().unlike(postId);
      } else {
        await PostsApi().like(postId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _post = original;
        _isLiked = wasLiked;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${wasLiked ? 'Unlike' : 'Like'} failed: ${_toError(e)}',
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
        await PostsApi().bookmark(postId);
      } else {
        await PostsApi().unbookmark(postId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _post = original;
        _isBookmarked = !willBookmark;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bookmark failed: ${_toError(e)}',
              style: GoogleFonts.inter()),
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
            content:
                Text('Link copied to clipboard', style: GoogleFonts.inter()),
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
      comments = await PostsApi().listComments(_post!.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Load comments failed: ${_toError(e)}',
              style: GoogleFonts.inter()),
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
          await PostsApi().addComment(_post!.id, content: text);
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
          await PostsApi().addComment(_post!.id,
              content: replyText, parentCommentId: commentId);
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
              content: Text('Reply failed: ${_toError(e)}',
                  style: GoogleFonts.inter()),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
  }
    Future<void> _replyToCommentDesktop(String commentId) async {
    if (_post == null) return;
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final reply = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
          title: Text('Reply', style: GoogleFonts.inter()),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            style: GoogleFonts.inter(),
            decoration: InputDecoration(
              hintText: 'Write your reply...',
              hintStyle: GoogleFonts.inter(color: const Color(0xFF666666)),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text('Send',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );

    if (reply == null || reply.isEmpty) return;
    try {
      await PostsApi()
          .addComment(_post!.id, content: reply, parentCommentId: commentId);
      await _loadComments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reply posted!', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
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
  }

  Future<void> _submitComment() async {
    if (_post == null) return;
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    try {
      await PostsApi().addComment(_post!.id, content: text);
      _commentController.clear();
      _commentFocusNode.unfocus();

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
    final desktop = _isDesktopLayout(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        size: 20,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
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
                  GestureDetector(
                    onTap: _showPostOptions,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black : Colors.white,
                        shape: BoxShape.circle,
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
            Expanded(
              child: _loadingPost && _post == null
                  ? const Center(child: CircularProgressIndicator())
                  : (_post == null
                      ? const SizedBox.shrink()
                      : (desktop
                          ? _buildDesktopBody(isDark)
                          : _buildMobileBody(isDark))),
            ),
          ],
        ),
      ),
      bottomNavigationBar: desktop
          ? null
          : AnimatedNavbar(
              selectedIndex: 0,
              onTabChange: (index) => Navigator.pop(context),
            ),
    );
  }

  Widget _buildMobileBody(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Column(
        children: [
          _buildPostCard(isDark, showPreviewComments: true),
          Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: isDark ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    focusNode: _commentFocusNode,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Write a comment...',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF666666),
                      ),
                    ),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _submitComment,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopBody(bool isDark) {
    final surfaceColor = isDark ? Colors.black : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: _buildPostCard(isDark, showPreviewComments: false),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Text('Comments',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                            )),
                        const Spacer(),
                        const Icon(Icons.chat_bubble_outline,
                            size: 18, color: Color(0xFF666666)),
                        const SizedBox(width: 6),
                        Text(
                          (_post?.counts.comments ?? 0).toString(),
                          style:
                              GoogleFonts.inter(color: const Color(0xFF666666)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _loadingComments
                        ? const Center(child: CircularProgressIndicator())
                        : (_comments.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'No comments yet',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF666666),
                                    ),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: _comments.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, i) {
                                  final c = _comments[i];
                                  return CommentThread(
                                    comment: c,
                                    onReply: (id) => _replyToCommentDesktop(id),
                                    onLike: (_) {},
                                  );
                                },
                              )),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1A1A1A)
                                  : const Color(0xFFF7F7F7),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Center(
                              child: TextField(
                                controller: _commentController,
                                focusNode: _commentFocusNode,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Write a comment...',
                                  hintStyle: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: const Color(0xFF666666),
                                  ),
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                                onSubmitted: (_) => _submitComment(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _submitComment,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white : Colors.black,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.send,
                              size: 20,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(bool isDark, {required bool showPreviewComments}) {
    final surfaceColor = isDark ? Colors.black : Colors.white;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: NetworkImage(_post!.authorAvatarUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _post!.authorName,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
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
            if (_post!.text.isNotEmpty) ...[
              Text(
                _showTranslation ? (_translatedText ?? _post!.text) : _post!.text,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _toggleTranslation,
                child: Text(
                  _showTranslation ? 'Show Original' : 'Translate',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFFBFAE01),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (_post!.mediaType != MediaType.none) ...[
              if ((_post!.mediaType == MediaType.image ||
                      _post!.mediaType == MediaType.images) &&
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
                  borderRadius: BorderRadius.circular(25),
                ),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                GestureDetector(
                  onTap: _toggleLike,
                  child: Row(
                    children: [
                      Icon(
                        _isLiked
                            ? Icons.thumb_up_alt
                            : Icons.thumb_up_alt_outlined,
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
                        _post!.counts.comments.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
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
                GestureDetector(
                  onTap: _toggleBookmark,
                  child: Row(
                    children: [
                      Icon(
                        _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                        size: 20,
                        color: _isBookmarked
                            ? const Color(0xFFBFAE01)
                            : const Color(0xFF666666),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _post!.counts.bookmarks.toString(),
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
            const SizedBox(height: 12),
            Text(
              TimeUtils.relativeLabel(_post!.createdAt, locale: 'en_short'),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 0.2,
              color: const Color(0xFF666666).withValues(alpha: 0.2),
            ),
            const SizedBox(height: 20),
            if (showPreviewComments) ...[
              if (_loadingComments)
                const Center(child: CircularProgressIndicator())
              else if (_comments.isNotEmpty) ...[
                ..._comments.map(
                  (comment) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: CommentThread(
                      comment: comment,
                      isFirstReply: false,
                      onReply: (commentId) {
                        _openCommentsSheet();
                      },
                      onLike: (_) {},
                    ),
                  ),
                ),
                Center(
                  child: GestureDetector(
                    onTap: _openCommentsSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'View all commentairoauiueiwr',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF666666),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}