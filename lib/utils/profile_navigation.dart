import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../other_user_profile_page.dart';
import '../home_feed_page.dart';

/// Navigates to the appropriate profile page based on whether the user is the
/// authenticated user or another user.
/// 
/// If [userId] matches the current auth user, navigates to the main profile page
/// (index 4 in bottom nav). Otherwise, navigates to OtherUserProfilePage.
void navigateToUserProfile({
  required BuildContext context,
  required String userId,
  required String userName,
  required String userAvatarUrl,
  String userBio = '',
  String userCoverUrl = '',
  bool isConnected = false,
  bool theyConnectToYou = false,
}) {
  final currentUserId = fb.FirebaseAuth.instance.currentUser?.uid;
  
  if (currentUserId != null && currentUserId == userId) {
    // Navigate to own profile page (index 4 in bottom nav)
    // Pop all routes and go to HomeFeedPage with profile tab selected
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'home_feed_profile'),
        builder: (context) => const HomeFeedPage(initialNavIndex: 4),
      ),
      (route) => false,
    );
  } else {
    // Navigate to other user's profile
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: 'other_user_profile'),
        builder: (context) => OtherUserProfilePage(
          userId: userId,
          userName: userName,
          userAvatarUrl: userAvatarUrl,
          userBio: userBio,
          userCoverUrl: userCoverUrl,
          isConnected: isConnected,
          theyConnectToYou: theyConnectToYou,
        ),
      ),
    );
  }
}
