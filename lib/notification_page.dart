import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF0C0C0C)
        : const Color(0xFFF1F4F8);
    final cardColor = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final today = _sampleNotifications
        .where((n) => n.section == 'Today')
        .toList();
    final yesterday = _sampleNotifications
        .where((n) => n.section == 'Yesterday')
        .toList();

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
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0), // ~5% opacity
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
                ...today
                    .map((n) => _NotificationTile(item: n, isDark: isDark))
                    ,
                const SizedBox(height: 6),
                _SectionHeader(label: 'Yesterday', isDark: isDark),
                ...yesterday
                    .map((n) => _NotificationTile(item: n, isDark: isDark))
                    ,
                const SizedBox(height: 8),
              ],
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
  final _NotificationItem item;
  final bool isDark;
  const _NotificationTile({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final secondary = isDark
        ? const Color(0xFF999999)
        : const Color(0xFF666666);

    return InkWell(
      onTap: () {},
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
  final _NotificationItem item;
  final bool isDark;
  const _NotificationText({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? Colors.white : Colors.black;
    final secondary = isDark
        ? const Color(0xFF999999)
        : const Color(0xFF666666);

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

class _NotificationItem {
  final String section; // 'Today' | 'Yesterday'
  final List<String> avatarUrls;
  final String primaryText; // e.g., '@valerieaz90'
  final String actionText; // e.g., 'Liked your post'
  final String? previewText; // optional smaller trailing text snippet
  final String timeLabel; // e.g., '3hr ago' or '18 May 2025'
  final String? trailingImageUrl; // optional post thumbnail
  final String? trailingChipLabel; // e.g., 'Connected'

  const _NotificationItem({
    required this.section,
    required this.avatarUrls,
    required this.primaryText,
    required this.actionText,
    required this.timeLabel,
    this.previewText,
    this.trailingImageUrl,
    this.trailingChipLabel,
  });
}

List<_NotificationItem> get _sampleNotifications => [
  _NotificationItem(
    section: 'Today',
    avatarUrls: [
      'https://i.pravatar.cc/100?img=11',
      'https://i.pravatar.cc/100?img=12',
      'https://i.pravatar.cc/100?img=13',
    ],
    primaryText: '@valerieaz90',
    actionText: 'Liked your comments',
    timeLabel: '3hr ago',
    trailingImageUrl: 'https://picsum.photos/seed/np1/80/80',
  ),
  _NotificationItem(
    section: 'Today',
    avatarUrls: [
      'https://i.pravatar.cc/100?img=21',
      'https://i.pravatar.cc/100?img=22',
      'https://i.pravatar.cc/100?img=23',
    ],
    primaryText: '@ariagmn',
    actionText: 'Liked your post',
    timeLabel: '3hr ago',
    trailingImageUrl: 'https://picsum.photos/seed/np2/80/80',
  ),
  _NotificationItem(
    section: 'Today',
    avatarUrls: [
      'https://i.pravatar.cc/100?img=31',
      'https://i.pravatar.cc/100?img=32',
    ],
    primaryText: '@lolitahoran',
    actionText: 'Connected with you',
    timeLabel: '2hr ago',
    trailingChipLabel: 'Connected',
  ),
  _NotificationItem(
    section: 'Today',
    avatarUrls: [
      'https://i.pravatar.cc/100?img=41',
      'https://i.pravatar.cc/100?img=42',
    ],
    primaryText: '@skyedesn',
    actionText: 'mentioned you in a comments',
    previewText: '@laligabs do you wanna hang out th...',
    timeLabel: '2hr ago',
  ),
  _NotificationItem(
    section: 'Today',
    avatarUrls: [
      'https://i.pravatar.cc/100?img=51',
      'https://i.pravatar.cc/100?img=52',
    ],
    primaryText: '@harrymalks',
    actionText: 'Liked your post',
    timeLabel: '2hr ago',
    trailingImageUrl: 'https://picsum.photos/seed/np3/80/80',
  ),
  _NotificationItem(
    section: 'Yesterday',
    avatarUrls: [
      'https://i.pravatar.cc/100?img=61',
      'https://i.pravatar.cc/100?img=62',
    ],
    primaryText: '@jolinaangline',
    actionText: 'Connected with you',
    timeLabel: '18 May 2025',
    trailingChipLabel: 'Connected',
  ),
  _NotificationItem(
    section: 'Yesterday',
    avatarUrls: [
      'https://i.pravatar.cc/100?img=71',
      'https://i.pravatar.cc/100?img=72',
    ],
    primaryText: '@aidenblaze',
    actionText: 'Liked your post',
    timeLabel: '18 May 2025',
    trailingImageUrl: 'https://picsum.photos/seed/np4/80/80',
  ),
  _NotificationItem(
    section: 'Yesterday',
    avatarUrls: [
      'https://i.pravatar.cc/100?img=81',
      'https://i.pravatar.cc/100?img=82',
    ],
    primaryText: '@aidenfrost',
    actionText: 'Liked your comments',
    timeLabel: '18 May 2025',
    trailingImageUrl: 'https://picsum.photos/seed/np5/80/80',
  ),
];
