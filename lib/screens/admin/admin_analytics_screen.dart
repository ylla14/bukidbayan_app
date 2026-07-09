import 'package:bukidbayan_app/models/admin_analytics_report.dart';
import 'package:bukidbayan_app/models/demand_forecast.dart';
import 'package:bukidbayan_app/services/analytics/admin_analytics_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final NumberFormat _adminAnalyticsCurrency = NumberFormat.currency(
  locale: 'en_PH',
  symbol: 'PHP ',
  decimalDigits: 0,
);
final DateFormat _adminAnalyticsDate = DateFormat('MMM d, yyyy');
final DateFormat _adminAnalyticsDateTime = DateFormat('MMM d, yyyy • hh:mm a');

class AdminAnalyticsScreen extends StatefulWidget {
  final bool isCoop;
  final AdminAnalyticsService? serviceOverride;

  const AdminAnalyticsScreen({
    super.key,
    this.isCoop = false,
    this.serviceOverride,
  });

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  AdminAnalyticsService? _service;
  AdminAnalyticsTimePreset _preset = AdminAnalyticsTimePreset.allTime;
  Future<AdminAnalyticsReport>? _future;

  @override
  void initState() {
    super.initState();
    if (widget.isCoop) {
      _service = widget.serviceOverride ?? AdminAnalyticsService();
      _future = _loadReport();
    }
  }

  Future<AdminAnalyticsReport> _loadReport() {
    return _service!.generateReport(preset: _preset);
  }

  void _reload() {
    setState(() {
      _future = _loadReport();
    });
  }

  String _formatCurrency(num value) =>
      _adminAnalyticsCurrency.format(value.round());

  String _formatWindow(AdminAnalyticsReport report) {
    final window = report.timeWindow;
    if (window == null) return 'All recorded data';
    return '${_adminAnalyticsDate.format(window.start)} - ${_adminAnalyticsDate.format(window.end)}';
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'No data yet';
    return _adminAnalyticsDateTime.format(value);
  }

  String _formatRate(double value) => '${(value * 100).toStringAsFixed(0)}%';

  String _forecastLevelLabel(DemandForecastLevel level) {
    switch (level) {
      case DemandForecastLevel.high:
        return 'High';
      case DemandForecastLevel.medium:
        return 'Medium';
      case DemandForecastLevel.low:
        return 'Early';
    }
  }

  String _forecastConfidenceLabel(DemandForecastConfidence confidence) {
    switch (confidence) {
      case DemandForecastConfidence.high:
        return 'High';
      case DemandForecastConfidence.medium:
        return 'Medium';
      case DemandForecastConfidence.low:
        return 'Early';
    }
  }

