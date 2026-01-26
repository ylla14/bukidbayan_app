import 'package:cloud_firestore/cloud_firestore.dart';

class Equipment {
  final String? id; // Firestore document ID

  // REQUIRED BASIC INFO
  final String name;
  final String description;

  // CLASSIFICATION
  final String? category;
  final String? brand;
  final String? yearModel;

  // TECHNICAL DETAILS
  final String? power;
  final String condition;
  final String? attachments;
  final String? fuelType;
  final String? defects;

  // RENTAL DETAILS
  final double price;
  final String rentalUnit; // Per Hour, Per Day, etc.
  final String rentRate; // NEW (e.g., "Fixed", "Negotiable")

  // REQUIREMENTS
  final List<String> requirements;
  final bool landSizeRequirement; // NEW (hectares, sqm, etc.)
  final bool maxCropHeightRequirement; // NEW (cm or meters)
  final String? landSizeMin; // optional
  final String? landSizeMax; // optional
  final String? maxCropHeight; // optional

  // OPERATOR & AVAILABILITY
  final bool operatorIncluded;
  final bool isAvailable;
  final DateTime? availableFrom;
  final DateTime? availableUntil;

  // OWNER & LOCATION
  final String ownerId;
  final String? ownerName;
  final String? location;
  final double? latitude;
  final double? longitude;

  // MEDIA & REVIEWS
  final List<String> imageUrls;
  final List<String> reviews;

  // TIMESTAMPS
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    this.isAvailable = true,
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
  });

  // TO FIRESTORE
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
      'isAvailable': isAvailable,
      'availableFrom':
          availableFrom != null ? Timestamp.fromDate(availableFrom!) : null,
      'availableUntil':
          availableUntil != null ? Timestamp.fromDate(availableUntil!) : null,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrls': imageUrls,
      'reviews': reviews,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  // FROM FIRESTORE
  factory Equipment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Equipment(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'],
      // brand: data['brand'],
      // yearModel: data['yearModel'],
      // power: data['power'] ?? '',
      power: (data['power'] as String?)?.isNotEmpty == true
        ? data['power']
        : null,
      brand: (data['brand'] as String?)?.isNotEmpty == true
          ? data['brand']
          : null,
      fuelType: (data['fuelType'] as String?)?.isNotEmpty == true
          ? data['fuelType']
          : null,
      yearModel: (data['yearModel'] as String?)?.isNotEmpty == true
          ? data['brand']
          : null,
      condition: data['condition'] ?? '',
      attachments: data['attachments'],
      // fuelType: data['fuelType'],
      defects: data['defects'],
      price: (data['price'] ?? 0).toDouble(),
      rentalUnit: data['rentalUnit'] ?? 'Per Day',
      rentRate: data['rentRate'] ?? '',
      requirements: data['requirements'] != null
          ? List<String>.from(data['requirements'])
          : [],
      landSizeRequirement: data['landSizeRequirement'] is bool
          ? data['landSizeRequirement']
          : data['landSizeRequirement'] == 'true',
      maxCropHeightRequirement: data['maxCropHeightRequirement'] is bool
          ? data['maxCropHeightRequirement']
          : data['maxCropHeightRequirement'] == 'true',

     landSizeMin: (data['landSizeMin'] as String?)?.isNotEmpty == true
          ? data['landSizeMin']
          : null,
      landSizeMax: (data['landSizeMax'] as String?)?.isNotEmpty == true
          ? data['landSizeMax']
          : null,
      maxCropHeight: (data['maxCropHeight'] as String?)?.isNotEmpty == true
          ? data['maxCropHeight']
          : null,


      operatorIncluded: data['operatorIncluded'] ?? false,
      isAvailable: data['isAvailable'] ?? true,
      availableFrom: data['availableFrom'] != null
          ? (data['availableFrom'] as Timestamp).toDate()
          : null,
      availableUntil: data['availableUntil'] != null
          ? (data['availableUntil'] as Timestamp).toDate()
          : null,
      ownerId: data['ownerId'] ?? '',
      ownerName: data['ownerName'],
      location: data['location'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      imageUrls: data['imageUrls'] != null
          ? List<String>.from(data['imageUrls'])
          : [],
      reviews: data['reviews'] != null
          ? List<String>.from(data['reviews'])
          : [],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // COPY WITH
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
    double? price,
    String? rentalUnit,
    String? rentRate,
    List<String>? requirements,
    bool? landSizeRequirement,
    bool? maxCropHeightRequirement,
    bool? operatorIncluded,
    final String? landSizeMin, // optional
    final String? landSizeMax, // optional
    final String? maxCropHeight, // optional
    bool? isAvailable,
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
      price: price ?? this.price,
      rentalUnit: rentalUnit ?? this.rentalUnit,
      rentRate: rentRate ?? this.rentRate,
      requirements: requirements ?? this.requirements,
      landSizeRequirement: landSizeRequirement ?? this.landSizeRequirement,
      maxCropHeightRequirement: maxCropHeightRequirement ?? this.maxCropHeightRequirement,
      operatorIncluded:
          operatorIncluded ?? this.operatorIncluded,
      landSizeMin: landSizeMin ?? this.landSizeMin,
      landSizeMax: landSizeMax ?? this.landSizeMax,
      maxCropHeight: maxCropHeight ?? this.maxCropHeight,   
      isAvailable: isAvailable ?? this.isAvailable,
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
    );
  }
}
