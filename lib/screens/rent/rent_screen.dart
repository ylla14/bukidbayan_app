import 'package:bukidbayan_app/components/app_bar.dart';
import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:bukidbayan_app/components/rent/rent_item_card.dart';
import 'package:bukidbayan_app/screens/rent/equipment_listing_form_screen.dart';
import 'package:bukidbayan_app/screens/rent/product_page.dart';

import 'package:flutter/material.dart' hide CarouselController;
import 'package:carousel_slider/carousel_slider.dart';

import 'package:bukidbayan_app/theme/theme.dart';

import 'package:bukidbayan_app/mock_data/rent_items.dart';

class RentScreen extends StatefulWidget {
  const RentScreen({super.key});

  @override
  State<RentScreen> createState() => _RentScreenState();
}

class _RentScreenState extends State<RentScreen> {
  List<RentItem> filteredItems = [];
  final SearchController _searchController = SearchController();
  String searchQuery = '';
  String? activeCategory;
  bool isPriceFilterActive = false;

  late RangeValues priceRange;
  late double minPrice;
  late double maxPrice;


  @override
  void initState() {
    super.initState();
    filteredItems = items; // show all initially

    minPrice = getMinPrice();
    maxPrice = getMaxPrice();
    priceRange = RangeValues(minPrice, maxPrice);
  }

  double getMinPrice() {
    if (items.isEmpty) return 0;
    return items
        .map((item) => int.parse(item.price.replaceAll(RegExp(r'[^0-9]'), '')))
        .reduce((a, b) => a < b ? a : b)
        .toDouble();
  }

  double getMaxPrice() {
    if (items.isEmpty) return 500;
    return items
        .map((item) => int.parse(item.price.replaceAll(RegExp(r'[^0-9]'), '')))
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
  }

