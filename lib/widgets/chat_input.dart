import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../core/i18n/language_provider.dart';
import '../core/audio_recorder.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final Future<void> Function() onVoiceRecord;
  final VoidCallback onAttachment;
  final String? replyToMessage;
  final VoidCallback? onCancelReply;
  final VoidCallback? onVoiceSendComplete;

  const ChatInput({
    super.key,
    required this.onSendMessage,
    required this.onVoiceRecord,
    required this.onAttachment,
    this.replyToMessage,
    this.onCancelReply,
    this.onVoiceSendComplete,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isRecording = false;
  bool _isSending = false;
  bool _hasText = false;
  bool _cancelRequested = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  AnimationController? _pulseController;
  AnimationController? _rippleController;
  Animation<double>? _pulseAnimation;
  Animation<double>? _rippleAnimation;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController!, curve: Curves.easeOut),
    );
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  void _startRecordingAnimation() {
    _pulseController?.forward();
    _rippleController?.forward();
    _startRecordingTimer();
  }

  void _stopRecordingAnimation() {
    _pulseController?.stop();
    _rippleController?.stop();
    _pulseController?.reset();
    _rippleController?.reset();
    _stopRecordingTimer();
  }

  void _startRecordingTimer() {
    _recordingDuration = Duration.zero;
    _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _recordingDuration = Duration(milliseconds: timer.tick * 100);
      });
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    setState(() {
      _recordingDuration = Duration.zero;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSendMessage(text);
      _controller.clear();
    }
  }

  void _startRecording() async {
    _cancelRequested = false;
    
    // Add timeout to prevent UI freeze on simulator
    bool granted = false;
    try {
      granted = await _audioRecorder.hasPermission().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('⚠️ Permission check timed out - likely on simulator');
          return false;
        },
      );
    } catch (e) {
      debugPrint('❌ Error checking microphone permission: $e');
      return;
    }
    
    if (!granted) {
      debugPrint('ℹ️ Microphone permission not granted');
      return;
    }
    if (_cancelRequested) return;
    if (mounted) {
      setState(() {
        _isRecording = true;
      });
    }
    _startRecordingAnimation();
    await widget.onVoiceRecord();
  }

  void _stopRecording() async {
    _cancelRequested = true;
    if (!_isRecording) return;
    setState(() {
      _isRecording = false;
      _isSending = true;
    });
    _stopRecordingAnimation();
    try {
      await widget.onVoiceRecord().timeout(const Duration(seconds: 30));
    } catch (_) {
      // swallow; ChatPage will show a SnackBar if needed
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        widget.onVoiceSendComplete?.call();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _pulseController?.dispose();
    _rippleController?.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF666666).withAlpha(26),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyToMessage != null) _buildReplyPreview(isDark),

            Padding(
              padding: const EdgeInsets.all(16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!_isRecording)
                      GestureDetector(
                        onTap: widget.onAttachment,
                        child: Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF666666).withAlpha(51),
                              width: 0.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Color(0xFF666666),
                            size: 20,
                          ),
                        ),
                      ),

                    if (!_isRecording) const SizedBox(width: 12),

                    Expanded(
                      child: (_isRecording || _isSending)
                          ? (_isSending ? _buildSendingIndicator(isDark) : const SizedBox.shrink())
                          : Stack(
                              children: [
                                Container(
                                  constraints: const BoxConstraints(
                                    maxHeight: 200,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFF666666).withAlpha(51),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: TextField(
                                    controller: _controller,
                                    focusNode: _focusNode,
                                    decoration: InputDecoration(
                                      hintText: Provider.of<LanguageProvider>(context, listen: false).t('chat.type_message'),
                                      hintStyle: GoogleFonts.inter(
                                        fontSize: 16,
                                        color: const Color(0xFF666666),
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ).copyWith(right: _hasText ? 48 : 16),
                                    ),
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                    maxLines: 8,
                                    minLines: 1,
                                    textCapitalization: TextCapitalization.sentences,
                                    onSubmitted: (_) => _sendMessage(),
                                  ),
                                ),
                                if (_hasText)
                                  Positioned(
                                    right: 8,
                                    bottom: 8,
                                    child: GestureDetector(
                                      onTap: _sendMessage,
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF007AFF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.arrow_upward,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),

                    const SizedBox(width: 12),

                    SizedBox(
                      width: _isRecording ? 200 : (_isSending ? 0 : 36),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPressStart: (_) {
                          if (!_isRecording && !_isSending) {
                            _startRecording();
                          }
                        },
                        onLongPressEnd: (_) {
                          _cancelRequested = true;
                          if (_isRecording) {
                            _stopRecording();
                          }
                        },
                        child: (_isRecording && !_isSending)
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF007AFF),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _formatDuration(_recordingDuration),
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  AnimatedBuilder(
                                    animation: _pulseAnimation ?? const AlwaysStoppedAnimation(1.0),
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: _pulseAnimation?.value ?? 1.0,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            if (_rippleAnimation != null)
                                              AnimatedBuilder(
                                                animation: _rippleAnimation!,
                                                builder: (context, child) {
                                                  return Container(
                                                    width: 60 * _rippleAnimation!.value,
                                                    height: 60 * _rippleAnimation!.value,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: const Color(0xFF007AFF).withValues(
                                                        alpha:
                                                            (25 * (1 - _rippleAnimation!.value))
                                                                .round()
                                                                .toDouble(),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF007AFF),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(0xFF007AFF)
                                                        .withValues(alpha: 77),
                                                    blurRadius: 8,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.mic,
                                                color: Colors.white,
                                                size: 24,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              )
                            : (_hasText
                                ? const SizedBox.shrink()
                                : Container(
                                    width: 36,
                                    height: 36,
                                    margin: const EdgeInsets.only(bottom: 4),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF666666).withValues(alpha: 51),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.mic,
                                      color: Color(0xFF666666),
                                      size: 20,
                                    ),
                                  )),
                      ),
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

  Widget _buildSendingIndicator(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF666666).withAlpha(51),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            Provider.of<LanguageProvider>(context, listen: false).t('chat.sending'),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF666666),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF666666).withAlpha(26),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to message',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF007AFF),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.replyToMessage!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF666666),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: widget.onCancelReply,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: const Icon(
                Icons.close,
                color: Color(0xFF666666),
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}