// lib/core/audio_recorder.dart
// Platform wrapper: exports the proper implementation per platform.
export 'audio_recorder_io.dart' if (dart.library.html) 'audio_recorder_web.dart';