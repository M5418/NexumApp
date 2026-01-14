import 'package:isar/isar.dart';
import '../utils/hash_utils.dart';

part 'book_lite.g.dart';

/// Lightweight book model for local Isar storage.
@collection
class BookLite {
  Id get isarId => fastHash(id);

  @Index(unique: true)
  late String id;

  late String title;
  String? author;
  String? authorId;
  String? description;
  String? coverUrl;
  String? coverThumbUrl;
  String? epubUrl;
  String? pdfUrl;
  String? audioUrl;

  String? category;
  String? language;

  bool isPublished = true;

  @Index()
  DateTime? createdAt;

  @Index()
  DateTime? updatedAt;

  @Index()
  late DateTime localUpdatedAt;

  String syncStatus = 'synced';

  BookLite();

  factory BookLite.fromFirestore(String docId, Map<String, dynamic> data) {
    final book = BookLite()
      ..id = docId
      ..title = data['title'] as String? ?? ''
      ..author = data['author'] as String?
      ..authorId = data['authorId'] as String?
      ..description = data['description'] as String?
      ..coverUrl = data['coverUrl'] as String?
      ..coverThumbUrl = data['coverThumbUrl'] as String?
      ..epubUrl = data['epubUrl'] as String?
      ..pdfUrl = data['pdfUrl'] as String?
      ..audioUrl = data['audioUrl'] as String?
      ..category = data['category'] as String?
      ..language = data['language'] as String?
      ..isPublished = data['isPublished'] != false
      ..createdAt = _parseTimestamp(data['createdAt'])
      ..updatedAt = _parseTimestamp(data['updatedAt'])
      ..localUpdatedAt = DateTime.now()
      ..syncStatus = 'synced';

    return book;
  }

  /// Create from a simple Map (for Hive/web storage)
  factory BookLite.fromMap(Map<String, dynamic> data) {
    final book = BookLite()
      ..id = data['id'] as String? ?? ''
      ..title = data['title'] as String? ?? ''
      ..author = data['author'] as String?
      ..description = data['description'] as String?
      ..coverUrl = data['coverUrl'] as String?
      ..coverThumbUrl = data['coverThumbUrl'] as String?
      ..epubUrl = data['epubUrl'] as String?
      ..pdfUrl = data['pdfUrl'] as String?
      ..audioUrl = data['audioUrl'] as String?
      ..category = data['category'] as String?
      ..language = data['language'] as String?
      ..isPublished = data['isPublished'] as bool? ?? true;

    book.createdAt = _parseMapTimestamp(data['createdAt']);
    book.updatedAt = _parseMapTimestamp(data['updatedAt']);

    return book;
  }

  static DateTime? _parseMapTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  Map<String, dynamic> toDisplayMap() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'description': description,
      'coverUrl': coverUrl,
      'coverThumbUrl': coverThumbUrl,
      'epubUrl': epubUrl,
      'pdfUrl': pdfUrl,
      'audioUrl': audioUrl,
      'category': category,
      'language': language,
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      final seconds = (value as dynamic).seconds as int?;
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
      }
    } catch (_) {}
    return null;
  }
}

