class RentItem {
  final String title;
  final List<String> imageUrl;
  final String category;
  final String price;

  // Rent rate (required)
  final String rentRate; // e.g. "per day", "per week"

  // Availability
  final String? availableFrom;
  final String? availableTo;

  // Optional technical specifications
  final String? brand;
  final String? yearModel;
  final String? power;
  final String? fuelType;
  final String? condition;
  final String? attachments;
  final bool? operatorIncluded;

  // Requirements
  final bool landSizeRequirement; // REQUIRED
  final int? landSizeMin; // optional
  final int? landSizeMax; // optional

  final bool maxCropHeightRequirement; // REQUIRED
  final double? maxCropHeight; // optional

  RentItem({
    required this.title,
    required this.imageUrl,
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
    this.attachments,
    this.operatorIncluded,
  });
}



final List<RentItem> items = [
  RentItem(
    title: "Item 1",
    imageUrl: [
      'assets/images/rent1.jpg',
      'assets/images/rent3.jpeg',
      'assets/images/rent5.jpeg',
    ],
    category: "Hand Tool",
    price: "105",
    rentRate: "per day", // new
    availableFrom: "Jan 20, 2026",
    availableTo: "Feb 10, 2026",
    brand: "Makita",
    condition: "Good",
    landSizeRequirement: false,
    maxCropHeightRequirement: false,
  ),
  RentItem(
    title: "Item 2",
    imageUrl: [
      'assets/images/rent4.jpeg',
      'assets/images/rent5.jpeg',
    ],
    category: "Tractor",
    price: "200",
    rentRate: "per day",
    availableFrom: "Jan 25, 2026",
    availableTo: "Mar 01, 2026",
    brand: "John Deere",
    yearModel: "2019",
    power: "75 HP",
    fuelType: "Diesel",
    operatorIncluded: true,
    landSizeRequirement: true,
    landSizeMin: 500, // optional min size
    landSizeMax: 1000, // optional max size
    maxCropHeightRequirement: true,
    maxCropHeight: 120, // optional height in cm
  ),
  RentItem(
    title: "Item 3",
    imageUrl: [
      'assets/images/rent6.jpeg',
      'assets/images/rent3.jpeg',
      'assets/images/rent5.jpeg',
    ],
    category: "Machine",
    price: "50",
    rentRate: "per day",
    availableFrom: "Feb 01, 2026",
    availableTo: "Feb 15, 2026",
    condition: "Used",
    landSizeRequirement: false,
    maxCropHeightRequirement: true,
    maxCropHeight: 80,
  ),
  RentItem(
    title: "Item 4",
    imageUrl: [
      'assets/images/rent7.jpeg',
      'assets/images/rent4.jpeg',
      'assets/images/rent8.jpg',
    ],
    category: "Machine",
    price: "90",
    rentRate: "per day",
    availableFrom: "Jan 18, 2026",
    availableTo: "Apr 30, 2026",
    brand: "Caterpillar",
    yearModel: "2020",
    fuelType: "Diesel",
    attachments: "Bucket, Blade",
    landSizeRequirement: true,
    maxCropHeightRequirement: false,
  ),
  RentItem(
    title: "Item 5",
    imageUrl: [
      'assets/images/rent3.jpeg',
      'assets/images/rent5.jpeg',
    ],
    category: "Machine",
    price: "300",
    rentRate: "per day",
    availableFrom: "Mar 01, 2026",
    availableTo: "Mar 20, 2026",
    power: "150 HP",
    operatorIncluded: false,
    landSizeRequirement: false,
    maxCropHeightRequirement: false,
  ),
];
