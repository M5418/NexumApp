import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../theme_provider.dart';
import '../core/i18n/language_provider.dart';
import '../repositories/firebase/firebase_group_repository.dart';
import '../models/group_chat.dart';

class AddMembersPage extends StatefulWidget {
  final GroupChat group;

  const AddMembersPage({
    super.key,
    required this.group,
  });

  @override
  State<AddMembersPage> createState() => _AddMembersPageState();
}

class _AddMembersPageState extends State<AddMembersPage> {
  final _searchController = TextEditingController();
  final _groupRepo = FirebaseGroupRepository();

  final Set<String> _selectedUserIds = {};
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _connections = [];
  bool _loadingConnections = true;
  bool _searching = false;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadConnections() async {
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _loadingConnections = true);

    try {
      // Get mutual connections (users who follow you AND you follow them)
      final followersSnapshot = await FirebaseFirestore.instance
          .collection('follows')
          .where('followedId', isEqualTo: uid)
          .get();

      final followingSnapshot = await FirebaseFirestore.instance
          .collection('follows')
          .where('followerId', isEqualTo: uid)
          .get();

      // Get IDs
      final followersIds = followersSnapshot.docs
          .map((doc) => doc.data()['followerId']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      final followingIds = followingSnapshot.docs
          .map((doc) => doc.data()['followedId']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      // Mutual connections = intersection of both sets
      final mutualConnectionIds = followersIds.intersection(followingIds).toList();

      // Filter out users already in the group
      final existingMemberIds = widget.group.memberIds.toSet();
      final availableIds = mutualConnectionIds.where((id) => !existingMemberIds.contains(id)).toList();

      if (availableIds.isEmpty) {
        setState(() {
          _connections = [];
          _loadingConnections = false;
        });
        return;
      }

      // Fetch user profiles for available connections
      final connections = <Map<String, dynamic>>[];
      for (final odId in availableIds) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(odId)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data() ?? {};
          String displayName = (data['displayName'] ?? '').toString();
          if (displayName.isEmpty) {
            final fn = (data['firstName'] ?? '').toString();
            final ln = (data['lastName'] ?? '').toString();
            displayName = '$fn $ln'.trim();
            if (displayName.isEmpty) {
              displayName = (data['username'] ?? data['email'] ?? 'User').toString();
            }
          }

          connections.add({
            'id': odId,
            'name': displayName,
            'avatarUrl': data['avatarUrl']?.toString(),
            'username': data['username']?.toString() ?? '',
          });
        }
      }

      // Sort alphabetically
      connections.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      if (!mounted) return;
      setState(() {
        _connections = connections;
        _loadingConnections = false;
      });
    } catch (e) {
      debugPrint('Error loading connections: $e');
      if (!mounted) return;
      setState(() => _loadingConnections = false);
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) return;

    setState(() => _searching = true);

    try {
      final uid = fb.FirebaseAuth.instance.currentUser?.uid;
      final existingMemberIds = widget.group.memberIds.toSet();

      // Search by username or name
      final usernameResults = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
          .where('username', isLessThan: '${query.toLowerCase()}\uf8ff')
          .limit(20)
          .get();

      final nameResults = await FirebaseFirestore.instance
          .collection('users')
          .where('displayName', isGreaterThanOrEqualTo: query)
          .where('displayName', isLessThan: '$query\uf8ff')
          .limit(20)
          .get();

      // Combine and dedupe results
      final allDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final doc in usernameResults.docs) {
        allDocs[doc.id] = doc;
      }
      for (final doc in nameResults.docs) {
        allDocs[doc.id] = doc;
      }

      final results = <Map<String, dynamic>>[];
      for (final doc in allDocs.values) {
        final odId = doc.id;
        // Skip current user and existing members
        if (odId == uid || existingMemberIds.contains(odId)) continue;

        final data = doc.data();
        String displayName = (data['displayName'] ?? '').toString();
        if (displayName.isEmpty) {
          final fn = (data['firstName'] ?? '').toString();
          final ln = (data['lastName'] ?? '').toString();
          displayName = '$fn $ln'.trim();
          if (displayName.isEmpty) {
            displayName = (data['username'] ?? data['email'] ?? 'User').toString();
          }
        }

        results.add({
          'id': odId,
          'name': displayName,
          'avatarUrl': data['avatarUrl']?.toString(),
          'username': data['username']?.toString() ?? '',
        });
      }

