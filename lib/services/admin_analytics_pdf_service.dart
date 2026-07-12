import 'dart:typed_data';

import 'package:bukidbayan_app/models/admin_analytics_report.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class AdminAnalyticsPdfService {
  static final DateFormat _date = DateFormat('yyyy-MM-dd');
  static final DateFormat _dateTime = DateFormat('yyyy-MM-dd HH:mm');
  static final NumberFormat _currency = NumberFormat.currency(
    symbol: 'PHP ',
    decimalDigits: 0,
  );

  static String _formatCurrency(num value) => _currency.format(value.round());

  static String _formatDateTime(DateTime? value) {
    if (value == null) return 'No data yet';
    return _dateTime.format(value);
  }

  static String _formatRate(double value) =>
      '${(value * 100).toStringAsFixed(0)}%';

  static String _formatWindow(AdminAnalyticsReport report) {
    final window = report.timeWindow;
    if (window == null) return 'All recorded data';
    return '${_date.format(window.start)} to ${_date.format(window.end)}';
  }

  static String _formatPledgeState(int count, int amount) {
    final pledgeLabel = count == 1 ? 'pledge' : 'pledges';
    return '$count $pledgeLabel | ${_formatCurrency(amount)}';
  }

  static pw.Widget _buildSectionTitle({
    required String title,
    required pw.Font bold,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 12, bottom: 6),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          font: bold,
          fontSize: 13,
          color: PdfColors.green800,
        ),
      ),
    );
  }

  static pw.Widget _buildInfoTable({
    required List<List<String>> rows,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.7),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.2),
        1: pw.FlexColumnWidth(2.8),
      },
      children: [
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven ? PdfColors.green50 : PdfColors.white,
            ),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(7),
                child: pw.Text(
                  rows[i][0],
                  style: pw.TextStyle(font: bold, fontSize: 9),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(7),
                child: pw.Text(
                  rows[i][1],
                  style: pw.TextStyle(font: regular, fontSize: 9),
                ),
              ),
            ],
          ),
      ],
    );
  }

  static pw.Widget _buildDataTable({
    required List<String> headers,
    required List<List<String>> rows,
    required List<pw.TableColumnWidth> columnWidths,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.7),
      columnWidths: {
        for (var i = 0; i < columnWidths.length; i++) i: columnWidths[i],
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.green100),
          children: [
            for (final header in headers)
              pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  header,
                  style: pw.TextStyle(font: bold, fontSize: 8.5),
                ),
              ),
          ],
        ),
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isEven ? PdfColors.white : PdfColors.grey50,
            ),
            children: [
              for (final cell in rows[i])
                pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    cell,
                    style: pw.TextStyle(font: regular, fontSize: 8.5),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  static Future<_PdfFontSet> _loadFonts() async {
    try {
      return _PdfFontSet(
        regular: await PdfGoogleFonts.nunitoRegular(),
        bold: await PdfGoogleFonts.nunitoBold(),
      );
    } catch (_) {
      return _PdfFontSet(
        regular: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      );
    }
  }

  static Future<Uint8List> buildPdfBytes({
    required AdminAnalyticsReport report,
  }) async {
    final doc = pw.Document();
    final fonts = await _loadFonts();
    final regular = fonts.regular;
    final bold = fonts.bold;
    final generatedAt = _dateTime.format(report.generatedAt);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(font: regular, fontSize: 8),
          ),
        ),
        build: (context) => [
          pw.Text(
            'Admin Analytics Report',
            style: pw.TextStyle(
              font: bold,
              fontSize: 20,
              color: PdfColors.green800,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Generated: $generatedAt',
            style: pw.TextStyle(font: regular, fontSize: 10),
          ),
          pw.Text(
            'Window: ${_formatWindow(report)}',
            style: pw.TextStyle(font: regular, fontSize: 10),
          ),
          pw.SizedBox(height: 12),
          _buildInfoTable(
            rows: [
              ['Registered Users', report.platform.totalUsers.toString()],
              ['Listed Equipment', report.platform.totalEquipment.toString()],
              ['Active Rentals', report.rentals.activeRentals.toString()],
              [
                'Amount Received',
                _formatCurrency(report.crowdfunding.totalReceivedAmount),
              ],
            ],
            regular: regular,
            bold: bold,
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.green200, width: 0.7),
            ),
            child: pw.Text(
              'Current snapshot metrics ignore the selected window for availability and live operational backlog counts. Window-scoped totals use request dates, pledge creation dates, confirmation dates, invalidation dates, and cancellation dates where applicable.',
              style: pw.TextStyle(font: regular, fontSize: 9),
            ),
          ),
          _buildSectionTitle(title: 'Platform Overview', bold: bold),
          _buildInfoTable(
            rows: [
              ['Registered users', report.platform.totalUsers.toString()],
              [
                'New users in selected window',
                report.platform.newUsersInWindow.toString(),
              ],
              ['Co-op admin accounts', report.platform.coopAccounts.toString()],
              ['Listed equipment', report.platform.totalEquipment.toString()],
              [
                'New equipment in selected window',
                report.platform.newEquipmentInWindow.toString(),
              ],
              [
                'Participating equipment owners',
                report.platform.equipmentOwners.toString(),
              ],
              [
                'Equipment availability snapshot',
                '${report.platform.availableEquipment} available, ${report.platform.unavailableEquipment} unavailable, ${report.platform.underMaintenanceEquipment} under maintenance',
              ],
            ],
            regular: regular,
            bold: bold,
          ),
          _buildSectionTitle(title: 'System Health', bold: bold),
          _buildInfoTable(
            rows: [
              ['Current system status', report.systemHealth.currentStatus],
              [
                'Last heartbeat',
                '${_formatDateTime(report.systemHealth.lastHeartbeatAt)}${report.systemHealth.lastHeartbeatSource == null ? '' : ' | ${report.systemHealth.lastHeartbeatSource}'}',
              ],
              [
                'Last app open captured',
                _formatDateTime(report.systemHealth.lastAppOpenAt),
              ],
              [
                'Last background task result',
                '${report.systemHealth.lastBackgroundTaskName ?? 'No background task recorded yet'} (${report.systemHealth.lastBackgroundTaskStatus ?? 'unknown'}) | ${_formatDateTime(report.systemHealth.lastBackgroundTaskAt)}',
              ],
              [
                'Telemetry events in selected window',
                report.systemHealth.telemetryEventsInWindow.toString(),
              ],
              [
                'App opens in selected window',
                report.systemHealth.appOpensInWindow.toString(),
              ],
              [
                'Heartbeat events in selected window',
                report.systemHealth.heartbeatEventsInWindow.toString(),
              ],
              [
                'Login failures in selected window',
                report.systemHealth.loginFailuresInWindow.toString(),
              ],
              [
                'Background-task failures in selected window',
                report.systemHealth.backgroundTaskFailuresInWindow.toString(),
              ],
            ],
            regular: regular,
            bold: bold,
          ),
          _buildSectionTitle(title: 'Rental Operations', bold: bold),
          _buildInfoTable(
            rows: [
              ['Active rentals', report.rentals.activeRentals.toString()],
              [
                'Pending rental requests',
                report.rentals.pendingRentals.toString(),
              ],
              [
                'Completed rentals in selected window',
                report.rentals.completedRentals.toString(),
              ],
              [
                'Unique farmers served in selected window',
                report.rentals.uniqueFarmersServed.toString(),
              ],
              [
                'Completed rental value in selected window',
                _formatCurrency(report.rentals.completedRentalValue),
              ],
              [
                'Weather-risk bookings right now',
                report.rentals.weatherRiskBookings.toString(),
              ],
            ],
            regular: regular,
            bold: bold,
          ),
          _buildSectionTitle(title: 'Crowdfunding Overview', bold: bold),
          _buildInfoTable(
            rows: [
              [
                'Live campaigns right now',
                report.crowdfunding.liveCampaigns.toString(),
              ],
              [
                'Campaigns published in selected window',
                report.crowdfunding.campaignsPublishedInWindow.toString(),
              ],
              [
                'Pledge submissions in selected window',
                report.crowdfunding.totalPledges.toString(),
              ],
              [
                'Submitted pledge amount',
                _formatCurrency(report.crowdfunding.totalPledgedAmount),
              ],
              [
                'Amount received in selected window',
                _formatCurrency(report.crowdfunding.totalReceivedAmount),
              ],
              [
                'Unique supporters in selected window',
                report.crowdfunding.uniqueSupporters.toString(),
              ],
              [
                'Awaiting proof from supporters right now',
                _formatPledgeState(
                  report.crowdfunding.pendingProofPledges,
                  report.crowdfunding.pendingProofAmount,
                ),
              ],
              [
                'Proofs awaiting admin review right now',
                _formatPledgeState(
                  report.crowdfunding.pendingReviewPledges,
                  report.crowdfunding.pendingReviewAmount,
                ),
              ],
              [
                'Invalidated contributions in selected window',
                _formatPledgeState(
                  report.crowdfunding.invalidatedPledges,
                  report.crowdfunding.invalidatedAmount,
                ),
              ],
              [
                'Canceled pledges in selected window',
                _formatPledgeState(
                  report.crowdfunding.canceledPledges,
                  report.crowdfunding.canceledAmount,
                ),
              ],
            ],
            regular: regular,
            bold: bold,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Submitted pledges stay separate from confirmed contributions. A pledge can still be awaiting proof, awaiting review, confirmed, invalidated, or canceled.',
            style: pw.TextStyle(font: regular, fontSize: 9),
          ),
          _buildSectionTitle(title: 'Risk & Watchlist', bold: bold),
          _buildInfoTable(
            rows: [
              [
                'Blocked renters right now',
                report.watchlist.blockedRenters.toString(),
              ],
              [
                'Equipment under maintenance',
                report.watchlist.underMaintenanceEquipment.toString(),
              ],
              [
                'Weather-risk bookings right now',
                report.watchlist.weatherRiskBookings.toString(),
              ],
              [
                'Pending rental requests',
                report.watchlist.pendingRentals.toString(),
              ],
              [
                'Contribution proofs awaiting review',
                report.watchlist.contributionProofsAwaitingReview.toString(),
              ],
            ],
            regular: regular,
            bold: bold,
          ),
          _buildSectionTitle(title: 'Demand Proxy by Category', bold: bold),
          if (report.topDemandCategories.isEmpty)
            pw.Text(
              'No category demand data is available for this window.',
              style: pw.TextStyle(font: regular, fontSize: 9),
            )
          else
            _buildDataTable(
              headers: const [
                'Category',
                'Requests',
                'Completed',
                'Unique Farmers',
                'Completion Rate',
              ],
              rows: report.topDemandCategories
                  .map(
                    (item) => [
                      item.categoryLabel,
                      item.requestCount.toString(),
                      item.completedRequestCount.toString(),
                      item.uniqueRenters.toString(),
                      '${(item.completionRate * 100).toStringAsFixed(0)}%',
                    ],
                  )
                  .toList(),
              columnWidths: const [
                pw.FlexColumnWidth(2.2),
                pw.FlexColumnWidth(1),
                pw.FlexColumnWidth(1),
                pw.FlexColumnWidth(1.2),
                pw.FlexColumnWidth(1.2),
              ],
              regular: regular,
              bold: bold,
            ),
          _buildSectionTitle(title: 'Demand Forecast Hotspots', bold: bold),
          _buildInfoTable(
            rows: [
              [
                'Requests with usable forecast location',
                report.forecasting.requestsWithForecastLocation.toString(),
              ],
              [
                'Requests with location and forecast inputs',
                '${report.forecasting.requestsWithForecastInputsAndLocation} (${_formatRate(report.forecasting.locationCoverageRate)})',
              ],
              [
                'Locations analyzed',
                report.forecasting.locationsAnalyzed.toString(),
              ],
              [
                'Hotspots detected',
                '${report.forecasting.hotspotCount} total, ${report.forecasting.highDemandHotspots} high demand, ${report.forecasting.highConfidenceHotspots} high confidence',
              ],
            ],
            regular: regular,
            bold: bold,
          ),
          pw.SizedBox(height: 8),
          if (report.forecasting.hotspots.isEmpty)
            pw.Text(
              'No location-level forecast hotspots are available yet for this window.',
              style: pw.TextStyle(font: regular, fontSize: 9),
            )
          else
            _buildDataTable(
              headers: const [
                'Location',
                'Category',
                'Demand',
                'Confidence',
                'Matched',
                'Recent',
              ],
              rows: report.forecasting.hotspots
                  .map(
                    (item) => [
                      item.locationLabel,
                      item.equipmentCategory,
                      item.demandLevel.name,
                      item.confidence.name,
                      item.matchedRequests.toString(),
                      item.recentRequests.toString(),
                    ],
                  )
                  .toList(),
              columnWidths: const [
                pw.FlexColumnWidth(1.8),
                pw.FlexColumnWidth(1.6),
                pw.FlexColumnWidth(0.9),
                pw.FlexColumnWidth(1),
                pw.FlexColumnWidth(0.8),
                pw.FlexColumnWidth(0.8),
              ],
              regular: regular,
              bold: bold,
            ),
          _buildSectionTitle(title: 'Data Readiness', bold: bold),
          _buildInfoTable(
            rows: [
              [
                'Member profiles with normalized geography',
                '${report.dataReadiness.memberProfilesWithGeography}/${report.dataReadiness.totalMemberProfiles} (${_formatRate(report.dataReadiness.memberProfileCoverageRate)})',
              ],
              [
                'Equipment with normalized geography',
                '${report.dataReadiness.equipmentWithGeography}/${report.dataReadiness.totalEquipment} (${_formatRate(report.dataReadiness.equipmentGeographyCoverageRate)})',
              ],
              [
                'Requests with normalized geography',
                '${report.dataReadiness.requestsWithNormalizedGeography}/${report.dataReadiness.totalRequests} (${_formatRate(report.dataReadiness.requestGeographyCoverageRate)})',
              ],
              [
                'Requests with forecast inputs',
                '${report.dataReadiness.requestsWithForecastInputs}/${report.dataReadiness.totalRequests} (${_formatRate(report.dataReadiness.forecastInputCoverageRate)})',
              ],
              [
                'Requests with status-history logs',
                '${report.dataReadiness.requestsWithStatusHistory}/${report.dataReadiness.totalRequests} (${_formatRate(report.dataReadiness.requestHistoryCoverageRate)})',
              ],
              [
                'Requests with timeline events',
                '${report.dataReadiness.requestsWithTimelineEvents}/${report.dataReadiness.totalRequests} (${_formatRate(report.dataReadiness.requestTimelineCoverageRate)})',
              ],
              [
                'Equipment with maintenance logs',
                '${report.dataReadiness.equipmentWithMaintenanceLogs}/${report.dataReadiness.totalEquipment} (${_formatRate(report.dataReadiness.maintenanceLogCoverageRate)})',
              ],
              [
                'Maintenance log entries recorded',
                report.dataReadiness.maintenanceLogEntries.toString(),
              ],
              [
                'Commercial benchmark rows available',
                report.dataReadiness.benchmarkRows.toString(),
              ],
            ],
            regular: regular,
            bold: bold,
          ),
          _buildSectionTitle(title: 'Impact Summary', bold: bold),
          _buildInfoTable(
            rows: [
              [
                'Total farmers served',
                report.impact.totalFarmersServed.toString(),
              ],
              [
                'Participating equipment owners',
                report.impact.totalEquipmentOwners.toString(),
              ],
              [
                'Total campaign supporters',
                report.impact.totalCampaignSupporters.toString(),
              ],
              [
                'Completed rentals all-time',
                report.impact.totalCompletedRentals.toString(),
              ],
            ],
            regular: regular,
            bold: bold,
          ),
        ],
      ),
    );

    return doc.save();
  }

  static Future<void> printOrSavePdf({
    required AdminAnalyticsReport report,
  }) async {
    final bytes = await buildPdfBytes(report: report);
    final fileDate = _date.format(DateTime.now());
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'admin_analytics_$fileDate.pdf',
    );
  }
}

class _PdfFontSet {
  final pw.Font regular;
  final pw.Font bold;

  const _PdfFontSet({required this.regular, required this.bold});
}
