import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:video_compress/video_compress.dart';
import 'package:audioplayers/audioplayers.dart';
import 'models/message.dart';
import 'package:file_picker/file_picker.dart';
import 'widgets/message_actions_sheet.dart';
import 'package:provider/provider.dart';
import 'repositories/interfaces/message_repository.dart';
import 'repositories/firebase/firebase_message_repository.dart';
import 'repositories/interfaces/conversation_repository.dart';
import 'conversations_page.dart' show ConversationUpdateNotifier;
import 'repositories/interfaces/block_repository.dart';
import 'repositories/interfaces/storage_repository.dart';
import 'core/audio_recorder.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:async';
import 'core/profile_api.dart';
import 'repositories/firebase/firebase_user_repository.dart';
import 'widgets/media_preview_page.dart';
import 'core/video_utils_stub.dart' if (dart.library.io) 'core/video_utils_io.dart';
import 'utils/profile_navigation.dart';
import 'services/media_compression_service.dart';
import 'core/i18n/language_provider.dart';

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
  final TextEditingController _messageController = TextEditingController();
  final List<Message> _messages = [];
  Message? _replyToMessage;
  final Set<String> _starredIds = <String>{};
  final Map<String, String> _messageReactions = <String, String>{};

  late MessageRepository _msgRepo;
  late ConversationRepository _convRepo;
  late BlockRepository _blockRepo;
  late StorageRepository _storageRepo;
  final FirebaseMessageRepository _firebaseMsgRepo = FirebaseMessageRepository();
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _resolvedConversationId;
  bool _isRecording = false;
  bool _isLoading = false;
  bool _sending = false;
  String? _loadError;
  Timer? _pollTimer;
  bool _isRefreshing = false;
  bool _isBlocked = false;
  bool _isBlockedBy = false;
  
  // Audio player for voice messages
  AudioPlayer? _audioPlayer;
  String? _playingMessageId;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  
  // Hydrated user profile (fetched if widget.otherUser has incomplete data)
  String? _hydratedName;
  String? _hydratedAvatarUrl;

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
  _blockRepo = context.read<BlockRepository>();
  _storageRepo = context.read<StorageRepository>();
  _checkBlockStatus();
  _hydrateUserProfile(); // Fetch real user profile if data is incomplete
  _initLoad();
  _startPolling();
}

/// Fetch real user profile if the provided name looks like an email or is empty
Future<void> _hydrateUserProfile() async {
  final name = widget.otherUser.name;
  final avatar = widget.otherUser.avatarUrl;
  
  // Check if name looks like email or is empty
  final needsHydration = name.isEmpty || 
      name.contains('@') || 
      avatar == null || 
      avatar.isEmpty;
  
  if (!needsHydration) return;
  
  try {
    final userRepo = FirebaseUserRepository();
    final profile = await userRepo.getUserProfile(widget.otherUser.id);
    
    if (profile != null && mounted) {
      String displayName = profile.displayName ?? '';
      if (displayName.isEmpty) {
        final firstName = profile.firstName ?? '';
        final lastName = profile.lastName ?? '';
        if (firstName.isNotEmpty || lastName.isNotEmpty) {
          displayName = '$firstName $lastName'.trim();
        } else {
          displayName = profile.username ?? name;
        }
      }
      
      setState(() {
        _hydratedName = displayName.isNotEmpty ? displayName : null;
        _hydratedAvatarUrl = profile.avatarUrl;
      });
    }
  } catch (_) {
    // Ignore errors - will use original data
  }
}

Future<void> _checkBlockStatus() async {
  try {
    final hasBlocked = await _blockRepo.hasBlocked(widget.otherUser.id);
    final blockedBy = await _blockRepo.isBlockedBy(widget.otherUser.id);
    if (mounted) {
      setState(() {
        _isBlocked = hasBlocked;
        _isBlockedBy = blockedBy;
      });
    }
  } catch (e) {
    // Ignore error, defaults to not blocked
  }
}

