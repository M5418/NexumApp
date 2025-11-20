import 'dart:typed_data';

Future<Uint8List?> generateVideoThumbnail(String path) async {
  // Not supported on web; return null so callers can fallback.
  return null;
}
