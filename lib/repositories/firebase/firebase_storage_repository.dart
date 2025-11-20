import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart' as fs;
import '../interfaces/storage_repository.dart';

class FirebaseStorageRepository implements StorageRepository {
  final fs.FirebaseStorage _storage = fs.FirebaseStorage.instanceFor(
    bucket: Firebase.app().options.storageBucket,
  );
  final StreamController<double> _progress = StreamController<double>.broadcast();

  @override
  Stream<double> uploadProgress() => _progress.stream;

  @override
  Future<String> uploadFile({
    required String path,
    required Uint8List bytes,
    String? contentType,
    Map<String, String>? metadata,
  }) async {
    final ref = _storage.ref(path);
    final task = ref.putData(
      bytes,
      fs.SettableMetadata(contentType: contentType, customMetadata: metadata),
    );
    task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) {
        _progress.add(s.bytesTransferred / s.totalBytes);
      }
    });
    await task;
    return await ref.getDownloadURL();
  }

  @override
  Future<String> uploadFileFromPath({
    required String path,
    required File file,
    String? contentType,
    Map<String, String>? metadata,
  }) async {
    final ref = _storage.ref(path);
    final task = ref.putFile(
      file,
      fs.SettableMetadata(contentType: contentType, customMetadata: metadata),
    );
    task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) {
        _progress.add(s.bytesTransferred / s.totalBytes);
      }
    });
    await task;
    return await ref.getDownloadURL();
  }

  @override
  Future<String> getDownloadUrl(String path) async {
    return await _storage.ref(path).getDownloadURL();
  }

  @override
  Future<void> deleteFile(String path) async {
    await _storage.ref(path).delete();
  }

  @override
  Future<void> deleteFiles(List<String> paths) async {
    final futures = paths.map((p) => _storage.ref(p).delete());
    await Future.wait(futures);
  }

  @override
  Future<List<StorageFile>> listFiles({required String directory, int? maxResults}) async {
    final result = await _storage.ref(directory).list(fs.ListOptions(maxResults: maxResults));
    final files = <StorageFile>[];
    for (final i in result.items) {
      final meta = await i.getMetadata();
      files.add(
        StorageFile(
          path: i.fullPath,
          name: i.name,
          sizeBytes: meta.size ?? 0,
          createdAt: meta.timeCreated,
          updatedAt: meta.updated,
          downloadUrl: null,
          metadata: meta.customMetadata,
        ),
      );
    }
    return files;
  }

  @override
  Future<StorageMetadata?> getMetadata(String path) async {
    final meta = await _storage.ref(path).getMetadata();
    return StorageMetadata(
      path: path,
      sizeBytes: meta.size ?? 0,
      contentType: meta.contentType,
      createdAt: meta.timeCreated,
      updatedAt: meta.updated,
      customMetadata: meta.customMetadata,
    );
  }

  @override
  String generateUniqueFileName({required String uid, required String extension, String? prefix}) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    final rand = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final r = List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
    final base = prefix != null && prefix.isNotEmpty ? '$prefix-' : '';
    // Enforce uploads/{uid}/... to satisfy storage.rules
    return 'uploads/$uid/$base$ts-$r.$extension';
  }
}
