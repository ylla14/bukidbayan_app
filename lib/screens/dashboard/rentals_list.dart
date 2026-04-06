/// RentalsList — filters moved into a modal bottom sheet.
/// The AppBar shows a "Filter" button with an active-count badge.
/// A "Clear filters" chip appears inline only when filters are active.

import 'package:bukidbayan_app/blocs/request_bloc.dart';
import 'package:bukidbayan_app/blocs/request_event.dart';
import 'package:bukidbayan_app/blocs/request_state.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/screens/rent/request_sent.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/services/rent_request_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum RentalsListMode {
  myRequests,
  incomingRequests,
}

enum _SortOrder { newest, oldest }
enum _OperatorFilter { all, withOperator, withoutOperator }
enum _DeliveryFilter { all, pickup, delivery }

class RentalsList extends StatefulWidget {
  final RentalsListMode mode;
  const RentalsList({super.key, required this.mode});

  @override
  State<RentalsList> createState() => _RentalsListState();
}

class _RentalsListState extends State<RentalsList> {
  final RentRequestService _requestService = RentRequestService();
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Filter state ──────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<RentRequestStatus> _selectedStatuses = {};
  DateTimeRange? _dateRange;
  _SortOrder _sortOrder = _SortOrder.newest;
  _OperatorFilter _operatorFilter = _OperatorFilter.all;
  _DeliveryFilter _deliveryFilter = _DeliveryFilter.all;
  // null = no filter, true = with operator, false = without operator
  bool? _withOperator;
  // null = no filter, otherwise the selected delivery method
  DeliveryMethod? _deliveryMethod;
  bool? _hasOperator; // null = any, true = with operator, false = without
  Set<DeliveryMethod> _selectedDeliveryMethods = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String get _title => widget.mode == RentalsListMode.myRequests
      ? 'Aking Rental Requests'
      : 'Requests sa aking Kagamitan';

  Color _statusColor(RentRequestStatus status) {
    switch (status) {
      case RentRequestStatus.pending:        return const Color(0xFFF59E0B);
      case RentRequestStatus.approved:       return const Color(0xFF3B82F6);
      case RentRequestStatus.onTheWay:   
      case RentRequestStatus.readyForPickup: return const Color(0xFFF59E0B);
      case RentRequestStatus.pickedUp:
      case RentRequestStatus.inProgress:
      case RentRequestStatus.retrieving:     
      case RentRequestStatus.returned:     
      case RentRequestStatus.finished:
      case RentRequestStatus.completed:      return lightColorScheme.primary; // Forest Green (Active Brand Color)
      case RentRequestStatus.declined:
      case RentRequestStatus.canceled:       return lightColorScheme.error;
    }
  }

  String _statusLabel(RentRequestStatus status) {
    switch (status) {
      case RentRequestStatus.onTheWay:       return 'On The Way';
      case RentRequestStatus.inProgress:     return 'In Progress';
      case RentRequestStatus.readyForPickup: return 'Ready for Pick Up';
      case RentRequestStatus.pickedUp:       return 'Picked Up';
      default:
        return status.name[0].toUpperCase() + status.name.substring(1);
    }
  }

  String _dateSectionLabel(DateTime date) {
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target    = DateTime(date.year, date.month, date.day);
    if (target == today)     return 'Today';
    if (target == yesterday) return 'Yesterday';
    return DateFormat('MMMM dd, yyyy').format(date);
  }

