import 'package:cloud_firestore/cloud_firestore.dart';
import '../interfaces/support_repository.dart';

class FirebaseSupportRepository implements SupportRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<String> submitTicket({
    required String userId,
    required String userName,
    required String userEmail,
    required String subject,
    required String message,
    String? category,
    List<String>? attachmentUrls,
  }) async {
    final doc = _db.collection('support_tickets').doc();
    await doc.set({
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'subject': subject,
      'message': message,
      'category': category ?? 'general',
      'status': 'open',
      'adminResponse': null,
      'respondedAt': null,
      'attachmentUrls': attachmentUrls ?? [],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  @override
  Future<List<SupportTicket>> getUserTickets(String userId) async {
    final snapshot = await _db
        .collection('support_tickets')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map(_fromFirestore).toList();
  }

  @override
  Future<SupportTicket?> getTicket(String ticketId) async {
    final doc = await _db.collection('support_tickets').doc(ticketId).get();
    if (!doc.exists) return null;
    return _fromFirestore(doc);
  }

  SupportTicket _fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SupportTicket(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      subject: data['subject'] ?? '',
      message: data['message'] ?? '',
      category: data['category'] ?? 'general',
      status: data['status'] ?? 'open',
      createdAt: _toDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _toDateTime(data['updatedAt']) ?? DateTime.now(),
      adminResponse: data['adminResponse'],
      respondedAt: _toDateTime(data['respondedAt']),
      attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
    );
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
