import 'dart:io';
import 'package:dio/dio.dart';
import 'api_client.dart';

class FilesApi {
  final Dio _dio = ApiClient().dio;

  Future<Map<String, String>> uploadFile(File file) async {
    final ext = _extensionOf(file.path);

    // 1) presign
    final pres = await _dio.post(
      '/api/files/presign-upload',
      data: {'ext': ext},
    );
    final body = Map<String, dynamic>.from(pres.data);
    final data = Map<String, dynamic>.from(body['data'] ?? {});
    final putUrl = data['putUrl'] as String;
    final key = data['key'] as String;
    final readUrl = (data['readUrl'] ?? '').toString();
    final publicUrl = (data['publicUrl'] ?? '').toString();
    final bestUrl = readUrl.isNotEmpty ? readUrl : publicUrl;

    // 2) upload to S3 via presigned URL
    final bytes = await file.readAsBytes();
    final s3 = Dio();
    await s3.put(
      putUrl,
      data: Stream.fromIterable(bytes.map((b) => [b])),
      options: Options(
        headers: {
          'Content-Type': _contentTypeForExt(ext),
          'Content-Length': bytes.length,
        },
      ),
    );

    // 3) confirm (non-blocking)
    try {
      await _dio.post('/api/files/confirm', data: {'key': key, 'url': bestUrl});
    } catch (_) {}

    return {'key': key, 'url': bestUrl};
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

      // PDF
      case 'pdf':
        return 'application/pdf';

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

      default:
        return 'application/octet-stream';
    }
  }
}