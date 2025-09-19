import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MessageInviteCard extends StatefulWidget {
  final String fullName;
  final String bio;
  final String avatarUrl;
  final String coverUrl;
  final VoidCallback onClose;

  const MessageInviteCard({
    super.key,
    required this.fullName,
    required this.bio,
    required this.avatarUrl,
    required this.coverUrl,
    required this.onClose,
  });

  @override
  State<MessageInviteCard> createState() => _MessageInviteCardState();
}

class _MessageInviteCardState extends State<MessageInviteCard> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendInvitation() {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message required', style: GoogleFonts.inter()),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Show success message and close
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Invitation sent', style: GoogleFonts.inter()),
        duration: const Duration(seconds: 2),
      ),
    );
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.black : Colors.white;
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth * 0.9).clamp(0.0, 360.0);

    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF666666).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 16),

          // Header with cover image and user info
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: cardColor,
                child: Column(
                  children: [
                    // Cover image with overlapping avatar
                    SizedBox(
                      height:
                          220, // Increased to accommodate overlapping avatar and text
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Cover image
                          ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: CachedNetworkImage(
                              imageUrl: widget.coverUrl,
                              width: double.infinity,
                              height: 140,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: const Color(
                                  0xFF666666,
                                ).withValues(alpha: 0.2),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: const Color(
                                  0xFF666666,
                                ).withValues(alpha: 0.2),
                                child: const Icon(
                                  Icons.image,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ),
                          ),

                          // Avatar overlapping at bottom-left
                          Positioned(
                            left: 20,
                            top: 95, // Position to overlap cover image
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: cardColor, width: 4),
                              ),
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: widget.avatarUrl,
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: const Color(
                                      0xFF666666,
                                    ).withValues(alpha: 0.2),
                                    child: const Icon(
                                      Icons.person,
                                      color: Color(0xFF666666),
                                      size: 40,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        color: const Color(
                                          0xFF666666,
                                        ).withValues(alpha: 0.2),
                                        child: const Icon(
                                          Icons.person,
                                          color: Color(0xFF666666),
                                          size: 40,
                                        ),
                                      ),
                                ),
                              ),
                            ),
                          ),

                          // User info positioned to the right of avatar
                          Positioned(
                            left: 130,
                            top: 125,
                            right: 20,
                            bottom: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  widget.fullName,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.bio,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xFF666666),
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Message input field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Stack(
              children: [
                TextField(
                  controller: _messageController,
                  minLines: 3,
                  maxLines: 5,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Invitation message (required)',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF666666),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFF666666),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFF666666),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFFBFAE01),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.fromLTRB(16, 16, 60, 16),
                  ),
                ),

                // Send button positioned at bottom-right
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF666666),
                        width: 1,
                      ),
                      color: cardColor,
                    ),
                    child: IconButton(
                      onPressed: _sendInvitation,
                      icon: const Icon(
                        Icons.send,
                        color: Color(0xFF666666),
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
