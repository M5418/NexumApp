import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  late List<ShareUser> _users;

  @override
  void initState() {
    super.initState();
    _users = [
      ShareUser(
        id: '1',
        name: '@ava_',
        avatarUrl:
            'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=200&h=200&fit=crop&crop=face',
      ),
      ShareUser(
        id: '2',
        name: '@ava_',
        avatarUrl:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop&crop=face',
      ),
      ShareUser(
        id: '3',
        name: '@luc_',
        avatarUrl:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop&crop=face',
      ),
      ShareUser(
        id: '4',
        name: '@an_',
        avatarUrl:
            'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200&h=200&fit=crop&crop=face',
      ),
      ShareUser(
        id: '5',
        name: '@ada_',
        avatarUrl:
            'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200&h=200&fit=crop&crop=face',
      ),
    ];
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

  void _sendToSelectedUsers() {
    final selectedUsers = _users.where((user) => user.isSelected).toList();
    if (selectedUsers.isNotEmpty) {
      widget.onSendToUsers?.call(selectedUsers, _messageController.text);
      Navigator.pop(context);
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

          // Author info (Shavvya Malik)
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage(
                      'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=200&h=200&fit=crop&crop=face',
                    ),
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
                      'Shavvya Malik',
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
              Icon(Icons.keyboard_arrow_down, color: const Color(0xFF666666)),
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
            child: ListView.builder(
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
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  image: NetworkImage(user.avatarUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
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