  Widget _buildRestrictedView() {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Analytics')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Restricted Access',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ang admin analytics ay para lamang sa co-op accounts.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    return _SectionCard(
      title: 'Report Window',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<AdminAnalyticsTimePreset>(
            key: const Key('admin_analytics_preset_dropdown'),
            initialValue: _preset,
            decoration: const InputDecoration(
              labelText: 'Activity window',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: AdminAnalyticsTimePreset.values
                .map(
                  (preset) => DropdownMenuItem(
                    value: preset,
                    child: Text(preset.label),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null || value == _preset) return;
              setState(() {
                _preset = value;
                _future = _loadReport();
              });
            },
          ),
          const SizedBox(height: 12),
          Text(
            _preset.helperText,
            style: TextStyle(color: Colors.grey.shade700, height: 1.35),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: lightColorScheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: lightColorScheme.primary.withValues(alpha: 0.18),
              ),
            ),
            child: Text(
              'Current snapshot metrics ignore the selected window: equipment availability, active rentals, live campaigns, blocked renters, and weather-risk bookings. Window-scoped totals use request dates, pledge dates, and paid-attempt completion dates.',
              style: TextStyle(color: Colors.grey.shade800, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(AdminAnalyticsReport report) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _KpiCard(
          label: 'Registered Users',
          value: report.platform.totalUsers.toString(),
          subtitle: report.platform.coopAccounts == 0
              ? 'Member accounts'
              : '${report.platform.coopAccounts} co-op account${report.platform.coopAccounts == 1 ? '' : 's'} excluded from member count',
          icon: Icons.people_alt_outlined,
        ),
        _KpiCard(
          label: 'Listed Equipment',
          value: report.platform.totalEquipment.toString(),
          subtitle: '${report.platform.availableEquipment} available now',
          icon: Icons.agriculture_outlined,
        ),
        _KpiCard(
          label: 'Active Rentals',
          value: report.rentals.activeRentals.toString(),
          subtitle: '${report.rentals.pendingRentals} pending requests',
          icon: Icons.swap_horiz_outlined,
        ),
        _KpiCard(
          label: 'Paid Amount',
          value: _formatCurrency(report.crowdfunding.totalPaidAmount),
          subtitle: 'Within ${report.preset.label.toLowerCase()}',
          icon: Icons.payments_outlined,
        ),
      ],
    );
  }

  Widget _buildPlatformSection(AdminAnalyticsReport report) {
    return _SectionCard(
      title: 'Platform Overview',
      subtitle: 'Current inventory and account footprint',
      child: _InfoTable(
        rows: [
          _InfoRow(
            label: 'Registered users',
            value: report.platform.totalUsers.toString(),
          ),
          _InfoRow(
            label: 'New users in selected window',
            value: report.platform.newUsersInWindow.toString(),
          ),
          _InfoRow(
            label: 'Co-op admin accounts',
            value: report.platform.coopAccounts.toString(),
          ),
          _InfoRow(
            label: 'Listed equipment',
            value: report.platform.totalEquipment.toString(),
          ),
          _InfoRow(
            label: 'New equipment in selected window',
            value: report.platform.newEquipmentInWindow.toString(),
          ),
          _InfoRow(
            label: 'Participating equipment owners',
            value: report.platform.equipmentOwners.toString(),
          ),
          _InfoRow(
            label: 'Equipment availability snapshot',
            value:
                '${report.platform.availableEquipment} available, ${report.platform.unavailableEquipment} unavailable, ${report.platform.underMaintenanceEquipment} under maintenance',
          ),
        ],
      ),
    );
  }

  Widget _buildRentalsSection(AdminAnalyticsReport report) {
    return _SectionCard(
      title: 'Rental Operations',
      subtitle: 'Window-scoped activity plus current operational load',
      child: _InfoTable(
        rows: [
          _InfoRow(
            label: 'Active rentals',
            value: report.rentals.activeRentals.toString(),
          ),
          _InfoRow(
            label: 'Pending rental requests',
            value: report.rentals.pendingRentals.toString(),
          ),
          _InfoRow(
            label: 'Completed rentals in selected window',
            value: report.rentals.completedRentals.toString(),
          ),
          _InfoRow(
            label: 'Unique farmers served in selected window',
            value: report.rentals.uniqueFarmersServed.toString(),
          ),
          _InfoRow(
            label: 'Completed rental value in selected window',
            value: _formatCurrency(report.rentals.completedRentalValue),
          ),
          _InfoRow(
            label: 'Weather-risk bookings right now',
            value: report.rentals.weatherRiskBookings.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildDemandSection(AdminAnalyticsReport report) {
    return _SectionCard(
      title: 'Demand Proxy by Category',
      subtitle: 'Based on non-cancelled request volume in the selected window',
      child: report.topDemandCategories.isEmpty
          ? const Text('No category demand data is available for this window.')
          : SingleChildScrollView(
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
                  DataColumn(label: Text('Unique Farmers'), numeric: true),
                  DataColumn(label: Text('Completion Rate')),
                ],
                rows: report.topDemandCategories
                    .map(
                      (item) => DataRow(
                        cells: [
                          DataCell(Text(item.categoryLabel)),
                          DataCell(Text(item.requestCount.toString())),
                          DataCell(Text(item.completedRequestCount.toString())),
                          DataCell(Text(item.uniqueRenters.toString())),
                          DataCell(
                            Text(
                              '${(item.completionRate * 100).toStringAsFixed(0)}%',
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }

  Widget _buildForecastSection(AdminAnalyticsReport report) {
    final forecasting = report.forecasting;

    return _SectionCard(
      title: 'Demand Forecast Hotspots',
      subtitle:
          'Location-aware weekly outlook based on request history, booking geography, and forecast inputs',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoTable(
            rows: [
              _InfoRow(
                label: 'Requests with usable forecast location',
                value: forecasting.requestsWithForecastLocation.toString(),
              ),
              _InfoRow(
                label: 'Requests with location + forecast inputs',
                value:
                    '${forecasting.requestsWithForecastInputsAndLocation} (${_formatRate(forecasting.locationCoverageRate)})',
              ),
              _InfoRow(
                label: 'Locations analyzed',
                value: forecasting.locationsAnalyzed.toString(),
              ),
              _InfoRow(
                label: 'Hotspots detected',
                value:
                    '${forecasting.hotspotCount} total, ${forecasting.highDemandHotspots} high demand, ${forecasting.highConfidenceHotspots} high confidence',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (forecasting.hotspots.isEmpty)
            const Text(
              'No location-level forecast hotspots are available yet for this window.',
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 20,
                headingRowColor: WidgetStateProperty.resolveWith(
                  (_) => lightColorScheme.primary.withValues(alpha: 0.08),
                ),
                columns: const [
                  DataColumn(label: Text('Location')),
                  DataColumn(label: Text('Forecast Category')),
                  DataColumn(label: Text('Demand')),
                  DataColumn(label: Text('Confidence')),
                  DataColumn(label: Text('Matched Requests'), numeric: true),
                  DataColumn(label: Text('Recent Requests'), numeric: true),
                ],
                rows: forecasting.hotspots
                    .map(
                      (item) => DataRow(
                        cells: [
                          DataCell(Text(item.locationLabel)),
                          DataCell(Text(item.equipmentCategory)),
                          DataCell(Text(_forecastLevelLabel(item.demandLevel))),
                          DataCell(
                            Text(_forecastConfidenceLabel(item.confidence)),
                          ),
                          DataCell(Text(item.matchedRequests.toString())),
                          DataCell(Text(item.recentRequests.toString())),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          if (forecasting.hotspots.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...forecasting.hotspots
                .take(3)
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${item.locationLabel}: ${item.summary}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _buildSystemHealthSection(AdminAnalyticsReport report) {
    final systemHealth = report.systemHealth;
    final backgroundTaskSummary = systemHealth.lastBackgroundTaskName == null
        ? 'No background task recorded yet'
        : '${systemHealth.lastBackgroundTaskName} (${systemHealth.lastBackgroundTaskStatus ?? 'unknown'})';

    return _SectionCard(
      title: 'System Health',
      subtitle:
          'Latest heartbeat plus telemetry activity in the selected window',
      child: _InfoTable(
        rows: [
          _InfoRow(
            label: 'Current system status',
            value: systemHealth.currentStatus,
          ),
          _InfoRow(
            label: 'Last heartbeat',
            value:
                '${_formatDateTime(systemHealth.lastHeartbeatAt)}${systemHealth.lastHeartbeatSource == null ? '' : ' • ${systemHealth.lastHeartbeatSource}'}',
          ),
          _InfoRow(
            label: 'Last app open captured',
            value: _formatDateTime(systemHealth.lastAppOpenAt),
          ),
          _InfoRow(
            label: 'Last background task result',
            value:
                '$backgroundTaskSummary • ${_formatDateTime(systemHealth.lastBackgroundTaskAt)}',
          ),
          _InfoRow(
            label: 'Telemetry events in selected window',
            value: systemHealth.telemetryEventsInWindow.toString(),
          ),
          _InfoRow(
            label: 'App opens in selected window',
            value: systemHealth.appOpensInWindow.toString(),
          ),
          _InfoRow(
            label: 'Heartbeat events in selected window',
            value: systemHealth.heartbeatEventsInWindow.toString(),
          ),
          _InfoRow(
            label: 'Login failures in selected window',
            value: systemHealth.loginFailuresInWindow.toString(),
          ),
          _InfoRow(
            label: 'Background-task failures in selected window',
            value: systemHealth.backgroundTaskFailuresInWindow.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildDataReadinessSection(AdminAnalyticsReport report) {
    final dataReadiness = report.dataReadiness;

    return _SectionCard(
      title: 'Data Readiness',
      subtitle:
          'How much of the platform already has the new V2 analytics inputs',
      child: _InfoTable(
        rows: [
          _InfoRow(
            label: 'Member profiles with normalized geography',
            value:
                '${dataReadiness.memberProfilesWithGeography}/${dataReadiness.totalMemberProfiles} (${_formatRate(dataReadiness.memberProfileCoverageRate)})',
          ),
          _InfoRow(
            label: 'Equipment with normalized geography',
            value:
                '${dataReadiness.equipmentWithGeography}/${dataReadiness.totalEquipment} (${_formatRate(dataReadiness.equipmentGeographyCoverageRate)})',
          ),
          _InfoRow(
            label: 'Requests with normalized geography',
            value:
                '${dataReadiness.requestsWithNormalizedGeography}/${dataReadiness.totalRequests} (${_formatRate(dataReadiness.requestGeographyCoverageRate)})',
          ),
          _InfoRow(
            label: 'Requests with forecast inputs',
            value:
                '${dataReadiness.requestsWithForecastInputs}/${dataReadiness.totalRequests} (${_formatRate(dataReadiness.forecastInputCoverageRate)})',
          ),
          _InfoRow(
            label: 'Requests with status-history logs',
            value:
                '${dataReadiness.requestsWithStatusHistory}/${dataReadiness.totalRequests} (${_formatRate(dataReadiness.requestHistoryCoverageRate)})',
          ),
          _InfoRow(
            label: 'Requests with timeline events',
            value:
                '${dataReadiness.requestsWithTimelineEvents}/${dataReadiness.totalRequests} (${_formatRate(dataReadiness.requestTimelineCoverageRate)})',
          ),
          _InfoRow(
            label: 'Equipment with maintenance logs',
            value:
                '${dataReadiness.equipmentWithMaintenanceLogs}/${dataReadiness.totalEquipment} (${_formatRate(dataReadiness.maintenanceLogCoverageRate)})',
          ),
          _InfoRow(
            label: 'Maintenance log entries recorded',
            value: dataReadiness.maintenanceLogEntries.toString(),
          ),
          _InfoRow(
            label: 'Commercial benchmark rows available',
            value: dataReadiness.benchmarkRows.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildCrowdfundingSection(AdminAnalyticsReport report) {
    return _SectionCard(
      title: 'Crowdfunding Overview',
      subtitle: 'Pledged totals and paid checkout totals are kept separate',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoTable(
            rows: [
              _InfoRow(
                label: 'Live campaigns right now',
                value: report.crowdfunding.liveCampaigns.toString(),
              ),
              _InfoRow(
                label: 'Campaigns launched in selected window',
                value: report.crowdfunding.campaignsCreatedInWindow.toString(),
              ),
              _InfoRow(
                label: 'Pledges in selected window',
                value: report.crowdfunding.totalPledges.toString(),
              ),
              _InfoRow(
                label: 'Total pledged amount',
                value: _formatCurrency(report.crowdfunding.totalPledgedAmount),
              ),
              _InfoRow(
                label: 'Total paid amount',
                value: _formatCurrency(report.crowdfunding.totalPaidAmount),
              ),
              _InfoRow(
                label: 'Unique supporters in selected window',
                value: report.crowdfunding.uniqueSupporters.toString(),
              ),
              _InfoRow(
                label: 'Paid checkout attempts',
                value: report.crowdfunding.paidAttempts.toString(),
              ),
              _InfoRow(
                label: 'Failed checkout attempts',
                value: report.crowdfunding.failedAttempts.toString(),
              ),
              _InfoRow(
                label: 'Expired checkout attempts',
                value: report.crowdfunding.expiredAttempts.toString(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Paid totals use payment-attempt records. Older campaign data without checkout attempts may still appear in pledged totals but not in paid totals.',
            style: TextStyle(color: Colors.grey.shade700, height: 1.35),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchlistSection(AdminAnalyticsReport report) {
    return _SectionCard(
      title: 'Risk & Watchlist',
      subtitle: 'Current issues that may need co-op attention',
      child: _InfoTable(
        rows: [
          _InfoRow(
            label: 'Blocked renters right now',
            value: report.watchlist.blockedRenters.toString(),
          ),
          _InfoRow(
            label: 'Equipment under maintenance',
            value: report.watchlist.underMaintenanceEquipment.toString(),
          ),
          _InfoRow(
            label: 'Weather-risk bookings right now',
            value: report.watchlist.weatherRiskBookings.toString(),
          ),
          _InfoRow(
            label: 'Pending rental requests',
            value: report.watchlist.pendingRentals.toString(),
          ),
          _InfoRow(
            label: 'Failed payment attempts in selected window',
            value: report.watchlist.failedPaymentAttempts.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactSection(AdminAnalyticsReport report) {
    return _SectionCard(
      title: 'Impact Summary',
      subtitle: 'All-time reach across current platform records',
      child: _InfoTable(
        rows: [
          _InfoRow(
            label: 'Total farmers served',
            value: report.impact.totalFarmersServed.toString(),
          ),
          _InfoRow(
            label: 'Participating equipment owners',
            value: report.impact.totalEquipmentOwners.toString(),
          ),
          _InfoRow(
            label: 'Total campaign supporters',
            value: report.impact.totalCampaignSupporters.toString(),
          ),
          _InfoRow(
            label: 'Completed rentals all-time',
            value: report.impact.totalCompletedRentals.toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadedBody(AdminAnalyticsReport report) {
    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await _future!;
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Admin Analytics',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: lightColorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Generated ${_adminAnalyticsDate.format(report.generatedAt)} • Window: ${_formatWindow(report)}',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildFilterCard(),
          const SizedBox(height: 16),
          _buildSummaryCards(report),
          const SizedBox(height: 16),
          _buildPlatformSection(report),
          const SizedBox(height: 16),
          _buildSystemHealthSection(report),
          const SizedBox(height: 16),
          _buildRentalsSection(report),
          const SizedBox(height: 16),
          _buildDemandSection(report),
          const SizedBox(height: 16),
          _buildForecastSection(report),
          const SizedBox(height: 16),
          _buildCrowdfundingSection(report),
          const SizedBox(height: 16),
          _buildWatchlistSection(report),
          const SizedBox(height: 16),
          _buildDataReadinessSection(report),
          const SizedBox(height: 16),
          _buildImpactSection(report),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCoop) return _buildRestrictedView();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Analytics'),
        backgroundColor: Colors.white,
        foregroundColor: lightColorScheme.primary,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<AdminAnalyticsReport>(
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
                      'Failed to load admin analytics.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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
            return const Center(child: Text('No admin analytics available.'));
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
      width: 240,
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
          Icon(icon, color: lightColorScheme.primary),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: lightColorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade700, height: 1.25),
          ),
        ],
      ),
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
