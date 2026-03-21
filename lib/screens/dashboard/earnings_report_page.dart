import 'dart:typed_data';

import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/services/earnings_service.dart';
import 'package:bukidbayan_app/services/rent_request_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

class EarningsReportPage extends StatefulWidget {
  const EarningsReportPage({super.key});

  @override
  State<EarningsReportPage> createState() => _EarningsReportPageState();
}

class _EarningsReportPageState extends State<EarningsReportPage> {
  final RentRequestService _service = RentRequestService();
  final String _ownerId = FirebaseAuth.instance.currentUser!.uid;

  // Filters
  DateTimeRange? _dateRange;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Enriched row model
  List<_TransactionRow> _rows = [];
  List<_TransactionRow> _filtered = [];
  bool _loading = true;
  String? _error;

  // Add alongside existing filter state variables
String? _equipmentFilter;      // null = all
String _operatorFilter = 'all'; // 'all' | 'yes' | 'no'
double? _minPayment;
double? _maxPayment;
final TextEditingController _minPaymentController = TextEditingController();
final TextEditingController _maxPaymentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minPaymentController.dispose();
    _maxPaymentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Fetch all completed requests for this owner
      final snapshot = await FirebaseFirestore.instance
          .collection('rentRequests')
          .where('ownerId', isEqualTo: _ownerId)
          .where('status', isEqualTo: RentRequestStatus.completed.name)
          .get();

      final requests =
          snapshot.docs.map((d) => RentRequest.fromDoc(d)).toList();

      // Enrich each request with equipment data
      final rows = await Future.wait(requests.map((req) async {
        Equipment? equipment;
        try {
          final eqDoc = await FirebaseFirestore.instance
              .collection('equipment')
              .doc(req.itemId)
              .get();
          if (eqDoc.exists) equipment = Equipment.fromFirestore(eqDoc);
        } catch (_) {}
        return _TransactionRow(request: req, equipment: equipment);
      }));

      // Sort newest first
      rows.sort((a, b) => b.request.start.compareTo(a.request.start));

      setState(() {
        _rows = rows;
        _applyFilters();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

void _applyFilters() {
  setState(() {
    _filtered = _rows.where((row) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = row.request.name.toLowerCase().contains(q);
        final matchItem = row.request.itemName.toLowerCase().contains(q);
        final matchAddr = (row.request.farmAddress ?? row.request.address)
            .toLowerCase()
            .contains(q);
        if (!matchName && !matchItem && !matchAddr) return false;
      }
      // Date range filter
      if (_dateRange != null) {
        final start = row.request.start;
        if (start.isBefore(_dateRange!.start) ||
            start.isAfter(_dateRange!.end)) return false;
      }
      // Equipment filter
      if (_equipmentFilter != null &&
          row.request.itemName != _equipmentFilter) return false;
      // Operator filter
      if (_operatorFilter == 'yes' && !row.withOperator) return false;
      if (_operatorFilter == 'no' && row.withOperator) return false;
      // Payment range filter
      final payment = row.totalPayment ?? 0;
      if (_minPayment != null && payment < _minPayment!) return false;
      if (_maxPayment != null && payment > _maxPayment!) return false;

      return true;
    }).toList();
  });
}

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dateRange = picked);
      _applyFilters();
    }
  }

 void _clearFilters() {
  _searchController.clear();
  _minPaymentController.clear();
  _maxPaymentController.clear();
  setState(() {
    _searchQuery = '';
    _dateRange = null;
    _equipmentFilter = null;
    _operatorFilter = 'all';
    _minPayment = null;
    _maxPayment = null;
  });
  _applyFilters();
}

  // Add this method inside _EarningsReportPageState:
Future<void> _exportPdf() async {
  // Fetch owner name from Firestore
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  final data = userDoc.data();
  final ownerName = data != null
      ? '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim()
      : 'Owner';

  await EarningsPdfService.generateAndShare(
    rows: _filtered
        .map((r) => (request: r.request, equipment: r.equipment))
        .toList(),
    totalEarnings: _totalEarnings,
    ownerName: ownerName,
    dateRange: _dateRange,
  );
}

// Shared helper — builds the PDF bytes and fetches owner name
Future<(Uint8List, String)> _buildPdfData() async {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  final data = userDoc.data();
  final ownerName = data != null
      ? '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim()
      : 'Owner';

  final bytes = await EarningsPdfService.buildPdfBytes(
    rows: _filtered
        .map((r) => (request: r.request, equipment: r.equipment))
        .toList(),
    totalEarnings: _totalEarnings,
    ownerName: ownerName,
    dateRange: _dateRange,
    // ── NEW ──
    searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
    equipmentFilter: _equipmentFilter,
    operatorFilter: _operatorFilter != 'all' ? _operatorFilter : null,
    minPayment: _minPayment,
    maxPayment: _maxPayment,
  );

  return (bytes, ownerName);
}

// Instantly saves to device — no printer dialog
Future<void> _downloadPdf() async {
  try {
    final (bytes, _) = await _buildPdfData();
    final filename = 'earnings_report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';

    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: filename,
    );
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }
}

