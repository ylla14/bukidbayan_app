import 'package:cloud_firestore/cloud_firestore.dart';

enum RentRequestStatus {
  pending,
  approved,
  readyForPickup,
  pickedUp,
  onTheWay,
  inProgress,
  retrieving,
  returned,
  finished,
  completed,
  declined,
  canceled,
}

enum DeliveryMethod {
  pickup,
  delivery,
}

class RentRequest {
  final String requestId;
  final String itemId;
  final String itemName;
  final String name;
  final String address;
  final DateTime start;
  final DateTime end;

  // ── Changed: lists of URLs instead of single nullable String ──
  final List<String> landSizeProofPaths;
  final List<String> cropHeightProofPaths;
  final List<String> cropConditionProofPaths;

  final RentRequestStatus status;
  final String renterId;
  final String ownerId;
  final DateTime? createdAt;
  final String? declineReason;
  final double? volumeSubmitted;
  final double? agreedPrice;
  final String? agreedRentalUnit;

  final bool weatherFlag;
  final List<DateTime> weatherFlagDates;

  final bool? keepDarak;
  final double? estimatedMillingFee;
  final double? latitude;
  final double? longitude;
  final DeliveryMethod deliveryMethod;
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
    this.landSizeProofPaths = const [],
    this.cropHeightProofPaths = const [],
    this.cropConditionProofPaths = const [],
    this.status = RentRequestStatus.pending,
    required this.renterId,
    required this.ownerId,
    this.createdAt,
    this.declineReason,
    this.weatherFlag = false,
    this.weatherFlagDates = const [],
    this.volumeSubmitted,
    this.keepDarak,
    this.estimatedMillingFee,
    this.agreedPrice,
    this.agreedRentalUnit,
    this.latitude,
    this.longitude,
    this.deliveryMethod = DeliveryMethod.pickup,
    this.farmAddress,
    this.farmLatitude,
    this.farmLongitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'name': name,
      'address': address,
      'start': Timestamp.fromDate(start),
      'end': Timestamp.fromDate(end),
      // ── Lists stored as Firestore arrays ──────────────────
      'landSizeProofPaths': landSizeProofPaths,
      'cropHeightProofPaths': cropHeightProofPaths,
      'cropConditionProofPaths': cropConditionProofPaths,
      'status': status.name,
      'renterId': renterId,
      'ownerId': ownerId,
      'declineReason': declineReason,
      'volumeSubmitted': volumeSubmitted,
      'keepDarak': keepDarak,
      'estimatedMillingFee': estimatedMillingFee,
      'agreedPrice': agreedPrice,
      'agreedRentalUnit': agreedRentalUnit,
      'latitude': latitude,
      'longitude': longitude,
      'deliveryMethod': deliveryMethod.name,
      'farmAddress': farmAddress,
      'farmLatitude': farmLatitude,
      'farmLongitude': farmLongitude,
    };
  }

  factory RentRequest.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;

    // ── Helper: read either a List<String> (new) or a single
    //    nullable String (old docs) so old records don't break ──
    List<String> _toStringList(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.map((e) => e.toString()).toList();
      if (value is String && value.isNotEmpty) return [value];
      return [];
    }

    return RentRequest(
      requestId: doc.id,
      itemId: map['itemId'],
      itemName: map['itemName'],
      name: map['name'],
      address: map['address'],
      start: (map['start'] as Timestamp?)?.toDate() ?? DateTime.now(),
      end: (map['end'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 1)),
      // ── Backwards-compatible reads ─────────────────────────
      landSizeProofPaths: _toStringList(
        map['landSizeProofPaths'] ?? map['landSizeProofPath'],
      ),
      cropHeightProofPaths: _toStringList(
        map['cropHeightProofPaths'] ?? map['cropHeightProofPath'],
      ),
      cropConditionProofPaths: _toStringList(
        map['cropConditionProofPaths'] ?? map['cropConditionProofPath'],
      ),
      status: RentRequestStatus.values.firstWhere(
        (e) => e.name == (map['status'] ?? 'pending'),
        orElse: () => RentRequestStatus.pending,
      ),
      renterId: map['renterId'],
      ownerId: map['ownerId'],
      createdAt: map['createdAt'] != null
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
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      deliveryMethod: DeliveryMethod.values.firstWhere(
        (e) => e.name == (map['deliveryMethod'] ?? 'pickup'),
        orElse: () => DeliveryMethod.pickup,
      ),
      farmAddress: map['farmAddress'] as String?,
      farmLatitude: (map['farmLatitude'] as num?)?.toDouble(),
      farmLongitude: (map['farmLongitude'] as num?)?.toDouble(),
    );
  }

  RentRequest copyWith({
    String? requestId,
    String? itemId,
    String? itemName,
    String? name,
    String? address,
    DateTime? start,
    DateTime? end,
    List<String>? landSizeProofPaths,
    List<String>? cropHeightProofPaths,
    List<String>? cropConditionProofPaths,
    RentRequestStatus? status,
    String? renterId,
    String? ownerId,
    String? declineReason,
    double? volumeSubmitted,
    bool? keepDarak,
    double? estimatedMillingFee,
    double? agreedPrice,
    String? agreedRentalUnit,
    double? latitude,
    double? longitude,
    DeliveryMethod? deliveryMethod,
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
      landSizeProofPaths: landSizeProofPaths ?? this.landSizeProofPaths,
      cropHeightProofPaths: cropHeightProofPaths ?? this.cropHeightProofPaths,
      cropConditionProofPaths: cropConditionProofPaths ?? this.cropConditionProofPaths,
      status: status ?? this.status,
      renterId: renterId ?? this.renterId,
      ownerId: ownerId ?? this.ownerId,
      declineReason: declineReason ?? this.declineReason,
      volumeSubmitted: volumeSubmitted ?? this.volumeSubmitted,
      keepDarak: keepDarak ?? this.keepDarak,
      estimatedMillingFee: estimatedMillingFee ?? this.estimatedMillingFee,
      agreedPrice: agreedPrice ?? this.agreedPrice,
      agreedRentalUnit: agreedRentalUnit ?? this.agreedRentalUnit,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      farmAddress: farmAddress ?? this.farmAddress,
      farmLatitude: farmLatitude ?? this.farmLatitude,
      farmLongitude: farmLongitude ?? this.farmLongitude,
    );
  }
}