import 'package:cloud_firestore/cloud_firestore.dart';
import '../interfaces/report_repository.dart';

class FirebaseReportRepository implements ReportRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<String> createReport({
    required String targetType,
    required String targetId,
    required String cause,
    String? comment,
    required String reporterId,
  }) async {
    final doc = _db.collection('reports').doc();
    await doc.set({
      'targetType': targetType,
      'targetId': targetId,
      'cause': cause,
      'comment': comment ?? '',
      'reporterId': reporterId,
      'status': 'pending',
      'reviewedBy': null,
      'reviewedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  @override
  Future<List<ReportModel>> getReportsForTarget({
    required String targetType,
    required String targetId,
  }) async {
    final snapshot = await _db
        .collection('reports')
        .where('targetType', isEqualTo: targetType)
        .where('targetId', isEqualTo: targetId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map(_fromFirestore).toList();
  }

  @override
  Future<List<ReportModel>> getReportsByUser(String userId) async {
    final snapshot = await _db
        .collection('reports')
        .where('reporterId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snapshot.docs.map(_fromFirestore).toList();
  }

  @override
  Future<List<ReportModel>> getAllReports({
    String? targetType,
    String? status,
    int limit = 50,
  }) async {
    Query<Map<String, dynamic>> query = _db.collection('reports')
        .orderBy('createdAt', descending: true)
        .limit(limit);
    
    if (targetType != null) {
      query = query.where('targetType', isEqualTo: targetType);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    
    final snapshot = await query.get();
    return snapshot.docs.map(_fromFirestore).toList();
  }

  @override
  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    String? reviewedBy,
    DateTime? reviewedAt,
  }) async {
    await _db.collection('reports').doc(reportId).update({
      'status': status,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  ReportModel _fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ReportModel(
      id: doc.id,
      targetType: data['targetType'] ?? '',
      targetId: data['targetId'] ?? '',
      cause: data['cause'] ?? '',
      comment: data['comment'] ?? '',
      reporterId: data['reporterId'] ?? '',
      status: data['status'] ?? 'pending',
      reviewedBy: data['reviewedBy'],
      reviewedAt: _toDateTime(data['reviewedAt']),
      createdAt: _toDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _toDateTime(data['updatedAt']) ?? DateTime.now(),
    );
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
