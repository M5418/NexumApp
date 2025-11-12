import '../models/draft_model.dart';

abstract class DraftRepository {
  Future<String> savePostDraft({
    required String title,
    required String body,
    List<String>? mediaUrls,
    List<String>? taggedUsers,
    List<String>? communities,
  });

  Future<String> savePodcastDraft({
    required String title,
    required String description,
    String? coverUrl,
    String? audioUrl,
    String? category,
  });

  Future<List<DraftModel>> getPostDrafts();
  
  Future<List<DraftModel>> getPodcastDrafts();
  
  Future<void> deleteDraft(String draftId);
  
  Future<void> updatePostDraft({
    required String draftId,
    required String title,
    required String body,
    List<String>? mediaUrls,
    List<String>? taggedUsers,
    List<String>? communities,
  });

  Future<void> updatePodcastDraft({
    required String draftId,
    required String title,
    required String description,
    String? coverUrl,
    String? audioUrl,
    String? category,
  });
}
