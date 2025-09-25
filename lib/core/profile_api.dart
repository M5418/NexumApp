import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
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
    final url = await uploadFile(file);
    await update({'profile_photo_url': url});
    return url;
  }

  Future<String> uploadAndAttachCoverPhoto(File file) async {
    final url = await uploadFile(file);
    await update({'cover_photo_url': url});
    return url;
  }

  // Generic file upload (returns public URL) for mobile/desktop.
  // Reads the file as bytes and defers to uploadBytes (single upload path).
  Future<String> uploadFile(File file) async {
    final ext = _extensionOf(file.path);
    final bytes = await file.readAsBytes();
    return uploadBytes(bytes, ext: ext);
  }

  // Web-friendly upload using raw bytes. Avoids forbidden headers like Content-Length on web.
  Future<String> uploadBytes(Uint8List bytes, {required String ext}) async {
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

    // 2) Upload to S3 via presigned PUT
    final contentType = _contentTypeForExt(ext);
    final s3 = Dio();

    await s3.put(
      putUrl,
      // On web we pass raw bytes directly and DO NOT set Content-Length.
      data: kIsWeb ? bytes : Stream.fromIterable(bytes.map((b) => [b])),
      options: Options(
        headers: kIsWeb
            ? {
                'Content-Type': contentType,
              }
            : {
                'Content-Type': contentType,
                'Content-Length': bytes.length,
              },
      ),
    );

    // 3) Confirm upload (optional auditing) - non-blocking
    try {
      await _dio.post('/api/files/confirm', data: {'key': key, 'url': publicUrl});
    } catch (_) {
      // Ignore failures here; upload already succeeded.
    }

    return publicUrl;
  }

  String _extensionOf(String path) {
    final idx = path.lastIndexOf('.');
    if (idx == -1 || idx == path.length - 1) return 'bin';
    return path.substring(idx + 1).toLowerCase();
  }

  String _contentTypeForExt(String ext) {
    switch (ext.toLowerCase()) {
      // Images
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';

      // Video
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'mkv':
        return 'video/x-matroska';
      case 'avi':
        return 'video/x-msvideo';

      // Audio
      case 'm4a':
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';

      // Fallback
      default:
        return 'application/octet-stream';
    }
  }
}