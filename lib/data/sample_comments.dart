import '../models/comment.dart';

class SampleComments {
  static List<Comment> getCommentsForPost(String postId) {
    switch (postId) {
      case 'video_long_text':
        return [
          Comment(
            id: 'comment_1',
            userId: 'user_1',
            userName: 'Marcus Chen',
            userAvatarUrl:
                'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
            text:
                'This is so inspiring! Your journey really resonates with me. I\'m currently in the early stages of building my own startup and facing similar challenges. Thank you for sharing your story! 🙌',
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
            likesCount: 234,
            isLikedByUser: true,
            replies: [
              Comment(
                id: 'reply_1',
                userId: 'creator_1',
                userName: 'Alexandra Thompson',
                userAvatarUrl:
                    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&h=150&fit=crop&crop=face',
                text:
                    'Thank you so much! Keep pushing forward, you\'ve got this! 💪',
                createdAt: DateTime.now().subtract(const Duration(hours: 1)),
                likesCount: 45,
                isLikedByUser: false,
                replies: [],
                parentCommentId: 'comment_1',
                isCreator: true,
              ),
              Comment(
                id: 'reply_2',
                userId: 'user_2',
                userName: 'Sarah Kim',
                userAvatarUrl:
                    'https://images.unsplash.com/photo-1494790108755-2616b612b47c?w=150&h=150&fit=crop&crop=face',
                text: 'Same here! The validation part is so crucial.',
                createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
                likesCount: 12,
                isLikedByUser: true,
                replies: [],
                parentCommentId: 'comment_1',
              ),
            ],
          ),
          Comment(
            id: 'comment_2',
            userId: 'user_3',
            userName: 'David Rodriguez',
            userAvatarUrl:
                'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
            text:
                'Congratulations on the Series A! 🎉 What was the biggest lesson you learned during fundraising?',
            createdAt: DateTime.now().subtract(const Duration(hours: 3)),
            likesCount: 89,
            isLikedByUser: false,
            replies: [],
            isPinned: true,
          ),
          Comment(
            id: 'comment_3',
            userId: 'user_4',
            userName: 'Emily Watson',
            userAvatarUrl:
                'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=150&h=150&fit=crop&crop=face',
            text:
                'Love this! The part about listening to users really hits home. We made that mistake early on and had to pivot completely.',
            createdAt: DateTime.now().subtract(const Duration(hours: 5)),
            likesCount: 156,
            isLikedByUser: true,
            replies: [
              Comment(
                id: 'reply_3',
                userId: 'user_5',
                userName: 'James Wilson',
                userAvatarUrl:
                    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
                text: 'Pivoting is so hard but sometimes necessary!',
                createdAt: DateTime.now().subtract(const Duration(hours: 4)),
                likesCount: 23,
                isLikedByUser: false,
                replies: [],
                parentCommentId: 'comment_3',
              ),
            ],
          ),
          Comment(
            id: 'comment_4',
            userId: 'user_6',
            userName: 'Lisa Park',
            userAvatarUrl:
                'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&h=150&fit=crop&crop=face',
            text: '18 months from idea to Series A is incredible! 🚀',
            createdAt: DateTime.now().subtract(const Duration(hours: 6)),
            likesCount: 67,
            isLikedByUser: false,
            replies: [],
          ),
        ];
      default:
        return [
          Comment(
            id: 'comment_default_1',
            userId: 'user_7',
            userName: 'Alex Johnson',
            userAvatarUrl:
                'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150&h=150&fit=crop&crop=face',
            text: 'Great video! 👍',
            createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
            likesCount: 12,
            isLikedByUser: false,
            replies: [],
          ),
          Comment(
            id: 'comment_default_2',
            userId: 'user_8',
            userName: 'Maria Garcia',
            userAvatarUrl:
                'https://images.unsplash.com/photo-1494790108755-2616b612b47c?w=150&h=150&fit=crop&crop=face',
            text: 'Love the content! Keep it up 🔥',
            createdAt: DateTime.now().subtract(const Duration(hours: 1)),
            likesCount: 8,
            isLikedByUser: true,
            replies: [],
          ),
        ];
    }
  }
}
