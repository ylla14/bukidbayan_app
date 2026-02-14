import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RentRequestService {
  final CollectionReference _collection =
      FirebaseFirestore.instance.collection('rentRequests');

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

/// Get approved/active requests for a specific user and category
Future<List<RentRequest>> getActiveRequestsByCategory(
  String renterId,
  String category,
) async {
  final snapshot = await _collection
      .where('renterId', isEqualTo: renterId)
      .where('status', whereIn: ['approved', 'onTheWay', 'inProgress'])
      .get();

  final requests = snapshot.docs
      .map((doc) => RentRequest.fromDoc(doc))
      .toList();

  // Filter by category by checking equipment
  List<RentRequest> categoryRequests = [];
  
  for (var request in requests) {
    final equipmentDoc = await FirebaseFirestore.instance
        .collection('equipment')
        .doc(request.itemId)
        .get();
    
    if (equipmentDoc.exists) {
      final equipment = Equipment.fromFirestore(equipmentDoc);
      if (equipment.category == category) {
        categoryRequests.add(request);
      }
    }
  }
  
  return categoryRequests;
}

/// Check if user has active request in a category
Future<bool> hasActiveRequestInCategory(
  String renterId,
  String category,
) async {
  final requests = await getActiveRequestsByCategory(renterId, category);
  return requests.isNotEmpty;
}


}