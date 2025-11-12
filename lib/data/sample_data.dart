import '../models/post.dart';

class SampleData {
  static List<Post> getSamplePosts() {
    return [
      Post(
        id: '1',
        authorId: 'sample_user_1',
        userName: 'Alex Helena',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1494790108755-2616b612b47c?w=150&h=150&fit=crop&crop=face',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        text:
            'Just had the most amazing meeting with potential investors! The energy was incredible and I can see where it leads. The best time to start is now! 🚀',
        mediaType: MediaType.none,
        imageUrls: [],
        counts: const PostCounts(
          likes: 142,
          comments: 23,
          shares: 8,
          reposts: 12,
          bookmarks: 34,
        ),
        userReaction: ReactionType.like,
        isBookmarked: false,
        isRepost: false,
      ),
      Post(
        id: '2',
        authorId: 'sample_user_2',
        userName: 'Valerie Azar',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        text:
            'Get your hands dirty and create something beautiful! Discover the art of artisanal making in this immersive workshop where we explore traditional techniques and modern innovation.',
        mediaType: MediaType.image,
        imageUrls: [
          'https://images.unsplash.com/photo-1581833971358-2c8b550f87b3?w=400&h=300&fit=crop',
        ],
        counts: const PostCounts(
          likes: 89,
          comments: 15,
          shares: 22,
          reposts: 6,
          bookmarks: 45,
        ),
        userReaction: null,
        isBookmarked: true,
        isRepost: false,
      ),
      Post(
        id: '3',
        authorId: 'sample_user_2',
        userName: 'Valerie Azar',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face',
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        text:
            'Exploring the intersection of technology and creativity in our latest project. Here are some behind-the-scenes moments from our design process. The journey has been incredible so far, and we are excited to share more insights about how we approach problem-solving in the digital age. Innovation happens when diverse minds come together to create something meaningful.',
        mediaType: MediaType.images,
        imageUrls: [
          'https://images.unsplash.com/photo-1522202176988-66273c2fd55f?w=120&h=160&fit=crop',
          'https://images.unsplash.com/photo-1515378791036-0648a814c963?w=120&h=160&fit=crop',
          'https://images.unsplash.com/photo-1542744173-8e7e53415bb0?w=120&h=160&fit=crop',
          'https://images.unsplash.com/photo-1553877522-43269d4ea984?w=120&h=160&fit=crop',
        ],
        counts: const PostCounts(
          likes: 234,
          comments: 67,
          shares: 45,
          reposts: 23,
          bookmarks: 78,
        ),
        userReaction: ReactionType.heart,
        isBookmarked: false,
        isRepost: false,
      ),
      Post(
        id: '4',
        authorId: 'sample_user_3',
        userName: 'Harry Mills',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        text:
            'The future belongs to those who believe in the beauty of their dreams. Just wrapped up an incredible brainstorming session! 💡✨',
        mediaType: MediaType.video,
        videoUrl:
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        imageUrls: [],
        counts: const PostCounts(
          likes: 156,
          comments: 34,
          shares: 28,
          reposts: 15,
          bookmarks: 52,
        ),
        userReaction: null,
        isBookmarked: false,
        isRepost: false,
      ),
      Post(
        id: '5',
        authorId: 'sample_user_4',
        userName: 'Lola Gibson',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&h=150&fit=crop&crop=face',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        text: 'Exciting news! Our startup just secured Series A funding! 🎉',
        mediaType: MediaType.none,
        imageUrls: [],
        counts: const PostCounts(
          likes: 445,
          comments: 89,
          shares: 156,
          reposts: 78,
          bookmarks: 234,
        ),
        userReaction: ReactionType.diamond,
        isBookmarked: true,
        isRepost: true,
        repostedBy: const RepostedBy(
          userName: 'Dehoua Guy',
          userAvatarUrl:
              'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
        ),
      ),
      Post(
        id: '6',
        authorId: 'sample_user_5',
        userName: 'Vania Peter',
        userAvatarUrl:
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        text:
            'Sunny days, warm hearts, perfect vibes—today\'s weather feels like a gentle hug from nature. Perfect weather for brainstorming new ideas and connecting with amazing people in the entrepreneurship community.',
        mediaType: MediaType.image,
        imageUrls: [
          'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&h=300&fit=crop',
        ],
        counts: const PostCounts(
          likes: 78,
          comments: 12,
          shares: 5,
          reposts: 3,
          bookmarks: 23,
        ),
        userReaction: null,
        isBookmarked: false,
        isRepost: false,
      ),
    ];
  }

  static List<Map<String, dynamic>> getSampleStories() {
    return [
      {
        'imageUrl': null,
        'label': 'Your story',
        'isMine': true,
        'isSeen': false,
      },
      {
        'imageUrl':
            'https://images.unsplash.com/photo-1494790108755-2616b612b47c?w=150&h=150&fit=crop&crop=face',
        'label': 'Alex Helena',
        'isMine': false,
        'isSeen': false,
      },
      {
        'imageUrl':
            'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face',
        'label': 'Valerie',
        'isMine': false,
        'isSeen': true,
      },
      {
        'imageUrl':
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
        'label': 'Harry Mills',
        'isMine': false,
        'isSeen': false,
      },
      {
        'imageUrl':
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&h=150&fit=crop&crop=face',
        'label': 'Lola Gibson',
        'isMine': false,
        'isSeen': false,
      },
      {
        'imageUrl':
            'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
        'label': 'Vania Peter',
        'isMine': false,
        'isSeen': true,
      },
    ];
  }
}
