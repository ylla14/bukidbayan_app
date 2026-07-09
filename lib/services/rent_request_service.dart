import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:bukidbayan_app/services/geography_normalization_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RentRequestService {
  final FirebaseFirestore? _firestoreOverride;
  final GeographyNormalizationService _geography;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('rentRequests');

  RentRequestService({
    FirebaseFirestore? firestore,
    GeographyNormalizationService geography =
        const GeographyNormalizationService(),
  }) : _firestoreOverride = firestore,
       _geography = geography;

  /// CREATE — returns the new Firestore document ID
  Future<String> saveRequest(RentRequest request) async {
    final docRef = _collection.doc();
    final batch = _firestore.batch();

    batch.set(docRef, {
      ...request.toMap(),
      ..._normalizeRequestGeography(request),
      'createdAt': FieldValue.serverTimestamp(),
    });

    addStatusHistoryToBatch(
      batch: batch,
      requestId: docRef.id,
      toStatus: request.status,
      actorId: request.renterId,
      actorRole: 'renter',
      source: 'request_created',
    );
    addTimelineEventToBatch(
      batch: batch,
      requestId: docRef.id,
      eventType: 'request_created',
      actorId: request.renterId,
      actorRole: 'renter',
      source: 'request_created',
      metadata: {'status': request.status.name},
    );

    await batch.commit();
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
    return _collection.where('renterId', isEqualTo: renterId).snapshots().map((
      snapshot,
    ) {
      final list = snapshot.docs
          .map((doc) => RentRequest.fromDoc(doc))
          .toList();
      list.sort((a, b) => b.start.compareTo(a.start));
      return list;
    });
  }

  /// GET requests by owner (Stream for real-time updates)
  Stream<List<RentRequest>> getRequestsByOwner(String ownerId) {
    return _collection.where('ownerId', isEqualTo: ownerId).snapshots().map((
      snapshot,
    ) {
      final list = snapshot.docs
          .map((doc) => RentRequest.fromDoc(doc))
          .toList();
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
    String? actorId,
    String actorRole = 'system',
    String source = 'status_update',
  }) async {
    final docRef = _collection.doc(requestId);
    final currentDoc = await docRef.get();
    if (!currentDoc.exists) {
      throw Exception('Request not found');
    }

    final currentRequest = RentRequest.fromDoc(currentDoc);
    final updateData = <String, dynamic>{
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (declineReason != null) {
      updateData['declineReason'] = declineReason;
    }

    final batch = _firestore.batch();
    batch.update(docRef, updateData);
    addStatusHistoryToBatch(
      batch: batch,
      requestId: requestId,
      fromStatus: currentRequest.status,
      toStatus: status,
      actorId: actorId,
      actorRole: actorRole,
      source: source,
      reason: declineReason,
    );
    addTimelineEventToBatch(
      batch: batch,
      requestId: requestId,
      eventType: 'status_changed',
      actorId: actorId,
      actorRole: actorRole,
      source: source,
      metadata: {
        'fromStatus': currentRequest.status.name,
        'toStatus': status.name,
        if (declineReason != null && declineReason.isNotEmpty)
          'reason': declineReason,
      },
    );

    await batch.commit();
    final doc = await docRef.get();
    final updatedRequest = RentRequest.fromDoc(doc);

    // ✅ If canceled or declined, free up the equipment dates
    if (status == RentRequestStatus.canceled ||
        status == RentRequestStatus.declined) {
      final itemId = (doc.data() as Map<String, dynamic>)['itemId'] as String?;
      if (itemId != null) {
        await FirestoreService().validateEquipmentAvailabilityWithNotification(
          itemId,
        );
      }
    }

    return updatedRequest;
  }

  void addStatusHistoryToBatch({
    required WriteBatch batch,
    required String requestId,
    RentRequestStatus? fromStatus,
    required RentRequestStatus toStatus,
    String? actorId,
    String actorRole = 'system',
    String source = 'status_update',
    String? reason,
    Map<String, dynamic> metadata = const {},
  }) {
    final historyRef = _collection
        .doc(requestId)
        .collection('status_history')
        .doc();
    batch.set(historyRef, {
      'fromStatus': fromStatus?.name,
      'toStatus': toStatus.name,
      'reason': reason,
      'actorId': actorId,
      'actorRole': actorRole,
      'source': source,
      'metadata': _serializeMap(metadata),
      'capturedAt': Timestamp.fromDate(DateTime.now()),
      'changedAt': FieldValue.serverTimestamp(),
    });
  }

  void addTimelineEventToBatch({
    required WriteBatch batch,
    required String requestId,
    required String eventType,
    String? actorId,
    String actorRole = 'system',
    String source = 'timeline_event',
    Map<String, dynamic> metadata = const {},
  }) {
    final eventRef = _collection
        .doc(requestId)
        .collection('timeline_events')
        .doc();
    batch.set(eventRef, {
      'eventType': eventType,
      'actorId': actorId,
      'actorRole': actorRole,
      'source': source,
      'metadata': _serializeMap(metadata),
      'capturedAt': Timestamp.fromDate(DateTime.now()),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> recordTimelineEvent({
    required String requestId,
    required String eventType,
    String? actorId,
    String actorRole = 'system',
    String source = 'timeline_event',
    Map<String, dynamic> metadata = const {},
  }) async {
    final batch = _firestore.batch();
    addTimelineEventToBatch(
      batch: batch,
      requestId: requestId,
      eventType: eventType,
      actorId: actorId,
      actorRole: actorRole,
      source: source,
      metadata: metadata,
    );
    await batch.commit();
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
    final snapshot = await _firestore
        .collection('rentRequests')
        .where('itemId', isEqualTo: equipmentId)
        .where('status', whereIn: ['approved', 'inProgress'])
        .get();

    return snapshot.docs.map((doc) => RentRequest.fromDoc(doc)).toList();
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
      final equipmentDoc = await _firestore
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

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final start = (data['start'] as Timestamp?)?.toDate();
      final end = (data['end'] as Timestamp?)?.toDate();
      if (start == null || end == null) continue;

      final newStart = start.add(Duration(days: daysLate));
      final newEnd = end.add(Duration(days: daysLate));

      batch.update(doc.reference, {
        'start': Timestamp.fromDate(newStart),
        'end': Timestamp.fromDate(newEnd),
        'originalStart': Timestamp.fromDate(start),
        'originalEnd': Timestamp.fromDate(end),
        'shiftedDueToLateReturn': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      shifted.add(
        _ShiftedBooking(
          requestId: doc.id,
          renterId: data['renterId'] as String,
          ownerId: data['ownerId'] as String,
          itemName: data['itemName'] as String,
          originalStart: start,
          originalEnd: end,
          newStart: newStart,
          newEnd: newEnd,
        ),
      );
    }

    await batch.commit();

    // Notify each affected renter (non-critical — failures don't roll back).
    String fmt(DateTime d) => '${d.month}/${d.day}/${d.year}';

    final db = _firestore;
    for (final b in shifted) {
      try {
        await db
            .collection('notifications')
            .doc(b.renterId)
            .collection('items')
            .add({
              'type': 'booking_shifted',
              'title': '📅 Na-update ang Iyong Schedule',
              'body':
                  'Ang iyong booking para sa "${b.itemName}" ay na-delay ng '
                  '$daysLate ${daysLate == 1 ? 'araw' : 'na araw'} dahil sa '
                  'late return ng nakaraang nangupahan. '
                  'Orihinal na schedule: ${fmt(b.originalStart)} – ${fmt(b.originalEnd)}. '
                  'Bagong schedule: ${fmt(b.newStart)} – ${fmt(b.newEnd)}. '
                  'Maaari mong i-cancel o tanggapin ang bagong schedule.',
              'requestId': b.requestId,
              'ownerId': b.ownerId,
              'canCancel': true,
              'canAccept': true,
              'createdAt': FieldValue.serverTimestamp(),
              'read': false,
            });
      } catch (_) {
        // Non-fatal — swallow silently.
      }
    }
  }

  Map<String, dynamic> _normalizeRequestGeography(RentRequest request) {
    return {
      ..._geography.normalizeAddressFields(address: request.address),
      ..._geography.normalizeAddressFields(
        address: request.farmAddress,
        prefix: 'farm',
      ),
      if (request.barangay != null) 'barangay': request.barangay,
      if (request.municipality != null) 'municipality': request.municipality,
      if (request.province != null) 'province': request.province,
      if (request.region != null) 'region': request.region,
      if (request.farmBarangay != null) 'farmBarangay': request.farmBarangay,
      if (request.farmMunicipality != null)
        'farmMunicipality': request.farmMunicipality,
      if (request.farmProvince != null) 'farmProvince': request.farmProvince,
      if (request.farmRegion != null) 'farmRegion': request.farmRegion,
    };
  }

  Map<String, dynamic> _serializeMap(Map<String, dynamic> source) {
    return source.map((key, value) => MapEntry(key, _serializeValue(value)));
  }

  dynamic _serializeValue(dynamic value) {
    if (value is DateTime) {
      return Timestamp.fromDate(value);
    }
    if (value is RentRequestStatus) {
      return value.name;
    }
    if (value is Map<String, dynamic>) {
      return _serializeMap(value);
    }
    if (value is Iterable) {
      return value.map(_serializeValue).toList();
    }
    return value;
  }
}

class _ShiftedBooking {
  final String requestId;
  final String renterId;
  final String ownerId;
  final String itemName;
  final DateTime originalStart;
  final DateTime originalEnd;
  final DateTime newStart;
  final DateTime newEnd;
  const _ShiftedBooking({
    required this.requestId,
    required this.renterId,
    required this.ownerId,
    required this.itemName,
    required this.originalStart,
    required this.originalEnd,
    required this.newStart,
    required this.newEnd,
  });
}
