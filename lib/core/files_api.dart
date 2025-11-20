import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:firebase_storage/firebase_storage.dart' as fs;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FilesApi {
  fs.FirebaseStorage get _storage => fs.FirebaseStorage.instanceFor(
        bucket: Firebase.app().options.storageBucket,
      );

  Future<Map<String, String>> uploadFile(File file) async {
    final ext = _extensionOf(file.path);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    // 1) Generate unique file name with user ID
    final rand = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
    final key = 'uploads/$uid/${DateTime.now().microsecondsSinceEpoch}-$r.$ext';

    // 2) Upload to Firebase Storage
    final ref = _storage.ref(key);
    await ref.putFile(
      file,
      fs.SettableMetadata(contentType: _contentTypeForExt(ext)),
    );
    final bestUrl = await ref.getDownloadURL();

    return {'key': key, 'url': bestUrl};
  }

  // Web-friendly: upload raw bytes (e.g., from FilePicker on web)
  Future<Map<String, String>> uploadBytes(Uint8List bytes, {required String ext}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    if (uid == null) {
      throw Exception('User not authenticated');
    }

    // 1) Generate unique file name with user ID
    final rand = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
    final key = 'uploads/$uid/${DateTime.now().microsecondsSinceEpoch}-$r.$ext';

    // 2) Upload bytes
    final ref = _storage.ref(key);
    await ref.putData(
      bytes,
      fs.SettableMetadata(contentType: _contentTypeForExt(ext)),
    );
    final bestUrl = await ref.getDownloadURL();

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