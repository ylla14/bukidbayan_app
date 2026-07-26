import 'package:bukidbayan_app/models/equipment_price_limit.dart';
import 'package:bukidbayan_app/screens/rent/equipment_listing_form_screen.dart'
    show getCategoryPriceLimits;
import 'package:bukidbayan_app/services/equipment_price_limit_service.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:bukidbayan_app/services/strike_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminEquipmentScreen extends StatefulWidget {
  const AdminEquipmentScreen({super.key});

  @override
  State<AdminEquipmentScreen> createState() => _AdminEquipmentScreenState();
}

class _AdminEquipmentScreenState extends State<AdminEquipmentScreen> {
  final _db = FirebaseFirestore.instance;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _equipment = [];
  Map<String, String> _activeRenters = {};
  Map<String, int> _categoryCounts = {};
  Map<String, EquipmentPriceLimit> _priceLimits = {};
  List<String> _allCategories = [];
  String? _sortColumn;
  bool _sortAscending = false;
  String? _filterCategory;
  String? _filterStatus;

  // Sentinel used in PopupMenuButton items to represent "clear filter".
  // Flutter's PopupMenuButton never calls onSelected for null values.
  static const _kAll = '__all__';

  List<String> get _availableCategories {
    final cats = <String>{};
    for (final eq in _equipment) {
      final cat = (eq['category'] as String? ?? '').trim();
      if (cat.isNotEmpty) cats.add(cat);
    }
    return cats.toList()..sort();
  }

  List<Map<String, dynamic>> get _filteredSortedEquipment {
    var list = List<Map<String, dynamic>>.from(_equipment);
    if (_filterCategory != null) {
      list = list
          .where((eq) =>
              (eq['category'] as String? ?? '').trim() == _filterCategory)
          .toList();
    }
    if (_filterStatus != null) {
      list = list.where((eq) => eq['status'] == _filterStatus).toList();
    }
    if (_sortColumn != null) {
      list.sort((a, b) {
        int cmp;
        switch (_sortColumn) {
          case 'maintenance':
            cmp = ((a['maintenanceCount'] as int?) ?? 0)
                .compareTo((b['maintenanceCount'] as int?) ?? 0);
          case 'breakdowns':
            final aName = a['name'] as String? ?? '';
            final bName = b['name'] as String? ?? '';
            final aCount = StrikeService.isMotorizedEquipment(aName)
                ? (a['majorBreakdownCount'] as int?) ?? 0
                : (a['damageReportCount'] as int?) ?? 0;
            final bCount = StrikeService.isMotorizedEquipment(bName)
                ? (b['majorBreakdownCount'] as int?) ?? 0
                : (b['damageReportCount'] as int?) ?? 0;
            cmp = aCount.compareTo(bCount);
          default:
            return 0;
        }
        return _sortAscending ? cmp : -cmp;
      });
    }

    // Retired equipment always sinks to the bottom regardless of the
    // active sort/filter — split-and-concatenate rather than folding this
    // into the comparator above, since List.sort isn't guaranteed stable.
    final active =
        list.where((eq) => eq['status'] != 'retired').toList();
    final retired =
        list.where((eq) => eq['status'] == 'retired').toList();
    return [...active, ...retired];
  }

