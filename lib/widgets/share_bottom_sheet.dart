import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cached_network_image/cached_network_image.dart';
import '../repositories/firebase/firebase_user_repository.dart';
import '../repositories/interfaces/follow_repository.dart';
import '../repositories/interfaces/message_repository.dart';

class ShareUser {
  final String id;
  final String name;
  final String avatarUrl;
  bool isSelected;

  ShareUser({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.isSelected = false,
  });
}

class ShareBottomSheet extends StatefulWidget {
  final VoidCallback? onStories;
  final VoidCallback? onCopyLink;
  final VoidCallback? onTelegram;
  final VoidCallback? onFacebook;
  final VoidCallback? onMore;
  final Function(List<ShareUser> selectedUsers, String message)? onSendToUsers;

  const ShareBottomSheet({
    super.key,
    this.onStories,
    this.onCopyLink,
    this.onTelegram,
    this.onFacebook,
    this.onMore,
    this.onSendToUsers,
  });

  @override
  State<ShareBottomSheet> createState() => _ShareBottomSheetState();

  static void show(
    BuildContext context, {
    VoidCallback? onStories,
    VoidCallback? onCopyLink,
    VoidCallback? onTelegram,
    VoidCallback? onFacebook,
    VoidCallback? onMore,
    Function(List<ShareUser> selectedUsers, String message)? onSendToUsers,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ShareBottomSheet(
        onStories: onStories,
        onCopyLink: onCopyLink,
        onTelegram: onTelegram,
        onFacebook: onFacebook,
        onMore: onMore,
        onSendToUsers: onSendToUsers,
      ),
    );
  }
}

class _ShareBottomSheetState extends State<ShareBottomSheet> {
  final TextEditingController _messageController = TextEditingController();
  List<ShareUser> _users = [];
  bool _loading = true;
  String _currentUserName = '';
  String _currentUserAvatar = '';
  
  final FirebaseUserRepository _userRepo = FirebaseUserRepository();

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    try {
      final currentUserId = fb.FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;
      
      // Get repo before async calls
      final followRepo = context.read<FollowRepository>();
      
      // Load current user profile
      final currentUser = await _userRepo.getUserProfile(currentUserId);
      
      // Load connections (people they follow)
      final following = await followRepo.getFollowing(
        userId: currentUserId,
        limit: 50,
      );
      
      // Get user profiles for all connections
      final userIds = following.map((f) => f.followedId).toList();
      if (userIds.isEmpty) {
        setState(() {
          _loading = false;
          _currentUserName = currentUser?.displayName ?? currentUser?.username ?? 'User';
          _currentUserAvatar = currentUser?.avatarUrl ?? '';
        });
        return;
      }
      
      final users = await _userRepo.getUsers(userIds);
      
      if (!mounted) return;
      setState(() {
        _currentUserName = currentUser?.displayName ?? currentUser?.username ?? 'User';
        _currentUserAvatar = currentUser?.avatarUrl ?? '';
        _users = users.map((u) => ShareUser(
          id: u.uid,
          name: u.displayName ?? u.username ?? 'User',
          avatarUrl: u.avatarUrl ?? '',
        )).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _toggleUserSelection(int index) {
    setState(() {
      _users[index].isSelected = !_users[index].isSelected;
    });
  }

  Future<void> _sendToSelectedUsers() async {
    final selectedUsers = _users.where((user) => user.isSelected).toList();
    if (selectedUsers.isEmpty) return;
    
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    
    try {
      final messageRepo = context.read<MessageRepository>();
      
      // Send message to each selected user
      for (final user in selectedUsers) {
        await messageRepo.sendText(
          otherUserId: user.id,
          text: message,
        );
      }
      
      // Call callback if provided
      widget.onSendToUsers?.call(selectedUsers, message);
      
      if (!mounted) return;
      Navigator.pop(context);
      
      // Show success message
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Sent to ${selectedUsers.length} ${selectedUsers.length == 1 ? "person" : "people"}',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to send messages', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? Colors.black : Colors.white;
    final hasSelectedUsers = _users.any((user) => user.isSelected);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 20),

          // Current user info
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: _currentUserAvatar.isNotEmpty
                    ? CachedNetworkImageProvider(_currentUserAvatar)
                    : null,
                backgroundColor: const Color(0xFFBFAE01),
                child: _currentUserAvatar.isEmpty
                    ? Text(
                        _currentUserName.isNotEmpty ? _currentUserName[0].toUpperCase() : 'U',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentUserName.isNotEmpty ? _currentUserName : 'Loading...',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      'Say something about this...',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Message input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Say something about this...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF666666),
                ),
              ),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.black : Colors.black,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Users list
          SizedBox(
            height: 80,
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFBFAE01),
                    ),
                  )
                : _users.isEmpty
                    ? Center(
                        child: Text(
                          'No connections to share with',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF666666),
                          ),
                        ),
                      )
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _users.length,
                        itemBuilder: (context, index) {
                final user = _users[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () => _toggleUserSelection(index),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundImage: user.avatarUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(user.avatarUrl)
                                  : null,
                              backgroundColor: const Color(0xFFBFAE01),
                              child: user.avatarUrl.isEmpty
                                  ? Text(
                                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                                      style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            if (user.isSelected)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.name,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                      },
                    ),
          ),

          const SizedBox(height: 20),

          // Send to selected users button
          if (hasSelectedUsers) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sendToSelectedUsers,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBFAE01),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  'Send to ${_users.where((u) => u.isSelected).length} people',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Share options row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Stories
              _ShareOption(
                icon: Icons.add_circle_outline,
                label: 'Stories',
                backgroundColor: const Color(0xFF4CAF50),
                onTap: widget.onStories,
              ),

              // Copy Link
              _ShareOption(
                icon: Icons.link,
                label: 'Copy Link',
                backgroundColor: const Color(0xFF9E9E9E),
                onTap: widget.onCopyLink,
              ),

              // Telegram
              _ShareOption(
                icon: Icons.send,
                label: 'Telegram',
                backgroundColor: const Color(0xFF0088CC),
                onTap: widget.onTelegram,
              ),

              // Facebook
              _ShareOption(
                icon: Icons.facebook,
                label: 'Facebook',
                backgroundColor: const Color(0xFF1877F2),
                onTap: widget.onFacebook,
              ),

              // More
              _ShareOption(
                icon: Icons.more_horiz,
                label: '...',
                backgroundColor: const Color(0xFF666666),
                onTap: widget.onMore,
              ),
            ],
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final VoidCallback? onTap;

  const _ShareOption({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap?.call();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon container
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: backgroundColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),

          const SizedBox(height: 8),

          // Label
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
