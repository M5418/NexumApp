import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'core/notifications_api.dart';

// Navigation targets
import 'post_page.dart';
import 'community_post_page.dart';
import 'invitation_page.dart';
import 'chat_page.dart';
import 'models/message.dart' show ChatUser;
import 'other_user_profile_page.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final _api = NotificationsApi();
  bool _loading = true;
  String? _error;
  List<AppNotification> _items = const [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.list(limit: 50, offset: 0);
      setState(() {
        _items = list;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load notifications';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isYesterday(DateTime d) {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return d.year == y.year && d.month == y.month && d.day == y.day;
  }

  // Map backend item to UI tile data
  _NotificationUIItem _toUIItem(AppNotification n) {
    final primaryText = n.actorUsername.isNotEmpty ? n.actorUsername : n.actorName;
    final actionText = n.actionText;
    final previewText = n.previewText;
    final timeLabel = n.timeLabel();
    final trailingImageUrl = n.previewImageUrl;
    final trailingChipLabel = (n.type == 'connection_received') ? 'Connected' : null;

    return _NotificationUIItem(
      section: _isToday(n.createdAt)
          ? 'Today'
          : (_isYesterday(n.createdAt) ? 'Yesterday' : 'Yesterday'),
      avatarUrls: [
        if (n.actorAvatarUrl != null && n.actorAvatarUrl!.isNotEmpty) n.actorAvatarUrl!
      ],
      primaryText: primaryText,
      actionText: actionText,
      previewText: previewText,
      timeLabel: timeLabel,
      trailingImageUrl: trailingImageUrl,
      trailingChipLabel: trailingChipLabel,
      isRead: n.isRead,
      onTap: () => _handleTap(n),
    );
  }

  Future<void> _handleTap(AppNotification n) async {
    // Mark as read (non-blocking)
    try {
      if (!n.isRead) await _api.markRead(n.id);
    } catch (_) {
      // ignore
    }

    // Navigate based on backend-provided navigateType and params
    switch (n.navigateType) {
      case 'post': {
        final postId = n.navigateParams['postId']?.toString();
        if (postId != null && postId.isNotEmpty && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PostPage(postId: postId)),
          );
        }
        break;
      }
      case 'community_post': {
        final communityId = n.navigateParams['communityId']?.toString();
        final postId = n.navigateParams['postId']?.toString();
        if (communityId != null &&
            communityId.isNotEmpty &&
            postId != null &&
            postId.isNotEmpty &&
            mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CommunityPostPage(
                communityId: communityId,
                postId: postId,
              ),
            ),
          );
        }
        break;
      }
      case 'invitation': {
        // Optional: could deep-link to a specific invitation later using n.navigateParams['invitationId']
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InvitationPage()),
          );
        }
        break;
      }
      case 'conversation': {
        final conversationId = n.navigateParams['conversationId']?.toString();
        if (conversationId != null && conversationId.isNotEmpty && mounted) {
          final other = ChatUser(
            id: n.actorId,
            name: n.actorName.isNotEmpty
                ? n.actorName
                : (n.actorUsername.isNotEmpty ? n.actorUsername : 'User'),
            avatarUrl: n.actorAvatarUrl,
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatPage(
                otherUser: other,
                conversationId: conversationId,
              ),
            ),
          );
        }
        break;
      }
      case 'user_profile': {
        final userId = (n.navigateParams['userId'] ?? n.actorId).toString();
        if (userId.isNotEmpty && mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OtherUserProfilePage(
                userId: userId,
                userName: n.actorName.isNotEmpty
                    ? n.actorName
                    : (n.actorUsername.isNotEmpty ? n.actorUsername : 'User'),
                userAvatarUrl: n.actorAvatarUrl ?? '',
                userBio: '',
              ),
            ),
          );
        }
        break;
      }
      default:
        // no-op
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
    final cardColor = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final today = _items.where((n) => _isToday(n.createdAt)).map(_toUIItem).toList();
    final yesterday = _items.where((n) => !_isToday(n.createdAt)).map(_toUIItem).toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notification',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.more_horiz,
              color: isDark ? Colors.white70 : const Color(0xFF666666),
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _fetch,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0),
                              blurRadius: 1,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 10),
                            _SectionHeader(label: 'Today', isDark: isDark),
                            ...today.map((n) => _NotificationTile(item: n, isDark: isDark)),
                            const SizedBox(height: 6),
                            _SectionHeader(label: 'Yesterday', isDark: isDark),
                            ...yesterday.map((n) => _NotificationTile(item: n, isDark: isDark)),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final bool isDark;
  const _SectionHeader({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final _NotificationUIItem item;
  final bool isDark;
  const _NotificationTile({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final secondary = isDark ? const Color(0xFF999999) : const Color(0xFF666666);

    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _StackedAvatars(urls: item.avatarUrls),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NotificationText(item: item, isDark: isDark),
                  const SizedBox(height: 4),
                  Text(
                    item.timeLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: secondary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (item.trailingImageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item.trailingImageUrl!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              )
            else if (item.trailingChipLabel != null)
              _ConnectedChip(label: item.trailingChipLabel!, isDark: isDark),
          ],
        ),
      ),
    );
  }
}

class _NotificationText extends StatelessWidget {
  final _NotificationUIItem item;
  final bool isDark;
  const _NotificationText({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? Colors.white : Colors.black;
    final secondary = isDark ? const Color(0xFF999999) : const Color(0xFF666666);

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: item.primaryText,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
          TextSpan(
            text: ' ${item.actionText}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: secondary,
            ),
          ),
          if (item.previewText != null) ...[
            TextSpan(
              text: '  ${item.previewText}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: secondary,
              ),
            ),
          ],
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _StackedAvatars extends StatelessWidget {
  final List<String> urls;
  const _StackedAvatars({required this.urls});

  @override
  Widget build(BuildContext context) {
    final String? url = urls.isNotEmpty ? urls.first : null;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        image: url != null
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
        color: url == null ? const Color(0xFF666666) : null,
      ),
      child: url == null
          ? const Icon(Icons.person, color: Colors.white, size: 20)
          : null,
    );
  }
}

class _ConnectedChip extends StatelessWidget {
  final String label;
  final bool isDark;
  const _ConnectedChip({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final border = isDark ? const Color(0xFF999999) : const Color(0xFFDDDDDD);
    final fg = isDark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// UI model tailored to the existing widget structure
class _NotificationUIItem {
  final String section; // 'Today' | 'Yesterday'
  final List<String> avatarUrls;
  final String primaryText; // e.g., '@valerieaz90'
  final String actionText; // e.g., 'Liked your post'
  final String? previewText; // optional smaller trailing text snippet
  final String timeLabel; // e.g., '3hr ago' or '18 May 2025'
  final String? trailingImageUrl; // optional post thumbnail
  final String? trailingChipLabel; // e.g., 'Connected'
  final bool isRead;
  final VoidCallback? onTap;

  _NotificationUIItem({
    required this.section,
    required this.avatarUrls,
    required this.primaryText,
    required this.actionText,
    required this.timeLabel,
    this.previewText,
    this.trailingImageUrl,
    this.trailingChipLabel,
    this.isRead = false,
    this.onTap,
  });
}