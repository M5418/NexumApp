import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BlockedMutedAccountsPage extends StatefulWidget {
  const BlockedMutedAccountsPage({super.key});

  @override
  State<BlockedMutedAccountsPage> createState() =>
      _BlockedMutedAccountsPageState();
}

class _BlockedMutedAccountsPageState extends State<BlockedMutedAccountsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final TextEditingController _searchCtrl = TextEditingController();

  final List<String> _blocked = [
    'spam_user_01',
    'troll_account',
    'noisy_marketer',
  ];
  final List<String> _muted = ['loud_friend', 'brand_promo', 'sports_news'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF0C0C0C)
        : const Color(0xFFF1F4F8);
    final cardColor = isDark ? const Color(0xFF000000) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Blocked & Muted',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                indicator: BoxDecoration(
                  color: const Color(0xFFBFAE01),
                  borderRadius: BorderRadius.circular(25),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(2),
                dividerColor: Colors.transparent,
                labelColor: Colors.black,
                unselectedLabelColor: isDark
                    ? Colors.white70
                    : const Color(0xFF666666),
                labelStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                labelPadding: const EdgeInsets.symmetric(horizontal: 24),
                tabs: const [
                  Tab(text: 'Blocked'),
                  Tab(text: 'Muted'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search accounts',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildList(
                  items: _filtered(_blocked),
                  emptyLabel: 'No blocked accounts',
                  actionLabel: 'Unblock',
                  onAction: (u) => setState(() => _blocked.remove(u)),
                  onAdd: () => _addDialog(isBlocked: true),
                  cardColor: cardColor,
                ),
                _buildList(
                  items: _filtered(_muted),
                  emptyLabel: 'No muted accounts',
                  actionLabel: 'Unmute',
                  onAction: (u) => setState(() => _muted.remove(u)),
                  onAdd: () => _addDialog(isBlocked: false),
                  cardColor: cardColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _filtered(List<String> source) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source.where((e) => e.toLowerCase().contains(q)).toList();
  }

  Widget _buildList({
    required List<String> items,
    required String emptyLabel,
    required String actionLabel,
    required void Function(String user) onAction,
    required VoidCallback onAdd,
    required Color cardColor,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: Text(
                'Add',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFBFAE01),
                side: const BorderSide(color: Color(0xFFBFAE01), width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    emptyLabel,
                    style: GoogleFonts.inter(color: const Color(0xFF666666)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemBuilder: (_, i) {
                    final user = items[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(user.substring(0, 1).toUpperCase()),
                        ),
                        title: Text(
                          user,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                        ),
                        trailing: TextButton(
                          onPressed: () => onAction(user),
                          child: Text(
                            actionLabel,
                            style: GoogleFonts.inter(
                              color: const Color(0xFFBFAE01),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (context, _) => const SizedBox(height: 10),
                  itemCount: items.length,
                ),
        ),
      ],
    );
  }

  Future<void> _addDialog({required bool isBlocked}) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isBlocked ? 'Block account' : 'Mute account',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Enter @username',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(
              'Add',
              style: GoogleFonts.inter(color: const Color(0xFFBFAE01)),
            ),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    setState(() {
      if (isBlocked) {
        if (!_blocked.contains(result)) _blocked.add(result);
      } else {
        if (!_muted.contains(result)) _muted.add(result);
      }
    });
  }
}
