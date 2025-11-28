import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/message.dart';
import '../repositories/firebase/firebase_user_repository.dart';
import 'package:provider/provider.dart';
import '../repositories/interfaces/conversation_repository.dart';

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
            .where((user) =>
                user.name.toLowerCase().contains(query) ||
                user.bio.toLowerCase().contains(query))
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
      final repo = FirebaseUserRepository();
      final models = await repo.getSuggestedUsers(limit: 50);
      final users = models.map((m) => UserItem(
        id: m.uid,
        name: (m.displayName ?? m.username ?? 'User'),
        avatarUrl: m.avatarUrl ?? '',
        bio: m.bio ?? '',
        isOnline: false,
        mutualConnections: 0,
      )).toList();
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
      final chatUser = ChatUser(
        id: user.id,
        name: user.name,
        avatarUrl: user.avatarUrl,
        isOnline: user.isOnline,
      );

      final convRepo = ctx.read<ConversationRepository>();
      final convId = await convRepo.createOrGet(user.id);

      if (ctx.mounted) {
        Navigator.pop(ctx, {
          'conversationId': convId,
          'user': chatUser,
        });
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx)
            .showSnackBar(SnackBar(content: Text('Failed to start chat: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final screen = MediaQuery.of(context).size;
    final isMobile = screen.width < 600;
    final cardMaxWidth = screen.width >= 1280 ? 720.0 : 560.0;
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    // Mobile: bottom sheet, Desktop: centered popup
    if (isMobile) {
      return _buildMobileBottomSheet(cardColor, textColor);
    }

    return SafeArea(
      child: SizedBox.expand(
        child: Stack(
          children: [
            // Dimmed backdrop
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
              ),
            ),

            // Centered modal card
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: cardMaxWidth,
                  // take up to ~70% of height
                  maxHeight: screen.height * 0.8,
                ),
                child: Material(
                  color: cardColor,
                  elevation: 12,
                  borderRadius: BorderRadius.circular(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                          child: Row(
                            children: [
                              Text(
                                'Start New Chat',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: Icon(Icons.close, color: textColor),
                                tooltip: 'Close',
                              ),
                            ],
                          ),
                        ),

                        // Search bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2C2C2E)
                                  : const Color(0xFFF2F2F7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: _searchController,
                              style: GoogleFonts.inter(color: textColor),
                              decoration: InputDecoration(
                                hintText: 'Search users...',
                                hintStyle: GoogleFonts.inter(
                                  color: const Color(0xFF666666),
                                ),
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Color(0xFF666666),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Content
                        Expanded(
                          child: _loadingUsers
                              ? const Center(child: CircularProgressIndicator())
                              : _filteredUsers.isEmpty
                                  ? Center(
                                      child: Text(
                                        _error != null
                                            ? 'Failed to load users'
                                            : 'No users found',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          color: const Color(0xFF666666),
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      itemCount: _filteredUsers.length,
                                      separatorBuilder: (_, __) => Divider(
                                        height: 1,
                                        thickness: 0.5,
                                        color: const Color(0xFF666666)
                                            .withValues(alpha: 0.10),
                                      ),
                                      itemBuilder: (context, index) {
                                        final user = _filteredUsers[index];
                                        return InkWell(
                                          onTap: () => _startNewChat(user),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 10,
                                            ),
                                            child: Row(
                                              children: [
                                                // Avatar with online indicator
                                                Stack(
                                                  children: [
                                                    _buildAvatar(user, index),
                                                    if (user.isOnline)
                                                      Positioned(
                                                        right: 2,
                                                        bottom: 2,
                                                        child: Container(
                                                          width: 12,
                                                          height: 12,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: const Color(
                                                                0xFF34C759),
                                                            shape:
                                                                BoxShape.circle,
                                                            border: Border.all(
                                                              color: isDark
                                                                  ? cardColor
                                                                  : Colors
                                                                      .white,
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
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        user.name,
                                                        style:
                                                            GoogleFonts.inter(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: textColor,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                          height: 2),
                                                      Text(
                                                        user.bio,
                                                        style:
                                                            GoogleFonts.inter(
                                                          fontSize: 14,
                                                          color: const Color(
                                                              0xFF666666),
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      const SizedBox(
                                                          height: 2),
                                                      Text(
                                                        '${user.mutualConnections} mutual connections',
                                                        style:
                                                            GoogleFonts.inter(
                                                          fontSize: 12,
                                                          color: const Color(
                                                              0xFF007AFF),
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
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBottomSheet(Color cardColor, Color textColor) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.75, // Max 75% of screen height
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
            child: Row(
              children: [
                Text(
                  'Start New Chat',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: textColor),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: widget.isDarkMode
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  hintStyle: GoogleFonts.inter(
                    color: const Color(0xFF666666),
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF666666),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          // Content
          Flexible(
            child: _loadingUsers
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Text(
                          _error != null
                              ? 'Failed to load users'
                              : 'No users found',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: const Color(0xFF666666),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: _filteredUsers.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          thickness: 0.5,
                          color: const Color(0xFF666666).withValues(alpha: 0.10),
                        ),
                        itemBuilder: (context, index) {
                          final user = _filteredUsers[index];
                          return InkWell(
                            onTap: () => _startNewChat(user),
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  _buildAvatar(user, index),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user.name,
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
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

  Widget _buildAvatar(UserItem user, int index) {
    if (user.avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(user.avatarUrl),
        backgroundColor: Colors.transparent,
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.primaries[index % Colors.primaries.length],
      child: Text(
        user.name.isNotEmpty ? user.name.substring(0, 1).toUpperCase() : '?',
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

// Local lightweight user model for the selector
class UserItem {
  final String id;
  final String name;
  final String avatarUrl;
  final String bio;
  final bool isOnline;
  final int mutualConnections;

  UserItem({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.bio,
    required this.isOnline,
    required this.mutualConnections,
  });
}