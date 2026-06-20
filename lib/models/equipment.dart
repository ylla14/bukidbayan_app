import 'package:cloud_firestore/cloud_firestore.dart';

enum EquipmentStatus {
  available,
  unavailable,
  underMaintenance;

  static EquipmentStatus fromString(String? value) {
    switch (value) {
      case 'available': return EquipmentStatus.available;
      case 'unavailable': return EquipmentStatus.unavailable;
      case 'under_maintenance': return EquipmentStatus.underMaintenance;
      // migration fallback for old bool-based docs
      default: return EquipmentStatus.available;
    }
  }

  String toValue() {
    switch (this) {
      case EquipmentStatus.available: return 'available';
      case EquipmentStatus.unavailable: return 'unavailable';
      case EquipmentStatus.underMaintenance: return 'under_maintenance';
    }
  }
}

// ── New enum ──────────────────────────────────────────────────────────────
enum DeliveryMode {
  pickupOnly,
  deliveryOnly,
  both;

  static DeliveryMode fromString(String? value) {
    switch (value) {
      case 'pickup_only':   return DeliveryMode.pickupOnly;
      case 'delivery_only': return DeliveryMode.deliveryOnly;
      case 'both':          return DeliveryMode.both;
      default:              return DeliveryMode.both; // safe fallback
    }
  }

  String toValue() {
    switch (this) {
      case DeliveryMode.pickupOnly:   return 'pickup_only';
      case DeliveryMode.deliveryOnly: return 'delivery_only';
      case DeliveryMode.both:         return 'both';
    }
  }
}

class Equipment {
  final String? id;

  final String name;
  final String description;

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

  // NEW: replaces isAvailable
  final EquipmentStatus status; 
  // GETTER: backward-compatible, no breaking changes elsewhere
  bool get isAvailable => status == EquipmentStatus.available;

  final DateTime? availableFrom;
  final DateTime? availableUntil;

  final String ownerId;
  final String? ownerName;
  final String? location;
  final double? latitude;
  final double? longitude;

  final List<String> imageUrls;
  final List<String> reviews;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final bool minimumVolumeRequired;
  final double? minimumVolumeKg;       // stored in kg internally
  final double? minimumVolumeCavans;   // convenience getter (1 cavan ≈ 50 kg)
  final String minimumVolumeUnit;      // 'kg' or 'cavans'
  final bool batchingAllowed;          // if true, suggest batching for small loads

  double? get minimumVolumeInCavans =>
    minimumVolumeKg != null ? minimumVolumeKg! / 50.0 : null;
  
  final double? riceOnlyPricePerKg;
  final double? ricePlusDarakPricePerKg;

    final DateTime? maintenanceStart;
  final DateTime? maintenanceEnd;
  
  final DeliveryMode deliveryMode; // NEW

  final bool cropConditionRequirement;
final String? cropCondition;
// After cropCondition field
final bool cropShareRequired;
final double? cropSharePercent; // max 15.0

final bool maintenanceRequired;
final double maintenanceIntervalHrs;        // default 240
final double hoursUsedSinceLastMaintenance; // accumulated rental hours

/// Hours remaining before maintenance is due.
double get remainingMaintenanceHrs =>
    maintenanceIntervalHrs - hoursUsedSinceLastMaintenance;

/// True when ≤ 48 hours remain but maintenance is not yet overdue.
bool get isUpcomingMaintenance =>
    remainingMaintenanceHrs <= 48 && remainingMaintenanceHrs > 0;

/// True when accumulated hours have reached or exceeded the interval.
bool get isForMaintenance =>
    hoursUsedSinceLastMaintenance >= maintenanceIntervalHrs;

