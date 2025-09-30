// File: lib/core/kyc_api.dart
// Lines: 1-130
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import 'api_client.dart';

class KycApi {
  final Dio _dio = ApiClient().dio;

  Future<Map<String, dynamic>> getMine() async {
    try {
      final res = await _dio.get('/api/kyc/me');
      return Map<String, dynamic>.from(res.data ?? {});
    } catch (e) {
      debugPrint('KycApi.getMine error: $e');
      return {'ok': false, 'error': 'network_error'};
    }
  }

  Future<Map<String, dynamic>> submit({
    String? fullName,
    required String documentType,
    required String documentNumber,
    String? issuePlace,
    String? issueDate,   // YYYY-MM-DD
    String? expiryDate,  // YYYY-MM-DD
    String? country,
    String? cityOfBirth,
    String? address,
    List<String>? uploadedFileNames,
    String? frontUrl,
    String? backUrl,
    String? selfieUrl,
  }) async {
    try {
      final payload = {
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
        'document_type': documentType,
        'document_number': documentNumber,
        if (issuePlace != null && issuePlace.isNotEmpty) 'issue_place': issuePlace,
        if (issueDate != null && issueDate.isNotEmpty) 'issue_date': issueDate,
        if (expiryDate != null && expiryDate.isNotEmpty) 'expiry_date': expiryDate,
        if (country != null && country.isNotEmpty) 'country': country,
        if (cityOfBirth != null && cityOfBirth.isNotEmpty) 'city_of_birth': cityOfBirth,
        if (address != null && address.isNotEmpty) 'address': address,
        if (uploadedFileNames != null && uploadedFileNames.isNotEmpty)
          'uploaded_file_names': uploadedFileNames,
        if (frontUrl != null && frontUrl.isNotEmpty) 'front_url': frontUrl,
        if (backUrl != null && backUrl.isNotEmpty) 'back_url': backUrl,
        if (selfieUrl != null && selfieUrl.isNotEmpty) 'selfie_url': selfieUrl,
      };

      final res = await _dio.post('/api/kyc', data: payload);
      return Map<String, dynamic>.from(res.data ?? {});
    } catch (e) {
      debugPrint('KycApi.submit error: $e');
      return {'ok': false, 'error': 'network_error'};
    }
  }
}