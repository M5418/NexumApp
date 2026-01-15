import 'package:flutter_test/flutter_test.dart';

/// Tests for Group Chat feature
/// Covers: group management, member roles, message threading, mentions
void main() {
  group('Group Chat Model', () {
    test('should map group conversation to UI', () {
      final group = _MockGroupConversation(
        id: 'group1',
        name: 'Flutter Devs',
        memberIds: ['user1', 'user2', 'user3'],
        adminIds: ['user1'],
        createdAt: DateTime(2024, 1, 15),
      );
      
      final uiGroup = _mapGroupToUI(group);
      
      expect(uiGroup['name'], 'Flutter Devs');
      expect(uiGroup['memberCount'], 3);
    });

    test('should include group avatar', () {
      final group = _MockGroupConversation(
        id: 'group1',
        name: 'Team',
        avatarUrl: 'https://example.com/group.jpg',
        memberIds: ['user1', 'user2'],
        adminIds: ['user1'],
        createdAt: DateTime.now(),
      );
      
      final uiGroup = _mapGroupToUI(group);
      expect(uiGroup['avatarUrl'], isNotNull);
    });
  });

  group('Group Members', () {
    test('should identify admin', () {
      final group = _MockGroupConversation(
        id: 'group1',
        name: 'Team',
        memberIds: ['user1', 'user2', 'user3'],
        adminIds: ['user1'],
        createdAt: DateTime.now(),
      );
      
      expect(group.isAdmin('user1'), isTrue);
      expect(group.isAdmin('user2'), isFalse);
    });

    test('should check membership', () {
      final group = _MockGroupConversation(
        id: 'group1',
        name: 'Team',
        memberIds: ['user1', 'user2'],
        adminIds: ['user1'],
        createdAt: DateTime.now(),
      );
      
      expect(group.isMember('user1'), isTrue);
      expect(group.isMember('user3'), isFalse);
    });

    test('should add member', () {
      final group = _MockGroupConversation(
        id: 'group1',
        name: 'Team',
        memberIds: ['user1', 'user2'],
        adminIds: ['user1'],
        createdAt: DateTime.now(),
      );
      
      final updated = group.addMember('user3');
      expect(updated.memberIds.length, 3);
      expect(updated.isMember('user3'), isTrue);
    });

    test('should remove member', () {
      final group = _MockGroupConversation(
        id: 'group1',
        name: 'Team',
        memberIds: ['user1', 'user2', 'user3'],
        adminIds: ['user1'],
        createdAt: DateTime.now(),
      );
      
      final updated = group.removeMember('user3');
      expect(updated.memberIds.length, 2);
      expect(updated.isMember('user3'), isFalse);
    });
  });

  group('Group Messages Cache', () {
    test('should cache group messages', () {
      final cache = _MockGroupMessagesCache();
      cache.putMessages('group1', [
        _createGroupMessage('m1', 'group1'),
        _createGroupMessage('m2', 'group1'),
      ]);
      
      final messages = cache.getMessagesSync('group1', limit: 50);
      expect(messages.length, 2);
    });

    test('should show sender info for each message', () {
      final msg = _createGroupMessage('m1', 'group1', 
        senderId: 'user2',
        senderName: 'Jane',
      );
      
      expect(msg.senderName, 'Jane');
    });
  });

  group('Mentions', () {
    test('should detect @mentions in text', () {
      final mentions = _extractMentions('Hello @john and @jane!');
      expect(mentions, ['john', 'jane']);
    });

    test('should return empty for no mentions', () {
      final mentions = _extractMentions('Hello everyone!');
      expect(mentions, isEmpty);
    });

    test('should filter messages mentioning user', () {
      final cache = _MockGroupMessagesCache();
      cache.putMessages('group1', [
        _createGroupMessage('m1', 'group1', text: 'Hello @john'),
        _createGroupMessage('m2', 'group1', text: 'General message'),
        _createGroupMessage('m3', 'group1', text: '@john check this'),
      ]);
      
      final mentioning = cache.getMessagesMentioning('group1', 'john');
      expect(mentioning.length, 2);
    });
  });

  group('Admin Actions', () {
    test('should allow admin to change group name', () {
      final group = _MockGroupConversation(
        id: 'group1',
        name: 'Old Name',
        memberIds: ['user1', 'user2'],
        adminIds: ['user1'],
        createdAt: DateTime.now(),
      );
      
      final canEdit = group.canEditSettings('user1');
      expect(canEdit, isTrue);
    });

    test('should not allow non-admin to change settings', () {
      final group = _MockGroupConversation(
        id: 'group1',
        name: 'Team',
        memberIds: ['user1', 'user2'],
        adminIds: ['user1'],
        createdAt: DateTime.now(),
      );
      
      final canEdit = group.canEditSettings('user2');
      expect(canEdit, isFalse);
    });

    test('should allow admin to promote member', () {
      final group = _MockGroupConversation(
        id: 'group1',
        name: 'Team',
        memberIds: ['user1', 'user2'],
        adminIds: ['user1'],
        createdAt: DateTime.now(),
      );
      
      final updated = group.promoteToAdmin('user2');
      expect(updated.isAdmin('user2'), isTrue);
    });
  });

  group('Group Creation', () {
    test('should validate group name', () {
      expect(_isValidGroupName('Flutter Team'), isTrue);
      expect(_isValidGroupName(''), isFalse);
      expect(_isValidGroupName('AB'), isFalse); // Too short
    });

    test('should require at least 2 members', () {
      final result = _validateGroupCreation(
        name: 'Team',
        memberIds: ['user1'],
      );
      expect(result.isValid, isFalse);
    });

    test('should create group with creator as admin', () {
      final group = _createGroup(
        name: 'New Team',
        creatorId: 'user1',
        memberIds: ['user1', 'user2', 'user3'],
      );
      
      expect(group.isAdmin('user1'), isTrue);
      expect(group.memberIds.length, 3);
    });
  });

  group('Leave Group', () {
    test('should allow member to leave', () {
      final group = _MockGroupConversation(
        id: 'group1',
        name: 'Team',
        memberIds: ['user1', 'user2', 'user3'],
        adminIds: ['user1'],
        createdAt: DateTime.now(),
      );
      
      final updated = group.removeMember('user3');
      expect(updated.isMember('user3'), isFalse);
    });

    test('should transfer admin if last admin leaves', () {
      final group = _MockGroupConversation(
        id: 'group1',
        name: 'Team',
        memberIds: ['user1', 'user2'],
        adminIds: ['user1'],
        createdAt: DateTime.now(),
      );
      
      final updated = group.handleAdminLeave('user1');
      expect(updated.adminIds.contains('user2'), isTrue);
    });
  });
}

