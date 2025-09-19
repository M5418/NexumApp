import 'package:flutter/foundation.dart';

@immutable
class Podcast {
  final String id;
  final String title;
  final String author;
  final String coverUrl;
  final List<String> categories;
  final String description;
  final List<Episode> episodes;

  const Podcast({
    required this.id,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.categories,
    required this.description,
    required this.episodes,
  });
}

@immutable
class Episode {
  final String id;
  final String podcastId;
  final String title;
  final String author;
  final Duration duration;
  final String audioUrl;
  final String coverUrl;
  final DateTime publishedAt;
  final int plays;
  final bool isFavorite;

  const Episode({
    required this.id,
    required this.podcastId,
    required this.title,
    required this.author,
    required this.duration,
    required this.audioUrl,
    required this.coverUrl,
    required this.publishedAt,
    required this.plays,
    this.isFavorite = false,
  });
}

@immutable
class Playlist {
  final String id;
  final String title;
  final String coverUrl;
  final String description;
  final List<Episode> episodes;

  const Playlist({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.description,
    required this.episodes,
  });
}
