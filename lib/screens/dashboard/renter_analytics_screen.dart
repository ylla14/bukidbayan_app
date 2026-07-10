import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/models/renter_analytics_report.dart';
import 'package:bukidbayan_app/screens/dashboard/rentals_list.dart';
import 'package:bukidbayan_app/screens/rent/request_sent.dart';
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
final DateFormat _renterAnalyticsDateTime = DateFormat('MMM d, yyyy - hh:mm a');

enum _RenterRequestBucket {
  waitingReview,
  confirmedUpcoming,
  inUse,
  closingOut,
  confirmedAndActive,
  completed,
  cancelled,
  declined,
  weatherRisk,
}

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
  static const Set<RentRequestStatus> _confirmedUpcomingStatuses = {
    RentRequestStatus.approved,
    RentRequestStatus.readyForPickup,
    RentRequestStatus.onTheWay,
  };

  static const Set<RentRequestStatus> _inUseStatuses = {
    RentRequestStatus.pickedUp,
    RentRequestStatus.inProgress,
  };

  static const Set<RentRequestStatus> _closingStatuses = {
    RentRequestStatus.retrieving,
    RentRequestStatus.returned,
    RentRequestStatus.finished,
  };

  static const Set<RentRequestStatus> _confirmedAndActiveStatuses = {
    ..._confirmedUpcomingStatuses,
    ..._inUseStatuses,
    ..._closingStatuses,
  };

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

  String _formatCountLabel(int count) =>
      '$count request${count == 1 ? '' : 's'}';

  String _formatDateRange(RentRequest request) {
    return '${_renterAnalyticsDate.format(request.start)} - ${_renterAnalyticsDate.format(request.end)}';
  }

  double _requestValue(RentRequest request) {
    if (request.agreedPrice != null) return request.agreedPrice!;
    if (request.estimatedMillingFee != null) {
      return request.estimatedMillingFee!;
    }
    return 0;
  }

  Color _statusColor(RentRequestStatus status) {
    switch (status) {
      case RentRequestStatus.pending:
        return const Color(0xFFF59E0B);
      case RentRequestStatus.approved:
        return const Color(0xFF2563EB);
      case RentRequestStatus.readyForPickup:
      case RentRequestStatus.onTheWay:
        return const Color(0xFFEA580C);
      case RentRequestStatus.pickedUp:
      case RentRequestStatus.inProgress:
        return lightColorScheme.primary;
      case RentRequestStatus.retrieving:
      case RentRequestStatus.returned:
      case RentRequestStatus.finished:
        return const Color(0xFF0F766E);
      case RentRequestStatus.completed:
        return const Color(0xFF15803D);
      case RentRequestStatus.declined:
      case RentRequestStatus.canceled:
        return lightColorScheme.error;
    }
  }

  String _statusLabel(RentRequestStatus status) {
    switch (status) {
      case RentRequestStatus.readyForPickup:
        return 'Ready for pick up';
      case RentRequestStatus.pickedUp:
        return 'Picked up';
      case RentRequestStatus.onTheWay:
        return 'On the way';
      case RentRequestStatus.inProgress:
        return 'In progress';
      default:
        final raw = status.name;
        return raw[0].toUpperCase() + raw.substring(1);
    }
  }

  IconData _statusIcon(RentRequestStatus status) {
    switch (status) {
      case RentRequestStatus.pending:
        return Icons.hourglass_top_rounded;
      case RentRequestStatus.approved:
        return Icons.check_circle_outline_rounded;
      case RentRequestStatus.readyForPickup:
        return Icons.storefront_outlined;
      case RentRequestStatus.pickedUp:
        return Icons.backpack_outlined;
      case RentRequestStatus.onTheWay:
        return Icons.local_shipping_outlined;
      case RentRequestStatus.inProgress:
        return Icons.agriculture_rounded;
      case RentRequestStatus.retrieving:
        return Icons.assignment_return_outlined;
      case RentRequestStatus.returned:
        return Icons.inventory_2_outlined;
      case RentRequestStatus.finished:
        return Icons.task_alt_outlined;
      case RentRequestStatus.completed:
        return Icons.verified_outlined;
      case RentRequestStatus.declined:
        return Icons.cancel_outlined;
      case RentRequestStatus.canceled:
        return Icons.remove_circle_outline_rounded;
    }
  }

  String _bucketLabel(_RenterRequestBucket bucket) {
    switch (bucket) {
      case _RenterRequestBucket.waitingReview:
        return 'Waiting for review';
      case _RenterRequestBucket.confirmedUpcoming:
        return 'Confirmed booking';
      case _RenterRequestBucket.inUse:
        return 'Equipment in use';
      case _RenterRequestBucket.closingOut:
        return 'Return & closeout';
      case _RenterRequestBucket.confirmedAndActive:
        return 'Confirmed & active';
      case _RenterRequestBucket.completed:
        return 'Completed rentals';
      case _RenterRequestBucket.cancelled:
        return 'Cancelled requests';
      case _RenterRequestBucket.declined:
        return 'Declined requests';
      case _RenterRequestBucket.weatherRisk:
        return 'Weather-risk bookings';
    }
  }

  String _bucketDescription(_RenterRequestBucket bucket) {
    switch (bucket) {
      case _RenterRequestBucket.waitingReview:
        return 'Pending requests that still need an owner decision.';
      case _RenterRequestBucket.confirmedUpcoming:
        return 'Approved requests that are being prepared for pickup or delivery.';
      case _RenterRequestBucket.inUse:
        return 'Rentals that are currently picked up or actively in progress.';
      case _RenterRequestBucket.closingOut:
        return 'Rentals that are being returned or waiting for final closeout.';
      case _RenterRequestBucket.confirmedAndActive:
        return 'Everything from approved bookings through final wrap-up.';
      case _RenterRequestBucket.completed:
        return 'Finished rentals that were fully completed.';
      case _RenterRequestBucket.cancelled:
        return 'Requests that were cancelled before completion.';
      case _RenterRequestBucket.declined:
        return 'Requests that owners declined.';
      case _RenterRequestBucket.weatherRisk:
        return 'Requests that were flagged by the weather monitor.';
    }
  }

  IconData _bucketIcon(_RenterRequestBucket bucket) {
    switch (bucket) {
      case _RenterRequestBucket.waitingReview:
        return Icons.hourglass_top_rounded;
      case _RenterRequestBucket.confirmedUpcoming:
        return Icons.event_available_outlined;
      case _RenterRequestBucket.inUse:
        return Icons.agriculture_rounded;
      case _RenterRequestBucket.closingOut:
        return Icons.assignment_return_outlined;
      case _RenterRequestBucket.confirmedAndActive:
        return Icons.swap_horiz_outlined;
      case _RenterRequestBucket.completed:
        return Icons.verified_outlined;
      case _RenterRequestBucket.cancelled:
        return Icons.block_outlined;
      case _RenterRequestBucket.declined:
        return Icons.cancel_outlined;
      case _RenterRequestBucket.weatherRisk:
        return Icons.cloud_outlined;
    }
  }

  Color _bucketColor(_RenterRequestBucket bucket) {
    switch (bucket) {
      case _RenterRequestBucket.waitingReview:
        return const Color(0xFFF59E0B);
      case _RenterRequestBucket.confirmedUpcoming:
        return const Color(0xFF2563EB);
      case _RenterRequestBucket.inUse:
        return lightColorScheme.primary;
      case _RenterRequestBucket.closingOut:
        return const Color(0xFF0F766E);
      case _RenterRequestBucket.confirmedAndActive:
        return const Color(0xFF1D4ED8);
      case _RenterRequestBucket.completed:
        return const Color(0xFF15803D);
      case _RenterRequestBucket.cancelled:
      case _RenterRequestBucket.declined:
        return lightColorScheme.error;
      case _RenterRequestBucket.weatherRisk:
        return const Color(0xFFD97706);
    }
  }

  List<RentRequest> _sortedRequests(Iterable<RentRequest> requests) {
    final items = requests.toList();
    items.sort((a, b) {
      final aDate = a.createdAt ?? a.start;
      final bDate = b.createdAt ?? b.start;
      final dateCompare = bDate.compareTo(aDate);
      if (dateCompare != 0) return dateCompare;
      return b.requestId.compareTo(a.requestId);
    });
    return items;
  }

  List<RentRequest> _requestsForBucket(
    RenterAnalyticsReport report,
    _RenterRequestBucket bucket,
  ) {
    switch (bucket) {
      case _RenterRequestBucket.waitingReview:
        return _sortedRequests(
          report.requests.where(
            (request) => request.status == RentRequestStatus.pending,
          ),
        );
      case _RenterRequestBucket.confirmedUpcoming:
        return _sortedRequests(
          report.requests.where(
            (request) => _confirmedUpcomingStatuses.contains(request.status),
          ),
        );
      case _RenterRequestBucket.inUse:
        return _sortedRequests(
          report.requests.where(
            (request) => _inUseStatuses.contains(request.status),
          ),
        );
      case _RenterRequestBucket.closingOut:
        return _sortedRequests(
          report.requests.where(
            (request) => _closingStatuses.contains(request.status),
          ),
        );
      case _RenterRequestBucket.confirmedAndActive:
        return _sortedRequests(
          report.requests.where(
            (request) => _confirmedAndActiveStatuses.contains(request.status),
          ),
        );
      case _RenterRequestBucket.completed:
        return _sortedRequests(
          report.requests.where(
            (request) => request.status == RentRequestStatus.completed,
          ),
        );
      case _RenterRequestBucket.cancelled:
        return _sortedRequests(
          report.requests.where(
            (request) => request.status == RentRequestStatus.canceled,
          ),
        );
      case _RenterRequestBucket.declined:
        return _sortedRequests(
          report.requests.where(
            (request) => request.status == RentRequestStatus.declined,
          ),
        );
      case _RenterRequestBucket.weatherRisk:
        return _sortedRequests(
          report.requests.where((request) => request.weatherFlag),
        );
    }
  }

  int _bucketCount(RenterAnalyticsReport report, _RenterRequestBucket bucket) {
    return _requestsForBucket(report, bucket).length;
  }

  String _confirmedAndActiveSubtitle(RenterAnalyticsReport report) {
    final parts = <String>[];
    final upcoming = _bucketCount(
      report,
      _RenterRequestBucket.confirmedUpcoming,
    );
    final inUse = _bucketCount(report, _RenterRequestBucket.inUse);
    final closing = _bucketCount(report, _RenterRequestBucket.closingOut);
    if (upcoming > 0) parts.add('$upcoming upcoming');
    if (inUse > 0) parts.add('$inUse in use');
    if (closing > 0) parts.add('$closing closing out');
    if (parts.isEmpty) {
      return 'Approved bookings through final wrap-up';
    }
    return parts.join(', ');
  }

  void _openRequestDetails(RentRequest request) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RequestSentPage(requestId: request.requestId),
      ),
    );
  }

  void _openMyRequestsList() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const RentalsList(mode: RentalsListMode.myRequests),
      ),
    );
  }

  void _showDrillDownSheet(
    RenterAnalyticsReport report,
    _RenterRequestBucket bucket,
  ) {
    final requests = _requestsForBucket(report, bucket);
    final bucketColor = _bucketColor(bucket);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.94,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: bucketColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(_bucketIcon(bucket), color: bucketColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _bucketLabel(bucket),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatCountLabel(requests.length),
                                style: TextStyle(
                                  color: bucketColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _bucketDescription(bucket),
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(color: Colors.grey.shade200, height: 1),
                  Expanded(
                    child: requests.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'There are no requests in this stage right now.',
                                style: TextStyle(color: Colors.grey.shade700),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                            itemBuilder: (_, index) {
                              final request = requests[index];
                              return _RequestPreviewCard(
                                request: request,
                                amountLabel: _requestValue(request) > 0
                                    ? _formatCurrency(_requestValue(request))
                                    : null,
                                onTap: () {
                                  Navigator.of(sheetContext).pop();
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (!mounted) return;
                                    _openRequestDetails(request);
                                  });
                                },
                                statusLabel: _statusLabel(request.status),
                                statusColor: _statusColor(request.status),
                                statusIcon: _statusIcon(request.status),
                                dateRangeLabel: _formatDateRange(request),
                                submittedAtLabel: request.createdAt == null
                                    ? null
                                    : _renterAnalyticsDateTime.format(
                                        request.createdAt!,
                                      ),
                              );
                            },
                            separatorBuilder: (_, index) =>
                                const SizedBox(height: 12),
                            itemCount: requests.length,
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

  Widget _buildGuideCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightColorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: lightColorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to read this page',
            style: TextStyle(
              color: lightColorScheme.primary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _GuidePoint(
            icon: Icons.lock_person_outlined,
            text:
                'Only your own rental requests, completed-rental spending, and weather-risk flags are included.',
          ),
          const SizedBox(height: 10),
          const _GuidePoint(
            icon: Icons.insights_outlined,
            text:
                'Waiting for review only means pending approval. Confirmed & active covers approved bookings, delivery steps, in-progress rentals, and closeout steps.',
          ),
          const SizedBox(height: 10),
          const _GuidePoint(
            icon: Icons.touch_app_outlined,
            text:
                'Tap any stage with activity to drill down into the matching requests and open full request details.',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(RenterAnalyticsReport report) {
    final completedCount = report.summary.completedRentals;
    final cards = [
      _KpiCard(
        key: const Key('renter_analytics_summary_waiting_review'),
        label: 'Waiting for Review',
        value: report.summary.pendingRequests.toString(),
        subtitle: 'Still pending owner approval',
        icon: Icons.hourglass_top_rounded,
        onTap: report.summary.pendingRequests == 0
            ? null
            : () => _showDrillDownSheet(
                report,
                _RenterRequestBucket.waitingReview,
              ),
      ),
      _KpiCard(
        key: const Key('renter_analytics_summary_confirmed_active'),
        label: 'Confirmed & Active',
        value: report.summary.activeRentals.toString(),
        subtitle: _confirmedAndActiveSubtitle(report),
        icon: Icons.swap_horiz_outlined,
        onTap: report.summary.activeRentals == 0
            ? null
            : () => _showDrillDownSheet(
                report,
                _RenterRequestBucket.confirmedAndActive,
              ),
      ),
      _KpiCard(
        key: const Key('renter_analytics_summary_completed'),
        label: 'Completed Rentals',
        value: completedCount.toString(),
        subtitle: 'Finished and marked complete',
        icon: Icons.verified_outlined,
        onTap: completedCount == 0
            ? null
            : () => _showDrillDownSheet(report, _RenterRequestBucket.completed),
      ),
      _KpiCard(
        key: const Key('renter_analytics_summary_spending'),
        label: 'Total Spending',
        value: _formatCurrency(report.summary.totalSpending),
        subtitle:
            'From $completedCount completed rental${completedCount == 1 ? '' : 's'}',
        icon: Icons.payments_outlined,
        onTap: completedCount == 0
            ? null
            : () => _showDrillDownSheet(report, _RenterRequestBucket.completed),
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

  Widget _buildJourneySection(RenterAnalyticsReport report) {
    Widget stageTile({
      required Key key,
      required String label,
      required String subtitle,
      required _RenterRequestBucket bucket,
    }) {
      final count = _bucketCount(report, bucket);
      return _StageTile(
        key: key,
        label: label,
        subtitle: subtitle,
        count: count,
        icon: _bucketIcon(bucket),
        color: _bucketColor(bucket),
        onTap: count == 0 ? null : () => _showDrillDownSheet(report, bucket),
      );
    }

    return _SectionCard(
      title: 'Request Journey',
      subtitle:
          'Each request belongs to one stage below, so the counts do not overlap.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Open now',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          stageTile(
            key: const Key('renter_analytics_stage_waiting_review'),
            label: 'Waiting for review',
            subtitle: 'Pending requests that still need an owner decision',
            bucket: _RenterRequestBucket.waitingReview,
          ),
          const SizedBox(height: 10),
          stageTile(
            key: const Key('renter_analytics_stage_confirmed_booking'),
            label: 'Confirmed booking',
            subtitle: 'Approved, ready for pickup, or already on the way',
            bucket: _RenterRequestBucket.confirmedUpcoming,
          ),
          const SizedBox(height: 10),
          stageTile(
            key: const Key('renter_analytics_stage_in_use'),
            label: 'Equipment in use',
            subtitle: 'Picked up or currently being used',
            bucket: _RenterRequestBucket.inUse,
          ),
          const SizedBox(height: 10),
          stageTile(
            key: const Key('renter_analytics_stage_closing_out'),
            label: 'Return & closeout',
            subtitle: 'Returning, returned, or waiting for final completion',
            bucket: _RenterRequestBucket.closingOut,
          ),
          const SizedBox(height: 18),
          Text(
            'Closed',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          stageTile(
            key: const Key('renter_analytics_stage_completed'),
            label: 'Completed rentals',
            subtitle: 'Finished rentals that were fully completed',
            bucket: _RenterRequestBucket.completed,
          ),
          const SizedBox(height: 10),
          stageTile(
            key: const Key('renter_analytics_stage_cancelled'),
            label: 'Cancelled requests',
            subtitle: 'Requests that were cancelled before completion',
            bucket: _RenterRequestBucket.cancelled,
          ),
          const SizedBox(height: 10),
          stageTile(
            key: const Key('renter_analytics_stage_declined'),
            label: 'Declined requests',
            subtitle: 'Requests that owners declined',
            bucket: _RenterRequestBucket.declined,
          ),
          if (report.summary.weatherRiskBookings > 0) ...[
            const SizedBox(height: 18),
            Text(
              'Watchlist',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),
            stageTile(
              key: const Key('renter_analytics_stage_weather_risk'),
              label: 'Weather-risk bookings',
              subtitle: 'Requests that were flagged by the weather monitor',
              bucket: _RenterRequestBucket.weatherRisk,
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _openMyRequestsList,
              icon: const Icon(Icons.list_alt_rounded),
              label: const Text('Open My Requests'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRequestsSection(RenterAnalyticsReport report) {
    final recentRequests = _sortedRequests(report.requests).take(5).toList();

    return _SectionCard(
      title: 'Recent Requests',
      subtitle: 'Newest first. Tap a request to open the full request page.',
      child: Column(
        children: [
          for (var i = 0; i < recentRequests.length; i++) ...[
            _RequestPreviewCard(
              key: Key(
                'renter_analytics_recent_request_${recentRequests[i].requestId}',
              ),
              request: recentRequests[i],
              amountLabel: _requestValue(recentRequests[i]) > 0
                  ? _formatCurrency(_requestValue(recentRequests[i]))
                  : null,
              onTap: () => _openRequestDetails(recentRequests[i]),
              statusLabel: _statusLabel(recentRequests[i].status),
              statusColor: _statusColor(recentRequests[i].status),
              statusIcon: _statusIcon(recentRequests[i].status),
              dateRangeLabel: _formatDateRange(recentRequests[i]),
              submittedAtLabel: recentRequests[i].createdAt == null
                  ? null
                  : _renterAnalyticsDateTime.format(
                      recentRequests[i].createdAt!,
                    ),
            ),
            if (i != recentRequests.length - 1) const SizedBox(height: 12),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _openMyRequestsList,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('View all rental requests'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpendingSection(RenterAnalyticsReport report) {
    return _SectionCard(
      title: 'Spending & Timing',
      subtitle: 'Spending totals only use completed rentals',
      child: _InfoTable(
        rows: [
          _InfoRow(
            label: 'Total requests',
            value: report.summary.totalRequests.toString(),
          ),
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
      subtitle: 'Ranked by how often you requested each category',
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
            'Generated ${_renterAnalyticsDate.format(report.generatedAt)} | ${_formatCountLabel(report.summary.totalRequests)}',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const _RenterPullToRefreshHint(),
          const SizedBox(height: 16),
          _buildGuideCard(),
          const SizedBox(height: 16),
          _buildSummaryCards(report),
          const SizedBox(height: 16),
          _buildJourneySection(report),
          const SizedBox(height: 16),
          _buildRecentRequestsSection(report),
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

class _GuidePoint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _GuidePoint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: lightColorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey.shade800, height: 1.35),
          ),
        ),
      ],
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
  final VoidCallback? onTap;

  const _KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: lightColorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade700, height: 1.3),
          ),
          const SizedBox(height: 10),
          Opacity(
            opacity: onTap != null ? 1 : 0,
            child: Text(
              'Tap to inspect matching requests',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _StageTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StageTile({
    super.key,
    required this.label,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: onTap == null
              ? Colors.grey.shade300
              : color.withValues(alpha: 0.24),
        ),
        color: onTap == null
            ? Colors.grey.shade50
            : color.withValues(alpha: 0.04),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.3),
                ),
                if (onTap != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tap to view these requests',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(height: 8),
                Icon(Icons.chevron_right_rounded, color: Colors.grey.shade500),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return tile;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: tile,
      ),
    );
  }
}

class _RequestPreviewCard extends StatelessWidget {
  final RentRequest request;
  final String statusLabel;
  final Color statusColor;
  final IconData statusIcon;
  final String dateRangeLabel;
  final String? submittedAtLabel;
  final String? amountLabel;
  final VoidCallback? onTap;

  const _RequestPreviewCard({
    super.key,
    required this.request,
    required this.statusLabel,
    required this.statusColor,
    required this.statusIcon,
    required this.dateRangeLabel,
    this.submittedAtLabel,
    this.amountLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _StatusPill(
                icon: statusIcon,
                label: statusLabel,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaChip(
                icon: Icons.calendar_today_outlined,
                label: dateRangeLabel,
              ),
              if (submittedAtLabel != null)
                _MetaChip(
                  icon: Icons.schedule_outlined,
                  label: 'Submitted $submittedAtLabel',
                ),
              if (amountLabel != null)
                _MetaChip(icon: Icons.payments_outlined, label: amountLabel!),
              if (request.weatherFlag)
                const _MetaChip(
                  icon: Icons.cloud_outlined,
                  label: 'Weather risk',
                  color: Color(0xFFD97706),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  request.address,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 12),
                Text(
                  'Open',
                  style: TextStyle(
                    color: lightColorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  color: lightColorScheme.primary,
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MetaChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: resolvedColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: resolvedColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: resolvedColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
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
