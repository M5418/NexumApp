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
  Future<Map<String, dynamic>> getByUserId(String userId) async {
    final res = await _dio.get('/api/profile/$userId');
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

  // Generic file upload
  Future<String> uploadFile(File file) async {
    final ext = _extensionOf(file.path);
    final bytes = await file.readAsBytes();
    return uploadBytes(bytes, ext: ext);
  }

  // Web-friendly upload using raw bytes
  Future<String> uploadBytes(Uint8List bytes, {required String ext}) async {
    String resolvedExt = _normalizeExt(ext);
    const allowed = {
      // images
      'jpg', 'jpeg', 'png', 'webp',
      // docs
      'pdf', 'doc', 'docx', 'xls', 'xlsx',
      // video
      'mp4',
      // audio
      'm4a', 'mp3', 'wav', 'aac', 'webm',
    };

    if (!allowed.contains(resolvedExt)) {
      final sniffed = _detectExtFromBytes(bytes);
      if (sniffed != null) {
        resolvedExt = sniffed;
      }
    }
    if (resolvedExt == 'jpeg') resolvedExt = 'jpg';
    if (!allowed.contains(resolvedExt)) {
      // safest default
      resolvedExt = 'jpg';
    }

    // 1) Presign
    final pres = await _dio.post('/api/files/presign-upload', data: {'ext': resolvedExt});
    final body = Map<String, dynamic>.from(pres.data);
    final data = Map<String, dynamic>.from(body['data'] ?? {});
    final putUrl = data['putUrl'] as String;
    final key = data['key'] as String;
    final readUrl = (data['readUrl'] ?? '').toString();
    final publicUrl = (data['publicUrl'] ?? '').toString();
    final bestUrl = readUrl.isNotEmpty ? readUrl : publicUrl;

    // 2) Upload to S3
    final contentType = _contentTypeForExt(resolvedExt);
    final s3 = Dio();
    await s3.put(
      putUrl,
      data: kIsWeb ? bytes : Stream.fromIterable(bytes.map((b) => [b])),
      options: Options(
        headers: kIsWeb
            ? {'Content-Type': contentType}
            : {'Content-Type': contentType, 'Content-Length': bytes.length},
      ),
    );

    // 3) Confirm (best-effort)
    try {
      await _dio.post('/api/files/confirm', data: {'key': key, 'url': bestUrl});
    } catch (_) {}

    return bestUrl;
  }

  String? _detectExtFromBytes(Uint8List b) {
    // PNG
    if (b.length >= 8 &&
        b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47 &&
        b[4] == 0x0D && b[5] == 0x0A && b[6] == 0x1A && b[7] == 0x0A) {
      return 'png';
    }
    // JPEG
    if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xD8) return 'jpg';
    // WEBP
    if (b.length >= 12 &&
        b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 &&
        b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) {
      return 'webp';
    }
    // MP4/QuickTime
    if (b.length >= 12 && b[4] == 0x66 && b[5] == 0x74 && b[6] == 0x79 && b[7] == 0x70) {
      return 'mp4';
    }
    // WebM (EBML)
    if (b.length >= 4 && b[0] == 0x1A && b[1] == 0x45 && b[2] == 0xDF && b[3] == 0xA3) {
      return 'webm';
    }
    return null;
  }

  String _extensionOf(String path) {
    final idx = path.lastIndexOf('.');
    if (idx == -1 || idx == path.length - 1) return 'bin';
    return path.substring(idx + 1).toLowerCase();
  }

  String _normalizeExt(String ext) => (ext.isEmpty ? 'bin' : ext.toLowerCase());

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

      // Audio
      case 'm4a':
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'webm':
        return 'audio/webm';

      // Docs
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

      default:
        return 'application/octet-stream';
    }
  }
}