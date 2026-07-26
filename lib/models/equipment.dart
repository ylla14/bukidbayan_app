import 'package:cloud_firestore/cloud_firestore.dart';

enum EquipmentStatus {
  available,
  unavailable,
  underMaintenance,
  retired;

  static EquipmentStatus fromString(String? value) {
    switch (value) {
      case 'available':
        return EquipmentStatus.available;
      case 'unavailable':
        return EquipmentStatus.unavailable;
      case 'under_maintenance':
        return EquipmentStatus.underMaintenance;
      case 'retired':
        return EquipmentStatus.retired;
      default:
        return EquipmentStatus.available;
    }
  }

  String toValue() {
    switch (this) {
      case EquipmentStatus.available:
        return 'available';
      case EquipmentStatus.unavailable:
        return 'unavailable';
      case EquipmentStatus.underMaintenance:
        return 'under_maintenance';
      case EquipmentStatus.retired:
        return 'retired';
    }
  }
}

enum DeliveryMode {
  pickupOnly,
  deliveryOnly,
  both;

  static DeliveryMode fromString(String? value) {
    switch (value) {
      case 'pickup_only':
        return DeliveryMode.pickupOnly;
      case 'delivery_only':
        return DeliveryMode.deliveryOnly;
      case 'both':
        return DeliveryMode.both;
      default:
        return DeliveryMode.both;
    }
  }

  String toValue() {
    switch (this) {
      case DeliveryMode.pickupOnly:
        return 'pickup_only';
      case DeliveryMode.deliveryOnly:
        return 'delivery_only';
      case DeliveryMode.both:
        return 'both';
    }
  }
}

class Equipment {
  final String? id;
  final String name;
  final String description;
  final String? nameEn;
  final String? nameTl;
  final String? descriptionEn;
  final String? descriptionTl;
  final String? category;
  final String? brand;
  final String? yearModel;
  final String? power;
  final String condition;
  final String? attachments;
  final String? fuelType;
  final String? defects;
  final int damageReportCount;
  final double price;
  final String rentalUnit;
  final String rentRate;
  final List<String> requirements;
  final bool landSizeRequirement;
  final bool maxCropHeightRequirement;
  final String? landSizeMin;
  final String? landSizeMax;
  final String? maxCropHeight;
  final bool operatorIncluded;
  final EquipmentStatus status;
  final DateTime? availableFrom;
  final DateTime? availableUntil;
  final String ownerId;
  final String? ownerName;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? barangay;
  final String? municipality;
  final String? province;
  final String? region;
  final List<String> imageUrls;
  final List<String> reviews;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool minimumVolumeRequired;
  final double? minimumVolumeKg;
  final double? minimumVolumeCavans;
  final String minimumVolumeUnit;
  final bool batchingAllowed;
  final double? riceOnlyPricePerKg;
  final double? ricePlusDarakPricePerKg;
  final DateTime? maintenanceStart;
  final DateTime? maintenanceEnd;
  final DeliveryMode deliveryMode;
  final bool cropConditionRequirement;
  final String? cropCondition;
  final bool cropShareRequired;
  final double? cropSharePercent;
  final bool maintenanceRequired;
  final double maintenanceIntervalHrs;
  final double hoursUsedSinceLastMaintenance;
  final int maintenanceCount;
  final int majorBreakdownCount;
  final bool retirementFlaggedByAdmin;
  final DateTime? retiredAt;

