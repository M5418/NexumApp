import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/i18n/language_provider.dart';
import 'theme_provider.dart';

/// Model for shared media items
class SharedMediaItem {
  final String id;
  final String type; // 'image', 'video', 'link', 'file'
  final String url;
  final String? thumbnailUrl;
  final String? fileName;
  final int? fileSize;
  final DateTime timestamp;
  final String senderId;
  final String senderName;

  SharedMediaItem({
    required this.id,
    required this.type,
    required this.url,
    this.thumbnailUrl,
    this.fileName,
    this.fileSize,
    required this.timestamp,
    required this.senderId,
    required this.senderName,
  });
}

/// Page to display shared media, links, and documents from a conversation
class SharedMediaPage extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String? conversationId;

  const SharedMediaPage({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.conversationId,
  });

  @override
  State<SharedMediaPage> createState() => _SharedMediaPageState();
}

class _SharedMediaPageState extends State<SharedMediaPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<SharedMediaItem> _mediaItems = [];
  List<SharedMediaItem> _linkItems = [];
  List<SharedMediaItem> _docItems = [];
  
  bool _loading = true;
  String? _error;
  String? _conversationId;
  
  // FASTFEED: Real-time listener for auto-update
  StreamSubscription<QuerySnapshot>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _conversationId = widget.conversationId;
    // FASTFEED: Load from cache first, then setup real-time listener
    _loadFromCacheInstantly();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  /// FASTFEED: Load from cache instantly for perceived fast load
  Future<void> _loadFromCacheInstantly() async {
    final currentUserId = fb.FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      setState(() {
        _error = 'Not authenticated';
        _loading = false;
      });
      return;
    }

    // Find conversation if not provided
    if (_conversationId == null) {
      _conversationId = await _findConversation(currentUserId, widget.otherUserId);
    }

    if (_conversationId == null) {
      setState(() => _loading = false);
      return;
    }

    // FASTFEED: Try cache first for instant display
    try {
      final cachedSnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(_conversationId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .get(const GetOptions(source: Source.cache));
      
      if (cachedSnapshot.docs.isNotEmpty && mounted) {
        _processMessages(cachedSnapshot.docs);
      }
    } catch (_) {
      // Cache miss - will load from server
    }

    // Setup real-time listener for fresh data + auto-updates
    _setupRealtimeListener();
  }

  /// FASTFEED: Real-time listener for auto-updates when new media is shared
  void _setupRealtimeListener() {
    if (_conversationId == null) return;
    
    _messagesSubscription?.cancel();
    _messagesSubscription = FirebaseFirestore.instance
        .collection('conversations')
        .doc(_conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      _processMessages(snapshot.docs);
    }, onError: (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    });
  }

  /// Process messages and extract media/links/docs
  void _processMessages(List<QueryDocumentSnapshot<Map<String, dynamic>>> messageDocs) {
    final media = <SharedMediaItem>[];
    final links = <SharedMediaItem>[];
    final docItems = <SharedMediaItem>[];

    for (final doc in messageDocs) {
      final data = doc.data();
      final type = data['type']?.toString() ?? 'text';
      final senderId = data['senderId']?.toString() ?? '';
      final senderName = data['senderName']?.toString() ?? 'User';
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final content = data['content']?.toString() ?? '';

      // Check for attachments
      final attachments = data['attachments'] as List<dynamic>? ?? [];
      for (final att in attachments) {
        final attMap = att as Map<String, dynamic>;
        final attType = attMap['type']?.toString() ?? '';
        final url = attMap['url']?.toString() ?? '';
        final fileName = attMap['fileName']?.toString();
        final fileSize = attMap['fileSize'] as int?;
        final thumbnail = attMap['thumbnail']?.toString();

        if (url.isEmpty) continue;

        final item = SharedMediaItem(
          id: '${doc.id}_${attachments.indexOf(att)}',
          type: attType,
          url: url,
          thumbnailUrl: thumbnail,
          fileName: fileName,
          fileSize: fileSize,
          timestamp: createdAt,
          senderId: senderId,
          senderName: senderName,
        );

        if (attType == 'image' || attType == 'video') {
          media.add(item);
        } else if (attType == 'file') {
          docItems.add(item);
        }
      }

      // Check for links in text content
      if (type == 'text' && content.isNotEmpty) {
        final urlRegex = RegExp(
          r'https?://[^\s<>"{}|\\^`\[\]]+',
          caseSensitive: false,
        );
        final matches = urlRegex.allMatches(content);
        for (final match in matches) {
          final matchUrl = match.group(0) ?? '';
          if (matchUrl.isNotEmpty) {
            links.add(SharedMediaItem(
              id: '${doc.id}_link_${matches.toList().indexOf(match)}',
              type: 'link',
              url: matchUrl,
              timestamp: createdAt,
              senderId: senderId,
              senderName: senderName,
            ));
          }
        }
      }

      // Handle image/video message types directly
      if (type == 'image' || type == 'video') {
        final mediaUrl = data['mediaUrl']?.toString() ?? content;
        if (mediaUrl.isNotEmpty && !media.any((m) => m.url == mediaUrl)) {
          media.add(SharedMediaItem(
            id: doc.id,
            type: type,
            url: mediaUrl,
            thumbnailUrl: data['thumbnailUrl']?.toString(),
            timestamp: createdAt,
            senderId: senderId,
            senderName: senderName,
          ));
        }
      }

      // Handle file message type
      if (type == 'file') {
        final fileUrl = data['fileUrl']?.toString() ?? content;
        final fileName = data['fileName']?.toString();
        if (fileUrl.isNotEmpty && !docItems.any((d) => d.url == fileUrl)) {
          docItems.add(SharedMediaItem(
            id: doc.id,
            type: 'file',
            url: fileUrl,
            fileName: fileName,
            fileSize: data['fileSize'] as int?,
            timestamp: createdAt,
            senderId: senderId,
            senderName: senderName,
          ));
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _mediaItems = media;
      _linkItems = links;
      _docItems = docItems;
      _loading = false;
    });
  }

  Future<String?> _findConversation(String currentUserId, String otherUserId) async {
    // Generate pair key (same logic as repository)
    final pairKey = currentUserId.compareTo(otherUserId) <= 0
        ? '${currentUserId}_$otherUserId'
        : '${otherUserId}_$currentUserId';

    final snapshot = await FirebaseFirestore.instance
        .collection('conversations')
        .where('pairKey', isEqualTo: pairKey)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.id;
    }
    return null;
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
          appBar: AppBar(
            backgroundColor: isDark ? Colors.black : Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              lang.t('shared_media.title'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFFBFAE01),
              unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
              indicatorColor: const Color(0xFFBFAE01),
              labelStyle: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(text: '${lang.t('shared_media.media')} (${_mediaItems.length})'),
                Tab(text: '${lang.t('shared_media.links')} (${_linkItems.length})'),
                Tab(text: '${lang.t('shared_media.docs')} (${_docItems.length})'),
              ],
            ),
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01)))
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: GoogleFonts.inter(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildMediaGrid(isDark, cardColor),
                        _buildLinksList(isDark, cardColor, textColor),
                        _buildDocsList(isDark, cardColor, textColor),
                      ],
                    ),
        );
      },
    );
  }

  Widget _buildMediaGrid(bool isDark, Color cardColor) {
    if (_mediaItems.isEmpty) {
      return _buildEmptyState(
        icon: Icons.photo_library_outlined,
        message: Provider.of<LanguageProvider>(context, listen: false).t('shared_media.no_media'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _mediaItems.length,
      itemBuilder: (context, index) {
        final item = _mediaItems[index];
        final isVideo = item.type == 'video';
        final displayUrl = item.thumbnailUrl ?? item.url;

        return GestureDetector(
          onTap: () {
            if (isVideo) {
              // Open video in browser/external player
              launchUrl(Uri.parse(item.url), mode: LaunchMode.externalApplication);
            } else {
              // Show full screen image dialog
              showDialog(
                context: context,
                builder: (ctx) => Dialog(
                  backgroundColor: Colors.black,
                  insetPadding: EdgeInsets.zero,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      InteractiveViewer(
                        child: CachedNetworkImage(
                          imageUrl: item.url,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Positioned(
                        top: 40,
                        right: 16,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: displayUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFBFAE01),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
              ),
              if (isVideo)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 128),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLinksList(bool isDark, Color cardColor, Color textColor) {
    if (_linkItems.isEmpty) {
      return _buildEmptyState(
        icon: Icons.link_outlined,
        message: Provider.of<LanguageProvider>(context, listen: false).t('shared_media.no_links'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _linkItems.length,
      itemBuilder: (context, index) {
        final item = _linkItems[index];
        final uri = Uri.tryParse(item.url);
        final domain = uri?.host ?? item.url;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 13),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            onTap: () async {
              final url = Uri.parse(item.url);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFBFAE01).withValues(alpha: 26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.link,
                color: Color(0xFFBFAE01),
                size: 20,
              ),
            ),
            title: Text(
              domain,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              item.url,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[500],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Icon(
              Icons.open_in_new,
              size: 18,
              color: Colors.grey[400],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocsList(bool isDark, Color cardColor, Color textColor) {
    if (_docItems.isEmpty) {
      return _buildEmptyState(
        icon: Icons.folder_outlined,
        message: Provider.of<LanguageProvider>(context, listen: false).t('shared_media.no_docs'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _docItems.length,
      itemBuilder: (context, index) {
        final item = _docItems[index];
        final fileName = item.fileName ?? item.url.split('/').last.split('?').first;
        final ext = fileName.split('.').last.toLowerCase();
        final icon = _getFileIcon(ext);
        final sizeStr = item.fileSize != null ? _formatFileSize(item.fileSize!) : '';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 13),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            onTap: () async {
              final url = Uri.parse(item.url);
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getFileColor(ext).withValues(alpha: 26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: _getFileColor(ext),
                size: 20,
              ),
            ),
            title: Text(
              fileName,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              sizeStr.isNotEmpty ? sizeStr : ext.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            trailing: Icon(
              Icons.download_outlined,
              size: 18,
              color: Colors.grey[400],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String ext) {
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileColor(String ext) {
    switch (ext) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      default:
        return const Color(0xFFBFAE01);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Static method to get shared media counts for a conversation
class SharedMediaHelper {
  static Future<Map<String, int>> getSharedMediaCounts(String otherUserId) async {
    try {
      final currentUserId = fb.FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return {'media': 0, 'links': 0, 'docs': 0};

      // Generate pair key
      final pairKey = currentUserId.compareTo(otherUserId) <= 0
          ? '${currentUserId}_$otherUserId'
          : '${otherUserId}_$currentUserId';

      // Find conversation
      final convSnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .where('pairKey', isEqualTo: pairKey)
          .limit(1)
          .get();

      if (convSnapshot.docs.isEmpty) {
        return {'media': 0, 'links': 0, 'docs': 0};
      }

      final conversationId = convSnapshot.docs.first.id;

      // Fetch messages
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .get();

      int mediaCount = 0;
      int linkCount = 0;
      int docCount = 0;

      for (final doc in messagesSnapshot.docs) {
        final data = doc.data();
        final type = data['type']?.toString() ?? 'text';
        final content = data['content']?.toString() ?? '';

        // Count attachments
        final attachments = data['attachments'] as List<dynamic>? ?? [];
        for (final att in attachments) {
          final attMap = att as Map<String, dynamic>;
          final attType = attMap['type']?.toString() ?? '';
          if (attType == 'image' || attType == 'video') {
            mediaCount++;
          } else if (attType == 'file') {
            docCount++;
          }
        }

        // Count links in text
        if (type == 'text' && content.isNotEmpty) {
          final urlRegex = RegExp(r'https?://[^\s<>"{}|\\^`\[\]]+', caseSensitive: false);
          linkCount += urlRegex.allMatches(content).length;
        }

        // Count direct media messages
        if (type == 'image' || type == 'video') {
          mediaCount++;
        } else if (type == 'file') {
          docCount++;
        }
      }

      return {'media': mediaCount, 'links': linkCount, 'docs': docCount};
    } catch (e) {
      return {'media': 0, 'links': 0, 'docs': 0};
    }
  }
}
