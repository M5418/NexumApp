// c:\Users\dehou\nexum-app\lib\mentorship\mentorship_chat_page.dart
import 'dart:io';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/message.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/attachment_dropdown_menu.dart';
import '../widgets/message_actions_sheet.dart';
import '../widgets/media_preview_page.dart';
import '../core/messages_api.dart' show MessageRecord; // reuse DTO
import '../core/mentorship_messages_api.dart';
import '../core/profile_api.dart';
import '../core/audio_recorder.dart';
import '../core/mentorship_api.dart';
import '../core/api_client.dart';

class MentorshipChatPage extends StatefulWidget {
  final String mentorUserId;
  final String mentorName;
  final String mentorAvatar;
  final bool isOnline;
  final String? conversationId;
  const MentorshipChatPage({
    super.key,
    required this.mentorUserId,
    required this.mentorName,
    required this.mentorAvatar,
    required this.isOnline,
    this.conversationId,
  });
  @override
  State<MentorshipChatPage> createState() => _MentorshipChatPageState();
}

class _MentorshipChatPageState extends State<MentorshipChatPage> {
  final _scroll = ScrollController();
  final _messages = <Message>[];
  Message? _replyTo;
  final _reactions = <String, String>{};
  final _audio = AudioRecorder();
  final _msgApi = MentorshipMessagesApi();
  final _mentorApi = MentorshipApi();
  final Dio _dio = ApiClient().dio;

  String? _convId;
  bool _loading = false;
  String? _err;
  bool _recording = false;
  bool _muted = false;

  // Polling
  Timer? _pollTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _init();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      setState(() {
        _loading = true;
        _err = null;
      });
      _convId = (widget.conversationId != null &&
              widget.conversationId!.isNotEmpty)
          ? widget.conversationId
          : await _mentorApi.ensureConversationWithMentor(widget.mentorUserId);
      await _load();
      await _mentorApi.markConversationRead(_convId!);
      await _refreshMutedState();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _refreshMutedState() async {
    try {
      final convs = await _mentorApi.listConversations();
      for (final c in convs) {
        if (c.id == _convId) {
          if (!mounted) return;
          setState(() {
            _muted = c.muted;
          });
          break;
        }
      }
    } catch (_) {}
  }

