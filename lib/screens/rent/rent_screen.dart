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


class RentScreen extends StatefulWidget {
  const RentScreen({super.key});

  @override
  State<RentScreen> createState() => _RentScreenState();
}

class _RentScreenState extends State<RentScreen> {
  final RentService _rentService = RentService();

  final SearchController _searchController = SearchController();

  List<RentItem> allItems = [];
  List<RentItem> filteredItems = [];

  String searchQuery = '';
  String? activeCategory;
  bool isPriceFilterActive = false;

  late double minPrice;
  late double maxPrice;
  late RangeValues priceRange;

  @override
  void initState() {
    super.initState();
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
  }

  void clearFilters() {
    setState(() {
      searchQuery = '';
      activeCategory = null;
      isPriceFilterActive = false;
      priceRange = RangeValues(minPrice, maxPrice);
      filteredItems = allItems;
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

            /// GRID
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredItems.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductPage(item: item),
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
