import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/segmented_tabs.dart';

// Invitation models and actions
enum BulkAction { accept, reject, delete, cancel }

class Invitation {
  final String id;
  final String name;
  final String handle;
  final String avatarUrl;
  final String message;

  Invitation({
    required this.id,
    required this.name,
    required this.handle,
    required this.avatarUrl,
    required this.message,
  });
}

class InvitationPage extends StatefulWidget {
  final bool? isDarkMode;
  const InvitationPage({super.key, this.isDarkMode});

  @override
  State<InvitationPage> createState() => _InvitationPageState();
}

class _InvitationPageState extends State<InvitationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;

  bool _selectionMode = false;
  BulkAction? _currentAction;
  final Set<String> _selectedIds = <String>{};

  // Sample data
  final List<Invitation> _received = [
    Invitation(
      id: 'r1',
      name: 'Aiden Blaze',
      handle: '@aidenblaze',
      avatarUrl: 'https://picsum.photos/200/200?random=18',
      message:
          'Good morning Sir! It\'s pleasure to reach out to you! Could you please give me an answer I had a great business idea that I want us to talk about',
    ),
    Invitation(
      id: 'r2',
      name: 'Aiden Blaze',
      handle: '@aidenblaze',
      avatarUrl: 'https://picsum.photos/200/200?random=28',
      message:
          'Good morning Sir! It\'s pleasure to reach out to you! Could you please give me an answer I had a great business idea that I want us to talk about',
    ),
    Invitation(
      id: 'r3',
      name: 'Aiden Blaze',
      handle: '@aidenblaze',
      avatarUrl: 'https://picsum.photos/200/200?random=38',
      message:
          'Good morning Sir! It\'s pleasure to reach out to you! Could you please give me an answer I had a great business idea that I want us to talk about',
    ),
  ];

  final List<Invitation> _sent = [
    Invitation(
      id: 's1',
      name: 'Aiden Blaze',
      handle: '@aidenblaze',
      avatarUrl: 'https://picsum.photos/200/200?random=48',
      message:
          'Good morning Sir! It\'s pleasure to reach out to you! Could you please give me an answer I had a great business idea that I want us to talk about',
    ),
    Invitation(
      id: 's2',
      name: 'Aiden Blaze',
      handle: '@aidenblaze',
      avatarUrl: 'https://picsum.photos/200/200?random=58',
      message:
          'Good morning Sir! It\'s pleasure to reach out to you! Could you please give me an answer I had a great business idea that I want us to talk about',
    ),
    Invitation(
      id: 's3',
      name: 'Aiden Blaze',
      handle: '@aidenblaze',
      avatarUrl: 'https://picsum.photos/200/200?random=68',
      message:
          'Good morning Sir! It\'s pleasure to reach out to you! Could you please give me an answer I had a great business idea that I want us to talk about',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedTabIndex = _tabController.index;
          _selectionMode = false;
          _currentAction = null;
          _selectedIds.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = widget.isDarkMode ?? theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0C0C0C)
          : const Color(0xFFF1F4F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(isDark),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedTabs(
                tabs: const ['Invitations', 'Invitations Sent'],
                selectedIndex: _selectedTabIndex,
                onTabSelected: (index) {
                  setState(() {
                    _selectedTabIndex = index;
                    _tabController.animateTo(index);
                  });
                },
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildList(isDark, _received, isSent: false),
                  _buildList(isDark, _sent, isSent: true),
                ],
              ),
            ),
            _buildBulkActionBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    final String title = _selectedTabIndex == 0
        ? 'Invitations'
        : 'Invitations Sent';
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF666666), width: 0.6),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back_ios_new,
                size: 16,
                color: Color(0xFF666666),
              ),
              padding: EdgeInsets.zero,
            ),
          ),

          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),

          // 3-dots menu
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF666666), width: 0.6),
            ),
            child: PopupMenuButton<BulkAction>(
              tooltip: 'Options',
              icon: const Icon(
                Icons.more_horiz,
                size: 18,
                color: Color(0xFF666666),
              ),
              position: PopupMenuPosition.under,
              onSelected: (action) {
                setState(() {
                  _selectionMode = true;
                  _currentAction = action;
                  _selectedIds.clear();
                });
              },
              itemBuilder: (context) {
                final isReceived = _selectedTabIndex == 0;
                final List<PopupMenuEntry<BulkAction>> items = [
                  PopupMenuItem<BulkAction>(
                    enabled: false,
                    child: Text(
                      isReceived ? 'Invitations' : 'Invitations Sent',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const PopupMenuDivider(height: 8),
                ];
                if (isReceived) {
                  items.addAll(const [
                    PopupMenuItem(
                      value: BulkAction.accept,
                      child: Text('Accept'),
                    ),
                    PopupMenuItem(
                      value: BulkAction.reject,
                      child: Text('Reject'),
                    ),
                    PopupMenuItem(
                      value: BulkAction.delete,
                      child: Text('Delete'),
                    ),
                  ]);
                } else {
                  items.addAll(const [
                    PopupMenuItem(
                      value: BulkAction.cancel,
                      child: Text('Cancel'),
                    ),
                    PopupMenuItem(
                      value: BulkAction.delete,
                      child: Text('Delete'),
                    ),
                  ]);
                }
                return items;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    bool isDark,
    List<Invitation> data, {
    required bool isSent,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: data.length,
        separatorBuilder: (context, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = data[index];
          final bool showToggle = _selectionMode && _currentAction != null;
          return Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.black : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 13),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundImage: NetworkImage(item.avatarUrl),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!showToggle && !isSent) ...[
                            _pillButton(
                              label: 'Accept',
                              onTap: () =>
                                  _applySingle(BulkAction.accept, item.id),
                            ),
                            const SizedBox(width: 8),
                            _pillButton(
                              label: 'Reject',
                              onTap: () =>
                                  _applySingle(BulkAction.reject, item.id),
                            ),
                          ] else if (!showToggle && isSent) ...[
                            _pillButton(
                              label: 'Cancel',
                              onTap: () =>
                                  _applySingle(BulkAction.cancel, item.id),
                            ),
                          ] else ...[
                            _selectionToggleForAction(item.id),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.handle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.message,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF666666),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _selectionToggleForAction(String id) {
    final String label;
    switch (_currentAction) {
      case BulkAction.accept:
        label = 'Accept';
        break;
      case BulkAction.reject:
        label = 'Reject';
        break;
      case BulkAction.delete:
        label = 'Delete';
        break;
      case BulkAction.cancel:
        label = 'Cancel';
        break;
      default:
        label = '';
    }
    final selected = _selectedIds.contains(id);
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => _toggleSelected(id),
      labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
      shape: StadiumBorder(
        side: BorderSide(color: const Color(0xFF666666).withValues(alpha: 77)),
      ),
      selectedColor: const Color(0xFF007AFF).withValues(alpha: 51),
      backgroundColor: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _pillButton({required String label, required VoidCallback onTap}) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: const StadiumBorder(),
        side: const BorderSide(color: Color(0xFFDDDDDD), width: 1),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _applySingle(BulkAction action, String id) {
    setState(() {
      if (_selectedTabIndex == 0) {
        _received.removeWhere((e) => e.id == id);
      } else {
        _sent.removeWhere((e) => e.id == id);
      }
    });
  }

  void _applyBulk() {
    final ids = Set<String>.from(_selectedIds);
    setState(() {
      if (_selectedTabIndex == 0) {
        _received.removeWhere((e) => ids.contains(e.id));
      } else {
        _sent.removeWhere((e) => ids.contains(e.id));
      }
      _selectionMode = false;
      _currentAction = null;
      _selectedIds.clear();
    });
  }

  Widget _buildBulkActionBar(bool isDark) {
    if (!_selectionMode) return const SizedBox.shrink();
    final String cta;
    switch (_currentAction) {
      case BulkAction.accept:
        cta = 'Accept selected';
        break;
      case BulkAction.reject:
        cta = 'Reject selected';
        break;
      case BulkAction.delete:
        cta = 'Delete selected';
        break;
      case BulkAction.cancel:
        cta = 'Cancel selected';
        break;
      default:
        cta = 'Apply';
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        border: Border(
          top: BorderSide(color: const Color(0xFF666666).withValues(alpha: 26)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _selectedIds.isEmpty
                  ? 'Select invitations'
                  : '${_selectedIds.length} selected',
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectionMode = false;
                _currentAction = null;
                _selectedIds.clear();
              });
            },
            child: const Text('Close'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _selectedIds.isEmpty ? null : _applyBulk,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: const StadiumBorder(),
            ),
            child: Text(
              cta,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
