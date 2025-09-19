import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'models/message.dart';
import 'widgets/message_bubble.dart';
import 'widgets/chat_input.dart';
import 'widgets/attachment_dropdown_menu.dart';
import 'widgets/message_actions_sheet.dart';
import 'package:flutter/services.dart';

class ChatPage extends StatefulWidget {
  final ChatUser otherUser;
  final bool? isDarkMode;

  const ChatPage({super.key, required this.otherUser, this.isDarkMode});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
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
          senderId: widget.otherUser.id,
          senderName: widget.otherUser.name,
          senderAvatar: widget.otherUser.avatarUrl,
          content: "What's the fastest way to level up my routine?",
          type: MessageType.text,
          timestamp: today.add(const Duration(hours: 9, minutes: 41)),
          status: MessageStatus.read,
          isFromCurrentUser: false,
        ),
        Message(
          id: '2',
          senderId: 'current_user',
          senderName: 'You',
          content: "Recently, some high-level data and get back on track.",
          type: MessageType.text,
          timestamp: today.add(const Duration(hours: 9, minutes: 42)),
          status: MessageStatus.read,
          isFromCurrentUser: true,
        ),
        Message(
          id: '3',
          senderId: widget.otherUser.id,
          senderName: widget.otherUser.name,
          senderAvatar: widget.otherUser.avatarUrl,
          content:
              "Do you have suggestions you want me to feel like me again, but better",
          type: MessageType.text,
          timestamp: today.add(const Duration(hours: 9, minutes: 43)),
          status: MessageStatus.read,
          isFromCurrentUser: false,
        ),
        Message(
          id: '4',
          senderId: 'current_user',
          senderName: 'You',
          content: "What are you doing rn?",
          type: MessageType.text,
          timestamp: today.add(const Duration(hours: 9, minutes: 44)),
          status: MessageStatus.read,
          isFromCurrentUser: true,
        ),
        Message(
          id: '5',
          senderId: widget.otherUser.id,
          senderName: widget.otherUser.name,
          senderAvatar: widget.otherUser.avatarUrl,
          content:
              "I just wanna keep the streak. We're just here to keep it alive tonight.",
          type: MessageType.text,
          timestamp: today.add(const Duration(hours: 9, minutes: 45)),
          status: MessageStatus.read,
          isFromCurrentUser: false,
        ),
        Message(
          id: '6',
          senderId: widget.otherUser.id,
          senderName: widget.otherUser.name,
          senderAvatar: widget.otherUser.avatarUrl,
          content: "I just want to feel like me again, but better",
          type: MessageType.text,
          timestamp: today.add(const Duration(hours: 9, minutes: 46)),
          status: MessageStatus.read,
          isFromCurrentUser: false,
        ),
        Message(
          id: '7',
          senderId: widget.otherUser.id,
          senderName: widget.otherUser.name,
          senderAvatar: widget.otherUser.avatarUrl,
          content: "I just want to feel like me again, but better",
          type: MessageType.image,
          attachments: [
            MediaAttachment(
              id: 'img1',
              url: 'https://picsum.photos/400/400?random=1',
              type: MediaType.image,
            ),
          ],
          timestamp: today.add(const Duration(hours: 9, minutes: 47)),
          status: MessageStatus.read,
          isFromCurrentUser: false,
        ),
        Message(
          id: '8',
          senderId: widget.otherUser.id,
          senderName: widget.otherUser.name,
          senderAvatar: widget.otherUser.avatarUrl,
          content: "I just want to feel like me again, but better.",
          type: MessageType.image,
          attachments: [
            MediaAttachment(
              id: 'img2',
              url: 'https://picsum.photos/400/400?random=2',
              type: MediaType.image,
            ),
          ],
          timestamp: today.add(const Duration(hours: 9, minutes: 48)),
          status: MessageStatus.read,
          isFromCurrentUser: false,
        ),
        Message(
          id: '9',
          senderId: 'current_user',
          senderName: 'You',
          content: "Recently, some high-level data and get back on track.",
          type: MessageType.image,
          attachments: [
            MediaAttachment(
              id: 'img3',
              url: 'https://picsum.photos/400/400?random=3',
              type: MediaType.image,
            ),
            MediaAttachment(
              id: 'img4',
              url: 'https://picsum.photos/400/400?random=4',
              type: MediaType.image,
            ),
          ],
          timestamp: today.add(const Duration(hours: 9, minutes: 49)),
          status: MessageStatus.read,
          isFromCurrentUser: true,
        ),
        Message(
          id: '10',
          senderId: widget.otherUser.id,
          senderName: widget.otherUser.name,
          senderAvatar: widget.otherUser.avatarUrl,
          content: "",
          type: MessageType.image,
          attachments: [
            MediaAttachment(
              id: 'img10',
              url: 'https://picsum.photos/400/400?random=10',
              type: MediaType.image,
            ),
          ],
          timestamp: today.add(const Duration(hours: 9, minutes: 50)),
          status: MessageStatus.read,
          isFromCurrentUser: false,
        ),
        Message(
          id: '11',
          senderId: 'current_user',
          senderName: 'You',
          content: "",
          type: MessageType.video,
          attachments: [
            MediaAttachment(
              id: 'vid1',
              url: 'https://example.com/video1.mp4',
              thumbnailUrl: 'https://picsum.photos/400/400?random=11',
              type: MediaType.video,
              duration: const Duration(seconds: 36),
            ),
          ],
          timestamp: today.add(const Duration(hours: 9, minutes: 51)),
          status: MessageStatus.read,
          isFromCurrentUser: true,
        ),
        Message(
          id: '12',
          senderId: widget.otherUser.id,
          senderName: widget.otherUser.name,
          senderAvatar: widget.otherUser.avatarUrl,
          content: "Check this out!",
          type: MessageType.video,
          attachments: [
            MediaAttachment(
              id: 'vid2',
              url: 'https://example.com/video2.mp4',
              thumbnailUrl: 'https://picsum.photos/400/400?random=12',
              type: MediaType.video,
              duration: const Duration(seconds: 24),
            ),
          ],
          timestamp: today.add(const Duration(hours: 9, minutes: 52)),
          status: MessageStatus.read,
          isFromCurrentUser: false,
        ),
        Message(
          id: '13',
          senderId: 'current_user',
          senderName: 'You',
          content: "Weekend photo dump 📸",
          type: MessageType.image,
          attachments: [
            MediaAttachment(
              id: 'img11',
              url: 'https://picsum.photos/400/400?random=13',
              type: MediaType.image,
            ),
            MediaAttachment(
              id: 'img12',
              url: 'https://picsum.photos/400/400?random=14',
              type: MediaType.image,
            ),
            MediaAttachment(
              id: 'img13',
              url: 'https://picsum.photos/400/400?random=15',
              type: MediaType.image,
            ),
            MediaAttachment(
              id: 'img14',
              url: 'https://picsum.photos/400/400?random=16',
              type: MediaType.image,
            ),
            MediaAttachment(
              id: 'img15',
              url: 'https://picsum.photos/400/400?random=17',
              type: MediaType.image,
            ),
            MediaAttachment(
              id: 'img16',
              url: 'https://picsum.photos/400/400?random=18',
              type: MediaType.image,
            ),
            MediaAttachment(
              id: 'img17',
              url: 'https://picsum.photos/400/400?random=19',
              type: MediaType.image,
            ),
            MediaAttachment(
              id: 'img18',
              url: 'https://picsum.photos/400/400?random=20',
              type: MediaType.image,
            ),
          ],
          timestamp: today.add(const Duration(hours: 9, minutes: 53)),
          status: MessageStatus.read,
          isFromCurrentUser: true,
        ),
        Message(
          id: '14',
          senderId: widget.otherUser.id,
          senderName: widget.otherUser.name,
          senderAvatar: widget.otherUser.avatarUrl,
          content: "",
          type: MessageType.image,
          attachments: [
            MediaAttachment(
              id: 'img19',
              url: 'https://picsum.photos/400/400?random=21',
              type: MediaType.image,
            ),
            MediaAttachment(
              id: 'img20',
              url: 'https://picsum.photos/400/400?random=22',
              type: MediaType.image,
            ),
            MediaAttachment(
              id: 'img21',
              url: 'https://picsum.photos/400/400?random=23',
              type: MediaType.image,
            ),
            MediaAttachment(
              id: 'img22',
              url: 'https://picsum.photos/400/400?random=24',
              type: MediaType.image,
            ),
            MediaAttachment(
              id: 'img23',
              url: 'https://picsum.photos/400/400?random=25',
              type: MediaType.image,
            ),
            MediaAttachment(
              id: 'img24',
              url: 'https://picsum.photos/400/400?random=26',
              type: MediaType.image,
            ),
          ],
          timestamp: today.add(const Duration(hours: 9, minutes: 54)),
          status: MessageStatus.read,
          isFromCurrentUser: false,
        ),
        Message(
          id: '15',
          senderId: 'current_user',
          senderName: 'You',
          content: "",
          type: MessageType.video,
          attachments: [
            MediaAttachment(
              id: 'vid3',
              url: 'https://example.com/video3.mp4',
              thumbnailUrl: 'https://picsum.photos/400/400?random=27',
              type: MediaType.video,
              duration: const Duration(seconds: 42),
            ),
            MediaAttachment(
              id: 'vid4',
              url: 'https://example.com/video4.mp4',
              thumbnailUrl: 'https://picsum.photos/400/400?random=28',
              type: MediaType.video,
              duration: const Duration(seconds: 18),
            ),
            MediaAttachment(
              id: 'vid5',
              url: 'https://example.com/video5.mp4',
              thumbnailUrl: 'https://picsum.photos/400/400?random=29',
              type: MediaType.video,
              duration: const Duration(seconds: 30),
            ),
            MediaAttachment(
              id: 'vid6',
              url: 'https://example.com/video6.mp4',
              thumbnailUrl: 'https://picsum.photos/400/400?random=30',
              type: MediaType.video,
              duration: const Duration(seconds: 25),
            ),
          ],
          timestamp: today.add(const Duration(hours: 9, minutes: 55)),
          status: MessageStatus.read,
          isFromCurrentUser: true,
        ),
        Message(
          id: '16',
          senderId: 'current_user',
          senderName: 'You',
          content: 'Yep, totally agree!',
          type: MessageType.text,
          timestamp: today.add(const Duration(hours: 9, minutes: 56)),
          status: MessageStatus.read,
          isFromCurrentUser: true,
          replyTo: ReplyTo(
            messageId: '3',
            senderName: widget.otherUser.name,
            content:
                "Do you have suggestions you want me to feel like me again, but better",
            type: MessageType.text,
          ),
        ),
        Message(
          id: '17',
          senderId: widget.otherUser.id,
          senderName: widget.otherUser.name,
          senderAvatar: widget.otherUser.avatarUrl,
          content: '',
          type: MessageType.image,
          attachments: [
            MediaAttachment(
              id: 'img25',
              url: 'https://picsum.photos/400/400?random=31',
              type: MediaType.image,
            ),
            MediaAttachment(
              id: 'img26',
              url: 'https://picsum.photos/400/400?random=32',
              type: MediaType.image,
            ),
          ],
          timestamp: today.add(const Duration(hours: 9, minutes: 57)),
          status: MessageStatus.read,
          isFromCurrentUser: false,
          replyTo: ReplyTo(
            messageId: '2',
            senderName: 'You',
            content: "Recently, some high-level data and get back on track.",
            type: MessageType.text,
          ),
        ),
        Message(
          id: '18',
          senderId: 'current_user',
          senderName: 'You',
          content: 'Here is a quick clip',
          type: MessageType.video,
          attachments: [
            MediaAttachment(
              id: 'vid7',
              url: 'https://example.com/video7.mp4',
              thumbnailUrl: 'https://picsum.photos/400/400?random=33',
              type: MediaType.video,
              duration: const Duration(seconds: 12),
            ),
          ],
          timestamp: today.add(const Duration(hours: 9, minutes: 58)),
          status: MessageStatus.read,
          isFromCurrentUser: true,
          replyTo: ReplyTo(
            messageId: '7',
            senderName: widget.otherUser.name,
            content: "I just want to feel like me again, but better",
            type: MessageType.image,
          ),
        ),
        Message(
          id: '19',
          senderId: widget.otherUser.id,
          senderName: widget.otherUser.name,
          senderAvatar: widget.otherUser.avatarUrl,
          content: '',
          type: MessageType.voice,
          attachments: [
            MediaAttachment(
              id: 'voice1',
              url: 'https://example.com/audio1.mp3',
              type: MediaType.voice,
              duration: const Duration(seconds: 42),
            ),
          ],
          timestamp: today.add(const Duration(hours: 9, minutes: 59)),
          status: MessageStatus.read,
          isFromCurrentUser: false,
        ),
        Message(
          id: '20',
          senderId: 'current_user',
          senderName: 'You',
          content: '',
          type: MessageType.voice,
          attachments: [
            MediaAttachment(
              id: 'voice2',
              url: 'https://example.com/audio2.mp3',
              type: MediaType.voice,
              duration: const Duration(seconds: 16),
            ),
          ],
          timestamp: today.add(const Duration(hours: 10, minutes: 0)),
          status: MessageStatus.read,
          isFromCurrentUser: true,
          replyTo: ReplyTo(
            messageId: '12',
            senderName: widget.otherUser.name,
            content: 'Check this out!',
            type: MessageType.video,
          ),
        ),
        // Single photo with reply (sent)
        Message(
          id: '21',
          senderId: 'current_user',
          senderName: 'You',
          content: '',
          type: MessageType.image,
          attachments: [
            MediaAttachment(
              id: 'img27',
              url: 'https://picsum.photos/400/400?random=34',
              type: MediaType.image,
            ),
          ],
          timestamp: today.add(const Duration(hours: 10, minutes: 1)),
          status: MessageStatus.read,
          isFromCurrentUser: true,
          replyTo: ReplyTo(
            messageId: '10',
            senderName: widget.otherUser.name,
            content: 'Photo',
            type: MessageType.image,
          ),
        ),
        // Multiple photos with reply (received)
        Message(
          id: '22',
          senderId: widget.otherUser.id,
          senderName: widget.otherUser.name,
          senderAvatar: widget.otherUser.avatarUrl,
          content: '',
          type: MessageType.image,
          attachments: [
            MediaAttachment(
              id: 'img28',
              url: 'https://picsum.photos/400/400?random=35',
              type: MediaType.image,
            ),
            MediaAttachment(
              id: 'img29',
              url: 'https://picsum.photos/400/400?random=36',
              type: MediaType.image,
            ),
            MediaAttachment(
              id: 'img30',
              url: 'https://picsum.photos/400/400?random=37',
              type: MediaType.image,
            ),
            MediaAttachment(
              id: 'img31',
              url: 'https://picsum.photos/400/400?random=38',
              type: MediaType.image,
            ),
            MediaAttachment(
              id: 'img32',
              url: 'https://picsum.photos/400/400?random=39',
              type: MediaType.image,
            ),
            MediaAttachment(
              id: 'img33',
              url: 'https://picsum.photos/400/400?random=40',
              type: MediaType.image,
            ),
          ],
          timestamp: today.add(const Duration(hours: 10, minutes: 2)),
          status: MessageStatus.read,
          isFromCurrentUser: false,
          replyTo: ReplyTo(
            messageId: '20',
            senderName: 'You',
            content: 'Voice message (0:16)',
            type: MessageType.voice,
          ),
        ),
        // Single video with reply (received)
        Message(
          id: '23',
          senderId: widget.otherUser.id,
          senderName: widget.otherUser.name,
          senderAvatar: widget.otherUser.avatarUrl,
          content: 'This one?',
          type: MessageType.video,
          attachments: [
            MediaAttachment(
              id: 'vid8',
              url: 'https://example.com/video8.mp4',
              thumbnailUrl: 'https://picsum.photos/400/400?random=41',
              type: MediaType.video,
              duration: const Duration(seconds: 9),
            ),
          ],
          timestamp: today.add(const Duration(hours: 10, minutes: 3)),
          status: MessageStatus.read,
          isFromCurrentUser: false,
          replyTo: ReplyTo(
            messageId: '13',
            senderName: 'You',
            content: '8 photos',
            type: MessageType.image,
          ),
        ),
        // Multiple videos with reply (sent)
        Message(
          id: '24',
          senderId: 'current_user',
          senderName: 'You',
          content: '',
          type: MessageType.video,
          attachments: [
            MediaAttachment(
              id: 'vid9',
              url: 'https://example.com/video9.mp4',
              thumbnailUrl: 'https://picsum.photos/400/400?random=42',
              type: MediaType.video,
              duration: const Duration(seconds: 14),
            ),
            MediaAttachment(
              id: 'vid10',
              url: 'https://example.com/video10.mp4',
              thumbnailUrl: 'https://picsum.photos/400/400?random=43',
              type: MediaType.video,
              duration: const Duration(seconds: 21),
            ),
            MediaAttachment(
              id: 'vid11',
              url: 'https://example.com/video11.mp4',
              thumbnailUrl: 'https://picsum.photos/400/400?random=44',
              type: MediaType.video,
              duration: const Duration(seconds: 11),
            ),
          ],
          timestamp: today.add(const Duration(hours: 10, minutes: 4)),
          status: MessageStatus.read,
          isFromCurrentUser: true,
          replyTo: ReplyTo(
            messageId: '10',
            senderName: widget.otherUser.name,
            content: 'Photo',
            type: MessageType.image,
          ),
        ),
        // Voice note with reply (received)
        Message(
          id: '25',
          senderId: widget.otherUser.id,
          senderName: widget.otherUser.name,
          senderAvatar: widget.otherUser.avatarUrl,
          content: '',
          type: MessageType.voice,
          attachments: [
            MediaAttachment(
              id: 'voice3',
              url: 'https://example.com/audio3.mp3',
              type: MediaType.voice,
              duration: const Duration(seconds: 22),
            ),
          ],
          timestamp: today.add(const Duration(hours: 10, minutes: 5)),
          status: MessageStatus.read,
          isFromCurrentUser: false,
          replyTo: ReplyTo(
            messageId: '11',
            senderName: 'You',
            content: 'Video (0:36)',
            type: MessageType.video,
          ),
        ),
      ]);
    });

    // Demo reactions on a few messages
    _messageReactions['7'] = '❤️'; // single photo (received)
    _messageReactions['12'] = '👏'; // single video (received)
    _messageReactions['13'] = '🥳'; // multiple photos (sent)
    _messageReactions['20'] = '👍'; // voice (sent)
    _messageReactions['24'] = '🔥'; // multiple videos (sent)
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
              senderName: widget.otherUser.name,
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
    final isDark =
        widget.isDarkMode ?? Theme.of(context).brightness == Brightness.dark;
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
    final isDark =
        widget.isDarkMode ?? Theme.of(context).brightness == Brightness.dark;
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

  // ignore: unused_element
  String _formatDurationLocal(Duration duration) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(duration.inMinutes.remainder(60))}:${two(duration.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDarkMode ?? theme.brightness == Brightness.dark;

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
            child: widget.otherUser.avatarUrl != null
                ? CachedNetworkImage(
                    imageUrl: widget.otherUser.avatarUrl!,
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
                  )
                : Container(
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

          const SizedBox(width: 12),

          // Name and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUser.name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  widget.otherUser.isOnline ? 'Online' : 'Last seen recently',
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
                showTimestamp: _shouldShowTimestamp(messageIndex),
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
