import 'package:cloud_firestore/cloud_firestore.dart';

class Equipment {
  final String? id; // Firestore document ID
  final String name; // REQUIRED
  final String description; // REQUIRED
  final String? category; // e.g., Hand Tool, Tractor, Machine
  final String? brand;
  final String? yearModel;
  final String power; // REQUIRED - e.g., "75 HP" or "Manual"
  final String condition; // REQUIRED - Brand New, Excellent, Good, Fair, Needs Maintenance
  final String? attachments; // e.g., "Plow, Harrow"
  final bool operatorIncluded; // Operator inclusion status
  final DateTime? availableFrom; // Availability date range
  final DateTime? availableUntil;
  final List<String> requirements; // Usage requirements (land size, crop height, etc.)
  final List<String> reviews; // Array of review IDs or review content

  // Pricing information
  final double price; // Rental price
  final String rentalUnit; // Per Hour, Per Day, Per Week, Per Month

  // Owner and location information
  final String ownerId; // User ID of the equipment owner
  final String? ownerName;
  final String? location; // For location proximity filtering
  final double? latitude;
  final double? longitude;

  // Image URLs (using external URLs since no Firebase Storage on free plan)
  final List<String> imageUrls;

  // Additional fields
  final String? fuelType;
  final String? defects; // For equipment that needs maintenance
  final bool isAvailable; // Quick availability check

  // Timestamps
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Equipment({
    this.id,
    required this.name,
    required this.description,
    this.category,
    this.brand,
    this.yearModel,
    required this.power,
    required this.condition,
    this.attachments,
    this.operatorIncluded = false,
    this.availableFrom,
    this.availableUntil,
    this.requirements = const [],
    this.reviews = const [],
    required this.price,
    required this.rentalUnit,
    required this.ownerId,
    this.ownerName,
    this.location,
    this.latitude,
    this.longitude,
    this.imageUrls = const [],
    this.fuelType,
    this.defects,
    this.isAvailable = true,
    this.createdAt,
    this.updatedAt,
  });

  // Convert Equipment to Map for Firestore
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
      'operatorIncluded': operatorIncluded,
      'availableFrom': availableFrom != null ? Timestamp.fromDate(availableFrom!) : null,
      'availableUntil': availableUntil != null ? Timestamp.fromDate(availableUntil!) : null,
      'requirements': requirements,
      'reviews': reviews,
      'price': price,
      'rentalUnit': rentalUnit,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrls': imageUrls,
      'fuelType': fuelType,
      'defects': defects,
      'isAvailable': isAvailable,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  // Create Equipment from Firestore DocumentSnapshot
  factory Equipment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Equipment(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      category: data['category'],
      brand: data['brand'],
      yearModel: data['yearModel'],
      power: data['power'] ?? '',
      condition: data['condition'] ?? '',
      attachments: data['attachments'],
      operatorIncluded: data['operatorIncluded'] ?? false,
      availableFrom: data['availableFrom'] != null
          ? (data['availableFrom'] as Timestamp).toDate()
          : null,
      availableUntil: data['availableUntil'] != null
          ? (data['availableUntil'] as Timestamp).toDate()
          : null,
      requirements: data['requirements'] != null
          ? List<String>.from(data['requirements'])
          : [],
      reviews: data['reviews'] != null
          ? List<String>.from(data['reviews'])
          : [],
      price: (data['price'] ?? 0).toDouble(),
      rentalUnit: data['rentalUnit'] ?? 'Per Day',
      ownerId: data['ownerId'] ?? '',
      ownerName: data['ownerName'],
      location: data['location'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      imageUrls: data['imageUrls'] != null
          ? List<String>.from(data['imageUrls'])
          : [],
      fuelType: data['fuelType'],
      defects: data['defects'],
      isAvailable: data['isAvailable'] ?? true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Create a copy of Equipment with updated fields
  Equipment copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    String? brand,
    String? yearModel,
    String? power,
    String? condition,
    String? attachments,
    bool? operatorIncluded,
    DateTime? availableFrom,
    DateTime? availableUntil,
    List<String>? requirements,
    List<String>? reviews,
    double? price,
    String? rentalUnit,
    String? ownerId,
    String? ownerName,
    String? location,
    double? latitude,
    double? longitude,
    List<String>? imageUrls,
    String? fuelType,
    String? defects,
    bool? isAvailable,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Equipment(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      yearModel: yearModel ?? this.yearModel,
      power: power ?? this.power,
      condition: condition ?? this.condition,
      attachments: attachments ?? this.attachments,
      operatorIncluded: operatorIncluded ?? this.operatorIncluded,
      availableFrom: availableFrom ?? this.availableFrom,
      availableUntil: availableUntil ?? this.availableUntil,
      requirements: requirements ?? this.requirements,
      reviews: reviews ?? this.reviews,
      price: price ?? this.price,
      rentalUnit: rentalUnit ?? this.rentalUnit,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrls: imageUrls ?? this.imageUrls,
      fuelType: fuelType ?? this.fuelType,
      defects: defects ?? this.defects,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
