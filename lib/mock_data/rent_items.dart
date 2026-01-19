class RentItem {
  final String title;
  final List<String> imageUrl;
  final String category;
  final String price;

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

  RentItem({
    required this.title,
    required this.imageUrl,
    required this.category,
    required this.price,
    required this.availableFrom,
    required this.availableTo,
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
      // "https://i.pinimg.com/736x/65/50/01/655001d9f809051060e4a8417e85af07.jpg",
      // "https://i.pinimg.com/736x/22/ae/3b/22ae3bb2f7b46bed0e3a99a025835ab0.jpg",
     
      'assets/images/rent1.jpg',
      'assets/images/rent3.jpeg',
      'assets/images/rent5.jpeg',
    ],
    category: "Hand Tool",
    price: "105",
    availableFrom: "Jan 20, 2026",
    availableTo: "Feb 10, 2026",
    brand: "Makita",
    condition: "Good",
  ),

  RentItem(
    title: "Item 2",
    imageUrl: [
      // "https://i.pinimg.com/736x/ce/58/c5/ce58c546f766df0654ee3b3e1bd9fad0.jpg",
      // "https://i.pinimg.com/736x/22/ae/3b/22ae3bb2f7b46bed0e3a99a025835ab0.jpg",

      'assets/images/rent4.jpeg',
      'assets/images/rent5.jpeg',
    ],
    category: "Tractor",
    price: "200",
    availableFrom: "Jan 25, 2026",
    availableTo: "Mar 01, 2026",
    brand: "John Deere",
    yearModel: "2019",
    power: "75 HP",
    fuelType: "Diesel",
    operatorIncluded: true,
  ),

  RentItem(
    title: "Item 3",
    imageUrl: [
      // "https://i.pinimg.com/736x/cd/6f/82/cd6f82478ba340ee729c3735ef788912.jpg",
      // "https://i.pinimg.com/736x/22/ae/3b/22ae3bb2f7b46bed0e3a99a025835ab0.jpg",

      'assets/images/rent6.jpeg',
      'assets/images/rent3.jpeg',
      'assets/images/rent5.jpeg',
    ],
    category: "Machine",
    price: "50",
    availableFrom: "Feb 01, 2026",
    availableTo: "Feb 15, 2026",
    condition: "Used",
  ),

  RentItem(
    title: "Item 4",
    imageUrl: [
      // "https://i.pinimg.com/1200x/58/de/53/58de530d9f145f66336a0ceb11c81a4a.jpg",
      // "https://i.pinimg.com/736x/22/ae/3b/22ae3bb2f7b46bed0e3a99a025835ab0.jpg",

      'assets/images/rent7.jpeg',
      'assets/images/rent4.jpeg',
      'assets/images/rent8.jpg',
    ],
    category: "Machine",
    price: "90",
    availableFrom: "Jan 18, 2026",
    availableTo: "Apr 30, 2026",
    brand: "Caterpillar",
    yearModel: "2020",
    fuelType: "Diesel",
    attachments: "Bucket, Blade",
  ),

  RentItem(
    title: "Item 5",
    imageUrl: [
      // "https://i.pinimg.com/736x/e2/f9/66/e2f96658bcfbd5b735b30d61bdf3f1c2.jpg",
      // "https://i.pinimg.com/736x/22/ae/3b/22ae3bb2f7b46bed0e3a99a025835ab0.jpg",

      'assets/images/rent3.jpeg',
      'assets/images/rent5.jpeg',
    ],
    category: "Machine",
    price: "300",
    availableFrom: "Mar 01, 2026",
    availableTo: "Mar 20, 2026",
    power: "150 HP",
    operatorIncluded: false,
  ),
];
