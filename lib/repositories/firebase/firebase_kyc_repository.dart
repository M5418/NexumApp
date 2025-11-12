import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../interfaces/kyc_repository.dart';

class FirebaseKycRepository implements KycRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  @override
  Future<String> submitKyc({
    required String userId,
    required String fullName,
    required String documentType,
    required String documentNumber,
    required String issueCountry,
    String? expiryDate,
    required String countryOfResidence,
    required String address,
    required String cityOfBirth,
    String? frontUrl,
    String? backUrl,
    required String selfieUrl,
  }) async {
    final doc = _db.collection('kyc_requests').doc();
    await doc.set({
      'userId': userId,
      'fullName': fullName,
      'documentType': documentType,
      'documentNumber': documentNumber,
      'issueCountry': issueCountry,
      'expiryDate': expiryDate,
      'countryOfResidence': countryOfResidence,
      'address': address,
      'cityOfBirth': cityOfBirth,
      'frontUrl': frontUrl,
      'backUrl': backUrl,
      'selfieUrl': selfieUrl,
      'status': 'pending',
      'isApproved': false,
      'isRejected': false,
      'reviewedBy': null,
      'reviewedAt': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  @override
  Future<KycModel?> getUserKyc(String userId) async {
    final query = await _db
        .collection('kyc_requests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    
    if (query.docs.isEmpty) return null;
    return _fromFirestore(query.docs.first);
  }

  @override
  Future<KycModel?> getMyKyc() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return getUserKyc(user.uid);
  }

  @override
  Future<void> updateKycStatus({
    required String kycId,
    required String status,
    String? reviewedBy,
    DateTime? reviewedAt,
  }) async {
    await _db.collection('kyc_requests').doc(kycId).update({
      'status': status,
      'isApproved': status == 'approved',
      'isRejected': status == 'rejected',
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<List<KycModel>> getAllKycRequests({
    String? status,
    int limit = 50,
  }) async {
    Query<Map<String, dynamic>> query = _db.collection('kyc_requests')
        .orderBy('createdAt', descending: true)
        .limit(limit);
    
    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }
    
    final snapshot = await query.get();
    return snapshot.docs.map(_fromFirestore).toList();
  }

  KycModel _fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return KycModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      fullName: data['fullName'] ?? '',
      documentType: data['documentType'] ?? '',
      documentNumber: data['documentNumber'] ?? '',
      issueCountry: data['issueCountry'] ?? '',
      expiryDate: data['expiryDate'],
      countryOfResidence: data['countryOfResidence'] ?? '',
      address: data['address'] ?? '',
      cityOfBirth: data['cityOfBirth'] ?? '',
      frontUrl: data['frontUrl'],
      backUrl: data['backUrl'],
      selfieUrl: data['selfieUrl'] ?? '',
      status: data['status'] ?? 'pending',
      isApproved: data['isApproved'] ?? false,
      isRejected: data['isRejected'] ?? false,
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
