import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DraftService {
  final _firestore = FirebaseFirestore.instance;

  CollectionReference get _drafts => _firestore.collection('drafts');

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<String> saveDraft(Map<String, dynamic> draftData) async {
    if (_uid == null) throw Exception('Not logged in');
    final doc = await _drafts.add({
      ...draftData,
      'ownerId': _uid,
      'savedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> updateDraft(String draftId, Map<String, dynamic> draftData) async {
    await _drafts.doc(draftId).update({
      ...draftData,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteDraft(String draftId) async {
    await _drafts.doc(draftId).delete();
  }

  Stream<QuerySnapshot> watchDrafts() {
    if (_uid == null) return const Stream.empty();
    return _drafts
        .where('ownerId', isEqualTo: _uid)
        .orderBy('savedAt', descending: true)
        .snapshots();
  }
}