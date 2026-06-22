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

enum DeliveryMethod { pickup, delivery }

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
  final double? hectaresEntered; // for tractor bookings

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

  /// Tracks the last date a late-return strike was issued for this request.
  /// Used client-side to calculate how many new overdue days need strikes.
  final DateTime? lastLateStrikeIssuedDate;

  /// Original dates before the booking was shifted due to a late return.
  /// Non-null only on bookings that have been shifted.
  final DateTime? originalStart;
  final DateTime? originalEnd;

  final bool? keepDarak;
  final double? estimatedMillingFee;
  final double? latitude;
  final double? longitude;
  final DeliveryMethod deliveryMethod;
  final String? farmAddress;
  final double? farmLatitude;
  final double? farmLongitude;
  final String? phoneNumber;
  final String? barangay;
  final String? municipality;
  final String? province;
  final String? region;
  final String? farmBarangay;
  final String? farmMunicipality;
  final String? farmProvince;
  final String? farmRegion;
  final String? cropType;
  final String? farmingPhase;
  final String? intendedUse;

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
    this.hectaresEntered,
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
    this.phoneNumber,
    this.barangay,
    this.municipality,
    this.province,
    this.region,
    this.farmBarangay,
    this.farmMunicipality,
    this.farmProvince,
    this.farmRegion,
    this.cropType,
    this.farmingPhase,
    this.intendedUse,

    this.lastLateStrikeIssuedDate,
    this.originalStart,
    this.originalEnd,
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
      'hectaresEntered': hectaresEntered,
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
      'phoneNumber': phoneNumber,
      'barangay': barangay,
      'municipality': municipality,
      'province': province,
      'region': region,
      'farmBarangay': farmBarangay,
      'farmMunicipality': farmMunicipality,
      'farmProvince': farmProvince,
      'farmRegion': farmRegion,
      'cropType': cropType,
      'farmingPhase': farmingPhase,
      'intendedUse': intendedUse,

      'lastLateStrikeIssuedDate': lastLateStrikeIssuedDate != null
          ? Timestamp.fromDate(lastLateStrikeIssuedDate!)
          : null,
      'originalStart': originalStart != null
          ? Timestamp.fromDate(originalStart!)
          : null,
      'originalEnd': originalEnd != null
          ? Timestamp.fromDate(originalEnd!)
          : null,
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
      end:
          (map['end'] as Timestamp?)?.toDate() ??
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
      hectaresEntered: (map['hectaresEntered'] as num?)?.toDouble(),
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
      phoneNumber: map['phoneNumber'] as String?,
      barangay: map['barangay'] as String?,
      municipality: map['municipality'] as String?,
      province: map['province'] as String?,
      region: map['region'] as String?,
      farmBarangay: map['farmBarangay'] as String?,
      farmMunicipality: map['farmMunicipality'] as String?,
      farmProvince: map['farmProvince'] as String?,
      farmRegion: map['farmRegion'] as String?,
      cropType: map['cropType'] as String?,
      farmingPhase: map['farmingPhase'] as String?,
      intendedUse: map['intendedUse'] as String?,

      lastLateStrikeIssuedDate: (map['lastLateStrikeIssuedDate'] as Timestamp?)
          ?.toDate(),
      originalStart: (map['originalStart'] as Timestamp?)?.toDate(),
      originalEnd: (map['originalEnd'] as Timestamp?)?.toDate(),
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
    DateTime? createdAt,
    String? declineReason,
    bool? weatherFlag,
    List<DateTime>? weatherFlagDates,
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
    double? hectaresEntered,
    String? phoneNumber,
    String? barangay,
    String? municipality,
    String? province,
    String? region,
    String? farmBarangay,
    String? farmMunicipality,
    String? farmProvince,
    String? farmRegion,
    String? cropType,
    String? farmingPhase,
    String? intendedUse,

    DateTime? lastLateStrikeIssuedDate,
    DateTime? originalStart,
    DateTime? originalEnd,
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
      cropConditionProofPaths:
          cropConditionProofPaths ?? this.cropConditionProofPaths,
      hectaresEntered: hectaresEntered ?? this.hectaresEntered,
      status: status ?? this.status,
      renterId: renterId ?? this.renterId,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      declineReason: declineReason ?? this.declineReason,
      weatherFlag: weatherFlag ?? this.weatherFlag,
      weatherFlagDates: weatherFlagDates ?? this.weatherFlagDates,
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
      phoneNumber: phoneNumber ?? this.phoneNumber,
      barangay: barangay ?? this.barangay,
      municipality: municipality ?? this.municipality,
      province: province ?? this.province,
      region: region ?? this.region,
      farmBarangay: farmBarangay ?? this.farmBarangay,
      farmMunicipality: farmMunicipality ?? this.farmMunicipality,
      farmProvince: farmProvince ?? this.farmProvince,
      farmRegion: farmRegion ?? this.farmRegion,
      cropType: cropType ?? this.cropType,
      farmingPhase: farmingPhase ?? this.farmingPhase,
      intendedUse: intendedUse ?? this.intendedUse,
      lastLateStrikeIssuedDate:
          lastLateStrikeIssuedDate ?? this.lastLateStrikeIssuedDate,
      originalStart: originalStart ?? this.originalStart,
      originalEnd: originalEnd ?? this.originalEnd,
    );
  }
}
