import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'data/interest_domains.dart';

// Simple script to fix all communities directly
Future<void> fixAllCommunities() async {
  final db = FirebaseFirestore.instance;
  
  try {
    // Get all communities
    final allCommunities = await db.collection('communities').get();
    
    // Update each community with proper name
    for (final doc in allCommunities.docs) {
      final data = doc.data();
      final currentName = data['name']?.toString() ?? '';
      
      // Check if name needs fixing
      if (currentName.isEmpty || currentName == 'null' || currentName == 'undefined') {
        // Try to match with interest domain
        String properName = '';
        
        // First, try to match by ID
        final docId = doc.id;
        for (final interest in interestDomains) {
          final expectedId = interest
              .toLowerCase()
              .replaceAll(' & ', '-and-')
              .replaceAll('&', '-and-')
              .replaceAll('/', '-')  // Critical: handle slashes!
              .replaceAll(' ', '-')
              .replaceAll('(', '')
              .replaceAll(')', '')
              .replaceAll(',', '')
              .replaceAll("'", '')
              .replaceAll(RegExp(r'-+'), '-');
          if (docId == expectedId) {
            properName = interest;
            break;
          }
        }
        
        // If no match by ID, use the ID itself as name (capitalize properly)
        if (properName.isEmpty) {
          properName = docId
              .split('-')
              .map((word) => word.isNotEmpty 
                  ? '${word[0].toUpperCase()}${word.substring(1)}' 
                  : '')
              .join(' ');
        }
        
        // Update the document
        await doc.reference.update({
          'name': properName,
          'bio': 'A community for $properName enthusiasts. Connect with like-minded people, share ideas, and discover new content.',
          'interestDomain': properName,
          'avatarUrl': data['avatarUrl'] ?? '',
          'coverUrl': data['coverUrl'] ?? '',
          'memberCount': data['memberCount'] ?? 0,
          'postsCount': data['postsCount'] ?? 0,
          'unreadPosts': data['unreadPosts'] ?? 0,
          'friendsInCommon': data['friendsInCommon'] ?? '+0',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    
    // Also create any missing communities
    for (final interest in interestDomains) {
      final communityId = interest.toLowerCase().replaceAll(' & ', '-').replaceAll(' ', '-');
      final docRef = db.collection('communities').doc(communityId);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        await docRef.set({
        'name': interest,
        'bio': 'A community for $interest enthusiasts. Connect with like-minded people, share ideas, and discover new content.',
        'avatarUrl': '',
        'coverUrl': '',
        'interestDomain': interest,
        'memberCount': 0,
        'postsCount': 0,
        'unreadPosts': 0,
        'friendsInCommon': '+0',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
  } catch (e) {
    // Silent fail
  }
}

// Call this from your app to fix communities
class FixCommunitiesButton extends StatelessWidget {
  const FixCommunitiesButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final navigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
        
        try {
          await fixAllCommunities();
          navigator.pop(); // Close loading
          messenger.showSnackBar(
            const SnackBar(content: Text('✅ All communities fixed!')),
          );
        } catch (e) {
          navigator.pop(); // Close loading
          messenger.showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      },
      child: const Text('FIX ALL COMMUNITIES'),
    );
  }
}
