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
  // Also auto-detects the right extension/Content-Type from bytes when needed
  // to prevent browser decode errors.
  Future<String> uploadBytes(Uint8List bytes, {required String ext}) async {
    // Normalize/auto-detect extension for correctness
    String resolvedExt = _normalizeExt(ext);
    const allowed = {'jpg', 'jpeg', 'png', 'webp', 'pdf', 'mp4'};

    if (!allowed.contains(resolvedExt)) {
      final sniffed = _detectExtFromBytes(bytes);
      if (sniffed != null) {
        resolvedExt = sniffed;
      }
    }
    // Map jpeg -> jpg to keep consistent key/content-type
    if (resolvedExt == 'jpeg') resolvedExt = 'jpg';
    // Final fallback to jpg for unknown image blobs
    if (!allowed.contains(resolvedExt)) {
      resolvedExt = 'jpg';
    }

    // 1) Presign
    final pres = await _dio.post(
      '/api/files/presign-upload',
      data: {'ext': resolvedExt},
    );
    final body = Map<String, dynamic>.from(pres.data);
    final data = Map<String, dynamic>.from(body['data'] ?? {});
    final putUrl = data['putUrl'] as String;
    final key = data['key'] as String;
    final publicUrl = data['publicUrl'] as String;

    // 2) Upload to S3 via presigned PUT
    final contentType = _contentTypeForExt(resolvedExt);
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

  // Best-effort detection of common image/video types used by the app.
  String? _detectExtFromBytes(Uint8List b) {
    if (b.length >= 8 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47 &&
        b[4] == 0x0D &&
        b[5] == 0x0A &&
        b[6] == 0x1A &&
        b[7] == 0x0A) {
      return 'png';
    }
    if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xD8) {
      return 'jpg'; // jpeg
    }
    if (b.length >= 12 &&
        b[0] == 0x52 && // R
        b[1] == 0x49 && // I
        b[2] == 0x46 && // F
        b[3] == 0x46 && // F
        b[8] == 0x57 && // W
        b[9] == 0x45 && // E
        b[10] == 0x42 && // B
        b[11] == 0x50) {
      return 'webp';
    }
    // MP4/QuickTime: 'ftyp' at bytes 4-7 in ISO Base Media File Format
    if (b.length >= 12 &&
        b[4] == 0x66 &&
        b[5] == 0x74 &&
        b[6] == 0x79 &&
        b[7] == 0x70) {
      return 'mp4';
    }
    // WebM: EBML header 1A 45 DF A3 (we don't upload webm by default, map to mp4 if needed)
    if (b.length >= 4 &&
        b[0] == 0x1A &&
        b[1] == 0x45 &&
        b[2] == 0xDF &&
        b[3] == 0xA3) {
      return 'mp4';
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

      // Docs (supported by files route, not used for chat media here)
      case 'pdf':
        return 'application/pdf';

      // Fallback
      default:
        return 'application/octet-stream';
    }
  }
}