Future<void> _handleUnblock() async {
  try {
    await _blockRepo.unblockUser(widget.otherUser.id);
    if (mounted) {
      setState(() => _isBlocked = false);
      _showSnack('${widget.otherUser.name} unblocked');
    }
  } catch (e) {
    if (mounted) {
      _showSnack('Failed to unblock user');
    }
  }
}

  void _initLoad() {
    if (widget.conversationId != null && widget.conversationId!.isNotEmpty) {
      _resolvedConversationId = widget.conversationId;
      // FASTFEED: Load cached messages instantly, then refresh from server
      _loadFromCacheInstantly().then((_) {
        if (mounted) {
          _loadMessages();
          _markRead();
        }
      });
    } else {
      _ensureConversationAndLoad();
    }
  }

  /// INSTANT: Load cached messages (no network wait)
  Future<void> _loadFromCacheInstantly() async {
    if (_resolvedConversationId == null) return;
    try {
      final records = await _firebaseMsgRepo.listFromCache(_resolvedConversationId!);
      if (records.isNotEmpty && mounted) {
        final mapped = records.map(_toUiMessage).toList();
        setState(() {
          _messages.clear();
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
      }
    } catch (_) {
      // Cache miss - will load from server
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
      // Only show loading if we don't have cached messages
      if (_messages.isEmpty) {
        setState(() {
          _isLoading = true;
          _loadError = null;
        });
      }
      if (_resolvedConversationId == null) return;
      
      final records = await _msgRepo.list(_resolvedConversationId!);
      final mapped = records.map(_toUiMessage).toList();
      
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _messages.addAll(mapped);
        _messageReactions.clear();
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
    
    // Smart merge: Keep optimistic (temp_) messages until server data replaces them
    // This prevents flicker when sending messages
    final tempMessages = _messages.where((m) => m.id.startsWith('temp_')).toList();
    final serverIds = mapped.map((m) => m.id).toSet();
    
    setState(() {
      _messages.clear();
      _messages.addAll(mapped);
      // Re-add temp messages that aren't yet on server (still sending)
      for (final temp in tempMessages) {
        if (!serverIds.contains(temp.id)) {
          _messages.add(temp);
        }
      }
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
  _messageController.dispose();
  _audioPlayer?.dispose();
  super.dispose();
}

  void _initAudioPlayer() {
    _audioPlayer = AudioPlayer();
    _audioPlayer!.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
        if (state == PlayerState.completed) {
          _playingMessageId = null;
          _currentPosition = Duration.zero;
        }
      });
    });
    _audioPlayer!.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _currentPosition = position);
    });
    _audioPlayer!.onDurationChanged.listen((duration) {
      // Duration tracked via attachment metadata
    });
  }

  Future<void> _playVoiceMessage(String messageId, String url) async {
    if (_audioPlayer == null) _initAudioPlayer();
    
    if (_playingMessageId == messageId && _isPlaying) {
      await _audioPlayer!.pause();
    } else if (_playingMessageId == messageId) {
      await _audioPlayer!.resume();
    } else {
      _playingMessageId = messageId;
      await _audioPlayer!.play(UrlSource(url));
    }
  }

  String _formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds.remainder(60))}';
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
    // OPTIMISTIC UI: Show message immediately for instant feedback
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final currentUid = fb.FirebaseAuth.instance.currentUser?.uid ?? 'me';
    final optimisticMsg = Message(
      id: tempId,
      senderId: currentUid,
      senderName: 'You',
      senderAvatar: null,
      content: content,
      type: MessageType.text,
      attachments: const [],
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      isFromCurrentUser: true,
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
      _messages.add(optimisticMsg);
      _replyToMessage = null;
    });
    _scrollToBottom();
    
    // Send in background
    try {
      final convId = await _requireConversationId();
      await _msgRepo.sendText(
        conversationId: convId,
        otherUserId: null,
        text: content,
        replyToMessageId: optimisticMsg.replyTo?.messageId,
      );
      
      // FASTFEED: Notify conversation list instantly
      ConversationUpdateNotifier().notifyMessageSent(
        conversationId: convId,
        messageText: content,
        messageType: 'text',
      );
      
      // Remove temp message before refresh to avoid duplicate display
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == tempId);
        });
      }
      
      // Refresh to get the real message from server
      await _refreshMessages();
    } catch (e) {
      // Remove failed message
      setState(() {
        _messages.removeWhere((m) => m.id == tempId);
      });
      if (mounted) _showSnack('Failed to send: $e');
    }
  }

  Future<void> _sendVoiceMessage(VoiceRecordingResult recording) async {
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _showSnack('User not authenticated');
      return;
    }
    
    final durationSec = recording.duration.inSeconds;
    final replyToId = _replyToMessage?.id;
    
    // Clear reply state
    setState(() => _replyToMessage = null);
    
    // Upload and send in background - no temp bubble
    try {
      String audioUrl;
      int sizeBytes;
      String contentType;

      if (kIsWeb) {
        final bytes = await (_audioRecorder as dynamic).takeRecordedBytes() as Uint8List?;
        if (bytes == null || bytes.isEmpty) {
          throw Exception('No recorded audio');
        }
        final ext = (_audioRecorder as dynamic).currentExtension as String? ?? 'webm';
        final path = _storageRepo.generateUniqueFileName(
          uid: uid,
          extension: ext,
          prefix: 'voice_messages',
        );
        contentType = ext == 'm4a' || ext == 'aac' ? 'audio/mp4' : 'audio/webm';
        audioUrl = await _storageRepo.uploadFile(
          path: path,
          bytes: bytes,
          contentType: contentType,
        );
        sizeBytes = bytes.length;
        debugPrint('📤 Uploaded web voice as .$ext');
      } else {
        if (recording.filePath == null) {
          throw Exception('Recording file path is null');
        }
        final file = File(recording.filePath!);
        if (!await file.exists()) {
          throw Exception('Recording file not found');
        }
        final path = _storageRepo.generateUniqueFileName(
          uid: uid,
          extension: 'm4a',
          prefix: 'voice_messages',
        );
        contentType = 'audio/m4a';
        audioUrl = await _storageRepo.uploadFileFromPath(
          path: path,
          file: file,
          contentType: contentType,
        );
        sizeBytes = recording.fileSize;
        try { await file.delete(); } catch (_) {}
      }

      final convId = await _requireConversationId();
      await _msgRepo.sendVoice(
        conversationId: convId,
        otherUserId: null,
        audioUrl: audioUrl,
        durationSec: durationSec,
        fileSize: sizeBytes,
        replyToMessageId: replyToId,
      );

      // Notify conversation list
      ConversationUpdateNotifier().notifyMessageSent(
        conversationId: convId,
        messageText: '🎤 Voice message',
        messageType: 'voice',
      );

      // Refresh to show the new message
      if (mounted) await _refreshMessages();
    } catch (e) {
      if (mounted) _showSnack('Failed to send voice message: $e');
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
                label: Provider.of<LanguageProvider>(context, listen: false).t('common.camera'),
                color: const Color(0xFF34C759),
                onTap: () => _pickMedia(ImageSource.camera),
                isDark: isDark,
              ),
              _buildAttachmentOption(
                icon: Icons.photo_library,
                label: Provider.of<LanguageProvider>(context, listen: false).t('common.gallery'),
                color: const Color(0xFF007AFF),
                onTap: () => _pickMedia(ImageSource.gallery),
                isDark: isDark,
              ),
              _buildAttachmentOption(
                icon: Icons.videocam,
                label: Provider.of<LanguageProvider>(context, listen: false).t('common.video'),
                color: const Color(0xFFFF9500),
                onTap: () => _pickVideo(),
                isDark: isDark,
              ),
              _buildAttachmentOption(
                icon: Icons.description,
                label: Provider.of<LanguageProvider>(context, listen: false).t('common.file'),
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
      // Force instant refresh
      await _refreshMessages();
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
        settings: const RouteSettings(name: 'media_preview'),
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

      String guessVideoContentType(String ext) {
        switch (ext.toLowerCase()) {
          case 'mp4':
            return 'video/mp4';
          case 'webm':
            return 'video/webm';
          case 'mov':
            return 'video/quicktime';
          case 'mkv':
            return 'video/x-matroska';
          case 'avi':
            return 'video/x-msvideo';
          default:
            return 'video/mp4';
        }
      }

      // OPTIMIZATION: Upload all media in parallel for speed
      debugPrint('📤 Starting parallel upload of ${mediaFiles.length} media files');
      final uploadFutures = mediaFiles.map((mediaFile) async {
        final nameOrPath =
            mediaFile.name.isNotEmpty ? mediaFile.name : mediaFile.path;

        final dot = nameOrPath.lastIndexOf('.');
        final ext = (dot != -1 && dot < nameOrPath.length - 1)
            ? nameOrPath.substring(dot + 1).toLowerCase()
            : 'bin';

        String url;
        int? fileSize;
        String? thumbUrl;
        final compressionService = MediaCompressionService();
        final isVideo = isVideoPath(nameOrPath);
        final isImage = MediaCompressionService.isImage(nameOrPath);

        if (kIsWeb) {
          // Web: Compress images + generate thumbnails
          if (isImage) {
            final originalBytes = await mediaFile.readAsBytes();
            
            // Generate thumbnail in parallel with compression
            final thumbFuture = compressionService.generateFeedThumbnailFromBytes(
              bytes: originalBytes,
              filename: nameOrPath,
              maxSize: 400,
              quality: 60,
            );
            
            final compressedBytes = await compressionService.compressImageBytes(
              bytes: originalBytes,
              filename: nameOrPath,
              quality: 92,
              minWidth: 1920,
              minHeight: 1920,
            );
            
            final thumbBytes = await thumbFuture;
            final bytes = compressedBytes ?? originalBytes;
            fileSize = bytes.length;
            
            // Upload full + thumbnail in parallel
            final fullUpload = profileApi.uploadBytes(bytes, ext: ext);
            final thumbUpload = thumbBytes != null 
                ? profileApi.uploadBytes(thumbBytes, ext: 'jpg', contentType: 'image/jpeg')
                : Future.value('');
            final results = await Future.wait([fullUpload, thumbUpload]);
            url = results[0];
            if (results[1].isNotEmpty) thumbUrl = results[1];
          } else {
            // Video on web - upload without compression
            final bytes = await mediaFile.readAsBytes();
            fileSize = bytes.length;
            final ct = isVideo ? guessVideoContentType(ext) : null;
            url = await profileApi.uploadBytes(bytes, ext: ext, contentType: ct);
          }
        } else {
          // Mobile: Compress both images and videos + generate thumbnails
          if (isImage) {
            final originalBytes = await mediaFile.readAsBytes();
            
            // Generate thumbnail (400px) in parallel with compression
            final thumbFuture = compressionService.generateFeedThumbnailFromBytes(
              bytes: originalBytes,
              filename: nameOrPath,
              maxSize: 400,
              quality: 60,
            );
            
            final compressedBytes = await compressionService.compressImage(
              filePath: mediaFile.path,
              quality: 92,
              minWidth: 1920,
              minHeight: 1920,
            );
            
            final thumbBytes = await thumbFuture;
            
            if (compressedBytes != null) {
              fileSize = compressedBytes.length;
              // Upload full image + thumbnail in parallel
              final fullUpload = profileApi.uploadBytes(compressedBytes, ext: ext);
              final thumbUpload = thumbBytes != null 
                  ? profileApi.uploadBytes(thumbBytes, ext: 'jpg', contentType: 'image/jpeg')
                  : Future.value('');
              final results = await Future.wait([fullUpload, thumbUpload]);
              url = results[0];
              if (results[1].isNotEmpty) thumbUrl = results[1];
            } else {
              final file = File(mediaFile.path);
              fileSize = await file.length();
              url = await profileApi.uploadFile(file);
              // Upload thumbnail if available
              if (thumbBytes != null) {
                thumbUrl = await profileApi.uploadBytes(thumbBytes, ext: 'jpg', contentType: 'image/jpeg');
              }
            }
          } else if (isVideo) {
            debugPrint('🎥 Compressing video before sending: $nameOrPath');
            final compressedFile = await compressionService.compressVideo(
              filePath: mediaFile.path,
              quality: VideoQuality.HighestQuality,
            );
            
            if (compressedFile != null) {
              fileSize = await compressedFile.length();
              url = await profileApi.uploadFile(compressedFile);
              
              // Generate thumbnail from compressed video
              try {
                final thumb = await generateVideoThumbnail(compressedFile.path);
                if (thumb != null && thumb.isNotEmpty) {
                  thumbUrl = await profileApi.uploadBytes(thumb, ext: 'jpg', contentType: 'image/jpeg');
                }
              } catch (_) {}
            } else {
              final file = File(mediaFile.path);
              fileSize = await file.length();
              url = await profileApi.uploadFile(file);
              
              // Generate thumbnail from original video
              try {
                final thumb = await generateVideoThumbnail(file.path);
                if (thumb != null && thumb.isNotEmpty) {
                  thumbUrl = await profileApi.uploadBytes(thumb, ext: 'jpg', contentType: 'image/jpeg');
                }
              } catch (_) {}
            }
          } else {
            // Other file types - upload without compression
            final file = File(mediaFile.path);
            fileSize = await file.length();
            url = await profileApi.uploadFile(file);
          }
        }

        return {
          'type': isVideo ? 'video' : 'image',
          'url': url,
          'fileName': mediaFile.name,
          'fileSize': fileSize,
          if (thumbUrl != null) 'thumbnail': thumbUrl,
        };
      }).toList();
      
      // Wait for all uploads to complete in parallel
      final uploadedAttachments = await Future.wait(uploadFutures);
      attachments.addAll(uploadedAttachments);
      debugPrint('✅ All ${attachments.length} media files uploaded');

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
      
      // FASTFEED: Notify conversation list instantly
      ConversationUpdateNotifier().notifyMessageSent(
        conversationId: convId,
        messageText: caption.isNotEmpty ? caption : '📷 Media',
        messageType: attachments.first['type'] ?? 'image',
      );

      if (!mounted) return;
      _hideSnack();
      // Force instant refresh
      await _refreshMessages();
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
          title: Text(Provider.of<LanguageProvider>(ctx, listen: false).t('chat.delete_message_title')),
          content: Text(
            isMine
                ? Provider.of<LanguageProvider>(ctx, listen: false).t('chat.delete_for_me_or_everyone')
                : Provider.of<LanguageProvider>(ctx, listen: false).t('chat.delete_this_message'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('me'),
              child: Text(Provider.of<LanguageProvider>(ctx, listen: false).t('chat.delete_for_me')),
            ),
            if (isMine)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop('everyone'),
                child: Text(Provider.of<LanguageProvider>(ctx, listen: false).t('chat.delete_for_everyone')),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(Provider.of<LanguageProvider>(ctx, listen: false).t('common.cancel')),
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

  Future<void> _startRecording() async {
    if (_isRecording) return;
    
    // Check permission with timeout to prevent UI freeze
    bool hasPermission = false;
    try {
      hasPermission = await _audioRecorder.hasPermission().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('⚠️ Permission check timed out');
          return false;
        },
      );
    } catch (e) {
      debugPrint('❌ Error checking microphone permission: $e');
      return;
    }
    
    if (!hasPermission) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).t('chat.microphone_permission_required'))),
      );
      return;
    }

    // Start recording immediately - no delay
    setState(() => _isRecording = true);
    await _audioRecorder.startRecording();
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;

    final result = await _audioRecorder.stopRecording();
    setState(() => _isRecording = false);

    if (result != null) {
      await _sendVoiceMessage(result);
    }
  }

  void _cancelRecordingInline() async {
    if (!_isRecording) return;
    await _audioRecorder.stopRecording();
    setState(() => _isRecording = false);
  }

  Future<void> _sendTextMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    
    _messageController.clear();
    setState(() => _sending = true);
    
    try {
      await _sendMessage(content);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _buildInputArea(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reply preview
            if (_replyToMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFFBFAE01),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _replyToMessage!.senderName,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFBFAE01),
                            ),
                          ),
                          Text(
                            _replyToMessage!.content,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _cancelReply,
                      child: const Icon(Icons.close, size: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                // Attachment button
                IconButton(
                  icon: Icon(Icons.add, color: Colors.grey[600]),
                  onPressed: _sending ? null : _showAttachmentOptions,
                ),

                // Text input or recording indicator
                Expanded(
                  child: _isRecording
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.mic, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                Provider.of<LanguageProvider>(context, listen: false).t('chat.recording'),
                                style: GoogleFonts.inter(color: Colors.red),
                              ),
                            ],
                          ),
                        )
                      : TextField(
                          controller: _messageController,
                          style: GoogleFonts.inter(color: textColor),
                          maxLines: 4,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: Provider.of<LanguageProvider>(context, listen: false).t('chat.type_message'),
                            hintStyle: GoogleFonts.inter(color: Colors.grey),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                ),

                const SizedBox(width: 8),

                // Send or Voice button
                if (_isRecording)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: _cancelRecordingInline,
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Color(0xFFBFAE01)),
                        onPressed: _stopRecordingAndSend,
                      ),
                    ],
                  )
                else if (_messageController.text.trim().isNotEmpty)
                  IconButton(
                    icon: Icon(
                      Icons.send,
                      color: _sending ? Colors.grey : const Color(0xFFBFAE01),
                    ),
                    onPressed: _sending ? null : _sendTextMessage,
                  )
                else
                  GestureDetector(
                    onTap: () {
                      // Instant tap to start recording - no delay
                      if (!_isRecording) {
                        _startRecording();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFFBFAE01),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mic, color: Colors.black, size: 20),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
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
                            child: Text(Provider.of<LanguageProvider>(context).t('chat.retry')),
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
          // Show blocked message or chat input
          if (_isBlocked)
            _buildBlockedBanner(isDark)
          else if (_isBlockedBy)
            _buildBlockedByBanner(isDark)
          else
            _buildInputArea(isDark),
        ],
      ),
    );
  }

  Widget _buildBlockedBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[200],
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.block,
            color: Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You blocked ${widget.otherUser.name}',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          TextButton(
            onPressed: _handleUnblock,
            child: Text(
              'Unblock',
              style: GoogleFonts.inter(
                color: const Color(0xFFBFAE01),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedByBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[200],
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You can\'t send messages to this user',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
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
      title: GestureDetector(
        onTap: () {
          navigateToUserProfile(
            context: context,
            userId: widget.otherUser.id,
            userName: widget.otherUser.name,
            userAvatarUrl: widget.otherUser.avatarUrl ?? '',
            userBio: '',
          );
        },
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: (_hydratedAvatarUrl ?? widget.otherUser.avatarUrl) != null &&
                      (_hydratedAvatarUrl ?? widget.otherUser.avatarUrl)!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: (_hydratedAvatarUrl ?? widget.otherUser.avatarUrl)!,
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
                      errorWidget: (context, url, error) => Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFBFAE01).withValues(alpha: 51),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            (_hydratedName ?? widget.otherUser.name).isNotEmpty
                                ? (_hydratedName ?? widget.otherUser.name)[0].toUpperCase()
                                : 'U',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFBFAE01),
                            ),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFBFAE01).withValues(alpha: 51),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          (_hydratedName ?? widget.otherUser.name).isNotEmpty
                              ? (_hydratedName ?? widget.otherUser.name)[0].toUpperCase()
                              : 'U',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFBFAE01),
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hydratedName ?? widget.otherUser.name,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    widget.otherUser.isOnline ? Provider.of<LanguageProvider>(context).t('chat.online') : Provider.of<LanguageProvider>(context).t('chat.last_seen'),
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

  Widget _buildMessageBubble(Message message, bool isDark, String? reaction) {
    final isMe = message.isFromCurrentUser;
    final isSending = message.status == MessageStatus.sending;
    final bubbleColor = isMe
        ? const Color(0xFFBFAE01)
        : (isDark ? const Color(0xFF2A2A2A) : Colors.white);
    final bubbleTextColor = isMe ? Colors.black : (isDark ? Colors.white : Colors.black);

    return GestureDetector(
      onLongPress: () => _showMessageActions(message),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 12, right: 12),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe)
              CircleAvatar(
                radius: 14,
                backgroundImage: widget.otherUser.avatarUrl != null && widget.otherUser.avatarUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(widget.otherUser.avatarUrl!)
                    : null,
                backgroundColor: Colors.grey[400],
                child: widget.otherUser.avatarUrl == null || widget.otherUser.avatarUrl!.isEmpty
                    ? Text(
                        widget.otherUser.name.isNotEmpty ? widget.otherUser.name[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 10),
                      )
                    : null,
              ),
            if (!isMe) const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Reply preview
                  if (message.replyTo != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.replyTo!.senderName,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFBFAE01),
                            ),
                          ),
                          Text(
                            message.replyTo!.content,
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                  // Message content
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSending ? bubbleColor.withValues(alpha: 0.7) : bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Attachments
                        if (message.attachments.isNotEmpty)
                          ...message.attachments.map((att) {
                            if (att.type == MediaType.image) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: isSending
                                      ? Container(
                                          width: 200,
                                          height: 150,
                                          color: Colors.grey[300],
                                          child: const Center(child: CircularProgressIndicator()),
                                        )
                                      : CachedNetworkImage(
                                          imageUrl: att.url,
                                          width: 200,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(
                                            width: 200,
                                            height: 150,
                                            color: Colors.grey[300],
                                            child: const Center(child: CircularProgressIndicator()),
                                          ),
                                        ),
                                ),
                              );
                            } else if (att.type == MediaType.voice) {
                              final isThisPlaying = _playingMessageId == message.id && _isPlaying;
                              final duration = att.duration ?? Duration.zero;
                              final displayDuration = _playingMessageId == message.id ? _currentPosition : duration;
                              
                              return GestureDetector(
                                onTap: isSending ? null : () => _playVoiceMessage(message.id, att.url),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isSending ? Icons.upload : (isThisPlaying ? Icons.pause : Icons.play_arrow),
                                        color: bubbleTextColor,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isSending 
                                                ? Provider.of<LanguageProvider>(context, listen: false).t('chat.sending')
                                                : 'Voice message',
                                            style: GoogleFonts.inter(color: bubbleTextColor, fontSize: 13),
                                          ),
                                          Text(
                                            _formatDuration(displayDuration),
                                            style: GoogleFonts.inter(color: bubbleTextColor.withValues(alpha: 0.7), fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            } else if (att.type == MediaType.video) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  width: 200,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[800],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: isSending
                                        ? const CircularProgressIndicator()
                                        : const Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
                                  ),
                                ),
                              );
                            } else if (att.type == MediaType.document) {
                              return Container(
                                padding: const EdgeInsets.all(8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.attach_file, color: bubbleTextColor, size: 20),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        isSending ? 'Uploading...' : (att.fileName ?? 'File'),
                                        style: GoogleFonts.inter(color: bubbleTextColor),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }),

                        // Text content
                        if (message.content.isNotEmpty)
                          Text(
                            message.content,
                            style: GoogleFonts.inter(fontSize: 14, color: bubbleTextColor),
                          ),

                        // Timestamp and status
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isSending 
                                  ? Provider.of<LanguageProvider>(context, listen: false).t('chat.sending')
                                  : _formatTime(message.timestamp),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: isMe ? Colors.black54 : Colors.grey,
                              ),
                            ),
                            if (isSending) ...[
                              const SizedBox(width: 4),
                              SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: isMe ? Colors.black54 : Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Reaction
                  if (reaction != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(reaction, style: const TextStyle(fontSize: 14)),
                    ),
                ],
              ),
            ),
            if (isMe) const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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

        return _buildMessageBubble(message, isDark, reaction);
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
      dateText = Provider.of<LanguageProvider>(context, listen: false).t('common.today');
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      dateText = Provider.of<LanguageProvider>(context, listen: false).t('common.yesterday');
    } else {
      final lang = Provider.of<LanguageProvider>(context, listen: false);
      final months = [
        lang.t('chat.month_january'), lang.t('chat.month_february'), lang.t('chat.month_march'),
        lang.t('chat.month_april'), lang.t('chat.month_may'), lang.t('chat.month_june'),
        lang.t('chat.month_july'), lang.t('chat.month_august'), lang.t('chat.month_september'),
        lang.t('chat.month_october'), lang.t('chat.month_november'), lang.t('chat.month_december'),
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