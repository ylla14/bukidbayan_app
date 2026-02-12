import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:bukidbayan_app/components/rent/rent_item_card.dart';
import 'package:bukidbayan_app/screens/notification_screen.dart';
import 'package:bukidbayan_app/screens/rent/equipment_listing_form_screen.dart';
import 'package:bukidbayan_app/screens/rent/my_equipment.dart';
import 'package:bukidbayan_app/screens/rent/product_page.dart';
import 'package:bukidbayan_app/widgets/custom_icon_button.dart';
import 'package:bukidbayan_app/components/rent/rent_screen/active_filters_chip.dart';
import 'package:bukidbayan_app/components/rent/rent_screen/category_filter_bar.dart';
import 'package:bukidbayan_app/components/rent/rent_screen/equipment_carousel.dart';
import 'package:bukidbayan_app/components/rent/rent_screen/operator_filter_button.dart';
import 'package:bukidbayan_app/components/rent/rent_screen/price_filter_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart' hide CarouselController;
import 'package:carousel_slider/carousel_slider.dart';
import 'package:bukidbayan_app/theme/theme.dart';

import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RentScreen extends StatefulWidget {
  const RentScreen({super.key});

  @override
  State<RentScreen> createState() => _RentScreenState();
}

class _RentScreenState extends State<RentScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirestoreService _firestoreService = FirestoreService();
  final SearchController _searchController = SearchController();

  List<Equipment> allItems = [];
  List<Equipment> filteredItems = [];

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
  }

void applyFilters() {
  setState(() {
    filteredItems = allItems.where((item) {
      final matchesSearch = item.name
          .toLowerCase()
          .contains(searchQuery.toLowerCase());

      final matchesCategory =
          activeCategory == null || item.category == activeCategory;

      final matchesPrice = !isPriceFilterActive ||
          (item.price >= priceRange.start &&
           item.price <= priceRange.end);

      return matchesSearch && matchesCategory && matchesPrice;
    }).toList();
  });
}


