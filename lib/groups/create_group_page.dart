import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../theme_provider.dart';
import '../core/i18n/language_provider.dart';
import '../repositories/firebase/firebase_group_repository.dart';
import '../repositories/interfaces/storage_repository.dart';
import '../services/media_compression_service.dart';
import '../models/group_chat.dart';

class CreateGroupPage extends StatefulWidget {
  final List<String>? preselectedUserIds;

  const CreateGroupPage({
    super.key,
    this.preselectedUserIds,
  });

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();
  final _groupRepo = FirebaseGroupRepository();

  final Set<String> _selectedUserIds = {};
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _connections = [];
  bool _loadingConnections = true;
  bool _searching = false;
  bool _creating = false;
  String? _avatarUrl;
  XFile? _selectedImage;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedUserIds != null) {
      _selectedUserIds.addAll(widget.preselectedUserIds!);
    }
    _loadConnections();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
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

      if (mutualConnectionIds.isEmpty) {
        setState(() {
          _connections = [];
          _loadingConnections = false;
        });
        return;
      }

      // Fetch user profiles for mutual connections
      final connections = <Map<String, dynamic>>[];
      for (final odId in mutualConnectionIds) {
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
      if (!mounted) return;
      setState(() => _loadingConnections = false);
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _searching = true);

    try {
      final uid = fb.FirebaseAuth.instance.currentUser?.uid;
      final queryLower = query.toLowerCase();

      // Search by username
      final usernameQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: queryLower)
          .where('username', isLessThanOrEqualTo: '$queryLower\uf8ff')
          .limit(20)
          .get();

      final results = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      for (final doc in usernameQuery.docs) {
        if (doc.id == uid || seenIds.contains(doc.id)) continue;
        seenIds.add(doc.id);

        final data = doc.data();
        String displayName = (data['displayName'] ?? '').toString();
        if (displayName.isEmpty) {
          final fn = (data['firstName'] ?? '').toString();
          final ln = (data['lastName'] ?? '').toString();
          displayName = '$fn $ln'.trim();
          if (displayName.isEmpty) {
            displayName = (data['username'] ?? 'User').toString();
          }
        }

        results.add({
          'id': doc.id,
          'name': displayName,
          'avatarUrl': data['avatarUrl']?.toString(),
          'username': data['username']?.toString() ?? '',
        });
      }

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedImage = image);
    }
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).t('groups.select_members'))),
      );
      return;
    }

    setState(() => _creating = true);

    try {
      String? uploadedAvatarUrl;

      // Upload avatar if selected
      if (_selectedImage != null) {
        final storageRepo = context.read<StorageRepository>();
        final compressionService = MediaCompressionService();
        final storagePath = 'groups/avatars/${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        if (kIsWeb) {
          final bytes = await _selectedImage!.readAsBytes();
          final compressed = await compressionService.compressImageBytes(
            bytes: bytes,
            filename: _selectedImage!.name,
            quality: 80,
            minWidth: 500,
            minHeight: 500,
          );
          if (compressed != null) {
            uploadedAvatarUrl = await storageRepo.uploadFile(
              path: storagePath,
              bytes: compressed,
              contentType: 'image/jpeg',
            );
          }
        } else {
          final compressed = await compressionService.compressImage(
            filePath: _selectedImage!.path,
            quality: 80,
            minWidth: 500,
            minHeight: 500,
          );
          if (compressed != null) {
            uploadedAvatarUrl = await storageRepo.uploadFile(
              path: storagePath,
              bytes: compressed,
              contentType: 'image/jpeg',
            );
          }
        }
      }

      // Create group
      final groupId = await _groupRepo.createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        avatarUrl: uploadedAvatarUrl,
        memberIds: _selectedUserIds.toList(),
      );

      // Get group for navigation
      final group = await _groupRepo.getGroup(groupId);

      if (!mounted) return;

      // Navigate back with the created group
      Navigator.pop(context, group);
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create group: $e')),
      );
    }
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
              lang.t('groups.create_group'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            actions: [
              if (_creating)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                TextButton(
                  onPressed: _createGroup,
                  child: Text(
                    lang.t('groups.create'),
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFBFAE01),
                    ),
                  ),
                ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Group Avatar
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                          backgroundImage: _selectedImage != null
                              ? (kIsWeb
                                  ? NetworkImage(_selectedImage!.path)
                                  : FileImage(File(_selectedImage!.path)) as ImageProvider)
                              : (_avatarUrl != null
                                  ? CachedNetworkImageProvider(_avatarUrl!)
                                  : null),
                          child: _selectedImage == null && _avatarUrl == null
                              ? Icon(
                                  Icons.group,
                                  size: 40,
                                  color: isDark ? Colors.grey[600] : Colors.grey[500],
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFBFAE01),
                              shape: BoxShape.circle,
                              border: Border.all(color: cardColor, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Group Name
                TextFormField(
                  controller: _nameController,
                  style: GoogleFonts.inter(color: textColor),
                  decoration: InputDecoration(
                    labelText: lang.t('groups.group_name'),
                    labelStyle: GoogleFonts.inter(color: Colors.grey),
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Icon(Icons.group, color: Colors.grey[500]),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return lang.t('groups.name_required');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Description (optional)
                TextFormField(
                  controller: _descriptionController,
                  style: GoogleFonts.inter(color: textColor),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: lang.t('groups.description_optional'),
                    labelStyle: GoogleFonts.inter(color: Colors.grey),
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Icon(Icons.description, color: Colors.grey[500]),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Selected Members Count
                Row(
                  children: [
                    Text(
                      lang.t('groups.members'),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBFAE01),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_selectedUserIds.length}/${GroupChat.maxMembers}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Selected Members Chips
                if (_selectedUserIds.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedUserIds.map((userId) {
                      final user = _connections.firstWhere(
                        (c) => c['id'] == userId,
                        orElse: () => _searchResults.firstWhere(
                          (s) => s['id'] == userId,
                          orElse: () => {'id': userId, 'name': 'User'},
                        ),
                      );
                      return Chip(
                        avatar: CircleAvatar(
                          backgroundImage: user['avatarUrl'] != null
                              ? CachedNetworkImageProvider(user['avatarUrl'])
                              : null,
                          backgroundColor: Colors.grey[400],
                          child: user['avatarUrl'] == null
                              ? Text(
                                  (user['name'] as String? ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 12),
                                )
                              : null,
                        ),
                        label: Text(user['name'] ?? 'User'),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() => _selectedUserIds.remove(userId));
                        },
                        backgroundColor: cardColor,
                        labelStyle: GoogleFonts.inter(color: textColor),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Search Field
                TextFormField(
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
                const SizedBox(height: 16),

                // Search Results or Connections
                if (_searching)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: Color(0xFFBFAE01)),
                    ),
                  )
                else if (_searchResults.isNotEmpty)
                  _buildUserList(_searchResults, isDark, cardColor, textColor, lang.t('groups.search_results'))
                else if (_loadingConnections)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(color: Color(0xFFBFAE01)),
                    ),
                  )
                else
                  _buildUserList(_connections, isDark, cardColor, textColor, lang.t('groups.your_connections')),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserList(
    List<Map<String, dynamic>> users,
    bool isDark,
    Color cardColor,
    Color textColor,
    String title,
  ) {
    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            Provider.of<LanguageProvider>(context, listen: false).t('groups.no_users_found'),
            style: GoogleFonts.inter(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                  } else if (_selectedUserIds.length < GroupChat.maxMembers - 1) {
                    _selectedUserIds.add(userId);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          Provider.of<LanguageProvider>(context, listen: false)
                              .t('groups.max_members_reached'),
                        ),
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
                user['name'] ?? 'User',
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
