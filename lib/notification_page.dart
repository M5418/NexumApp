import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'repositories/interfaces/notification_repository.dart';
import 'core/i18n/language_provider.dart';
import 'repositories/firebase/firebase_notification_repository.dart';

// Navigation targets
import 'post_page.dart';
import 'responsive/responsive_breakpoints.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final _repo = FirebaseNotificationRepository();
  bool _loading = true;
  String? _error;
  List<NotificationModel> _items = const [];

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
      final list = await _repo.getNotifications(limit: 50);
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

  // Map Firebase notification to UI tile data
  _NotificationUIItem _toUIItem(NotificationModel n) {
    final primaryText = n.title;
    final actionText = n.body;
    final previewText = null as String?;
    final timeLabel = _timeLabel(n.createdAt);
    final trailingImageUrl = null as String?;
    final trailingChipLabel = null as String?;

    return _NotificationUIItem(
      section: _isToday(n.createdAt)
          ? 'Today'
          : (_isYesterday(n.createdAt) ? 'Yesterday' : 'Yesterday'),
      avatarUrls: const [],
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

  String _timeLabel(DateTime dt) {
    final n = DateTime.now();
    final diff = n.difference(dt);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min ago';
    if (diff.inHours < 24) return '${diff.inHours}hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day} ${_monthLabel(dt.month)} ${dt.year}';
  }

  String _monthLabel(int m) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return months[(m - 1).clamp(0, 11)];
  }

  Future<void> _handleTap(NotificationModel n) async {
    // Mark as read (non-blocking)
    try {
      if (!n.isRead) await _repo.markAsRead(n.id);
    } catch (_) {
      // ignore
    }

    // Minimal navigation for like/comment types when refId present
    if (n.refId != null && n.refId!.isNotEmpty && mounted) {
      if (n.type == NotificationType.like || n.type == NotificationType.comment) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostPage(postId: n.refId!)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = context.isDesktop || context.isLargeDesktop;
    final backgroundColor =
        isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
    final cardColor = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final today =
        _items.where((n) => _isToday(n.createdAt)).map(_toUIItem).toList();
    final yesterday =
        _items.where((n) => !_isToday(n.createdAt)).map(_toUIItem).toList();
    final hasAny = today.isNotEmpty || yesterday.isNotEmpty;

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
          Provider.of<LanguageProvider>(context).t('notifications.title'),
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
                            child: Text(Provider.of<LanguageProvider>(context).t('notifications.retry')),
                          ),
                        ],
                      ),
                    ),
                  )
                : (isDesktop
                    ? Align(
                        alignment: Alignment.topLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: SingleChildScrollView(
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
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: hasAny
                                      ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 10),
                                            _SectionHeader(
                                                label: Provider.of<LanguageProvider>(context, listen: false).t('common.today'), isDark: isDark),
                                            ...today.map((n) =>
                                                _NotificationTile(
                                                    item: n, isDark: isDark)),
                                            const SizedBox(height: 6),
                                            _SectionHeader(
                                                label: Provider.of<LanguageProvider>(context, listen: false).t('common.yesterday'),
                                                isDark: isDark),
                                            ...yesterday.map((n) =>
                                                _NotificationTile(
                                                    item: n, isDark: isDark)),
                                          ],
                                        )
                                      : Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Text(
                                            Provider.of<LanguageProvider>(context).t('notifications.no_notifications'),
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              color: isDark
                                                  ? Colors.white70
                                                  : const Color(0xFF666666),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
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
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: hasAny
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 10),
                                        _SectionHeader(
                                            label: Provider.of<LanguageProvider>(context, listen: false).t('common.today'), isDark: isDark),
                                        ...today.map((n) => _NotificationTile(
                                            item: n, isDark: isDark)),
                                        const SizedBox(height: 6),
                                        _SectionHeader(
                                            label: Provider.of<LanguageProvider>(context, listen: false).t('common.yesterday'), isDark: isDark),
                                        ...yesterday.map((n) =>
                                            _NotificationTile(
                                                item: n, isDark: isDark)),
                                      ],
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        Provider.of<LanguageProvider>(context).t('notifications.no_notifications'),
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.white70
                                              : const Color(0xFF666666),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      )),
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
    final secondary =
        isDark ? const Color(0xFF999999) : const Color(0xFF666666);

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
    final secondary =
        isDark ? const Color(0xFF999999) : const Color(0xFF666666);

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
