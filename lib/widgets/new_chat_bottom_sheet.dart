import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/message.dart';
import '../chat_page.dart';
import '../conversations_page.dart';
import '../core/users_api.dart';
import '../core/conversations_api.dart';

class NewChatBottomSheet extends StatefulWidget {
  final bool isDarkMode;
  final List<UserItem> availableUsers;

  const NewChatBottomSheet({
    super.key,
    required this.isDarkMode,
    required this.availableUsers,
  });

  @override
  State<NewChatBottomSheet> createState() => _NewChatBottomSheetState();
}

class _NewChatBottomSheetState extends State<NewChatBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<UserItem> _filteredUsers = [];
  bool _loadingUsers = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _filteredUsers = widget.availableUsers;
    _searchController.addListener(_filterUsers);
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = widget.availableUsers;
      } else {
        _filteredUsers = widget.availableUsers
            .where(
              (user) =>
                  user.name.toLowerCase().contains(query) ||
                  user.bio.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  Future<void> _loadUsers() async {
    try {
      setState(() {
        _loadingUsers = true;
        _error = null;
      });
      final api = UsersApi();
      final raw = await api.list();
      final users = raw.map((u) {
        final id = (u['id'] ?? '').toString();
        final name = (u['name'] ?? 'User').toString();
        final avatarUrl = u['avatarUrl']?.toString() ?? '';
        final bio = (u['bio'] ?? '').toString();
        return UserItem(
          id: id,
          name: name,
          avatarUrl: avatarUrl.isEmpty ? '' : avatarUrl,
          bio: bio,
          isOnline: false,
          mutualConnections: 0,
        );
      }).toList();
      setState(() {
        _filteredUsers = users;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  void _startNewChat(UserItem user) async {
    final ctx = context;
    try {
      Navigator.pop(ctx);
      if (ctx.mounted) {
        // Convert UserItem to ChatUser for navigation
        final chatUser = ChatUser(
          id: user.id,
          name: user.name,
          avatarUrl: user.avatarUrl,
          isOnline: user.isOnline,
        );

        final convApi = ConversationsApi();
        convApi
            .createOrGet(user.id)
            .then((convId) {
              if (ctx.mounted) {
                Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (ctx) => ChatPage(
                      otherUser: chatUser,
                      isDarkMode: widget.isDarkMode,
                      conversationId: convId,
                    ),
                  ),
                );
              }
            })
            .catchError((e) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Failed to start chat: $e')),
                );
              }
            });
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(
          ctx,
        ).showSnackBar(SnackBar(content: Text('Failed to start chat: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF666666).withValues(alpha: 128),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Start New Chat',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: widget.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: widget.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Container(
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(
                  color: widget.isDarkMode ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF666666)),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF666666),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),

          // Users list
          Expanded(
            child: _filteredUsers.isEmpty
                ? Center(
                    child: _loadingUsers
                        ? const CircularProgressIndicator()
                        : Text(
                            _error != null
                                ? 'Failed to load users'
                                : 'No users found',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: const Color(0xFF666666),
                            ),
                          ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return GestureDetector(
                        onTap: () => _startNewChat(user),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: const Color(
                                  0xFF666666,
                                ).withValues(alpha: 26),
                                width: 0.5,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Avatar with online indicator
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor:
                                        Colors.primaries[index %
                                            Colors.primaries.length],
                                    child: Text(
                                      user.name.substring(0, 1),
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  if (user.isOnline)
                                    Positioned(
                                      right: 2,
                                      bottom: 2,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF34C759),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: widget.isDarkMode
                                                ? const Color(0xFF1C1C1E)
                                                : Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              const SizedBox(width: 12),

                              // User info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: widget.isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user.bio,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        color: const Color(0xFF666666),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${user.mutualConnections} mutual connections',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: const Color(0xFF007AFF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
