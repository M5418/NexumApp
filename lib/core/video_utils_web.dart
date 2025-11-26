// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

/// Creates a blob URL from video bytes for web video playback
String createVideoBlobUrl(Uint8List bytes, String mimeType) {
  final blob = html.Blob([bytes], mimeType);
  return html.Url.createObjectUrlFromBlob(blob);
}

/// Revokes a blob URL to free memory
void revokeBlobUrl(String url) {
  html.Url.revokeObjectUrl(url);
}
