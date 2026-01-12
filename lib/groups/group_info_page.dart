import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../theme_provider.dart';
import '../core/i18n/language_provider.dart';
import '../repositories/firebase/firebase_group_repository.dart';
import '../repositories/interfaces/storage_repository.dart';
import '../services/media_compression_service.dart';
import '../models/group_chat.dart';
import '../utils/profile_navigation.dart';

class GroupInfoPage extends StatefulWidget {
  final GroupChat group;

  const GroupInfoPage({
    super.key,
    required this.group,
  });

  @override
  State<GroupInfoPage> createState() => _GroupInfoPageState();
}

class _GroupInfoPageState extends State<GroupInfoPage> {
  final _groupRepo = FirebaseGroupRepository();
  
  late GroupChat _group;
  List<GroupMember> _members = [];
  bool _loadingMembers = true;
  bool _updating = false;

  String? get _currentUserId => fb.FirebaseAuth.instance.currentUser?.uid;
  bool get _isAdmin => _group.isAdmin(_currentUserId ?? '');

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    try {
      final members = await _groupRepo.getGroupMembers(_group.id);
      if (!mounted) return;
      setState(() {
        _members = members;
        _loadingMembers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMembers = false);
    }
  }

  Future<void> _updateGroupAvatar() async {
    if (!_isAdmin && _group.onlyAdminsCanEditInfo) return;
    final storageRepo = context.read<StorageRepository>();
    final compressionService = MediaCompressionService();

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _updating = true);

    try {
      final storagePath = 'groups/avatars/${_group.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String? url;

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        final compressed = await compressionService.compressImageBytes(
          bytes: bytes,
          filename: image.name,
          quality: 80,
          minWidth: 500,
          minHeight: 500,
        );
        if (compressed != null) {
          url = await storageRepo.uploadFile(
            path: storagePath,
            bytes: compressed,
            contentType: 'image/jpeg',
          );
        }
      } else {
        final compressed = await compressionService.compressImage(
          filePath: image.path,
          quality: 80,
          minWidth: 500,
          minHeight: 500,
        );
        if (compressed != null) {
          url = await storageRepo.uploadFile(
            path: storagePath,
            bytes: compressed,
            contentType: 'image/jpeg',
          );
        }
      }

      if (url != null) {
        await _groupRepo.updateGroup(groupId: _group.id, avatarUrl: url);
        final updated = await _groupRepo.getGroup(_group.id);
        if (updated != null && mounted) {
          setState(() => _group = updated);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update avatar: $e')),
      );
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _editGroupName() async {
    if (!_isAdmin && _group.onlyAdminsCanEditInfo) return;

    final controller = TextEditingController(text: _group.name);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Provider.of<LanguageProvider>(context, listen: false).t('groups.edit_name')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: Provider.of<LanguageProvider>(context, listen: false).t('groups.group_name'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Provider.of<LanguageProvider>(context, listen: false).t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(Provider.of<LanguageProvider>(context, listen: false).t('common.save')),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != _group.name) {
      setState(() => _updating = true);
      try {
        await _groupRepo.updateGroup(groupId: _group.id, name: result);
        final updated = await _groupRepo.getGroup(_group.id);
        if (updated != null && mounted) {
          setState(() => _group = updated);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update name: $e')),
        );
      } finally {
        if (mounted) setState(() => _updating = false);
      }
    }
  }

  Future<void> _editGroupDescription() async {
    if (!_isAdmin && _group.onlyAdminsCanEditInfo) return;

    final controller = TextEditingController(text: _group.description ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Provider.of<LanguageProvider>(context, listen: false).t('groups.edit_description')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: Provider.of<LanguageProvider>(context, listen: false).t('groups.description_optional'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(Provider.of<LanguageProvider>(context, listen: false).t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(Provider.of<LanguageProvider>(context, listen: false).t('common.save')),
          ),
        ],
      ),
    );

    if (result != null && result != _group.description) {
      setState(() => _updating = true);
      try {
        await _groupRepo.updateGroup(groupId: _group.id, description: result);
        final updated = await _groupRepo.getGroup(_group.id);
        if (updated != null && mounted) {
          setState(() => _group = updated);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update description: $e')),
        );
      } finally {
        if (mounted) setState(() => _updating = false);
      }
    }
  }

