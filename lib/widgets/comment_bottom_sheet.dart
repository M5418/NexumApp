import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/comment.dart';
import '../core/post_events.dart';
import '../repositories/firebase/firebase_comment_repository.dart';
import '../repositories/firebase/firebase_user_repository.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'comment_widget.dart';

class CommentBottomSheet extends StatefulWidget {
  final String postId;
  final List<Comment> comments;
  final bool isDarkMode;
  final String currentUserId;

  // Optional hooks so parent can adjust counts after operations
  final Future<void> Function(String)? onAddComment;
  final Future<void> Function(String, String)? onReplyToComment;

  const CommentBottomSheet({
    super.key,
    required this.postId,
    required this.comments,
    required this.currentUserId,
    this.isDarkMode = true,
    this.onAddComment,
    this.onReplyToComment,
  });

  static void show(
    BuildContext context, {
    required String postId,
    required List<Comment> comments,
    required String currentUserId,
    bool isDarkMode = true,
    Future<void> Function(String)? onAddComment,
    Future<void> Function(String, String)? onReplyToComment,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CommentBottomSheet(
        postId: postId,
        comments: comments,
        currentUserId: currentUserId,
        isDarkMode: isDarkMode,
        onAddComment: onAddComment,
        onReplyToComment: onReplyToComment,
      ),
    );
  }

  @override
  State<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final Map<String, bool> _showRepliesMap = {};

  String? _replyingToCommentId;
  String? _replyingToUserName;

  List<Comment> _comments = [];
  String? _currentUserAvatar;
  String _currentUserName = 'User';

  final FirebaseCommentRepository _commentRepo = FirebaseCommentRepository();
  final FirebaseUserRepository _userRepo = FirebaseUserRepository();
  StreamSubscription<CommentLikeEvent>? _commentLikeSub;

  bool _isLoadingComments = false;

  @override
  void initState() {
    super.initState();
    _comments = widget.comments;
    _loadCurrentUserProfile();
    // Listen for comment like events from other parts of the app
    _commentLikeSub = CommentEvents.stream.listen(_onCommentLikeEvent);
    
    // If opened with empty comments, load them immediately
    if (widget.comments.isEmpty) {
      _loadCommentsInstantly();
    }
  }
  
