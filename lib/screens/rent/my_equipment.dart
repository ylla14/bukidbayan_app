import 'dart:async';

import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/models/review.dart';
import 'package:bukidbayan_app/screens/rent/equipment_listing_form_screen.dart';
import 'package:bukidbayan_app/screens/rent/product_page.dart';
import 'package:bukidbayan_app/screens/rent/request_sent.dart';
import 'package:bukidbayan_app/services/maintenance_service.dart';
import 'package:bukidbayan_app/services/strike_service.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/services/weather_service.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────
// Sort & Filter enums
// ─────────────────────────────────────────────

enum EquipmentSortOption {
  nameAZ,
  nameZA,
  priceLow,
  priceHigh,
  ratingHigh,
  ratingLow,
  maintenanceHours,
  newest,
}

extension EquipmentSortOptionLabel on EquipmentSortOption {
  String get label {
    switch (this) {
      case EquipmentSortOption.nameAZ:
        return 'Name (A–Z)';
      case EquipmentSortOption.nameZA:
        return 'Name (Z–A)';
      case EquipmentSortOption.priceLow:
        return 'Price: Low → High';
      case EquipmentSortOption.priceHigh:
        return 'Price: High → Low';
      case EquipmentSortOption.ratingHigh:
        return 'Rating: Best First';
      case EquipmentSortOption.ratingLow:
        return 'Rating: Lowest First';
      case EquipmentSortOption.maintenanceHours:
        return 'Maintenance Hours';
      case EquipmentSortOption.newest:
        return 'Newest First';
    }
  }

  IconData get icon {
    switch (this) {
      case EquipmentSortOption.nameAZ:
      case EquipmentSortOption.nameZA:
        return Icons.sort_by_alpha;
      case EquipmentSortOption.priceLow:
      case EquipmentSortOption.priceHigh:
        return Icons.attach_money;
      case EquipmentSortOption.ratingHigh:
      case EquipmentSortOption.ratingLow:
        return Icons.star_rounded;
      case EquipmentSortOption.maintenanceHours:
        return Icons.build_rounded;
      case EquipmentSortOption.newest:
        return Icons.schedule;
    }
  }
}

// ─────────────────────────────────────────────
// Filter state
// ─────────────────────────────────────────────

class _FilterState {
  final EquipmentSortOption sortOption;
  final EquipmentStatus? statusFilter;
  final bool onlyForMaintenance;
  final bool onlyUpcomingMaintenance;

  const _FilterState({
    this.sortOption = EquipmentSortOption.newest,
    this.statusFilter,
    this.onlyForMaintenance = false,
    this.onlyUpcomingMaintenance = false,
  });

  _FilterState copyWith({
    EquipmentSortOption? sortOption,
    Object? statusFilter = _sentinel,
    bool? onlyForMaintenance,
    bool? onlyUpcomingMaintenance,
  }) {
    return _FilterState(
      sortOption: sortOption ?? this.sortOption,
      statusFilter: statusFilter == _sentinel
          ? this.statusFilter
          : statusFilter as EquipmentStatus?,
      onlyForMaintenance: onlyForMaintenance ?? this.onlyForMaintenance,
      onlyUpcomingMaintenance:
          onlyUpcomingMaintenance ?? this.onlyUpcomingMaintenance,
    );
  }
}

const Object _sentinel = Object();

// ─────────────────────────────────────────────
// Main widget
// ─────────────────────────────────────────────

class MyEquipment extends StatefulWidget {
  const MyEquipment({super.key});

  @override
  State<MyEquipment> createState() => _MyEquipmentState();
}

class _MyEquipmentState extends State<MyEquipment> {
  final FirestoreService _firestoreService = FirestoreService();

  _FilterState _filter = const _FilterState();

  final Map<String, double> _ratingCache = {};
  final Set<String> _ratingFetchedIds = {};
  StreamSubscription<QuerySnapshot>? _equipmentSub;

  @override
  void initState() {
    super.initState();
    _subscribeToEquipmentForRatings();
  }

  @override
  void dispose() {
    _equipmentSub?.cancel();
    super.dispose();
  }

