// Web-compatible BookLite model (no Isar annotations)

class BookLite {
  String id = '';
  String title = '';
  String? author;
  String? description;
  String? coverUrl;
  String? coverThumbUrl;
  String? epubUrl;
  String? pdfUrl;
  String? audioUrl;
  String? category;
  String? language;
  bool isPublished = true;
  DateTime? createdAt;
  DateTime? updatedAt;
  DateTime localUpdatedAt = DateTime.now();
  String syncStatus = 'synced';

  BookLite();

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

    book.createdAt = _parseTimestamp(data['createdAt']);
    book.updatedAt = _parseTimestamp(data['updatedAt']);

    return book;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