  DateTime _dayKey(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  int get _activeFilterCount {
    int count = 0;
    if (_searchQuery.isNotEmpty)         count++;
    count += _selectedStatuses.length;
    if (_dateRange != null)              count++;
    if (_sortOrder == _SortOrder.oldest) count++;
    if (_operatorFilter != _OperatorFilter.all) count++;
    if (_deliveryFilter != _DeliveryFilter.all) count++;
    if (_hasOperator != null)            count++;
    count += _selectedDeliveryMethods.length;
    return count;
  }

  bool get _hasActiveFilters => _activeFilterCount > 0;

  void _clearAllFilters() => setState(() {
        _searchController.clear();
        _searchQuery = '';
        _selectedStatuses.clear();
        _dateRange = null;
        _sortOrder = _SortOrder.newest;
        _operatorFilter = _OperatorFilter.all;
        _deliveryFilter = _DeliveryFilter.all;
        _hasOperator = null;
        _selectedDeliveryMethods.clear();
      });

  // ── Equipment operator cache ──────────────────────────────────────────────
  // itemId → operatorIncluded. Populated on demand when operator filter is set.
  final Map<String, bool> _equipmentOperatorCache = {};

  Future<void> _warmOperatorCache(List<RentRequest> requests) async {
    final missing = requests
        .map((r) => r.itemId)
        .toSet()
        .where((id) => !_equipmentOperatorCache.containsKey(id))
        .toList();
    if (missing.isEmpty) return;
    for (int i = 0; i < missing.length; i += 30) {
      final chunk = missing.sublist(i, (i + 30).clamp(0, missing.length));
      final snap = await FirebaseFirestore.instance
          .collection('equipment')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        _equipmentOperatorCache[doc.id] =
            (doc.data()['operatorIncluded'] as bool?) ?? false;
      }
      for (final id in chunk) {
        _equipmentOperatorCache.putIfAbsent(id, () => false);
      }
    }
    if (mounted) setState(() {});
  }

  // ── Filtering ─────────────────────────────────────────────────────────────

