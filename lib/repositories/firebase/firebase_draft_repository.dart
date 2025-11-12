import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../interfaces/draft_repository.dart';
import '../models/draft_model.dart';

class FirebaseDraftRepository implements DraftRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _drafts => _db.collection('drafts');

  @override
  Future<String> savePostDraft({
    required String title,
    required String body,
    List<String>? mediaUrls,
    List<String>? taggedUsers,
    List<String>? communities,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final draft = DraftModel(
      id: '',
      userId: user.uid,
      type: DraftType.post,
      title: title,
      body: body,
      mediaUrls: mediaUrls ?? [],
      taggedUsers: taggedUsers,
      communities: communities,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final ref = await _drafts.add(draft.toMap());
    return ref.id;
  }

  @override
  Future<String> savePodcastDraft({
    required String title,
    required String description,
    String? coverUrl,
    String? audioUrl,
    String? category,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final draft = DraftModel(
      id: '',
      userId: user.uid,
      type: DraftType.podcast,
      title: title,
      body: description,
      coverUrl: coverUrl,
      audioUrl: audioUrl,
      category: category,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final ref = await _drafts.add(draft.toMap());
    return ref.id;
  }

  @override
  Future<List<DraftModel>> getPostDrafts() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final query = await _drafts
        .where('userId', isEqualTo: user.uid)
        .where('type', isEqualTo: 'post')
        .orderBy('updatedAt', descending: true)
        .get();

    return query.docs.map((doc) => DraftModel.fromFirestore(doc)).toList();
  }

  @override
  Future<List<DraftModel>> getPodcastDrafts() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final query = await _drafts
        .where('userId', isEqualTo: user.uid)
        .where('type', isEqualTo: 'podcast')
        .orderBy('updatedAt', descending: true)
        .get();

    return query.docs.map((doc) => DraftModel.fromFirestore(doc)).toList();
  }

  @override
  Future<void> deleteDraft(String draftId) async {
    await _drafts.doc(draftId).delete();
  }

  @override
  Future<void> updatePostDraft({
    required String draftId,
    required String title,
    required String body,
    List<String>? mediaUrls,
    List<String>? taggedUsers,
    List<String>? communities,
  }) async {
    await _drafts.doc(draftId).update({
      'title': title,
      'body': body,
      'mediaUrls': mediaUrls ?? [],
      if (taggedUsers != null) 'taggedUsers': taggedUsers,
      if (communities != null) 'communities': communities,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updatePodcastDraft({
    required String draftId,
    required String title,
    required String description,
    String? coverUrl,
    String? audioUrl,
    String? category,
  }) async {
    await _drafts.doc(draftId).update({
      'title': title,
      'body': description,
      if (coverUrl != null) 'coverUrl': coverUrl,
      if (audioUrl != null) 'audioUrl': audioUrl,
      if (category != null) 'category': category,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
