import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/comment.dart';
import '../utils/profile_navigation.dart';
import 'report_bottom_sheet.dart';

class CommentWidget extends StatefulWidget {
  final Comment comment;
  final void Function(Comment comment)? onLike;
  final void Function(Comment comment)? onReply;
  final void Function(Comment comment)? onDelete;
  final VoidCallback? onShowReplies;
  final bool showReplies;
  final int depth;
  final bool isDarkMode;
  final String currentUserId;

  const CommentWidget({
    super.key,
    required this.comment,
    this.onLike,
    this.onReply,
    this.onDelete,
    this.onShowReplies,
    this.showReplies = false,
    this.depth = 0,
    this.isDarkMode = true,
    required this.currentUserId,
  });

  @override
  State<CommentWidget> createState() => _CommentWidgetState();
}

class _CommentWidgetState extends State<CommentWidget> {
  bool _isExpanded = false;

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  String _formatLikes(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = widget.isDarkMode
        ? Colors.white.withValues(alpha: 179)
        : Colors.black.withValues(alpha: 179);
    final canDelete = widget.comment.userId == widget.currentUserId;

    return Container(
      margin: EdgeInsets.only(left: widget.depth > 0 ? 40.0 : 0, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User avatar
              GestureDetector(
                onTap: () {
                  navigateToUserProfile(
                    context: context,
                    userId: widget.comment.userId,
                    userName: widget.comment.userName,
                    userAvatarUrl: widget.comment.userAvatarUrl,
                    userBio: '',
                  );
                },
                child: CircleAvatar(
                  radius: widget.depth > 0 ? 14 : 18,
                  backgroundImage: NetworkImage(widget.comment.userAvatarUrl),
                ),
              ),

              const SizedBox(width: 12),

              // Comment content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User name and badges
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            navigateToUserProfile(
                              context: context,
                              userId: widget.comment.userId,
                              userName: widget.comment.userName,
                              userAvatarUrl: widget.comment.userAvatarUrl,
                              userBio: '',
                            );
                          },
                          child: Text(
                            widget.comment.userName,
                            style: GoogleFonts.inter(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        if (widget.comment.isCreator) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFBFAE01),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Creator',
                              style: GoogleFonts.inter(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],

                        if (widget.comment.isPinned) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.push_pin, size: 14, color: subtitleColor),
                        ],

                        const Spacer(),

                        Text(
                          _formatTime(widget.comment.createdAt),
                          style: GoogleFonts.inter(
                            color: subtitleColor,
                            fontSize: 12,
                          ),
                        ),

                        PopupMenuButton<String>(
                          color: widget.isDarkMode ? Colors.grey[900] : Colors.white,
                          icon: Icon(Icons.more_vert, size: 18, color: subtitleColor),
                          onSelected: (value) {
                            if (value == 'delete') {
                              widget.onDelete?.call(widget.comment);
                            } else if (value == 'report') {
                              ReportBottomSheet.show(
                                context,
                                targetType: 'comment',
                                targetId: widget.comment.id,
                                authorName: widget.comment.userName,
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            if (canDelete)
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline, size: 18, color: subtitleColor),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Delete',
                                      style: GoogleFonts.inter(
                                        color: textColor,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            PopupMenuItem(
                              value: 'report',
                              child: Row(
                                children: [
                                  Icon(Icons.flag_outlined, size: 18, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Report',
                                    style: GoogleFonts.inter(
                                      color: Colors.red,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Comment text
                    GestureDetector(
                      onTap: () {
                        if (widget.comment.text.length > 100) {
                          setState(() {
                            _isExpanded = !_isExpanded;
                          });
                        }
                      },
                      child: Text(
                        widget.comment.text.isEmpty ? '[deleted]' : widget.comment.text,
                        style: GoogleFonts.inter(
                          color: widget.comment.text.isEmpty ? subtitleColor : textColor,
                          fontSize: 14,
                          height: 1.3,
                          fontStyle: widget.comment.text.isEmpty ? FontStyle.italic : FontStyle.normal,
                        ),
                        maxLines: _isExpanded ? null : 3,
                        overflow: _isExpanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                      ),
                    ),

                    if (widget.comment.text.length > 100 && !_isExpanded)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isExpanded = true;
                          });
                        },
                        child: Text(
                          'Read more',
                          style: GoogleFonts.inter(
                            color: subtitleColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Action buttons
                    Row(
                      children: [
                        // Like button
                        GestureDetector(
                          onTap: () => widget.onLike?.call(widget.comment),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.comment.isLikedByUser
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 16,
                                color: widget.comment.isLikedByUser
                                    ? Colors.red
                                    : subtitleColor,
                              ),
                              if (widget.comment.likesCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  _formatLikes(widget.comment.likesCount),
                                  style: GoogleFonts.inter(
                                    color: subtitleColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(width: 20),

                        // Reply button
                        GestureDetector(
                          onTap: () => widget.onReply?.call(widget.comment),
                          child: Text(
                            'Reply',
                            style: GoogleFonts.inter(
                              color: subtitleColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        if (widget.comment.replies.isNotEmpty) ...[
                          const SizedBox(width: 20),

                          // Show replies button
                          GestureDetector(
                            onTap: widget.onShowReplies,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.showReplies
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: 16,
                                  color: subtitleColor,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${widget.comment.replies.length} ${widget.comment.replies.length == 1 ? 'reply' : 'replies'}',
                                  style: GoogleFonts.inter(
                                    color: subtitleColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Replies
          if (widget.showReplies && widget.comment.replies.isNotEmpty)
            Column(
              children: widget.comment.replies.map((reply) {
                return CommentWidget(
                  comment: reply,
                  depth: widget.depth + 1,
                  isDarkMode: widget.isDarkMode,
                  currentUserId: widget.currentUserId,
                  onLike: widget.onLike,
                  onReply: widget.onReply,
                  onDelete: widget.onDelete,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}