  // ------ POLLING (live updates) ------
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      if (_convId == null) return;
      if (_loading || _isRefreshing) return;
      await _refreshMessages();
    });
  }

  Future<void> _refreshMessages() async {
    if (_convId == null) return;
    try {
      _isRefreshing = true;

      final bool wasAtBottom = _scroll.hasClients &&
          (_scroll.position.maxScrollExtent - _scroll.position.pixels) < 120;

      final recs = await _msgApi.list(_convId!, limit: 50);
      if (!mounted) return;

      setState(() {
        _messages
          ..clear()
          ..addAll(recs.map(_toUi));
        _reactions.clear();
        for (final r in recs) {
          if ((r.reaction ?? '').isNotEmpty) {
            _reactions[r.id] = r.reaction!;
          } else if ((r.myReaction ?? '').isNotEmpty) {
            _reactions[r.id] = r.myReaction!;
          }
        }
      });

      if (wasAtBottom) {
        _toBottom();
      }

      await _mentorApi.markConversationRead(_convId!);
    } catch (_) {
      // silent refresh failure
    } finally {
      _isRefreshing = false;
    }
  }
  // -----------------------------------

  Future<void> _load() async {
    final recs = await _msgApi.list(_convId!);
    setState(() {
      _messages
        ..clear()
        ..addAll(recs.map(_toUi));
      for (final r in recs) {
        if ((r.reaction ?? '').isNotEmpty) {
          _reactions[r.id] = r.reaction!;
        } else if ((r.myReaction ?? '').isNotEmpty) {
          _reactions[r.id] = r.myReaction!;
        }
      }
    });
    _toBottom();
  }

  Message _toUi(MessageRecord r) {
    final mine = r.senderId != widget.mentorUserId;
    return Message(
      id: r.id,
      senderId: r.senderId,
      senderName: mine ? 'You' : widget.mentorName,
      senderAvatar: mine ? null : widget.mentorAvatar,
      content: r.text ?? '',
      type: r.type == 'image'
          ? MessageType.image
          : r.type == 'video'
              ? MessageType.video
              : r.type == 'voice'
                  ? MessageType.voice
                  : r.type == 'file'
                      ? MessageType.file
                      : MessageType.text,
      attachments: r.attachments
          .map((a) => MediaAttachment(
                id: a.id,
                url: a.url,
                type: a.type == 'image'
                    ? MediaType.image
                    : a.type == 'video'
                        ? MediaType.video
                        : a.type == 'voice'
                            ? MediaType.voice
                            : MediaType.document,
                thumbnailUrl: a.thumbnail,
                duration: a.durationSec != null
                    ? Duration(seconds: a.durationSec!)
                    : null,
                fileSize: a.fileSize,
                fileName: a.fileName,
              ))
          .toList(),
      timestamp: r.createdAt,
      status: r.readAt != null ? MessageStatus.read : MessageStatus.sent,
      replyTo: r.replyTo == null
          ? null
          : ReplyTo(
              messageId: (r.replyTo!['message_id'] ?? '').toString(),
              senderName: (r.replyTo!['sender_name'] ?? 'User').toString(),
              content: (r.replyTo!['content'] ?? '').toString(),
              type: _mt(r.replyTo!['type']?.toString() ?? 'text'),
            ),
      isFromCurrentUser: mine,
    );
  }

  MessageType _mt(String t) {
    switch (t) {
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

  Future<void> _sendText(String text) async {
    try {
      final id = _convId ??
          await _mentorApi.ensureConversationWithMentor(widget.mentorUserId);
      _convId = id;
      final rec = await _msgApi.sendText(
          conversationId: id, text: text, replyToMessageId: _replyTo?.id);
      final msg = _toUi(rec).copyWith(
        replyTo: _replyTo == null
            ? null
            : ReplyTo(
                messageId: _replyTo!.id,
                senderName: _replyTo!.senderName,
                content: _replyTo!.content,
                type: _replyTo!.type,
                mediaUrl: _replyTo!.attachments.isNotEmpty
                    ? _replyTo!.attachments.first.url
                    : null,
              ),
      );
      setState(() {
        _messages.add(msg);
        _replyTo = null;
      });
      _toBottom();
    } catch (e) {
      if (mounted) _snack('Failed to send: $e');
    }
  }

  Future<void> _handleVoice() async {
    try {
      if (!_recording) {
        final path = await _audio.startRecording();
        if (path != null) {
          setState(() => _recording = true);
        } else {
          _snack('Failed to start recording');
        }
      } else {
        final r = await _audio.stopRecording();
        setState(() => _recording = false);
        if (r == null) return;
        final url = await _audio.uploadVoiceFile(r.filePath);
        if (url == null) throw 'Failed to upload voice';
        final id = await _requireConv();
        final rec = await _msgApi.sendVoice(
          conversationId: id,
          audioUrl: url,
          durationSec: r.duration.inSeconds,
          fileSize: r.fileSize,
          replyToMessageId: _replyTo?.id,
        );
        setState(() {
          _messages.add(_toUi(rec));
          _replyTo = null;
        });
        _toBottom();
      }
    } catch (e) {
      if (mounted) _snack('Recording error: $e');
    }
  }

  Future<void> _sendFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: kIsWeb,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
      );
      if (res == null || res.files.isEmpty) return;
      _snack('Uploading file(s)...');
      final profile = ProfileApi();
      final atts = <Map<String, dynamic>>[];
      for (final f in res.files) {
        final name = f.name;
        final ext =
            (f.extension ?? (name.contains('.') ? name.split('.').last : 'bin'))
                .toLowerCase();
        String url;
        if (kIsWeb) {
          final b = f.bytes;
          if (b == null || b.isEmpty) continue;
          url = await profile.uploadBytes(b, ext: ext);
        } else {
          final p = f.path;
          if (p == null) continue;
          url = await profile.uploadFile(File(p));
        }
        atts.add({
          'type': 'document',
          'url': url,
          'fileName': name,
          'fileSize': f.size
        });
      }
      if (atts.isEmpty) {
        _hideSnack();
        return;
      }
      final id = await _requireConv();
      final rec = await _msgApi.sendTextWithMedia(
        conversationId: id,
        text: '',
        attachments: atts,
        replyToMessageId: _replyTo?.id,
      );
      setState(() {
        _messages.add(_toUi(rec));
        _replyTo = null;
      });
      _toBottom();
      _hideSnack();
    } catch (e) {
      _hideSnack();
      _snack('Failed to send files: $e');
    }
  }

  Future<void> _sendVideosOrImages({required bool videos}) async {
    try {
      final picker = ImagePicker();
      if (videos) {
        final XFile? v = await picker.pickVideo(source: ImageSource.gallery);
        if (v == null) return;
        await _sendMediaWithPreview([v]);
      } else {
        final List<XFile> media =
            await picker.pickMultipleMedia(); // images or short videos
        if (media.isEmpty) return;
        await _sendMediaWithPreview(media);
      }
    } catch (e) {
      _snack('Pick error: $e');
    }
  }

  Future<void> _sendMediaWithPreview(List<XFile> files) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preview = await Navigator.push<MediaPreviewResult>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              MediaPreviewPage(initialFiles: files, isDark: isDark)),
    );
    if (preview == null || preview.files.isEmpty) return;
    await _uploadAndSend(preview.files, preview.caption);
  }

  Future<void> _uploadAndSend(List<XFile> files, String caption) async {
    try {
      _snack('Uploading media...');
      final profile = ProfileApi();
      final atts = <Map<String, dynamic>>[];
      bool isVideoName(String p) =>
          p.toLowerCase().endsWith('.mp4') ||
          p.toLowerCase().endsWith('.mov') ||
          p.toLowerCase().endsWith('.webm') ||
          p.toLowerCase().endsWith('.mkv') ||
          p.toLowerCase().endsWith('.avi');
      for (final f in files) {
        final nameOrPath = f.name.isNotEmpty ? f.name : f.path;
        final dot = nameOrPath.lastIndexOf('.');
        final ext = (dot != -1 && dot < nameOrPath.length - 1)
            ? nameOrPath.substring(dot + 1).toLowerCase()
            : 'bin';
        String url;
        int? size;
        if (kIsWeb) {
          final bytes = await f.readAsBytes();
          size = bytes.length;
          url = await profile.uploadBytes(bytes, ext: ext);
        } else {
          final file = File(f.path);
          size = await file.length();
          url = await profile.uploadFile(file);
        }
        atts.add({
          'type': isVideoName(nameOrPath) ? 'video' : 'image',
          'url': url,
          'fileName': f.name,
          'fileSize': size
        });
      }
      final id = await _requireConv();
      final rec = await _msgApi.sendTextWithMedia(
        conversationId: id,
        text: caption,
        attachments: atts,
        replyToMessageId: _replyTo?.id,
      );
      setState(() {
        _messages.add(_toUi(rec));
        _replyTo = null;
      });
      _toBottom();
      _hideSnack();
    } catch (e) {
      _hideSnack();
      _snack('Failed to send media: $e');
    }
  }

  Future<String> _requireConv() async => _convId ??=
      await _mentorApi.ensureConversationWithMentor(widget.mentorUserId);

  Future<void> _toggleMute() async {
    try {
      final id = await _requireConv();
      if (_muted) {
        await _dio.post('/api/mentorship/conversations/$id/unmute');
      } else {
        await _dio.post('/api/mentorship/conversations/$id/mute');
      }
      if (!mounted) return;
      setState(() {
        _muted = !_muted;
      });
      _snack(_muted ? 'Notifications muted' : 'Notifications unmuted');
    } catch (e) {
      _snack('Failed to update notifications: $e');
    }
  }

  Future<void> _deleteConversation() async {
    try {
      final id = await _requireConv();
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete conversation'),
          content:
              const Text('Are you sure you want to delete this conversation?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete')),
          ],
        ),
      );
      if (confirm != true) return;
      await _dio.delete('/api/mentorship/conversations/$id');
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _snack('Failed to delete: $e');
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _snack(String m) {
    final s = ScaffoldMessenger.maybeOf(context);
    s?.showSnackBar(SnackBar(content: Text(m)));
  }

  void _hideSnack() {
    final s = ScaffoldMessenger.maybeOf(context);
    s?.hideCurrentSnackBar();
  }

  void _onReply(Message m) {
    setState(() => _replyTo = m);
  }

  void _cancelReply() {
    setState(() => _replyTo = null);
  }

  Future<void> _onReact(Message m, String emoji) async {
    try {
      await _msgApi.react(m.id, emoji);
      setState(() {
        _reactions[m.id] = emoji;
      });
    } catch (e) {
      _snack('Failed to react: $e');
    }
  }

  Future<void> _deleteForMe(Message m) async {
    try {
      await _msgApi.deleteForMe(m.id);
      setState(() {
        _reactions.remove(m.id);
        _messages.removeWhere((x) => x.id == m.id);
      });
      _snack('Deleted for me');
    } catch (e) {
      _snack('Failed to delete: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios,
              color: isDark ? Colors.white : Colors.black, size: 20),
        ),
        title: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: CachedNetworkImage(
              imageUrl: widget.mentorAvatar,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF666666).withAlpha(51),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.person,
                    color: Color(0xFF666666), size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                widget.mentorName,
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black),
              ),
              Text(
                widget.isOnline ? 'Online' : 'Last seen recently',
                style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF666666)),
              ),
            ]),
          ),
        ]),
        actions: [
          IconButton(
              onPressed: () {},
              icon: Icon(Icons.videocam,
                  color: isDark ? Colors.white : Colors.black, size: 24)),
          IconButton(
              onPressed: () {},
              icon: Icon(Icons.phone,
                  color: isDark ? Colors.white : Colors.black, size: 24)),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert,
                color: isDark ? Colors.white : Colors.black),
            onSelected: (v) async {
              if (v == 'mute') {
                await _toggleMute();
              } else if (v == 'delete') {
                await _deleteConversation();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                  value: 'mute',
                  child: Text(
                      _muted ? 'Unmute notifications' : 'Mute notifications')),
              const PopupMenuItem(
                  value: 'delete', child: Text('Delete conversation')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: Builder(builder: (_) {
            if (_loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_err != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_err!, style: const TextStyle(color: Colors.red)),
                ),
              );
            }
            return ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _messages.length + _daySeparators(),
              itemBuilder: (ctx, idx) => _itemOrSeparator(idx, isDark),
            );
          }),
        ),
        ChatInput(
          onSendMessage: _sendText,
          onVoiceRecord: _handleVoice,
          onAttachment: () => showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => AttachmentDropdownMenu(
              isDark: isDark,
              onSendVideos: () => _sendVideosOrImages(videos: true),
              onSendFiles: _sendFiles,
            ),
          ),
          replyToMessage: _replyTo?.content,
          onCancelReply: _cancelReply,
        ),
      ]),
    );
  }

  int _daySeparators() {
    int c = 0;
    for (int i = 0; i < _messages.length; i++) {
      if (i == 0 ||
          !_sameDay(_messages[i].timestamp, _messages[i - 1].timestamp)) {
        c++;
      }
    }
    return c;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _itemOrSeparator(int index, bool isDark) {
    int msgIdx = index, passed = 0;
    for (int i = 0; i < _messages.length; i++) {
      if (i == 0 ||
          !_sameDay(_messages[i].timestamp, _messages[i - 1].timestamp)) {
        if (msgIdx == i + passed) {
          return _daySep(_messages[i].timestamp, isDark);
        }
        passed++;
        msgIdx--;
      }
      if (msgIdx == i) {
        final m = _messages[i];
        final reaction = _reactions[m.id];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Column(
            crossAxisAlignment: m.isFromCurrentUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              MessageBubble(
                message: m,
                allMessages: _messages,
                showTimestamp: true,
                onReply: () => _onReply(m),
                onLongPress: () => showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => MessageActionsSheet(
                    message: m,
                    isDark: isDark,
                    isStarred: false,
                    onCopy: (t) => ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Copied'))),
                    onReply: () => _onReply(m),
                    onToggleStar: () {},
                    onShareToStory: () {},
                    onDelete: () => _deleteForMe(m),
                    onReact: (e) => _onReact(m, e),
                  ),
                ),
              ),
              if (reaction != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 2),
                  child: Align(
                    alignment: m.isFromCurrentUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withAlpha(26),
                              blurRadius: 6,
                              offset: const Offset(0, 1))
                        ],
                      ),
                      child:
                          Text(reaction, style: const TextStyle(fontSize: 14)),
                    ),
                  ),
                ),
            ],
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }

  Widget _daySep(DateTime date, bool isDark) {
    final now = DateTime.now(),
        today = DateTime(now.year, now.month, now.day),
        d = DateTime(date.year, date.month, date.day);
    String txt;
    if (d == today) {
      txt = 'Today';
    } else if (d == today.subtract(const Duration(days: 1))) {
      txt = 'Yesterday';
    } else {
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
        'December'
      ];
      txt = '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: const Color(0xFF666666).withAlpha(26),
              borderRadius: BorderRadius.circular(12)),
          child: Text(txt,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF666666),
                  fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}
