import 'package:cloud_firestore/cloud_firestore.dart';

enum RentRequestStatus {
  pending,     // Request sent by renter; awaiting owner approval
  approved,    // Owner approved request; item is being prepared
  onTheWay,    // Item has been dispatched and is en route to renter
  inProgress,  // Renter has received item; rental period is active
  returned,    // Item has been physically returned (condition not yet finalized)
  finished,
  completed,   // Rental fully concluded and confirmed by both parties
  declined,    // Owner rejected the rental request
}


class RentRequest {
  final String requestId; // 🔑 Firestore document ID
  final String itemId;
  final String itemName;
  final String name;
  final String address;
  final DateTime start;
  final DateTime end;
  final String? landSizeProofPath;
  final String? cropHeightProofPath;
  final RentRequestStatus status;
  final String renterId;
  final String ownerId;

  RentRequest({
    required this.requestId,
    required this.itemId,
    required this.itemName,
    required this.name,
    required this.address,
    required this.start,
    required this.end,
    this.landSizeProofPath,
    this.cropHeightProofPath,
    this.status = RentRequestStatus.pending,
    required this.renterId,
    required this.ownerId,
  });

  /// ✅ What gets stored in Firestore
  /// (requestId is NOT stored — Firestore already has it)
  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'name': name,
      'address': address,
      'start': Timestamp.fromDate(start),
      'end': Timestamp.fromDate(end),
      'landSizeProofPath': landSizeProofPath,
      'cropHeightProofPath': cropHeightProofPath,
      'status': status.name,
      'renterId': renterId,
      'ownerId': ownerId,
    };
  }

  /// ✅ Build model FROM Firestore document
  factory RentRequest.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;

    return RentRequest(
      requestId: doc.id, // 🔑 THIS IS THE REQUEST ID
      itemId: map['itemId'],
      itemName: map['itemName'],
      name: map['name'],
      address: map['address'],
      start: (map['start'] as Timestamp?)?.toDate() ?? DateTime.now(),
      end: (map['end'] as Timestamp?)?.toDate() ?? DateTime.now().add(Duration(days: 1)),
      landSizeProofPath: map['landSizeProofPath'],
      cropHeightProofPath: map['cropHeightProofPath'],
      status: RentRequestStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'pending'),
        orElse: () => RentRequestStatus.pending, // default if missing/invalid
      ),

      renterId: map['renterId'],
      ownerId: map['ownerId'],
    );
  }


  /// ✅ For updating fields safely
  RentRequest copyWith({
    String? requestId,
    String? itemId,
    String? itemName,
    String? name,
    String? address,
    DateTime? start,
    DateTime? end,
    String? landSizeProofPath,
    String? cropHeightProofPath,
    RentRequestStatus? status,
    String? renterId,
    String? ownerId,
  }) {
    return RentRequest(
      requestId: requestId ?? this.requestId,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      name: name ?? this.name,
      address: address ?? this.address,
      start: start ?? this.start,
      end: end ?? this.end,
      landSizeProofPath: landSizeProofPath ?? this.landSizeProofPath,
      cropHeightProofPath: cropHeightProofPath ?? this.cropHeightProofPath,
      status: status ?? this.status,
      renterId: renterId ?? this.renterId,
      ownerId: ownerId ?? this.ownerId,
    );
  }
}
