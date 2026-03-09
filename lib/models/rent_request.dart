import 'package:cloud_firestore/cloud_firestore.dart';

enum RentRequestStatus {
  pending,
  approved,
  onTheWay,
  inProgress,
  retrieving, // 👈 NEW
  returned,
  finished,
  completed,
  declined,
  canceled,
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
  final DateTime? createdAt;
  final String? declineReason;
  final double? volumeSubmitted; // NEW
  final double? agreedPrice;      // the price per unit at time of booking
final String? agreedRentalUnit; // 'Per Day', 'Per Hour', 'Per kg', etc.

  // Weather flagging — set by WeatherService when severe weather overlaps
  // this booking's dates. Any authenticated user may write these fields.
  final bool weatherFlag;
  final List<DateTime> weatherFlagDates;

  final bool? keepDarak;
final double? estimatedMillingFee;

  // Farm location for this specific rent request.
  final String? farmAddress;
  final double? farmLatitude;
  final double? farmLongitude;

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
    this.createdAt,
    this.declineReason,
    this.weatherFlag = false,
    this.weatherFlagDates = const [],
    this.volumeSubmitted = null,
    this.keepDarak,
    this.estimatedMillingFee,
    this.agreedPrice,
this.agreedRentalUnit,
    this.farmAddress,
    this.farmLatitude,
    this.farmLongitude,
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
      'declineReason': declineReason,
      'volumeSubmitted': volumeSubmitted,
      'keepDarak': keepDarak,
      'estimatedMillingFee': estimatedMillingFee,
      'agreedPrice': agreedPrice,
'agreedRentalUnit': agreedRentalUnit,
      'farmAddress': farmAddress,
      'farmLatitude': farmLatitude,
      'farmLongitude': farmLongitude,
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
      end:
          (map['end'] as Timestamp?)?.toDate() ??
          DateTime.now().add(Duration(days: 1)),
      landSizeProofPath: map['landSizeProofPath'],
      cropHeightProofPath: map['cropHeightProofPath'],
      status: RentRequestStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'pending'),
        orElse: () => RentRequestStatus.pending, // default if missing/invalid
      ),
      renterId: map['renterId'],
      ownerId: map['ownerId'],
      createdAt:
          map['createdAt'] !=
              null // ← ADD THESE 3 LINES
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      declineReason: map['declineReason'],
      weatherFlag: (map['weatherFlag'] as bool?) ?? false,
      weatherFlagDates: ((map['weatherFlagDates'] as List<dynamic>?) ?? [])
          .map((t) => (t as Timestamp).toDate())
          .toList(),
      volumeSubmitted: (map['volumeSubmitted'] as num?)?.toDouble(),
      keepDarak: map['keepDarak'] as bool?,
      estimatedMillingFee: (map['estimatedMillingFee'] as num?)?.toDouble(),
      agreedPrice: (map['agreedPrice'] as num?)?.toDouble(),
agreedRentalUnit: map['agreedRentalUnit'] as String?,
      farmAddress: map['farmAddress'] as String?,
      farmLatitude: (map['farmLatitude'] as num?)?.toDouble(),
      farmLongitude: (map['farmLongitude'] as num?)?.toDouble(),
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
    String? declineReason,
    double? volumeSubmitted,
    bool? keepDarak,
    double? estimatedMillingFee,
    double? agreedPrice,
    String? agreedRentalUnit,
    String? farmAddress,
    double? farmLatitude,
    double? farmLongitude,
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
      declineReason: declineReason ?? this.declineReason,
      volumeSubmitted: volumeSubmitted ?? this.volumeSubmitted,
      keepDarak: keepDarak ?? this.keepDarak,
      estimatedMillingFee: estimatedMillingFee ?? this.estimatedMillingFee,
      agreedPrice: agreedPrice ?? this.agreedPrice,
      agreedRentalUnit: agreedRentalUnit ?? this.agreedRentalUnit,
      farmAddress: farmAddress ?? this.farmAddress,
      farmLatitude: farmLatitude ?? this.farmLatitude,
      farmLongitude: farmLongitude ?? this.farmLongitude,
    );
  }
}
