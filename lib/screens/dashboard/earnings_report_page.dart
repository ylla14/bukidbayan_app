import 'dart:typed_data';

import 'package:bukidbayan_app/models/analytics_time_window.dart';
import 'package:bukidbayan_app/models/demand_forecast.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/owner_rental_report.dart';
import 'package:bukidbayan_app/services/analytics/rental_analytics_service.dart';
import 'package:bukidbayan_app/services/earnings_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

final NumberFormat _reportCurrency = NumberFormat.currency(
  symbol: 'PHP ',
  decimalDigits: 2,
);
final DateFormat _reportDate = DateFormat('MMM d, yyyy');

class EarningsReportPage extends StatefulWidget {
  const EarningsReportPage({super.key});

  @override
  State<EarningsReportPage> createState() => _EarningsReportPageState();
}

class _EarningsReportPageState extends State<EarningsReportPage>
    with SingleTickerProviderStateMixin {
  final RentalAnalyticsService _analyticsService = RentalAnalyticsService();
  final String _ownerId = FirebaseAuth.instance.currentUser!.uid;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minPaymentController = TextEditingController();
  final TextEditingController _maxPaymentController = TextEditingController();
  late final TabController _tabController;

  OwnerRentalReportFilter _filter = const OwnerRentalReportFilter();
  OwnerRentalReportSource? _source;
  OwnerRentalReport? _report;
  bool _loading = true;
  String? _error;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
    _loadData();
  }

  void _handleTabChanged() {
    if (_selectedTabIndex == _tabController.index) return;
    setState(() {
      _selectedTabIndex = _tabController.index;
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
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
      final source = await _analyticsService.loadOwnerReportSource(
        ownerId: _ownerId,
      );
      final report = _analyticsService.buildOwnerRentalReport(
        source: source,
        filter: _filter,
      );

      if (!mounted) return;

      setState(() {
        _source = source;
        _report = report;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _rebuildReport(OwnerRentalReportFilter nextFilter) {
    final source = _source;
    if (source == null) return;

    setState(() {
      _filter = nextFilter;
      _report = _analyticsService.buildOwnerRentalReport(
        source: source,
        filter: _filter,
      );
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _filter.timeWindow == null
          ? null
          : DateTimeRange(
              start: _filter.timeWindow!.start,
              end: _filter.timeWindow!.end,
            ),
    );

    if (picked == null) return;

    _rebuildReport(
      _filter.copyWith(
        timeWindow: AnalyticsTimeWindow(start: picked.start, end: picked.end),
      ),
    );
  }

  void _clearFilters() {
    _searchController.clear();
    _minPaymentController.clear();
    _maxPaymentController.clear();
    _rebuildReport(const OwnerRentalReportFilter());
  }

  List<_EquipmentFilterOption> get _equipmentOptions {
    final source = _source;
    if (source == null) return const [];

    final options = <String, _EquipmentFilterOption>{};

    for (final equipment in source.ownedEquipment) {
      final equipmentId = equipment.id;
      if (equipmentId == null) continue;
      options[equipmentId] = _EquipmentFilterOption(
        equipmentId: equipmentId,
        equipmentName: equipment.name,
      );
    }

    for (final row in source.rows) {
      options.putIfAbsent(
        row.request.itemId,
        () => _EquipmentFilterOption(
          equipmentId: row.request.itemId,
          equipmentName: row.request.itemName,
        ),
      );
    }

    final values = options.values.toList()
      ..sort(
        (a, b) => a.equipmentName.toLowerCase().compareTo(
          b.equipmentName.toLowerCase(),
        ),
      );
    return values;
  }

  Future<String> _getOwnerName() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = userDoc.data();
    if (data == null) return 'Owner';

    final firstName = (data['firstName'] as String?)?.trim() ?? '';
    final lastName = (data['lastName'] as String?)?.trim() ?? '';
    final fullName = '$firstName $lastName'.trim();
    return fullName.isEmpty ? 'Owner' : fullName;
  }

  Future<(Uint8List, String)> _buildAnalyticsPdfData() async {
    final report = _report;
    if (report == null) {
      throw StateError('Report is not available.');
    }

    final ownerName = await _getOwnerName();
    final bytes = await EarningsPdfService.buildPdfBytes(
      report: report,
      ownerName: ownerName,
    );

    return (bytes, ownerName);
  }

  Future<(Uint8List, String)> _buildLegacyPdfData() async {
    final report = _report;
    if (report == null) {
      throw StateError('Report is not available.');
    }

    final ownerName = await _getOwnerName();
    final bytes = await EarningsPdfService.buildLegacyPdfBytes(
      report: report,
      ownerName: ownerName,
    );

    return (bytes, ownerName);
  }

  bool get _showAnalyticsTab => _selectedTabIndex == 1;

  Future<void> _sharePdf() async {
    try {
      final (bytes, _) = _showAnalyticsTab
          ? await _buildAnalyticsPdfData()
          : await _buildLegacyPdfData();
      final filename = _showAnalyticsTab
          ? 'owner_rental_analytics_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf'
          : 'earnings_report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('PDF export failed: $error')));
    }
  }

  Future<void> _printPdf() async {
    try {
      final (bytes, _) = _showAnalyticsTab
          ? await _buildAnalyticsPdfData()
          : await _buildLegacyPdfData();
      final filename = _showAnalyticsTab
          ? 'owner_rental_analytics_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf'
          : 'earnings_report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf';
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: filename);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Print failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final showBottomActions =
        report != null && (_showAnalyticsTab || report.filteredRows.isNotEmpty);

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
          : report == null
          ? _ErrorView(
              error: 'No owner analytics report is available.',
              onRetry: _loadData,
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _FiltersBar(
                    searchController: _searchController,
                    reportFilter: _filter,
                    equipmentOptions: _equipmentOptions,
                    minPaymentController: _minPaymentController,
                    maxPaymentController: _maxPaymentController,
                    onSearchChanged: (value) {
                      _rebuildReport(_filter.copyWith(searchQuery: value));
                    },
                    onPickDateRange: _pickDateRange,
                    onEquipmentChanged: (equipmentId) {
                      _rebuildReport(
                        _filter.copyWith(equipmentId: equipmentId),
                      );
                    },
                    onOperatorChanged: (operatorFilter) {
                      _rebuildReport(
                        _filter.copyWith(operatorFilter: operatorFilter),
                      );
                    },
                    onMinPaymentChanged: (value) {
                      _rebuildReport(
                        _filter.copyWith(
                          minPayment: value.trim().isEmpty
                              ? null
                              : double.tryParse(value),
                        ),
                      );
                    },
                    onMaxPaymentChanged: (value) {
                      _rebuildReport(
                        _filter.copyWith(
                          maxPayment: value.trim().isEmpty
                              ? null
                              : double.tryParse(value),
                        ),
                      );
                    },
                    onClear: _clearFilters,
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: lightColorScheme.primary,
                      unselectedLabelColor: Colors.black54,
                      indicatorColor: lightColorScheme.primary,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                      tabs: const [
                        Tab(text: 'Earnings'),
                        Tab(text: 'Analytics'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _EarningsTab(
                        report: report,
                        hasBottomActions: showBottomActions,
                      ),
                      _AnalyticsTab(
                        report: report,
                        hasBottomActions: showBottomActions,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: report == null || !showBottomActions || _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _sharePdf,
                        icon: Icon(
                          _showAnalyticsTab
                              ? Icons.share_rounded
                              : Icons.download_rounded,
                        ),
                        label: Text(
                          _showAnalyticsTab ? 'Export PDF' : 'Download',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: lightColorScheme.primary,
                          foregroundColor: lightColorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _printPdf,
                        icon: const Icon(Icons.print_rounded),
                        label: const Text(
                          'Print',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
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
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _EquipmentFilterOption {
  final String equipmentId;
  final String equipmentName;

  const _EquipmentFilterOption({
    required this.equipmentId,
    required this.equipmentName,
  });
}

class _FiltersBar extends StatelessWidget {
  final TextEditingController searchController;
  final OwnerRentalReportFilter reportFilter;
  final List<_EquipmentFilterOption> equipmentOptions;
  final TextEditingController minPaymentController;
  final TextEditingController maxPaymentController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onPickDateRange;
  final ValueChanged<String?> onEquipmentChanged;
  final ValueChanged<OwnerOperatorFilter> onOperatorChanged;
  final ValueChanged<String> onMinPaymentChanged;
  final ValueChanged<String> onMaxPaymentChanged;
  final VoidCallback onClear;

  const _FiltersBar({
    required this.searchController,
    required this.reportFilter,
    required this.equipmentOptions,
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

  @override
  Widget build(BuildContext context) {
    final timeWindow = reportFilter.timeWindow;
    final dateLabel = timeWindow == null
        ? 'Filter by Date'
        : '${_reportDate.format(timeWindow.start)} - ${_reportDate.format(timeWindow.end)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filter completed rentals',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickDateRange,
                  icon: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(
                    dateLabel,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: reportFilter.equipmentId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: 'All Equipment',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.agriculture_rounded, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text(
                        'All Equipment',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    ...equipmentOptions.map(
                      (option) => DropdownMenuItem<String>(
                        value: option.equipmentId,
                        child: Text(
                          option.equipmentName,
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: onEquipmentChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Operator:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(width: 6),
                  ...OwnerOperatorFilter.values.map((option) {
                    final isSelected = reportFilter.operatorFilter == option;
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: GestureDetector(
                        onTap: () => onOperatorChanged(option),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
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
                            option.shortLabel,
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
                            prefixIcon: const Icon(
                              Icons.arrow_downward_rounded,
                              size: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 10,
                            ),
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
                            prefixIcon: const Icon(
                              Icons.arrow_upward_rounded,
                              size: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 10,
                            ),
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
          if (reportFilter.hasActiveFilters) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 15),
                label: const Text(
                  'Clear all filters',
                  style: TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade400,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EarningsTab extends StatelessWidget {
  final OwnerRentalReport report;
  final bool hasBottomActions;

  const _EarningsTab({required this.report, required this.hasBottomActions});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, hasBottomActions ? 92 : 24),
      children: [
        _LegacySummaryCard(
          totalEarnings: report.summary.totalEarnings,
          totalTransactions: report.filteredRows.length,
        ),
        const SizedBox(height: 12),
        if (report.filteredRows.isEmpty)
          const _EmptyTransactionsView()
        else
          _TransactionTable(rows: report.filteredRows),
      ],
    );
  }
}

class _AnalyticsTab extends StatelessWidget {
  final OwnerRentalReport report;
  final bool hasBottomActions;

  const _AnalyticsTab({required this.report, required this.hasBottomActions});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, hasBottomActions ? 92 : 24),
      children: [
        _SummarySection(summary: report.summary),
        const SizedBox(height: 12),
        _AnalyticsNoteCard(window: report.utilizationWindow),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Forecast for Your Tools',
          subtitle:
              'Owner-only demand outlook based on request history for your equipment and the new crop/phase inputs when available.',
          child: _ForecastSectionView(snapshot: report.forecastSnapshot),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Current Fleet Maintenance',
          subtitle:
              'This snapshot reflects the current state of the equipment in scope.',
          child: _MaintenanceSnapshotView(snapshot: report.maintenanceSnapshot),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Performance by Equipment',
          subtitle:
              'Completed rentals only. Totals follow the current report filters.',
          child: report.equipmentPerformance.isEmpty
              ? const _SectionEmpty(
                  message:
                      'No equipment performance data matches the current filters.',
                )
              : _EquipmentPerformanceTable(items: report.equipmentPerformance),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Performance by Category',
          subtitle:
              'Useful for seeing which equipment types are earning and serving the most farmers.',
          child: report.categoryPerformance.isEmpty
              ? const _SectionEmpty(
                  message:
                      'No category performance data matches the current filters.',
                )
              : _CategoryPerformanceTable(items: report.categoryPerformance),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Estimated Utilization',
          subtitle:
              'Estimated booked hours use booked days x 24 hours, consistent with the current maintenance-hour heuristic.',
          child: report.utilizationItems.isEmpty
              ? const _SectionEmpty(
                  message:
                      'No equipment utilization data is available for the current scope.',
                )
              : _UtilizationTable(items: report.utilizationItems),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Completed Transactions',
          subtitle:
              'Detailed rental history for the rows matched by the current filters.',
          child: report.filteredRows.isEmpty
              ? const _EmptyTransactionsView()
              : _TransactionTable(rows: report.filteredRows),
        ),
      ],
    );
  }
}

class _ForecastSectionView extends StatelessWidget {
  final OwnerRentalForecastSnapshot snapshot;

  const _ForecastSectionView({required this.snapshot});

  String _confidenceLabel(DemandForecastConfidence confidence) {
    switch (confidence) {
      case DemandForecastConfidence.high:
        return 'High';
      case DemandForecastConfidence.medium:
        return 'Medium';
      case DemandForecastConfidence.low:
        return 'Early';
    }
  }

  String _levelLabel(DemandForecastLevel level) {
    switch (level) {
      case DemandForecastLevel.high:
        return 'High demand';
      case DemandForecastLevel.medium:
        return 'Medium demand';
      case DemandForecastLevel.low:
        return 'Early signal';
    }
  }

  Color _levelColor(DemandForecastLevel level) {
    switch (level) {
      case DemandForecastLevel.high:
        return Colors.red.shade700;
      case DemandForecastLevel.medium:
        return Colors.orange.shade700;
      case DemandForecastLevel.low:
        return Colors.blue.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MiniStatusCard(
              label: 'Signals Used',
              value: '${snapshot.requestsConsidered}',
              color: Colors.blueGrey.shade700,
            ),
            _MiniStatusCard(
              label: 'Forecast Inputs',
              value:
                  '${snapshot.requestsWithForecastInputs} (${(snapshot.forecastInputCoverageRate * 100).toStringAsFixed(0)}%)',
              color: Colors.teal.shade700,
            ),
            _MiniStatusCard(
              label: 'Confidence',
              value: _confidenceLabel(snapshot.confidence),
              color: Colors.indigo.shade700,
            ),
            _MiniStatusCard(
              label: 'Matched Tools',
              value: '${snapshot.equipmentMatches.length}',
              color: Colors.green.shade700,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.blueGrey.shade100),
          ),
          child: Text(
            snapshot.summary,
            style: TextStyle(color: Colors.blueGrey.shade900, height: 1.35),
          ),
        ),
        const SizedBox(height: 12),
        if (!snapshot.hasInsights)
          const _SectionEmpty(
            message:
                'Not enough owner-side demand signals yet. This section improves as more requests are recorded, especially when renters fill in crop type, farming phase, and intended use.',
          )
        else ...[
          ...snapshot.categoryInsights.map(
            (insight) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _levelColor(insight.level).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _levelColor(insight.level).withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          insight.equipmentCategory,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        _levelLabel(insight.level),
                        style: TextStyle(
                          color: _levelColor(insight.level),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    insight.recommendation,
                    style: TextStyle(color: Colors.grey.shade800, height: 1.3),
                  ),
                  if (insight.drivers.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    ...insight.drivers
                        .take(2)
                        .map(
                          (driver) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              '• $driver',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ),
          if (snapshot.equipmentMatches.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Matching tools in your fleet',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(
                  Colors.deepPurple.shade700.withValues(alpha: 0.08),
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
                  DataColumn(label: Text('Tool')),
                  DataColumn(label: Text('Category')),
                  DataColumn(label: Text('Demand')),
                  DataColumn(label: Text('Availability')),
                  DataColumn(label: Text('Recommendation')),
                ],
                rows: snapshot.equipmentMatches
                    .map(
                      (item) => DataRow(
                        cells: [
                          DataCell(Text(item.equipmentName)),
                          DataCell(Text(item.categoryLabel)),
                          DataCell(
                            Text(
                              _levelLabel(item.demandLevel),
                              style: TextStyle(
                                color: _levelColor(item.demandLevel),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              item.isUnderMaintenance
                                  ? 'Under maintenance'
                                  : (item.isAvailable
                                        ? 'Available'
                                        : 'Unavailable'),
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 280),
                              child: Text(
                                item.recommendation,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _LegacySummaryCard extends StatelessWidget {
  final double totalEarnings;
  final int totalTransactions;

  const _LegacySummaryCard({
    required this.totalEarnings,
    required this.totalTransactions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 4),
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
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _reportCurrency.format(totalEarnings),
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

class _SummarySection extends StatelessWidget {
  final OwnerRentalSummary summary;

  const _SummarySection({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _SummaryMetricCard(
          title: 'Total Earnings',
          value: _reportCurrency.format(summary.totalEarnings),
          icon: Icons.payments_rounded,
          accent: lightColorScheme.primary,
        ),
        _SummaryMetricCard(
          title: 'Completed Rentals',
          value: '${summary.completedRentals}',
          icon: Icons.task_alt_rounded,
          accent: Colors.green.shade700,
        ),
        _SummaryMetricCard(
          title: 'Farmers Served',
          value: '${summary.uniqueFarmersServed}',
          icon: Icons.people_alt_rounded,
          accent: Colors.teal.shade700,
        ),
        _SummaryMetricCard(
          title: 'Booked Days',
          value: '${summary.totalBookedDays}',
          icon: Icons.calendar_month_rounded,
          accent: Colors.orange.shade700,
        ),
        _SummaryMetricCard(
          title: 'Estimated Hours',
          value: '${summary.estimatedBookedHours.toStringAsFixed(0)} hrs',
          icon: Icons.schedule_rounded,
          accent: Colors.indigo.shade700,
        ),
        _SummaryMetricCard(
          title: 'Average Rental',
          value: '${summary.averageRentalDurationDays.toStringAsFixed(1)} days',
          icon: Icons.av_timer_rounded,
          accent: Colors.brown.shade700,
        ),
      ],
    );
  }
}

class _SummaryMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;

  const _SummaryMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final tileWidth = width > 820 ? (width - 56) / 3 : (width - 44) / 2;

    return Container(
      width: tileWidth.clamp(150.0, 280.0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.grey.shade900,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsNoteCard extends StatelessWidget {
  final AnalyticsTimeWindow window;

  const _AnalyticsNoteCard({required this.window});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.green.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How this analytics view is calculated',
                  style: TextStyle(
                    color: Colors.green.shade900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Estimated booked hours and utilization follow the current maintenance heuristic: booked days x 24 hours. '
                  'Utilization uses the analysis window ${_reportDate.format(window.start)} to ${_reportDate.format(window.end)} '
                  'and each equipment listing\'s current availability window.',
                  style: TextStyle(color: Colors.green.shade900, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade600, height: 1.3),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SectionEmpty extends StatelessWidget {
  final String message;

  const _SectionEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(message, style: TextStyle(color: Colors.grey.shade600)),
    );
  }
}

class _MaintenanceSnapshotView extends StatelessWidget {
  final OwnerMaintenanceSnapshot snapshot;

  const _MaintenanceSnapshotView({required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MiniStatusCard(
              label: 'In Scope',
              value: '${snapshot.totalOwnedEquipment}',
              color: Colors.blueGrey.shade700,
            ),
            _MiniStatusCard(
              label: 'Available',
              value: '${snapshot.availableCount}',
              color: Colors.green.shade700,
            ),
            _MiniStatusCard(
              label: 'Unavailable',
              value: '${snapshot.unavailableCount}',
              color: Colors.orange.shade700,
            ),
            _MiniStatusCard(
              label: 'Under Maintenance',
              value: '${snapshot.underMaintenanceCount}',
              color: Colors.red.shade700,
            ),
            _MiniStatusCard(
              label: 'Maintenance Due',
              value: '${snapshot.dueCount}',
              color: Colors.deepOrange.shade700,
            ),
            _MiniStatusCard(
              label: 'Upcoming Maintenance',
              value: '${snapshot.upcomingCount}',
              color: Colors.indigo.shade700,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _EquipmentListLine(
          title: 'Due now',
          items: snapshot.dueEquipment,
          emptyLabel: 'No equipment is due for maintenance.',
          color: Colors.deepOrange.shade700,
        ),
        const SizedBox(height: 8),
        _EquipmentListLine(
          title: 'Upcoming',
          items: snapshot.upcomingEquipment,
          emptyLabel: 'No equipment is approaching the maintenance threshold.',
          color: Colors.indigo.shade700,
        ),
        const SizedBox(height: 8),
        _EquipmentListLine(
          title: 'Currently under maintenance',
          items: snapshot.underMaintenanceEquipment,
          emptyLabel: 'No equipment is currently marked under maintenance.',
          color: Colors.red.shade700,
        ),
      ],
    );
  }
}

class _MiniStatusCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStatusCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 145,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey.shade900,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EquipmentListLine extends StatelessWidget {
  final String title;
  final List<Equipment> items;
  final String emptyLabel;
  final Color color;

  const _EquipmentListLine({
    required this.title,
    required this.items,
    required this.emptyLabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final text = items.isEmpty
        ? emptyLabel
        : items.map((equipment) => equipment.name).join(', ');

    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style.copyWith(height: 1.35),
        children: [
          TextSpan(
            text: '$title: ',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: text,
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _EquipmentPerformanceTable extends StatelessWidget {
  final List<OwnerRentalEquipmentPerformance> items;

  const _EquipmentPerformanceTable({required this.items});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          Colors.green.shade700.withValues(alpha: 0.08),
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
          DataColumn(label: Text('Equipment')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Operator')),
          DataColumn(label: Text('Rentals'), numeric: true),
          DataColumn(label: Text('Farmers'), numeric: true),
          DataColumn(label: Text('Days'), numeric: true),
          DataColumn(label: Text('Est Hours'), numeric: true),
          DataColumn(label: Text('Earnings'), numeric: true),
        ],
        rows: items
            .map(
              (item) => DataRow(
                cells: [
                  DataCell(Text(item.itemName)),
                  DataCell(Text(item.categoryLabel)),
                  DataCell(Text(item.withOperator ? 'Yes' : 'No')),
                  DataCell(Text('${item.completedRentals}')),
                  DataCell(Text('${item.uniqueFarmersServed}')),
                  DataCell(Text('${item.bookedDays}')),
                  DataCell(Text(item.estimatedBookedHours.toStringAsFixed(0))),
                  DataCell(
                    Text(
                      _reportCurrency.format(item.totalEarnings),
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _CategoryPerformanceTable extends StatelessWidget {
  final List<OwnerRentalCategoryPerformance> items;

  const _CategoryPerformanceTable({required this.items});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          Colors.teal.shade700.withValues(alpha: 0.08),
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
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Rentals'), numeric: true),
          DataColumn(label: Text('Farmers'), numeric: true),
          DataColumn(label: Text('Days'), numeric: true),
          DataColumn(label: Text('Est Hours'), numeric: true),
          DataColumn(label: Text('Earnings'), numeric: true),
        ],
        rows: items
            .map(
              (item) => DataRow(
                cells: [
                  DataCell(Text(item.categoryLabel)),
                  DataCell(Text('${item.completedRentals}')),
                  DataCell(Text('${item.uniqueFarmersServed}')),
                  DataCell(Text('${item.bookedDays}')),
                  DataCell(Text(item.estimatedBookedHours.toStringAsFixed(0))),
                  DataCell(
                    Text(
                      _reportCurrency.format(item.totalEarnings),
                      style: TextStyle(
                        color: Colors.teal.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _UtilizationTable extends StatelessWidget {
  final List<OwnerRentalUtilizationItem> items;

  const _UtilizationTable({required this.items});

  String _statusLabel(OwnerRentalUtilizationItem item) {
    if (item.isUnderMaintenance) return 'Under maintenance';
    if (item.isMaintenanceDue) return 'Due';
    if (item.isMaintenanceUpcoming) return 'Upcoming';
    return 'Normal';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          Colors.indigo.shade700.withValues(alpha: 0.08),
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
          DataColumn(label: Text('Equipment')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Operator')),
          DataColumn(label: Text('Booked Hrs'), numeric: true),
          DataColumn(label: Text('Schedulable Hrs'), numeric: true),
          DataColumn(label: Text('Utilization'), numeric: true),
          DataColumn(label: Text('Status')),
        ],
        rows: items
            .map(
              (item) => DataRow(
                cells: [
                  DataCell(Text(item.equipmentName)),
                  DataCell(Text(item.categoryLabel)),
                  DataCell(Text(item.withOperator ? 'Yes' : 'No')),
                  DataCell(Text(item.bookedHours.toStringAsFixed(0))),
                  DataCell(Text(item.schedulableHours.toStringAsFixed(0))),
                  DataCell(
                    Text(
                      '${(item.utilizationRate * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: Colors.indigo.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  DataCell(Text(_statusLabel(item))),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TransactionTable extends StatelessWidget {
  final List<OwnerRentalTransactionRow> rows;

  const _TransactionTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStatePropertyAll(
          Colors.green.shade700.withValues(alpha: 0.08),
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
          DataColumn(label: Text('Price Rate'), numeric: true),
          DataColumn(label: Text('Rate Unit')),
          DataColumn(label: Text('Days Rented')),
          DataColumn(label: Text('Area / Volume')),
          DataColumn(label: Text('Payment'), numeric: true),
        ],
        rows: List.generate(rows.length, (index) {
          final row = rows[index];
          final request = row.request;
          final priceRate = row.equipment == null
              ? '-'
              : _reportCurrency.format(row.equipment!.price);

          return DataRow(
            cells: [
              DataCell(
                Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
              DataCell(Text(_reportDate.format(request.start))),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(request.name, overflow: TextOverflow.ellipsis),
                ),
              ),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    row.farmLocation,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    request.itemName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(
                Text(
                  priceRate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              DataCell(
                Text(
                  request.agreedRentalUnit ?? row.equipment?.rentalUnit ?? '-',
                ),
              ),
              DataCell(
                Text(
                  request.agreedRentalUnit?.toLowerCase().contains('day') ==
                          true
                      ? '${row.daysRented} day${row.daysRented == 1 ? '' : 's'}'
                      : '-',
                ),
              ),
              DataCell(Text(row.measurementDisplay)),
              DataCell(
                Text(
                  row.totalPayment == null
                      ? '-'
                      : _reportCurrency.format(row.totalPayment),
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
    );
  }
}

class _EmptyTransactionsView extends StatelessWidget {
  const _EmptyTransactionsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 12),
          Text(
            'No completed transactions match the current filters.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Try clearing one or more filters to see more completed rentals.',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            textAlign: TextAlign.center,
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
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            const Text(
              'Failed to load report',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
