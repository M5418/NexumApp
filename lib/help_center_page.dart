import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/i18n/language_provider.dart';
import 'support_page.dart';

class HelpCenterPage extends StatefulWidget {
  const HelpCenterPage({super.key});

  @override
  State<HelpCenterPage> createState() => _HelpCenterPageState();
}

class _HelpCenterPageState extends State<HelpCenterPage> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF0C0C0C) : const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: isDarkMode ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.t('help.title'),
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFBFAE01).withValues(alpha: 0.1),
                    const Color(0xFFBFAE01).withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 64,
                    color: const Color(0xFFBFAE01),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    lang.t('help.subtitle'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Search Bar
                  Container(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() => _searchQuery = value.toLowerCase());
                      },
                      decoration: InputDecoration(
                        hintText: lang.t('help.search'),
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF666666)),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF666666)),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Color(0xFF666666)),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      style: GoogleFonts.inter(
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Help Categories
            Container(
              constraints: const BoxConstraints(maxWidth: 800),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildCategory(
                    lang,
                    isDarkMode,
                    lang.t('help.getting_started'),
                    Icons.rocket_launch,
                    [
                      _HelpItem('gs_create_account', 'gs_create_account_desc'),
                      _HelpItem('gs_complete_profile', 'gs_complete_profile_desc'),
                      _HelpItem('gs_find_people', 'gs_find_people_desc'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildCategory(
                    lang,
                    isDarkMode,
                    lang.t('help.posts'),
                    Icons.article,
                    [
                      _HelpItem('posts_create', 'posts_create_desc'),
                      _HelpItem('posts_react', 'posts_react_desc'),
                      _HelpItem('posts_comment', 'posts_comment_desc'),
                      _HelpItem('posts_share', 'posts_share_desc'),
                      _HelpItem('posts_bookmark', 'posts_bookmark_desc'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildCategory(
                    lang,
                    isDarkMode,
                    lang.t('help.communities'),
                    Icons.groups,
                    [
                      _HelpItem('comm_join', 'comm_join_desc'),
                      _HelpItem('comm_create', 'comm_create_desc'),
                      _HelpItem('comm_post', 'comm_post_desc'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildCategory(
                    lang,
                    isDarkMode,
                    lang.t('help.messages'),
                    Icons.chat_bubble_outline,
                    [
                      _HelpItem('msg_send', 'msg_send_desc'),
                      _HelpItem('msg_attachments', 'msg_attachments_desc'),
                      _HelpItem('msg_voice', 'msg_voice_desc'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildCategory(
                    lang,
                    isDarkMode,
                    lang.t('help.profile'),
                    Icons.person_outline,
                    [
                      _HelpItem('prof_edit', 'prof_edit_desc'),
                      _HelpItem('prof_privacy', 'prof_privacy_desc'),
                      _HelpItem('prof_block', 'prof_block_desc'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildCategory(
                    lang,
                    isDarkMode,
                    lang.t('help.monetization'),
                    Icons.monetization_on_outlined,
                    [
                      _HelpItem('mon_enable', 'mon_enable_desc'),
                      _HelpItem('mon_earnings', 'mon_earnings_desc'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildCategory(
                    lang,
                    isDarkMode,
                    lang.t('help.privacy'),
                    Icons.shield_outlined,
                    [
                      _HelpItem('priv_report', 'priv_report_desc'),
                      _HelpItem('priv_data', 'priv_data_desc'),
                    ],
                  ),
                  
                  // Still Need Help Section
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          lang.t('help.still_need_help'),
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SupportPage(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFBFAE01),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.support_agent, color: Colors.black),
                                const SizedBox(width: 8),
                                Text(
                                  lang.t('help.contact_support'),
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategory(
    LanguageProvider lang,
    bool isDarkMode,
    String title,
    IconData icon,
    List<_HelpItem> items,
  ) {
    // Filter items based on search query
    final filteredItems = _searchQuery.isEmpty
        ? items
        : items.where((item) {
            final titleText = lang.t('help.${item.titleKey}').toLowerCase();
            final descText = lang.t('help.${item.descKey}').toLowerCase();
            return titleText.contains(_searchQuery) || descText.contains(_searchQuery);
          }).toList();

    // Don't show category if no items match search
    if (filteredItems.isEmpty && _searchQuery.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: isDarkMode ? const Color(0xFF1A1A1A) : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDarkMode ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
          width: 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFBFAE01).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFBFAE01),
              size: 24,
            ),
          ),
          title: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          children: filteredItems.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.t('help.${item.titleKey}'),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lang.t('help.${item.descKey}'),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.5,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  if (item != filteredItems.last)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Divider(height: 1),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _HelpItem {
  final String titleKey;
  final String descKey;

  _HelpItem(this.titleKey, this.descKey);
}
