import 'package:flutter/foundation.dart' show debugPrint;
import 'package:dio/dio.dart';
import 'api_client.dart';

class InvitationUser {
  final String name;
  final String username;
  final String? avatarUrl;

  InvitationUser({required this.name, required this.username, this.avatarUrl});

  factory InvitationUser.fromJson(Map<String, dynamic> json) {
    return InvitationUser(
      name: json['name'] ?? 'User',
      username: json['username'] ?? '@user',
      avatarUrl: json['avatarUrl'],
    );
  }
}

class Invitation {
  final String id;
  final String senderId;
  final String receiverId;
  final String invitationContent;
  final String status; // 'pending', 'accepted', 'refused'
  final DateTime createdAt;
  final DateTime? updatedAt;
  final InvitationUser sender;
  final InvitationUser receiver;
  final bool isSender;
  final bool isReceiver;

  Invitation({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.invitationContent,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    required this.sender,
    required this.receiver,
    required this.isSender,
    required this.isReceiver,
  });

  factory Invitation.fromJson(Map<String, dynamic> json) {
    return Invitation(
      id: json['id'] ?? '',
      senderId: json['sender_id'] ?? '',
      receiverId: json['receiver_id'] ?? '',
      invitationContent: json['invitation_content'] ?? '',
      status: json['status'] ?? 'pending',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      sender: InvitationUser.fromJson(json['sender'] ?? {}),
      receiver: InvitationUser.fromJson(json['receiver'] ?? {}),
      isSender: json['is_sender'] ?? false,
      isReceiver: json['is_receiver'] ?? false,
    );
  }
}

class InvitationStats {
  final int sent;
  final int received;
  final int accepted;
  final int refused;
  final int pending;

  InvitationStats({
    required this.sent,
    required this.received,
    required this.accepted,
    required this.refused,
    required this.pending,
  });

  factory InvitationStats.fromJson(Map<String, dynamic> json) {
    return InvitationStats(
      sent: json['sent'] ?? 0,
      received: json['received'] ?? 0,
      accepted: json['accepted'] ?? 0,
      refused: json['refused'] ?? 0,
      pending: json['pending'] ?? 0,
    );
  }
}

class InvitationsApi {
  final Dio _dio = ApiClient().dio;

  /// Get invitations for the current user
  /// [type] can be 'sent', 'received', or null for both
  Future<List<Invitation>> getInvitations({String? type}) async {
    try {
      debugPrint('🔍 InvitationsApi: Fetching invitations with type: $type');

      final queryParams = <String, dynamic>{};
      if (type != null) {
        queryParams['type'] = type;
      }

      final response = await _dio.get(
        '/api/invitations',
        queryParameters: queryParams,
      );

      debugPrint('🔍 InvitationsApi: Response status: ${response.statusCode}');
      debugPrint('🔍 InvitationsApi: Response data: ${response.data}');

      final data = Map<String, dynamic>.from(response.data);
      final invitationsData = data['data'] as Map<String, dynamic>? ?? {};
      final invitationsList =
          invitationsData['invitations'] as List<dynamic>? ?? [];

      final invitations = invitationsList
          .map((e) => Invitation.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      debugPrint('🔍 InvitationsApi: Parsed ${invitations.length} invitations');
      return invitations;
    } catch (e) {
      debugPrint('❌ InvitationsApi: Error fetching invitations');
      debugPrint('❌ Error details: $e');
      rethrow;
    }
  }

  /// Send a new invitation
  Future<Invitation> sendInvitation({
    required String receiverId,
    required String invitationContent,
  }) async {
    try {
      debugPrint('🔍 InvitationsApi: Sending invitation to $receiverId');

      final response = await _dio.post(
        '/api/invitations',
        data: {
          'receiver_id': receiverId,
          'invitation_content': invitationContent,
        },
      );

      debugPrint(
        '🔍 InvitationsApi: Send invitation response: ${response.data}',
      );

      final data = Map<String, dynamic>.from(response.data);
      final invitationData = data['data'] as Map<String, dynamic>? ?? {};
      final invitation =
          invitationData['invitation'] as Map<String, dynamic>? ?? {};

      return Invitation.fromJson(invitation);
    } catch (e) {
      debugPrint('❌ InvitationsApi: Error sending invitation: $e');
      rethrow;
    }
  }

  /// Update invitation status (accept or refuse)
  Future<void> updateInvitationStatus({
    required String invitationId,
    required String status, // 'accepted' or 'refused'
  }) async {
    try {
      debugPrint(
        '🔍 InvitationsApi: Updating invitation $invitationId to $status',
      );

      final response = await _dio.put(
        '/api/invitations/$invitationId',
        data: {'status': status},
      );

      debugPrint('🔍 InvitationsApi: Update status response: ${response.data}');
    } catch (e) {
      debugPrint('❌ InvitationsApi: Error updating invitation status: $e');
      rethrow;
    }
  }

  /// Accept an invitation and return the created/found conversation ID
  Future<String?> acceptInvitation(String invitationId) async {
    try {
      debugPrint('🔍 InvitationsApi: Accepting invitation $invitationId');

      final response = await _dio.put(
        '/api/invitations/$invitationId',
        data: {'status': 'accepted'},
      );

      debugPrint('🔍 InvitationsApi: Accept response: ${response.data}');

      final data = Map<String, dynamic>.from(response.data);
      final result = data['data'] as Map<String, dynamic>? ?? {};
      final conversationId = result['conversation_id']?.toString();
      return conversationId;
    } catch (e) {
      debugPrint(
        '❌ InvitationsApi: Error accepting invitation $invitationId: $e',
      );
      rethrow;
    }
  }

  /// Refuse an invitation
  Future<void> refuseInvitation(String invitationId) async {
    return updateInvitationStatus(
      invitationId: invitationId,
      status: 'refused',
    );
  }

  /// Delete an invitation (only sender can delete)
  Future<void> deleteInvitation(String invitationId) async {
    try {
      debugPrint('🔍 InvitationsApi: Deleting invitation $invitationId');

      final response = await _dio.delete('/api/invitations/$invitationId');

      debugPrint(
        '🔍 InvitationsApi: Delete invitation response: ${response.data}',
      );
    } catch (e) {
      debugPrint('❌ InvitationsApi: Error deleting invitation $invitationId');
      debugPrint('❌ Error details: $e');
      rethrow;
    }
  }

  /// Get invitation statistics
  Future<InvitationStats> getInvitationStats() async {
    try {
      debugPrint('🔍 InvitationsApi: Fetching invitation stats');

      final response = await _dio.get('/api/invitations/stats');

      debugPrint('🔍 InvitationsApi: Stats response: ${response.data}');

      final data = Map<String, dynamic>.from(response.data);
      final statsData = data['data'] as Map<String, dynamic>? ?? {};
      final stats = statsData['stats'] as Map<String, dynamic>? ?? {};

      return InvitationStats.fromJson(stats);
    } catch (e) {
      debugPrint('❌ InvitationsApi: Error fetching invitation stats');
      rethrow;
    }
  }

  /// Get sent invitations
  Future<List<Invitation>> getSentInvitations() async {
    return getInvitations(type: 'sent');
  }

  /// Get received invitations
  Future<List<Invitation>> getReceivedInvitations() async {
    return getInvitations(type: 'received');
  }

  /// Get pending invitations (received and pending)
  Future<List<Invitation>> getPendingInvitations() async {
    final received = await getReceivedInvitations();
    return received
        .where((invitation) => invitation.status == 'pending')
        .toList();
  }
}
