import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
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
  String? declineReason,
}) async {
  final updateData = <String, dynamic>{
    'status': status.name,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  if (declineReason != null) {
    updateData['declineReason'] = declineReason;
  }

  await _collection.doc(requestId).update(updateData);
  final doc = await _collection.doc(requestId).get();
  final updatedRequest = RentRequest.fromDoc(doc);

  // ✅ If canceled or declined, free up the equipment dates
  if (status == RentRequestStatus.canceled || status == RentRequestStatus.declined) {
    final itemId = (doc.data() as Map<String, dynamic>)['itemId'] as String?;
    if (itemId != null) {
      await FirestoreService().validateEquipmentAvailabilityWithNotification(itemId);
    }
  }

  return updatedRequest;
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

  // ── Case 4: shift queued bookings forward ──────────────────────────────────

  /// Pushes the start/end dates of all queued bookings for [equipmentId]
  /// forward by [daysLate] days.
  ///
  /// "Queued" means any request in a pending/active state that has not yet
  /// started (i.e. start > now).  Statuses covered: pending, approved,
  /// readyForPickup, pickedUp.
  Future<void> shiftQueuedBookingsForEquipment({
    required String equipmentId,
    required int daysLate,
  }) async {
    if (daysLate <= 0) return;

    const queuedStatuses = [
      'pending',
      'approved',
      'readyForPickup',
      'pickedUp',
    ];

    final snapshot = await _collection
        .where('itemId', isEqualTo: equipmentId)
        .where('status', whereIn: queuedStatuses)
        .get();

    // Collect shifted request data before committing so we can notify renters.
    final List<_ShiftedBooking> shifted = [];

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      final data  = doc.data() as Map<String, dynamic>;
      final start = (data['start'] as Timestamp?)?.toDate();
      final end   = (data['end']   as Timestamp?)?.toDate();
      if (start == null || end == null) continue;

      final newStart = start.add(Duration(days: daysLate));
      final newEnd   = end.add(Duration(days: daysLate));

      batch.update(doc.reference, {
        'start': Timestamp.fromDate(newStart),
        'end'  : Timestamp.fromDate(newEnd),
        'shiftedDueToLateReturn': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      shifted.add(_ShiftedBooking(
        renterId : data['renterId'] as String,
        itemName : data['itemName'] as String,
        newStart : newStart,
        newEnd   : newEnd,
      ));
    }

    await batch.commit();

    // Notify each affected renter (non-critical — failures don't roll back).
    String fmt(DateTime d) => '${d.month}/${d.day}/${d.year}';

    final db = FirebaseFirestore.instance;
    for (final b in shifted) {
      try {
        await db
            .collection('notifications')
            .doc(b.renterId)
            .collection('items')
            .add({
          'type'     : 'booking_shifted',
          'title'    : 'Booking Schedule Updated',
          'body'     : 'Ang iyong booking para sa "${b.itemName}" ay na-delay ng '
              '$daysLate ${daysLate == 1 ? 'araw' : 'na araw'} dahil sa '
              'late return ng nakaraang nangupahan. '
              'Bagong schedule: ${fmt(b.newStart)} – ${fmt(b.newEnd)}.',
          'createdAt': FieldValue.serverTimestamp(),
          'read'     : false,
        });
      } catch (_) {
        // Non-fatal — swallow silently.
      }
    }
  }
}

class _ShiftedBooking {
  final String renterId;
  final String itemName;
  final DateTime newStart;
  final DateTime newEnd;
  const _ShiftedBooking({
    required this.renterId,
    required this.itemName,
    required this.newStart,
    required this.newEnd,
  });
}