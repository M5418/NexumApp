import 'package:intl/intl.dart';
import '../data/interest_domains.dart';
import 'podcast_models.dart';

class PodcastSampleData {
  static final List<Podcast> topPodcasts = [
    Podcast(
      id: 'p1',
      title: 'Business Builders',
      author: 'James Rowe',
      coverUrl:
          'https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=600',
      categories: const ['Business & Finance'],
      description:
          'Interviews and stories from founders, operators, and investors.',
      episodes: [
        Episode(
          id: 'e1',
          podcastId: 'p1',
          title: 'We Can Do Hard Things',
          author: 'James Rowe',
          duration: const Duration(minutes: 38, seconds: 12),
          audioUrl:
              'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
          coverUrl:
              'https://images.unsplash.com/photo-1544717305-996b815c338c?w=800',
          publishedAt: DateTime.now().subtract(const Duration(days: 3)),
          plays: 18342,
          isFavorite: true,
        ),
        Episode(
          id: 'e2',
          podcastId: 'p1',
          title: 'Raising Seed with Purpose',
          author: 'James Rowe',
          duration: const Duration(minutes: 42, seconds: 6),
          audioUrl:
              'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-14.mp3',
          coverUrl:
              'https://images.unsplash.com/photo-1551836022-d5d88e9218df?w=800',
          publishedAt: DateTime.now().subtract(const Duration(days: 10)),
          plays: 22410,
        ),
      ],
    ),
    Podcast(
      id: 'p2',
      title: 'The Product Mind',
      author: 'Luca Holland',
      coverUrl:
          'https://images.unsplash.com/photo-1544006659-f0b21884ce1d?w=600',
      categories: const ['Science & Tech', 'Business & Finance'],
      description: 'Deep-dives into product strategy, growth, and UX.',
      episodes: [
        Episode(
          id: 'e3',
          podcastId: 'p2',
          title: 'Crafting Roadmaps',
          author: 'Luca Holland',
          duration: const Duration(minutes: 29, seconds: 45),
          audioUrl:
              'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
          coverUrl:
              'https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=800',
          publishedAt: DateTime.now().subtract(const Duration(days: 1)),
          plays: 12980,
        ),
        Episode(
          id: 'e4',
          podcastId: 'p2',
          title: 'North Star Metrics',
          author: 'Luca Holland',
          duration: const Duration(minutes: 31, seconds: 11),
          audioUrl:
              'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3',
          coverUrl:
              'https://images.unsplash.com/photo-1494790108755-2616b612b47c?w=800',
          publishedAt: DateTime.now().subtract(const Duration(days: 7)),
          plays: 9800,
        ),
      ],
    ),
    Podcast(
      id: 'p3',
      title: 'Education Unboxed',
      author: 'Maya Roberts',
      coverUrl:
          'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=600',
      categories: const ['Education & Languages'],
      description: 'Learning science, languages, and the future of education.',
      episodes: [
        Episode(
          id: 'e5',
          podcastId: 'p3',
          title: 'Learning How to Learn',
          author: 'Maya Roberts',
          duration: const Duration(minutes: 35, seconds: 0),
          audioUrl:
              'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-4.mp3',
          coverUrl:
              'https://images.unsplash.com/photo-1523580846011-d3a5bc25702b?w=800',
          publishedAt: DateTime.now().subtract(const Duration(days: 2)),
          plays: 5543,
        ),
      ],
    ),
    Podcast(
      id: 'p4',
      title: 'Tech in Africa',
      author: 'Nexum Studio',
      coverUrl:
          'https://images.unsplash.com/photo-1518791841217-8f162f1e1131?w=600',
      categories: const ['Science & Tech'],
      description: 'Stories from founders and investors across the continent.',
      episodes: [
        Episode(
          id: 'e6',
          podcastId: 'p4',
          title: 'Fintech Infrastructure',
          author: 'Nexum Studio',
          duration: const Duration(minutes: 47, seconds: 22),
          audioUrl:
              'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-5.mp3',
          coverUrl:
              'https://images.unsplash.com/photo-1519340241574-2cec6aef0c01?w=800',
          publishedAt: DateTime.now().subtract(const Duration(days: 5)),
          plays: 20100,
        ),
      ],
    ),
  ];

  static final List<Playlist> myPlaylists = [
    Playlist(
      id: 'pl1',
      title: 'My favorite playlist Crime',
      coverUrl:
          'https://images.unsplash.com/photo-1525517450344-d08a3d2a97d2?w=800',
      description: 'Handpicked episodes on fraud, forensics, and justice.',
      episodes: [
        topPodcasts[0].episodes[0],
        topPodcasts[1].episodes[1],
        topPodcasts[2].episodes[0],
      ],
    ),
  ];

  static List<Episode> favorites() {
    return [
      topPodcasts[0].episodes[0],
      topPodcasts[1].episodes[0],
      topPodcasts[1].episodes[1],
      topPodcasts[3].episodes[0],
    ];
  }

  static String shortDate(DateTime d) => DateFormat('MMM d, y').format(d);

  static List<Podcast> byDomain(String domain) {
    return topPodcasts.where((p) => p.categories.contains(domain)).toList();
  }

  static List<String> allDomains() => interestDomains;
}