  void applyFilters() {
    setState(() {
      filteredItems = items.where((item) {
        final matchesSearch = item.title.toLowerCase().contains(
          searchQuery.toLowerCase(),
        );

        final matchesCategory = activeCategory == null
            ? true
            : item.category == activeCategory;

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  void clearFilters() {
    setState(() {
      searchQuery = '';
      activeCategory = null;
      filteredItems = items;
    });
  }

  Widget CategoryButtons(String category) {
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
            if (activeCategory == category) {
              // tap again → deselect
              activeCategory = null;
            } else {
              activeCategory = category;
            }
            applyFilters();
          });
        },
        child: Text(
          category,
          style: TextStyle(
            color: isSelected ? Colors.green.shade900 : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [lightColorScheme.primary, lightColorScheme.secondary],
              stops: [0.0, 0.9],
            ),
          ),
        ),
        centerTitle: true,
        title: Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
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
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10), // boxy, not rounded
                ),
              ),
              backgroundColor: WidgetStateProperty.all(
                lightColorScheme.onPrimary,
              ),
              elevation: WidgetStateProperty.all(0),
              hintText: 'Search',
              onChanged: (value) {
                searchQuery = value;
                applyFilters();
              },
            ),
          ),
        ),
        actions: [
          // IconButton(
          //   onPressed: () {
          //     Navigator.push(context, MaterialPageRoute(builder: (e) => const EquipmentListingScreen(),));
          //   },
          //   icon: Icon(Icons.add_box_rounded),
          // ),

             IconButton(
              icon: const Icon(Icons.notifications_outlined),
              iconSize: 35,
              onPressed: () {
                // TODO: navigate to notifications screen
              },
            ),

        ],
      ),

      drawer: const CustomDrawer(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              // /// SEARCH BAR
              // Padding(
              //   padding: const EdgeInsets.all(8),
              //   child: SearchBar(
              //     backgroundColor: WidgetStateProperty.all(
              //       lightColorScheme.onPrimary,
              //     ),
              //     hintText: 'Search Item...',
              //     onChanged: (value) {
              //       searchQuery = value;
              //       applyFilters();
              //     },
              //   ),
              // ),

              /// CREATE LISTING & RENT BUTTONS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    /// CREATE LISTING BUTTON
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.green.shade100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: Icon(Icons.add_box_rounded, color: lightColorScheme.primary,),
                        label: Text(
                          'Create',
                          style: TextStyle(
                            color: lightColorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EquipmentListingScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const SizedBox(width: 8),

                    /// RENT BUTTON
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.green.shade100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon:  Icon(Icons.shopping_cart_outlined, color: lightColorScheme.primary,),
                        label:  Text(
                          'My Equipment',
                          style: TextStyle(
                            color: lightColorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          // TODO: navigate to rent-related screen if needed
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),


              /// CAROUSEL (only when no filters)
              if (searchQuery.isEmpty && activeCategory == null)
                CarouselSlider(
                  options: CarouselOptions(
                    height: 180,
                    autoPlay: true,
                    enlargeCenterPage: true,
                    viewportFraction: 0.950,
                  ),
                  items: items.map((item) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      // child: Image.network(item.imageUrl[1], fit: BoxFit.cover, width: double.infinity,),
                      child: Image.asset(item.imageUrl[0], fit: BoxFit.cover, width: double.infinity,),

                    );
                  }).toList(),
                ),
                

              const SizedBox(height: 10),

                            /// FILTER BUTTONS
              SizedBox(
                height: 40, // adjust height as needed
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    CategoryButtons('Hand Tool'),
                    CategoryButtons('Tractor'),
                    CategoryButtons('Machine'),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              /// FILTER SECTION under carousel
              if (searchQuery.isEmpty && activeCategory == null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    // vertical: 8,
                  ),
                  child: Row(
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
                                      MediaQuery.of(context).viewInsets.bottom +
                                          16,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        /// TITLE
                                        const Text(
                                          'Filter by Price',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        const SizedBox(height: 12),

                                        /// PRICE LABELS (for older users)
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'PHP ${priceRange.start.toInt()}',
                                            ),
                                            Text(
                                              'PHP ${priceRange.end.toInt()}',
                                            ),
                                          ],
                                        ),

                                        /// SLIDER
                                        SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            activeTrackColor:
                                                lightColorScheme.primary,
                                            inactiveTrackColor:
                                                Colors.green.shade100,
                                            thumbColor:
                                                lightColorScheme.primary,
                                            overlayColor: Colors.green.shade100,
                                            rangeThumbShape:
                                                const RoundRangeSliderThumbShape(
                                                  enabledThumbRadius: 10,
                                                ),
                                            valueIndicatorColor:
                                                lightColorScheme.primary,
                                            valueIndicatorTextStyle:
                                                const TextStyle(
                                                  color: Colors.white,
                                                ),
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

                                        /// ACTION BUTTONS
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton(
                                                
                                                onPressed: () {
                                                  setState(() {
                                                    priceRange =
                                                         RangeValues(
                                                          minPrice, maxPrice
                                                        );
                                                    isPriceFilterActive = false;
                                                    filteredItems = items;
                                                  });
                                                  Navigator.pop(context);
                                                },
                                                child: Text('Clear', style: TextStyle(color: lightColorScheme.primary),),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () {
                                                  setState(() {
                                                    isPriceFilterActive = true;

                                                    filteredItems = items.where(
                                                      (item) {
                                                        final price = int.parse(
                                                          item.price.replaceAll(
                                                            RegExp(r'[^0-9]'),
                                                            '',
                                                          ),
                                                        );
                                                        return price >=
                                                                priceRange.start
                                                                    .toInt() &&
                                                            price <=
                                                                priceRange.end
                                                                    .toInt();
                                                      },
                                                    ).toList();
                                                  });
                                                  Navigator.pop(context);
                                                },
                                                child: Text('Apply', style: TextStyle(color: lightColorScheme.primary),),
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

                      if (isPriceFilterActive)
                        Row(
                          children: [
                            /// PRICE RANGE CHIP
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: lightColorScheme.primary.withOpacity(
                                  0.1,
                                ),
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

                            /// CLEAR FILTER ICON (NO EXTRA SPACE)
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
                ),

              /// GRID
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: filteredItems.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.8,
                ),
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  return GestureDetector(
                     onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductPage(item: item,),
                        ),
                      );
                    },
                  child: RentItemCard(
                    title: item.title,
                    imageUrl: item.imageUrl[0],
                    price: item.price,
                  )
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
