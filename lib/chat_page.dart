import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'models/message.dart';
import 'widgets/message_bubble.dart';
import 'package:file_picker/file_picker.dart';
import 'widgets/chat_input.dart';
import 'widgets/message_actions_sheet.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'repositories/interfaces/message_repository.dart';
import 'repositories/interfaces/conversation_repository.dart';
import 'core/audio_recorder.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:async';
import 'core/profile_api.dart';
import 'widgets/media_preview_page.dart';

class ChatPage extends StatefulWidget {
  final ChatUser otherUser;
  final bool? isDarkMode;
  final String? conversationId;

  const ChatPage({
    super.key,
    required this.otherUser,
    this.isDarkMode,
    this.conversationId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  Message? _replyToMessage;
  final Set<String> _starredIds = <String>{};
  final Map<String, String> _messageReactions = <String, String>{};

  late MessageRepository _msgRepo;
  late ConversationRepository _convRepo;
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _resolvedConversationId;
  bool _isRecording = false;
  bool _isLoading = false;
  String? _loadError;
  Timer? _pollTimer;
  bool _isRefreshing = false;

  void _showSnack(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  void _hideSnack() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
  }

  @override
void initState() {
  super.initState();
  _msgRepo = context.read<MessageRepository>();
  _convRepo = context.read<ConversationRepository>();
  _initLoad();
  _startPolling();
}

  void _initLoad() {
    if (widget.conversationId != null && widget.conversationId!.isNotEmpty) {
      _resolvedConversationId = widget.conversationId;
      _loadMessages();
      _markRead();
    } else {
      _ensureConversationAndLoad();
    }
  }

  Future<void> _ensureConversationAndLoad() async {
    try {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
      final id = await _convRepo.createOrGet(widget.otherUser.id);
      if (!mounted) return;
      setState(() {
        _resolvedConversationId = id;
      });
      await _loadMessages();
      await _markRead();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<String> _requireConversationId() async {
    if (_resolvedConversationId != null && _resolvedConversationId!.isNotEmpty) {
      return _resolvedConversationId!;
    }
    final id = await _convRepo.createOrGet(widget.otherUser.id);
    if (mounted) {
      setState(() => _resolvedConversationId = id);
    } else {
      _resolvedConversationId = id;
    }
    return id;
  }

  Future<void> _loadMessages() async {
    try {
      setState(() {
        _isLoading = true;
        _loadError = null;
        _messages.clear();
        _messageReactions.clear();
      });
      if (_resolvedConversationId == null) return;
      final records = await _msgRepo.list(_resolvedConversationId!);
      final mapped = records.map(_toUiMessage).toList();
      setState(() {
        _messages.addAll(mapped);
        for (final r in records) {
          if ((r.reaction ?? '').isNotEmpty) {
            _messageReactions[r.id] = r.reaction!;
          } else if ((r.myReaction ?? '').isNotEmpty) {
            _messageReactions[r.id] = r.myReaction!;
          }
        }
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _markRead() async {
    try {
      if (_resolvedConversationId != null) {
        await _convRepo.markRead(_resolvedConversationId!);
      }
    } catch (_) {}
  }
  void _startPolling() {
  _pollTimer?.cancel();
  // Poll every 3 seconds for new messages when we have a conversation ID
  _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
    if (!mounted) return;
    if (_resolvedConversationId == null) return;
    if (_isLoading || _isRefreshing) return; // avoid overlapping calls
    await _refreshMessages();
  });
}

Future<void> _refreshMessages() async {
  if (_resolvedConversationId == null) return;
  try {
    _isRefreshing = true;

    // Check if user is near bottom to decide whether to auto-scroll after update
    final bool wasAtBottom = _scrollController.hasClients &&
        (_scrollController.position.maxScrollExtent - _scrollController.position.pixels) < 120;

    final records = await _msgRepo.list(_resolvedConversationId!, limit: 50);
    final mapped = records.map(_toUiMessage).toList();

    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(mapped);
      _messageReactions.clear();
      for (final r in records) {
        if ((r.reaction ?? '').isNotEmpty) {
          _messageReactions[r.id] = r.reaction!;
        } else if ((r.myReaction ?? '').isNotEmpty) {
          _messageReactions[r.id] = r.myReaction!;
        }
      }
    });

    if (wasAtBottom) {
      _scrollToBottom();
    }

    // Mark all as read in this conversation after refresh
    await _markRead();
  } catch (_) {
    // swallow refresh error silently to avoid spamming the user
  } finally {
    _isRefreshing = false;
  }
}

@override
void dispose() {
  _pollTimer?.cancel();
  _scrollController.dispose();
  super.dispose();
}

  Message _toUiMessage(MessageRecordModel r) {
    final isFromCurrentUser = r.senderId != widget.otherUser.id;
    String? senderAvatar = isFromCurrentUser ? null : widget.otherUser.avatarUrl;

    final attachments = r.attachments.map((a) {
      final t = a.type;
      final mediaType = t == 'image'
          ? MediaType.image
          : t == 'video'
              ? MediaType.video
              : t == 'voice'
                  ? MediaType.voice
                  : MediaType.document;
      return MediaAttachment(
        id: a.id,
        url: a.url,
        type: mediaType,
        thumbnailUrl: a.thumbnail,
        duration: a.durationSec != null ? Duration(seconds: a.durationSec!) : null,
        fileSize: a.fileSize,
        fileName: a.fileName,
      );
    }).toList();

    ReplyTo? replyTo;
    if (r.replyTo != null) {
      final replyData = r.replyTo!;
      replyTo = ReplyTo(
        messageId: (replyData['message_id'] ?? '').toString(),
        senderName: (replyData['sender_name'] ?? 'User').toString(),
        content: (replyData['content'] ?? '').toString(),
        type: _mapStringToMessageType(replyData['type']?.toString() ?? 'text'),
        mediaUrl: null,
      );
    }

    return Message(
      id: r.id,
      senderId: r.senderId,
      senderName: isFromCurrentUser ? 'You' : widget.otherUser.name,
      senderAvatar: senderAvatar,
      content: r.text ?? '',
      type: r.type == 'text'
          ? MessageType.text
          : r.type == 'image'
              ? MessageType.image
              : r.type == 'video'
                  ? MessageType.video
                  : r.type == 'voice'
                      ? MessageType.voice
                      : MessageType.file,
      attachments: attachments,
      timestamp: r.createdAt,
      status: r.readAt != null ? MessageStatus.read : MessageStatus.sent,
      replyTo: replyTo,
      isFromCurrentUser: isFromCurrentUser,
    );
  }

  MessageType _mapStringToMessageType(String type) {
    switch (type) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'video':
        return MessageType.video;
      case 'voice':
        return MessageType.voice;
      case 'file':
        return MessageType.file;
      default:
        return MessageType.text;
    }
  }

  Future<void> _sendMessage(String content) async {
    try {
      final convId = await _requireConversationId();
      final record = await _msgRepo.sendText(
        conversationId: convId,
        otherUserId: null,
        text: content,
        replyToMessageId: _replyToMessage?.id,
      );
      final msg = _toUiMessage(record).copyWith(
        replyTo: _replyToMessage != null
            ? ReplyTo(
                messageId: _replyToMessage!.id,
                senderName: _replyToMessage!.senderName,
                content: _replyToMessage!.content,
                type: _replyToMessage!.type,
                mediaUrl: _replyToMessage!.attachments.isNotEmpty
                    ? _replyToMessage!.attachments.first.url
                    : null,
              )
            : null,
      );
      setState(() {
        _messages.add(msg);
        _replyToMessage = null;
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) _showSnack('Failed to send: $e');
    }
  }

  Future<void> _handleVoiceRecord() async {
    try {
      if (!_isRecording) {
        final path = await _audioRecorder.startRecording();
        if (path != null) {
          setState(() {
            _isRecording = true;
          });
        } else {
          if (!mounted) return;
          _showSnack('Failed to start recording');
        }
      } else {
        final result = await _audioRecorder.stopRecording();
        setState(() {
          _isRecording = false;
        });

        if (result != null) {
          await _sendVoiceMessage(result);
        }
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
      });
      if (!mounted) return;
      _showSnack('Recording error: $e');
    }
  }

  Future<void> _sendVoiceMessage(VoiceRecordingResult recording) async {
    try {
      final audioUrl = await _audioRecorder.uploadVoiceFile(recording.filePath);
      if (audioUrl == null) {
        throw Exception('Failed to upload voice file');
      }

      final convId = await _requireConversationId();
      final record = await _msgRepo.sendVoice(
        conversationId: convId,
        otherUserId: null,
        audioUrl: audioUrl,
        durationSec: recording.duration.inSeconds,
        fileSize: recording.fileSize,
        replyToMessageId: _replyToMessage?.id,
      );

      final msg = _toUiMessage(record);
      setState(() {
        _messages.add(msg);
        _replyToMessage = null;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to send voice message: $e');
    }
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
      builder: (_) => _buildAttachmentBottomSheet(isDark),
    );
  }

  Widget _buildAttachmentBottomSheet(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF666666).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAttachmentOption(
                icon: Icons.camera_alt,
                label: 'Camera',
                color: const Color(0xFF34C759),
                onTap: () => _pickMedia(ImageSource.camera),
                isDark: isDark,
              ),
              _buildAttachmentOption(
                icon: Icons.photo_library,
                label: 'Gallery',
                color: const Color(0xFF007AFF),
                onTap: () => _pickMedia(ImageSource.gallery),
                isDark: isDark,
              ),
              _buildAttachmentOption(
                icon: Icons.videocam,
                label: 'Video',
                color: const Color(0xFFFF9500),
                onTap: () => _pickVideo(),
                isDark: isDark,
              ),
              _buildAttachmentOption(
                icon: Icons.description,
                label: 'File',
                color: const Color(0xFFFF3B30),
                onTap: () => _pickFile(),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  // Open picker first (to keep browser user-gesture), then close the sheet.
  Future<void> _pickMedia(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultipleMedia();
      if (mounted) Navigator.pop(context);
      if (images.isNotEmpty) {
        await _sendMediaWithText(images);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) _showSnack('Failed to pick images: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
      if (mounted) Navigator.pop(context);
      if (video != null) {
        await _sendMediaWithText([video]);
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) _showSnack('Failed to pick video: $e');
    }
  }

  // PDF/DOC/DOCX/XLS/XLSX
  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: kIsWeb, // provide .bytes on web
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
      );
      if (mounted) Navigator.pop(context);
      if (res == null || res.files.isEmpty) return;

      _showSnack('Uploading file(s)...');

      final profileApi = ProfileApi();
      final attachments = <Map<String, dynamic>>[];

      for (final f in res.files) {
        final name = f.name;
        final ext = (f.extension ?? (name.contains('.') ? name.split('.').last : 'bin'))
            .toLowerCase();

        String url;
        final fileSize = f.size;

        if (kIsWeb) {
          final bytes = f.bytes;
          if (bytes == null || bytes.isEmpty) continue;
          url = await profileApi.uploadBytes(bytes, ext: ext);
        } else {
          final path = f.path;
          if (path == null) continue;
          url = await profileApi.uploadFile(File(path));
        }

        attachments.add({
          'type': 'document',
          'url': url,
          'fileName': name,
          'fileSize': fileSize,
        });
      }

      if (attachments.isEmpty) {
        _hideSnack();
        return;
      }

      final convId = await _requireConversationId();
      final record = await _msgRepo.sendTextWithAttachments(
        conversationId: convId,
        otherUserId: null,
        text: '',
        attachments: attachments,
        replyToMessageId: _replyToMessage?.id,
      );

      final msg = _toUiMessage(record);
      setState(() {
        _messages.add(msg);
        _replyToMessage = null;
      });
      _scrollToBottom();
      _hideSnack();
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      _showSnack('Failed to pick/send files: $e');
    }
  }

  Future<void> _sendMediaWithText(List<XFile> mediaFiles) async {
    final isDark =
        widget.isDarkMode ?? Theme.of(context).brightness == Brightness.dark;

    final previewResult = await Navigator.push<MediaPreviewResult>(
      context,
      MaterialPageRoute(
        builder: (_) => MediaPreviewPage(
          initialFiles: mediaFiles,
          isDark: isDark,
        ),
      ),
    );

    if (previewResult != null && previewResult.files.isNotEmpty) {
      await _uploadAndSendMedia(previewResult.files, previewResult.caption);
    }
  }

  Future<void> _uploadAndSendMedia(
    List<XFile> mediaFiles,
    String caption,
  ) async {
    try {
      if (!mounted) return;
      _showSnack('Uploading media...');

      final profileApi = ProfileApi();
      final attachments = <Map<String, dynamic>>[];

      bool isVideoPath(String p) {
        final path = p.toLowerCase();
        return path.endsWith('.mp4') ||
            path.endsWith('.mov') ||
            path.endsWith('.webm') ||
            path.endsWith('.mkv') ||
            path.endsWith('.avi');
      }

      for (final mediaFile in mediaFiles) {
        final nameOrPath =
            mediaFile.name.isNotEmpty ? mediaFile.name : mediaFile.path;

        final dot = nameOrPath.lastIndexOf('.');
        final ext = (dot != -1 && dot < nameOrPath.length - 1)
            ? nameOrPath.substring(dot + 1).toLowerCase()
            : 'bin';

        String url;
        int? fileSize;

        if (kIsWeb) {
          final bytes = await mediaFile.readAsBytes();
          fileSize = bytes.length;
          url = await profileApi.uploadBytes(bytes, ext: ext);
        } else {
          final file = File(mediaFile.path);
          fileSize = await file.length();
          url = await profileApi.uploadFile(file);
        }

        final isVideo = isVideoPath(nameOrPath);

        attachments.add({
          'type': isVideo ? 'video' : 'image',
          'url': url,
          'fileName': mediaFile.name,
          'fileSize': fileSize,
        });
      }

      final convId = await _requireConversationId();
      final record = await _msgRepo.sendTextWithAttachments(
        conversationId: convId,
        otherUserId: null,
        text: caption,
        attachments: attachments,
        replyToMessageId: _replyToMessage?.id,
      );

      final msg = _toUiMessage(record);
      setState(() {
        _messages.add(msg);
        _replyToMessage = null;
      });
      _scrollToBottom();

      if (!mounted) return;
      _hideSnack();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to send media: $e');
    }
  }

  void _replyToMessageHandler(Message message) {
    setState(() {
      _replyToMessage = message;
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
          _showSnack('Copied');
        },
        onReply: () {
          _replyToMessageHandler(message);
        },
        onToggleStar: () => _toggleStar(message),
        onShareToStory: () => _showSnack('Shared to Story'),
        onDelete: () => _confirmDelete(message),
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

  Future<void> _addReaction(Message message, String emoji) async {
    try {
      await _msgRepo.react(message.id, emoji);
      setState(() {
        _messageReactions[message.id] = emoji;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to react: $e');
    }
  }

  // Confirm delete: "Delete for me" always available; "Delete for everyone" if sender
  Future<void> _confirmDelete(Message message) async {
    final isMine = message.isFromCurrentUser;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete message?'),
          content: Text(
            isMine
                ? 'Do you want to delete this message for you or for everyone?'
                : 'Do you want to delete this message from your chat? It will remain visible to ${widget.otherUser.name}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('me'),
              child: const Text('Delete for me'),
            ),
            if (isMine)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('everyone'),
                child: const Text('Delete for everyone'),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (result == 'me') {
      await _deleteForMe(message);
    } else if (result == 'everyone') {
      await _deleteForEveryone(message);
    }
  }

  Future<void> _deleteForMe(Message message) async {
    try {
      await _msgRepo.deleteForMe(message.id);
      setState(() {
        _messageReactions.remove(message.id);
        _messages.removeWhere((m) => m.id == message.id);
      });
      _showSnack('Deleted for me');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to delete: $e');
    }
  }

  Future<void> _deleteForEveryone(Message message) async {
    try {
      await _msgRepo.deleteForEveryone(message.id);
      setState(() {
        _messageReactions.remove(message.id);
        _messages.removeWhere((m) => m.id == message.id);
      });
      _showSnack('Deleted for everyone');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to delete for everyone: $e');
    }
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
      backgroundColor: isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
      appBar: _buildAppBar(isDark),
      body: Column(
        children: [
          Expanded(
            child: Builder(
              builder: (context) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (_loadError != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Failed to load messages',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _loadError!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: const Color(0xFF666666),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadMessages,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _messages.length + _getDaySeparatorCount(),
                  itemBuilder: (context, index) {
                    return _buildMessageOrSeparator(index, isDark);
                  },
                );
              },
            ),
          ),
          ChatInput(
            onSendMessage: _sendMessage,
            onVoiceRecord: _handleVoiceRecord,
            onAttachment: _showAttachmentOptions,
            replyToMessage: _replyToMessage?.content,
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
        IconButton(
          onPressed: () {},
          icon: Icon(
            Icons.videocam,
            color: isDark ? Colors.white : Colors.black,
            size: 24,
          ),
        ),
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
                reactionEmoji: reaction,
              ),
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
      const months = [
        'January','February','March','April','May','June',
        'July','August','September','October','November','December',
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
              color: const Color.fromARGB(255, 255, 255, 255),
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