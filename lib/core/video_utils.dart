export 'video_utils_stub.dart'
    if (dart.library.html) 'video_utils_web.dart'
    if (dart.library.io) 'video_utils_io.dart';
