import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';
import 'package:firebase_storage/firebase_storage.dart' as fs;
import 'package:ionicons/ionicons.dart';
import 'package:readmore/readmore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'dart:async';

import 'models/post_detail.dart';
import 'models/comment.dart';
import 'models/post.dart';

import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'widgets/media_carousel.dart';
import 'widgets/auto_play_video.dart';
import 'widgets/comment_widget.dart';
import 'widgets/animated_navbar.dart';
import 'widgets/post_options_menu.dart';
import 'widgets/share_bottom_sheet.dart';
import 'utils/profile_navigation.dart';
import 'core/time_utils.dart';
import 'core/post_events.dart';
import 'package:provider/provider.dart';
import 'core/i18n/language_provider.dart';
import 'repositories/interfaces/block_repository.dart';
import 'repositories/interfaces/mute_repository.dart';
import 'repositories/firebase/firebase_translate_repository.dart';
import 'repositories/firebase/firebase_post_repository.dart';
import 'repositories/firebase/firebase_comment_repository.dart';
import 'repositories/firebase/firebase_user_repository.dart';
import 'repositories/models/post_model.dart';
import 'repositories/interfaces/comment_repository.dart';
import 'repositories/interfaces/bookmark_repository.dart';
import 'repositories/models/bookmark_model.dart';
import 'services/content_analytics_service.dart';

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

  final FirebasePostRepository _postRepo = FirebasePostRepository();
  final FirebaseCommentRepository _commentRepo = FirebaseCommentRepository();
  final FirebaseUserRepository _userRepo = FirebaseUserRepository();
  StreamSubscription<PostModel?>? _postSub;
  StreamSubscription<List<CommentModel>>? _commentsSub;
  StreamSubscription<CommentLikeEvent>? _commentLikeSub;
  bool _isLiked = false;
  bool _isBookmarked = false;

  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  List<Comment> _comments = [];
  bool _loadingPost = false;
  bool _loadingComments = false;
  
  // Comment UI state
  final Map<String, bool> _showRepliesMap = {};
  String? _replyingToCommentId;
  String? _replyingToUserName;
  bool _isReplyingToReply = false;
  String? _replyingToParentId;

  String? _currentUserId;

  String? _lastUgcCode;
  
  // Cache for faster loading
  static final Map<String, PostDetail> _postCache = {};
  static final Map<String, List<Comment>> _commentsCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

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
    _postSub?.cancel();
    _commentsSub?.cancel();
    _commentLikeSub?.cancel();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // Get user ID synchronously - it's already available
    _currentUserId = fb.FirebaseAuth.instance.currentUser?.uid;
    
    // Listen for comment like events from other parts of the app
    _commentLikeSub = CommentEvents.stream.listen(_onCommentLikeEvent);
    
    if (widget.post != null) {
      // INSTANT: Apply post immediately - no await
      _applyPost(widget.post!);
      _trackView(widget.post!);
      _subscribeToPost(widget.post!.id);
      _subscribeToComments(widget.post!.id);
      // Load comments in background (non-blocking)
      _loadComments();
    } else {
      final postId = widget.postId!;
      
      // Try cache first for instant display
      if (_isCacheValid(postId)) {
        final cachedPost = _postCache[postId];
        final cachedComments = _commentsCache[postId];
        if (cachedPost != null) {
          setState(() {
            _post = cachedPost;
            _isBookmarked = cachedPost.isBookmarked;
            if (cachedComments != null) {
              _comments = cachedComments;
              _loadingComments = false;
            }
            _loadingPost = false;
          });
        }
      }
      
      // Subscribe immediately for real-time updates
      _subscribeToPost(postId);
      _subscribeToComments(postId);
      
      // Load fresh data in background (non-blocking)
      _loadPostById();
      _loadComments();
    }
  }
  
  bool _isCacheValid(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < _cacheDuration;
  }
  
  void _updateCache(String postId, PostDetail post, List<Comment> comments) {
    _postCache[postId] = post;
    _commentsCache[postId] = comments;
    _cacheTimestamps[postId] = DateTime.now();
  }

  // ============ Analytics Tracking ============

  void _trackView(Post post) {
    if (!mounted) return;
    try {
      final analytics = context.read<ContentAnalyticsService>();
      analytics.trackView(
        contentId: post.id,
        contentType: 'post',
        userId: post.authorId,
      );
    } catch (e) {
      debugPrint('❌ Error tracking view: $e');
    }
  }

  void _trackLike(String postId, String authorId) {
    if (!mounted) return;
    try {
      final analytics = context.read<ContentAnalyticsService>();
      analytics.trackLike(
        contentId: postId,
        contentType: 'post',
        userId: authorId,
      );
    } catch (e) {
      debugPrint('❌ Error tracking like: $e');
    }
  }

  void _trackComment(String postId, String authorId) {
    if (!mounted) return;
    try {
      final analytics = context.read<ContentAnalyticsService>();
      analytics.trackComment(
        contentId: postId,
        contentType: 'post',
        userId: authorId,
      );
    } catch (e) {
      debugPrint('❌ Error tracking comment: $e');
    }
  }

  void _trackShare(String postId, String authorId) {
    if (!mounted) return;
    try {
      final analytics = context.read<ContentAnalyticsService>();
      analytics.trackShare(
        contentId: postId,
        contentType: 'post',
        userId: authorId,
      );
    } catch (e) {
      debugPrint('❌ Error tracking share: $e');
    }
  }

  void _trackBookmark(String postId, String authorId) {
    if (!mounted) return;
    try {
      final analytics = context.read<ContentAnalyticsService>();
      analytics.trackBookmark(
        contentId: postId,
        contentType: 'post',
        userId: authorId,
      );
    } catch (e) {
      debugPrint('❌ Error tracking bookmark: $e');
    }
  }

  // ============================================

  bool _isDesktopLayout(BuildContext context) {
    if (kIsWeb) {
      return MediaQuery.of(context).size.width >= 1000;
    }
    final p = Theme.of(context).platform;
    return p == TargetPlatform.windows ||
        p == TargetPlatform.macOS ||
        p == TargetPlatform.linux;
  }

  MediaType _mediaTypeFor(List<String> mediaUrls) {
    if (mediaUrls.isEmpty) return MediaType.none;
    final hasVideo = mediaUrls.any((u) {
      final l = u.toLowerCase();
      return l.endsWith('.mp4') || l.endsWith('.mov') || l.endsWith('.webm');
    });
    if (hasVideo) return MediaType.video;
    return mediaUrls.length > 1 ? MediaType.images : MediaType.image;
  }

  String? _videoUrlFromMedia(List<String> mediaUrls) {
    for (final u in mediaUrls) {
      final l = u.toLowerCase();
      if (l.endsWith('.mp4') || l.endsWith('.mov') || l.endsWith('.webm')) {
        return u;
      }
    }
    return null;
  }

  // FAST: Normalize storage URLs - skip network calls for valid URLs
  String _normalizeUrlSync(String u) {
    final s = u.trim();
    if (s.isEmpty) return s;
    // Auto-upgrade insecure http to https
    if (s.startsWith('http://')) {
      return 'https://${s.substring('http://'.length)}';
    }
    // Already a valid https URL - use as-is (FAST PATH)
    if (s.startsWith('https://')) return s;
    return s;
  }

  // SLOW: Only call for gs:// URLs that need resolution
  Future<String> _normalizeUrl(String u) async {
    final s = u.trim();
    if (s.isEmpty) return s;
    if (s.startsWith('http://')) {
      return 'https://${s.substring('http://'.length)}';
    }
    // Already valid https - no network call needed
    if (s.startsWith('https://')) return s;
    // Only resolve gs:// or storage paths
    try {
      if (s.startsWith('gs://')) {
        return await fs.FirebaseStorage.instance.refFromURL(s).getDownloadURL();
      }
      // Treat as storage path like "uploads/uid/file.jpg"
      return await fs.FirebaseStorage.instance.ref(s).getDownloadURL();
    } catch (_) {
      return s;
    }
  }

  // FAST: Parallel URL normalization
  Future<List<String>> _normalizeUrls(List<String> urls) async {
    if (urls.isEmpty) return [];
    // Fast path: if all URLs are already https, no async needed
    final needsAsync = urls.any((u) => !u.startsWith('https://') && !u.startsWith('http://'));
    if (!needsAsync) {
      return urls.map(_normalizeUrlSync).where((u) => u.isNotEmpty).toList();
    }
    // Parallel async for URLs that need resolution
    final results = await Future.wait(urls.map(_normalizeUrl));
    return results.where((u) => u.isNotEmpty).toList();
  }

  void _applyPost(Post p) {
    final detail = PostDetail(
      id: p.id,
      authorId: '', // Post model doesn't have authorId, will be fetched
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
      final model = await _postRepo.getPost(widget.postId!);
      if (model == null) throw Exception('Post not found');
      
      // Use denormalized data from post model for INSTANT display
      // (authorName, authorAvatarUrl are already in the post document)
      final authorName = model.authorName ?? 'User';
      final avatarUrl = model.authorAvatarUrl ?? '';
      
      // Normalize URLs to ensure they're loadable (gs:// -> https://)
      final mediaUrls = await _normalizeUrls(model.mediaUrls);
      
      // Show post IMMEDIATELY with available data
      final detail = PostDetail(
        id: model.id,
        authorId: model.authorId,
        authorName: authorName,
        authorAvatarUrl: avatarUrl,
        createdAt: model.createdAt,
        text: model.text,
        mediaType: _mediaTypeFor(mediaUrls),
        imageUrls: mediaUrls,
        videoUrl: _videoUrlFromMedia(mediaUrls),
        counts: PostCounts(
          likes: model.summary.likes,
          comments: model.summary.comments,
          shares: model.summary.shares,
          reposts: model.summary.reposts,
          bookmarks: model.summary.bookmarks,
        ),
        userReaction: null,
        isBookmarked: false,
        comments: const [],
      );
      
      if (!mounted) return;
      setState(() {
        _post = detail;
        _loadingPost = false;
      });
      
      // Load like/bookmark status in background (non-blocking)
      if (_currentUserId != null) {
        _loadUserInteractions(model.id);
      }
      
      // Track view
      _trackView(Post(
        id: model.id,
        userName: authorName,
        userAvatarUrl: avatarUrl,
        createdAt: model.createdAt,
        text: model.text,
        mediaType: _mediaTypeFor(mediaUrls),
        imageUrls: mediaUrls,
        videoUrl: _videoUrlFromMedia(mediaUrls),
        counts: detail.counts,
        userReaction: null,
        isBookmarked: false,
        authorId: model.authorId,
        isRepost: model.repostOf != null,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('post.load_failed')}: ${_toError(e)}',
              style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pop(context);
    } finally {
      if (mounted && _loadingPost) {
        setState(() {
          _loadingPost = false;
        });
      }
    }
  }
  
  // Load user interactions (like/bookmark) in background
  Future<void> _loadUserInteractions(String postId) async {
    if (_currentUserId == null) return;
    try {
      final results = await Future.wait([
        _postRepo.hasUserLikedPost(postId: postId, uid: _currentUserId!),
        _postRepo.hasUserBookmarkedPost(postId: postId, uid: _currentUserId!),
      ]);
      if (!mounted) return;
      setState(() {
        _isLiked = results[0];
        _isBookmarked = results[1];
      });
    } catch (_) {
      // Silent fail - not critical
    }
  }

  void _subscribeToPost(String id) {
    _postSub?.cancel();
    _postSub = _postRepo.postStream(id).listen((model) async {
      if (!mounted) return;
      if (model == null) return;
      String name = _post?.authorName ?? '';
      String avatar = _post?.authorAvatarUrl ?? '';
      if (name.isEmpty || avatar.isEmpty) {
        final a = await _userRepo.getUserProfile(model.authorId);
        if (!mounted) return;
        
        // Build full name for post author
        final fn = a?.firstName?.trim() ?? '';
        final ln = a?.lastName?.trim() ?? '';
        name = (fn.isNotEmpty || ln.isNotEmpty)
            ? '$fn $ln'.trim()
            : (a?.displayName ?? a?.username ?? 'User');
        avatar = a?.avatarUrl ?? '';
      }
      final normUrls = await _normalizeUrls(model.mediaUrls);
      final avatarUrl2 = await _normalizeUrl(avatar);
      final detail = PostDetail(
        id: model.id,
        authorId: model.authorId,
        authorName: name,
        authorAvatarUrl: avatarUrl2,
        createdAt: model.createdAt,
        text: model.text,
        mediaType: _mediaTypeFor(normUrls),
        imageUrls: normUrls,
        videoUrl: _videoUrlFromMedia(normUrls),
        counts: PostCounts(
          likes: model.summary.likes,
          comments: model.summary.comments,
          shares: model.summary.shares,
          reposts: model.summary.reposts,
          bookmarks: model.summary.bookmarks,
        ),
        userReaction: _isLiked ? ReactionType.like : null,
        isBookmarked: _isBookmarked,
        comments: _post?.comments ?? const [],
      );
      if (!mounted) return;
      setState(() {
        _post = detail;
      });
      // Update cache
      if (widget.postId != null) {
        _updateCache(widget.postId!, detail, _comments);
      }
    });
  }

  void _subscribeToComments(String id) {
    _commentsSub?.cancel();
    _commentsSub = _commentRepo.commentsStream(postId: id, limit: 200).listen((list) async {
      final uids = list.map((m) => m.authorId).toSet().toList();
      final profiles = await _userRepo.getUsers(uids);
      final byId = {for (final p in profiles) p.uid: p};
      
      // Check which comments the user has liked
      final likedCommentIds = <String>{};
      for (final m in list) {
        final isLiked = await _commentRepo.hasUserLikedComment(m.id);
        if (isLiked) likedCommentIds.add(m.id);
      }
      
      final allComments = list.map((m) {
        final u = byId[m.authorId];
        // Build full name for comment author
        final firstName = u?.firstName?.trim() ?? '';
        final lastName = u?.lastName?.trim() ?? '';
        final fullName = (firstName.isNotEmpty || lastName.isNotEmpty)
            ? '$firstName $lastName'.trim()
            : (u?.displayName ?? u?.username ?? 'User');
        
        return Comment(
          id: m.id,
          userId: m.authorId,
          userName: fullName,
          userAvatarUrl: (u?.avatarUrl ?? ''),
          text: m.text,
          createdAt: m.createdAt,
          likesCount: m.likesCount,
          isLikedByUser: likedCommentIds.contains(m.id),
          replies: const [],
          parentCommentId: m.parentCommentId,
        );
      }).toList();
      
      // Build tree structure
      final comments = _buildCommentTree(allComments);
      
      if (!mounted) return;
      setState(() {
        _comments = comments;
      });
      // Update cache
      if (_post != null && widget.postId != null) {
        _updateCache(widget.postId!, _post!, comments);
      }
    });
  }

  Future<void> _loadComments() async {
    if (_post == null) return;
    setState(() {
      _loadingComments = true;
    });
    try {
      final list = await _commentRepo.getComments(postId: _post!.id, limit: 200);
      final uids = list.map((m) => m.authorId).toSet().toList();
      final profiles = await _userRepo.getUsers(uids);
      final byId = {for (final p in profiles) p.uid: p};
      
      // Check which comments the user has liked
      final likedCommentIds = <String>{};
      for (final m in list) {
        final isLiked = await _commentRepo.hasUserLikedComment(m.id);
        if (isLiked) likedCommentIds.add(m.id);
      }
      
      final allComments = list.map((m) {
        final u = byId[m.authorId];
        // Build full name for comment author
        final firstName = u?.firstName?.trim() ?? '';
        final lastName = u?.lastName?.trim() ?? '';
        final fullName = (firstName.isNotEmpty || lastName.isNotEmpty)
            ? '$firstName $lastName'.trim()
            : (u?.displayName ?? u?.username ?? 'User');
        
        return Comment(
          id: m.id,
          userId: m.authorId,
          userName: fullName,
          userAvatarUrl: (u?.avatarUrl ?? ''),
          text: m.text,
          createdAt: m.createdAt,
          likesCount: m.likesCount,
          isLikedByUser: likedCommentIds.contains(m.id),
          replies: const [],
          parentCommentId: m.parentCommentId,
        );
      }).toList();
      
      // Build tree structure
      final comments = _buildCommentTree(allComments);
      
      if (!mounted) return;
      setState(() {
        _comments = comments;
      });
      // Update cache
      if (_post != null && widget.postId != null) {
        _updateCache(widget.postId!, _post!, comments);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('post.load_comments_failed')}: ${_toError(e)}',
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
  
  List<Comment> _buildCommentTree(List<Comment> allComments) {
    final List<Comment> topLevelComments = [];
    final Map<String, List<Comment>> repliesMap = {};
    
    for (final comment in allComments) {
      if (comment.parentCommentId == null || comment.parentCommentId!.isEmpty) {
        topLevelComments.add(comment);
      } else {
        repliesMap.putIfAbsent(comment.parentCommentId!, () => []).add(comment);
      }
    }
    
    Comment attachReplies(Comment comment) {
      final replies = repliesMap[comment.id] ?? [];
      if (replies.isEmpty) return comment;
      final nestedReplies = replies.map((r) => attachReplies(r)).toList();
      nestedReplies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return comment.copyWith(replies: nestedReplies);
    }
    
    final result = topLevelComments.map((c) => attachReplies(c)).toList();
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  /// Handle comment like events from other parts of the app
  void _onCommentLikeEvent(CommentLikeEvent event) {
    if (!mounted) return;
    
    bool updateInTree(List<Comment> items) {
      for (int i = 0; i < items.length; i++) {
        if (items[i].id == event.commentId) {
          items[i] = items[i].copyWith(
            isLikedByUser: event.isLiked,
            likesCount: event.likesCount,
          );
          return true;
        }
        final children = List<Comment>.from(items[i].replies);
        if (updateInTree(children)) {
          items[i] = items[i].copyWith(replies: children);
          return true;
        }
      }
      return false;
    }
    
    setState(() {
      updateInTree(_comments);
    });
  }

  /// Add a reply to the comment tree (for optimistic updates)
  bool _addReplyToTree(List<Comment> comments, String parentId, Comment reply) {
    for (int i = 0; i < comments.length; i++) {
      if (comments[i].id == parentId) {
        final updatedReplies = List<Comment>.from(comments[i].replies)..add(reply);
        comments[i] = comments[i].copyWith(replies: updatedReplies);
        return true;
      }
      // Check nested replies
      final nestedReplies = List<Comment>.from(comments[i].replies);
      if (_addReplyToTree(nestedReplies, parentId, reply)) {
        comments[i] = comments[i].copyWith(replies: nestedReplies);
        return true;
      }
    }
    return false;
  }

  void _toggleReplies(String commentId) {
    setState(() {
      _showRepliesMap[commentId] = !(_showRepliesMap[commentId] ?? false);
    });
  }

  void _startReply(String commentId, String userName, {String? parentCommentId}) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUserName = userName;
      _isReplyingToReply = parentCommentId != null;
      _replyingToParentId = parentCommentId;
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUserName = null;
      _isReplyingToReply = false;
      _replyingToParentId = null;
    });
  }

  Future<void> _toggleCommentLike(Comment comment) async {
    // Optimistic update
    void applyLocal(bool liked) {
      bool updateInTree(List<Comment> items) {
        for (int i = 0; i < items.length; i++) {
          if (items[i].id == comment.id) {
            final newCount = (items[i].likesCount + (liked ? 1 : -1)).clamp(0, 1 << 30);
            items[i] = items[i].copyWith(
              isLikedByUser: liked,
              likesCount: newCount,
            );
            return true;
          }
          final children = List<Comment>.from(items[i].replies);
          final updated = updateInTree(children);
          if (updated) {
            items[i] = items[i].copyWith(replies: children);
            return true;
          }
        }
        return false;
      }
      setState(() {
        updateInTree(_comments);
      });
    }

    final willLike = !comment.isLikedByUser;
    final newCount = (comment.likesCount + (willLike ? 1 : -1)).clamp(0, 1 << 30);
    applyLocal(willLike);
    
    // Emit event to sync across app
    CommentEvents.emitLike(CommentLikeEvent(
      commentId: comment.id,
      isLiked: willLike,
      likesCount: newCount,
    ));

    try {
      if (willLike) {
        await _commentRepo.likeComment(comment.id);
      } else {
        await _commentRepo.unlikeComment(comment.id);
      }
    } catch (_) {
      applyLocal(!willLike);
      // Emit rollback event
      CommentEvents.emitLike(CommentLikeEvent(
        commentId: comment.id,
        isLiked: !willLike,
        likesCount: comment.likesCount,
      ));
    }
  }

  Future<void> _deleteComment(Comment comment) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 179)
        : Colors.black.withValues(alpha: 179);

    final okPressed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          'Delete comment?',
          style: GoogleFonts.inter(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This will remove the comment${comment.replies.isNotEmpty ? ' and its replies' : ''}.',
          style: GoogleFonts.inter(color: subtitleColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: subtitleColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );

    if (okPressed != true) return;

    try {
      await _commentRepo.deleteComment(comment.id);
      await _loadComments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Comment deleted', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
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
    final isOwnPost = _currentUserId != null && _post!.authorId == _currentUserId;
    PostOptionsMenu.show(
      context,
      authorName: _post!.authorName,
      postId: _post!.id,
      authorId: _post!.authorId,
      isOwnPost: isOwnPost,
      onReport: () {},
      onMute: () => _handleMute(),
      onBlock: () => _handleBlock(),
      onDelete: isOwnPost ? _deletePost : null,
      position: const Offset(16, 120),
    );
  }

  Future<void> _handleMute() async {
    if (_post == null || _post!.authorId.isEmpty) return;
    
    try {
      final muteRepo = context.read<MuteRepository>();
      await muteRepo.muteUser(
        mutedUid: _post!.authorId,
        mutedUsername: _post!.authorName,
        mutedAvatarUrl: _post!.authorAvatarUrl,
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_post!.authorName} ${Provider.of<LanguageProvider>(context, listen: false).t('post.user_muted')}', style: GoogleFonts.inter()),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Provider.of<LanguageProvider>(context, listen: false).t('post.mute_failed'), style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleBlock() async {
    if (_post == null || _post!.authorId.isEmpty) return;
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${Provider.of<LanguageProvider>(context, listen: false).t('post.block_title')} ${_post!.authorName}?', style: GoogleFonts.inter()),
        content: Text(
          Provider.of<LanguageProvider>(context, listen: false).t('post.block_message'),
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(Provider.of<LanguageProvider>(context, listen: false).t('common.cancel'), style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(Provider.of<LanguageProvider>(context, listen: false).t('post.block_title'), style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final blockRepo = context.read<BlockRepository>();
      await blockRepo.blockUser(
        blockedUid: _post!.authorId,
        blockedUsername: _post!.authorName,
        blockedAvatarUrl: _post!.authorAvatarUrl,
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_post!.authorName} ${Provider.of<LanguageProvider>(context, listen: false).t('post.user_blocked')}', style: GoogleFonts.inter()),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Provider.of<LanguageProvider>(context, listen: false).t('post.block_failed'), style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deletePost() async {
    if (_post == null) return;
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(Provider.of<LanguageProvider>(context, listen: false).t('post.delete_post_title'), style: GoogleFonts.inter()),
        content: Text(
          Provider.of<LanguageProvider>(context, listen: false).t('post.delete_post_message'),
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(Provider.of<LanguageProvider>(context, listen: false).t('common.cancel'), style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(Provider.of<LanguageProvider>(context, listen: false).t('common.delete'), style: GoogleFonts.inter(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _postRepo.deletePost(_post!.id);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(Provider.of<LanguageProvider>(context, listen: false).t('post.delete_success'), style: GoogleFonts.inter()),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('post.delete_failed')}: ${_toError(e)}', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
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
        // Track like analytics
        _trackLike(postId, original.authorId);
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
        // Save to bookmarks collection
        if (!mounted) return;
        final bookmarkRepo = context.read<BookmarkRepository>();
        await bookmarkRepo.bookmarkPost(
          postId: postId,
          title: original.text.length > 100 ? original.text.substring(0, 100) : original.text,
          authorName: original.authorName,
          coverUrl: original.imageUrls.isNotEmpty ? original.imageUrls.first : null,
        );
        // Track bookmark analytics
        _trackBookmark(postId, original.authorId);
      } else {
        await _postRepo.unbookmarkPost(postId);
        // Remove from bookmarks collection
        if (!mounted) return;
        final bookmarkRepo = context.read<BookmarkRepository>();
        await bookmarkRepo.removeBookmarkByItem(postId, BookmarkType.post);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _post = original;
        _isBookmarked = !willBookmark;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('post.bookmark_failed')}: ${_toError(e)}',
              style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showShareOptions() {
    // Track share analytics when share dialog is opened
    if (_post != null) {
      _trackShare(_post!.id, _post!.authorId);
    }
    
    ShareBottomSheet.show(
      context,
      onStories: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(context, listen: false).t('post.shared_stories'), style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      },
      onCopyLink: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(Provider.of<LanguageProvider>(context, listen: false).t('common.link_copied'), style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF9E9E9E),
          ),
        );
      },
      onTelegram: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(context, listen: false).t('post.shared_telegram'), style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF0088CC),
          ),
        );
      },
      onFacebook: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(context, listen: false).t('post.shared_facebook'), style: GoogleFonts.inter()),
            backgroundColor: const Color(0xFF1877F2),
          ),
        );
      },
      onMore: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(context, listen: false).t('post.more_share'), style: GoogleFonts.inter()),
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

  Future<void> _submitComment() async {
    if (_post == null) return;
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    // Handle reply with @mention for nested replies
    String finalText = text;
    String? parentId;
    if (_replyingToCommentId != null) {
      if (_isReplyingToReply && _replyingToUserName != null) {
        if (!text.startsWith('@$_replyingToUserName')) {
          finalText = '@$_replyingToUserName $text';
        }
      }
      parentId = _replyingToParentId ?? _replyingToCommentId;
    }

    // Get current user info for optimistic update
    final currentUserId = _currentUserId ?? '';
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    
    // Optimistic update - add comment immediately
    final optimisticComment = Comment(
      id: tempId,
      userId: currentUserId,
      userName: 'You', // Will be replaced on refresh
      userAvatarUrl: '',
      text: finalText,
      createdAt: DateTime.now(),
      likesCount: 0,
      isLikedByUser: false,
      replies: const [],
      parentCommentId: parentId,
    );

    // Add to UI immediately
    setState(() {
      if (parentId != null) {
        // Add as reply to parent comment
        _addReplyToTree(_comments, parentId, optimisticComment);
        _showRepliesMap[parentId] = true; // Auto-expand to show new reply
      } else {
        // Add as top-level comment
        _comments.add(optimisticComment);
      }
    });

    _commentController.clear();
    _cancelReply();
    _commentFocusNode.unfocus();

    try {
      await _commentRepo.createComment(postId: _post!.id, text: finalText, parentCommentId: parentId);
      // Track comment analytics
      _trackComment(_post!.id, _post!.authorId);
      // Refresh to get real comment with proper ID and user info
      await _loadComments();

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
          content: Text(Provider.of<LanguageProvider>(context, listen: false).t('post.comment_posted'), style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('post.comment_failed')}: ${_toError(e)}',
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
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: _buildPostCard(isDark, showPreviewComments: true),
          ),
        ),
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
                    hintText: Provider.of<LanguageProvider>(context, listen: false).t('common.write_comment'),
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
                        Text(Provider.of<LanguageProvider>(context, listen: false).t('post.comments'),
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
                                  return CommentWidget(
                                    comment: c,
                                    isDarkMode: Theme.of(context).brightness == Brightness.dark,
                                    currentUserId: _currentUserId ?? '',
                                    showReplies: _showRepliesMap[c.id] ?? false,
                                    onLike: (comment) => _toggleCommentLike(comment),
                                    onReply: (comment) => _startReply(comment.id, comment.userName),
                                    onReplyWithParent: (comment, parentId) => _startReply(comment.id, comment.userName, parentCommentId: parentId),
                                    onDelete: (comment) => _deleteComment(comment),
                                    onShowReplies: c.replies.isNotEmpty
                                        ? () => _toggleReplies(c.id)
                                        : null,
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
                                  hintText: Provider.of<LanguageProvider>(context, listen: false).t('common.write_comment'),
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
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      width: double.infinity,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0) : Colors.black.withValues(alpha: 0.05),
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
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    navigateToUserProfile(
                      context: context,
                      userId: _post!.authorId,
                      userName: _post!.authorName,
                      userAvatarUrl: _post!.authorAvatarUrl,
                      userBio: '',
                    );
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: _post!.authorAvatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(_post!.authorAvatarUrl)
                        : null,
                    backgroundColor: const Color(0xFFBFAE01),
                    child: _post!.authorAvatarUrl.isEmpty
                        ? Text(
                            _post!.authorName.isNotEmpty ? _post!.authorName[0].toUpperCase() : 'U',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      navigateToUserProfile(
                        context: context,
                        userId: _post!.authorId,
                        userName: _post!.authorName,
                        userAvatarUrl: _post!.authorAvatarUrl,
                        userBio: '',
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _post!.authorName,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
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
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_post!.text.isNotEmpty) ...[
              ReadMoreText(
                _showTranslation ? (_translatedText ?? _post!.text) : _post!.text,
                trimMode: TrimMode.Length,
                trimLength: 300,
                colorClickableText: const Color(0xFFBFAE01),
                trimCollapsedText: 'Read more',
                trimExpandedText: 'Read less',
                style: GoogleFonts.inter(fontSize: 16, color: isDark ? Colors.white : Colors.black),
                moreStyle: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xFFBFAE01),
                  fontWeight: FontWeight.w500,
                ),
                lessStyle: GoogleFonts.inter(
                  fontSize: 16,
                  color: const Color(0xFFBFAE01),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              // Only show translate button if translation is enabled in settings
              if (context.watch<LanguageProvider>().postTranslationEnabled)
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
              const SizedBox(height: 16),
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
                  useSharedController: true, // Seamless transition from home feed
                ),
              const SizedBox(height: 8),
            ],
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 8),
              color: const Color(0xFF666666).withAlpha(76),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: _toggleLike,
                  child: Row(
                    children: [
                      Icon(
                        _isLiked
                            ? Ionicons.heart
                            : Ionicons.heart_outline,
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
                // Comment count (no tap action - comments shown below)
                Row(
                  children: [
                    const Icon(
                        Ionicons.chatbubble_outline,
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
                const SizedBox(width: 20),
                GestureDetector(
                  onTap: _showShareOptions,
                  child: Row(
                    children: [
                      const Icon(
                        Ionicons.arrow_redo_outline,
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
                      Ionicons.repeat_outline,
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
                        _isBookmarked ? Ionicons.bookmark : Ionicons.bookmark_outline,
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
            const SizedBox(height: 20),
            if (showPreviewComments) ...[
              if (_loadingComments)
                const Center(child: CircularProgressIndicator())
              else if (_comments.isNotEmpty) ...[
                ..._comments.map(
                  (comment) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: CommentWidget(
                      comment: comment,
                      isDarkMode: Theme.of(context).brightness == Brightness.dark,
                      currentUserId: _currentUserId ?? '',
                      showReplies: _showRepliesMap[comment.id] ?? false,
                      onLike: (c) => _toggleCommentLike(c),
                      onReply: (c) => _startReply(c.id, c.userName),
                      onReplyWithParent: (c, parentId) => _startReply(c.id, c.userName, parentCommentId: parentId),
                      onDelete: (c) => _deleteComment(c),
                      onShowReplies: comment.replies.isNotEmpty
                          ? () => _toggleReplies(comment.id)
                          : null,
                    ),
                  ),
                ),
                // Comments are displayed inline, no "View all" button needed
              ],
            ],
          ],
        ),
      ),
    );
  }
}