// Opens print dialog for selecting a printer
Future<void> _printPdf() async {
  try {
    final (bytes, _) = await _buildPdfData();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'earnings_report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
    );
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e')),
      );
    }
  }
}

  double get _totalEarnings => _filtered.fold(0, (sum, r) {
  final payment = (r.request.estimatedMillingFee != null &&
          r.request.estimatedMillingFee! > 0)
      ? r.request.estimatedMillingFee!
      : (r.request.agreedPrice ?? 0);
  return sum + payment;
});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Earnings Report',
          style: TextStyle(color: lightColorScheme.onPrimary, fontSize: 16),
        ),
        centerTitle: true,
        backgroundColor: lightColorScheme.primary,
        iconTheme: IconThemeData(color: lightColorScheme.onPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _loadData)
              : Column(
                  children: [
                   _FiltersBar(
                    searchController: _searchController,
                    dateRange: _dateRange,
                    equipmentOptions: _rows.map((r) => r.request.itemName).toSet().toList()..sort(),
                    equipmentFilter: _equipmentFilter,
                    operatorFilter: _operatorFilter,
                    minPaymentController: _minPaymentController,
                    maxPaymentController: _maxPaymentController,
                    onSearchChanged: (v) {
                      setState(() => _searchQuery = v);
                      _applyFilters();
                    },
                    onPickDateRange: _pickDateRange,
                    onEquipmentChanged: (v) {
                      setState(() => _equipmentFilter = v);
                      _applyFilters();
                    },
                    onOperatorChanged: (v) {
                      setState(() => _operatorFilter = v);
                      _applyFilters();
                    },
                    onMinPaymentChanged: (v) {
                      setState(() => _minPayment = double.tryParse(v));
                      _applyFilters();
                    },
                    onMaxPaymentChanged: (v) {
                      setState(() => _maxPayment = double.tryParse(v));
                      _applyFilters();
                    },
                    onClear: _clearFilters,
                  ),
                    _SummaryCard(
                      totalEarnings: _totalEarnings,
                      totalTransactions: _filtered.length,
                    ),
                    Expanded(
                      child: _filtered.isEmpty
                          ? const _EmptyView()
                          : _TransactionTable(rows: _filtered),
                    ),
                  ],
                ),

                bottomNavigationBar: _filtered.isEmpty || _loading
    ? null
    : SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.download_rounded),
                  label: const Text(
                    'Download',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lightColorScheme.primary,
                    foregroundColor: lightColorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _downloadPdf,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.print_rounded),
                  label: const Text(
                    'Print',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    foregroundColor: Colors.grey.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  onPressed: _printPdf,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Data model ────────────────────────────────────────────────────────────

class _TransactionRow {
  final RentRequest request;
  final Equipment? equipment;

  const _TransactionRow({required this.request, this.equipment});

  int get daysRented => request.end.difference(request.start).inDays
      .clamp(1, 9999);

  String get measurementDisplay {
    if (request.hectaresEntered != null) {
      return '${request.hectaresEntered!.toStringAsFixed(2)} ha';
    }
    if (request.volumeSubmitted != null) {
      return '${request.volumeSubmitted!.toStringAsFixed(1)} kg';
    }
    return '—';
  }

  bool get withOperator => equipment?.operatorIncluded ?? false;

  String get farmLocation =>
      request.farmAddress ?? request.address;

    // Add this getter to _TransactionRow:
double? get totalPayment {
  // estimatedMillingFee is the total for rice mill (per kg * volume)
  // agreedPrice is the total for everything else
  if (request.estimatedMillingFee != null && request.estimatedMillingFee! > 0) {
    return request.estimatedMillingFee;
  }
  return request.agreedPrice;
}

}



// ─── Filters bar ───────────────────────────────────────────────────────────

class _FiltersBar extends StatelessWidget {
  final TextEditingController searchController;
  final DateTimeRange? dateRange;
  final List<String> equipmentOptions;
  final String? equipmentFilter;
  final String operatorFilter;
  final TextEditingController minPaymentController;
  final TextEditingController maxPaymentController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onPickDateRange;
  final ValueChanged<String?> onEquipmentChanged;
  final ValueChanged<String> onOperatorChanged;
  final ValueChanged<String> onMinPaymentChanged;
  final ValueChanged<String> onMaxPaymentChanged;
  final VoidCallback onClear;

  const _FiltersBar({
    required this.searchController,
    required this.dateRange,
    required this.equipmentOptions,
    required this.equipmentFilter,
    required this.operatorFilter,
    required this.minPaymentController,
    required this.maxPaymentController,
    required this.onSearchChanged,
    required this.onPickDateRange,
    required this.onEquipmentChanged,
    required this.onOperatorChanged,
    required this.onMinPaymentChanged,
    required this.onMaxPaymentChanged,
    required this.onClear,
  });

  bool get _hasActiveFilters =>
      dateRange != null ||
      searchController.text.isNotEmpty ||
      equipmentFilter != null ||
      operatorFilter != 'all' ||
      minPaymentController.text.isNotEmpty ||
      maxPaymentController.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search ───────────────────────────────────────
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search farmer, equipment, or location...',
              prefixIcon: const Icon(Icons.search_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),

          // ── Date range + Equipment row ────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(
                    dateRange == null
                        ? 'Filter by Date'
                        : '${DateFormat('MMM d').format(dateRange!.start)} – ${DateFormat('MMM d, yyyy').format(dateRange!.end)}',
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onPickDateRange,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: equipmentFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: 'All Equipment',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.agriculture_rounded, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 8),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Equipment',
                          style: TextStyle(fontSize: 13)),
                    ),
                    ...equipmentOptions.map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        )),
                  ],
                  onChanged: onEquipmentChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

         // ── Operator filter + Payment range row ──────────
