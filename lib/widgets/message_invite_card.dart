import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../repositories/firebase/firebase_invitation_repository.dart';
import '../repositories/interfaces/invitation_repository.dart';

class MessageInviteCard extends StatefulWidget {
  final String receiverId;
  final String fullName;
  final String bio;
  final String avatarUrl;
  final String coverUrl;
  final VoidCallback onClose;
  final Function(InvitationModel)? onInvitationSent;

  const MessageInviteCard({
    super.key,
    required this.receiverId,
    required this.fullName,
    required this.bio,
    required this.avatarUrl,
    required this.coverUrl,
    required this.onClose,
    this.onInvitationSent,
  });

  @override
  State<MessageInviteCard> createState() => _MessageInviteCardState();
}

class _MessageInviteCardState extends State<MessageInviteCard> {
  final TextEditingController _messageController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendInvitation() async {
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message required', style: GoogleFonts.inter()),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final message = _messageController.text.trim();
      final user = fb.FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please sign in to send invitations', style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final repo = FirebaseInvitationRepository();
      final id = await repo.createInvitation(
        fromUserId: user.uid,
        toUserId: widget.receiverId,
        message: message,
      );

      // Build a minimal InvitationModel for callback compatibility
      final invitation = InvitationModel(
        id: id,
        fromUserId: user.uid,
        toUserId: widget.receiverId,
        message: message,
        status: 'pending',
        conversationId: null,
        createdAt: DateTime.now(),
        respondedAt: null,
        sender: null,
        receiver: null,
      );

      if (mounted) {
        widget.onInvitationSent?.call(invitation);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Invitation sent successfully!',
              style: GoogleFonts.inter(),
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );

        // Close after a short delay
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          widget.onClose();
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to send invitation';
        if (e.toString().contains('invitation_already_exists')) {
          errorMessage =
              'An invitation already exists between you and this user';
        } else if (e.toString().contains('receiver_not_found')) {
          errorMessage = 'User not found';
        } else if (e.toString().contains('cannot_invite_self')) {
          errorMessage = 'You cannot send an invitation to yourself';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage, style: GoogleFonts.inter()),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF666666);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Card dimensions - responsive
    final cardWidth = (screenWidth * 0.9).clamp(300.0, 400.0);

    return Center(
      child: Container(
        width: cardWidth,
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.75,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Close button at top right
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 12),
                  child: GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Avatar - centered and prominent
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFBFAE01),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFBFAE01).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: widget.avatarUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: Icon(
                        Icons.person,
                        color: secondaryTextColor,
                        size: 50,
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: Icon(
                        Icons.person,
                        color: secondaryTextColor,
                        size: 50,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // User name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  widget.fullName,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Bio
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  widget.bio.isNotEmpty ? widget.bio : 'No bio available',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: secondaryTextColor,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Divider
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                height: 1,
                color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
              ),
              
              const SizedBox(height: 24),
              
              // "Send Connection Request" label
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Send Connection Request',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Message input field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: _messageController,
                  minLines: 3,
                  maxLines: 4,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Write a message to introduce yourself...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: secondaryTextColor.withValues(alpha: 0.6),
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: Color(0xFFBFAE01),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Send button - full width
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendInvitation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBFAE01),
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: const Color(0xFFBFAE01).withValues(alpha: 0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Send Invitation',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
