import 'package:cloud_firestore/cloud_firestore.dart';

class StoryMusicModel {
  final String id;
  final String title;
  final String artist;
  final String audioUrl;
  final String? coverUrl;
  final int durationSec;
  final String? genre;
  final bool isActive;
  final DateTime createdAt;
  final String uploadedBy; // Admin user ID

  StoryMusicModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    this.coverUrl,
    required this.durationSec,
    this.genre,
    this.isActive = true,
    required this.createdAt,
    required this.uploadedBy,
  });

  factory StoryMusicModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return StoryMusicModel(
      id: doc.id,
      title: data['title']?.toString() ?? '',
      artist: data['artist']?.toString() ?? '',
      audioUrl: data['audioUrl']?.toString() ?? '',
      coverUrl: data['coverUrl']?.toString(),
      durationSec: (data['durationSec'] ?? 0).toInt(),
      genre: data['genre']?.toString(),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      uploadedBy: data['uploadedBy']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'artist': artist,
      'audioUrl': audioUrl,
      'coverUrl': coverUrl,
      'durationSec': durationSec,
      'genre': genre,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'uploadedBy': uploadedBy,
    };
  }

  StoryMusicModel copyWith({
    String? id,
    String? title,
    String? artist,
    String? audioUrl,
    String? coverUrl,
    int? durationSec,
    String? genre,
    bool? isActive,
    DateTime? createdAt,
    String? uploadedBy,
  }) {
    return StoryMusicModel(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      audioUrl: audioUrl ?? this.audioUrl,
      coverUrl: coverUrl ?? this.coverUrl,
      durationSec: durationSec ?? this.durationSec,
      genre: genre ?? this.genre,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      uploadedBy: uploadedBy ?? this.uploadedBy,
    );
  }

  String get formattedDuration {
    final minutes = durationSec ~/ 60;
    final seconds = durationSec % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
