import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/segmented_tabs.dart';
import 'core/invitations_api.dart';
import 'chat_page.dart';
import 'models/message.dart';

// String extension for capitalize
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

// Invitation actions
enum BulkAction { accept, reject, delete, cancel }

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

  List<Invitation> _received = [];
  List<Invitation> _sent = [];

  final InvitationsApi _api = InvitationsApi();

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
    _loadInvitations();
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
      backgroundColor:
          isDark ? const Color(0xFF0C0C0C) : const Color(0xFFF1F4F8),
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
    final String title =
        _selectedTabIndex == 0 ? 'Invitations' : 'Invitations Sent';
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
                  backgroundImage: item.sender.avatarUrl != null
                      ? NetworkImage(item.sender.avatarUrl!)
                      : null,
                  child: item.sender.avatarUrl == null
                      ? Text(
                          item.sender.name.isNotEmpty
                              ? item.sender.name[0].toUpperCase()
                              : 'U',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
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
                              isSent ? item.receiver.name : item.sender.name,
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
                        isSent ? item.receiver.username : item.sender.username,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.invitationContent,
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

  Future<void> _applySingle(BulkAction action, String id) async {
    try {
      switch (action) {
        case BulkAction.accept:
          // Capture the invitation before it's removed by reload
          Invitation? invitation;
          try {
            invitation = _received.firstWhere((e) => e.id == id);
          } catch (_) {
            invitation = null;
          }

          final conversationId = await _api.acceptInvitation(id);

          if (mounted && conversationId != null && invitation != null) {
            final other = ChatUser(
              id: invitation.senderId,
              name: invitation.sender.name,
              avatarUrl: invitation.sender.avatarUrl,
            );
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatPage(
                  otherUser: other,
                  isDarkMode: widget.isDarkMode,
                  conversationId: conversationId,
                ),
              ),
            );
          }
          break;
        case BulkAction.reject:
          await _api.refuseInvitation(id);
          break;
        case BulkAction.delete:
          await _api.deleteInvitation(id);
          break;
        case BulkAction.cancel:
          await _api.deleteInvitation(id);
          break;
      }

      // Reload invitations after action
      await _loadInvitations();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${action.name.capitalize()} successful',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to ${action.name}: ${e.toString()}',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _applyBulk() async {
    if (_selectedIds.isEmpty) return;

    try {
      final futures = _selectedIds.map((id) {
        switch (_currentAction!) {
          case BulkAction.accept:
            return _api.acceptInvitation(id);
          case BulkAction.reject:
            return _api.refuseInvitation(id);
          case BulkAction.delete:
            return _api.deleteInvitation(id);
          case BulkAction.cancel:
            return _api.deleteInvitation(id);
        }
      });

      await Future.wait(futures);

      // Reload invitations after bulk action
      await _loadInvitations();

      setState(() {
        _selectionMode = false;
        _currentAction = null;
        _selectedIds.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bulk ${_currentAction!.name.capitalize()} successful',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to apply bulk action: ${e.toString()}',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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

  Future<void> _loadInvitations() async {
    try {
      final received = await _api.getReceivedInvitations();
      final sent = await _api.getSentInvitations();
      setState(() {
        // Show only pending invitations so accepted/refused disappear
        _received = received.where((i) => i.status == 'pending').toList();
        _sent = sent.where((i) => i.status == 'pending').toList();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to load invitations: ${e.toString()}',
              style: GoogleFonts.inter(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
