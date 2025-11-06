import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import '../interfaces/mentorship_repository.dart';

class FirebaseMentorshipRepository implements MentorshipRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _mentors => _db.collection('mentors');
  CollectionReference<Map<String, dynamic>> get _mentorshipConversations => _db.collection('mentorship_conversations');
  CollectionReference<Map<String, dynamic>> get _mentorshipFields => _db.collection('mentorship_fields');
  CollectionReference<Map<String, dynamic>> get _mentorshipRequests => _db.collection('mentorship_requests');

  MentorModel _mentorFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return MentorModel(
      id: doc.id,
      name: (d['name'] ?? '').toString(),
      avatarUrl: d['avatarUrl']?.toString(),
      profession: d['profession']?.toString(),
      company: d['company']?.toString(),
      expertise: List<String>.from(d['expertise'] ?? []),
      rating: (d['rating'] ?? 0.0).toDouble(),
      reviewCount: (d['reviewCount'] ?? 0).toInt(),
      bio: (d['bio'] ?? '').toString(),
      isOnline: d['isOnline'] == true,
      location: (d['location'] ?? '').toString(),
      yearsExperience: (d['yearsExperience'] ?? 0).toInt(),
    );
  }

  MentorshipConversationModel _conversationFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    MentorModel? mentor,
  ) {
    final d = doc.data() ?? {};
    return MentorshipConversationModel(
      id: doc.id,
      mentorId: (d['mentorId'] ?? '').toString(),
      studentId: (d['studentId'] ?? '').toString(),
      lastMessageType: d['lastMessageType']?.toString(),
      lastMessageText: d['lastMessageText']?.toString(),
      lastMessageAt: (d['lastMessageAt'] as Timestamp?)?.toDate(),
      unreadCount: (d['unreadCount'] ?? 0).toInt(),
      muted: d['muted'] == true,
      mentor: mentor,
    );
  }

  MentorshipFieldModel _fieldFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return MentorshipFieldModel(
      id: doc.id,
      name: (d['name'] ?? '').toString(),
      icon: (d['icon'] ?? '').toString(),
      description: d['description']?.toString(),
      mentorCount: (d['mentorCount'] ?? 0).toInt(),
    );
  }

  MentorshipRequestModel _requestFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return MentorshipRequestModel(
      id: doc.id,
      mentorId: (d['mentorId'] ?? '').toString(),
      studentId: (d['studentId'] ?? '').toString(),
      message: (d['message'] ?? '').toString(),
      status: (d['status'] ?? 'pending').toString(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (d['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  Future<List<MentorModel>> listMentors({String? fieldId, int limit = 20}) async {
    Query<Map<String, dynamic>> query = _mentors;
    
    if (fieldId != null) {
      query = query.where('fieldIds', arrayContains: fieldId);
    }
    
    final snap = await query.limit(limit).get();
    return snap.docs.map(_mentorFromDoc).toList();
  }

  @override
  Future<MentorModel?> getMentor(String mentorId) async {
    final doc = await _mentors.doc(mentorId).get();
    if (!doc.exists) return null;
    return _mentorFromDoc(doc);
  }

  @override
  Future<List<MentorModel>> searchMentors(String query) async {
    final q = query.toLowerCase();
    
    // Search by name
    final nameQuery = await _mentors
        .where('nameLower', isGreaterThanOrEqualTo: q)
        .where('nameLower', isLessThan: '$q\uf8ff')
        .limit(10)
        .get();
    
    // Search by profession
    final profQuery = await _mentors
        .where('professionLower', isGreaterThanOrEqualTo: q)
        .where('professionLower', isLessThan: '$q\uf8ff')
        .limit(10)
        .get();
    
    // Combine and deduplicate
    final mentorMap = <String, MentorModel>{};
    for (final doc in [...nameQuery.docs, ...profQuery.docs]) {
      mentorMap[doc.id] = _mentorFromDoc(doc);
    }
    
    return mentorMap.values.toList();
  }

  @override
  Future<List<MentorModel>> getMyMentors() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    
    // Get accepted mentorship requests
    final requests = await _mentorshipRequests
        .where('studentId', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .get();
    
    final mentorIds = requests.docs.map((d) => d['mentorId'].toString()).toSet();
    if (mentorIds.isEmpty) return [];
    
    final mentors = <MentorModel>[];
    for (final id in mentorIds) {
      final mentor = await getMentor(id);
      if (mentor != null) mentors.add(mentor);
    }
    
    return mentors;
  }

  @override
  Future<List<MentorshipFieldModel>> listFields() async {
    final snap = await _mentorshipFields.orderBy('name').get();
    return snap.docs.map(_fieldFromDoc).toList();
  }

  @override
  Future<MentorshipFieldModel?> getField(String fieldId) async {
    final doc = await _mentorshipFields.doc(fieldId).get();
    if (!doc.exists) return null;
    return _fieldFromDoc(doc);
  }

  @override
  Future<List<MentorshipConversationModel>> listConversations() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    
    final snap = await _mentorshipConversations
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .get();
    
    final conversations = <MentorshipConversationModel>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      final mentorId = d['participants']?.firstWhere(
        (p) => p != uid,
        orElse: () => null,
      );
      
      MentorModel? mentor;
      if (mentorId != null) {
        mentor = await getMentor(mentorId.toString());
      }
      
      conversations.add(_conversationFromDoc(doc, mentor));
    }
    
    return conversations;
  }

  @override
  Future<String> createConversationWithMentor(String mentorId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');
    
    // Check if conversation already exists
    final existing = await _mentorshipConversations
        .where('participants', arrayContains: uid)
        .get();
    
    for (final doc in existing.docs) {
      final participants = List<String>.from(doc.data()['participants'] ?? []);
      if (participants.contains(mentorId)) {
        return doc.id;
      }
    }
    
    // Create new conversation
    final data = {
      'participants': [uid, mentorId],
      'mentorId': mentorId,
      'studentId': uid,
      'lastMessageType': null,
      'lastMessageText': null,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCount': 0,
      'muted': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
    
    final ref = await _mentorshipConversations.add(data);
    return ref.id;
  }

  @override
  Future<void> markConversationRead(String conversationId) async {
    await _mentorshipConversations.doc(conversationId).update({
      'unreadCount': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> muteConversation(String conversationId) async {
    await _mentorshipConversations.doc(conversationId).update({
      'muted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> unmuteConversation(String conversationId) async {
    await _mentorshipConversations.doc(conversationId).update({
      'muted': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    
    await _mentorshipConversations.doc(conversationId).update({
      'deletedFor.$uid': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<MentorshipRequestModel> sendRequest({
    required String mentorId,
    required String message,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');
    
    // Check if request already exists
    final existing = await _mentorshipRequests
        .where('studentId', isEqualTo: uid)
        .where('mentorId', isEqualTo: mentorId)
        .where('status', isEqualTo: 'pending')
        .get();
    
    if (existing.docs.isNotEmpty) {
      return _requestFromDoc(existing.docs.first);
    }
    
    final data = {
      'mentorId': mentorId,
      'studentId': uid,
      'message': message,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'respondedAt': null,
    };
    
    final ref = await _mentorshipRequests.add(data);
    final doc = await ref.get();
    return _requestFromDoc(doc);
  }

  @override
  Future<List<MentorshipRequestModel>> listMyRequests() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    
    final snap = await _mentorshipRequests
        .where('studentId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();
    
    return snap.docs.map(_requestFromDoc).toList();
  }

  @override
  Future<List<MentorshipRequestModel>> listReceivedRequests() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];
    
    final snap = await _mentorshipRequests
        .where('mentorId', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .get();
    
    return snap.docs.map(_requestFromDoc).toList();
  }

  @override
  Future<void> acceptRequest(String requestId) async {
    await _mentorshipRequests.doc(requestId).update({
      'status': 'accepted',
      'respondedAt': FieldValue.serverTimestamp(),
    });
    
    // Auto-create conversation
    final doc = await _mentorshipRequests.doc(requestId).get();
    if (doc.exists) {
      final d = doc.data()!;
      await createConversationWithMentor(d['studentId'].toString());
    }
  }

  @override
  Future<void> rejectRequest(String requestId) async {
    await _mentorshipRequests.doc(requestId).update({
      'status': 'rejected',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<MentorshipConversationModel>> conversationsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    
    return _mentorshipConversations
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .asyncMap((snap) async {
      final conversations = <MentorshipConversationModel>[];
      for (final doc in snap.docs) {
        final d = doc.data();
        final mentorId = d['participants']?.firstWhere(
          (p) => p != uid,
          orElse: () => null,
        );
        
        MentorModel? mentor;
        if (mentorId != null) {
          mentor = await getMentor(mentorId.toString());
        }
        
        conversations.add(_conversationFromDoc(doc, mentor));
      }
      return conversations;
    });
  }

  @override
  Stream<List<MentorshipRequestModel>> requestsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    
    return _mentorshipRequests
        .where('studentId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(_requestFromDoc).toList());
  }
}
