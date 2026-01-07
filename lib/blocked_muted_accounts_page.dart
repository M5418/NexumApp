import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/i18n/language_provider.dart';
import 'repositories/interfaces/block_repository.dart';
import 'repositories/interfaces/mute_repository.dart';
import 'utils/profile_navigation.dart';

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

  List<BlockedUser> _blocked = [];
  List<MutedUser> _muted = [];
  bool _loadingBlocked = true;
  bool _loadingMuted = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    _loadBlocked();
    _loadMuted();
  }

  Future<void> _loadBlocked() async {
    try {
      final blockRepo = context.read<BlockRepository>();
      final users = await blockRepo.getBlockedUsers();
      if (mounted) {
        setState(() {
          _blocked = users;
          _loadingBlocked = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingBlocked = false);
      }
    }
  }

  Future<void> _loadMuted() async {
    try {
      final muteRepo = context.read<MuteRepository>();
      final users = await muteRepo.getMutedUsers();
      if (mounted) {
        setState(() {
          _muted = users;
          _loadingMuted = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMuted = false);
      }
    }
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
          Provider.of<LanguageProvider>(context).t('blocked_muted.title'),
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
                tabs: [
                  Tab(text: Provider.of<LanguageProvider>(context).t('blocked_muted.blocked_tab')),
                  Tab(text: Provider.of<LanguageProvider>(context).t('blocked_muted.muted_tab')),
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
                hintText: Provider.of<LanguageProvider>(context, listen: false).t('common.search_accounts'),
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
                _buildBlockedList(cardColor),
                _buildMutedList(cardColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<BlockedUser> _filteredBlocked() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _blocked;
    return _blocked.where((user) => 
      (user.blockedUsername ?? '').toLowerCase().contains(q)
    ).toList();
  }

  List<MutedUser> _filteredMuted() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _muted;
    return _muted.where((user) => 
      (user.mutedUsername ?? '').toLowerCase().contains(q)
    ).toList();
  }

  Widget _buildBlockedList(Color cardColor) {
    if (_loadingBlocked) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _filteredBlocked();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemBuilder: (_, i) {
        final user = items[i];
        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            onTap: () {
              navigateToUserProfile(
                context: context,
                userId: user.blockedUid,
                userName: user.blockedUsername ?? 'Unknown',
                userAvatarUrl: user.blockedAvatarUrl ?? '',
                userBio: '',
              );
            },
            leading: CircleAvatar(
              backgroundImage: user.blockedAvatarUrl != null && user.blockedAvatarUrl!.isNotEmpty
                  ? NetworkImage(user.blockedAvatarUrl!)
                  : null,
              child: user.blockedAvatarUrl == null || user.blockedAvatarUrl!.isEmpty
                  ? Text((user.blockedUsername ?? 'U')[0].toUpperCase())
                  : null,
            ),
            title: Text(
              user.blockedUsername ?? Provider.of<LanguageProvider>(context, listen: false).t('common.unknown_user'),
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            trailing: TextButton(
              onPressed: () => _handleUnblock(user.blockedUid),
              child: Text(
                Provider.of<LanguageProvider>(context).t('blocked_muted.unblock'),
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
    );
  }

  Widget _buildMutedList(Color cardColor) {
    if (_loadingMuted) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = _filteredMuted();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemBuilder: (_, i) {
        final user = items[i];
        return Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            onTap: () {
              navigateToUserProfile(
                context: context,
                userId: user.mutedUid,
                userName: user.mutedUsername ?? 'Unknown',
                userAvatarUrl: user.mutedAvatarUrl ?? '',
                userBio: '',
              );
            },
            leading: CircleAvatar(
              backgroundImage: user.mutedAvatarUrl != null && user.mutedAvatarUrl!.isNotEmpty
                  ? NetworkImage(user.mutedAvatarUrl!)
                  : null,
              child: user.mutedAvatarUrl == null || user.mutedAvatarUrl!.isEmpty
                  ? Text((user.mutedUsername ?? 'U')[0].toUpperCase())
                  : null,
            ),
            title: Text(
              user.mutedUsername ?? Provider.of<LanguageProvider>(context, listen: false).t('common.unknown_user'),
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            trailing: TextButton(
              onPressed: () => _handleUnmute(user.mutedUid),
              child: Text(
                Provider.of<LanguageProvider>(context).t('blocked_muted.unmute'),
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
    );
  }

  Future<void> _handleUnblock(String blockedUid) async {
    try {
      final blockRepo = context.read<BlockRepository>();
      await blockRepo.unblockUser(blockedUid);
      _loadBlocked();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(context, listen: false).t('blocked_muted.unblock_success'), style: GoogleFonts.inter()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(context, listen: false).t('blocked_muted.unblock_failed'), style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleUnmute(String mutedUid) async {
    try {
      final muteRepo = context.read<MuteRepository>();
      await muteRepo.unmuteUser(mutedUid);
      _loadMuted();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(context, listen: false).t('blocked_muted.unmute_success'), style: GoogleFonts.inter()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(Provider.of<LanguageProvider>(context, listen: false).t('blocked_muted.unmute_failed'), style: GoogleFonts.inter()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
