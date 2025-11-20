import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart' as fs;

class ProfileApi {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final fs.FirebaseStorage _storage = fs.FirebaseStorage.instance;

  Future<Map<String, dynamic>> me() async {
    final u = _auth.currentUser;
    if (u == null) return {'ok': false, 'error': 'unauthenticated'};
    final doc = await _db.collection('users').doc(u.uid).get();
    final data = _legacyFromFirestore(doc.data() ?? {});
    return {'ok': true, 'data': {'id': u.uid, 'email': u.email, ...data}};
  }

  Future<Map<String, dynamic>> getByUserId(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    final data = _legacyFromFirestore(doc.data() ?? {});
    return {'ok': true, 'data': {'id': userId, ...data}};
  }

  Future<Map<String, dynamic>> update(Map<String, dynamic> data) async {
    final u = _auth.currentUser;
    if (u == null) return {'ok': false, 'error': 'unauthenticated'};
    final updates = <String, dynamic>{};
    void setIf(String key, String newKey) {
      if (data.containsKey(key)) updates[newKey] = data[key];
    }
    setIf('first_name', 'firstName');
    setIf('last_name', 'lastName');
    setIf('bio', 'bio');
    setIf('profile_photo_url', 'avatarUrl');
    setIf('cover_photo_url', 'coverUrl');
    setIf('email', 'email');
    if (data.containsKey('username')) {
      final v = (data['username'] ?? '').toString();
      updates['username'] = v;
      updates['usernameLower'] = v.toLowerCase();
    }
    if (data.containsKey('interest_domains')) {
      updates['interestDomains'] = List<String>.from(
        (data['interest_domains'] as List?)?.map((e) => e.toString()) ?? const [],
      );
    }
    for (final k in ['show_reposts', 'show_suggested_posts', 'prioritize_interests']) {
      if (data.containsKey(k)) updates[k] = data[k];
    }
    updates['lastActive'] = FieldValue.serverTimestamp();
    await _db.collection('users').doc(u.uid).set(updates, SetOptions(merge: true));
    final fresh = await _db.collection('users').doc(u.uid).get();
    final d = _legacyFromFirestore(fresh.data() ?? {});
    return {'ok': true, 'data': {'id': u.uid, 'email': u.email, ...d}};
  }

  Future<String> uploadAndAttachProfilePhoto(File file) async {
    final ext = _extensionOf(file.path);
    final bytes = await file.readAsBytes();
    final url = await uploadBytes(bytes, ext: ext);
    await update({'profile_photo_url': url});
    return url;
  }

  Future<String> uploadAndAttachCoverPhoto(File file) async {
    final ext = _extensionOf(file.path);
    final bytes = await file.readAsBytes();
    final url = await uploadBytes(bytes, ext: ext);
    await update({'cover_photo_url': url});
    return url;
  }

  // Generic file upload
  Future<String> uploadFile(File file) async {
    final ext = _extensionOf(file.path);
    final bytes = await file.readAsBytes();
    return uploadBytes(bytes, ext: ext);
  }

  // Web-friendly upload using raw bytes (Firebase Storage)
  Future<String> uploadBytes(Uint8List bytes, {required String ext, String? contentType}) async {
    final u = _auth.currentUser;
    if (u == null) throw Exception('unauthenticated');
    String resolvedExt = _normalizeExt(ext);
    const allowed = {
      'jpg', 'jpeg', 'png', 'webp',
      'pdf', 'doc', 'docx', 'xls', 'xlsx',
      'mp4',
      'm4a', 'mp3', 'wav', 'aac', 'webm',
    };
    if (!allowed.contains(resolvedExt)) {
      final sniffed = _detectExtFromBytes(bytes);
      if (sniffed != null) resolvedExt = sniffed;
    }
    if (resolvedExt == 'jpeg') resolvedExt = 'jpg';
    if (!allowed.contains(resolvedExt)) resolvedExt = 'jpg';

    final ct = contentType ?? _contentTypeForExt(resolvedExt);
    final path = 'uploads/${u.uid}/profile/${DateTime.now().microsecondsSinceEpoch}.$resolvedExt';
    final ref = _storage.ref(path);
    await ref.putData(bytes, fs.SettableMetadata(contentType: ct));
    final url = await ref.getDownloadURL();
    return url;
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
        return 'video/webm';

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

  Map<String, dynamic> _legacyFromFirestore(Map<String, dynamic> d) {
    final out = Map<String, dynamic>.from(d);
    void mapKey(String from, String to) {
      if (d.containsKey(from)) out[to] = d[from];
    }
    mapKey('firstName', 'first_name');
    mapKey('lastName', 'last_name');
    mapKey('avatarUrl', 'profile_photo_url');
    mapKey('coverUrl', 'cover_photo_url');
    mapKey('interestDomains', 'interest_domains');
    mapKey('professionalExperiences', 'professional_experiences');
    return out;
  }
}