abstract class SupportRepository {
  // Submit a support ticket
  Future<String> submitTicket({
    required String userId,
    required String userName,
    required String userEmail,
    required String subject,
    required String message,
    String? category,
    List<String>? attachmentUrls,
  });

  // Get user's support tickets
  Future<List<SupportTicket>> getUserTickets(String userId);

  // Get single ticket details
  Future<SupportTicket?> getTicket(String ticketId);
}

class SupportTicket {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final String subject;
  final String message;
  final String category; // 'general', 'technical', 'billing', 'feature_request', 'bug_report'
  final String status; // 'open', 'in_progress', 'resolved', 'closed'
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? adminResponse;
  final DateTime? respondedAt;
  final List<String> attachmentUrls;

  SupportTicket({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.subject,
    required this.message,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.adminResponse,
    this.respondedAt,
    this.attachmentUrls = const [],
  });
}