  Equipment({
    this.id,
    required this.name,
    required this.description,
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
    this.cropConditionRequirement = false,
    this.cropCondition,
    this.operatorIncluded = false,
    this.status = EquipmentStatus.available,
    this.availableFrom,
    this.availableUntil,
    required this.ownerId,
    this.ownerName,
    this.location,
    this.latitude,
    this.longitude,
    this.imageUrls = const [],
    this.reviews = const [],
    this.createdAt,
    this.updatedAt,
    this.minimumVolumeRequired = false,
    this.minimumVolumeKg,
    this.minimumVolumeUnit = 'cavans',
    this.batchingAllowed = true,
    this.minimumVolumeCavans,
    this.riceOnlyPricePerKg,
    this.ricePlusDarakPricePerKg,
    this.maintenanceStart,
    this.maintenanceEnd,
    this.deliveryMode = DeliveryMode.both,
    this.cropShareRequired = false,
this.cropSharePercent,
this.maintenanceRequired = false,
this.maintenanceIntervalHrs = 240,
this.hoursUsedSinceLastMaintenance = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
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
      'cropConditionRequirement': cropConditionRequirement,
      'cropCondition': cropCondition,
      'operatorIncluded': operatorIncluded,
      'status': status.toValue(),
      'availableFrom': availableFrom != null ? Timestamp.fromDate(availableFrom!) : null,
      'availableUntil': availableUntil != null ? Timestamp.fromDate(availableUntil!) : null,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrls': imageUrls,
      'reviews': reviews,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'minimumVolumeRequired': minimumVolumeRequired,
      'minimumVolumeKg': minimumVolumeKg,
      'minimumVolumeUnit': minimumVolumeUnit,
      'batchingAllowed': batchingAllowed,
      'riceOnlyPricePerKg': riceOnlyPricePerKg,
      'ricePlusDarakPricePerKg': ricePlusDarakPricePerKg,
        'maintenanceStart': maintenanceStart != null ? Timestamp.fromDate(maintenanceStart!) : null,
  'maintenanceEnd': maintenanceEnd != null ? Timestamp.fromDate(maintenanceEnd!) : null,
  'deliveryMode': deliveryMode.toValue(),
  'cropShareRequired': cropShareRequired,
'cropSharePercent': cropSharePercent,
'maintenanceRequired': maintenanceRequired,
'maintenanceIntervalHrs': maintenanceIntervalHrs,
'hoursUsedSinceLastMaintenance': hoursUsedSinceLastMaintenance,
    };
  }

  factory Equipment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Graceful migration: if old doc has isAvailable but no status, derive it
    EquipmentStatus resolvedStatus;
    if (data['status'] != null) {
      resolvedStatus = EquipmentStatus.fromString(data['status']);
    } else if (data['isAvailable'] != null) {
      final oldIsAvailable = data['isAvailable'] is bool
          ? data['isAvailable']
          : data['isAvailable']?.toString().toLowerCase() == 'true';
      resolvedStatus = oldIsAvailable ? EquipmentStatus.available : EquipmentStatus.unavailable;
    } else {
      resolvedStatus = EquipmentStatus.available;
    }

