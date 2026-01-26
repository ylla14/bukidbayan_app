class RentItem {
  final String title;
  final List<String> imageUrl;
  final String category;
  final String price;
  final String id;
  final String description;

  // Rent rate (required)
  final String rentalUnit; // e.g. "per day", "per week"
  final String? rentRate;

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
  final String? landSizeMin; // optional
  final String? landSizeMax; // optional

  final bool maxCropHeightRequirement; // REQUIRED
  final String? maxCropHeight; // optional

  // NEW: Owner Name
  final String? ownerName;

  RentItem({
    required this.title,
    required this.imageUrl,
    required this.category,
    required this.price,
    required this.rentalUnit,
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
    this.rentRate,
    required this.id,
    required this.description,
    this.ownerName, // <-- add here
  });
}


final testItem = RentItem(
  id: '1',
  title: 'Mini Tractor',
  imageUrl: ['assets/images/rent1.jpg', 'assets/images/rent3.jpeg'],
  category: 'Tractor',
  price: '1500',
  rentalUnit: 'per day',
  landSizeRequirement: true,
  landSizeMin: '500',   // ✅ Hardcoded value
  landSizeMax: '2000',  // ✅ Hardcoded value
  maxCropHeightRequirement: true,
  maxCropHeight: '120', // ✅ Hardcoded value
  description: 'A reliable mini tractor suitable for small to medium farms.',
  brand: 'John Deere',
  yearModel: '2020',
  power: '75 HP',
  fuelType: 'Diesel',
  condition: 'Good',
  attachments: 'Plow, Harrow',
  operatorIncluded: true,
);




final List<RentItem> items = [
  RentItem(
    id: "1",
    title: "Item 1",
    imageUrl: [
      'assets/images/rent1.jpg',
      'assets/images/rent3.jpeg',
      'assets/images/rent5.jpeg',
    ],
    category: "Hand Tool",
    price: "105",
    rentalUnit: "per day", // new
    availableFrom: "Jan 20, 2026",
    availableTo: "Feb 10, 2026",
    brand: "Makita",
    condition: "Good",
    landSizeRequirement: false,
    maxCropHeightRequirement: false,
    description: "A reliable hand tool suitable for small farming and gardening tasks.",

  ),
  RentItem(
    id: "2",
    title: "Item 2",
    imageUrl: [
      'assets/images/rent4.jpeg',
      'assets/images/rent5.jpeg',
    ],
    category: "Tractor",
    price: "200",
    rentalUnit: "per day",
    availableFrom: "Jan 25, 2026",
    availableTo: "Mar 01, 2026",
    brand: "John Deere",
    yearModel: "2019",
    power: "75 HP",
    fuelType: "Diesel",
    operatorIncluded: true,
    landSizeRequirement: true,
    landSizeMin: "500", // optional min size
    landSizeMax: "1000", // optional max size
    maxCropHeightRequirement: true,
    maxCropHeight: "120", // optional height in cm
    description: "Powerful tractor ideal for medium to large farms, comes with operator.",

  ),
  RentItem(
    id: "3",
    title: "Item 3",
    imageUrl: [
      'assets/images/rent6.jpeg',
      'assets/images/rent3.jpeg',
      'assets/images/rent5.jpeg',
    ],
    category: "Machine",
    price: "50",
    rentalUnit: "per day",
    availableFrom: "Feb 01, 2026",
    availableTo: "Feb 15, 2026",
    condition: "Used",
    landSizeRequirement: false,
    maxCropHeightRequirement: true,
    maxCropHeight: "80",
    description: "Compact machine suitable for small-scale farming and light soil work.",

  ),
  RentItem(
    id: "4",
    title: "Item 4",
    imageUrl: [
      'assets/images/rent7.jpeg',
      'assets/images/rent4.jpeg',
      'assets/images/rent8.jpg',
    ],
    category: "Machine",
    price: "90",
    rentalUnit: "per day",
    availableFrom: "Jan 18, 2026",
    availableTo: "Apr 30, 2026",
    brand: "Caterpillar",
    yearModel: "2020",
    fuelType: "Diesel",
    attachments: "Bucket, Blade",
    landSizeRequirement: true,
    maxCropHeightRequirement: false,
    description: "Versatile heavy machine for large-scale earthmoving and excavation projects.",

  ),
  RentItem(
    id: "5",
    title: "Item 5",
    imageUrl: [
      'assets/images/rent3.jpeg',
      'assets/images/rent5.jpeg',
    ],
    category: "Machine",
    price: "300",
    rentalUnit: "per day",
    availableFrom: "Mar 01, 2026",
    availableTo: "Mar 20, 2026",
    power: "150 HP",
    operatorIncluded: false,
    landSizeRequirement: false,
    maxCropHeightRequirement: false,
    description: "High-powered machine for heavy-duty farming tasks. Operator not included.",

  ),
];
