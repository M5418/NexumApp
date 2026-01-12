import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../theme_provider.dart';
import '../core/i18n/language_provider.dart';
import '../core/audio_recorder.dart';
import '../repositories/firebase/firebase_group_repository.dart';
import '../repositories/interfaces/storage_repository.dart';
import '../services/media_compression_service.dart';
import '../models/group_chat.dart';
import 'group_info_page.dart';

class GroupChatPage extends StatefulWidget {
  final GroupChat group;

  const GroupChatPage({
    super.key,
    required this.group,
  });

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _groupRepo = FirebaseGroupRepository();
  final _audioRecorder = AudioRecorder();

  late GroupChat _group;
  List<GroupMessage> _messages = [];
  StreamSubscription<List<GroupMessage>>? _messagesSubscription;
  
  bool _loading = true;
  bool _sending = false;
  bool _isRecording = false;
  bool _isRecordingLocked = false; // Locked via swipe up
  double _swipeUpOffset = 0; // Track swipe distance for animation
  DateTime? _recordingStartTime; // Track when recording started for min duration
  Timer? _recordingTimer; // Timer for updating recording duration display
  Duration _recordingDuration = Duration.zero; // Current recording duration
  GroupMessage? _replyTo;

  String? get _currentUserId => fb.FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _loadFromCacheInstantly();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messagesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadFromCacheInstantly() async {
    // Try cache first
    try {
      final cached = await _groupRepo.getMessagesFromCache(_group.id);
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _messages = cached;
          _loading = false;
        });
      }
    } catch (_) {}

    // Setup real-time listener
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    _messagesSubscription?.cancel();
    _messagesSubscription = _groupRepo.streamMessages(_group.id).listen((messages) {
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
    }, onError: (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  Future<void> _markAsRead() async {
    await _groupRepo.markAsRead(_group.id);
  }

  Future<void> _sendMessage({
    String? content,
    String type = 'text',
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final text = content ?? _messageController.text.trim();
    if (text.isEmpty && attachments.isEmpty) return;

    final uid = _currentUserId;
    if (uid == null) return;

    // Create optimistic message
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final user = fb.FirebaseAuth.instance.currentUser;
    final optimisticMsg = GroupMessage(
      id: tempId,
      groupId: _group.id,
      senderId: uid,
      senderName: user?.displayName ?? 'You',
      senderAvatar: user?.photoURL,
      content: text,
      type: type,
      attachments: attachments,
      createdAt: DateTime.now(),
      replyToId: _replyTo?.id,
      replyToSenderName: _replyTo?.senderName,
      replyToContent: _replyTo?.content,
      replyToType: _replyTo?.type,
      isSending: true,
    );

    // Add optimistic message immediately
    setState(() {
      _messages.insert(0, optimisticMsg);
      _replyTo = null;
      _sending = true;
    });
    _messageController.clear();

    // Scroll to bottom
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    // Send in background
    try {
      await _groupRepo.sendMessage(
        groupId: _group.id,
        content: text,
        type: type,
        attachments: attachments,
        replyToId: optimisticMsg.replyToId,
        replyToSenderName: optimisticMsg.replyToSenderName,
        replyToContent: optimisticMsg.replyToContent,
        replyToType: optimisticMsg.replyToType,
      );

      // Remove temp message - real one will come from stream
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == tempId);
          _sending = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == tempId);
        _sending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    }
  }

  Future<void> _pickAndSendImage() async {
    final storageRepo = context.read<StorageRepository>();
    final compressionService = MediaCompressionService();
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty) return;

    setState(() => _sending = true);

    try {
      final attachments = <Map<String, dynamic>>[];

      for (final image in images) {
        final storagePath = 'groups/${_group.id}/media/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
        String? url;

        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          final compressed = await compressionService.compressImageBytes(
            bytes: bytes,
            filename: image.name,
            quality: 85,
          );
          if (compressed != null) {
            url = await storageRepo.uploadFile(
              path: storagePath,
              bytes: compressed,
              contentType: 'image/jpeg',
            );
          }
        } else {
          final compressed = await compressionService.compressImage(
            filePath: image.path,
            quality: 85,
          );
          if (compressed != null) {
            url = await storageRepo.uploadFile(
              path: storagePath,
              bytes: compressed,
              contentType: 'image/jpeg',
            );
          }
        }

        if (url != null) {
          attachments.add({
            'type': 'image',
            'url': url,
            'fileName': image.name,
          });
        }
      }

      if (attachments.isNotEmpty) {
        await _sendMessage(
          content: '',
          type: 'image',
          attachments: attachments,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendFile() async {
    final storageRepo = context.read<StorageRepository>();
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _sending = true);

    try {
      final attachments = <Map<String, dynamic>>[];

      for (final file in result.files) {
        if (file.bytes == null && file.path == null) continue;

        final storagePath = 'groups/${_group.id}/files/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        String? url;

        if (kIsWeb && file.bytes != null) {
          url = await storageRepo.uploadFile(
            path: storagePath,
            bytes: file.bytes!,
          );
        } else if (file.path != null) {
          final fileBytes = await File(file.path!).readAsBytes();
          url = await storageRepo.uploadFile(
            path: storagePath,
            bytes: fileBytes,
          );
        }

        if (url != null) {
          attachments.add({
            'type': 'file',
            'url': url,
            'fileName': file.name,
            'fileSize': file.size,
          });
        }
      }

      if (attachments.isNotEmpty) {
        await _sendMessage(
          content: '',
          type: 'file',
          attachments: attachments,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload file: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
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
    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
    });
    
    // Start timer to update duration display every 100ms
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_recordingStartTime != null && mounted) {
        setState(() {
          _recordingDuration = DateTime.now().difference(_recordingStartTime!);
        });
      }
    });
    
    await _audioRecorder.startRecording();
  }

  Future<void> _stopRecordingAndSend() async {
    if (!_isRecording) return;
    final storageRepo = context.read<StorageRepository>();

    _recordingTimer?.cancel();
    _recordingTimer = null;
    
    final result = await _audioRecorder.stopRecording();
    final path = result?.filePath;
    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });

    if (path == null) return;

    // Upload and send in background - NO temp bubble
    try {
      final storagePath = 'groups/${_group.id}/voice/${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      final fileBytes = await File(path).readAsBytes();
      final url = await storageRepo.uploadFile(
        path: storagePath,
        bytes: fileBytes,
        contentType: 'audio/m4a',
      );

      await _groupRepo.sendMessage(
        groupId: _group.id,
        content: '',
        type: 'voice',
        attachments: [
          {
            'type': 'voice',
            'url': url,
            'fileName': 'voice_message.m4a',
          }
        ],
      );
      // Real message will appear via stream subscription
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send voice message: $e')),
      );
    }
  }

  void _cancelRecording() async {
    if (!_isRecording) return;
    
    _recordingTimer?.cancel();
    _recordingTimer = null;
    
    await _audioRecorder.stopRecording();
    setState(() {
      _isRecording = false;
      _isRecordingLocked = false;
      _recordingDuration = Duration.zero;
    });
  }

  String _formatRecordingDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final tenths = (duration.inMilliseconds ~/ 100) % 10;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.$tenths';
  }

  void _showReactionPicker(GroupMessage message) {
    final emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: emojis.map((emoji) {
            return GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _addReaction(message, emoji);
              },
              child: Text(emoji, style: const TextStyle(fontSize: 32)),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _addReaction(GroupMessage message, String emoji) async {
    try {
      final currentReaction = message.reactions[_currentUserId];
      if (currentReaction == emoji) {
        await _groupRepo.removeReaction(_group.id, message.id);
      } else {
        await _groupRepo.addReaction(_group.id, message.id, emoji);
      }
    } catch (e) {
      debugPrint('Failed to add reaction: $e');
    }
  }

  void _showMessageOptions(GroupMessage message) {
    final isMyMessage = message.senderId == _currentUserId;
    final isAdmin = _group.isAdmin(_currentUserId ?? '');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply),
              title: Text(Provider.of<LanguageProvider>(context, listen: false).t('chat.reply')),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyTo = message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: Text(Provider.of<LanguageProvider>(context, listen: false).t('chat.react')),
              onTap: () {
                Navigator.pop(ctx);
                _showReactionPicker(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(Provider.of<LanguageProvider>(context, listen: false).t('chat.copy')),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).t('chat.copied'))),
                );
              },
            ),
            if (isMyMessage || isAdmin)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(
                  Provider.of<LanguageProvider>(context, listen: false).t('chat.delete'),
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _groupRepo.deleteMessage(_group.id, message.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDarkMode;
        final bgColor = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
        final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: _buildAppBar(isDark, textColor),
          body: Column(
            children: [
              // Messages List
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01)))
                    : _messages.isEmpty
                        ? Center(
                            child: Text(
                              lang.t('groups.no_messages'),
                              style: GoogleFonts.inter(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final message = _messages[index];
                              final isMe = message.senderId == _currentUserId;
                              final showAvatar = !isMe && (index == _messages.length - 1 ||
                                  _messages[index + 1].senderId != message.senderId);

                              return _buildMessageBubble(
                                message,
                                isMe,
                                showAvatar,
                                isDark,
                                cardColor,
                                textColor,
                              );
                            },
                          ),
              ),

              // Reply Preview
              if (_replyTo != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: isDark ? Colors.grey[900] : Colors.grey[200],
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 40,
                        color: const Color(0xFFBFAE01),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _replyTo!.senderName,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFBFAE01),
                              ),
                            ),
                            Text(
                              _replyTo!.content,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () => setState(() => _replyTo = null),
                      ),
                    ],
                  ),
                ),

              // Input Area
              _buildInputArea(isDark, cardColor, textColor),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark, Color textColor) {
    return AppBar(
      backgroundColor: isDark ? Colors.black : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: textColor),
        onPressed: () => Navigator.pop(context),
      ),
      title: GestureDetector(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: 'group_info'),
              builder: (_) => GroupInfoPage(group: _group),
            ),
          );
          if (result is GroupChat) {
            setState(() => _group = result);
          } else if (result == 'deleted' || result == 'left') {
            if (mounted) Navigator.pop(context);
          }
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: _group.avatarUrl != null
                  ? CachedNetworkImageProvider(_group.avatarUrl!)
                  : null,
              backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
              child: _group.avatarUrl == null
                  ? Icon(Icons.group, size: 18, color: Colors.grey[500])
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _group.name,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_group.memberIds.length} ${Provider.of<LanguageProvider>(context, listen: false).t('groups.members_count')}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey,
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
          icon: Icon(Icons.more_vert, color: textColor),
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                settings: const RouteSettings(name: 'group_info'),
                builder: (_) => GroupInfoPage(group: _group),
              ),
            );
            if (result is GroupChat) {
              setState(() => _group = result);
            } else if (result == 'deleted' || result == 'left') {
              if (mounted) Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }

  Widget _buildMessageBubble(
    GroupMessage message,
    bool isMe,
    bool showAvatar,
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    final bubbleColor = isMe
        ? const Color(0xFFBFAE01)
        : (isDark ? const Color(0xFF2A2A2A) : Colors.white);
    final bubbleTextColor = isMe ? Colors.black : textColor;

    return GestureDetector(
      onLongPress: () => _showMessageOptions(message),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe && showAvatar)
              CircleAvatar(
                radius: 14,
                backgroundImage: message.senderAvatar != null
                    ? CachedNetworkImageProvider(message.senderAvatar!)
                    : null,
                backgroundColor: Colors.grey[400],
                child: message.senderAvatar == null
                    ? Text(
                        message.senderName[0].toUpperCase(),
                        style: const TextStyle(fontSize: 10),
                      )
                    : null,
              )
            else if (!isMe)
              const SizedBox(width: 28),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Sender name (for group messages)
                  if (!isMe && showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 2),
                      child: Text(
                        message.senderName,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFBFAE01),
                        ),
                      ),
                    ),

                  // Reply preview
                  if (message.replyToId != null)
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
                            message.replyToSenderName ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFBFAE01),
                            ),
                          ),
                          Text(
                            message.replyToContent ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
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
                      color: message.isDeleted ? Colors.grey[600] : (message.isSending ? bubbleColor.withValues(alpha: 0.7) : bubbleColor),
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
                        if (message.attachments.isNotEmpty && !message.isDeleted)
                          ...message.attachments.map((att) {
                            final type = att['type'] ?? '';
                            final url = att['url'] ?? '';

                            if (type == 'image') {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: url,
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
                            } else if (type == 'voice') {
                              final durationSec = att['duration'] as int? ?? 0;
                              final durationStr = '${durationSec ~/ 60}:${(durationSec % 60).toString().padLeft(2, '0')}';
                              
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Play/Pause button
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: bubbleTextColor.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        message.isSending ? Icons.upload : Icons.play_arrow,
                                        color: bubbleTextColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Waveform visualization
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Waveform bars
                                        SizedBox(
                                          height: 24,
                                          width: 120,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: List.generate(20, (i) {
                                              final heights = [0.4, 0.7, 0.5, 0.9, 0.6, 0.8, 0.4, 1.0, 0.5, 0.7, 
                                                               0.6, 0.9, 0.4, 0.8, 0.5, 0.7, 0.6, 0.9, 0.5, 0.7];
                                              return Container(
                                                width: 3,
                                                height: 24 * heights[i],
                                                decoration: BoxDecoration(
                                                  color: message.isSending 
                                                      ? bubbleTextColor.withValues(alpha: 0.3)
                                                      : bubbleTextColor.withValues(alpha: 0.5),
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                              );
                                            }),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // Duration
                                        Text(
                                          message.isSending 
                                              ? Provider.of<LanguageProvider>(context, listen: false).t('chat.sending')
                                              : durationStr,
                                          style: GoogleFonts.inter(
                                            color: bubbleTextColor.withValues(alpha: 0.7), 
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            } else if (type == 'file') {
                              return Container(
                                padding: const EdgeInsets.all(8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.attach_file, color: bubbleTextColor, size: 20),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        att['fileName'] ?? 'File',
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
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: message.isDeleted ? Colors.grey[400] : bubbleTextColor,
                              fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
                            ),
                          ),

                        // Timestamp
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message.isSending 
                                  ? Provider.of<LanguageProvider>(context, listen: false).t('chat.sending')
                                  : _formatTime(message.createdAt),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: isMe ? Colors.black54 : Colors.grey,
                              ),
                            ),
                            if (message.isSending) ...[
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

                  // Reactions
                  if (message.reactions.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: _buildReactionChips(message.reactions),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildReactionChips(Map<String, String> reactions) {
    final reactionCounts = <String, int>{};
    for (final emoji in reactions.values) {
      reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
    }

    return reactionCounts.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(right: 4),
        child: Text(
          '${entry.key} ${entry.value}',
          style: const TextStyle(fontSize: 12),
        ),
      );
    }).toList();
  }

  Widget _buildInputArea(bool isDark, Color cardColor, Color textColor) {
    // Check if user can send messages
    final canSend = !_group.onlyAdminsCanSend || _group.isAdmin(_currentUserId ?? '');

    if (!canSend) {
      return Container(
        padding: const EdgeInsets.all(16),
        color: isDark ? Colors.grey[900] : Colors.grey[200],
        child: Text(
          Provider.of<LanguageProvider>(context, listen: false).t('groups.only_admins_can_send'),
          style: GoogleFonts.inter(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

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
        child: Row(
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
                            _formatRecordingDuration(_recordingDuration),
                            style: GoogleFonts.inter(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
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
            if (_messageController.text.trim().isNotEmpty && !_isRecording)
              IconButton(
                icon: Icon(
                  Icons.send,
                  color: _sending ? Colors.grey : const Color(0xFFBFAE01),
                ),
                onPressed: _sending ? null : () => _sendMessage(),
              )
            else if (_isRecording && _isRecordingLocked)
              // Locked recording: show cancel and send buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: _cancelRecording,
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFFBFAE01)),
                    onPressed: _stopRecordingAndSend,
                  ),
                ],
              )
            else
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Swipe up indicator (lock icon that moves up)
                  if (_isRecording && !_isRecordingLocked)
                    Positioned(
                      bottom: 50 + _swipeUpOffset.clamp(0, 80),
                      left: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        opacity: _swipeUpOffset > 10 ? 1.0 : 0.5,
                        duration: const Duration(milliseconds: 100),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _swipeUpOffset > 50 ? Colors.green : Colors.grey[700],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _swipeUpOffset > 50 ? Icons.lock : Icons.lock_open,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Icon(
                              Icons.keyboard_arrow_up,
                              color: _swipeUpOffset > 50 ? Colors.green : Colors.grey,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Mic button - use Listener for instant response (no gesture delay)
                  Listener(
                    onPointerDown: (_) {
                      // INSTANT start recording on touch
                      if (!_isRecording) {
                        setState(() {
                          _swipeUpOffset = 0;
                          _recordingStartTime = DateTime.now();
                        });
                        _startRecording();
                      }
                    },
                    onPointerMove: (details) {
                      if (_isRecording && !_isRecordingLocked) {
                        // Track swipe distance (negative Y = upward)
                        final offset = -details.localDelta.dy;
                        setState(() {
                          _swipeUpOffset = (_swipeUpOffset + offset).clamp(0, 100);
                        });
                        
                        // Lock when swiped up enough
                        if (_swipeUpOffset > 80) {
                          setState(() => _isRecordingLocked = true);
                        }
                      }
                    },
                    onPointerUp: (_) async {
                      // Release to send (only if not locked)
                      if (_isRecording && !_isRecordingLocked) {
                        // Ensure minimum recording time (500ms) for web to capture audio
                        final minDuration = const Duration(milliseconds: 500);
                        final elapsed = DateTime.now().difference(_recordingStartTime ?? DateTime.now());
                        if (elapsed < minDuration) {
                          await Future.delayed(minDuration - elapsed);
                        }
                        _stopRecordingAndSend();
                      }
                      setState(() => _swipeUpOffset = 0);
                    },
                    onPointerCancel: (_) async {
                      // Handle cancel same as release
                      if (_isRecording && !_isRecordingLocked) {
                        final minDuration = const Duration(milliseconds: 500);
                        final elapsed = DateTime.now().difference(_recordingStartTime ?? DateTime.now());
                        if (elapsed < minDuration) {
                          await Future.delayed(minDuration - elapsed);
                        }
                        _stopRecordingAndSend();
                      }
                      setState(() => _swipeUpOffset = 0);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.red : const Color(0xFFBFAE01),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mic,
                        color: _isRecording ? Colors.white : Colors.black,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo, color: Colors.purple),
              ),
              title: Text(Provider.of<LanguageProvider>(context, listen: false).t('chat.photo')),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendImage();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.insert_drive_file, color: Colors.blue),
              ),
              title: Text(Provider.of<LanguageProvider>(context, listen: false).t('chat.file')),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSendFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    // Convert to local timezone for proper time display
    final localTime = time.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(localTime.year, localTime.month, localTime.day);
    final timeStr = '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';

    if (messageDate == today) {
      return timeStr;
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday $timeStr';
    } else {
      return '${localTime.day}/${localTime.month} $timeStr';
    }
  }
}