  const Equipment({
    this.id,
    required this.name,
    required this.description,
    this.nameEn,
    this.nameTl,
    this.descriptionEn,
    this.descriptionTl,
    this.category,
    this.brand,
    this.yearModel,
    this.power,
    required this.condition,
    this.attachments,
    this.fuelType,
    this.defects,
    this.damageReportCount = 0,
    required this.price,
    required this.rentalUnit,
    this.rentRate = '',
    this.requirements = const [],
    required this.landSizeRequirement,
    required this.maxCropHeightRequirement,
    this.landSizeMin,
    this.landSizeMax,
    this.maxCropHeight,
    this.operatorIncluded = false,
    this.status = EquipmentStatus.available,
    this.availableFrom,
    this.availableUntil,
    required this.ownerId,
    this.ownerName,
    this.location,
    this.latitude,
    this.longitude,
    this.barangay,
    this.municipality,
    this.province,
    this.region,
    this.imageUrls = const [],
    this.reviews = const [],
    this.createdAt,
    this.updatedAt,
    this.minimumVolumeRequired = false,
    this.minimumVolumeKg,
    this.minimumVolumeCavans,
    this.minimumVolumeUnit = 'cavans',
    this.batchingAllowed = true,
    this.riceOnlyPricePerKg,
    this.ricePlusDarakPricePerKg,
    this.maintenanceStart,
    this.maintenanceEnd,
    this.deliveryMode = DeliveryMode.both,
    this.cropConditionRequirement = false,
    this.cropCondition,
    this.cropShareRequired = false,
    this.cropSharePercent,
    this.maintenanceRequired = false,
    this.maintenanceIntervalHrs = 240,
    this.hoursUsedSinceLastMaintenance = 0,
    this.maintenanceCount = 0,
    this.majorBreakdownCount = 0,
    this.retirementFlaggedByAdmin = false,
    this.retiredAt,
  });

  bool get isAvailable => status == EquipmentStatus.available;

  double? get minimumVolumeInCavans =>
      minimumVolumeKg != null ? minimumVolumeKg! / 50.0 : null;

  double get remainingMaintenanceHrs =>
      maintenanceIntervalHrs - hoursUsedSinceLastMaintenance;

  bool get isUpcomingMaintenance =>
      remainingMaintenanceHrs <= 48 && remainingMaintenanceHrs > 0;

