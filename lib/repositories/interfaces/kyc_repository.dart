abstract class KycRepository {
  // Submit KYC request
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
  });

  // Get user's KYC status
  Future<KycModel?> getUserKyc(String userId);

  // Get current user's KYC
  Future<KycModel?> getMyKyc();

  // Admin: Update KYC status
  Future<void> updateKycStatus({
    required String kycId,
    required String status,
    String? reviewedBy,
    DateTime? reviewedAt,
  });

  // Admin: Get all KYC requests
  Future<List<KycModel>> getAllKycRequests({
    String? status,
    int limit = 50,
  });
}

class KycModel {
  final String id;
  final String userId;
  final String fullName;
  final String documentType;
  final String documentNumber;
  final String issueCountry;
  final String? expiryDate;
  final String countryOfResidence;
  final String address;
  final String cityOfBirth;
  final String? frontUrl;
  final String? backUrl;
  final String selfieUrl;
  final String status; // 'pending', 'approved', 'rejected'
  final bool isApproved;
  final bool isRejected;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  KycModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.documentType,
    required this.documentNumber,
    required this.issueCountry,
    this.expiryDate,
    required this.countryOfResidence,
    required this.address,
    required this.cityOfBirth,
    this.frontUrl,
    this.backUrl,
    required this.selfieUrl,
    required this.status,
    required this.isApproved,
    required this.isRejected,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });
}
