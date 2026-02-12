import 'dart:io';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class RentRequestService {
  final CollectionReference _collection =
      FirebaseFirestore.instance.collection('rentRequests');

  /// Save image locally
  Future<String> saveFileLocally(XFile file) async {
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
    final newFile = await File(file.path).copy(path);
    return newFile.path;
  }

  /// CREATE — returns the new Firestore document ID
  Future<String> saveRequest(RentRequest request) async {
    final docRef = await _collection.add({
      ...request.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  /// READ ALL (Future-based, for one-shot reads)
  Future<List<RentRequest>> getAllRequests() async {
    final snapshot = await _collection.get();
    final list = snapshot.docs.map((doc) => RentRequest.fromDoc(doc)).toList();
    list.sort((a, b) => b.start.compareTo(a.start));
    return list;
  }

  /// GET requests by renter (Stream for real-time updates)
  Stream<List<RentRequest>> getRequestsByRenter(String renterId) {
    return _collection
        .where('renterId', isEqualTo: renterId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => RentRequest.fromDoc(doc)).toList();
          list.sort((a, b) => b.start.compareTo(a.start));
          return list;
        });
  }

  /// GET requests by owner (Stream for real-time updates)
  Stream<List<RentRequest>> getRequestsByOwner(String ownerId) {
    return _collection
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs.map((doc) => RentRequest.fromDoc(doc)).toList();
          list.sort((a, b) => b.start.compareTo(a.start));
          return list;
        });
  }

  /// GET single request by document ID
  Future<RentRequest> getRequestById(String requestId) async {
    final doc = await _collection.doc(requestId).get();
    if (!doc.exists) throw Exception('Request not found');
    return RentRequest.fromDoc(doc);
  }

  /// UPDATE request status
  Future<RentRequest> updateRequestStatus({
    required String requestId,
    required RentRequestStatus status,
  }) async {
    await _collection.doc(requestId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final doc = await _collection.doc(requestId).get();
    return RentRequest.fromDoc(doc);
  }

  /// DELETE request
  Future<void> deleteRequest(RentRequest request) async {
    await _collection.doc(request.requestId).delete();

    // Delete proof files locally
    if (request.landSizeProofPath != null) {
      final file = File(request.landSizeProofPath!);
      if (await file.exists()) await file.delete();
    }
    if (request.cropHeightProofPath != null) {
      final file = File(request.cropHeightProofPath!);
      if (await file.exists()) await file.delete();
    }
  }

  /// Check for currently approved request on an equipment item
  Future<bool> hasActiveApprovedRequest(String equipmentId) async {
    final snapshot = await _collection
        .where('itemId', isEqualTo: equipmentId)
        .where('status', isEqualTo: 'approved')
        .get();
    return snapshot.docs.isNotEmpty;
  }
  /// Stream a single request by its document ID (real-time updates)
Stream<RentRequest> requestStream(String requestId) {
  return _collection.doc(requestId).snapshots().map((doc) {
    if (!doc.exists) throw Exception('Request not found');
    return RentRequest.fromDoc(doc);
  });
}

// Future<bool> hasDateConflict({
//   required String equipmentId,
//   required DateTime newStart,
//   required DateTime newEnd,
// }) async {
//   final snapshot = await FirebaseFirestore.instance
//       .collection('rentRequests')
//       .where('itemId', isEqualTo: equipmentId)
//       .where('status', whereIn: ['approved', 'inProgress'])
//       .get();

//   for (var doc in snapshot.docs) {
//     final request = RentRequest.fromDoc(doc);

//     final existingStart = request.start;
//     final existingEnd = request.end;

//     final overlaps =
//         existingStart.isBefore(newEnd) &&
//         existingEnd.isAfter(newStart);

//     if (overlaps) {
//       return true; // ❌ conflict found
//     }
//   }

//   return false; // ✅ safe
// }

Future<List<RentRequest>> getApprovedRequests(String equipmentId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('rentRequests')
      .where('itemId', isEqualTo: equipmentId)
      .where('status', whereIn: ['approved', 'inProgress'])
      .get();

  return snapshot.docs
      .map((doc) => RentRequest.fromDoc(doc))
      .toList();
}



}