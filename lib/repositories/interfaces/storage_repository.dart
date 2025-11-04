import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

abstract class StorageRepository {
  // Upload file from bytes
  Future<String> uploadFile({
    required String path,
    required Uint8List bytes,
    String? contentType,
    Map<String, String>? metadata,
  });
  
  // Upload file from File
  Future<String> uploadFileFromPath({
    required String path,
    required File file,
    String? contentType,
    Map<String, String>? metadata,
  });
  
  // Get download URL
  Future<String> getDownloadUrl(String path);
  
  // Delete file
  Future<void> deleteFile(String path);
  
  // Delete multiple files
  Future<void> deleteFiles(List<String> paths);
  
  // List files in directory
  Future<List<StorageFile>> listFiles({
    required String directory,
    int? maxResults,
  });
  
  // Get file metadata
  Future<StorageMetadata?> getMetadata(String path);
  
  // Upload progress stream
  Stream<double> uploadProgress();
  
  // Generate unique filename
  String generateUniqueFileName({
    required String uid,
    required String extension,
    String? prefix,
  });
}

class StorageFile {
  final String path;
  final String name;
  final int sizeBytes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? downloadUrl;
  final Map<String, String>? metadata;
  
  StorageFile({
    required this.path,
    required this.name,
    required this.sizeBytes,
    this.createdAt,
    this.updatedAt,
    this.downloadUrl,
    this.metadata,
  });
}

class StorageMetadata {
  final String path;
  final int sizeBytes;
  final String? contentType;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, String>? customMetadata;
  
  StorageMetadata({
    required this.path,
    required this.sizeBytes,
    this.contentType,
    this.createdAt,
    this.updatedAt,
    this.customMetadata,
  });
}