  Future<void> _loadCommentsInstantly() async {
    setState(() {
      _isLoadingComments = true;
    });
    try {
      final comments = await _loadComments();
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingComments = false;
        });
      }
    }
  }

  Future<void> _loadCurrentUserProfile() async {
    try {
      final currentUserId = fb.FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;
      
      final users = await _userRepo.getUsers([currentUserId]);
      if (users.isNotEmpty && mounted) {
        final u = users.first;
        final firstName = u.firstName?.trim() ?? '';
        final lastName = u.lastName?.trim() ?? '';
        final fullName = (firstName.isNotEmpty || lastName.isNotEmpty)
            ? '$firstName $lastName'.trim()
            : (u.displayName ?? u.username ?? 'User');
        
        setState(() {
          _currentUserAvatar = u.avatarUrl;
          _currentUserName = fullName;
        });
      }
    } catch (e) {
      // Ignore error, will use fallback
    }
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

  @override
  void dispose() {
    _commentLikeSub?.cancel();
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int _totalCommentsCount(List<Comment> list) {
    int total = 0;
    void walk(List<Comment> items) {
      for (final c in items) {
        total++;
        if (c.replies.isNotEmpty) walk(c.replies);
      }
    }

    walk(list);
    return total;
  }

  Future<void> _refresh() async {
    try {
      final latest = await _loadComments();
      if (!mounted) return;
      setState(() {
        _comments = latest;
      });
    } catch (_) {
      // ignore refresh error in UI
    }
  }

  Future<List<Comment>> _loadComments() async {
    final list = await _commentRepo.getComments(postId: widget.postId, limit: 200);
    final uids = list.map((m) => m.authorId).toSet().toList();
    final profiles = await _userRepo.getUsers(uids);
    final byId = {for (final p in profiles) p.uid: p};
    
    // Check which comments the user has liked
    final likedCommentIds = <String>{};
    for (final m in list) {
      final isLiked = await _commentRepo.hasUserLikedComment(m.id);
      if (isLiked) likedCommentIds.add(m.id);
    }
    
    // Convert to Comment objects
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
    
    // Organize into tree structure (top-level comments with nested replies)
    return _buildCommentTree(allComments);
  }
  
  /// Build a tree structure from flat list of comments
  List<Comment> _buildCommentTree(List<Comment> allComments) {
    final Map<String, Comment> commentMap = {};
    final List<Comment> topLevelComments = [];
    final Map<String, List<Comment>> repliesMap = {};
    
    // First pass: create map and separate top-level vs replies
    for (final comment in allComments) {
      commentMap[comment.id] = comment;
      if (comment.parentCommentId == null || comment.parentCommentId!.isEmpty) {
        topLevelComments.add(comment);
      } else {
        repliesMap.putIfAbsent(comment.parentCommentId!, () => []).add(comment);
      }
    }
    
    // Second pass: attach replies to their parent comments
    Comment attachReplies(Comment comment) {
      final replies = repliesMap[comment.id] ?? [];
      if (replies.isEmpty) return comment;
      
      // Recursively attach replies to nested comments
      final nestedReplies = replies.map((r) => attachReplies(r)).toList();
      // Sort replies by creation time
      nestedReplies.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      return comment.copyWith(replies: nestedReplies);
    }
    
    // Build the tree
    final result = topLevelComments.map((c) => attachReplies(c)).toList();
    // Sort top-level comments by creation time
    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    return result;
  }

  /// Add a reply to the comment tree (for optimistic updates)
  bool _addReplyToTree(List<Comment> comments, String parentId, Comment reply) {
    for (int i = 0; i < comments.length; i++) {
      if (comments[i].id == parentId) {
        final updatedReplies = List<Comment>.from(comments[i].replies)..add(reply);
        comments[i] = comments[i].copyWith(replies: updatedReplies);
        return true;
      }
      final nestedReplies = List<Comment>.from(comments[i].replies);
      if (_addReplyToTree(nestedReplies, parentId, reply)) {
        comments[i] = comments[i].copyWith(replies: nestedReplies);
        return true;
      }
    }
    return false;
  }

  /// Remove a comment from the tree (for rollback on failure)
  bool _removeCommentFromTree(List<Comment> comments, String commentId) {
    for (int i = 0; i < comments.length; i++) {
      if (comments[i].id == commentId) {
        comments.removeAt(i);
        return true;
      }
      final nestedReplies = List<Comment>.from(comments[i].replies);
      if (_removeCommentFromTree(nestedReplies, commentId)) {
        comments[i] = comments[i].copyWith(replies: nestedReplies);
        return true;
      }
    }
    return false;
  }

  Future<void> _toggleLike(Comment comment) async {
    // Optimistic update through tree
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
          // try children
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
      // revert on failure
      applyLocal(!willLike);
      // Emit rollback event
      CommentEvents.emitLike(CommentLikeEvent(
        commentId: comment.id,
        isLiked: !willLike,
        likesCount: comment.likesCount,
      ));
    }
  }

  Future<void> _confirmDelete(Comment comment) async {
    final subtitleColor = widget.isDarkMode
        ? Colors.white.withValues(alpha: 179)
        : Colors.black.withValues(alpha: 179);

    final okPressed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDarkMode ? Colors.grey[900] : Colors.white,
        title: Text(
          'Delete comment?',
          style: GoogleFonts.inter(
            color: widget.isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'This will remove the comment${comment.replies.isNotEmpty ? ' and its replies' : ''}.',
          style: GoogleFonts.inter(
            color: subtitleColor,
          ),
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
      await _refresh();
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

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    // For nested replies, prepend @username if replying to a reply
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

    // Optimistic update - add comment immediately
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticComment = Comment(
      id: tempId,
      userId: widget.currentUserId,
      userName: _currentUserName,
      userAvatarUrl: _currentUserAvatar ?? '',
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
        _addReplyToTree(_comments, parentId, optimisticComment);
        _showRepliesMap[parentId] = true;
      } else {
        _comments.add(optimisticComment);
      }
    });

    _commentController.clear();
    _cancelReply();

    try {
      if (_replyingToCommentId != null) {
        if (widget.onReplyToComment != null) {
          await widget.onReplyToComment!.call(parentId!, finalText);
        } else {
          await _commentRepo.createComment(
            postId: widget.postId,
            text: finalText,
            parentCommentId: parentId,
          );
        }
      } else {
        if (widget.onAddComment != null) {
          await widget.onAddComment!.call(finalText);
        } else {
          await _commentRepo.createComment(postId: widget.postId, text: finalText);
        }
      }

      // Refresh to get real comment with proper ID
      await _refresh();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Comment posted!', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      // Remove optimistic comment on failure
      setState(() {
        _removeCommentFromTree(_comments, tempId);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to post comment', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Track if we're replying to a reply (nested) vs a top-level comment
  bool _isReplyingToReply = false;
  String? _replyingToParentId; // The actual parent comment ID for nested replies

  void _startReply(String commentId, String userName, {String? parentCommentId}) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUserName = userName;
      _isReplyingToReply = parentCommentId != null;
      _replyingToParentId = parentCommentId;
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToCommentId = null;
      _replyingToUserName = null;
    });
  }

  void _toggleReplies(String commentId) {
    setState(() {
      _showRepliesMap[commentId] = !(_showRepliesMap[commentId] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isDarkMode ? Colors.black : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = widget.isDarkMode
        ? Colors.white.withValues(alpha: 179)
        : Colors.black.withValues(alpha: 179);

    final totalCount = _totalCommentsCount(_comments);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 16),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: subtitleColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '$totalCount ${totalCount == 1 ? 'comment' : 'comments'}',
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: subtitleColor),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Comments list
          Expanded(
            child: _isLoadingComments
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: subtitleColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No comments yet',
                          style: GoogleFonts.inter(
                            color: subtitleColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to comment!',
                          style: GoogleFonts.inter(
                            color: subtitleColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                      final comment = _comments[index];
                      return CommentWidget(
                        comment: comment,
                        isDarkMode: widget.isDarkMode,
                        currentUserId: widget.currentUserId,
                        showReplies: _showRepliesMap[comment.id] ?? false,
                        onLike: (c) => _toggleLike(c),
                        onReply: (c) => _startReply(c.id, c.userName),
                        onReplyWithParent: (c, parentId) => _startReply(c.id, c.userName, parentCommentId: parentId),
                        onDelete: (c) => _confirmDelete(c),
                        onShowReplies: comment.replies.isNotEmpty
                            ? () => _toggleReplies(comment.id)
                            : null,
                      );
                    },
                  ),
          ),

          // Reply indicator
          if (_replyingToCommentId != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: widget.isDarkMode ? Colors.grey[900] : Colors.grey[100],
              child: Row(
                children: [
                  Icon(Icons.reply, size: 16, color: subtitleColor),
                  const SizedBox(width: 8),
                  Text(
                    'Replying to $_replyingToUserName',
                    style: GoogleFonts.inter(
                      color: subtitleColor,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: Icon(Icons.close, size: 16, color: subtitleColor),
                  ),
                ],
              ),
            ),

          // Comment input
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(
                top: BorderSide(
                  color: widget.isDarkMode
                      ? Colors.grey[800]!
                      : Colors.grey[300]!,
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Current user avatar
                  CircleAvatar(
                    radius: 16,
                    backgroundImage: _currentUserAvatar != null && _currentUserAvatar!.isNotEmpty
                        ? NetworkImage(_currentUserAvatar!)
                        : null,
                    backgroundColor: const Color(0xFFBFAE01),
                    child: _currentUserAvatar == null || _currentUserAvatar!.isEmpty
                        ? Text(
                            _currentUserName.isNotEmpty ? _currentUserName[0].toUpperCase() : 'U',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),

                  const SizedBox(width: 12),

                  // Text input
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isDarkMode
                            ? Colors.grey[900]
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _commentController,
                        focusNode: _focusNode,
                        style: GoogleFonts.inter(
                          color: textColor,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: _replyingToCommentId != null
                              ? 'Reply to $_replyingToUserName...'
                              : 'Add a comment...',
                          hintStyle: GoogleFonts.inter(
                            color: subtitleColor,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Send button with enabled/disabled style
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _commentController,
                    builder: (context, value, _) {
                      final hasText = value.text.trim().isNotEmpty;
                      return GestureDetector(
                        onTap: hasText ? _submitComment : null,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: hasText
                                ? const Color(0xFFBFAE01)
                                : subtitleColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.send,
                            size: 16,
                            color: hasText ? Colors.black : Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}