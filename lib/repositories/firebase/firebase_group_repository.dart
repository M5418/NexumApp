import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../../models/group_chat.dart';

class FirebaseGroupRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _groups => _db.collection('groups');

  String? get _currentUserId => _auth.currentUser?.uid;

  // ============================================
  // GROUP CRUD OPERATIONS
  // ============================================

  /// Create a new group
  Future<String> createGroup({
    required String name,
    String? description,
    String? avatarUrl,
    required List<String> memberIds,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    if (memberIds.length > GroupChat.maxMembers) {
      throw Exception('Group cannot have more than ${GroupChat.maxMembers} members');
    }

    // Ensure creator is in member list
    final allMembers = {...memberIds, uid}.toList();

    final now = DateTime.now();
    final groupData = {
      'name': name,
      'description': description,
      'avatarUrl': avatarUrl,
      'createdBy': uid,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'memberIds': allMembers,
      'adminIds': [uid], // Creator is admin
      'lastMessageText': null,
      'lastMessageType': null,
      'lastMessageAt': Timestamp.fromDate(now),
      'lastMessageSenderId': null,
      'lastMessageSenderName': null,
      'unreadCounts': {for (var id in allMembers) id: 0},
      'mutedBy': {},
      'onlyAdminsCanSend': false,
      'onlyAdminsCanEditInfo': true,
    };

    final docRef = await _groups.add(groupData);
    return docRef.id;
  }

  /// Get a group by ID
  Future<GroupChat?> getGroup(String groupId) async {
    final doc = await _groups.doc(groupId).get();
    if (!doc.exists) return null;
    return GroupChat.fromDoc(doc);
  }

  /// Get all groups for current user
  Future<List<GroupChat>> getMyGroups({int limit = 50}) async {
    final uid = _currentUserId;
    if (uid == null) return [];

    final query = await _groups
        .where('memberIds', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .limit(limit)
        .get();

    return query.docs.map((doc) => GroupChat.fromDoc(doc)).toList();
  }

  /// Get groups from cache (FastFeed optimization)
  Future<List<GroupChat>> getMyGroupsFromCache({int limit = 50}) async {
    final uid = _currentUserId;
    if (uid == null) return [];

    try {
      final query = await _groups
          .where('memberIds', arrayContains: uid)
          .orderBy('lastMessageAt', descending: true)
          .limit(limit)
          .get(const GetOptions(source: Source.cache));

      return query.docs.map((doc) => GroupChat.fromDoc(doc)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Stream groups for real-time updates
  Stream<List<GroupChat>> streamMyGroups({int limit = 50}) {
    final uid = _currentUserId;
    if (uid == null) return Stream.value([]);

    return _groups
        .where('memberIds', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => GroupChat.fromDoc(doc)).toList());
  }

  /// Update group info
  Future<void> updateGroup({
    required String groupId,
    String? name,
    String? description,
    String? avatarUrl,
    bool? onlyAdminsCanSend,
    bool? onlyAdminsCanEditInfo,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('Group not found');

    // Check if user can edit (admin or if onlyAdminsCanEditInfo is false)
    if (group.onlyAdminsCanEditInfo && !group.isAdmin(uid)) {
      throw Exception('Only admins can edit group info');
    }

    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;
    if (onlyAdminsCanSend != null) updates['onlyAdminsCanSend'] = onlyAdminsCanSend;
    if (onlyAdminsCanEditInfo != null) updates['onlyAdminsCanEditInfo'] = onlyAdminsCanEditInfo;

    await _groups.doc(groupId).update(updates);
  }

  /// Delete group (admin only)
  Future<void> deleteGroup(String groupId) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('Group not found');
    if (!group.isAdmin(uid)) throw Exception('Only admins can delete the group');

    // Delete all messages first
    final messages = await _groups.doc(groupId).collection('messages').get();
    final batch = _db.batch();
    for (final msg in messages.docs) {
      batch.delete(msg.reference);
    }
    await batch.commit();

    // Delete the group
    await _groups.doc(groupId).delete();
  }

  // ============================================
  // MEMBER MANAGEMENT
  // ============================================

  /// Add members to group
  Future<void> addMembers(String groupId, List<String> userIds) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('Group not found');
    if (!group.isAdmin(uid)) throw Exception('Only admins can add members');

    final newMemberCount = group.memberIds.length + userIds.length;
    if (newMemberCount > GroupChat.maxMembers) {
      throw Exception('Group cannot have more than ${GroupChat.maxMembers} members');
    }

    // Add new members and initialize their unread counts
    final unreadUpdates = <String, dynamic>{};
    for (final userId in userIds) {
      unreadUpdates['unreadCounts.$userId'] = 0;
    }

    await _groups.doc(groupId).update({
      'memberIds': FieldValue.arrayUnion(userIds),
      'updatedAt': FieldValue.serverTimestamp(),
      ...unreadUpdates,
    });
  }

  /// Remove member from group
  Future<void> removeMember(String groupId, String userId) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('Group not found');

    // Can remove if: admin OR removing self
    if (!group.isAdmin(uid) && uid != userId) {
      throw Exception('Only admins can remove members');
    }

    // Cannot remove the last admin
    if (group.isAdmin(userId) && group.adminIds.length == 1) {
      throw Exception('Cannot remove the last admin. Promote another admin first.');
    }

    await _groups.doc(groupId).update({
      'memberIds': FieldValue.arrayRemove([userId]),
      'adminIds': FieldValue.arrayRemove([userId]),
      'unreadCounts.$userId': FieldValue.delete(),
      'mutedBy.$userId': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Leave group
  Future<void> leaveGroup(String groupId) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    await removeMember(groupId, uid);
  }

  /// Promote member to admin
  Future<void> promoteToAdmin(String groupId, String userId) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('Group not found');
    if (!group.isAdmin(uid)) throw Exception('Only admins can promote members');
    if (!group.isMember(userId)) throw Exception('User is not a member');

    await _groups.doc(groupId).update({
      'adminIds': FieldValue.arrayUnion([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Demote admin to member
  Future<void> demoteFromAdmin(String groupId, String userId) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('Group not found');
    if (!group.isAdmin(uid)) throw Exception('Only admins can demote admins');

    // Cannot demote the last admin
    if (group.adminIds.length == 1) {
      throw Exception('Cannot demote the last admin');
    }

    await _groups.doc(groupId).update({
      'adminIds': FieldValue.arrayRemove([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get group members with details
  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    final group = await getGroup(groupId);
    if (group == null) return [];

    final members = <GroupMember>[];
    for (final memberId in group.memberIds) {
      final userDoc = await _db.collection('users').doc(memberId).get();
      final userData = userDoc.data() ?? {};

      String displayName = (userData['displayName'] ?? '').toString();
      if (displayName.isEmpty) {
        final fn = (userData['firstName'] ?? '').toString();
        final ln = (userData['lastName'] ?? '').toString();
        displayName = '$fn $ln'.trim();
        if (displayName.isEmpty) {
          displayName = (userData['username'] ?? userData['email'] ?? 'User').toString();
        }
      }

      members.add(GroupMember(
        odId: memberId,
        name: displayName,
        avatarUrl: userData['avatarUrl']?.toString(),
        role: group.isAdmin(memberId) ? GroupRole.admin : GroupRole.member,
        joinedAt: group.createdAt, // Simplified - could track individual join times
      ));
    }

    // Sort: admins first, then alphabetically
    members.sort((a, b) {
      if (a.isAdmin && !b.isAdmin) return -1;
      if (!a.isAdmin && b.isAdmin) return 1;
      return a.name.compareTo(b.name);
    });

    return members;
  }

  // ============================================
  // MUTE/UNMUTE
  // ============================================

  Future<void> muteGroup(String groupId) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    await _groups.doc(groupId).update({
      'mutedBy.$uid': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unmuteGroup(String groupId) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    await _groups.doc(groupId).update({
      'mutedBy.$uid': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================
  // MESSAGES
  // ============================================

  /// Send a message to group
  Future<String> sendMessage({
    required String groupId,
    required String content,
    required String type,
    List<Map<String, dynamic>> attachments = const [],
    String? replyToId,
    String? replyToSenderName,
    String? replyToContent,
    String? replyToType,
  }) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('Group not found');
    if (!group.isMember(uid)) throw Exception('You are not a member of this group');

    // Check if only admins can send
    if (group.onlyAdminsCanSend && !group.isAdmin(uid)) {
      throw Exception('Only admins can send messages in this group');
    }

    // Get sender info
    final userDoc = await _db.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? {};
    String senderName = (userData['displayName'] ?? '').toString();
    if (senderName.isEmpty) {
      final fn = (userData['firstName'] ?? '').toString();
      final ln = (userData['lastName'] ?? '').toString();
      senderName = '$fn $ln'.trim();
      if (senderName.isEmpty) senderName = 'User';
    }
    final senderAvatar = userData['avatarUrl']?.toString();

    final now = DateTime.now();
    final messageData = {
      'groupId': groupId,
      'senderId': uid,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'content': content,
      'type': type,
      'attachments': attachments,
      'createdAt': Timestamp.fromDate(now),
      'replyToId': replyToId,
      'replyToSenderName': replyToSenderName,
      'replyToContent': replyToContent,
      'replyToType': replyToType,
      'reactions': {},
      'readBy': [uid],
      'isDeleted': false,
      'deletedBy': null,
    };

    // Add message
    final msgRef = await _groups.doc(groupId).collection('messages').add(messageData);

    // Update group with last message info and increment unread for others
    final unreadUpdates = <String, dynamic>{};
    for (final memberId in group.memberIds) {
      if (memberId != uid) {
        unreadUpdates['unreadCounts.$memberId'] = FieldValue.increment(1);
      }
    }

    await _groups.doc(groupId).update({
      'lastMessageText': type == 'text' ? content : _getMessageTypeLabel(type),
      'lastMessageType': type,
      'lastMessageAt': Timestamp.fromDate(now),
      'lastMessageSenderId': uid,
      'lastMessageSenderName': senderName,
      'updatedAt': FieldValue.serverTimestamp(),
      ...unreadUpdates,
    });

    return msgRef.id;
  }

  String _getMessageTypeLabel(String type) {
    switch (type) {
      case 'image':
        return '📷 Photo';
      case 'video':
        return '🎥 Video';
      case 'voice':
        return '🎤 Voice message';
      case 'file':
        return '📎 File';
      default:
        return type;
    }
  }

  /// Get messages for a group
  Future<List<GroupMessage>> getMessages(String groupId, {int limit = 50}) async {
    final query = await _groups
        .doc(groupId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();

    return query.docs.map((doc) => GroupMessage.fromDoc(doc)).toList();
  }

  /// Get messages from cache (FastFeed)
  Future<List<GroupMessage>> getMessagesFromCache(String groupId, {int limit = 50}) async {
    try {
      final query = await _groups
          .doc(groupId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get(const GetOptions(source: Source.cache));

      return query.docs.map((doc) => GroupMessage.fromDoc(doc)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Stream messages for real-time updates
  Stream<List<GroupMessage>> streamMessages(String groupId, {int limit = 50}) {
    return _groups
        .doc(groupId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => GroupMessage.fromDoc(doc)).toList());
  }

  /// Mark messages as read
  Future<void> markAsRead(String groupId) async {
    final uid = _currentUserId;
    if (uid == null) return;

    // Reset unread count
    await _groups.doc(groupId).update({
      'unreadCounts.$uid': 0,
    });

    // Mark recent messages as read
    final messages = await _groups
        .doc(groupId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();

    final batch = _db.batch();
    for (final msg in messages.docs) {
      final readBy = List<String>.from(msg.data()['readBy'] ?? []);
      if (!readBy.contains(uid)) {
        batch.update(msg.reference, {
          'readBy': FieldValue.arrayUnion([uid]),
        });
      }
    }
    await batch.commit();
  }

  /// Add reaction to message
  Future<void> addReaction(String groupId, String messageId, String emoji) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    await _groups.doc(groupId).collection('messages').doc(messageId).update({
      'reactions.$uid': emoji,
    });
  }

  /// Remove reaction from message
  Future<void> removeReaction(String groupId, String messageId) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    await _groups.doc(groupId).collection('messages').doc(messageId).update({
      'reactions.$uid': FieldValue.delete(),
    });
  }

  /// Delete message (soft delete)
  Future<void> deleteMessage(String groupId, String messageId) async {
    final uid = _currentUserId;
    if (uid == null) throw Exception('Not authenticated');

    final group = await getGroup(groupId);
    if (group == null) throw Exception('Group not found');

    final msgDoc = await _groups.doc(groupId).collection('messages').doc(messageId).get();
    if (!msgDoc.exists) throw Exception('Message not found');

    final msgData = msgDoc.data() ?? {};
    final senderId = msgData['senderId'];

    // Can delete if: sender OR admin
    if (senderId != uid && !group.isAdmin(uid)) {
      throw Exception('You can only delete your own messages');
    }

    await _groups.doc(groupId).collection('messages').doc(messageId).update({
      'isDeleted': true,
      'deletedBy': uid,
      'content': 'This message was deleted',
      'attachments': [],
    });
  }
}
