import 'dart:typed_data';

import 'package:bukidbayan_app/models/demand_forecast.dart';
import 'package:bukidbayan_app/models/owner_rental_report.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class EarningsPdfService {
  static Future<Uint8List> buildLegacyPdfBytes({
    required OwnerRentalReport report,
    required String ownerName,
  }) async {
    final pdf = pw.Document();
    final currency = NumberFormat.currency(symbol: 'PHP ', decimalDigits: 2);
    final dateFormat = DateFormat('MMM d, yyyy');
    final timestampFormat = DateFormat('MMMM d, yyyy hh:mm a');
    final generatedAt = timestampFormat.format(DateTime.now());

    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontItalic = await PdfGoogleFonts.nunitoItalic();

    final titleStyle = pw.TextStyle(
      font: fontBold,
      fontSize: 18,
      color: PdfColors.green800,
    );
    final subtitleStyle = pw.TextStyle(
      font: fontRegular,
      fontSize: 10,
      color: PdfColors.grey700,
    );
    final sectionTitleStyle = pw.TextStyle(
      font: fontBold,
      fontSize: 12,
      color: PdfColors.green900,
    );
    final bodyStyle = pw.TextStyle(
      font: fontRegular,
      fontSize: 9,
      color: PdfColors.grey900,
    );
    final captionStyle = pw.TextStyle(
      font: fontItalic,
      fontSize: 8,
      color: PdfColors.grey600,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}  |  Generated: $generatedAt',
            style: captionStyle,
          ),
        ),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Earnings Report', style: titleStyle),
                    pw.SizedBox(height: 4),
                    pw.Text('Owner: $ownerName', style: subtitleStyle),
                    pw.Text(
                      report.filter.timeWindow == null
                          ? 'Period: All time'
                          : 'Period: ${dateFormat.format(report.filter.timeWindow!.start)} - ${dateFormat.format(report.filter.timeWindow!.end)}',
                      style: subtitleStyle,
                    ),
                    pw.Text('Generated: $generatedAt', style: subtitleStyle),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green800,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Total Earnings',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 9,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      currency.format(report.summary.totalEarnings),
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 16,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Transactions',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 9,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '${report.filteredRows.length}',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 16,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (report.filter.hasActiveFilters) ...[
            pw.SizedBox(height: 12),
            _filterBlock(
              report: report,
              dateFormat: dateFormat,
              bodyStyle: bodyStyle,
              titleStyle: sectionTitleStyle,
              currency: currency,
            ),
          ],
          pw.SizedBox(height: 14),
          if (report.filteredRows.isEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Text(
                'No completed transactions match the current filters.',
                style: bodyStyle,
              ),
            )
          else
            _buildTable(
              headers: const [
                '#',
                'Date Rented',
                'Farmer Name',
                'Farm Location',
                'Equipment',
                'Price Rate',
                'Rate Unit',
                'Days',
                'Area / Volume',
                'Payment',
              ],
              rows: report.filteredRows.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                final request = row.request;
                final priceRate = row.equipment == null
                    ? '-'
                    : currency.format(row.equipment!.price);

                return [
                  '${index + 1}',
                  dateFormat.format(request.start),
                  request.name,
                  row.farmLocation,
                  request.itemName,
                  priceRate,
                  request.agreedRentalUnit ?? row.equipment?.rentalUnit ?? '-',
                  request.agreedRentalUnit?.toLowerCase().contains('day') ==
                          true
                      ? '${row.daysRented}'
                      : '-',
                  row.measurementDisplay,
                  row.totalPayment == null
                      ? '-'
                      : currency.format(row.totalPayment),
                ];
              }).toList(),
              fontRegular: fontRegular,
              fontBold: fontBold,
              numericColumns: const {0, 5, 7, 9},
            ),
          pw.SizedBox(height: 14),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.green200),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Earnings Report:  ',
                  style: pw.TextStyle(
                    font: fontRegular,
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  currency.format(report.summary.totalEarnings),
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 14,
                    color: PdfColors.green900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<Uint8List> buildPdfBytes({
    required OwnerRentalReport report,
    required String ownerName,
  }) async {
    final pdf = pw.Document();
    final currency = NumberFormat.currency(symbol: 'PHP ', decimalDigits: 2);
    final dateFormat = DateFormat('MMM d, yyyy');
    final timestampFormat = DateFormat('MMMM d, yyyy hh:mm a');
    final generatedAt = timestampFormat.format(DateTime.now());

    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontItalic = await PdfGoogleFonts.nunitoItalic();

    final titleStyle = pw.TextStyle(
      font: fontBold,
      fontSize: 18,
      color: PdfColors.green800,
    );
    final subtitleStyle = pw.TextStyle(
      font: fontRegular,
      fontSize: 10,
      color: PdfColors.grey700,
    );
    final sectionTitleStyle = pw.TextStyle(
      font: fontBold,
      fontSize: 12,
      color: PdfColors.green900,
    );
    final bodyStyle = pw.TextStyle(
      font: fontRegular,
      fontSize: 9,
      color: PdfColors.grey900,
    );
    final captionStyle = pw.TextStyle(
      font: fontItalic,
      fontSize: 8,
      color: PdfColors.grey600,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}  |  Generated: $generatedAt',
            style: captionStyle,
          ),
        ),
        build: (context) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Owner Rental Analytics Report', style: titleStyle),
                    pw.SizedBox(height: 4),
                    pw.Text('Owner: $ownerName', style: subtitleStyle),
                    pw.Text(
                      'Utilization window: ${dateFormat.format(report.utilizationWindow.start)} - ${dateFormat.format(report.utilizationWindow.end)}',
                      style: subtitleStyle,
                    ),
                    pw.Text('Generated: $generatedAt', style: subtitleStyle),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              _summaryBanner(
                label: 'Total earnings',
                value: currency.format(report.summary.totalEarnings),
                fontRegular: fontRegular,
                fontBold: fontBold,
              ),
            ],
          ),
          if (report.filter.hasActiveFilters) ...[
            pw.SizedBox(height: 12),
            _filterBlock(
              report: report,
              dateFormat: dateFormat,
              bodyStyle: bodyStyle,
              titleStyle: sectionTitleStyle,
              currency: currency,
            ),
          ],
          pw.SizedBox(height: 12),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricCard(
                label: 'Completed rentals',
                value: '${report.summary.completedRentals}',
                fontRegular: fontRegular,
                fontBold: fontBold,
                background: PdfColors.green50,
              ),
              _metricCard(
                label: 'Farmers served',
                value: '${report.summary.uniqueFarmersServed}',
                fontRegular: fontRegular,
                fontBold: fontBold,
                background: PdfColors.teal50,
              ),
              _metricCard(
                label: 'Booked days',
                value: '${report.summary.totalBookedDays}',
                fontRegular: fontRegular,
                fontBold: fontBold,
                background: PdfColors.orange50,
              ),
              _metricCard(
                label: 'Estimated booked hours',
                value:
                    '${report.summary.estimatedBookedHours.toStringAsFixed(0)} hrs',
                fontRegular: fontRegular,
                fontBold: fontBold,
                background: PdfColors.indigo50,
              ),
              _metricCard(
                label: 'Average rental duration',
                value:
                    '${report.summary.averageRentalDurationDays.toStringAsFixed(1)} days',
                fontRegular: fontRegular,
                fontBold: fontBold,
                background: PdfColors.brown50,
              ),
            ],
          ),
          pw.SizedBox(height: 14),
          _sectionTitle('Forecast for Your Tools', sectionTitleStyle),
          pw.SizedBox(height: 6),
          _forecastBlock(
            report: report,
            fontRegular: fontRegular,
            fontBold: fontBold,
            bodyStyle: bodyStyle,
            titleStyle: sectionTitleStyle,
          ),
          pw.SizedBox(height: 14),
          _sectionTitle('Current Fleet Maintenance', sectionTitleStyle),
          pw.SizedBox(height: 6),
          _maintenanceBlock(
            report: report,
            fontRegular: fontRegular,
            fontBold: fontBold,
          ),
          pw.SizedBox(height: 14),
          if (report.equipmentPerformance.isNotEmpty) ...[
            _sectionTitle('Performance by Equipment', sectionTitleStyle),
            pw.SizedBox(height: 6),
            _buildTable(
              headers: const [
                'Equipment',
                'Category',
                'Operator',
                'Rentals',
                'Farmers',
                'Days',
                'Est Hours',
                'Earnings',
              ],
              rows: report.equipmentPerformance
                  .map(
                    (item) => [
                      item.itemName,
                      item.categoryLabel,
                      item.withOperator ? 'Yes' : 'No',
                      '${item.completedRentals}',
                      '${item.uniqueFarmersServed}',
                      '${item.bookedDays}',
                      item.estimatedBookedHours.toStringAsFixed(0),
                      currency.format(item.totalEarnings),
                    ],
                  )
                  .toList(),
              fontRegular: fontRegular,
              fontBold: fontBold,
              numericColumns: const {3, 4, 5, 6, 7},
            ),
            pw.SizedBox(height: 14),
          ],
          if (report.categoryPerformance.isNotEmpty) ...[
            _sectionTitle('Performance by Category', sectionTitleStyle),
            pw.SizedBox(height: 6),
            _buildTable(
              headers: const [
                'Category',
                'Rentals',
                'Farmers',
                'Days',
                'Est Hours',
                'Earnings',
              ],
              rows: report.categoryPerformance
                  .map(
                    (item) => [
                      item.categoryLabel,
                      '${item.completedRentals}',
                      '${item.uniqueFarmersServed}',
                      '${item.bookedDays}',
                      item.estimatedBookedHours.toStringAsFixed(0),
                      currency.format(item.totalEarnings),
                    ],
                  )
                  .toList(),
              fontRegular: fontRegular,
              fontBold: fontBold,
              numericColumns: const {1, 2, 3, 4, 5},
            ),
            pw.SizedBox(height: 14),
          ],
          if (report.utilizationItems.isNotEmpty) ...[
            _sectionTitle('Estimated Utilization', sectionTitleStyle),
            pw.SizedBox(height: 4),
            pw.Text(
              'Estimated booked hours use booked days x 24 hours, consistent with the current maintenance-hour heuristic.',
              style: bodyStyle,
            ),
            pw.SizedBox(height: 6),
            _buildTable(
              headers: const [
                'Equipment',
                'Category',
                'Operator',
                'Booked Hrs',
                'Schedulable Hrs',
                'Utilization',
                'Status',
              ],
              rows: report.utilizationItems
                  .map(
                    (item) => [
                      item.equipmentName,
                      item.categoryLabel,
                      item.withOperator ? 'Yes' : 'No',
                      item.bookedHours.toStringAsFixed(0),
                      item.schedulableHours.toStringAsFixed(0),
                      '${(item.utilizationRate * 100).toStringAsFixed(1)}%',
                      _utilizationStatus(item),
                    ],
                  )
                  .toList(),
              fontRegular: fontRegular,
              fontBold: fontBold,
              numericColumns: const {3, 4, 5},
            ),
            pw.SizedBox(height: 14),
          ],
          _sectionTitle('Completed Transactions', sectionTitleStyle),
          pw.SizedBox(height: 6),
          if (report.filteredRows.isEmpty)
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Text(
                'No completed transactions match the current filters.',
                style: bodyStyle,
              ),
            )
          else
            _buildTable(
              headers: const [
                '#',
                'Date Rented',
                'Farmer',
                'Farm Location',
                'Equipment',
                'Price Rate',
                'Rate Unit',
                'Days',
                'Area / Volume',
                'Payment',
              ],
              rows: report.filteredRows.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                final request = row.request;
                final priceRate = row.equipment == null
                    ? '-'
                    : currency.format(row.equipment!.price);

                return [
                  '${index + 1}',
                  dateFormat.format(request.start),
                  request.name,
                  row.farmLocation,
                  request.itemName,
                  priceRate,
                  request.agreedRentalUnit ?? row.equipment?.rentalUnit ?? '-',
                  request.agreedRentalUnit?.toLowerCase().contains('day') ==
                          true
                      ? '${row.daysRented}'
                      : '-',
                  row.measurementDisplay,
                  row.totalPayment == null
                      ? '-'
                      : currency.format(row.totalPayment),
                ];
              }).toList(),
              fontRegular: fontRegular,
              fontBold: fontBold,
              numericColumns: const {0, 5, 7, 9},
            ),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<void> generateAndShare({
    required OwnerRentalReport report,
    required String ownerName,
  }) async {
    final bytes = await buildPdfBytes(report: report, ownerName: ownerName);
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'owner_rental_analytics_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
    );
  }

  static pw.Widget _summaryBanner({
    required String label,
    required String value,
    required pw.Font fontRegular,
    required pw.Font fontBold,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: pw.BoxDecoration(
        color: PdfColors.green800,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: fontRegular,
              fontSize: 9,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 16,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _metricCard({
    required String label,
    required String value,
    required pw.Font fontRegular,
    required pw.Font fontBold,
    required PdfColor background,
  }) {
    return pw.Container(
      width: 145,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: background,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: fontRegular,
              fontSize: 8,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 12,
              color: PdfColors.grey900,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _filterBlock({
    required OwnerRentalReport report,
    required DateFormat dateFormat,
    required pw.TextStyle bodyStyle,
    required pw.TextStyle titleStyle,
    required NumberFormat currency,
  }) {
    final lines = <String>[];

    if (report.filter.timeWindow != null) {
      lines.add(
        'Date range: ${dateFormat.format(report.filter.timeWindow!.start)} - ${dateFormat.format(report.filter.timeWindow!.end)}',
      );
    }
    if (report.filter.searchQuery.trim().isNotEmpty) {
      lines.add('Search keyword: "${report.filter.searchQuery.trim()}"');
    }
    final equipmentName = report.resolveEquipmentName(
      report.filter.equipmentId,
    );
    if (equipmentName != null) {
      lines.add('Equipment: $equipmentName');
    }
    final operatorLabel = report.filter.operatorFilter.pdfLabel;
    if (operatorLabel != null) {
      lines.add('Operator filter: $operatorLabel');
    }
    if (report.filter.minPayment != null || report.filter.maxPayment != null) {
      lines.add(
        'Payment range: ${report.filter.minPayment != null ? currency.format(report.filter.minPayment) : 'any'} - ${report.filter.maxPayment != null ? currency.format(report.filter.maxPayment) : 'any'}',
      );
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.amber200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Filters applied', style: titleStyle),
          pw.SizedBox(height: 4),
          ...lines.map((line) => pw.Text(line, style: bodyStyle)),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String title, pw.TextStyle style) {
    return pw.Text(title, style: style);
  }

  static pw.Widget _forecastBlock({
    required OwnerRentalReport report,
    required pw.Font fontRegular,
    required pw.Font fontBold,
    required pw.TextStyle bodyStyle,
    required pw.TextStyle titleStyle,
  }) {
    final snapshot = report.forecastSnapshot;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _metricCard(
              label: 'Signals used',
              value: '${snapshot.requestsConsidered}',
              fontRegular: fontRegular,
              fontBold: fontBold,
              background: PdfColors.blue50,
            ),
            _metricCard(
              label: 'Forecast inputs',
              value:
                  '${snapshot.requestsWithForecastInputs} (${(snapshot.forecastInputCoverageRate * 100).toStringAsFixed(0)}%)',
              fontRegular: fontRegular,
              fontBold: fontBold,
              background: PdfColors.teal50,
            ),
            _metricCard(
              label: 'Confidence',
              value: _forecastConfidenceLabel(snapshot.confidence),
              fontRegular: fontRegular,
              fontBold: fontBold,
              background: PdfColors.indigo50,
            ),
            _metricCard(
              label: 'Matched tools',
              value: '${snapshot.equipmentMatches.length}',
              fontRegular: fontRegular,
              fontBold: fontBold,
              background: PdfColors.green50,
            ),
            _metricCard(
              label: 'Rising / emerging',
              value:
                  '${snapshot.risingTrendCount}/${snapshot.emergingTrendCount}',
              fontRegular: fontRegular,
              fontBold: fontBold,
              background: PdfColors.orange50,
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue50,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.blue200),
          ),
          child: pw.Text(snapshot.summary, style: bodyStyle),
        ),
        pw.SizedBox(height: 10),
        if (!snapshot.hasInsights)
          _infoBlock(
            message:
                'Not enough owner-side demand signals yet. This section improves as more requests are recorded, especially when renters fill in crop type, farming phase, and intended use.',
            bodyStyle: bodyStyle,
          )
        else ...[
          _sectionTitle('Category Signals', titleStyle),
          pw.SizedBox(height: 6),
          _buildTable(
            headers: const [
              'Category',
              'Demand',
              'Matched',
              'Recent',
              'Drivers',
              'Recommendation',
            ],
            rows: snapshot.categoryInsights
                .map(
                  (insight) => [
                    insight.equipmentCategory,
                    _forecastLevelLabel(insight.level),
                    '${insight.matchedRequests}',
                    '${insight.recentRequests}',
                    insight.drivers.isEmpty
                        ? '-'
                        : insight.drivers.take(2).join(', '),
                    insight.recommendation,
                  ],
                )
                .toList(),
            fontRegular: fontRegular,
            fontBold: fontBold,
            numericColumns: const {2, 3},
          ),
          if (snapshot.equipmentMatches.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _sectionTitle('Matching Tools in Your Fleet', titleStyle),
            pw.SizedBox(height: 6),
            _buildTable(
              headers: const [
                'Tool',
                'Category',
                'Demand',
                'Availability',
                'Recommendation',
              ],
              rows: snapshot.equipmentMatches
                  .map(
                    (item) => [
                      item.equipmentName,
                      item.categoryLabel,
                      _forecastLevelLabel(item.demandLevel),
                      _forecastAvailabilityLabel(item),
                      item.recommendation,
                    ],
                  )
                  .toList(),
              fontRegular: fontRegular,
              fontBold: fontBold,
            ),
          ],
          if (snapshot.equipmentTrends.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _sectionTitle('Recent Demand Trend by Tool', titleStyle),
            pw.SizedBox(height: 6),
            _buildTable(
              headers: const [
                'Tool',
                'Category',
                'Trend',
                'Recent',
                'Previous',
                'Seasonal Signal',
                'Note',
              ],
              rows: snapshot.equipmentTrends
                  .map(
                    (item) => [
                      item.equipmentName,
                      item.categoryLabel,
                      _forecastTrendLabel(item.trend),
                      '${item.recentRequestCount}',
                      '${item.previousRequestCount}',
                      _forecastSeasonalSignal(item),
                      item.note,
                    ],
                  )
                  .toList(),
              fontRegular: fontRegular,
              fontBold: fontBold,
              numericColumns: const {3, 4},
            ),
          ],
        ],
      ],
    );
  }

  static pw.Widget _maintenanceBlock({
    required OwnerRentalReport report,
    required pw.Font fontRegular,
    required pw.Font fontBold,
  }) {
    final snapshot = report.maintenanceSnapshot;

    pw.Widget stat(String label, String value, PdfColor color) {
      return pw.Container(
        width: 105,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: PdfColors.grey300),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                font: fontRegular,
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 12,
                color: PdfColors.grey900,
              ),
            ),
          ],
        ),
      );
    }

    String names(List<String> items, String emptyLabel) {
      if (items.isEmpty) return emptyLabel;
      return items.join(', ');
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            stat(
              'In scope',
              '${snapshot.totalOwnedEquipment}',
              PdfColors.blue50,
            ),
            stat('Available', '${snapshot.availableCount}', PdfColors.green50),
            stat(
              'Unavailable',
              '${snapshot.unavailableCount}',
              PdfColors.orange50,
            ),
            stat(
              'Under maintenance',
              '${snapshot.underMaintenanceCount}',
              PdfColors.red50,
            ),
            stat('Due now', '${snapshot.dueCount}', PdfColors.deepOrange50),
            stat('Upcoming', '${snapshot.upcomingCount}', PdfColors.indigo50),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Due now: ${names(snapshot.dueEquipment.map((item) => item.name).toList(), 'None')}',
          style: pw.TextStyle(font: fontRegular, fontSize: 9),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Upcoming: ${names(snapshot.upcomingEquipment.map((item) => item.name).toList(), 'None')}',
          style: pw.TextStyle(font: fontRegular, fontSize: 9),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Under maintenance: ${names(snapshot.underMaintenanceEquipment.map((item) => item.name).toList(), 'None')}',
          style: pw.TextStyle(font: fontRegular, fontSize: 9),
        ),
      ],
    );
  }

  static pw.Widget _buildTable({
    required List<String> headers,
    required List<List<String>> rows,
    required pw.Font fontRegular,
    required pw.Font fontBold,
    Set<int> numericColumns = const {},
  }) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
      headerStyle: pw.TextStyle(
        font: fontBold,
        fontSize: 8,
        color: PdfColors.white,
      ),
      cellStyle: pw.TextStyle(
        font: fontRegular,
        fontSize: 8,
        color: PdfColors.grey900,
      ),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
      rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.green50),
      cellAlignments: {
        for (final index in numericColumns) index: pw.Alignment.centerRight,
      },
    );
  }

  static pw.Widget _infoBlock({
    required String message,
    required pw.TextStyle bodyStyle,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Text(message, style: bodyStyle),
    );
  }

  static String _forecastConfidenceLabel(DemandForecastConfidence confidence) {
    switch (confidence) {
      case DemandForecastConfidence.high:
        return 'High';
      case DemandForecastConfidence.medium:
        return 'Medium';
      case DemandForecastConfidence.low:
        return 'Early';
    }
  }

  static String _forecastLevelLabel(DemandForecastLevel level) {
    switch (level) {
      case DemandForecastLevel.high:
        return 'High demand';
      case DemandForecastLevel.medium:
        return 'Medium demand';
      case DemandForecastLevel.low:
        return 'Early signal';
    }
  }

  static String _forecastAvailabilityLabel(
    OwnerRentalForecastEquipmentMatch item,
  ) {
    if (item.isUnderMaintenance) return 'Under maintenance';
    return item.isAvailable ? 'Available' : 'Unavailable';
  }

  static String _forecastTrendLabel(OwnerRentalDemandTrend trend) {
    switch (trend) {
      case OwnerRentalDemandTrend.emerging:
        return 'Emerging';
      case OwnerRentalDemandTrend.rising:
        return 'Rising';
      case OwnerRentalDemandTrend.steady:
        return 'Steady';
      case OwnerRentalDemandTrend.softening:
        return 'Softening';
    }
  }

  static String _forecastSeasonalSignal(OwnerRentalDemandTrendItem item) {
    final signals = <String>[];

    if (item.hasHistoricalMonthSignal) {
      signals.add(
        '${item.sameMonthHistoricalCount} in ${item.sameMonthLabel} across ${item.sameMonthHistoricalYears} yr',
      );
    }
    if (item.hasPeakMonthSignal) {
      signals.add(
        'Peak: ${item.peakMonthLabel} (${item.peakMonthRequestCount})',
      );
    }
    if (item.isCurrentMonthPeak) {
      signals.add('Current month peak');
    } else if (item.isCurrentMonthAboveAverage) {
      signals.add('Current month above avg');
    }

    return signals.isEmpty ? '-' : signals.join('; ');
  }

  static String _utilizationStatus(OwnerRentalUtilizationItem item) {
    if (item.isUnderMaintenance) return 'Under maintenance';
    if (item.isMaintenanceDue) return 'Due';
    if (item.isMaintenanceUpcoming) return 'Upcoming';
    return 'Normal';
  }
}
