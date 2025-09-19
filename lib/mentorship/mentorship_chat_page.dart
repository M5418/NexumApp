import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/message.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/attachment_dropdown_menu.dart';
import '../widgets/message_actions_sheet.dart';
import 'package:flutter/services.dart';

class MentorshipChatPage extends StatefulWidget {
  final String mentorName;
  final String mentorAvatar;
  final bool isOnline;

  const MentorshipChatPage({
    super.key,
    required this.mentorName,
    required this.mentorAvatar,
    required this.isOnline,
  });

  @override
  State<MentorshipChatPage> createState() => _MentorshipChatPageState();
}

class _MentorshipChatPageState extends State<MentorshipChatPage> {
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  String? _replyToMessage;
  final Set<String> _starredIds = <String>{};
  final Map<String, String> _messageReactions = <String, String>{};

  @override
  void initState() {
    super.initState();
    _loadSampleMessages();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadSampleMessages() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    setState(() {
      _messages.addAll([
        Message(
          id: '1',
          senderId: 'mentor',
          senderName: widget.mentorName,
          senderAvatar: widget.mentorAvatar,
          content:
              'Hi! I\'m excited to be your mentor. What specific areas would you like to focus on in our sessions?',
          timestamp: today.add(const Duration(hours: 9, minutes: 30)),
          type: MessageType.text,
          status: MessageStatus.read,
          isFromCurrentUser: false,
        ),
        Message(
          id: '2',
          senderId: 'current_user',
          senderName: 'You',
          content:
              'Thank you! I\'m particularly interested in investment strategies and portfolio management.',
          timestamp: today.add(const Duration(hours: 9, minutes: 35)),
          type: MessageType.text,
          status: MessageStatus.read,
          isFromCurrentUser: true,
        ),
        Message(
          id: '3',
          senderId: 'mentor',
          senderName: widget.mentorName,
          senderAvatar: widget.mentorAvatar,
          content:
              'Great! That\'s exactly my area of expertise. Let\'s start with understanding your risk tolerance.',
          timestamp: today.add(const Duration(hours: 9, minutes: 40)),
          type: MessageType.text,
          status: MessageStatus.read,
          isFromCurrentUser: false,
        ),
        Message(
          id: '4',
          senderId: 'current_user',
          senderName: 'You',
          content:
              'I\'m looking to build long-term wealth, maybe 10-15 year horizon.',
          timestamp: today.add(const Duration(hours: 9, minutes: 45)),
          type: MessageType.text,
          status: MessageStatus.read,
          isFromCurrentUser: true,
        ),
        Message(
          id: '5',
          senderId: 'mentor',
          senderName: widget.mentorName,
          senderAvatar: widget.mentorAvatar,
          content:
              'Perfect! For our next session, I\'ll prepare a diversified portfolio strategy.',
          timestamp: today.add(const Duration(hours: 9, minutes: 50)),
          type: MessageType.text,
          status: MessageStatus.read,
          isFromCurrentUser: false,
        ),
        Message(
          id: '6',
          senderId: 'mentor',
          senderName: widget.mentorName,
          senderAvatar: widget.mentorAvatar,
          content: 'Here\'s a sample portfolio breakdown I prepared for you',
          type: MessageType.image,
          attachments: [
            MediaAttachment(
              id: 'img1',
              url: 'https://picsum.photos/400/400?random=1',
              type: MediaType.image,
            ),
          ],
          timestamp: today.add(const Duration(hours: 9, minutes: 55)),
          status: MessageStatus.read,
          isFromCurrentUser: false,
        ),
        Message(
          id: '7',
          senderId: 'current_user',
          senderName: 'You',
          content: 'This looks great! Thank you for the detailed breakdown.',
          timestamp: today.add(const Duration(hours: 10, minutes: 0)),
          type: MessageType.text,
          status: MessageStatus.read,
          isFromCurrentUser: true,
          replyTo: ReplyTo(
            messageId: '6',
            senderName: widget.mentorName,
            content: 'Here\'s a sample portfolio breakdown I prepared for you',
            type: MessageType.image,
          ),
        ),
      ]);
    });

    // Demo reactions
    _messageReactions['5'] = '';
    _messageReactions['6'] = '';
  }

  void _sendMessage(String content) {
    final newMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: 'current_user',
      senderName: 'You',
      content: content,
      type: MessageType.text,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      isFromCurrentUser: true,
      replyTo: _replyToMessage != null
          ? ReplyTo(
              messageId: 'reply_id',
              senderName: widget.mentorName,
              content: _replyToMessage!,
              type: MessageType.text,
            )
          : null,
    );

