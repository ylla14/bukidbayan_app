import 'dart:async';

import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:bukidbayan_app/components/rent/rent_item_card.dart';
import 'package:bukidbayan_app/models/crop_preference.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/models/review.dart';
import 'package:bukidbayan_app/screens/notification_screen.dart';
import 'package:bukidbayan_app/screens/rent/drafts_screen.dart';
import 'package:bukidbayan_app/screens/rent/equipment_listing_form_screen.dart';
import 'package:bukidbayan_app/screens/rent/my_equipment.dart';
import 'package:bukidbayan_app/screens/rent/product_page.dart';
import 'package:bukidbayan_app/services/rent_request_service.dart';
import 'package:bukidbayan_app/services/strike_service.dart';
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
import 'package:bukidbayan_app/services/language_notifier.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RentScreen extends StatefulWidget {
  final String? initialSearchQuery;
  final String? initialCategory;
  final bool initialRecommendedOnly;

  const RentScreen({
    super.key,
    this.initialSearchQuery,
    this.initialCategory,
    this.initialRecommendedOnly = false,
  });

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
  bool?
  operatorFilter; // null = no filter, true = with operator, false = without operator
  bool recommendedOnly = false;

  late double minPrice;
  late double maxPrice;
  late RangeValues priceRange;

  Set<String> blockedCategories = {};
  Set<String> _recommendedToolTypes = {};
  DateTime? _accountBlockedUntil;

  Timer? _availabilityTimer;
  DateTimeRange? dateFilter;
  Map<String, int> _reviewCountCache = {};

  @override
  void initState() {
    super.initState();
    minPrice = 0;
    maxPrice = 10000;
    priceRange = RangeValues(minPrice, maxPrice);

    final initialQuery = widget.initialSearchQuery?.trim();
    if (initialQuery != null && initialQuery.isNotEmpty) {
      searchQuery = initialQuery;
      _searchController.text = initialQuery;
    }

    final initialCategory = widget.initialCategory?.trim();
    if (initialCategory != null && initialCategory.isNotEmpty) {
      activeCategory = initialCategory;
    }
    recommendedOnly = widget.initialRecommendedOnly;

    _setupAvailabilityListener();
    _loadBlockedCategories();
    _loadCropPreferences();
    _checkAccountBlock();
    LanguageNotifier.showTl.addListener(_onLanguageChange);
  }

  void _onLanguageChange() => setState(() {});

  StreamSubscription<QuerySnapshot>? _requestListener;

  void _setupAvailabilityListener() {
    _requestListener = FirebaseFirestore.instance
        .collection('rentRequests')
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.modified ||
                change.type == DocumentChangeType.added) {
              final data = change.doc.data();
              if (data != null) {
                final itemId = data['itemId'] as String?;
                final status = data['status'] as String?;
                final renterId =
                    data['renterId'] as String?; // 👈 ADD THIS LINE

                // Only update for active statuses
                if (itemId != null &&
                    (status == 'pending' ||
                        status == 'approved' ||
                        status == 'onTheWay' ||
                        status == 'inProgress' ||
                        status == 'completed' ||
                        status == 'finished' ||
                        status == 'declined')) {
                  print(
                    '🔔 Rent request changed, refreshing equipment: $itemId',
                  );
                  _firestoreService
                      .validateEquipmentAvailabilityWithNotification(itemId);

                  // NEW: Refresh blocked categories if it's current user's request
                  if (renterId == _auth.currentUser?.uid) {
                    _loadBlockedCategories();
                  }
                }
              }
            }
          }
        });
  }

  /// Load categories that user already has active requests for
  Future<void> _loadBlockedCategories() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final rentRequestService = RentRequestService();

    // Get all active requests for this user
    final snapshot = await FirebaseFirestore.instance
        .collection('rentRequests')
        .where('renterId', isEqualTo: currentUserId)
        .where(
          'status',
          whereIn: [
            'pending',
            'approved',
            'readyForPickup',
            'pickedUp',
            'onTheWay',
            'inProgress',
            'retrieving',
            'returned',
          ],
        )
        .get();
    Set<String> categories = {};

    for (var doc in snapshot.docs) {
      final request = RentRequest.fromDoc(doc);

      // Get equipment category
      final equipmentDoc = await FirebaseFirestore.instance
          .collection('equipment')
          .doc(request.itemId)
          .get();

      if (equipmentDoc.exists) {
        final equipment = Equipment.fromFirestore(equipmentDoc);
        if (equipment.category != null) {
          categories.add(equipment.category!);
        }
      }
    }

    if (mounted) {
      setState(() {
        blockedCategories = categories;
      });
    }
  }

  Future<void> _checkAccountBlock() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final until = await StrikeService().blockedUntil(uid);
    if (mounted) setState(() => _accountBlockedUntil = until);
  }

  Future<void> _loadCropPreferences() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    final prefs = await _firestoreService.getCropPreferences(userId);
    if (prefs != null && mounted) {
      setState(() {
        _recommendedToolTypes = recommendedToolTypes(prefs);
      });
    }
  }

  Future<void> _prefetchReviewCounts(List<Equipment> equipmentList) async {
    final service = FirestoreService();
    final futures = equipmentList.map((e) async {
      if (e.id != null && !_reviewCountCache.containsKey(e.id)) {
        final reviews = await service.getReviewsForEquipment(e.id!);
        _reviewCountCache[e.id!] = reviews.length;
      }
    });
    await Future.wait(futures);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LanguageNotifier.showTl.removeListener(_onLanguageChange);
    _requestListener?.cancel();
    super.dispose();
  }

  void applyFilters() {
    setState(() {
      filteredItems = allItems.where((item) {
        final matchesSearch = item.name.toLowerCase().contains(
          searchQuery.toLowerCase(),
        );

        final matchesCategory =
            activeCategory == null || item.category == activeCategory;

        final matchesPrice =
            !isPriceFilterActive ||
            (item.price >= priceRange.start && item.price <= priceRange.end);

        return matchesSearch && matchesCategory && matchesPrice;
      }).toList();
    });
  }

  List<Equipment> applyEquipmentFilters(List<Equipment> equipmentList) {
    return equipmentList.where((equipment) {
      final matchesSearch =
          searchQuery.isEmpty ||
          equipment.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          equipment.description.toLowerCase().contains(
            searchQuery.toLowerCase(),
          );

      final matchesCategory =
          activeCategory == null || equipment.category == activeCategory;

      final matchesPrice =
          !isPriceFilterActive ||
          (equipment.price >= priceRange.start &&
              equipment.price <= priceRange.end);

      final matchesOperator =
          operatorFilter == null ||
          equipment.operatorIncluded == operatorFilter;

      // DATE FILTER: equipment must have at least 1 free day in the selected window
      // We can only check this client-side using the equipment's availableFrom/Until
      // The actual booked-day check happens via the stream per-card, but here we
      // quickly exclude equipment whose availability window doesn't even overlap.
      final matchesDate =
          dateFilter == null || _equipmentOverlapsDateFilter(equipment);
      final matchesRecommended =
          !recommendedOnly ||
          _recommendedToolTypes.isEmpty ||
          _recommendedToolTypes.contains(equipment.category);

      return matchesSearch &&
          matchesCategory &&
          matchesPrice &&
          matchesOperator &&
          matchesRecommended &&
          matchesDate;
    }).toList();
  }

  bool _equipmentOverlapsDateFilter(Equipment equipment) {
    if (dateFilter == null) return true;

    final equipFrom = equipment.availableFrom;
    final equipUntil = equipment.availableUntil;

    // No dates = never available
    if (equipFrom == null || equipUntil == null) return false;

    final filterStart = DateTime(
      dateFilter!.start.year,
      dateFilter!.start.month,
      dateFilter!.start.day,
    );
    final filterEnd = DateTime(
      dateFilter!.end.year,
      dateFilter!.end.month,
      dateFilter!.end.day,
    );
    final eqFrom = DateTime(equipFrom.year, equipFrom.month, equipFrom.day);
    final eqUntil = DateTime(equipUntil.year, equipUntil.month, equipUntil.day);

    // Overlap = equipment window and filter window share at least one day
    return !eqUntil.isBefore(filterStart) && !eqFrom.isAfter(filterEnd);
  }

  void clearFilters() {
    setState(() {
      searchQuery = '';
      activeCategory = null;
      isPriceFilterActive = false;
      operatorFilter = null;
      recommendedOnly = false;
      dateFilter = null; // NEW
      priceRange = RangeValues(minPrice, maxPrice);
      _searchController.clear();
    });
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: CustomDrawer(onLogout: logout),
      appBar: AppBar(
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [lightColorScheme.primary, lightColorScheme.secondary],
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
            backgroundColor: WidgetStateProperty.all(
              lightColorScheme.onPrimary,
            ),
            hintText: 'Search',
            onChanged: (value) {
              searchQuery = value;
              applyFilters();
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 30),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  // builder: (context) => const NotificationScreen(),
                  builder: (context) => NotificationScreen(),
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
            // ── ACCOUNT BLOCK BANNER ──────────────────────────────────────
            if (_accountBlockedUntil != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.block_rounded,
                      color: Colors.red.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hindi Ka Maaaring Mag-rent',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ang iyong account ay pansamantalang nasuspinde. '
                            'Hindi ka maaaring humiling ng kagamitan hanggang '
                            '${_accountBlockedUntil!.day}/${_accountBlockedUntil!.month}/${_accountBlockedUntil!.year}.',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            // ── SECTION HEADER ──
            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            //   child: Column(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
            //       Text(
            //         'Mag-Arkila',
            //         style: TextStyle(
            //           fontSize: 22,
            //           fontWeight: FontWeight.bold,
            //           color: lightColorScheme.primary,
            //         ),
            //       ),
            //       Text(
            //         'Hanapin ang kagamitang kailangan mo',
            //         style: TextStyle(
            //           fontSize: 13,
            //           color: Colors.grey[500],
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
            /// CREATE & MY EQUIPMENT
            Padding(
              padding: const EdgeInsets.fromLTRB(10.0, 0, 10.0, 0),
              child: Column(
                children: [
                  Row(
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
                          icon: const Icon(Icons.drafts_outlined),
                          label: const Text('Drafts'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DraftsScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: CustomIconButton(
                          icon: const Icon(Icons.shopping_cart_outlined),
                          label: const Text('Aking Equipment'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => MyEquipment()),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // CAROUSEL
            // if (searchQuery.isEmpty && activeCategory == null)
            //   StreamBuilder<QuerySnapshot>(
            //     stream: _firestoreService.getAvailableEquipment(),
            //     builder: (context, snapshot) {
            //       if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            //         return const SizedBox();
            //       }

            //       final currentUserId = _auth.currentUser?.uid;
            //       final now = DateTime.now();

            //       final equipmentList = snapshot.data!.docs
            //           .map((doc) {
            //             final equipment = Equipment.fromFirestore(doc);
            //             final data = doc.data() as Map<String, dynamic>;

            //             final status = EquipmentStatus.fromString(data['status'] as String?);
            //             final availableUntil =
            //               (data['availableUntil'] as Timestamp?)?.toDate();

            //             final dateOk = availableUntil != null && now.isBefore(availableUntil);

            //             final isOwnedByUser = equipment.ownerId == currentUserId;

            //             if (!isOwnedByUser && status == EquipmentStatus.available && dateOk){
            //               return equipment;
            //             }
            //             return null;
            //           })
            //           .whereType<Equipment>() // removes nulls
            //           .toList();

            //       if (equipmentList.isEmpty) {
            //         return const SizedBox();
            //       }

            //       return EquipmentCarousel(
            //         equipment: equipmentList,
            //         maxItems: 5,
            //       );
            //     },
            //   ),

            // const SizedBox(height: 10),

            /// FILTERS SECTION (Category + Price)
            if (searchQuery.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // CATEGORY BUTTONS
                    // SizedBox(
                    //   height: 40,
                    //   child: ListView(
                    //     scrollDirection: Axis.horizontal,
                    //     children: [
                    //       CategoryFilterBar(
                    //         activeCategory: activeCategory,
                    //         onCategorySelected: (category) {
                    //           setState(() {
                    //             activeCategory =
                    //                 activeCategory == category ? null : category;
                    //           });
                    //         },
                    //       ),

                    //       const SizedBox(width: 8),

                    //       OperatorFilterButton(
                    //         isActive: operatorFilter,
                    //         onPressed: () {
                    //           setState(() {
                    //             if (operatorFilter == true) {
                    //               operatorFilter = null;
                    //             } else {
                    //               operatorFilter = true;
                    //             }
                    //           });
                    //         },
                    //       ),
                    //     ],
                    //   ),
                    // ),

                    // const SizedBox(height: 8),
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
                              builder: (_) {
                                return PriceFilterSheet(
                                  initialRange: priceRange,
                                  minPrice: minPrice,
                                  maxPrice: maxPrice,
                                  activeCategory: activeCategory,
                                  operatorFilter: operatorFilter,
                                  dateFilter: dateFilter, // NEW
                                  onApply:
                                      (
                                        range,
                                        isActive,
                                        category,
                                        operator,
                                        dates,
                                      ) {
                                        // NEW signature
                                        setState(() {
                                          priceRange = range;
                                          isPriceFilterActive = isActive;
                                          activeCategory = category;
                                          operatorFilter = operator;
                                          dateFilter = dates; // NEW
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

                                if (recommendedOnly)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ActiveFiltersChip(
                                      label: 'Recommended',
                                      onClear: () => setState(
                                        () => recommendedOnly = false,
                                      ),
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
                                          priceRange = RangeValues(
                                            minPrice,
                                            maxPrice,
                                          );
                                        });
                                      },
                                    ),
                                  ),

                                if (dateFilter != null)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ActiveFiltersChip(
                                      label:
                                          '${dateFilter!.start.month}/${dateFilter!.start.day} – ${dateFilter!.end.month}/${dateFilter!.end.day}',
                                      onClear: () =>
                                          setState(() => dateFilter = null),
                                    ),
                                  ),
                              ],
                            ),
                          ),
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
                final filteredEquipment = applyEquipmentFilters(
                  equipmentNotOwnedByUser,
                );
                filteredEquipment.sort((a, b) {
                  final isPendingA =
                      a.category != null &&
                      blockedCategories.contains(a.category);
                  final isPendingB =
                      b.category != null &&
                      blockedCategories.contains(b.category);

                  // Tier 1: available (not pending, not blocked) comes first
                  int tierA = isPendingA ? 2 : (a.isAvailable ? 1 : 3);
                  int tierB = isPendingB ? 2 : (b.isAvailable ? 1 : 3);

                  if (tierA != tierB) return tierA.compareTo(tierB);

                  // Tier 2: within same availability tier, sort by review count descending
                  final reviewsA = _reviewCountCache[a.id] ?? 0;
                  final reviewsB = _reviewCountCache[b.id] ?? 0;
                  return reviewsB.compareTo(reviewsA);
                });

                // Pre-fetch reviews for any items not yet cached
                final uncached = filteredEquipment
                    .where(
                      (e) =>
                          e.id != null && !_reviewCountCache.containsKey(e.id!),
                    )
                    .toList();
                if (uncached.isNotEmpty) {
                  _prefetchReviewCounts(uncached);
                }

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
                          return RentItemCard(
                            title: LanguageNotifier.showTl.value
    ? (equipment.nameTl ?? equipment.name)
    : (equipment.nameEn ?? equipment.name),
                            imageUrl: equipment.imageUrls.isNotEmpty
                                ? equipment.imageUrls[0]
                                : 'assets/images/rent1.jpg',
                            price: '₱${equipment.price.toStringAsFixed(0)}',
                            ownerName: 'Loading...',
                            isAvailable: false,
                            isPending: false,
                            rentalUnit: equipment.rentalUnit,
                            isRecommended: _recommendedToolTypes.contains(
                              equipment.category,
                            ),
                          );
                        }

                        final data =
                            snapshot.data!.data() as Map<String, dynamic>? ??
                            {};
                        final status = EquipmentStatus.fromString(
                          data['status'] as String?,
                        );
                        final availableUntil =
                            (data['availableUntil'] as Timestamp?)?.toDate();

                        final finalAvailability =
                            status == EquipmentStatus.available &&
                            availableUntil != null &&
                            DateTime.now().isBefore(availableUntil);

                        // NEW: Check if category is blocked
                        final isPendingCategory =
                            equipment.category != null &&
                            blockedCategories.contains(equipment.category);

                        return FutureBuilder<String?>(
                          future: _firestoreService.getUserNameById(
                            equipment.ownerId,
                          ),
                          builder: (context, ownerSnapshot) {
                            final ownerName =
                                ownerSnapshot.data ?? 'Unknown Owner';

                            return FutureBuilder<List<Review>>(
                              future: FirestoreService().getReviewsForEquipment(
                                equipment.id!,
                              ),
                              builder: (context, reviewSnap) {
                                final reviews = reviewSnap.data ?? [];
                                final avgRating = reviews.isEmpty
                                    ? null
                                    : reviews
                                              .map((r) => r.rating)
                                              .reduce((a, b) => a + b) /
                                          reviews.length;
                                final reviewCount = reviews.isEmpty
                                    ? null
                                    : reviews.length;

                                // PENDING CATEGORY: orange + tap shows message
                                if (isPendingCategory) {
                                  return Opacity(
                                    opacity: 0.6,
                                    child: GestureDetector(
                                      onTap: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'You already have an active request for a ${equipment.category}. Complete or cancel it first.',
                                            ),
                                            duration: const Duration(
                                              seconds: 3,
                                            ),
                                          ),
                                        );
                                      },
                                      child: RentItemCard(
                                        title: LanguageNotifier.showTl.value
    ? (equipment.nameTl ?? equipment.name)
    : (equipment.nameEn ?? equipment.name),
                                        imageUrl: equipment.imageUrls.isNotEmpty
                                            ? equipment.imageUrls[0]
                                            : 'assets/images/rent1.jpg',
                                        price:
                                            '₱${equipment.price.toStringAsFixed(0)}',
                                        ownerName: ownerName,
                                        rentalUnit: equipment.rentalUnit,
                                        isAvailable: false,
                                        isPending: true,
                                        isRecommended: _recommendedToolTypes
                                            .contains(equipment.category),
                                        rating: avgRating,
                                        reviewCount: reviewCount,
                                      ),
                                    ),
                                  );
                                }

                                // 🔴 UNAVAILABLE: greyed + tap shows message
                                if (!finalAvailability) {
                                  return Opacity(
                                    opacity: 0.5,
                                    child: GestureDetector(
                                      onTap: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'This equipment is currently unavailable.',
                                            ),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                        final tempItem = equipment.copyWith(
                                          ownerName: ownerName,
                                        );
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ProductPage(item: tempItem),
                                          ),
                                        );
                                      },
                                      child: RentItemCard(
                                        title: LanguageNotifier.showTl.value
    ? (equipment.nameTl ?? equipment.name)
    : (equipment.nameEn ?? equipment.name),
                                        imageUrl: equipment.imageUrls.isNotEmpty
                                            ? equipment.imageUrls[0]
                                            : 'assets/images/rent1.jpg',
                                        price:
                                            '₱${equipment.price.toStringAsFixed(0)}',
                                        ownerName: ownerName,
                                        rentalUnit: equipment.rentalUnit,
                                        isAvailable: false,
                                        isPending: false,
                                        isRecommended: _recommendedToolTypes
                                            .contains(equipment.category),
                                        rating: avgRating,
                                        reviewCount: reviewCount,
                                      ),
                                    ),
                                  );
                                }

                                // 🟢 AVAILABLE: tappable
                                return GestureDetector(
                                  onTap: () {
                                    final tempItem = equipment.copyWith(
                                      ownerName: ownerName,
                                    );
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ProductPage(item: tempItem),
                                      ),
                                    );
                                  },
                                  child: RentItemCard(
                                    title: LanguageNotifier.showTl.value
    ? (equipment.nameTl ?? equipment.name)
    : (equipment.nameEn ?? equipment.name),
                                    imageUrl: equipment.imageUrls.isNotEmpty
                                        ? equipment.imageUrls[0]
                                        : 'assets/images/rent1.jpg',
                                    price:
                                        '₱${equipment.price.toStringAsFixed(0)}',
                                    ownerName: ownerName,
                                    rentalUnit: equipment.rentalUnit,
                                    isAvailable: true,
                                    isPending: false,
                                    isRecommended: _recommendedToolTypes
                                        .contains(equipment.category),
                                    rating: avgRating,
                                    reviewCount: reviewCount,
                                  ),
                                );
                              },
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
