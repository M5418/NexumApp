// c:\Users\dehou\nexum-app\lib\mentorship\mentorship_conversations_page.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/mentorship_api.dart';
import 'mentorship_chat_page.dart';
import '../core/time_utils.dart';

class MentorshipConversationsPage extends StatefulWidget {
  const MentorshipConversationsPage({super.key});
  @override
  State<MentorshipConversationsPage> createState() => _MentorshipConversationsPageState();
}

class _MentorshipConversationsPageState extends State<MentorshipConversationsPage> {
  final _api = MentorshipApi();
  bool _loading = true;
  String? _error;
  List<MentorshipConversationSummary> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.listConversations();
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      String msg = 'Failed to load conversations';
      if (e is DioException) {
        final code = e.response?.statusCode;
        msg = code == null ? '$msg: network error' : '$msg (HTTP $code)';
      } else {
        msg = '$msg: $e';
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

String _formatTimeOrDate(DateTime? dt) {
  if (dt == null) return '';
return TimeUtils.relativeLabel(dt, locale: 'en_short');
}

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8);
    final card = isDark ? Colors.black : Colors.white;
    final text = isDark ? Colors.white : Colors.black;
    const secondary = Color(0xFF666666);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: card,
        elevation: 0,
        centerTitle: false,
        title: Text('Mentorship Chats', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: text)),
        leading: IconButton(icon: Icon(Icons.arrow_back, color: text), onPressed: () => Navigator.pop(context)),
      ),
      body: _loading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01)))
          : _error != null && _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: GoogleFonts.inter(color: Colors.red), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _load,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBFAE01)),
                          child: Text('Retry', style: GoogleFonts.inter(color: Colors.black, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFFBFAE01),
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Text(
                                'No conversations yet',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: secondary),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final c = _items[i];
                            final m = c.mentor;
                            final avatar = m.avatarUrl ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(m.name)}';
                            final subtitle = (c.lastMessageText == null || c.lastMessageText!.trim().isEmpty)
                                ? _label(c.lastMessageType)
                                : c.lastMessageText!;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10, offset: const Offset(0, 2))],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => MentorshipChatPage(
                                          mentorUserId: m.id,
                                          mentorName: m.name,
                                          mentorAvatar: avatar,
                                          isOnline: m.isOnline,
                                          conversationId: c.id,
                                        ),
                                      ),
                                    );
                                    await _load();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Stack(
                                          children: [
                                            CircleAvatar(radius: 28, backgroundImage: NetworkImage(avatar)),
                                            if (m.isOnline)
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: Container(
                                                  width: 16,
                                                  height: 16,
                                                  decoration: BoxDecoration(
                                                    color: Colors.green,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: card, width: 2),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      m.name,
                                                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: text),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatTimeOrDate(c.lastMessageAt),
                                                    style: GoogleFonts.inter(fontSize: 12, color: secondary),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(m.profession ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFFBFAE01))),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      subtitle,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: GoogleFonts.inter(fontSize: 14, color: secondary),
                                                    ),
                                                  ),
                                                  if (c.unreadCount > 0)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFBFAE01),
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      child: Text(
                                                        '${c.unreadCount}',
                                                        style: GoogleFonts.inter(fontSize: 12, color: Colors.black, fontWeight: FontWeight.w700),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }

  String _label(String? t) {
    switch ((t ?? '').toLowerCase()) {
      case 'image':
        return 'Photo';
      case 'video':
        return 'Video';
      case 'voice':
        return 'Voice message';
      case 'file':
        return 'File';
      default:
        return '';
    }
  }
}