  Future<void> _addMembers() async {
    if (!_isAdmin) return;

    // Navigate to member selection (reuse create group page logic)
    // For now, show a simple dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(Provider.of<LanguageProvider>(context, listen: false).t('groups.add_members_coming_soon'))),
    );
  }

  Future<void> _removeMember(GroupMember member) async {
    if (!_isAdmin && member.odId != _currentUserId) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Provider.of<LanguageProvider>(context, listen: false).t('groups.remove_member')),
        content: Text(
          member.odId == _currentUserId
              ? Provider.of<LanguageProvider>(context, listen: false).t('groups.leave_confirm')
              : '${Provider.of<LanguageProvider>(context, listen: false).t('groups.remove_confirm')} ${member.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Provider.of<LanguageProvider>(context, listen: false).t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              member.odId == _currentUserId
                  ? Provider.of<LanguageProvider>(context, listen: false).t('groups.leave')
                  : Provider.of<LanguageProvider>(context, listen: false).t('groups.remove'),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _groupRepo.removeMember(_group.id, member.odId);
      
      if (member.odId == _currentUserId) {
        // Left the group
        if (mounted) Navigator.pop(context, 'left');
      } else {
        // Reload members
        await _loadMembers();
        // Refresh group
        final updated = await _groupRepo.getGroup(_group.id);
        if (updated != null && mounted) {
          setState(() => _group = updated);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Future<void> _toggleAdmin(GroupMember member) async {
    if (!_isAdmin) return;

    try {
      if (member.isAdmin) {
        await _groupRepo.demoteFromAdmin(_group.id, member.odId);
      } else {
        await _groupRepo.promoteToAdmin(_group.id, member.odId);
      }
      
      await _loadMembers();
      final updated = await _groupRepo.getGroup(_group.id);
      if (updated != null && mounted) {
        setState(() => _group = updated);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Future<void> _toggleMute() async {
    try {
      if (_group.isMuted(_currentUserId ?? '')) {
        await _groupRepo.unmuteGroup(_group.id);
      } else {
        await _groupRepo.muteGroup(_group.id);
      }
      
      final updated = await _groupRepo.getGroup(_group.id);
      if (updated != null && mounted) {
        setState(() => _group = updated);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Future<void> _toggleOnlyAdminsCanSend() async {
    if (!_isAdmin) return;

    try {
      await _groupRepo.updateGroup(
        groupId: _group.id,
        onlyAdminsCanSend: !_group.onlyAdminsCanSend,
      );
      
      final updated = await _groupRepo.getGroup(_group.id);
      if (updated != null && mounted) {
        setState(() => _group = updated);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  Future<void> _deleteGroup() async {
    if (!_isAdmin) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(Provider.of<LanguageProvider>(context, listen: false).t('groups.delete_group')),
        content: Text(Provider.of<LanguageProvider>(context, listen: false).t('groups.delete_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(Provider.of<LanguageProvider>(context, listen: false).t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(Provider.of<LanguageProvider>(context, listen: false).t('groups.delete')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _groupRepo.deleteGroup(_group.id);
      if (mounted) Navigator.pop(context, 'deleted');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
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
              onPressed: () => Navigator.pop(context, _group),
            ),
            title: Text(
              lang.t('groups.group_info'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
          body: _updating
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Group Avatar & Name
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: (_isAdmin || !_group.onlyAdminsCanEditInfo) ? _updateGroupAvatar : null,
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 50,
                                  backgroundImage: _group.avatarUrl != null
                                      ? CachedNetworkImageProvider(_group.avatarUrl!)
                                      : null,
                                  backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                                  child: _group.avatarUrl == null
                                      ? Icon(Icons.group, size: 40, color: Colors.grey[500])
                                      : null,
                                ),
                                if (_isAdmin || !_group.onlyAdminsCanEditInfo)
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
                                      child: const Icon(Icons.camera_alt, size: 14, color: Colors.black),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: (_isAdmin || !_group.onlyAdminsCanEditInfo) ? _editGroupName : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _group.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                if (_isAdmin || !_group.onlyAdminsCanEditInfo) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.edit, size: 18, color: Colors.grey[500]),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_group.memberIds.length} ${lang.t('groups.members_count')}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Description
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                lang.t('groups.description'),
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                              if (_isAdmin || !_group.onlyAdminsCanEditInfo)
                                IconButton(
                                  icon: Icon(Icons.edit, size: 18, color: Colors.grey[500]),
                                  onPressed: _editGroupDescription,
                                ),
                            ],
                          ),
                          Text(
                            _group.description?.isNotEmpty == true
                                ? _group.description!
                                : lang.t('groups.no_description'),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: _group.description?.isNotEmpty == true ? textColor : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Settings
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              _group.isMuted(_currentUserId ?? '') ? Icons.notifications_off : Icons.notifications,
                              color: textColor,
                            ),
                            title: Text(
                              lang.t('groups.mute_notifications'),
                              style: GoogleFonts.inter(color: textColor),
                            ),
                            trailing: Switch(
                              value: _group.isMuted(_currentUserId ?? ''),
                              onChanged: (_) => _toggleMute(),
                              activeThumbColor: const Color(0xFFBFAE01),
                            ),
                          ),
                          if (_isAdmin) ...[
                            const Divider(height: 1),
                            ListTile(
                              leading: Icon(Icons.admin_panel_settings, color: textColor),
                              title: Text(
                                lang.t('groups.only_admins_send'),
                                style: GoogleFonts.inter(color: textColor),
                              ),
                              trailing: Switch(
                                value: _group.onlyAdminsCanSend,
                                onChanged: (_) => _toggleOnlyAdminsCanSend(),
                                activeThumbColor: const Color(0xFFBFAE01),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Members
                    Container(
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${lang.t('groups.members')} (${_members.length})',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                if (_isAdmin)
                                  TextButton.icon(
                                    onPressed: _addMembers,
                                    icon: const Icon(Icons.add, size: 18),
                                    label: Text(lang.t('groups.add')),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFBFAE01),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (_loadingMembers)
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator(color: Color(0xFFBFAE01))),
                            )
                          else
                            ...List.generate(_members.length, (index) {
                              final member = _members[index];
                              final isMe = member.odId == _currentUserId;

                              return ListTile(
                                onTap: isMe ? null : () {
                                  navigateToUserProfile(
                                    context: context,
                                    userId: member.odId,
                                    userName: member.name,
                                    userAvatarUrl: member.avatarUrl ?? '',
                                    userBio: '',
                                  );
                                },
                                leading: CircleAvatar(
                                  backgroundImage: member.avatarUrl != null
                                      ? CachedNetworkImageProvider(member.avatarUrl!)
                                      : null,
                                  backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                                  child: member.avatarUrl == null
                                      ? Text(
                                          member.name[0].toUpperCase(),
                                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                        )
                                      : null,
                                ),
                                title: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        isMe ? '${member.name} (${lang.t('groups.you')})' : member.name,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w500,
                                          color: textColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (member.isAdmin) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFBFAE01),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          lang.t('groups.admin'),
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: _isAdmin && !isMe
                                    ? PopupMenuButton<String>(
                                        icon: Icon(Icons.more_vert, color: Colors.grey[500]),
                                        onSelected: (value) {
                                          if (value == 'toggle_admin') {
                                            _toggleAdmin(member);
                                          } else if (value == 'remove') {
                                            _removeMember(member);
                                          }
                                        },
                                        itemBuilder: (ctx) => [
                                          PopupMenuItem(
                                            value: 'toggle_admin',
                                            child: Text(
                                              member.isAdmin
                                                  ? lang.t('groups.remove_admin')
                                                  : lang.t('groups.make_admin'),
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'remove',
                                            child: Text(
                                              lang.t('groups.remove'),
                                              style: const TextStyle(color: Colors.red),
                                            ),
                                          ),
                                        ],
                                      )
                                    : (isMe
                                        ? IconButton(
                                            icon: Icon(Icons.exit_to_app, color: Colors.red[400]),
                                            onPressed: () => _removeMember(member),
                                          )
                                        : null),
                              );
                            }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Leave/Delete Group
                    if (_isAdmin)
                      ElevatedButton(
                        onPressed: _deleteGroup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          lang.t('groups.delete_group'),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: () {
                          final me = _members.firstWhere(
                            (m) => m.odId == _currentUserId,
                            orElse: () => GroupMember(
                              odId: _currentUserId ?? '',
                              name: '',
                              role: GroupRole.member,
                              joinedAt: DateTime.now(),
                            ),
                          );
                          _removeMember(me);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          lang.t('groups.leave_group'),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                        ),
                      ),
                    const SizedBox(height: 32),
                  ],
                ),
        );
      },
    );
  }
}
