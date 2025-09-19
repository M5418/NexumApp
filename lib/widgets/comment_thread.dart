import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/comment.dart';

class CommentThread extends StatefulWidget {
  final Comment comment;
  final int depth;
  final bool isFirstReply;
  final Function(String commentId)? onReply;
  final Function(String commentId)? onLike;

  const CommentThread({
    super.key,
    required this.comment,
    this.depth = 0,
    this.isFirstReply = false,
    this.onReply,
    this.onLike,
  });

  @override
  State<CommentThread> createState() => _CommentThreadState();
}

class _CommentThreadState extends State<CommentThread> {
  late bool _isLiked;
  late int _likeCount;

  String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 0) return '${difference.inDays}d';
    if (difference.inHours > 0) return '${difference.inHours}h';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m';
    return 'now';
  }

  @override
  void initState() {
    super.initState();
    _isLiked = widget.comment.isLikedByUser;
    _likeCount = widget.comment.likesCount;
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      if (_isLiked) {
        _likeCount++;
      } else {
        _likeCount--;
      }
    });
    widget.onLike?.call(widget.comment.id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indentation and connector line for replies
            if (widget.depth > 0) ...[
              SizedBox(
                width: (widget.depth * 20).toDouble(),
                height: 60,
                child: Stack(
                  children: [
                    // Vertical connector line
                    Positioned(
                      left: 10,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 1,
                        color: const Color(0xFF666666).withValues(alpha: 51),
                      ),
                    ),
                    // Horizontal connector line
                    Positioned(
                      left: 10,
                      top: 30,
                      child: Container(
                        width: (widget.depth * 20 - 10).toDouble(),
                        height: 1,
                        color: const Color(0xFF666666).withValues(alpha: 51),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: DecorationImage(
                  image: CachedNetworkImageProvider(
                    widget.comment.userAvatarUrl,
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Comment content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and time
                  Row(
                    children: [
                      Text(
                        widget.comment.userName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(widget.comment.createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Comment text
                  Text(
                    widget.comment.text,
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.black),
                  ),

                  const SizedBox(height: 8),

                  // Reply button
                  GestureDetector(
                    onTap: () => widget.onReply?.call(widget.comment.id),
                    child: Text(
                      'Reply',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF666666),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Like button and count
            Column(
              children: [
                GestureDetector(
                  onTap: _toggleLike,
                  child: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    size: 18,
                    color: _isLiked
                        ? const Color(0xFFBFAE01)
                        : const Color(0xFF666666),
                  ),
                ),
                if (_likeCount > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    _likeCount.toString(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF666666),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Replies
        if (widget.comment.replies.isNotEmpty)
          ...widget.comment.replies.asMap().entries.map(
            (entry) => CommentThread(
              comment: entry.value,
              depth: widget.depth + 1,
              isFirstReply:
                  entry.key == 0, // Only first reply gets connector line
              onReply: widget.onReply,
              onLike: widget.onLike,
            ),
          ),
      ],
    );
  }
}
