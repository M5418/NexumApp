import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/comment.dart';
import 'comment_widget.dart';

class CommentBottomSheet extends StatefulWidget {
  final String postId;
  final List<Comment> comments;
  final bool isDarkMode;
  final Function(String)? onAddComment;
  final Function(String)? onLikeComment;
  final Function(String, String)? onReplyToComment;

  const CommentBottomSheet({
    super.key,
    required this.postId,
    required this.comments,
    this.isDarkMode = true,
    this.onAddComment,
    this.onLikeComment,
    this.onReplyToComment,
  });

  static void show(
    BuildContext context, {
    required String postId,
    required List<Comment> comments,
    bool isDarkMode = true,
    Function(String)? onAddComment,
    Function(String)? onLikeComment,
    Function(String, String)? onReplyToComment,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CommentBottomSheet(
        postId: postId,
        comments: comments,
        isDarkMode: isDarkMode,
        onAddComment: onAddComment,
        onLikeComment: onLikeComment,
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

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isNotEmpty) {
      if (_replyingToCommentId != null) {
        widget.onReplyToComment?.call(_replyingToCommentId!, text);
      } else {
        widget.onAddComment?.call(text);
      }
      _commentController.clear();
      _cancelReply();
    }
  }

  void _startReply(String commentId, String userName) {
    setState(() {
      _replyingToCommentId = commentId;
      _replyingToUserName = userName;
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
                  '${widget.comments.length} ${widget.comments.length == 1 ? 'comment' : 'comments'}',
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
            child: widget.comments.isEmpty
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
                    itemCount: widget.comments.length,
                    itemBuilder: (context, index) {
                      final comment = widget.comments[index];
                      return CommentWidget(
                        comment: comment,
                        isDarkMode: widget.isDarkMode,
                        showReplies: _showRepliesMap[comment.id] ?? false,
                        onLike: () => widget.onLikeComment?.call(comment.id),
                        onReply: () =>
                            _startReply(comment.id, comment.userName),
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
                  const CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(
                      'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
                    ),
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

                  // Send button
                  GestureDetector(
                    onTap: _submitComment,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _commentController.text.trim().isNotEmpty
                            ? const Color(0xFFBFAE01)
                            : subtitleColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.send,
                        size: 16,
                        color: _commentController.text.trim().isNotEmpty
                            ? Colors.black
                            : Colors.white,
                      ),
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
}