  bool get isForMaintenance =>
      hoursUsedSinceLastMaintenance >= maintenanceIntervalHrs;

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'nameEn': nameEn,
      'nameTl': nameTl,
      'descriptionEn': descriptionEn,
      'descriptionTl': descriptionTl,
      'category': category,
      'brand': brand,
      'yearModel': yearModel,
      'power': power,
      'condition': condition,
      'attachments': attachments,
      'fuelType': fuelType,
      'defects': defects,
      'damageReportCount': damageReportCount,
      'price': price,
      'rentalUnit': rentalUnit,
      'rentRate': rentRate,
      'requirements': requirements,
      'landSizeRequirement': landSizeRequirement,
      'maxCropHeightRequirement': maxCropHeightRequirement,
      'landSizeMin': landSizeMin,
      'landSizeMax': landSizeMax,
      'maxCropHeight': maxCropHeight,
      'operatorIncluded': operatorIncluded,
      'status': status.toValue(),
      'availableFrom': availableFrom != null
          ? Timestamp.fromDate(availableFrom!)
          : null,
      'availableUntil': availableUntil != null
          ? Timestamp.fromDate(availableUntil!)
          : null,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'barangay': barangay,
      'municipality': municipality,
      'province': province,
      'region': region,
      'imageUrls': imageUrls,
      'reviews': reviews,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
      'minimumVolumeRequired': minimumVolumeRequired,
      'minimumVolumeKg': minimumVolumeKg,
      'minimumVolumeUnit': minimumVolumeUnit,
      'batchingAllowed': batchingAllowed,
      'riceOnlyPricePerKg': riceOnlyPricePerKg,
      'ricePlusDarakPricePerKg': ricePlusDarakPricePerKg,
      'maintenanceStart': maintenanceStart != null
          ? Timestamp.fromDate(maintenanceStart!)
          : null,
      'maintenanceEnd': maintenanceEnd != null
          ? Timestamp.fromDate(maintenanceEnd!)
          : null,
      'deliveryMode': deliveryMode.toValue(),
      'cropConditionRequirement': cropConditionRequirement,
      'cropCondition': cropCondition,
      'cropShareRequired': cropShareRequired,
      'cropSharePercent': cropSharePercent,
      'maintenanceRequired': maintenanceRequired,
      'maintenanceIntervalHrs': maintenanceIntervalHrs,
      'hoursUsedSinceLastMaintenance': hoursUsedSinceLastMaintenance,
      'maintenanceCount': maintenanceCount,
      'majorBreakdownCount': majorBreakdownCount,
      'retirementFlaggedByAdmin': retirementFlaggedByAdmin,
      'retiredAt': retiredAt != null ? Timestamp.fromDate(retiredAt!) : null,
    };
  }

  factory Equipment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Equipment.fromMap(data, doc.id);
  }

  factory Equipment.fromMap(Map<String, dynamic> data, [String? docId]) {
    EquipmentStatus resolvedStatus;
    if (data['status'] != null) {
      resolvedStatus = EquipmentStatus.fromString(data['status'] as String?);
    } else if (data['isAvailable'] != null) {
      final oldIsAvailable = data['isAvailable'] is bool
          ? data['isAvailable'] as bool
          : data['isAvailable']?.toString().toLowerCase() == 'true';
      resolvedStatus = oldIsAvailable
          ? EquipmentStatus.available
          : EquipmentStatus.unavailable;
    } else {
      resolvedStatus = EquipmentStatus.available;
    }

    DateTime? asDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return null;
    }

    String? asTrimmedString(dynamic value) {
      final text = value as String?;
      if (text == null || text.trim().isEmpty) return null;
      return text;
    }

    return Equipment(
      id: docId,
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      nameEn: data['nameEn'] as String?,
      nameTl: data['nameTl'] as String?,
      descriptionEn: data['descriptionEn'] as String?,
      descriptionTl: data['descriptionTl'] as String?,
      category: asTrimmedString(data['category']),
      brand: asTrimmedString(data['brand']),
      yearModel: asTrimmedString(data['yearModel']),
      power: asTrimmedString(data['power']),
      condition: data['condition'] as String? ?? '',
      attachments: asTrimmedString(data['attachments']),
      fuelType: asTrimmedString(data['fuelType']),
      defects: asTrimmedString(data['defects']),
      damageReportCount: (data['damageReportCount'] as num?)?.toInt() ?? 0,
      price: (data['price'] as num?)?.toDouble() ?? 0,
      rentalUnit: data['rentalUnit'] as String? ?? 'Per Day',
      rentRate: data['rentRate'] as String? ?? '',
      requirements: data['requirements'] != null
          ? List<String>.from(data['requirements'] as List<dynamic>)
          : const [],
      landSizeRequirement: data['landSizeRequirement'] is bool
          ? data['landSizeRequirement'] as bool
          : data['landSizeRequirement']?.toString().toLowerCase() == 'true',
      maxCropHeightRequirement: data['maxCropHeightRequirement'] is bool
          ? data['maxCropHeightRequirement'] as bool
          : data['maxCropHeightRequirement']?.toString().toLowerCase() ==
                'true',
      landSizeMin: asTrimmedString(data['landSizeMin']),
      landSizeMax: asTrimmedString(data['landSizeMax']),
      maxCropHeight: asTrimmedString(data['maxCropHeight']),
      operatorIncluded: data['operatorIncluded'] as bool? ?? false,
      status: resolvedStatus,
      availableFrom: asDate(data['availableFrom']),
      availableUntil: asDate(data['availableUntil']),
      ownerId: data['ownerId'] as String? ?? '',
      ownerName: asTrimmedString(data['ownerName']),
      location: asTrimmedString(data['location']),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      barangay: asTrimmedString(data['barangay']),
      municipality: asTrimmedString(data['municipality']),
      province: asTrimmedString(data['province']),
      region: asTrimmedString(data['region']),
      imageUrls: data['imageUrls'] != null
          ? List<String>.from(data['imageUrls'] as List<dynamic>)
          : const [],
      reviews: data['reviews'] != null
          ? List<String>.from(data['reviews'] as List<dynamic>)
          : const [],
      createdAt: asDate(data['createdAt']),
      updatedAt: asDate(data['updatedAt']),
      minimumVolumeRequired: data['minimumVolumeRequired'] as bool? ?? false,
      minimumVolumeKg: (data['minimumVolumeKg'] as num?)?.toDouble(),
      minimumVolumeUnit: data['minimumVolumeUnit'] as String? ?? 'cavans',
      batchingAllowed: data['batchingAllowed'] as bool? ?? true,
      riceOnlyPricePerKg: (data['riceOnlyPricePerKg'] as num?)?.toDouble(),
      ricePlusDarakPricePerKg: (data['ricePlusDarakPricePerKg'] as num?)
          ?.toDouble(),
      maintenanceStart: asDate(data['maintenanceStart']),
      maintenanceEnd: asDate(data['maintenanceEnd']),
      deliveryMode: DeliveryMode.fromString(data['deliveryMode'] as String?),
      cropConditionRequirement: data['cropConditionRequirement'] is bool
          ? data['cropConditionRequirement'] as bool
          : data['cropConditionRequirement']?.toString().toLowerCase() ==
                'true',
      cropCondition: asTrimmedString(data['cropCondition']),
      cropShareRequired: data['cropShareRequired'] is bool
          ? data['cropShareRequired'] as bool
          : data['cropShareRequired']?.toString().toLowerCase() == 'true',
      cropSharePercent: (data['cropSharePercent'] as num?)?.toDouble(),
      maintenanceRequired: data['maintenanceRequired'] is bool
          ? data['maintenanceRequired'] as bool
          : data['maintenanceRequired']?.toString().toLowerCase() == 'true',
      maintenanceIntervalHrs:
          (data['maintenanceIntervalHrs'] as num?)?.toDouble() ?? 240,
      hoursUsedSinceLastMaintenance:
          (data['hoursUsedSinceLastMaintenance'] as num?)?.toDouble() ?? 0,
      maintenanceCount: (data['maintenanceCount'] as num?)?.toInt() ?? 0,
      majorBreakdownCount: (data['majorBreakdownCount'] as num?)?.toInt() ?? 0,
      retirementFlaggedByAdmin:
          data['retirementFlaggedByAdmin'] as bool? ?? false,
      retiredAt: asDate(data['retiredAt']),
    );
  }

  Equipment copyWith({
    String? name,
    String? description,
    String? nameEn,
    String? nameTl,
    String? descriptionEn,
    String? descriptionTl,
    String? category,
    String? brand,
    String? yearModel,
    String? power,
    String? condition,
    String? attachments,
    String? fuelType,
    String? defects,
    int? damageReportCount,
    double? price,
    String? rentalUnit,
    String? rentRate,
    List<String>? requirements,
    bool? landSizeRequirement,
    bool? maxCropHeightRequirement,
    String? landSizeMin,
    String? landSizeMax,
    String? maxCropHeight,
    bool? operatorIncluded,
    EquipmentStatus? status,
    DateTime? availableFrom,
    DateTime? availableUntil,
    String? ownerId,
    String? ownerName,
    String? location,
    double? latitude,
    double? longitude,
    String? barangay,
    String? municipality,
    String? province,
    String? region,
    List<String>? imageUrls,
    List<String>? reviews,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? minimumVolumeRequired,
    double? minimumVolumeKg,
    double? minimumVolumeCavans,
    String? minimumVolumeUnit,
    bool? batchingAllowed,
    double? riceOnlyPricePerKg,
    double? ricePlusDarakPricePerKg,
    DateTime? maintenanceStart,
    DateTime? maintenanceEnd,
    DeliveryMode? deliveryMode,
    bool? cropConditionRequirement,
    String? cropCondition,
    bool? cropShareRequired,
    double? cropSharePercent,
    bool? maintenanceRequired,
    double? maintenanceIntervalHrs,
    double? hoursUsedSinceLastMaintenance,
    int? maintenanceCount,
    int? majorBreakdownCount,
    bool? retirementFlaggedByAdmin,
    DateTime? retiredAt,
  }) {
    return Equipment(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      nameEn: nameEn ?? this.nameEn,
      nameTl: nameTl ?? this.nameTl,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      descriptionTl: descriptionTl ?? this.descriptionTl,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      yearModel: yearModel ?? this.yearModel,
      power: power ?? this.power,
      condition: condition ?? this.condition,
      attachments: attachments ?? this.attachments,
      fuelType: fuelType ?? this.fuelType,
      defects: defects ?? this.defects,
      damageReportCount: damageReportCount ?? this.damageReportCount,
      price: price ?? this.price,
      rentalUnit: rentalUnit ?? this.rentalUnit,
      rentRate: rentRate ?? this.rentRate,
      requirements: requirements ?? this.requirements,
      landSizeRequirement: landSizeRequirement ?? this.landSizeRequirement,
      maxCropHeightRequirement:
          maxCropHeightRequirement ?? this.maxCropHeightRequirement,
      landSizeMin: landSizeMin ?? this.landSizeMin,
      landSizeMax: landSizeMax ?? this.landSizeMax,
      maxCropHeight: maxCropHeight ?? this.maxCropHeight,
      operatorIncluded: operatorIncluded ?? this.operatorIncluded,
      status: status ?? this.status,
      availableFrom: availableFrom ?? this.availableFrom,
      availableUntil: availableUntil ?? this.availableUntil,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      barangay: barangay ?? this.barangay,
      municipality: municipality ?? this.municipality,
      province: province ?? this.province,
      region: region ?? this.region,
      imageUrls: imageUrls ?? this.imageUrls,
      reviews: reviews ?? this.reviews,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      minimumVolumeRequired:
          minimumVolumeRequired ?? this.minimumVolumeRequired,
      minimumVolumeKg: minimumVolumeKg ?? this.minimumVolumeKg,
      minimumVolumeCavans: minimumVolumeCavans ?? this.minimumVolumeCavans,
      minimumVolumeUnit: minimumVolumeUnit ?? this.minimumVolumeUnit,
      batchingAllowed: batchingAllowed ?? this.batchingAllowed,
      riceOnlyPricePerKg: riceOnlyPricePerKg ?? this.riceOnlyPricePerKg,
      ricePlusDarakPricePerKg:
          ricePlusDarakPricePerKg ?? this.ricePlusDarakPricePerKg,
      maintenanceStart: maintenanceStart ?? this.maintenanceStart,
      maintenanceEnd: maintenanceEnd ?? this.maintenanceEnd,
      deliveryMode: deliveryMode ?? this.deliveryMode,
      cropConditionRequirement:
          cropConditionRequirement ?? this.cropConditionRequirement,
      cropCondition: cropCondition ?? this.cropCondition,
      cropShareRequired: cropShareRequired ?? this.cropShareRequired,
      cropSharePercent: cropSharePercent ?? this.cropSharePercent,
      maintenanceRequired: maintenanceRequired ?? this.maintenanceRequired,
      maintenanceIntervalHrs:
          maintenanceIntervalHrs ?? this.maintenanceIntervalHrs,
      hoursUsedSinceLastMaintenance:
          hoursUsedSinceLastMaintenance ?? this.hoursUsedSinceLastMaintenance,
      maintenanceCount: maintenanceCount ?? this.maintenanceCount,
      majorBreakdownCount: majorBreakdownCount ?? this.majorBreakdownCount,
      retirementFlaggedByAdmin:
          retirementFlaggedByAdmin ?? this.retirementFlaggedByAdmin,
      retiredAt: retiredAt ?? this.retiredAt,
    );
  }
}
