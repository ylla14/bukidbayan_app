// import 'package:bukidbayan_app/models/rentModel.dart';
import 'package:bukidbayan_app/mock_data/rent_items.dart';



class RentService {
  /// Internal in-memory storage (mock database)
  final List<RentItem> _items = [];

  /// 🔹 Seed mock data (call once on app start)
Future<void> seedRentItems() async {
  if (_items.isNotEmpty) return; // prevent duplicate seeding

  _items.addAll([
    RentItem(
      id: '1',
      title: "Item 1",
      imageUrl: [
        'assets/images/rent1.jpg',
        'assets/images/rent3.jpeg',
        'assets/images/rent5.jpeg',
      ],
      category: "Hand Tool",
      price: "105",
      rentRate: "per day",
      availableFrom: "Jan 20, 2026",
      availableTo: "Feb 10, 2026",
      brand: "Makita",
      condition: "Good",
      landSizeRequirement: false,
      maxCropHeightRequirement: false,
      description: "A reliable hand tool suitable for small farming and gardening tasks.",
    ),

    RentItem(
      id: '2',
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
      landSizeMin: 500,
      landSizeMax: 1000,
      maxCropHeightRequirement: true,
      maxCropHeight: 120,
      description: "Powerful tractor ideal for medium to large farms, comes with operator.",
    ),

    RentItem(
      id: '3',
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
      description: "Compact machine suitable for small-scale farming and light soil work.",
    ),

    RentItem(
      id: '4',
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
      description: "Versatile heavy machine for large-scale earthmoving and excavation projects.",
    ),

    RentItem(
      id: '5',
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
      description: "High-powered machine for heavy-duty farming tasks. Operator not included.",
    ),
  ]);
}


  /// 🔹 CREATE
  Future<void> addRentItem(RentItem item) async {
    _items.add(item);
  }

  /// 🔹 READ ALL
  Future<List<RentItem>> getAllItems() async {
    return List.unmodifiable(_items);
  }

  /// 🔹 READ BY CATEGORY
  Future<List<RentItem>> getItemsByCategory(String category) async {
    return _items
        .where((item) => item.category == category)
        .toList();
  }

  /// 🔹 FILTER: land size
  Future<List<RentItem>> filterByLandSize(int landSize) async {
    return _items.where((item) {
      if (!item.landSizeRequirement) return true;

      final min = item.landSizeMin ?? 0;
      final max = item.landSizeMax ?? double.infinity;

      return landSize >= min && landSize <= max;
    }).toList();
  }

  /// 🔹 DELETE
  Future<void> deleteItem(String id) async {
    _items.removeWhere((item) => item.id == id);
  }
}
