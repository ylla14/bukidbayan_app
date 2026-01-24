class RentItem {
  final String id; // important for Firebase later
  final String title;
  final List<String> imageUrls;
  final String category;
  final String price;
  final String rentRate;
  final String? description; // NEW: equipment description

  // Availability
  final String? availableFrom;
  final String? availableTo;

  // Technical specs
  final String? brand;
  final String? yearModel;
  final String? power;
  final String? fuelType;
  final String? condition;
  final String? defects; // NEW: defects/issues description
  final String? attachments;
  final bool? operatorIncluded;

  // Requirements
  final bool landSizeRequirement;
  final int? landSizeMin;
  final int? landSizeMax;

  final bool maxCropHeightRequirement;
  final double? maxCropHeight;

  RentItem({
    required this.id,
    required this.title,
    required this.imageUrls,
    required this.category,
    required this.price,
    required this.rentRate,
    required this.landSizeRequirement,
    required this.maxCropHeightRequirement,
    this.landSizeMin,
    this.landSizeMax,
    this.maxCropHeight,
    this.availableFrom,
    this.availableTo,
    this.brand,
    this.yearModel,
    this.power,
    this.fuelType,
    this.condition,
    this.defects, // include in constructor
    this.attachments,
    this.operatorIncluded,
    this.description,
  });

  /// 🔁 Firebase → App
  factory RentItem.fromMap(String id, Map<String, dynamic> data) {
    return RentItem(
      id: id,
      title: data['title'],
      imageUrls: List<String>.from(data['imageUrls']),
      category: data['category'],
      price: data['price'],
      rentRate: data['rentRate'],
      availableFrom: data['availableFrom'],
      availableTo: data['availableTo'],
      brand: data['brand'],
      yearModel: data['yearModel'],
      power: data['power'],
      fuelType: data['fuelType'],
      condition: data['condition'],
      defects: data['defects'], // map defects
      attachments: data['attachments'],
      operatorIncluded: data['operatorIncluded'],
      landSizeRequirement: data['landSizeRequirement'],
      landSizeMin: data['landSizeMin'],
      landSizeMax: data['landSizeMax'],
      maxCropHeightRequirement: data['maxCropHeightRequirement'],
      maxCropHeight: data['maxCropHeight'],
      description: data['description'],
    );
  }

  /// 🔁 App → Firebase
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'imageUrls': imageUrls,
      'category': category,
      'price': price,
      'rentRate': rentRate,
      'availableFrom': availableFrom,
      'availableTo': availableTo,
      'brand': brand,
      'yearModel': yearModel,
      'power': power,
      'fuelType': fuelType,
      'condition': condition,
      'defects': defects, // map defects
      'attachments': attachments,
      'operatorIncluded': operatorIncluded,
      'landSizeRequirement': landSizeRequirement,
      'landSizeMin': landSizeMin,
      'landSizeMax': landSizeMax,
      'maxCropHeightRequirement': maxCropHeightRequirement,
      'maxCropHeight': maxCropHeight,
      'description': description,
    };
  }
}