      // Sort alphabetically
      results.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (e) {
      debugPrint('Error searching users: $e');
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  Future<void> _addSelectedMembers() async {
    if (_selectedUserIds.isEmpty) return;

    setState(() => _adding = true);

    try {
      await _groupRepo.addMembers(widget.group.id, _selectedUserIds.toList());

      if (!mounted) return;
      
      // Return the list of added user IDs
      Navigator.pop(context, _selectedUserIds.toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${Provider.of<LanguageProvider>(context, listen: false).t('groups.add_members_failed')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? const Color(0xFF1A1A1A) : Colors.grey[100]!;
    final lang = Provider.of<LanguageProvider>(context, listen: false);

    final currentMemberCount = widget.group.memberIds.length;
    final maxCanAdd = GroupChat.maxMembers - currentMemberCount;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lang.t('groups.add_members'),
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        actions: [
          if (_selectedUserIds.isNotEmpty)
            TextButton(
              onPressed: _adding ? null : _addSelectedMembers,
              child: _adding
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFBFAE01),
                      ),
                    )
                  : Text(
                      '${lang.t('groups.add')} (${_selectedUserIds.length})',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFBFAE01),
                      ),
                    ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Selected users chips
          if (_selectedUserIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedUserIds.map((userId) {
                  // Find user info
                  final user = [..._connections, ..._searchResults]
                      .firstWhere((u) => u['id'] == userId, orElse: () => {'id': userId, 'name': 'User'});
                  return Chip(
                    label: Text(
                      user['name'] as String,
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() => _selectedUserIds.remove(userId));
                    },
                    backgroundColor: cardColor,
                  );
                }).toList(),
              ),
            ),

          // Search field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextFormField(
              controller: _searchController,
              style: GoogleFonts.inter(color: textColor),
              decoration: InputDecoration(
                hintText: lang.t('groups.search_users'),
                hintStyle: GoogleFonts.inter(color: Colors.grey),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchResults = []);
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                if (value.length >= 2) {
                  _searchUsers(value);
                } else {
                  setState(() => _searchResults = []);
                }
              },
            ),
          ),

          // Info text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${lang.t('groups.can_add_up_to')} $maxCanAdd ${lang.t('groups.more_members')}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // User list
          Expanded(
            child: _searching
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFBFAE01)),
                  )
                : _searchResults.isNotEmpty
                    ? _buildUserList(_searchResults, isDark, cardColor, textColor, lang.t('groups.search_results'), maxCanAdd)
                    : _loadingConnections
                        ? const Center(
                            child: CircularProgressIndicator(color: Color(0xFFBFAE01)),
                          )
                        : _buildUserList(_connections, isDark, cardColor, textColor, lang.t('groups.your_connections'), maxCanAdd),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(
    List<Map<String, dynamic>> users,
    bool isDark,
    Color cardColor,
    Color textColor,
    String title,
    int maxCanAdd,
  ) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    
    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            lang.t('groups.no_users_found'),
            style: GoogleFonts.inter(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        ...users.map((user) {
          final userId = user['id'] as String;
          final isSelected = _selectedUserIds.contains(userId);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedUserIds.remove(userId);
                  } else if (_selectedUserIds.length < maxCanAdd) {
                    _selectedUserIds.add(userId);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(lang.t('groups.max_members_reached')),
                      ),
                    );
                  }
                });
              },
              leading: CircleAvatar(
                backgroundImage: user['avatarUrl'] != null
                    ? CachedNetworkImageProvider(user['avatarUrl'])
                    : null,
                backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                child: user['avatarUrl'] == null
                    ? Text(
                        (user['name'] as String? ?? 'U')[0].toUpperCase(),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      )
                    : null,
              ),
              title: Text(
                user['name'] as String,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              subtitle: user['username'] != null && (user['username'] as String).isNotEmpty
                  ? Text(
                      '@${user['username']}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    )
                  : null,
              trailing: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? const Color(0xFFBFAE01) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? const Color(0xFFBFAE01) : Colors.grey,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.black)
                    : null,
              ),
            ),
          );
        }),
      ],
    );
  }
}