List<Equipment> applyEquipmentFilters(List<Equipment> equipmentList) {
  return equipmentList.where((equipment) {
    final matchesSearch = searchQuery.isEmpty ||
        equipment.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
        equipment.description.toLowerCase().contains(searchQuery.toLowerCase());

    final matchesCategory =
        activeCategory == null || equipment.category == activeCategory;

    final matchesPrice = !isPriceFilterActive ||
        (equipment.price >= priceRange.start &&
            equipment.price <= priceRange.end);

    final matchesOperator =
        operatorFilter == null ||
        equipment.operatorIncluded == operatorFilter;

    return matchesSearch &&
        matchesCategory &&
        matchesPrice &&
        matchesOperator;
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

  Future<void> logout() async {
    await _auth.signOut();
  }

  bool calculateAvailability(Equipment equipment) {
  final from = equipment.availableFrom;
  final until = equipment.availableUntil;

  if (from == null || until == null) {
    return false; // no dates = unavailable
  }

  final now = DateTime.now();
  return now.isAfter(from) && now.isBefore(until);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: CustomDrawer(onLogout: logout,),      
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
       actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              size: 30,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            /// CREATE & MY EQUIPMENT
            Padding(
              padding: const EdgeInsets.fromLTRB(10.0, 0, 10.0, 0),
              child: Row(
                children: [
                  Expanded(
                    child: CustomIconButton(
                      icon: const Icon(Icons.add_box_rounded),
                      label: const Text('Create'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EquipmentListingScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: CustomIconButton(
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: const Text('My Equipment'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MyEquipment(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),


            const SizedBox(height: 10),

            // CAROUSEL
            if (searchQuery.isEmpty && activeCategory == null)
              StreamBuilder<QuerySnapshot>(
                stream: _firestoreService.getAvailableEquipment(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const SizedBox();
                  }

                  final currentUserId = _auth.currentUser?.uid;
                  final now = DateTime.now();

                  final equipmentList = snapshot.data!.docs
                      .map((doc) {
                        final equipment = Equipment.fromFirestore(doc);
                        final data = doc.data() as Map<String, dynamic>;

                        final isAvailable = data['isAvailable'] ?? false;
                        final availableUntil =
                          (data['availableUntil'] as Timestamp?)?.toDate();

                        final dateOk = availableUntil != null && now.isBefore(availableUntil);

                        final isOwnedByUser = equipment.ownerId == currentUserId;

                        if (!isOwnedByUser && isAvailable && dateOk) {
                          return equipment;
                        }
                        return null;
                      })
                      .whereType<Equipment>() // removes nulls
                      .toList();

                  if (equipmentList.isEmpty) {
                    return const SizedBox();
                  }

                  return EquipmentCarousel(
                    equipment: equipmentList,
                    maxItems: 5,
                  );
                },
              ),



            const SizedBox(height: 10),

          /// FILTERS SECTION (Category + Price)
          if (searchQuery.isEmpty)
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
                        CategoryFilterBar(
                          activeCategory: activeCategory,
                          onCategorySelected: (category) {
                            setState(() {
                              activeCategory =
                                  activeCategory == category ? null : category;
                            });
                          },
                        ),

                        const SizedBox(width: 8),

                        OperatorFilterButton(
                          isActive: operatorFilter,
                          onPressed: () {
                            setState(() {
                              if (operatorFilter == true) {
                                operatorFilter = null;
                              } else {
                                operatorFilter = true;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),


                  const SizedBox(height: 8),

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
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            builder: (_) {
                              return PriceFilterSheet(
                                initialRange: priceRange,
                                minPrice: minPrice,
                                maxPrice: maxPrice,
                                onApply: (range, isActive) {
                                  setState(() {
                                    priceRange = range;
                                    isPriceFilterActive = isActive;
                                  });
                                },
                              );
                            },
                          );
                        },
                      ),

                      const SizedBox(width: 8),

                      // 👇 ONLY THIS PART SCROLLS
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              if (activeCategory != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ActiveFiltersChip(
                                    label: activeCategory!,
                                    onClear: () =>
                                        setState(() => activeCategory = null),
                                  ),
                                ),

                              if (operatorFilter == true)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ActiveFiltersChip(
                                    label: 'With Operator',
                                    onClear: () =>
                                        setState(() => operatorFilter = null),
                                  ),
                                ),

                              if (isPriceFilterActive)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ActiveFiltersChip(
                                    label:
                                        'PHP ${priceRange.start.toInt()} – ${priceRange.end.toInt()}',
                                    onClear: () {
                                      setState(() {
                                        isPriceFilterActive = false;
                                        priceRange =
                                            RangeValues(minPrice, maxPrice);
                                      });
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )


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
                  // final allEquipment = snapshot.data!.docs
                  //     .map((doc) => Equipment.fromFirestore(doc))
                  //     .toList();

                  // // Apply filters
                  // final filteredEquipment = applyEquipmentFilters(allEquipment);

                 final allEquipment = snapshot.data!.docs
                    .map((doc) => Equipment.fromFirestore(doc))
                    .toList();

                // Exclude items owned by the current user
                final currentUserId = _auth.currentUser?.uid;
                final equipmentNotOwnedByUser = allEquipment
                    .where((equipment) => equipment.ownerId != currentUserId)
                    .toList();

                // Apply your existing filters
                final filteredEquipment = applyEquipmentFilters(equipmentNotOwnedByUser);

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

                // GRID
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

                      // Listen to live updates for this equipment
                      return StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('equipment')
                            .doc(equipment.id)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            // Placeholder while loading
                            return RentItemCard(
                              title: equipment.name,
                              imageUrl: equipment.imageUrls.isNotEmpty
                                  ? equipment.imageUrls[0]
                                  : 'assets/images/rent1.jpg',
                              price: '₱${equipment.price.toStringAsFixed(0)}',
                              ownerName: 'Loading...',
                              isAvailable: false,
                              rentalUnit: equipment.rentalUnit,
                            );
                          }

                          final data =
                              snapshot.data!.data() as Map<String, dynamic>? ?? {};

                          final isAvailableFirestore =
                              data['isAvailable'] ?? false;

                          final availableUntil =
                              (data['availableUntil'] as Timestamp?)?.toDate();

                          final finalAvailability =
                              isAvailableFirestore &&
                              availableUntil != null &&
                              DateTime.now().isBefore(availableUntil);

                          return FutureBuilder<String?>(
                            future: _firestoreService
                                .getUserNameById(equipment.ownerId),
                            builder: (context, ownerSnapshot) {
                              final ownerName =
                                  ownerSnapshot.data ?? 'Unknown Owner';

                              // 👇 UNAVAILABLE: greyed + no tap
                             if (!finalAvailability) {
                              return Opacity(
                                opacity: 0.5,
                                child: GestureDetector(
                                  // 🔕 OPTIONAL UX: tap unavailable item
                                  
                                  onTap: () {
                                    // Show SnackBar
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'This equipment is currently unavailable.',
                                        ),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );

                                    // Navigate to product page
                                    final tempItem = equipment.copyWith(ownerName: ownerName);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProductPage(item: tempItem),
                                      ),
                                    );
                                  },
                                  
                                  // child: IgnorePointer(
                                    // ⛔ Prevents navigation by default
                                    child: RentItemCard(
                                      title: equipment.name,
                                      imageUrl: equipment.imageUrls.isNotEmpty
                                          ? equipment.imageUrls[0]
                                          : 'assets/images/rent1.jpg',
                                      price: '₱${equipment.price.toStringAsFixed(0)}',
                                      ownerName: ownerName,
                                      rentalUnit: equipment.rentalUnit,
                                      isAvailable: false,
                                    ),
                                  // ),
                                ),
                              );
                            }


                              // 👇 AVAILABLE: tappable
                              return GestureDetector(
                                onTap: () {
                                  final tempItem =
                                      equipment.copyWith(ownerName: ownerName);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ProductPage(item: tempItem),
                                    ),
                                  );
                                },
                                child: RentItemCard(
                                  title: equipment.name,
                                  imageUrl: equipment.imageUrls.isNotEmpty
                                      ? equipment.imageUrls[0]
                                      : 'assets/images/rent1.jpg',
                                  price:
                                      '₱${equipment.price.toStringAsFixed(0)}',
                                  ownerName: ownerName,
                                  rentalUnit: equipment.rentalUnit,
                                  isAvailable: true,
                                ),
                              );
                            },
                          );
                        },
                      );

                    },
                  );

                },
              ),
          ],
        ),
      ),
    );
  }
}