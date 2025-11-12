abstract class ReportRepository {
  // Create a report
  Future<String> createReport({
    required String targetType, // 'post', 'story', 'user'
    required String targetId,
    required String cause,
    String? comment,
    required String reporterId,
  });

  // Get reports for a specific target
  Future<List<ReportModel>> getReportsForTarget({
    required String targetType,
    required String targetId,
  });

  // Get reports by a user
  Future<List<ReportModel>> getReportsByUser(String userId);

  // Admin: Get all reports
  Future<List<ReportModel>> getAllReports({
    String? targetType,
    String? status,
    int limit = 50,
  });

  // Admin: Update report status
  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    String? reviewedBy,
    DateTime? reviewedAt,
  });
}

class ReportModel {
  final String id;
  final String targetType; // 'post', 'story', 'user'
  final String targetId;
  final String cause;
  final String comment;
  final String reporterId;
  final String status; // 'pending', 'reviewed', 'dismissed', 'actioned'
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReportModel({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.cause,
    required this.comment,
    required this.reporterId,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });
}
