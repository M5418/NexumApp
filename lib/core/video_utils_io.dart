import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart';

Future<Uint8List?> generateVideoThumbnail(String path) async {
  try {
    final data = await VideoThumbnail.thumbnailData(
      video: path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 512,
      quality: 75,
    );
    return data;
  } catch (_) {
    return null;
  }
}
