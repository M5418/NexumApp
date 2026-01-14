import 'dart:typed_data';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:get_thumbnail_video/index.dart';

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
