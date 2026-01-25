import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:bukidbayan_app/components/rent/rent_item_card.dart';
import 'package:bukidbayan_app/screens/rent/equipment_listing_form_screen.dart';
import 'package:bukidbayan_app/screens/rent/product_page.dart';
import 'package:flutter/material.dart' hide CarouselController;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:bukidbayan_app/theme/theme.dart';

// 🔹 NEW
// import 'package:bukidbayan_app/models/rentModel.dart';
import 'package:bukidbayan_app/services/rent_service.dart';
import 'package:bukidbayan_app/mock_data/rent_items.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RentScreen extends StatefulWidget {
  const RentScreen({super.key});

  @override
  State<RentScreen> createState() => _RentScreenState();
}

class _RentScreenState extends State<RentScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final SearchController _searchController = SearchController();

  List<RentItem> allItems = [];
  List<RentItem> filteredItems = [];

  String searchQuery = '';
  String? activeCategory;
  bool isPriceFilterActive = false;
  bool? operatorFilter; // null = no filter, true = with operator, false = without operator

  late double minPrice;
  late double maxPrice;
  late RangeValues priceRange;

  @override
  void initState() {
    super.initState();
    minPrice = 0;
    maxPrice = 10000;
    priceRange = RangeValues(minPrice, maxPrice);
    _loadItems();
  }

  Future<void> _loadItems() async {
    await _rentService.seedRentItems();
    final items = await _rentService.getAllItems();

    setState(() {
      allItems = items;
      filteredItems = items;

      minPrice = _getMinPrice(items);
      maxPrice = _getMaxPrice(items);
      priceRange = RangeValues(minPrice, maxPrice);
    });
  }

  double _getMinPrice(List<RentItem> items) {
    if (items.isEmpty) return 0;
    return items
        .map((e) => int.parse(e.price.replaceAll(RegExp(r'[^0-9]'), '')))
        .reduce((a, b) => a < b ? a : b)
        .toDouble();
  }

  double _getMaxPrice(List<RentItem> items) {
    if (items.isEmpty) return 500;
    return items
        .map((e) => int.parse(e.price.replaceAll(RegExp(r'[^0-9]'), '')))
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
  }

  void applyFilters() {
    setState(() {
      filteredItems = allItems.where((item) {
        final matchesSearch = item.title
            .toLowerCase()
            .contains(searchQuery.toLowerCase());

        final matchesCategory =
            activeCategory == null || item.category == activeCategory;

        final matchesPrice = !isPriceFilterActive ||
            (() {
              final price = int.parse(
                item.price.replaceAll(RegExp(r'[^0-9]'), ''),
              );
              return price >= priceRange.start &&
                  price <= priceRange.end;
            })();

        return matchesSearch && matchesCategory && matchesPrice;
      }).toList();
    });
  // Filter equipment list based on current filters
  List<Equipment> applyFilters(List<Equipment> equipmentList) {
    return equipmentList.where((equipment) {
      // Search filter
      final matchesSearch = searchQuery.isEmpty ||
          equipment.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          (equipment.description.toLowerCase().contains(searchQuery.toLowerCase()));

      // Category filter
      final matchesCategory = activeCategory == null || equipment.category == activeCategory;

      // Price filter
      final matchesPrice = !isPriceFilterActive ||
          (equipment.price >= priceRange.start && equipment.price <= priceRange.end);

      // Operator filter
      final matchesOperator = operatorFilter == null || equipment.operatorIncluded == operatorFilter;

      return matchesSearch && matchesCategory && matchesPrice && matchesOperator;
    }).toList();
  }

  void clearFilters() {
    setState(() {
      searchQuery = '';
      activeCategory = null;
      isPriceFilterActive = false;
      operatorFilter = null;
      priceRange = RangeValues(minPrice, maxPrice);
      _searchController.clear();
    });
  }

  Widget categoryButton(String category) {
    final bool isSelected = activeCategory == category;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? Colors.green.shade100 : null,
          side: BorderSide(color: isSelected ? Colors.green : Colors.grey),
        ),
        onPressed: () {
          setState(() {
            activeCategory =
                activeCategory == category ? null : category;
            applyFilters();
          });
        },
        child: Text(
          category,
          style: TextStyle(
            color: isSelected ? Colors.green.shade900 : Colors.black,
            fontWeight:
                isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const CustomDrawer(),
      appBar: AppBar(
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                lightColorScheme.primary,
                lightColorScheme.secondary
              ],
            ),
          ),
        ),
        title: SizedBox(
          height: 40,
          child: SearchBar(
            controller: _searchController,
            leading: const Icon(Icons.search),
            trailing: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _searchController.clear();
                  clearFilters();
                },
              ),
            ],
            backgroundColor:
                WidgetStateProperty.all(lightColorScheme.onPrimary),
            hintText: 'Search',
            onChanged: (value) {
              searchQuery = value;
              applyFilters();
            },
          ),
        ),
        actions: const [
          Icon(Icons.notifications_outlined, size: 30),
          SizedBox(width: 8),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            /// CREATE & MY EQUIPMENT
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 5, 13, 5),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.green.shade100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.add_box_rounded),
                      label: const Text('Create'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const EquipmentListingScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.green.shade100,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: const Text('My Equipment'),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            /// CAROUSEL
            if (searchQuery.isEmpty && activeCategory == null)
              CarouselSlider(
                options: CarouselOptions(
                  height: 180,
                  autoPlay: true,
                  enlargeCenterPage: true,
                  viewportFraction: 0.925
                ),
                items: allItems.map((item) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      item.imageUrl.first,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 10),

          /// FILTERS SECTION (Category + Price)
          if (searchQuery.isEmpty && activeCategory == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CATEGORY BUTTONS
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        categoryButton('Hand Tool'),
                        categoryButton('Tractor'),
                        categoryButton('Machine'),
                    const SizedBox(width: 8),
                    // Operator filter button
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: operatorFilter == true
                              ? Colors.blue.shade100
                              : null,
                          side: BorderSide(
                            color: operatorFilter == true
                                ? Colors.blue
                                : Colors.grey,
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            if (operatorFilter == true) {
                              operatorFilter = null;
                            } else {
                              operatorFilter = true;
                            }
                          });
                        },
                        icon: Icon(
                          Icons.person,
                          size: 18,
                          color: operatorFilter == true
                              ? Colors.blue.shade900
                              : Colors.black,
                        ),
                        label: Text(
                          'With Operator',
                          style: TextStyle(
                            color: operatorFilter == true
                                ? Colors.blue.shade900
                                : Colors.black,
                            fontWeight: operatorFilter == true
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // PRICE FILTER
                  Row(
                    children: [
                      const Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                            ),
                            builder: (context) {
                              return StatefulBuilder(
                                builder: (context, setModalState) {
                                  return Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      16,
                                      16,
                                      MediaQuery.of(context).viewInsets.bottom + 16,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Filter by Price',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('PHP ${priceRange.start.toInt()}'),
                                            Text('PHP ${priceRange.end.toInt()}'),
                                          ],
                                        ),
                                        SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            activeTrackColor: lightColorScheme.primary,
                                            inactiveTrackColor: Colors.green.shade100,
                                            thumbColor: lightColorScheme.primary,
                                            overlayColor: Colors.green.shade100,
                                            rangeThumbShape:
                                                const RoundRangeSliderThumbShape(
                                                    enabledThumbRadius: 10),
                                            valueIndicatorColor: lightColorScheme.primary,
                                            valueIndicatorTextStyle:
                                                const TextStyle(color: Colors.white),
                                          ),
                                          child: RangeSlider(
                                            min: minPrice,
                                            max: maxPrice,
                                            divisions: 10,
                                            values: priceRange,
                                            labels: RangeLabels(
                                              'PHP ${priceRange.start.toInt()}',
                                              'PHP ${priceRange.end.toInt()}',
                                            ),
                                            onChanged: (values) {
                                              setModalState(() {
                                                priceRange = values;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () {
                                                  setState(() {
                                                    priceRange =
                                                        RangeValues(minPrice, maxPrice);
                                                    isPriceFilterActive = false;
                                                    filteredItems = allItems;
                                                  });
                                                  Navigator.pop(context);
                                                },
                                                child: Text(
                                                  'Clear',
                                                  style: TextStyle(
                                                      color: lightColorScheme.primary),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () {
                                                  setState(() {
                                                    isPriceFilterActive = true;
                                                    filteredItems = allItems.where((item) {
                                                      final price = int.parse(
                                                        item.price.replaceAll(
                                                            RegExp(r'[^0-9]'), ''),
                                                      );
                                                      return price >=
                                                              priceRange.start.toInt() &&
                                                          price <=
                                                              priceRange.end.toInt();
                                                    }).toList();
                                                  });
                                                  Navigator.pop(context);
                                                },
                                                child: Text(
                                                  'Apply',
                                                  style: TextStyle(
                                                      color: lightColorScheme.primary),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),

                      // ACTIVE PRICE FILTER CHIP
                      if (isPriceFilterActive)
                        Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: lightColorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: lightColorScheme.primary,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'PHP ${priceRange.start.toInt()} – ${priceRange.end.toInt()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: lightColorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Clear filters',
                              iconSize: 18,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                clearFilters();
                                setState(() {
                                  isPriceFilterActive = false;
                                  priceRange = RangeValues(minPrice, maxPrice);
                                });
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),

              /// GRID - Equipment from Firestore
              StreamBuilder<QuerySnapshot>(
                stream: _firestoreService.getAvailableEquipment(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text('Error: ${snapshot.error}'),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.agriculture_outlined,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No equipment available yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to list your equipment!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Convert Firestore documents to Equipment objects
                  final allEquipment = snapshot.data!.docs
                      .map((doc) => Equipment.fromFirestore(doc))
                      .toList();

                  // Apply filters
                  final filteredEquipment = applyFilters(allEquipment);

                  if (filteredEquipment.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No equipment found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try adjusting your filters',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: filteredEquipment.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.8,
                    ),
                    itemBuilder: (context, index) {
                      final equipment = filteredEquipment[index];

                      // Create a temporary RentItem for compatibility with existing ProductPage
                      final tempItem = RentItem(
                        title: equipment.name,
                        imageUrl: equipment.imageUrls.isNotEmpty
                            ? equipment.imageUrls
                            : ['assets/images/rent1.jpg'], // Fallback image
                        category: equipment.category ?? 'Other',
                        price: equipment.price.toString(),
                        availableFrom: equipment.availableFrom?.toString().split(' ')[0],
                        availableTo: equipment.availableUntil?.toString().split(' ')[0],
                        brand: equipment.brand,
                        yearModel: equipment.yearModel,
                        power: equipment.power,
                        fuelType: equipment.fuelType,
                        condition: equipment.condition,
                        attachments: equipment.attachments,
                        operatorIncluded: equipment.operatorIncluded,
                      );

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductPage(item: tempItem),
                            ),
                          );
                        },
                        child: RentItemCard(
                          title: equipment.name,
                          imageUrl: equipment.imageUrls.isNotEmpty
                              ? equipment.imageUrls[0]
                              : 'assets/images/rent1.jpg',
                          price: '₱${equipment.price.toStringAsFixed(0)}',
                        ),
                      );
                    },
                    child: RentItemCard(
                      title: item.title,
                      imageUrl: item.imageUrl.first,
                      price: item.price,
                      rentRate: item.rentRate,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
