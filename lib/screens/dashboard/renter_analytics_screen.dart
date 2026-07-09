import 'package:bukidbayan_app/models/renter_analytics_report.dart';
import 'package:bukidbayan_app/services/analytics/renter_analytics_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final NumberFormat _renterAnalyticsCurrency = NumberFormat.currency(
  locale: 'en_PH',
  symbol: 'PHP ',
  decimalDigits: 0,
);
final DateFormat _renterAnalyticsDate = DateFormat('MMM d, yyyy');

class RenterAnalyticsScreen extends StatefulWidget {
  final RenterAnalyticsService? serviceOverride;
  final String? renterIdOverride;

  const RenterAnalyticsScreen({
    super.key,
    this.serviceOverride,
    this.renterIdOverride,
  });

  @override
  State<RenterAnalyticsScreen> createState() => _RenterAnalyticsScreenState();
}

class _RenterAnalyticsScreenState extends State<RenterAnalyticsScreen> {
  RenterAnalyticsService? _service;
  Future<RenterAnalyticsReport>? _future;
  String? _renterId;

  @override
  void initState() {
    super.initState();
    _renterId = widget.renterIdOverride;
    if (_renterId == null) {
      try {
        _renterId = FirebaseAuth.instance.currentUser?.uid;
      } catch (_) {
        _renterId = null;
      }
    }

    if (_renterId != null) {
      _service = widget.serviceOverride ?? RenterAnalyticsService();
      _future = _loadReport();
    }
  }

  Future<RenterAnalyticsReport> _loadReport() {
    return _service!.generateReport(renterId: _renterId!);
  }

  void _reload() {
    if (_renterId == null) return;
    setState(() {
      _future = _loadReport();
    });
  }

  String _formatCurrency(num value) =>
      _renterAnalyticsCurrency.format(value.round());

  String _formatDate(DateTime? value) =>
      value == null ? '-' : _renterAnalyticsDate.format(value);

