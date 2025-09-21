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
    final publicUrl = data['publicUrl'] as String;

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

    // 3) confirm
    await _dio.post('/api/files/confirm', data: {'key': key, 'url': publicUrl});

    return {'key': key, 'url': publicUrl};
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
      case 'mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }
}
