import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ionicons/ionicons.dart';
import 'package:image_picker/image_picker.dart';
import '../core/i18n/language_provider.dart';
import '../repositories/interfaces/livestream_repository.dart';
import '../repositories/interfaces/storage_repository.dart';
import '../services/media_compression_service.dart';
import 'livestream_host_page.dart';

class CreateLiveStreamPage extends StatefulWidget {
  const CreateLiveStreamPage({super.key});

  @override
  State<CreateLiveStreamPage> createState() => _CreateLiveStreamPageState();
}

class _CreateLiveStreamPageState extends State<CreateLiveStreamPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  Uint8List? _thumbnailBytes;
  String? _thumbnailName;
  bool _isPrivate = false;
  bool _isScheduled = false;
  DateTime? _scheduledDate;
  TimeOfDay? _scheduledTime;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickThumbnail() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _thumbnailBytes = bytes;
        _thumbnailName = picked.name;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _scheduledDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _scheduledTime ?? TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _scheduledTime = time);
    }
  }

  DateTime? get _scheduledDateTime {
    if (_scheduledDate == null || _scheduledTime == null) return null;
    return DateTime(
      _scheduledDate!.year,
      _scheduledDate!.month,
      _scheduledDate!.day,
      _scheduledTime!.hour,
      _scheduledTime!.minute,
    );
  }

  Future<void> _createStream() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_isScheduled && (_scheduledDate == null || _scheduledTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<LanguageProvider>().t('livestream.select_date_time')),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = context.read<LiveStreamRepository>();
      String? thumbnailUrl;

      // Upload thumbnail if selected (with small thumb for fast loading)
      String? thumbUrl;
      if (_thumbnailBytes != null) {
        final storageRepo = context.read<StorageRepository>();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        
        Uint8List imageBytes = _thumbnailBytes!;
        Uint8List? smallThumbBytes;
        
        // Only compress on non-web platforms (web already compressed by ImagePicker)
        if (!kIsWeb) {
          final compressionService = MediaCompressionService();
          
          // Compress from bytes
          final compressedBytes = await compressionService.compressImageBytes(
            bytes: _thumbnailBytes!,
            filename: _thumbnailName ?? 'thumbnail.jpg',
            quality: 85,
            minWidth: 1920,
            minHeight: 1080,
          );
          if (compressedBytes != null) imageBytes = compressedBytes;
          
          // Generate small thumbnail for fast feed loading
          smallThumbBytes = await compressionService.generateFeedThumbnailFromBytes(
            bytes: _thumbnailBytes!,
            filename: _thumbnailName ?? 'thumbnail.jpg',
            maxSize: 400,
            quality: 60,
          );
        }
        
        // Upload full image
        thumbnailUrl = await storageRepo.uploadFile(
          path: 'livestream_thumbnails/$timestamp.jpg',
          bytes: imageBytes,
          contentType: 'image/jpeg',
        );
        
        // Upload small thumbnail if available
        if (smallThumbBytes != null) {
          thumbUrl = await storageRepo.uploadFile(
            path: 'livestream_thumbnails/${timestamp}_thumb.jpg',
            bytes: smallThumbBytes,
            contentType: 'image/jpeg',
          );
        }
      }

      final streamId = await repo.createLiveStream(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        thumbnailUrl: thumbnailUrl,
        thumbUrl: thumbUrl,
        scheduledAt: _isScheduled ? _scheduledDateTime : null,
        isPrivate: _isPrivate,
      );

      if (!mounted) return;

      if (_isScheduled) {
        // Just go back if scheduled
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.read<LanguageProvider>().t('livestream.stream_scheduled')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Go to host page to start streaming
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'livestream'),
            builder: (_) => LiveStreamHostPage(streamId: streamId),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating stream: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<LanguageProvider>().t('livestream.error_creating')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Ionicons.close,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.t('livestream.create_stream'),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createStream,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBFAE01),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        _isScheduled
                            ? lang.t('livestream.schedule')
                            : lang.t('livestream.go_live'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Thumbnail picker
            GestureDetector(
              onTap: _pickThumbnail,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                    width: 2,
                    style: BorderStyle.solid,
                  ),
                  image: _thumbnailBytes != null
                      ? DecorationImage(
                          image: MemoryImage(_thumbnailBytes!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _thumbnailBytes == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Ionicons.image_outline,
                            size: 48,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            lang.t('livestream.add_thumbnail'),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lang.t('livestream.thumbnail_optional'),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    : Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              icon: const Icon(
                                Ionicons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                              onPressed: () =>
                                  setState(() {
                                    _thumbnailBytes = null;
                                    _thumbnailName = null;
                                  }),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              lang.t('livestream.stream_title'),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: lang.t('livestream.title_hint'),
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFBFAE01)),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return lang.t('livestream.title_required');
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Description
            Text(
              lang.t('livestream.description'),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              maxLines: 4,
              decoration: InputDecoration(
                hintText: lang.t('livestream.description_hint'),
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFBFAE01)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Settings section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Private toggle
                  _buildSettingRow(
                    icon: Ionicons.lock_closed_outline,
                    title: lang.t('livestream.private_stream'),
                    subtitle: lang.t('livestream.private_subtitle'),
                    trailing: Switch(
                      value: _isPrivate,
                      onChanged: (v) => setState(() => _isPrivate = v),
                      activeThumbColor: const Color(0xFFBFAE01),
                    ),
                    isDark: isDark,
                  ),
                  const Divider(height: 24),
                  // Schedule toggle
                  _buildSettingRow(
                    icon: Ionicons.calendar_outline,
                    title: lang.t('livestream.schedule_stream'),
                    subtitle: lang.t('livestream.schedule_subtitle'),
                    trailing: Switch(
                      value: _isScheduled,
                      onChanged: (v) => setState(() => _isScheduled = v),
                      activeThumbColor: const Color(0xFFBFAE01),
                    ),
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            // Schedule date/time pickers
            if (_isScheduled) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // Date picker
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFBFAE01).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Ionicons.calendar,
                          color: Color(0xFFBFAE01),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        lang.t('livestream.select_date'),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        _scheduledDate != null
                            ? _formatDate(_scheduledDate!)
                            : lang.t('livestream.no_date_selected'),
                        style: TextStyle(
                          color: _scheduledDate != null
                              ? const Color(0xFFBFAE01)
                              : Colors.grey[500],
                        ),
                      ),
                      trailing: Icon(
                        Ionicons.chevron_forward,
                        color: Colors.grey[500],
                      ),
                      onTap: _pickDate,
                    ),
                    const Divider(height: 24),
                    // Time picker
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFBFAE01).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Ionicons.time,
                          color: Color(0xFFBFAE01),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        lang.t('livestream.select_time'),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        _scheduledTime != null
                            ? _formatTime(_scheduledTime!)
                            : lang.t('livestream.no_time_selected'),
                        style: TextStyle(
                          color: _scheduledTime != null
                              ? const Color(0xFFBFAE01)
                              : Colors.grey[500],
                        ),
                      ),
                      trailing: Icon(
                        Ionicons.chevron_forward,
                        color: Colors.grey[500],
                      ),
                      onTap: _pickTime,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Tips section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFBFAE01).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Ionicons.bulb_outline,
                        color: Color(0xFFBFAE01),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        lang.t('livestream.tips_title'),
                        style: const TextStyle(
                          color: Color(0xFFBFAE01),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTip(lang.t('livestream.tip_1'), isDark),
                  _buildTip(lang.t('livestream.tip_2'), isDark),
                  _buildTip(lang.t('livestream.tip_3'), isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFBFAE01).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFFBFAE01), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

  Widget _buildTip(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Ionicons.checkmark_circle,
            size: 16,
            color: Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}
