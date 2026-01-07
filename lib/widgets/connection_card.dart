import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../utils/profile_navigation.dart';
import '../providers/follow_state.dart';
import '../core/i18n/language_provider.dart';

class ConnectionCard extends StatefulWidget {
  final String userId;
  final String coverUrl;
  final String avatarUrl;
  final String fullName;
  final String username; // NEW
  final String bio;
  final bool initialConnectionStatus;
  final bool theyConnectToYou;
  final VoidCallback? onMessage;
  final VoidCallback? onTap;

  const ConnectionCard({
    super.key,
    required this.userId,
    required this.coverUrl,
    required this.avatarUrl,
    required this.fullName,
    required this.username, // NEW
    required this.bio,
    this.initialConnectionStatus = false,
    this.theyConnectToYou = false,
    this.onMessage,
    this.onTap,
  });

  @override
  State<ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<ConnectionCard> {

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Colors.black : Colors.white;
    final follow = context.watch<FollowState>();
    if (!follow.initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<FollowState>().initialize();
      });
    }
    final connected = follow.isConnected(widget.userId);
    final theyConnect = widget.theyConnectToYou || follow.theyConnectToYou(widget.userId);

    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!.call();
          return;
        }
        navigateToUserProfile(
          context: context,
          userId: widget.userId,
          userName: widget.fullName,
          userAvatarUrl: widget.avatarUrl,
          userBio: widget.bio,
          userCoverUrl: widget.coverUrl,
          isConnected: connected,
          theyConnectToYou: widget.theyConnectToYou,
        );
      },
      child: Container(
        width: 155,
        height: 260,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Cover Image
            Container(
              height: 85,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
                child: CachedNetworkImage(
                  imageUrl: widget.coverUrl,
                  width: double.infinity,
                  height: 85,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: const Color(0xFF666666).withAlpha(51),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: const Color(0xFF666666).withAlpha(51),
                    child: const Icon(Icons.image, color: Color(0xFF666666)),
                  ),
                ),
              ),
            ),

            // Avatar (overlapping)
            Transform.translate(
              offset: const Offset(0, -28),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: cardColor, width: 3),
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: widget.avatarUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: const Color(0xFF666666).withAlpha(51),
                      child: const Icon(Icons.person, color: Color(0xFF666666)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: const Color(0xFF666666).withAlpha(51),
                      child: const Icon(Icons.person, color: Color(0xFF666666)),
                    ),
                  ),
                ),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: Column(
                  children: [
                    // Full name (1 line)
                    Text(
                      widget.fullName,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 2),

                    // Username (1 line)
                    Text(
                      widget.username.isNotEmpty ? widget.username : '',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF666666),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Bio (1 line)
                    Text(
                      widget.bio,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF666666),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const Spacer(),

                    // Buttons
                    Column(
                      children: [
                        // Connect/Disconnect Button
                        SizedBox(
                          width: double.infinity,
                          height: 36,
                          child: ElevatedButton(
                            onPressed: () async {
                              final ctx = context;
                              try {
                                await ctx.read<FollowState>().toggle(widget.userId);
                              } catch (e) {
                                if (!ctx.mounted) return;
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(Provider.of<LanguageProvider>(ctx, listen: false).t('connection.toggle_failed')),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: connected
                                  ? Colors.transparent
                                  : (isDark ? Colors.white : Colors.black),
                              foregroundColor: connected
                                  ? const Color(0xFF666666)
                                  : (isDark ? Colors.black : Colors.white),
                              side: connected
                                  ? const BorderSide(
                                      color: Color(0xFF666666),
                                      width: 1,
                                    )
                                  : null,
                              elevation: connected ? 0 : 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Text(
                              connected
                                  ? 'Disconnect'
                                  : (theyConnect ? 'Connect Back' : 'Connect'),
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Message Button
                        SizedBox(
                          width: double.infinity,
                          height: 36,
                          child: OutlinedButton(
                            onPressed: () {
                              widget.onMessage?.call();
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: Color(0xFF666666),
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Text(
                              'Message',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF666666),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}