Wrap(
  spacing: 8,
  runSpacing: 8,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Operator:',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(width: 6),
        ...[
          ('all', 'All'),
          ('yes', 'Yes'),
          ('no', 'No'),
        ].map((opt) {
          final isSelected = operatorFilter == opt.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: () => onOperatorChanged(opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? lightColorScheme.primary
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? lightColorScheme.primary
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  opt.$2,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    ),

    // ── Payment range on its own line ─────────────
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Payment Range',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 130,
              child: TextField(
                controller: minPaymentController,
                onChanged: onMinPaymentChanged,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Min Payment',
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.arrow_downward_rounded, size: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 10),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 130,
              child: TextField(
                controller: maxPaymentController,
                onChanged: onMaxPaymentChanged,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Max Payment',
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.arrow_upward_rounded, size: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 10),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  ],
),

          // ── Clear all filters ─────────────────────────────
          if (_hasActiveFilters) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                icon: const Icon(Icons.close_rounded, size: 15),
                label: const Text('Clear all filters',
                    style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade400,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onClear,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Summary card ──────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double totalEarnings;
  final int totalTransactions;

  const _SummaryCard({
    required this.totalEarnings,
    required this.totalTransactions,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '₱', decimalDigits: 2);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: lightColorScheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Earnings',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currency.format(totalEarnings),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Transactions',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                '$totalTransactions',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Scrollable table ──────────────────────────────────────────────────────

class _TransactionTable extends StatelessWidget {
  final List<_TransactionRow> rows;

  const _TransactionTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              Colors.green.shade700.withOpacity(0.08),
            ),
            headingTextStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            dataTextStyle: const TextStyle(fontSize: 12),
            columnSpacing: 20,
            horizontalMargin: 14,
            border: TableBorder.all(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            columns: const [
              DataColumn(label: Text('#')),
              DataColumn(label: Text('Date Rented')),
              DataColumn(label: Text('Farmer Name')),
              DataColumn(label: Text('Farm Location')),
              DataColumn(label: Text('Equipment')),
              DataColumn(label: Text('Price Rate'), numeric: true),  // NEW — replaces W/ Operator
              DataColumn(label: Text('Rate')),
              DataColumn(label: Text('Days Rented')),
              DataColumn(label: Text('Area / Volume')),
              DataColumn(label: Text('Payment'), numeric: true),
            ],
            rows: List.generate(rows.length, (i) {
  final row = rows[i];
  final req = row.request;
  final currency = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
  final dateFormat = DateFormat('MMM d, yyyy');

  // Build price rate string: ₱price / rentalUnit
  final priceRate = row.equipment != null
      ? '${currency.format(row.equipment!.price)}'
      : '—';

  return DataRow(
    cells: [
      DataCell(Text('${i + 1}', style: const TextStyle(color: Colors.grey))),
      DataCell(Text(dateFormat.format(req.start))),
      DataCell(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Text(req.name, overflow: TextOverflow.ellipsis),
        ),
      ),
      DataCell(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(row.farmLocation, overflow: TextOverflow.ellipsis),
        ),
      ),
      DataCell(
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Text(req.itemName, overflow: TextOverflow.ellipsis),
        ),
      ),
      // NEW: Price Rate cell (replaces W/ Operator)
      DataCell(
        Text(
          priceRate,
          style: TextStyle(
            fontSize: 12,
            color: Colors.green.shade700,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.right,
        ),
      ),
      DataCell(Text(
        req.agreedRentalUnit ?? req.itemName,
        style: const TextStyle(fontSize: 12),
      )),
      DataCell(Text(
        req.agreedRentalUnit?.toLowerCase().contains('day') == true
            ? '${row.daysRented} day${row.daysRented > 1 ? 's' : ''}'
            : '—',
      )),
      DataCell(Text(row.measurementDisplay)),
      DataCell(
        Text(
          row.totalPayment != null
              ? currency.format(row.totalPayment)
              : '—',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green.shade700,
          ),
        ),
      ),
    ],
  );
}),
          ),
        ),
      ),
    );
  }
}

// ─── Empty / error states ──────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'No completed transactions found',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            'Completed rentals will appear here.',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text('Failed to load report',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}