  Future<void> _sendRetirementFlagNotification({
    required String ownerId,
    required String name,
  }) async {
    await _db.collection('notifications').doc(ownerId).collection('items').add({
      'type': 'equipment_retirement_flagged',
      'title': 'Equipment Flagged for Retirement',
      'body':
          'Your co-op has flagged "$name" for retirement based on its maintenance and breakdown history. Please review it and consider retiring it from active service.',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _toggleRetirementFlag(
      String id, bool current, String name, String? ownerId) async {
    final newValue = !current;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(newValue ? 'Flag for Retirement' : 'Remove Retirement Flag'),
        content: Text(
          newValue
              ? 'Flag "$name" for retirement? The owner will see a retirement suggestion in their equipment dashboard.'
              : 'Remove the retirement flag from "$name"? The owner will no longer see the admin-triggered retirement suggestion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  newValue ? Colors.deepOrange : Colors.grey.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(newValue ? 'Flag' : 'Unflag'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      final idx = _equipment.indexWhere((e) => e['_id'] == id);
      if (idx != -1) _equipment[idx]['retirementFlaggedByAdmin'] = newValue;
    });
    try {
      await _db
          .collection('equipment')
          .doc(id)
          .update({'retirementFlaggedByAdmin': newValue});
      if (newValue && ownerId != null && ownerId.isNotEmpty) {
        try {
          await _sendRetirementFlagNotification(ownerId: ownerId, name: name);
        } catch (_) {
          // Non-fatal — the flag itself already succeeded.
        }
      }
    } catch (e) {
      setState(() {
        final idx = _equipment.indexWhere((e) => e['_id'] == id);
        if (idx != -1) _equipment[idx]['retirementFlaggedByAdmin'] = current;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Widget _photoPlaceholder() => Container(
        width: 36,
        height: 36,
        color: Colors.grey.shade100,
        child: Icon(Icons.image_not_supported_outlined,
            size: 14, color: Colors.grey.shade400),
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final eqSnap = await _db.collection('equipment').orderBy('name').get();
      final equipment = eqSnap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['_id'] = d.id;
        return data;
      }).toList();

      final reqSnap = await _db
          .collection('rentRequests')
          .where('status', whereIn: ['approved', 'ongoing'])
          .get();

      final renterUids = <String>{};
      for (final doc in reqSnap.docs) {
        final uid = doc.data()['renterId'] as String?;
        if (uid != null) renterUids.add(uid);
      }

      final renterNames = <String, String>{};
      await Future.wait(
        renterUids.map((uid) async {
          final snap = await _db.collection('users').doc(uid).get();
          final d = snap.data();
          renterNames[uid] =
              d?['displayName'] as String? ??
              d?['name'] as String? ??
              d?['email'] as String? ??
              uid.substring(0, 8);
        }),
      );

      final activeRenters = <String, String>{};
      for (final req in reqSnap.docs) {
        final d = req.data();
        final eqId = d['equipmentId'] as String?;
        final renterId = d['renterId'] as String?;
        if (eqId != null && renterId != null) {
          activeRenters[eqId] =
              renterNames[renterId] ?? renterId.substring(0, 8);
        }
      }

      final catCounts = <String, int>{};
      for (final eq in equipment) {
        // Retired equipment stays visible in the inventory table but is
        // excluded from the Equipment Demographics statistics.
        if (eq['status'] == 'retired') continue;
        final cat = (eq['category'] as String? ?? '').trim();
        final key = cat.isEmpty ? 'Uncategorized' : cat;
        catCounts[key] = (catCounts[key] ?? 0) + 1;
      }

      final allCategories = await FirestoreService().getUniqueEquipmentCategories();
      final priceLimits = await EquipmentPriceLimitService().getAll();

      setState(() {
        _equipment = equipment;
        _activeRenters = activeRenters;
        _categoryCounts = catCounts;
        _allCategories = allCategories;
        _priceLimits = priceLimits;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'available':        return Colors.green;
      case 'under_maintenance': return Colors.orange;
      case 'retired':           return Colors.black54;
      default:                 return Colors.red;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'available':         return 'Available';
      case 'unavailable':       return 'Unavailable';
      case 'under_maintenance': return 'Under Maintenance';
      case 'retired':           return 'Retired';
      default:                  return status ?? '—';
    }
  }

  Widget _sectionHeader(String title, int count, {int? total}) {
    final label =
        (total != null && total != count) ? '$count / $total' : '$count';
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: lightColorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: lightColorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: lightColorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  // ── Drilldown helpers ────────────────────────────────────────────────────

  Color _conditionColor(String? condition) {
    switch (condition) {
      case 'Brand New': return Colors.green.shade700;
      case 'Excellent': return Colors.green.shade600;
      case 'Good':      return Colors.blue.shade600;
      case 'Fair':      return Colors.orange.shade700;
      default:          return Colors.grey.shade600;
    }
  }

  Widget _typeBadge(bool isMotorized) {
    final color = isMotorized ? Colors.blue : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMotorized ? Icons.settings : Icons.handyman_outlined,
            size: 12,
            color: isMotorized ? Colors.blue.shade700 : Colors.grey.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            isMotorized ? 'Motorized' : 'Manual',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isMotorized ? Colors.blue.shade700 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sheetPhotoPlaceholder() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.agriculture_outlined, color: Colors.grey.shade400),
      );

  Widget _detailRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 10),
          SizedBox(
            width: 84,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  void _showEquipmentDetails(Map<String, dynamic> eq) {
    final name = eq['name'] as String? ?? '—';
    final category = (eq['category'] as String? ?? '').trim();
    final condition = eq['condition'] as String? ?? '—';
    final status = eq['status'] as String?;
    final ownerName = eq['ownerName'] as String? ?? '—';
    final isMotorized = StrikeService.isMotorizedEquipment(name);
    final maintenanceCount = (eq['maintenanceCount'] as int?) ?? 0;
    final breakdownCount = isMotorized
        ? (eq['majorBreakdownCount'] as int?) ?? 0
        : (eq['damageReportCount'] as int?) ?? 0;
    final breakdownThreshold = isMotorized
        ? StrikeService.kMajorBreakdownThreshold
        : StrikeService.kDamageRetirementThreshold;
    final flagged = (eq['retirementFlaggedByAdmin'] as bool?) ?? false;
    final imageUrls =
        (eq['imageUrls'] as List<dynamic>? ?? []).cast<String>();
    final firstUrl = imageUrls.isNotEmpty ? imageUrls.first : null;
    final breakdownColor = breakdownCount >= breakdownThreshold
        ? Colors.red
        : breakdownCount >= breakdownThreshold - 1
            ? Colors.orange
            : Colors.blueGrey;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: firstUrl != null
                        ? Image.network(
                            firstUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _sheetPhotoPlaceholder(),
                          )
                        : _sheetPhotoPlaceholder(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _typeBadge(isMotorized),
                            if (flagged)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.deepOrange.shade200),
                                ),
                                child: Text(
                                  '🚩 Flagged for Retirement',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.deepOrange.shade700,
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
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              _detailRow(Icons.category_outlined, 'Category',
                  category.isEmpty ? 'Uncategorized' : category),
              _detailRow(Icons.star_outline, 'Condition', condition,
                  valueColor: _conditionColor(condition)),
              _detailRow(Icons.info_outline, 'Status', _statusLabel(status),
                  valueColor: _statusColor(status)),
              _detailRow(Icons.person_outline, 'Owner', ownerName),
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _statCard(
                      'Maintenance\nEvents',
                      '$maintenanceCount',
                      Icons.build_outlined,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _statCard(
                      isMotorized
                          ? 'Major\nBreakdowns'
                          : 'Damage\nReports',
                      '$breakdownCount / $breakdownThreshold',
                      Icons.warning_amber_outlined,
                      breakdownColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEquipmentTable() {
    const headerStyle = TextStyle(fontSize: 9, fontWeight: FontWeight.w700);
    const cellStyle = TextStyle(fontSize: 9);
    const cellPadding = EdgeInsets.symmetric(horizontal: 5, vertical: 8);

    Widget headerCell(String text) => Padding(
          padding: cellPadding,
          child: Text(text, style: headerStyle, overflow: TextOverflow.ellipsis),
        );

    // Compact chip used in the filter/sort button row
    Widget filterChip({
      required String label,
      required bool isActive,
      IconData? trailingIcon,
    }) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isActive
                ? lightColorScheme.primary.withValues(alpha: 0.12)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? lightColorScheme.primary
                  : Colors.grey.shade300,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive
                      ? lightColorScheme.primary
                      : Colors.grey.shade700,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                trailingIcon ?? Icons.arrow_drop_down,
                size: 14,
                color: isActive
                    ? lightColorScheme.primary
                    : Colors.grey.shade500,
              ),
            ],
          ),
        );

    final displayList = _filteredSortedEquipment;
    final activeFilters = _filterCategory != null || _filterStatus != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Equipment Inventory',
          displayList.length,
          total: activeFilters ? _equipment.length : null,
        ),
        const SizedBox(height: 10),
        // ── Filter / sort button row ──────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Type filter — uses Firestore category values (Machine, Tool, etc.)
              // PopupMenuButton<String> (non-nullable): _kAll sentinel = clear filter
              PopupMenuButton<String>(
                onSelected: (val) => setState(
                    () => _filterCategory = val == _kAll ? null : val),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: _kAll, child: Text('All Types')),
                  ..._availableCategories.map(
                      (cat) => PopupMenuItem(value: cat, child: Text(cat))),
                ],
                child: filterChip(
                  label: _filterCategory ?? 'Type',
                  isActive: _filterCategory != null,
                ),
              ),
              const SizedBox(width: 8),
              // Status filter — same sentinel pattern
              PopupMenuButton<String>(
                onSelected: (val) => setState(
                    () => _filterStatus = val == _kAll ? null : val),
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: _kAll, child: Text('All Statuses')),
                  PopupMenuItem(value: 'available', child: Text('Available')),
                  PopupMenuItem(
                      value: 'unavailable', child: Text('Unavailable')),
                  PopupMenuItem(
                      value: 'under_maintenance',
                      child: Text('Under Maintenance')),
                  PopupMenuItem(value: 'retired', child: Text('Retired')),
                ],
                child: filterChip(
                  label: _filterStatus != null
                      ? _statusLabel(_filterStatus)
                      : 'Status',
                  isActive: _filterStatus != null,
                ),
              ),
              const SizedBox(width: 8),
              // Maintenance sort — tap cycles: off → ↓ → ↑ → off
              GestureDetector(
                onTap: () => setState(() {
                  if (_sortColumn == 'maintenance') {
                    if (!_sortAscending) {
                      _sortAscending = true;
                    } else {
                      _sortColumn = null;
                    }
                  } else {
                    _sortColumn = 'maintenance';
                    _sortAscending = false;
                  }
                }),
                child: filterChip(
                  label: 'Maintenance',
                  isActive: _sortColumn == 'maintenance',
                  trailingIcon: _sortColumn == 'maintenance'
                      ? (_sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward)
                      : Icons.sort,
                ),
              ),
              const SizedBox(width: 8),
              // Breakdown sort — tap cycles: off → ↓ → ↑ → off
              GestureDetector(
                onTap: () => setState(() {
                  if (_sortColumn == 'breakdowns') {
                    if (!_sortAscending) {
                      _sortAscending = true;
                    } else {
                      _sortColumn = null;
                    }
                  } else {
                    _sortColumn = 'breakdowns';
                    _sortAscending = false;
                  }
                }),
                child: filterChip(
                  label: 'Breakdown',
                  isActive: _sortColumn == 'breakdowns',
                  trailingIcon: _sortColumn == 'breakdowns'
                      ? (_sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward)
                      : Icons.sort,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_equipment.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No equipment found.',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          )
        else if (displayList.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off,
                      size: 36, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'No equipment matches the current filters.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  columnWidths: const {
                    0: FixedColumnWidth(40),  // Photo
                    1: FixedColumnWidth(100), // Name + Category
                    2: FixedColumnWidth(72),  // Owner
                    3: FixedColumnWidth(65),  // Type (Motorized / Manual)
                    4: FixedColumnWidth(80),  // Status
                    5: FixedColumnWidth(62),  // Renter
                    6: FixedColumnWidth(50),  // Maintenance count
                    7: FixedColumnWidth(60),  // Breakdowns
                    8: FixedColumnWidth(42),  // Retirement flag
                  },
                  border: TableBorder(
                    horizontalInside: BorderSide(
                      color: Colors.grey.shade200,
                      width: 0.8,
                    ),
                  ),
                  children: [
                    // ── Header row ──────────────────────────────────
                    TableRow(
                      decoration: BoxDecoration(
                        color: lightColorScheme.primary.withValues(alpha: 0.07),
                      ),
                      children: [
                        const SizedBox.shrink(),
                        headerCell('Name / Category'),
                        headerCell('Owner'),
                        headerCell('Type'),
                        headerCell('Status'),
                        headerCell('Renter'),
                        headerCell('Maint.'),
                        headerCell('Breakdown'),
                        headerCell('Flag'),
                      ],
                    ),
                    // ── Data rows ────────────────────────────────────
                    ...displayList.map((eq) {
                      final id = eq['_id'] as String;
                      final renter = _activeRenters[id];
                      final status = eq['status'] as String?;
                      final statusColor = _statusColor(status);
                      final name = eq['name'] as String? ?? '';
                      final category = (eq['category'] as String? ?? '').trim();
                      final isMotorized = StrikeService.isMotorizedEquipment(name);
                      final maintenanceCount =
                          (eq['maintenanceCount'] as int?) ?? 0;
                      final breakdownCount = isMotorized
                          ? (eq['majorBreakdownCount'] as int?) ?? 0
                          : (eq['damageReportCount'] as int?) ?? 0;
                      final breakdownThreshold = isMotorized
                          ? StrikeService.kMajorBreakdownThreshold
                          : StrikeService.kDamageRetirementThreshold;
                      final flagged =
                          (eq['retirementFlaggedByAdmin'] as bool?) ?? false;

                      final imageUrls =
                          (eq['imageUrls'] as List<dynamic>? ?? [])
                              .cast<String>();
                      final firstUrl =
                          imageUrls.isNotEmpty ? imageUrls.first : null;

                      final breakdownColor =
                          breakdownCount >= breakdownThreshold
                              ? Colors.red.shade700
                              : breakdownCount >= breakdownThreshold - 1
                                  ? Colors.orange.shade700
                                  : Colors.grey.shade600;

                      // All non-flag cells open the drilldown sheet on tap
                      Widget tapCell(Widget child) => GestureDetector(
                            onTap: () => _showEquipmentDetails(eq),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                                padding: cellPadding, child: child),
                          );

                      return TableRow(
                        decoration: flagged
                            ? BoxDecoration(
                                color: Colors.deepOrange.withValues(alpha: 0.04))
                            : null,
                        children: [
                          // Photo (tappable)
                          GestureDetector(
                            onTap: () => _showEquipmentDetails(eq),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 2, vertical: 5),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: firstUrl != null
                                    ? Image.network(
                                        firstUrl,
                                        width: 36,
                                        height: 36,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            _photoPlaceholder(),
                                      )
                                    : _photoPlaceholder(),
                              ),
                            ),
                          ),
                          // Name + Category
                          tapCell(Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name.isEmpty ? '—' : name,
                                style: cellStyle.copyWith(
                                    fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                              Text(
                                category.isEmpty ? 'Uncategorized' : category,
                                style: TextStyle(
                                    fontSize: 8, color: Colors.grey.shade500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          )),
                          // Owner
                          tapCell(Text(
                            eq['ownerName'] as String? ?? '—',
                            style: cellStyle,
                            overflow: TextOverflow.ellipsis,
                          )),
                          // Type pill (Motorized / Manual)
                          tapCell(Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: isMotorized
                                  ? Colors.blue.shade50
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: isMotorized
                                    ? Colors.blue.shade200
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isMotorized
                                      ? Icons.settings
                                      : Icons.handyman_outlined,
                                  size: 8,
                                  color: isMotorized
                                      ? Colors.blue.shade700
                                      : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    isMotorized ? 'Motorized' : 'Manual',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w600,
                                      color: isMotorized
                                          ? Colors.blue.shade700
                                          : Colors.grey.shade600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )),
                          // Status pill
                          tapCell(Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              _statusLabel(status),
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                          // Renter
                          tapCell(renter != null
                              ? Text(renter,
                                  style: cellStyle.copyWith(
                                      color: Colors.blue.shade700),
                                  overflow: TextOverflow.ellipsis)
                              : Text('—',
                                  style: cellStyle.copyWith(
                                      color: Colors.grey.shade400))),
                          // Maintenance count
                          tapCell(Text(
                            '$maintenanceCount',
                            style: cellStyle.copyWith(
                                fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          )),
                          // Breakdown count (Major for motorized, Total for non)
                          tapCell(Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$breakdownCount',
                                style: cellStyle.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: breakdownColor,
                                ),
                              ),
                              Text(
                                isMotorized ? 'Major' : 'Total',
                                style: TextStyle(
                                    fontSize: 7, color: Colors.grey.shade500),
                              ),
                            ],
                          )),
                          // Retirement flag (own tap — does NOT open drilldown)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 4),
                            child: GestureDetector(
                              onTap: () => _toggleRetirementFlag(
                                  id, flagged, name, eq['ownerId'] as String?),
                              child: Icon(
                                flagged ? Icons.flag : Icons.flag_outlined,
                                size: 18,
                                color: flagged
                                    ? Colors.deepOrange
                                    : Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryTable() {
    final sorted = _categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = _categoryCounts.values.fold(0, (a, b) => a + b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Equipment Demographics', _categoryCounts.length),
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No data.',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                lightColorScheme.primary.withValues(alpha: 0.07),
              ),
              columnSpacing: 24,
              horizontalMargin: 16,
              columns: const [
                DataColumn(
                  label: Text(
                    'Category / Type',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Count',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: Text(
                    'Share',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  numeric: true,
                ),
              ],
              rows: [
                ...sorted.map((entry) {
                  final pct = total > 0
                      ? (entry.value / total * 100).toStringAsFixed(1)
                      : '0.0';
                  return DataRow(
                    cells: [
                      DataCell(Text(entry.key)),
                      DataCell(
                        Text(
                          '${entry.value}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(
                        Text(
                          '$pct%',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                DataRow(
                  cells: [
                    DataCell(
                      Text(
                        'Total',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: lightColorScheme.primary,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '$total',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: lightColorScheme.primary,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        '100%',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: lightColorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  (double, double) _effectivePriceLimit(String category) {
    final override = _priceLimits[category];
    if (override != null) return (override.minPrice, override.maxPrice);
    final fallback = getCategoryPriceLimits(category);
    return fallback ?? (0, 0);
  }

  Future<void> _openEditPriceLimitDialog(String category) async {
    final current = _effectivePriceLimit(category);
    final minCtrl = TextEditingController(
      text: current.$1 > 0 ? current.$1.toStringAsFixed(0) : '',
    );
    final maxCtrl = TextEditingController(
      text: current.$2 > 0 ? current.$2.toStringAsFixed(0) : '',
    );
    String? errorText;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text('Price Limits — $category'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Minimum Price (₱)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: maxCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Maximum Price (₱)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      errorText!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final min = double.tryParse(minCtrl.text.trim());
                    final max = double.tryParse(maxCtrl.text.trim());
                    if (min == null || max == null) {
                      setDialogState(() => errorText = 'Enter valid numbers.');
                      return;
                    }
                    if (min < 0 || max <= min) {
                      setDialogState(
                        () => errorText =
                            'Maximum must be greater than minimum, and minimum cannot be negative.',
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true || !mounted) return;

    final min = double.parse(minCtrl.text.trim());
    final max = double.parse(maxCtrl.text.trim());
    try {
      await EquipmentPriceLimitService().setLimit(
        categoryLabel: category,
        minPrice: min,
        maxPrice: max,
      );
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save price limit: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPriceLimitEditor() {
    final categories = List<String>.from(_allCategories)..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Category Price Limits', categories.length),
        const SizedBox(height: 4),
        Text(
          'Tap a category to set the minimum and maximum price listers can enter for it.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (categories.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No categories found.',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: categories.map((category) {
                final (min, max) = _effectivePriceLimit(category);
                final isOverridden = _priceLimits.containsKey(category);
                return ListTile(
                  title: Text(category),
                  subtitle: Text(
                    max > 0
                        ? '₱${min.toStringAsFixed(0)} – ₱${max.toStringAsFixed(0)}'
                        : 'No limit set',
                  ),
                  trailing: isOverridden
                      ? Chip(
                          label: const Text(
                            'Admin-set',
                            style: TextStyle(fontSize: 11),
                          ),
                          backgroundColor:
                              lightColorScheme.primary.withValues(alpha: 0.1),
                          visualDensity: VisualDensity.compact,
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: () => _openEditPriceLimitDialog(category),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
        titleTextStyle: TextStyle(
          color: lightColorScheme.onPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [lightColorScheme.primary, lightColorScheme.secondary],
            ),
          ),
        ),
        iconTheme: IconThemeData(color: lightColorScheme.onPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Failed to load data',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCategoryTable(),
                    const SizedBox(height: 28),
                    _buildPriceLimitEditor(),
                    const SizedBox(height: 28),
                    _buildEquipmentTable(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
