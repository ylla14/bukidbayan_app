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
  bool _sortByCondition = false;

  static const _conditionOrder = ['Brand New', 'Excellent', 'Good', 'Fair'];

  int _conditionRank(String? condition) {
    final idx = _conditionOrder.indexOf(condition ?? '');
    return idx == -1 ? _conditionOrder.length : idx;
  }

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
        final cat = (eq['category'] as String? ?? '').trim();
        final key = cat.isEmpty ? 'Uncategorized' : cat;
        catCounts[key] = (catCounts[key] ?? 0) + 1;
      }

      setState(() {
        _equipment = equipment;
        _activeRenters = activeRenters;
        _categoryCounts = catCounts;
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
      case 'available':
        return Colors.green;
      case 'underMaintenance':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'available':
        return 'Available';
      case 'underMaintenance':
        return 'Maintenance';
      case 'unavailable':
        return 'Unavailable';
      default:
        return status ?? '—';
    }
  }

  Widget _sectionHeader(String title, int count) {
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
            '$count',
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

  Widget _buildEquipmentTable() {
    const headerStyle = TextStyle(fontSize: 9, fontWeight: FontWeight.w700);
    const cellStyle = TextStyle(fontSize: 9);
    const cellPadding = EdgeInsets.symmetric(horizontal: 5, vertical: 8);

    Widget headerCell(String text) => Padding(
      padding: cellPadding,
      child: Text(text, style: headerStyle, overflow: TextOverflow.ellipsis),
    );

    final displayList = _sortByCondition
        ? (List<Map<String, dynamic>>.from(_equipment)
          ..sort((a, b) => _conditionRank(a['condition'] as String?)
              .compareTo(_conditionRank(b['condition'] as String?))))
        : _equipment;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Equipment Inventory', _equipment.length),
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
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Table(
                // Proportional columns — fills phone width automatically
                columnWidths: const {
                  0: FlexColumnWidth(2.5), // Name (widest)
                  1: FlexColumnWidth(1.8), // Category
                  2: FlexColumnWidth(1.8), // Owner
                  3: FlexColumnWidth(1.5), // Condition
                  4: FlexColumnWidth(1.8), // Status
                  5: FlexColumnWidth(1.8), // Renter
                },
                border: TableBorder(
                  horizontalInside: BorderSide(
                    color: Colors.grey.shade200,
                    width: 0.8,
                  ),
                ),
                children: [
                  // Header row
                  TableRow(
                    decoration: BoxDecoration(
                      color: lightColorScheme.primary.withValues(alpha: 0.07),
                    ),
                    children: [
                      headerCell('Name'),
                      headerCell('Category'),
                      headerCell('Owner'),
                      // Tappable sort header
                      GestureDetector(
                        onTap: () => setState(
                            () => _sortByCondition = !_sortByCondition),
                        child: Padding(
                          padding: cellPadding,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'Condition',
                                  style: headerStyle,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                _sortByCondition
                                    ? Icons.arrow_upward
                                    : Icons.unfold_more,
                                size: 10,
                                color: _sortByCondition
                                    ? lightColorScheme.primary
                                    : Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                      headerCell('Status'),
                      headerCell('Renter'),
                    ],
                  ),
                  // Data rows
                  ...displayList.map((eq) {
                    final id = eq['_id'] as String;
                    final renter = _activeRenters[id];
                    final status = eq['status'] as String?;
                    final color = _statusColor(status);

                    Widget cell(Widget child) =>
                        Padding(padding: cellPadding, child: child);

                    return TableRow(
                      children: [
                        cell(
                          Text(
                            eq['name'] as String? ?? '—',
                            style: cellStyle.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        cell(
                          Text(
                            (eq['category'] as String? ?? '').isEmpty
                                ? 'Uncategorized'
                                : eq['category'] as String,
                            style: cellStyle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        cell(
                          Text(
                            eq['ownerName'] as String? ?? '—',
                            style: cellStyle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        cell(
                          Text(
                            eq['condition'] as String? ?? '—',
                            style: cellStyle,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        cell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              _statusLabel(status),
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        cell(
                          renter != null
                              ? Text(
                                  renter,
                                  style: cellStyle.copyWith(
                                    color: Colors.blue.shade700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                )
                              : Text(
                                  '—',
                                  style: cellStyle.copyWith(
                                    color: Colors.grey.shade400,
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
        _sectionHeader('Equipment by Type', _categoryCounts.length),
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
                    _buildEquipmentTable(),
                    const SizedBox(height: 28),
                    _buildCategoryTable(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}
