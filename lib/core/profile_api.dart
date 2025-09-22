import 'dart:io';
import 'package:dio/dio.dart';
import 'api_client.dart';

class ProfileApi {
  final _dio = ApiClient().dio;

  Future<Map<String, dynamic>> me() async {
    final res = await _dio.get('/api/profile/me');
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> update(Map<String, dynamic> data) async {
    final res = await _dio.patch('/api/profile', data: data);
    return Map<String, dynamic>.from(res.data);
  }

  Future<String> uploadAndAttachProfilePhoto(File file) async {
    final url = await _uploadToS3(file);
    await update({'profile_photo_url': url});
    return url;
  }

  Future<String> uploadAndAttachCoverPhoto(File file) async {
    final url = await _uploadToS3(file);
    await update({'cover_photo_url': url});
    return url;
  }

  // Generic file upload (returns public URL)
  Future<String> uploadFile(File file) async {
    return _uploadToS3(file);
  }

  Future<String> _uploadToS3(File file) async {
    final ext = _extensionOf(file.path);
    final contentType = _contentTypeForExt(ext);

    // 1) Presign
    final pres = await _dio.post(
      '/api/files/presign-upload',
      data: {'ext': ext},
    );
    final body = Map<String, dynamic>.from(pres.data);
    final data = Map<String, dynamic>.from(body['data'] ?? {});
    final putUrl = data['putUrl'] as String;
    final key = data['key'] as String;
    final publicUrl = data['publicUrl'] as String;

    // 2) Upload to S3 via presigned PUT using a clean Dio (no auth headers)
    final bytes = await file.readAsBytes();
    final s3 = Dio();
    await s3.put(
      putUrl,
      data: Stream.fromIterable(bytes.map((b) => [b])),
      options: Options(
        headers: {'Content-Type': contentType, 'Content-Length': bytes.length},
      ),
    );

    // 3) Confirm upload (optional for audit)
    await _dio.post('/api/files/confirm', data: {'key': key, 'url': publicUrl});

    return publicUrl;
  }

  String _extensionOf(String path) {
    final idx = path.lastIndexOf('.');
    if (idx == -1 || idx == path.length - 1) return 'bin';
    return path.substring(idx + 1).toLowerCase();
  }

  String _contentTypeForExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'm4a':
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      default:
        return 'application/octet-stream';
    }
  }
}