    setState(() {
      _messages.add(newMessage);
      _replyToMessage = null;
    });

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showAttachmentOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AttachmentDropdownMenu(
        isDark: isDark,
        onSendVideos: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Send Video')));
        },
        onSendFiles: () {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Share File')));
        },
      ),
    );
  }

  void _handleVoiceRecord() {
    // Handle voice recording
  }

  void _replyToMessageHandler(Message message) {
    setState(() {
      _replyToMessage = message.content;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToMessage = null;
    });
  }

  void _showMessageActions(Message message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MessageActionsSheet(
        message: message,
        isDark: isDark,
        isStarred: _starredIds.contains(message.id),
        onCopy: (text) {
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Copied')));
        },
        onReply: () {
          _replyToMessageHandler(message);
        },
        onToggleStar: () => _toggleStar(message),
        onShareToStory: () => ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Shared to Story'))),
        onDelete: () {
          setState(() {
            _messages.removeWhere((m) => m.id == message.id);
          });
        },
        onReact: (emoji) => _addReaction(message, emoji),
      ),
    );
  }

  void _toggleStar(Message message) {
    setState(() {
      if (_starredIds.contains(message.id)) {
        _starredIds.remove(message.id);
      } else {
        _starredIds.add(message.id);
      }
    });
  }

  void _addReaction(Message message, String emoji) {
    setState(() {
      _messageReactions[message.id] = emoji;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0C0C0C)
          : const Color(0xFFF1F4F8),
      appBar: _buildAppBar(isDark),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _messages.length + _getDaySeparatorCount(),
              itemBuilder: (context, index) {
                return _buildMessageOrSeparator(index, isDark);
              },
            ),
          ),
          // Input area
          ChatInput(
            onSendMessage: _sendMessage,
            onVoiceRecord: _handleVoiceRecord,
            onAttachment: _showAttachmentOptions,
            replyToMessage: _replyToMessage,
            onCancelReply: _cancelReply,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? Colors.black : Colors.white,
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Icon(
          Icons.arrow_back_ios,
          color: isDark ? Colors.white : Colors.black,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          // Avatar
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CachedNetworkImage(
              imageUrl: widget.mentorAvatar,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF666666).withValues(alpha: 51),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF666666),
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.mentorName,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  widget.isOnline ? 'Online' : 'Last seen recently',
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
      actions: [
        // Video call button
        IconButton(
          onPressed: () {},
          icon: Icon(
            Icons.videocam,
            color: isDark ? Colors.white : Colors.black,
            size: 24,
          ),
        ),
        // Voice call button
        IconButton(
          onPressed: () {},
          icon: Icon(
            Icons.phone,
            color: isDark ? Colors.white : Colors.black,
            size: 24,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMessageOrSeparator(int index, bool isDark) {
    int messageIndex = index;
    int separatorsPassed = 0;

    // Calculate day separators
    for (int i = 0; i < _messages.length; i++) {
      if (i == 0 ||
          !_isSameDay(_messages[i].timestamp, _messages[i - 1].timestamp)) {
        if (messageIndex == i + separatorsPassed) {
          return _buildDaySeparator(_messages[i].timestamp, isDark);
        }
        separatorsPassed++;
        messageIndex--;
      }

      if (messageIndex == i) {
        final message = _messages[i];

        final reaction = _messageReactions[message.id];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Column(
            crossAxisAlignment: message.isFromCurrentUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              MessageBubble(
                message: message,
                allMessages: _messages,
                showTimestamp: _shouldShowTimestamp(i),
                onReply: () => _replyToMessageHandler(message),
                onLongPress: () => _showMessageActions(message),
              ),
              if (reaction != null) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 2),
                  child: Align(
                    alignment: message.isFromCurrentUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 26),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        reaction,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }
    }

    return const SizedBox.shrink();
  }

  Widget _buildDaySeparator(DateTime date, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (messageDate == today) {
      dateText = 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      dateText = 'Yesterday';
    } else {
      // Manual date formatting: "Month day, year"
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      dateText = '${months[date.month - 1]} ${date.day}, ${date.year}';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF666666).withValues(alpha: 26),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dateText,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF666666),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  bool _shouldShowTimestamp(int index) => true;

  int _getDaySeparatorCount() {
    int count = 0;
    for (int i = 0; i < _messages.length; i++) {
      if (i == 0 ||
          !_isSameDay(_messages[i].timestamp, _messages[i - 1].timestamp)) {
        count++;
      }
    }
    return count;
  }
}