  void _subscribeToEquipmentForRatings() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _equipmentSub = FirebaseFirestore.instance
        .collection('equipment')
        .where('ownerId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      final ids = snap.docs
          .map((d) => d.id)
          .where((id) => !_ratingFetchedIds.contains(id))
          .toList();

      if (ids.isEmpty) return;
      _ratingFetchedIds.addAll(ids);
      _fetchRatingsForIds(ids);
    });
  }

  Future<void> _fetchRatingsForIds(List<String> ids) async {
    const chunkSize = 30;
    final chunks = <List<String>>[];
    for (var i = 0; i < ids.length; i += chunkSize) {
      chunks.add(ids.sublist(
          i, i + chunkSize > ids.length ? ids.length : i + chunkSize));
    }

    final futures = chunks.map((chunk) async {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('reviews')
            .where('itemId', whereIn: chunk)
            .get();

        final grouped = <String, List<double>>{};
        for (final doc in snap.docs) {
          final review = Review.fromDoc(doc);
          grouped.putIfAbsent(review.itemId, () => []).add(review.rating);
        }

        for (final id in chunk) {
          final ratings = grouped[id];
          _ratingCache[id] = ratings == null || ratings.isEmpty
              ? 0
              : double.parse(
                  (ratings.reduce((a, b) => a + b) / ratings.length)
                      .toStringAsFixed(1));
        }
      } catch (_) {
        for (final id in chunk) {
          _ratingCache.putIfAbsent(id, () => 0);
        }
      }
    });

    await Future.wait(futures);
    if (mounted) setState(() {});
  }

  // ── Sorting + filtering ───────────────────────────────────────
  List<Equipment> _applyFilterAndSort(List<Equipment> list) {
    var result = List<Equipment>.from(list);

    if (_filter.statusFilter != null) {
      result = result.where((e) => e.status == _filter.statusFilter).toList();
    }
    if (_filter.onlyForMaintenance) {
      result = result.where((e) => e.isForMaintenance).toList();
    }
    if (_filter.onlyUpcomingMaintenance) {
      result = result.where((e) => e.isUpcomingMaintenance).toList();
    }

    result.sort((a, b) {
      switch (_filter.sortOption) {
        case EquipmentSortOption.nameAZ:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case EquipmentSortOption.nameZA:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case EquipmentSortOption.priceLow:
          return a.price.compareTo(b.price);
        case EquipmentSortOption.priceHigh:
          return b.price.compareTo(a.price);
        case EquipmentSortOption.ratingHigh:
          return (_ratingCache[b.id] ?? 0).compareTo(_ratingCache[a.id] ?? 0);
        case EquipmentSortOption.ratingLow:
          return (_ratingCache[a.id] ?? 0).compareTo(_ratingCache[b.id] ?? 0);
        case EquipmentSortOption.maintenanceHours:
          return b.hoursUsedSinceLastMaintenance
              .compareTo(a.hoursUsedSinceLastMaintenance);
        case EquipmentSortOption.newest:
          final aDate = a.createdAt ?? DateTime(2000);
          final bDate = b.createdAt ?? DateTime(2000);
          return bDate.compareTo(aDate);
      }
    });

    return result;
  }

  // ── Sort/Filter bottom sheet ──────────────────────────────────
  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final maxHeight = MediaQuery.of(ctx).size.height * 0.85;
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header ────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: lightColorScheme.primary
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.tune_rounded,
                                  color: lightColorScheme.primary, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Ayusin at I-filter',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: lightColorScheme.primary,
                                  ),
                                ),
                                Text(
                                  'Piliin kung paano ipapakita ang iyong mga kagamitan.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                      ],
                    ),
                  ),

                  // ── Scrollable body ───────────────────────────
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sheetSectionLabel('PAGKAKASUNOD-SUNOD'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: EquipmentSortOption.values.map((opt) {
                              final selected = _filter.sortOption == opt;
                              return ChoiceChip(
                                avatar: Icon(opt.icon,
                                    size: 14,
                                    color: selected
                                        ? Colors.white
                                        : lightColorScheme.primary),
                                label: Text(opt.label),
                                selected: selected,
                                onSelected: (_) => setSheetState(
                                    () => _filter =
                                        _filter.copyWith(sortOption: opt)),
                                selectedColor: lightColorScheme.primary,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: selected
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                backgroundColor: Colors.grey.shade100,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: selected
                                        ? lightColorScheme.primary
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                showCheckmark: false,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          _sheetSectionLabel('KATAYUAN'),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _statusChip(
                                setSheetState: setSheetState,
                                value: null,
                                label: 'Lahat',
                                icon: Icons.all_inclusive,
                                color: Colors.blueGrey,
                              ),
                              _statusChip(
                                setSheetState: setSheetState,
                                value: EquipmentStatus.available,
                                label: 'Available',
                                icon: Icons.check_circle_outline,
                                color: Colors.green.shade600,
                              ),
                              _statusChip(
                                setSheetState: setSheetState,
                                value: EquipmentStatus.unavailable,
                                label: 'Unavailable',
                                icon: Icons.cancel_outlined,
                                color: Colors.grey.shade600,
                              ),
                              _statusChip(
                                setSheetState: setSheetState,
                                value: EquipmentStatus.underMaintenance,
                                label: 'Maintenance',
                                icon: Icons.build_outlined,
                                color: Colors.orange.shade700,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Divider(height: 1),
                          const SizedBox(height: 16),
                          _sheetSectionLabel('MAINTENANCE FLAGS'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _toggleChip(
                                  label: 'For Maintenance',
                                  icon: Icons.build_rounded,
                                  color: Colors.red,
                                  value: _filter.onlyForMaintenance,
                                  onChanged: (v) => setSheetState(() =>
                                      _filter = _filter.copyWith(
                                          onlyForMaintenance: v)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _toggleChip(
                                  label: 'Upcoming Maintenance',
                                  icon: Icons.warning_amber_rounded,
                                  color: Colors.amber.shade700,
                                  value: _filter.onlyUpcomingMaintenance,
                                  onChanged: (v) => setSheetState(() =>
                                      _filter = _filter.copyWith(
                                          onlyUpcomingMaintenance: v)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  // ── Pinned action buttons ──────────────────────
                  const Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      12 + MediaQuery.of(ctx).viewPadding.bottom,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setSheetState(
                                () => _filter = const _FilterState()),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              foregroundColor: Colors.black54,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('I-reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {});
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: lightColorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Ilapat'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey.shade500,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _statusChip({
    required StateSetter setSheetState,
    required EquipmentStatus? value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final selected = _filter.statusFilter == value;
    return ChoiceChip(
      avatar: Icon(icon, size: 14, color: selected ? Colors.white : color),
      label: Text(label),
      selected: selected,
      onSelected: (_) => setSheetState(
          () => _filter = _filter.copyWith(statusFilter: value)),
      selectedColor: color,
      labelStyle: TextStyle(
        fontSize: 12,
        color: selected ? Colors.white : Colors.black87,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      backgroundColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: selected ? color : Colors.grey.shade300),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }

  Widget _toggleChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: value ? color.withOpacity(0.08) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: value ? color : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: value ? color : Colors.grey),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: value ? color : Colors.black54,
                  fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────
  bool get _hasActiveFilters =>
      _filter.statusFilter != null ||
      _filter.onlyForMaintenance ||
      _filter.onlyUpcomingMaintenance ||
      _filter.sortOption != EquipmentSortOption.newest;

  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Aking Equipment',
          style: TextStyle(
            color: lightColorScheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [lightColorScheme.primary, lightColorScheme.secondary],
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                color: Colors.white,
                tooltip: 'Ayusin at I-filter',
                onPressed: _showSortSheet,
              ),
              if (_hasActiveFilters)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ── Overdue returns banner ────────────────────────────
          _OverdueReturnsSection(ownerId: uid),

          // ── Active filter chips row ───────────────────────────
          if (_hasActiveFilters) ...[
            _ActiveFilterBar(
              filter: _filter,
              onClear: () => setState(() => _filter = const _FilterState()),
            ),
            const SizedBox(height: 10),
          ],

          // ── Equipment list ────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('equipment')
                .where('ownerId', isEqualTo: uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _EmptyState(
                  icon: Icons.agriculture_rounded,
                  title: 'Walang kagamitan pa',
                  subtitle:
                      'Mag-lista ng iyong unang kagamitan para magsimulang mag-rent out.',
                );
              }

              final rawList = snapshot.data!.docs
                  .map((doc) => Equipment.fromFirestore(doc))
                  .toList();

              final filteredList = _applyFilterAndSort(rawList);

              if (filteredList.isEmpty) {
                return _EmptyState(
                  icon: Icons.filter_list_off,
                  title: 'Walang nagtutugmang kagamitan',
                  subtitle: 'Subukang baguhin ang iyong filter.',
                  action: TextButton(
                    onPressed: () =>
                        setState(() => _filter = const _FilterState()),
                    child: const Text('I-clear ang Filter'),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '${filteredList.length} kagamitan',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ...filteredList.map((eq) => buildEquipmentCard(context, eq)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Equipment card (improved)
  // ─────────────────────────────────────────────────────────────
  Widget buildEquipmentCard(BuildContext context, Equipment equipment) {
    return FutureBuilder<String?>(
      future: _firestoreService.getUserNameById(equipment.ownerId),
      builder: (context, snapshot) {
        final ownerName = snapshot.data ?? 'Unknown Owner';

        final tempItem = Equipment(
          name: equipment.name,
          imageUrls: equipment.imageUrls.isNotEmpty
              ? equipment.imageUrls
              : ['assets/images/rent1.jpg'],
          category: equipment.category ?? 'Other',
          price: equipment.price,
          availableFrom: equipment.availableFrom,
          availableUntil: equipment.availableUntil,
          brand: equipment.brand,
          yearModel: equipment.yearModel,
          power: equipment.power,
          fuelType: equipment.fuelType,
          condition: equipment.condition,
          attachments: equipment.attachments,
          operatorIncluded: equipment.operatorIncluded,
          rentRate: equipment.rentRate,
          landSizeRequirement: equipment.landSizeRequirement,
          maxCropHeightRequirement: equipment.maxCropHeightRequirement,
          id: equipment.id ?? 'UNKNOWN ID',
          description: equipment.description,
          landSizeMax: equipment.landSizeMax,
          landSizeMin: equipment.landSizeMin,
          maxCropHeight: equipment.maxCropHeight,
          ownerName: ownerName,
          rentalUnit: equipment.rentalUnit,
          ownerId: equipment.ownerId,
          status: equipment.status,
        );

        final avgRating = _ratingCache[equipment.id] ?? -1;
final suggestRetirement = equipment.retirementFlaggedByAdmin ||
    equipment.damageReportCount >= StrikeService.kDamageRetirementThreshold ||
    (StrikeService.isMotorizedEquipment(equipment.name) &&
        equipment.majorBreakdownCount >= StrikeService.kMajorBreakdownThreshold);
        final hasBadge = avgRating >= 0 ||
            equipment.isForMaintenance ||
            equipment.isUpcomingMaintenance ||
            suggestRetirement;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Card ─────────────────────────────────────────────
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ProductPage(item: tempItem)),
              ),
              child: Card(
                elevation: 2,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Banner image ────────────────────────────
                    Stack(
                      children: [
                        SizedBox(
                          height: 100, // was 160
                          child: equipment.imageUrls.isNotEmpty
                              ? Image.network(
                                  equipment.imageUrls.first,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _bannerPlaceholder(),
                                )
                              : _bannerPlaceholder(),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _StatusPill(status: equipment.status),
                        ),
                      ],
                    ),

                    // ── Content ─────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0), // was 14,12,14,0
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  equipment.name,
                                  style: const TextStyle(
                                    fontSize: 14, // was 16
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '₱${equipment.price}/${equipment.rentalUnit}',
                                style: TextStyle(
                                  fontSize: 12, // was 15, moved inline to save a row
                                  fontWeight: FontWeight.w700,
                                  color: lightColorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            equipment.category ?? 'No category',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500), // was 12
                          ),

                          // ── Badge row ────────────────────────
                          if (hasBadge) ...[
                            const SizedBox(height: 6), // was 8
                            Wrap(
                              spacing: 5,
                              runSpacing: 5,
                              children: [
                                if (avgRating >= 0) _RatingBadge(rating: avgRating),
                                if (equipment.isForMaintenance)
                                  _BadgePill(
                                    label: 'For Maintenance',
                                    icon: Icons.build_rounded,
                                    textColor: Colors.red.shade700,
                                    bgColor: Colors.red.shade50,
                                    borderColor: Colors.red.shade200,
                                  ),
                                if (!equipment.isForMaintenance && equipment.isUpcomingMaintenance)
                                  _BadgePill(
                                    label: 'Upcoming Maintenance',
                                    icon: Icons.warning_amber_rounded,
                                    textColor: Colors.amber.shade800,
                                    bgColor: Colors.amber.shade50,
                                    borderColor: Colors.amber.shade300,
                                  ),
                                if (suggestRetirement)
                                  _BadgePill(
                                    label: 'Suggest Retirement',
                                    icon: Icons.archive_outlined,
                                    textColor: Colors.deepOrange.shade700,
                                    bgColor: Colors.deepOrange.shade50,
                                    borderColor: Colors.deepOrange.shade200,
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8), // was 12
                        ],
                      ),
                    ),

                    // ── Action strip ────────────────────────────
                    const Divider(height: 1),
                    IntrinsicHeight(
                      child: Row(
                        children: [
                         _CardAction(
                            icon: Icons.edit_outlined,
                            label: 'Edit',
                            color: lightColorScheme.primary,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EquipmentListingScreen(
                                    existingEquipment: tempItem),
                              ),
                            ),
                          ),
                          const VerticalDivider(width: 1, thickness: 1),
                          _CardAction(
                            icon: equipment.status == EquipmentStatus.available
                                ? Icons.build_outlined
                                : Icons.check_circle_outline,
                            label:
                                equipment.status == EquipmentStatus.available
                                    ? 'Maintenance'
                                    : 'Set Available',
                            color: equipment.status ==
                                    EquipmentStatus.unavailable
                                ? Colors.grey.shade400
                                : equipment.status == EquipmentStatus.available
                                    ? const Color(0xFFF59E0B)
                                    : Colors.green.shade600,
                            enabled: equipment.status !=
                                EquipmentStatus.unavailable,
                            onTap: () async {
                              if (equipment.status ==
                                  EquipmentStatus.available) {
                                await _scheduleMaintenance(context, equipment);
                              } else {
                                await _endMaintenance(context, equipment);
                              }
                            },
                          ),
                          const VerticalDivider(width: 1, thickness: 1),
                          _CardAction(
                            icon: Icons.delete_outline,
                            label: 'Delete',
                            color: Colors.red.shade500,
                            onTap: () => _deleteEquipment(context, equipment),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Weather postpone (attaches to card bottom) ───────
            if (equipment.id != null)
              _WeatherPostponeSection(equipment: equipment),

            const SizedBox(height: 14),
          ],
        );
      },
    );
  }

  Widget _bannerPlaceholder() {
    return Container(
      height: 160,
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(Icons.agriculture_rounded,
            color: Colors.grey.shade400, size: 48),
      ),
    );
  }

  // ── Migration helpers (dev-use only) ──────────────────────────
  Future<void> migrateEquipmentStatus(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Run Migration?'),
        content: const Text(
          'This will add a "status" field to all equipment docs that are missing it, based on their old "isAvailable" value. Safe to run multiple times.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Run')),
        ],
      ),
    );
    if (confirm != true) return;
    final snapshot =
        await FirebaseFirestore.instance.collection('equipment').get();
    int updated = 0, skipped = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['status'] != null) {
        skipped++;
        continue;
      }
      final oldIsAvailable = data['isAvailable'] is bool
          ? data['isAvailable']
          : data['isAvailable']?.toString().toLowerCase() == 'true';
      final newStatus = oldIsAvailable == true
          ? EquipmentStatus.available.toValue()
          : EquipmentStatus.unavailable.toValue();
      await doc.reference.update({'status': newStatus});
      updated++;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Migration done. Updated: $updated, Skipped: $skipped')));
    }
  }

  Future<void> rollbackEquipmentStatus(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rollback Migration?'),
        content: const Text(
          'This will remove the "status" field and restore "isAvailable" (bool) on all equipment docs.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Rollback')),
        ],
      ),
    );
    if (confirm != true) return;
    final snapshot =
        await FirebaseFirestore.instance.collection('equipment').get();
    int updated = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = data['status'];
      if (status == null) continue;
      final isAvailable = status == EquipmentStatus.available.toValue();
      await doc.reference.update({
        'isAvailable': isAvailable,
        'status': FieldValue.delete(),
      });
      updated++;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Rollback done. Restored isAvailable on $updated docs.')));
    }
  }

  // ── Notification helper ───────────────────────────────────────
  Future<void> _sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic> extra = const {},
  }) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .add({
      'title': title,
      'body': body,
      'type': type,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
      ...extra,
    });
  }

  Future<List<_AffectedBooking>> _fetchAffectedBookings({
    required String equipmentId,
    required DateTime today,
    required DateTime maintenanceEnd,
    required bool isUnforeseen,
    DateTime? availableUntil,
  }) async {
    const activeStatuses = ['pending', 'approved', 'readyForPickup'];
    final snap = await FirebaseFirestore.instance
        .collection('rentRequests')
        .where('itemId', isEqualTo: equipmentId)
        .where('status', whereIn: activeStatuses)
        .get();

    final maintenanceEndDay = DateTime(
        maintenanceEnd.year, maintenanceEnd.month, maintenanceEnd.day);
    final sortedDocs = snap.docs.toList()
      ..sort((a, b) {
        final aStart = (a.data()['start'] as Timestamp).toDate();
        final bStart = (b.data()['start'] as Timestamp).toDate();
        return aStart.compareTo(bStart);
      });

    final results = <_AffectedBooking>[];

    if (isUnforeseen) {
      for (final doc in sortedDocs) {
        final request = RentRequest.fromDoc(doc);
        final bookingStart = DateTime(
            request.start.year, request.start.month, request.start.day);
        final bookingEnd =
            DateTime(request.end.year, request.end.month, request.end.day);
        final overlaps =
            bookingStart.isBefore(
                maintenanceEndDay.add(const Duration(days: 1))) &&
            bookingEnd.isAfter(today.subtract(const Duration(days: 1)));
        if (!overlaps) continue;
        results.add(_AffectedBooking(
          renterName: request.name,
          start: request.start,
          end: request.end,
          willBeCancelled: true,
        ));
      }
    } else {
      DateTime blockedUntil = maintenanceEndDay;
      for (final doc in sortedDocs) {
        final request = RentRequest.fromDoc(doc);
        final bookingStart = DateTime(
            request.start.year, request.start.month, request.start.day);
        if (bookingStart.isAfter(blockedUntil)) continue;

        final bookingDuration = request.end.difference(request.start);
        final newStart = DateTime(
          blockedUntil.year,
          blockedUntil.month,
          blockedUntil.day,
          request.start.hour,
          request.start.minute,
        ).add(const Duration(days: 1));
        final newEnd = newStart.add(bookingDuration);
        final exceedsAvailability =
            availableUntil != null && newEnd.isAfter(availableUntil);

        results.add(_AffectedBooking(
          renterName: request.name,
          start: request.start,
          end: request.end,
          willBeCancelled: exceedsAvailability,
          newStart: exceedsAvailability ? null : newStart,
          newEnd: exceedsAvailability ? null : newEnd,
        ));

        if (!exceedsAvailability) {
          blockedUntil =
              DateTime(newEnd.year, newEnd.month, newEnd.day);
        }
      }
    }
    return results;
  }

  // ── Schedule maintenance ──────────────────────────────────────
  Future<void> _scheduleMaintenance(
      BuildContext context, Equipment equipment) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) =>
          _MaintenanceDatePicker(equipmentName: equipment.name, today: today),
    );
    if (picked == null || !context.mounted) return;

    final maintenanceEnd =
        DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
    final durationDays = maintenanceEnd.difference(today).inDays + 1;
    final isUnforeseen = durationDays > 7;

    final affectedBookings = await _fetchAffectedBookings(
      equipmentId: equipment.id!,
      today: today,
      maintenanceEnd: maintenanceEnd,
      isUnforeseen: isUnforeseen,
      availableUntil: equipment.availableUntil,
    );
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isUnforeseen
                  ? Icons.warning_amber_rounded
                  : Icons.build_outlined,
              color: isUnforeseen ? Colors.red : Colors.orange,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(isUnforeseen
                  ? 'Hindi Inaasahang Maintenance'
                  : 'I-schedule ang Maintenance'),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Panahon ng Maintenance: ${DateFormat('MMM d').format(today)} – ${DateFormat('MMM d, yyyy').format(maintenanceEnd)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '$durationDays na araw',
                  style: TextStyle(
                    color: isUnforeseen
                        ? Colors.red
                        : lightColorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                if (isUnforeseen)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const Text(
                      'Ang maintenance ay higit sa 7 araw. Lahat ng booking sa panahong ito ay IKAKANSELA.',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: lightColorScheme.secondary,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: lightColorScheme.primary),
                    ),
                    child: Text(
                      'Ang mga booking sa panahong ito ay ire-reschedule pagkatapos ng maintenance.',
                      style: TextStyle(
                          color: lightColorScheme.primary, fontSize: 13),
                    ),
                  ),
                if (affectedBookings.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Mga Apektadong Booking (${affectedBookings.length})',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  ...affectedBookings.map((b) => Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: b.willBeCancelled
                              ? Colors.red.shade50
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: b.willBeCancelled
                                ? Colors.red.shade200
                                : Colors.orange.shade300,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              b.willBeCancelled
                                  ? Icons.cancel_outlined
                                  : Icons.event_repeat,
                              size: 16,
                              color: b.willBeCancelled
                                  ? Colors.red.shade700
                                  : Colors.orange.shade800,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(b.renterName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                  Text(
                                    '${DateFormat('MMM d').format(b.start)} – ${DateFormat('MMM d, yyyy').format(b.end)}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700),
                                  ),
                                  if (!b.willBeCancelled &&
                                      b.newStart != null &&
                                      b.newEnd != null) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.arrow_forward,
                                            size: 12,
                                            color: Colors.orange.shade700),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${DateFormat('MMM d').format(b.newStart!)} – ${DateFormat('MMM d, yyyy').format(b.newEnd!)}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange.shade800,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 2),
                                  Text(
                                    b.willBeCancelled
                                        ? 'Ikakansela'
                                        : 'Ire-reschedule',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: b.willBeCancelled
                                          ? Colors.red.shade700
                                          : Colors.orange.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                ] else ...[
                  const SizedBox(height: 12),
                  const Text('Walang booking ang maaapektuhan.',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Kanselahin')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isUnforeseen ? Colors.red : lightColorScheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kumpirmahin'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final db = FirebaseFirestore.instance;
      await db.collection('equipment').doc(equipment.id).update({
        'status': EquipmentStatus.underMaintenance.toValue(),
        'isAvailable': false,
        'maintenanceStart': Timestamp.fromDate(today),
        'maintenanceEnd': Timestamp.fromDate(maintenanceEnd),
      });

      const activeStatuses = ['pending', 'approved', 'readyForPickup'];
      final bookingsSnap = await db
          .collection('rentRequests')
          .where('itemId', isEqualTo: equipment.id)
          .where('status', whereIn: activeStatuses)
          .get();

      final batch = db.batch();
      final List<Future<void>> notifFutures = [];
      final sortedDocs = bookingsSnap.docs.toList()
        ..sort((a, b) {
          final aStart = (a.data()['start'] as Timestamp).toDate();
          final bStart = (b.data()['start'] as Timestamp).toDate();
          return aStart.compareTo(bStart);
        });

      DateTime blockedUntil = DateTime(
          maintenanceEnd.year, maintenanceEnd.month, maintenanceEnd.day);
      final maintenanceEndDay = DateTime(
          maintenanceEnd.year, maintenanceEnd.month, maintenanceEnd.day);

      for (final doc in sortedDocs) {
        final request = RentRequest.fromDoc(doc);
        final bookingStart = DateTime(
            request.start.year, request.start.month, request.start.day);
        final bookingEnd =
            DateTime(request.end.year, request.end.month, request.end.day);

        if (isUnforeseen) {
          final overlaps =
              bookingStart.isBefore(
                  maintenanceEndDay.add(const Duration(days: 1))) &&
              bookingEnd.isAfter(today.subtract(const Duration(days: 1)));
          if (!overlaps) continue;

          batch.update(doc.reference, {
            'status': RentRequestStatus.canceled.name,
            'declineReason':
                'Ang kagamitan ay naka-schedule para sa hindi inaasahang maintenance mula '
                '${DateFormat('MMM d').format(today)} hanggang ${DateFormat('MMM d, yyyy').format(maintenanceEnd)}. '
                'Paumanhin sa abala.',
          });
          notifFutures.add(_sendNotification(
            userId: request.renterId,
            title: '🔧 Kinansela ang Booking — Maintenance',
            body: 'Ang iyong booking para sa "${equipment.name}" '
                '(${DateFormat('MMM d').format(request.start)} – ${DateFormat('MMM d').format(request.end)}) '
                'ay kinansela dahil sa hindi inaasahang maintenance ($durationDays na araw).',
            type: 'maintenance_cancel',
            extra: {
              'requestId': request.requestId,
              'equipmentId': equipment.id,
            },
          ));
        } else {
          if (bookingStart.isAfter(blockedUntil)) continue;
          final bookingDuration = request.end.difference(request.start);
          final newStart = DateTime(
            blockedUntil.year,
            blockedUntil.month,
            blockedUntil.day,
            request.start.hour,
            request.start.minute,
          ).add(const Duration(days: 1));
          final newEnd = newStart.add(bookingDuration);
          final exceedsAvailability = equipment.availableUntil != null &&
              newEnd.isAfter(equipment.availableUntil!);

          if (exceedsAvailability) {
            batch.update(doc.reference, {
              'status': RentRequestStatus.canceled.name,
              'declineReason':
                  'Hindi ma-reschedule ang booking pagkatapos ng maintenance.',
            });
            notifFutures.add(_sendNotification(
              userId: request.renterId,
              title: '🔧 Kinansela ang Booking — Labas ng Availability',
              body: 'Hindi ma-reschedule ang iyong booking para sa "${equipment.name}" '
                  'pagkatapos ng maintenance. Kinansela na ang iyong booking.',
              type: 'maintenance_cancel',
              extra: {
                'requestId': request.requestId,
                'equipmentId': equipment.id,
              },
            ));
          } else {
            batch.update(doc.reference, {
              'start': Timestamp.fromDate(newStart),
              'end': Timestamp.fromDate(newEnd),
              'originalStart': Timestamp.fromDate(request.start),
              'originalEnd': Timestamp.fromDate(request.end),
              'maintenanceRescheduled': true,
            });
            notifFutures.add(_sendNotification(
              userId: request.renterId,
              title: '📅 Na-reschedule ang Booking — Maintenance',
              body: 'Ang iyong booking para sa "${equipment.name}" ay inilipat mula '
                  '${DateFormat('MMM d').format(request.start)} – ${DateFormat('MMM d').format(request.end)} '
                  'patungong ${DateFormat('MMM d').format(newStart)} – ${DateFormat('MMM d, yyyy').format(newEnd)}.',
              type: 'maintenance_reschedule',
              extra: {
                'requestId': request.requestId,
                'equipmentId': equipment.id,
                'ownerId': equipment.ownerId,
                'canCancel': true,
                'canAccept': true,
                'newStart': Timestamp.fromDate(newStart),
                'newEnd': Timestamp.fromDate(newEnd),
              },
            ));
            blockedUntil = DateTime(newEnd.year, newEnd.month, newEnd.day);
          }
        }
      }

      await batch.commit();
      await Future.wait(notifFutures);
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isUnforeseen
              ? '⚠️ Maintenance na-set. Ang mga apektadong booking ay kinansela.'
              : '✅ Maintenance na-schedule. Ang mga booking ay na-reschedule.'),
          backgroundColor: isUnforeseen ? Colors.red : Colors.green,
          duration: const Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // ── End maintenance ───────────────────────────────────────────
  Future<void> _endMaintenance(
      BuildContext context, Equipment equipment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tapusin ang Maintenance'),
        content: const Text('Markahan ang kagamitan bilang available na?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Kanselahin')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Markahan Bilang Available'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await FirebaseFirestore.instance
        .collection('equipment')
        .doc(equipment.id)
        .update({
      'status': EquipmentStatus.available.toValue(),
      'isAvailable': true,
      'maintenanceStart': null,
      'maintenanceEnd': null,
    });
    await MaintenanceService().resetMaintenanceHours(equipment.id!);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Equipment is now available.'),
          backgroundColor: Colors.green));
    }
  }

  // ── Delete equipment ──────────────────────────────────────────
  Future<void> _deleteEquipment(
      BuildContext context, Equipment equipment) async {
    final activeSnap = await FirebaseFirestore.instance
        .collection('rentRequests')
        .where('itemId', isEqualTo: equipment.id)
        .where('status', whereIn: [
          'pending',
          'approved',
          'onTheWay',
          'inProgress',
          'readyForPickup',
        ])
        .get();

    if (activeSnap.docs.isNotEmpty && context.mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [
            Icon(Icons.block, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Text('Cannot Delete'),
          ]),
          content: Text(
            'This equipment has ${activeSnap.docs.length} active '
            '${activeSnap.docs.length == 1 ? 'booking' : 'bookings'}. '
            'Please resolve all active bookings before deleting.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
          SizedBox(width: 8),
          Flexible(child: Text('Burahin ang Kagamitan')),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                children: [
                  const TextSpan(
                      text: 'Sigurado ka bang gusto mong burahin ang '),
                  TextSpan(
                    text: '"${equipment.name}"',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                      text:
                          '? Hindi na maaaring bawiin ang pagkilos na ito.'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Kanselahin')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Burahin'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await _firestoreService.deleteEquipment(equipment.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"${equipment.name}" has been deleted.'),
          backgroundColor: Colors.red.shade600,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error deleting equipment: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }
}

// ─────────────────────────────────────────────
// Status pill (floats over banner image)
// ─────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final EquipmentStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final String label;

    switch (status) {
      case EquipmentStatus.available:
        bg = Colors.green.shade600;
        label = 'Available';
        break;
      case EquipmentStatus.underMaintenance:
        bg = Colors.orange.shade600;
        label = 'Under Maintenance';
        break;
      case EquipmentStatus.unavailable:
        bg = Colors.grey.shade600;
        label = 'Unavailable';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Generic badge pill
// ─────────────────────────────────────────────

class _BadgePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color textColor;
  final Color bgColor;
  final Color borderColor;

  const _BadgePill({
    required this.label,
    required this.icon,
    required this.textColor,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Card action button (bottom strip)
// ─────────────────────────────────────────────

class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  const _CardAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = enabled ? color : Colors.grey.shade400;
    return Expanded(
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: effectiveColor),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: effectiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Rating badge
// ─────────────────────────────────────────────

class _RatingBadge extends StatelessWidget {
  final double rating;
  const _RatingBadge({required this.rating});

  @override
  Widget build(BuildContext context) {
    final hasRating = rating > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasRating ? Colors.amber.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasRating ? Colors.amber.shade400 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: 13,
            color: hasRating ? Colors.amber.shade600 : Colors.grey,
          ),
          const SizedBox(width: 3),
          Text(
            hasRating ? rating.toStringAsFixed(1) : 'No ratings yet',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color:
                  hasRating ? Colors.amber.shade800 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Active filter bar
// ─────────────────────────────────────────────

class _ActiveFilterBar extends StatelessWidget {
  final _FilterState filter;
  final VoidCallback onClear;

  const _ActiveFilterBar({required this.filter, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (filter.sortOption != EquipmentSortOption.newest) {
      chips.add(_chip(
        label: filter.sortOption.label,
        icon: filter.sortOption.icon,
        color: lightColorScheme.primary,
      ));
    }
    if (filter.statusFilter != null) {
      final label = switch (filter.statusFilter!) {
        EquipmentStatus.available => 'Available',
        EquipmentStatus.unavailable => 'Unavailable',
        EquipmentStatus.underMaintenance => 'Maintenance',
      };
      chips.add(_chip(
          label: label, icon: Icons.circle, color: Colors.blueGrey));
    }
    if (filter.onlyForMaintenance) {
      chips.add(_chip(
          label: 'For Maintenance',
          icon: Icons.build_rounded,
          color: Colors.red));
    }
    if (filter.onlyUpcomingMaintenance) {
      chips.add(_chip(
          label: 'Upcoming Maint.',
          icon: Icons.warning_amber_rounded,
          color: Colors.amber.shade800));
    }

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: chips),
          ),
        ),
        GestureDetector(
          onTap: onClear,
          child: Container(
            margin: const EdgeInsets.only(left: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.close, size: 12, color: Colors.red.shade600),
                const SizedBox(width: 4),
                Text('I-clear',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(
      {required String label,
      required IconData icon,
      required Color color}) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Empty state widget
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: 12),
            action!,
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Affected booking data class
// ─────────────────────────────────────────────

class _AffectedBooking {
  final String renterName;
  final DateTime start;
  final DateTime end;
  final bool willBeCancelled;
  final DateTime? newStart;
  final DateTime? newEnd;

  const _AffectedBooking({
    required this.renterName,
    required this.start,
    required this.end,
    required this.willBeCancelled,
    this.newStart,
    this.newEnd,
  });
}

// ─────────────────────────────────────────────
// Maintenance date picker bottom sheet
// ─────────────────────────────────────────────

class _MaintenanceDatePicker extends StatefulWidget {
  final String equipmentName;
  final DateTime today;

  const _MaintenanceDatePicker({
    required this.equipmentName,
    required this.today,
  });

  @override
  State<_MaintenanceDatePicker> createState() =>
      _MaintenanceDatePickerState();
}

class _MaintenanceDatePickerState extends State<_MaintenanceDatePicker> {
  DateTime? _selectedEnd;

  int get _durationDays => _selectedEnd == null
      ? 0
      : _selectedEnd!.difference(widget.today).inDays + 1;

  bool get _isUnforeseen => _durationDays > 7;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: lightColorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.build_outlined,
                    color: lightColorScheme.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'I-schedule ang Maintenance',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    widget.equipmentName,
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _DateRow(
            label: 'Simula',
            value: DateFormat('EEEE, MMM d, yyyy').format(widget.today),
            icon: Icons.today,
            color: Colors.blue,
            isFixed: true,
          ),
          const SizedBox(height: 10),
          _DateRow(
            label: 'Katapusan',
            value: _selectedEnd != null
                ? DateFormat('EEEE, MMM d, yyyy').format(_selectedEnd!)
                : 'Pindutin para pumili',
            icon: Icons.event,
            color: Colors.orange,
            isFixed: false,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: widget.today.add(const Duration(days: 1)),
                firstDate: widget.today.add(const Duration(days: 1)),
                lastDate: widget.today.add(const Duration(days: 365)),
                helpText: 'Select maintenance end date',
              );
              if (picked != null) setState(() => _selectedEnd = picked);
            },
          ),
          if (_selectedEnd != null) ...[
            const SizedBox(height: 14),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _isUnforeseen
                    ? Colors.red.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isUnforeseen
                      ? Colors.red.shade300
                      : Colors.orange.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isUnforeseen
                        ? Icons.warning_amber_rounded
                        : Icons.info_outline,
                    color: _isUnforeseen
                        ? Colors.red
                        : Colors.orange.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isUnforeseen
                          ? '$_durationDays na araw — Hindi Inaasahan. Lahat ng booking ay IKAKANSELA.'
                          : '$_durationDays na araw — Ang mga booking ay ire-reschedule pagkatapos ng maintenance.',
                      style: TextStyle(
                        color: _isUnforeseen
                            ? Colors.red.shade700
                            : Colors.orange.shade800,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Kanselahin'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedEnd == null
                      ? null
                      : () => Navigator.pop(context, _selectedEnd),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isUnforeseen
                        ? Colors.red
                        : Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Kumpirmahin'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isFixed;
  final VoidCallback? onTap;

  const _DateRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isFixed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isFixed ? Colors.grey.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isFixed ? Colors.grey.shade300 : color.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isFixed ? Colors.grey.shade600 : Colors.black87,
                  ),
                ),
              ],
            ),
            if (!isFixed) ...[
              const Spacer(),
              Icon(Icons.chevron_right,
                  color: Colors.grey.shade400, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Weather postpone section
// ─────────────────────────────────────────────

class _WeatherPostponeSection extends StatefulWidget {
  final Equipment equipment;
  const _WeatherPostponeSection({required this.equipment});

  @override
  State<_WeatherPostponeSection> createState() =>
      _WeatherPostponeSectionState();
}

class _WeatherPostponeSectionState extends State<_WeatherPostponeSection> {
  bool _loading = true;
  bool _isBadWeather = false;
  List<RentRequest> _todayBookings = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final forecast = await WeatherService()
          .getOrFetchForecast(requestLocationPermission: false);
      final today = DateTime.now();
      final todayDay = DateTime(today.year, today.month, today.day);

      WeatherDay? todayWeather;
      for (final d in forecast) {
        if (DateTime(d.date.year, d.date.month, d.date.day) == todayDay) {
          todayWeather = d;
          break;
        }
      }

      final isBad = todayWeather?.isBadWeather ?? false;
      if (!isBad) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final snap = await FirebaseFirestore.instance
          .collection('rentRequests')
          .where('itemId', isEqualTo: widget.equipment.id)
          .where('status', whereIn: ['approved', 'readyForPickup'])
          .get();

      final bookings = snap.docs
          .map((d) => RentRequest.fromDoc(d))
          .where((r) {
            final startDay =
                DateTime(r.start.year, r.start.month, r.start.day);
            return startDay == todayDay;
          })
          .toList();

      if (mounted) {
        setState(() {
          _isBadWeather = isBad;
          _todayBookings = bookings;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _postpone() async {
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    final snap = await FirebaseFirestore.instance
        .collection('rentRequests')
        .where('itemId', isEqualTo: widget.equipment.id)
        .where('status', whereIn: ['pending', 'approved', 'readyForPickup'])
        .get();

    final upcoming = snap.docs
        .map((d) => RentRequest.fromDoc(d))
        .where((r) {
          final startDay =
              DateTime(r.start.year, r.start.month, r.start.day);
          return !startDay.isBefore(todayDay);
        })
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    if (!mounted) return;

    final fmt = DateFormat('MMM d');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ipagpaliban Dahil sa Masamang Panahon?'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Ang lahat ng nakatalagang booking mula ngayon ay ililipat ng isang araw.'),
                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Mga Apektadong Booking:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  ...upcoming.map((r) {
                    final newStart = r.start.add(const Duration(days: 1));
                    final newEnd = r.end.add(const Duration(days: 1));
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.person_outline,
                              size: 14, color: Colors.black54),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                Text(
                                  'Dati: ${fmt.format(r.start)} – ${fmt.format(r.end)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black54),
                                ),
                                Text(
                                  'Bago: ${fmt.format(newStart)} – ${DateFormat('MMM d, yyyy').format(newEnd)}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Huwag')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Oo, Ipagpaliban'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final db = FirebaseFirestore.instance;
    final futures = <Future>[];
    final fmt2 = DateFormat('MMM d');

    for (final r in upcoming) {
      final newStart = r.start.add(const Duration(days: 1));
      final newEnd = r.end.add(const Duration(days: 1));

      futures.add(db.collection('rentRequests').doc(r.requestId).update({
        'start': Timestamp.fromDate(newStart),
        'end': Timestamp.fromDate(newEnd),
        'weatherPostponed': true,
        'originalStart': Timestamp.fromDate(r.start),
        'originalEnd': Timestamp.fromDate(r.end),
      }));

      futures.add(db
          .collection('notifications')
          .doc(r.renterId)
          .collection('items')
          .add({
        'type': 'maintenance_reschedule',
        'title': '📅 Na-reschedule ang Booking — Masamang Panahon',
        'body': 'Ang iyong booking para sa "${widget.equipment.name}" '
            '(${fmt2.format(r.start)} – ${fmt2.format(r.end)}) '
            'ay inilipat ng isang araw dahil sa masamang kondisyon ng panahon. '
            'Bagong petsa: ${fmt2.format(newStart)} – ${DateFormat('MMM d, yyyy').format(newEnd)}.',
        'requestId': r.requestId,
        'equipmentId': widget.equipment.id,
        'ownerId': widget.equipment.ownerId,
        'canCancel': true,
        'canAccept': true,
        'newStart': Timestamp.fromDate(newStart),
        'newEnd': Timestamp.fromDate(newEnd),
        'originalStart': Timestamp.fromDate(r.start),
        'originalEnd': Timestamp.fromDate(r.end),
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      }));
    }

    await Future.wait(futures);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Na-postpone ang mga booking ng isang araw dahil sa masamang panahon.'),
        backgroundColor: Colors.blue,
      ));
      setState(() {
        _todayBookings = [];
        _isBadWeather = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_isBadWeather || _todayBookings.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.thunderstorm_outlined,
              color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${_todayBookings.length} booking today affected by bad weather.',
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: _postpone,
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Postpone'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Overdue returns section
// ─────────────────────────────────────────────

class _OverdueReturnsSection extends StatelessWidget {
  final String ownerId;
  const _OverdueReturnsSection({required this.ownerId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('rentRequests')
          .where('ownerId', isEqualTo: ownerId)
          .where('status', isEqualTo: 'inProgress')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final now = DateTime.now();
        final overdue = snapshot.data!.docs
            .map((doc) => RentRequest.fromDoc(doc))
            .where((r) => now.isAfter(r.end))
            .toList();

        if (overdue.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.07),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Red header strip
              Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade600,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(13)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Unreturned Equipment  •  ${overdue.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              // Row list
              ...overdue.asMap().entries.map((entry) {
                final i = entry.key;
                final r = entry.value;
                final days = now.difference(r.end).inDays;
                return Column(
                  children: [
                    if (i > 0)
                      const Divider(height: 1, indent: 14, endIndent: 14),
                    InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              RequestSentPage(requestId: r.requestId),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.agriculture_rounded,
                                  color: Colors.red.shade400, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.itemName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${r.name}  •  Due ${DateFormat('MMM dd').format(r.end)}',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                days == 0
                                    ? 'Due today'
                                    : '$days ${days == 1 ? 'day' : 'days'} late',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }
}