  List<RentRequest> _applyFilters(List<RentRequest> raw) {
    Iterable<RentRequest> result = raw;

    // Kick off cache warm whenever operator filter is active and ids are missing.
    if (_operatorFilter != _OperatorFilter.all) {
      final uncached = raw
          .map((r) => r.itemId)
          .where((id) => !_equipmentOperatorCache.containsKey(id))
          .isNotEmpty;
      if (uncached) _warmOperatorCache(raw);
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((r) => r.itemName.toLowerCase().contains(q));
    }
    if (_selectedStatuses.isNotEmpty) {
      result = result.where((r) => _selectedStatuses.contains(r.status));
    }
    if (_dateRange != null) {
      result = result.where((r) =>
          !r.start.isAfter(_dateRange!.end) &&
          !r.end.isBefore(_dateRange!.start));
    }
    if (_operatorFilter != _OperatorFilter.all) {
      result = result.where((r) {
        final hasOperator = _equipmentOperatorCache[r.itemId] ?? false;
        return _operatorFilter == _OperatorFilter.withOperator
            ? hasOperator
            : !hasOperator;
      });
    }
    if (_deliveryFilter != _DeliveryFilter.all) {
      result = result.where((r) => _deliveryFilter == _DeliveryFilter.pickup
          ? r.deliveryMethod == DeliveryMethod.pickup
          : r.deliveryMethod == DeliveryMethod.delivery);
    }

    return result.toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return _sortOrder == _SortOrder.newest
            ? bDate.compareTo(aDate)
            : aDate.compareTo(bDate);
      });
  }

  Future<void> _pickDateRange(StateSetter setSheetState) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _dateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: lightColorScheme.primary,
            onPrimary: lightColorScheme.onPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      setSheetState(() {});
    }
  }

  // ── Filter bottom sheet ───────────────────────────────────────────────────

  void _openFilterSheet() {
    // Local copies so changes only commit on "Apply"
    String localSearch                      = _searchQuery;
    final localController                   = TextEditingController(text: localSearch);
    final Set<RentRequestStatus> localStatuses = Set.from(_selectedStatuses);
    DateTimeRange? localDateRange           = _dateRange;
    _SortOrder localSort                    = _sortOrder;
    _OperatorFilter localOperator           = _operatorFilter;
    _DeliveryFilter localDelivery           = _deliveryFilter;

    final primary = lightColorScheme.primary;
    final fmt     = DateFormat('MMM d');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickDate() async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDateRange: localDateRange,
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: primary,
                      onPrimary: lightColorScheme.onPrimary,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) setSheetState(() => localDateRange = picked);
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.92,
              builder: (_, scrollController) => Column(
                children: [
                  // ── Handle ────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),

                  // ── Header ────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 12, 4),
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 20, color: primary),
                        const SizedBox(width: 8),
                        Text(
                          'Filter & Sort',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              localController.clear();
                              localSearch = '';
                              localStatuses.clear();
                              localDateRange = null;
                              localSort = _SortOrder.newest;
                              localOperator = _OperatorFilter.all;
                              localDelivery = _DeliveryFilter.all;
                            });
                          },
                          child: Text(
                            'Reset',
                            style: TextStyle(
                              color: Colors.red.shade400,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  // ── Scrollable body ───────────────────────────────────────
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      children: [

                        // Search
                        _SheetSection(
                          label: 'Search by item name',
                          child: TextField(
                            controller: localController,
                            decoration: InputDecoration(
                              hintText: 'e.g. Tractor, Sprayer…',
                              hintStyle: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 14),
                              prefixIcon: Icon(Icons.search_rounded,
                                  size: 20, color: primary),
                              suffixIcon: localSearch.isNotEmpty
                                  ? GestureDetector(
                                      onTap: () => setSheetState(() {
                                        localController.clear();
                                        localSearch = '';
                                      }),
                                      child: Icon(Icons.cancel_rounded,
                                          size: 18,
                                          color: Colors.grey.shade400),
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 0, horizontal: 16),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide:
                                    BorderSide(color: primary, width: 1.5),
                              ),
                            ),
                            onChanged: (v) =>
                                setSheetState(() => localSearch = v.trim()),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Sort
                        _SheetSection(
                          label: 'Sort by date',
                          child: Row(
                            children: [
                              _SortButton(
                                label: 'Newest first',
                                icon: Icons.arrow_downward_rounded,
                                selected: localSort == _SortOrder.newest,
                                color: primary,
                                onTap: () => setSheetState(
                                    () => localSort = _SortOrder.newest),
                              ),
                              const SizedBox(width: 10),
                              _SortButton(
                                label: 'Oldest first',
                                icon: Icons.arrow_upward_rounded,
                                selected: localSort == _SortOrder.oldest,
                                color: primary,
                                onTap: () => setSheetState(
                                    () => localSort = _SortOrder.oldest),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Date range
                        _SheetSection(
                          label: 'Rental date range',
                          child: GestureDetector(
                            onTap: pickDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: localDateRange != null
                                    ? primary.withOpacity(0.07)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: localDateRange != null
                                      ? primary
                                      : Colors.grey.shade300,
                                  width: localDateRange != null ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.date_range_rounded,
                                      size: 18,
                                      color: localDateRange != null
                                          ? primary
                                          : Colors.grey.shade500),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      localDateRange == null
                                          ? 'Select date range'
                                          : '${fmt.format(localDateRange!.start)}  →  ${fmt.format(localDateRange!.end)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: localDateRange != null
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: localDateRange != null
                                            ? primary
                                            : Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  if (localDateRange != null)
                                    GestureDetector(
                                      onTap: () => setSheetState(
                                          () => localDateRange = null),
                                      child: Icon(Icons.cancel_rounded,
                                          size: 16, color: primary),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Operator filter
                        _SheetSection(
                          label: 'Operator',
                          child: Row(
                            children: [
                              _ToggleChip(
                                label: 'All',
                                selected: localOperator == _OperatorFilter.all,
                                color: lightColorScheme.primary,
                                onTap: () => setSheetState(
                                    () => localOperator = _OperatorFilter.all),
                              ),
                              const SizedBox(width: 8),
                              _ToggleChip(
                                label: 'w/ Operator',
                                icon: Icons.person_rounded,
                                selected: localOperator == _OperatorFilter.withOperator,
                                color: lightColorScheme.primary,
                                onTap: () => setSheetState(() =>
                                    localOperator = _OperatorFilter.withOperator),
                              ),
                              const SizedBox(width: 8),
                              _ToggleChip(
                                label: 'w/o Operator',
                                icon: Icons.person_off_rounded,
                                selected: localOperator == _OperatorFilter.withoutOperator,
                                color: lightColorScheme.primary,
                                onTap: () => setSheetState(() =>
                                    localOperator = _OperatorFilter.withoutOperator),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Delivery method filter
                        _SheetSection(
                          label: 'Delivery method',
                          child: Row(
                            children: [
                              _ToggleChip(
                                label: 'All',
                                selected: localDelivery == _DeliveryFilter.all,
                                color: lightColorScheme.primary,
                                onTap: () => setSheetState(
                                    () => localDelivery = _DeliveryFilter.all),
                              ),
                              const SizedBox(width: 8),
                              _ToggleChip(
                                label: 'Pick-up',
                                icon: Icons.storefront_rounded,
                                selected: localDelivery == _DeliveryFilter.pickup,
                                color: lightColorScheme.primary,
                                onTap: () => setSheetState(
                                    () => localDelivery = _DeliveryFilter.pickup),
                              ),
                              const SizedBox(width: 8),
                              _ToggleChip(
                                label: 'Delivery',
                                icon: Icons.local_shipping_rounded,
                                selected: localDelivery == _DeliveryFilter.delivery,
                                color: lightColorScheme.primary,
                                onTap: () => setSheetState(() =>
                                    localDelivery = _DeliveryFilter.delivery),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Status filter
                        _SheetSection(
                          label: 'Filter by status',
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: RentRequestStatus.values.map((s) {
                              final selected = localStatuses.contains(s);
                              final color    = _statusColor(s);
                              return GestureDetector(
                                onTap: () => setSheetState(() => selected
                                    ? localStatuses.remove(s)
                                    : localStatuses.add(s)),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? color.withOpacity(0.12)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: selected
                                          ? color
                                          : Colors.grey.shade300,
                                      width: selected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (selected) ...[
                                        Icon(Icons.check_circle_rounded,
                                            size: 13, color: color),
                                        const SizedBox(width: 5),
                                      ],
                                      Text(
                                        _statusLabel(s),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: selected
                                              ? color
                                              : Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Apply button ──────────────────────────────────────────
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _searchQuery     = localSearch;
                              _searchController.text = localSearch;
                              _selectedStatuses
                                ..clear()
                                ..addAll(localStatuses);
                              _dateRange = localDateRange;
                              _sortOrder = localSort;
                              _operatorFilter = localOperator;
                              _deliveryFilter = localDelivery;
                            });
                            Navigator.pop(context);
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: lightColorScheme.onPrimary,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Apply filters',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
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

  // ── Grouped list builder ──────────────────────────────────────────────────

  List<Widget> _buildGroupedList(List<RentRequest> requests) {
    final List<Widget> widgets = [];
    DateTime? lastKey;

    for (final request in requests) {
      final submittedAt = request.createdAt;
      final key = submittedAt != null ? _dayKey(submittedAt) : null;

      if (key != lastKey) {
        lastKey = key;
        final label =
            key != null ? _dateSectionLabel(submittedAt!) : 'Unknown Date';
        widgets.add(_DateSectionHeader(label: label));
      }

      widgets.add(_RequestCard(
        request: request,
        mode: widget.mode,
        firestoreService: _firestoreService,
        requestService: _requestService,
        statusColor: _statusColor(request.status),
        statusLabel: _statusLabel(request.status),
        onDeleted: () => setState(() {}),
      ));
    }
    return widgets;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final primary = lightColorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _title,
          style: TextStyle(
            color: lightColorScheme.onPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                lightColorScheme.primary,
                lightColorScheme.secondary,
              ],
            ),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          // Filter button with badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                color: lightColorScheme.onPrimary,
                tooltip: 'Filter & Sort',
                onPressed: _openFilterSheet,
              ),
              if (_activeFilterCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_activeFilterCount',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<RentRequest>>(
        stream: widget.mode == RentalsListMode.myRequests
            ? _requestService.getRequestsByRenter(_auth.currentUser!.uid)
            : _requestService.getRequestsByOwner(_auth.currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final raw      = snapshot.data ?? [];
          final requests = _applyFilters(raw);

          if (raw.isEmpty) {
            return const Center(
              child: Text('No rentals to display.',
                  style: TextStyle(fontSize: 16)),
            );
          }

          return Column(
            children: [
              // ── Active filter strip ─────────────────────────────────────
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _hasActiveFilters
                    ? Container(
                        color: primary.withOpacity(0.05),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.filter_alt_rounded,
                                size: 15, color: primary),
                            const SizedBox(width: 6),
                            Text(
                              '$_activeFilterCount filter${_activeFilterCount == 1 ? '' : 's'} active',
                              style: TextStyle(
                                fontSize: 13,
                                color: primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _clearAllFilters,
                              child: Row(
                                children: [
                                  Icon(Icons.close_rounded,
                                      size: 14,
                                      color: Colors.red.shade400),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Clear filters',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade400,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // ── Results ─────────────────────────────────────────────────
              Expanded(
                child: requests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded,
                                size: 52, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              'No rentals match your filters.',
                              style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade500),
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: _clearAllFilters,
                              icon: const Icon(
                                  Icons.filter_alt_off_rounded,
                                  size: 16),
                              label: const Text('Clear filters'),
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.red.shade400),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _buildGroupedList(requests).length,
                        itemBuilder: (context, index) =>
                            _buildGroupedList(requests)[index],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Sheet Section ─────────────────────────────────────────────────────────────

class _SheetSection extends StatelessWidget {
  final String label;
  final Widget child;
  const _SheetSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// ── Sort Button ───────────────────────────────────────────────────────────────

class _SortButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SortButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.1) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 15,
                  color: selected ? color : Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? color : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Toggle Chip ───────────────────────────────────────────────────────────────

class _ToggleChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: selected ? color : Colors.grey.shade500),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected ? color : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date Section Header ───────────────────────────────────────────────────────

class _DateSectionHeader extends StatelessWidget {
  final String label;
  const _DateSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Row(
        children: [
          Expanded(
              child: Divider(color: Colors.grey.shade300, thickness: 1.2)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.shade900.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month,
                      size: 13, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
              child: Divider(color: Colors.grey.shade300, thickness: 1.2)),
        ],
      ),
    );
  }
}

// ── Request Card ──────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final RentRequest request;
  final RentalsListMode mode;
  final FirestoreService firestoreService;
  final RentRequestService requestService;
  final Color statusColor;
  final String statusLabel;
  final VoidCallback onDeleted;

  const _RequestCard({
    required this.request,
    required this.mode,
    required this.firestoreService,
    required this.requestService,
    required this.statusColor,
    required this.statusLabel,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 4, color: statusColor),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          request.itemName,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              statusLabel.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (request.createdAt != null)
                    _InfoRow(
                      icon: Icons.schedule_rounded,
                      text:
                          "Submitted: ${DateFormat('MMM dd, yyyy • hh:mm a').format(request.createdAt!)}",
                      color: Colors.grey.shade500,
                      fontSize: 12,
                      italic: true,
                    ),
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.calendar_today_rounded,
                    text:
                        "${DateFormat('MMM dd, yyyy').format(request.start)} → ${DateFormat('MMM dd, yyyy').format(request.end)}",
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  if (request.originalStart != null &&
                      request.originalEnd != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 21, top: 2),
                      child: Text(
                        "Orihinal: ${DateFormat('MMM dd, yyyy').format(request.originalStart!)} – ${DateFormat('MMM dd, yyyy').format(request.originalEnd!)}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  FutureBuilder<String?>(
                    future: mode == RentalsListMode.incomingRequests
                        ? firestoreService.getUserNameById(request.renterId)
                        : firestoreService.getUserNameById(request.ownerId),
                    builder: (context, snapshot) => _InfoRow(
                      icon: Icons.person_rounded,
                      text: snapshot.data ?? 'Loading…',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _InfoRow(
                    icon: Icons.location_on_rounded,
                    text: request.address,
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BlocProvider(
                                create: (_) => RequestBloc()
                                  ..add(LoadRequest(request.requestId)),
                                child: RequestSentPage(
                                    requestId: request.requestId),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.visibility_rounded, size: 16),
                          label: const Text('View'),
                          style: FilledButton.styleFrom(
                            backgroundColor: lightColorScheme.primary,
                            foregroundColor: lightColorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Delete Request'),
                                content: const Text(
                                  'Are you sure you want to delete this rental request?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Delete',
                                        style:
                                            TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await FirestoreService()
                                  .validateEquipmentAvailabilityWithNotification(
                                      request.itemId);
                              await requestService.deleteRequest(request);
                              onDeleted();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Request deleted')));
                              }
                            }
                          },
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 16),
                          label: const Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Info Row helper ───────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  final double fontSize;
  final FontWeight fontWeight;
  final bool italic;

  const _InfoRow({
    required this.icon,
    required this.text,
    this.color,
    this.fontSize = 14,
    this.fontWeight = FontWeight.normal,
    this.italic = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey.shade600;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: c),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color ?? Colors.black87,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }
}