// Helper functions

Map<String, dynamic> _mapGroupToUI(_MockGroupConversation group) {
  return {
    'id': group.id,
    'name': group.name,
    'avatarUrl': group.avatarUrl,
    'memberCount': group.memberIds.length,
    'isAdmin': group.adminIds.isNotEmpty,
  };
}

List<String> _extractMentions(String text) {
  final regex = RegExp(r'@(\w+)');
  return regex.allMatches(text).map((m) => m.group(1)!).toList();
}

bool _isValidGroupName(String name) {
  return name.isNotEmpty && name.length >= 3;
}

_ValidationResult _validateGroupCreation({
  required String name,
  required List<String> memberIds,
}) {
  if (!_isValidGroupName(name)) {
    return _ValidationResult(isValid: false, error: 'Invalid group name');
  }
  if (memberIds.length < 2) {
    return _ValidationResult(isValid: false, error: 'Need at least 2 members');
  }
  return _ValidationResult(isValid: true);
}

_MockGroupConversation _createGroup({
  required String name,
  required String creatorId,
  required List<String> memberIds,
}) {
  return _MockGroupConversation(
    id: 'group_${DateTime.now().millisecondsSinceEpoch}',
    name: name,
    memberIds: memberIds,
    adminIds: [creatorId],
    createdAt: DateTime.now(),
  );
}

_MockGroupMessage _createGroupMessage(
  String id,
  String groupId, {
  String senderId = 'user1',
  String senderName = 'Test User',
  String text = 'Test message',
}) {
  return _MockGroupMessage(
    id: id,
    groupId: groupId,
    senderId: senderId,
    senderName: senderName,
    text: text,
    createdAt: DateTime.now(),
  );
}

// Mock classes

class _MockGroupConversation {
  final String id;
  final String name;
  final String? avatarUrl;
  final List<String> memberIds;
  final List<String> adminIds;
  final DateTime createdAt;

  _MockGroupConversation({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.memberIds,
    required this.adminIds,
    required this.createdAt,
  });

  bool isAdmin(String userId) => adminIds.contains(userId);
  bool isMember(String userId) => memberIds.contains(userId);
  bool canEditSettings(String userId) => isAdmin(userId);

  _MockGroupConversation addMember(String userId) {
    return _MockGroupConversation(
      id: id,
      name: name,
      avatarUrl: avatarUrl,
      memberIds: [...memberIds, userId],
      adminIds: adminIds,
      createdAt: createdAt,
    );
  }

  _MockGroupConversation removeMember(String userId) {
    return _MockGroupConversation(
      id: id,
      name: name,
      avatarUrl: avatarUrl,
      memberIds: memberIds.where((m) => m != userId).toList(),
      adminIds: adminIds.where((a) => a != userId).toList(),
      createdAt: createdAt,
    );
  }

  _MockGroupConversation promoteToAdmin(String userId) {
    if (!isMember(userId)) return this;
    return _MockGroupConversation(
      id: id,
      name: name,
      avatarUrl: avatarUrl,
      memberIds: memberIds,
      adminIds: [...adminIds, userId],
      createdAt: createdAt,
    );
  }

  _MockGroupConversation handleAdminLeave(String userId) {
    final newAdmins = adminIds.where((a) => a != userId).toList();
    final newMembers = memberIds.where((m) => m != userId).toList();
    
    // Transfer admin to first remaining member if no admins left
    if (newAdmins.isEmpty && newMembers.isNotEmpty) {
      newAdmins.add(newMembers.first);
    }
    
    return _MockGroupConversation(
      id: id,
      name: name,
      avatarUrl: avatarUrl,
      memberIds: newMembers,
      adminIds: newAdmins,
      createdAt: createdAt,
    );
  }
}

class _MockGroupMessage {
  final String id;
  final String groupId;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime createdAt;

  _MockGroupMessage({
    required this.id,
    required this.groupId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });
}

class _MockGroupMessagesCache {
  final Map<String, List<_MockGroupMessage>> _messages = {};

  void putMessages(String groupId, List<_MockGroupMessage> messages) {
    _messages.putIfAbsent(groupId, () => []);
    _messages[groupId]!.addAll(messages);
  }

  List<_MockGroupMessage> getMessagesSync(String groupId, {required int limit}) {
    return _messages[groupId]?.take(limit).toList() ?? [];
  }

  List<_MockGroupMessage> getMessagesMentioning(String groupId, String username) {
    final msgs = _messages[groupId] ?? [];
    return msgs.where((m) => m.text.contains('@$username')).toList();
  }
}

class _ValidationResult {
  final bool isValid;
  final String? error;

  _ValidationResult({required this.isValid, this.error});
}