    return Equipment(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'],
      power: (data['power'] as String?)?.isNotEmpty == true ? data['power'] : null,
      brand: (data['brand'] as String?)?.isNotEmpty == true ? data['brand'] : null,
      fuelType: (data['fuelType'] as String?)?.isNotEmpty == true ? data['fuelType'] : null,
      yearModel: (data['yearModel'] as String?)?.isNotEmpty == true ? data['yearModel'] : null,
      condition: data['condition'] ?? '',
      attachments: data['attachments'],
      defects: data['defects'],
      damageReportCount: (data['damageReportCount'] as int?) ?? 0,
      price: (data['price'] ?? 0).toDouble(),
      rentalUnit: data['rentalUnit'] ?? 'Per Day',
      rentRate: data['rentRate'] ?? '',
      requirements: data['requirements'] != null ? List<String>.from(data['requirements']) : [],
      landSizeRequirement: data['landSizeRequirement'] is bool
          ? data['landSizeRequirement']
          : data['landSizeRequirement'] == 'true',
      maxCropHeightRequirement: data['maxCropHeightRequirement'] is bool
          ? data['maxCropHeightRequirement']
          : data['maxCropHeightRequirement'] == 'true',
      landSizeMin: (data['landSizeMin'] as String?)?.isNotEmpty == true ? data['landSizeMin'] : null,
      landSizeMax: (data['landSizeMax'] as String?)?.isNotEmpty == true ? data['landSizeMax'] : null,
      maxCropHeight: (data['maxCropHeight'] as String?)?.isNotEmpty == true ? data['maxCropHeight'] : null,
      cropConditionRequirement: data['cropConditionRequirement'] is bool
          ? data['cropConditionRequirement']
          : data['cropConditionRequirement']?.toString().toLowerCase() == 'true',
      cropCondition: (data['cropCondition'] as String?)?.isNotEmpty == true ? data['cropCondition'] : null,
      operatorIncluded: data['operatorIncluded'] ?? false,
      status: resolvedStatus, // NEW
      availableFrom: data['availableFrom'] != null ? (data['availableFrom'] as Timestamp).toDate() : null,
      availableUntil: data['availableUntil'] != null ? (data['availableUntil'] as Timestamp).toDate() : null,
      ownerId: data['ownerId'] ?? '',
      ownerName: data['ownerName'],
      location: data['location'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      imageUrls: data['imageUrls'] != null ? List<String>.from(data['imageUrls']) : [],
      reviews: data['reviews'] != null ? List<String>.from(data['reviews']) : [],
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      minimumVolumeRequired: data['minimumVolumeRequired'] ?? false,
      minimumVolumeKg: data['minimumVolumeKg']?.toDouble(),
      minimumVolumeUnit: data['minimumVolumeUnit'] ?? 'cavans',
      batchingAllowed: data['batchingAllowed'] ?? true,
      riceOnlyPricePerKg: (data['riceOnlyPricePerKg'] as num?)?.toDouble(),
      ricePlusDarakPricePerKg: (data['ricePlusDarakPricePerKg'] as num?)?.toDouble(),
      maintenanceStart: data['maintenanceStart'] != null ? (data['maintenanceStart'] as Timestamp).toDate() : null,
  maintenanceEnd: data['maintenanceEnd'] != null ? (data['maintenanceEnd'] as Timestamp).toDate() : null,
  deliveryMode: DeliveryMode.fromString(data['deliveryMode']),
  cropShareRequired: data['cropShareRequired'] is bool
    ? data['cropShareRequired']
    : data['cropShareRequired']?.toString().toLowerCase() == 'true',
cropSharePercent: (data['cropSharePercent'] as num?)?.toDouble(),
maintenanceRequired: data['maintenanceRequired'] is bool
    ? data['maintenanceRequired']
    : data['maintenanceRequired']?.toString().toLowerCase() == 'true',
maintenanceIntervalHrs: (data['maintenanceIntervalHrs'] as num?)?.toDouble() ?? 240,
hoursUsedSinceLastMaintenance:
    (data['hoursUsedSinceLastMaintenance'] as num?)?.toDouble() ?? 0,
    );
  }

factory Equipment.fromMap(Map<String, dynamic> data, [String? docId]) {
    EquipmentStatus resolvedStatus;
    if (data['status'] != null) {
      resolvedStatus = EquipmentStatus.fromString(data['status']);
    } else if (data['isAvailable'] != null) {
      final oldIsAvailable = data['isAvailable'] is bool
          ? data['isAvailable']
          : data['isAvailable']?.toString().toLowerCase() == 'true';
      resolvedStatus = oldIsAvailable ? EquipmentStatus.available : EquipmentStatus.unavailable;
    } else {
      resolvedStatus = EquipmentStatus.available;
    }
    return Equipment(
      id: docId,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: (data['category'] as String?)?.isNotEmpty == true ? data['category'] : null,
      brand: (data['brand'] as String?)?.isNotEmpty == true ? data['brand'] : null,
      yearModel: (data['yearModel'] as String?)?.isNotEmpty == true ? data['yearModel'] : null,
      power: (data['power'] as String?)?.isNotEmpty == true ? data['power'] : null,
      condition: data['condition'] ?? '',
      attachments: (data['attachments'] as String?)?.isNotEmpty == true ? data['attachments'] : null,
      fuelType: (data['fuelType'] as String?)?.isNotEmpty == true ? data['fuelType'] : null,
      defects: (data['defects'] as String?)?.isNotEmpty == true ? data['defects'] : null,
      damageReportCount: (data['damageReportCount'] as int?) ?? 0,
      price: (data['price'] ?? 0).toDouble(),
      rentalUnit: data['rentalUnit'] ?? 'Per Day',
      rentRate: data['rentRate'] ?? '',
      requirements: data['requirements'] != null ? List<String>.from(data['requirements']) : [],
      landSizeRequirement: data['landSizeRequirement'] is bool
          ? data['landSizeRequirement']
          : data['landSizeRequirement']?.toString().toLowerCase() == 'true',
      maxCropHeightRequirement: data['maxCropHeightRequirement'] is bool
          ? data['maxCropHeightRequirement']
          : data['maxCropHeightRequirement']?.toString().toLowerCase() == 'true',
      landSizeMin: (data['landSizeMin'] as String?)?.isNotEmpty == true ? data['landSizeMin'] : null,
      landSizeMax: (data['landSizeMax'] as String?)?.isNotEmpty == true ? data['landSizeMax'] : null,
      maxCropHeight: (data['maxCropHeight'] as String?)?.isNotEmpty == true ? data['maxCropHeight'] : null,
      cropConditionRequirement: data['cropConditionRequirement'] is bool
          ? data['cropConditionRequirement']
          : data['cropConditionRequirement']?.toString().toLowerCase() == 'true',
      cropCondition: (data['cropCondition'] as String?)?.isNotEmpty == true ? data['cropCondition'] : null,
      operatorIncluded: data['operatorIncluded'] ?? false,
      status: resolvedStatus, // NEW
      availableFrom: data['availableFrom'] is Timestamp ? (data['availableFrom'] as Timestamp).toDate() : null,
      availableUntil: data['availableUntil'] is Timestamp ? (data['availableUntil'] as Timestamp).toDate() : null,
      ownerId: data['ownerId'] ?? '',
      ownerName: data['ownerName'],
      location: data['location'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      imageUrls: data['imageUrls'] != null ? List<String>.from(data['imageUrls']) : [],
      reviews: data['reviews'] != null ? List<String>.from(data['reviews']) : [],
      createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : null,
      updatedAt: data['updatedAt'] is Timestamp ? (data['updatedAt'] as Timestamp).toDate() : null,
      minimumVolumeRequired: data['minimumVolumeRequired'] ?? false,
      minimumVolumeKg: data['minimumVolumeKg']?.toDouble(),
      minimumVolumeUnit: data['minimumVolumeUnit'] ?? 'cavans',
      batchingAllowed: data['batchingAllowed'] ?? true,
      riceOnlyPricePerKg: (data['riceOnlyPricePerKg'] as num?)?.toDouble(),
      ricePlusDarakPricePerKg: (data['ricePlusDarakPricePerKg'] as num?)?.toDouble(),
      maintenanceStart: data['maintenanceStart'] != null ? (data['maintenanceStart'] as Timestamp).toDate() : null,
  maintenanceEnd: data['maintenanceEnd'] != null ? (data['maintenanceEnd'] as Timestamp).toDate() : null,
  deliveryMode: DeliveryMode.fromString(data['deliveryMode']),
  cropShareRequired: data['cropShareRequired'] is bool
    ? data['cropShareRequired']
    : data['cropShareRequired']?.toString().toLowerCase() == 'true',
cropSharePercent: (data['cropSharePercent'] as num?)?.toDouble(),
maintenanceRequired: data['maintenanceRequired'] is bool
    ? data['maintenanceRequired']
    : data['maintenanceRequired']?.toString().toLowerCase() == 'true',
maintenanceIntervalHrs: (data['maintenanceIntervalHrs'] as num?)?.toDouble() ?? 240,
hoursUsedSinceLastMaintenance:
    (data['hoursUsedSinceLastMaintenance'] as num?)?.toDouble() ?? 0,
    );
  }

  Equipment copyWith({
    String? name,
    String? description,
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
    bool? operatorIncluded,
    String? landSizeMin,
    String? landSizeMax,
    String? maxCropHeight,
    bool? cropConditionRequirement,
    String? cropCondition,
    EquipmentStatus? status,
    DateTime? availableFrom,
    DateTime? availableUntil,
    String? ownerId,
    String? ownerName,
    String? location,
    double? latitude,
    double? longitude,
    List<String>? imageUrls,
    List<String>? reviews,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? minimumVolumeRequired,
    double? minimumVolumeKg,
    String? minimumVolumeUnit,
    bool? batchingAllowed,
    double? riceOnlyPricePerKg,
    double? ricePlusDarakPricePerKg,
      DateTime? maintenanceStart,
  DateTime? maintenanceEnd,
  DeliveryMode? deliveryMode,
  bool? cropShareRequired,
double? cropSharePercent,
bool? maintenanceRequired,
double? maintenanceIntervalHrs,
double? hoursUsedSinceLastMaintenance,
  }) {
    return Equipment(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
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
      maxCropHeightRequirement: maxCropHeightRequirement ?? this.maxCropHeightRequirement,
      operatorIncluded: operatorIncluded ?? this.operatorIncluded,
      landSizeMin: landSizeMin ?? this.landSizeMin,
      landSizeMax: landSizeMax ?? this.landSizeMax,
      maxCropHeight: maxCropHeight ?? this.maxCropHeight,
      cropConditionRequirement: cropConditionRequirement ?? this.cropConditionRequirement,
      cropCondition: cropCondition ?? this.cropCondition,
      status: status ?? this.status, // NEW
      availableFrom: availableFrom ?? this.availableFrom,
      availableUntil: availableUntil ?? this.availableUntil,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrls: imageUrls ?? this.imageUrls,
      reviews: reviews ?? this.reviews,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      minimumVolumeRequired: minimumVolumeRequired ?? this.minimumVolumeRequired,
      minimumVolumeKg: minimumVolumeKg ?? this.minimumVolumeKg,
      minimumVolumeUnit: minimumVolumeUnit ?? this.minimumVolumeUnit,
      batchingAllowed: batchingAllowed ?? this.batchingAllowed,
      riceOnlyPricePerKg: riceOnlyPricePerKg ?? this.riceOnlyPricePerKg,
      ricePlusDarakPricePerKg: ricePlusDarakPricePerKg ?? this.ricePlusDarakPricePerKg,
        maintenanceStart: maintenanceStart ?? this.maintenanceStart,
      maintenanceEnd: maintenanceEnd ?? this.maintenanceEnd,
      deliveryMode: deliveryMode ?? this.deliveryMode,
      cropShareRequired: cropShareRequired ?? this.cropShareRequired,
      cropSharePercent: cropSharePercent ?? this.cropSharePercent,
      maintenanceRequired: maintenanceRequired ?? this.maintenanceRequired,
      maintenanceIntervalHrs: maintenanceIntervalHrs ?? this.maintenanceIntervalHrs,
      hoursUsedSinceLastMaintenance:
          hoursUsedSinceLastMaintenance ?? this.hoursUsedSinceLastMaintenance,
    );
  }
}