  Widget _buildMissingUserState() {
    return Scaffold(
      appBar: AppBar(title: const Text('My Rental Analytics')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_off_outlined,
                size: 56,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 14),
              const Text(
                'No signed-in renter account was found.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in first to view your rental analytics.',
                style: TextStyle(color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivacyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: lightColorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: lightColorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_person_outlined, color: lightColorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This report only uses your own rental requests, your own completed-rental spending, and your own weather-risk booking history.',
              style: TextStyle(color: Colors.grey.shade800, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(RenterAnalyticsReport report) {
    final cards = [
      _KpiCard(
        label: 'Total Requests',
        value: report.summary.totalRequests.toString(),
        subtitle: 'All requests you have submitted',
        icon: Icons.list_alt_rounded,
      ),
      _KpiCard(
        label: 'Completed Rentals',
        value: report.summary.completedRentals.toString(),
        subtitle: 'Finished bookings with completed status',
        icon: Icons.check_circle_outline_rounded,
      ),
      _KpiCard(
        label: 'Active Rentals',
        value: report.summary.activeRentals.toString(),
        subtitle:
            '${report.summary.pendingRequests} pending request${report.summary.pendingRequests == 1 ? '' : 's'}',
        icon: Icons.agriculture_rounded,
      ),
      _KpiCard(
        label: 'Total Spending',
        value: _formatCurrency(report.summary.totalSpending),
        subtitle: 'Completed rentals only',
        icon: Icons.payments_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final cardWidth = availableWidth >= 720
            ? (availableWidth - 12) / 2
            : availableWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }

  Widget _buildActivitySection(RenterAnalyticsReport report) {
    return _SectionCard(
      title: 'Request Activity',
      subtitle: 'Status counts from your rental history',
      child: _InfoTable(
        rows: [
          _InfoRow(
            label: 'Total requests',
            value: report.summary.totalRequests.toString(),
          ),
          _InfoRow(
            label: 'Completed rentals',
            value: report.summary.completedRentals.toString(),
          ),
          _InfoRow(
            label: 'Active rentals',
            value: report.summary.activeRentals.toString(),
          ),
          _InfoRow(
            label: 'Pending requests',
            value: report.summary.pendingRequests.toString(),
          ),
          _InfoRow(
            label: 'Cancelled or declined',
            value: report.summary.cancelledOrDeclinedRequests.toString(),
          ),
          _InfoRow(
            label: 'Cancelled requests',
            value: report.summary.cancelledRequests.toString(),
          ),
          _InfoRow(
            label: 'Declined requests',
            value: report.summary.declinedRequests.toString(),
          ),
          _InfoRow(
            label: 'Weather-risk bookings',
            value: report.summary.weatherRiskBookings.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingSection(RenterAnalyticsReport report) {
    return _SectionCard(
      title: 'Spending & Duration',
      subtitle: 'Based on your completed rentals only',
      child: _InfoTable(
        rows: [
          _InfoRow(
            label: 'Total spending',
            value: _formatCurrency(report.summary.totalSpending),
          ),
          _InfoRow(
            label: 'Average rental duration',
            value:
                '${report.summary.averageRentalDurationDays.toStringAsFixed(1)} days',
          ),
          _InfoRow(
            label: 'First request',
            value: _formatDate(report.firstRequestAt),
          ),
          _InfoRow(
            label: 'Latest request',
            value: _formatDate(report.lastRequestAt),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(RenterAnalyticsReport report) {
    return _SectionCard(
      title: 'Most-used Equipment Categories',
      subtitle: 'Ranked by how often you booked each category',
      child: report.categoryUsage.isEmpty
          ? const Text('No category usage data is available yet.')
          : _RenterTableScrollFrame(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 20,
                  headingRowColor: WidgetStateProperty.resolveWith(
                    (_) => lightColorScheme.primary.withValues(alpha: 0.08),
                  ),
                  columns: const [
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Requests'), numeric: true),
                    DataColumn(label: Text('Completed'), numeric: true),
                    DataColumn(label: Text('Spending')),
                  ],
                  rows: report.categoryUsage
                      .map(
                        (item) => DataRow(
                          cells: [
                            DataCell(Text(item.categoryLabel)),
                            DataCell(Text(item.requestCount.toString())),
                            DataCell(Text(item.completedRentals.toString())),
                            DataCell(Text(_formatCurrency(item.totalSpending))),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insights_outlined,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            const Text(
              'No rental analytics yet.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your analytics will appear here after you start sending rental requests.',
              style: TextStyle(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedBody(RenterAnalyticsReport report) {
    if (report.summary.totalRequests == 0) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await _future!;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'My Rental Analytics',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: lightColorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Generated ${_renterAnalyticsDate.format(report.generatedAt)}',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const _RenterPullToRefreshHint(),
          const SizedBox(height: 16),
          _buildPrivacyCard(),
          const SizedBox(height: 16),
          _buildSummaryCards(report),
          const SizedBox(height: 16),
          _buildActivitySection(report),
          const SizedBox(height: 16),
          _buildSpendingSection(report),
          const SizedBox(height: 16),
          _buildCategorySection(report),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_renterId == null) return _buildMissingUserState();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Rental Analytics'),
        backgroundColor: Colors.white,
        foregroundColor: lightColorScheme.primary,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<RenterAnalyticsReport>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 44,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Failed to load your rental analytics.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final report = snapshot.data;
          if (report == null) {
            return const Center(child: Text('No rental analytics available.'));
          }

          return _buildLoadedBody(report);
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({required this.title, required this.child, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(color: Colors.grey.shade700, height: 1.3),
              ),
            ],
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: lightColorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: lightColorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: lightColorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade700, height: 1.25),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RenterPullToRefreshHint extends StatelessWidget {
  const _RenterPullToRefreshHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.swipe_down_rounded, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          'Pull down to refresh your analytics.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _RenterTableScrollFrame extends StatelessWidget {
  final Widget child;

  const _RenterTableScrollFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.swipe_left_alt_rounded,
              size: 16,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              'Swipe horizontally to see more columns.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _InfoRow {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});
}

class _InfoTable extends StatelessWidget {
  final List<_InfoRow> rows;

  const _InfoTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Table(
        border: TableBorder(
          horizontalInside: BorderSide(color: Colors.grey.shade200),
        ),
        columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(3)},
        children: [
          for (var i = 0; i < rows.length; i++)
            TableRow(
              decoration: BoxDecoration(
                color: i.isEven
                    ? lightColorScheme.primary.withValues(alpha: 0.04)
                    : Colors.white,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Text(
                    rows[i].label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Text(rows[i].value),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
