import 'dart:typed_data';

import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/models/renter_analytics_report.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

enum _RenterJourneyStage {
  waitingReview,
  confirmedBooking,
  inUse,
  closingOut,
  completed,
  cancelled,
  declined,
  weatherRisk,
}

class RenterAnalyticsPdfService {
  static final DateFormat _date = DateFormat('MMM d, yyyy');
  static final DateFormat _dateTime = DateFormat('MMM d, yyyy hh:mm a');
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'en_PH',
    symbol: 'PHP ',
    decimalDigits: 0,
  );

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
  };

  static const Set<RentRequestStatus> _completedStatuses = {
    RentRequestStatus.finished,
    RentRequestStatus.completed,
  };

  static String _t({
    required bool useTagalog,
    required String en,
    required String tl,
  }) => useTagalog ? tl : en;

  static String _formatCurrency(num value) => _currency.format(value.round());

  static String _formatDate(DateTime? value) =>
      value == null ? '-' : _date.format(value);

  static String _formatDateTime(DateTime? value) =>
      value == null ? '-' : _dateTime.format(value);

  static String _formatDateRange(RentRequest request) =>
      '${_date.format(request.start)} - ${_date.format(request.end)}';

  static double _requestValue(RentRequest request) {
    if (request.agreedPrice != null) return request.agreedPrice!;
    if (request.estimatedMillingFee != null) {
      return request.estimatedMillingFee!;
    }
    return 0;
  }

  static String _requestAmountLabel(RentRequest request) {
    final value = _requestValue(request);
    if (value <= 0) return '-';
    return _formatCurrency(value);
  }

  static String _formattedRequestId(String requestId) {
    final trimmed = requestId.trim();
    if (trimmed.isEmpty) return '-';

    final buffer = StringBuffer();
    for (var i = 0; i < trimmed.length; i += 8) {
      if (i > 0) buffer.write(' ');
      final end = (i + 8 < trimmed.length) ? i + 8 : trimmed.length;
      buffer.write(trimmed.substring(i, end));
    }
    return buffer.toString();
  }

  static String _requestLocation(RentRequest request) {
    final farmAddress = request.farmAddress?.trim();
    if (farmAddress != null && farmAddress.isNotEmpty) {
      return farmAddress;
    }
    return request.address.trim().isEmpty ? '-' : request.address.trim();
  }

  static List<RentRequest> _sortedRequests(Iterable<RentRequest> requests) {
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

  static List<RentRequest> _requestsForStage(
    RenterAnalyticsReport report,
    _RenterJourneyStage stage,
  ) {
    switch (stage) {
      case _RenterJourneyStage.waitingReview:
        return _sortedRequests(
          report.requests.where(
            (request) => request.status == RentRequestStatus.pending,
          ),
        );
      case _RenterJourneyStage.confirmedBooking:
        return _sortedRequests(
          report.requests.where(
            (request) => _confirmedUpcomingStatuses.contains(request.status),
          ),
        );
      case _RenterJourneyStage.inUse:
        return _sortedRequests(
          report.requests.where(
            (request) => _inUseStatuses.contains(request.status),
          ),
        );
      case _RenterJourneyStage.closingOut:
        return _sortedRequests(
          report.requests.where(
            (request) => _closingStatuses.contains(request.status),
          ),
        );
      case _RenterJourneyStage.completed:
        return _sortedRequests(
          report.requests.where(
            (request) => _completedStatuses.contains(request.status),
          ),
        );
      case _RenterJourneyStage.cancelled:
        return _sortedRequests(
          report.requests.where(
            (request) => request.status == RentRequestStatus.canceled,
          ),
        );
      case _RenterJourneyStage.declined:
        return _sortedRequests(
          report.requests.where(
            (request) => request.status == RentRequestStatus.declined,
          ),
        );
      case _RenterJourneyStage.weatherRisk:
        return _sortedRequests(
          report.requests.where((request) => request.weatherFlag),
        );
    }
  }

  static int _stageCount(
    RenterAnalyticsReport report,
    _RenterJourneyStage stage,
  ) => _requestsForStage(report, stage).length;

  static String _statusLabel(
    RentRequestStatus status, {
    required bool useTagalog,
  }) {
    switch (status) {
      case RentRequestStatus.pending:
        return _t(useTagalog: useTagalog, en: 'Pending', tl: 'Pending');
      case RentRequestStatus.approved:
        return _t(useTagalog: useTagalog, en: 'Approved', tl: 'Approved');
      case RentRequestStatus.readyForPickup:
        return _t(
          useTagalog: useTagalog,
          en: 'Ready for pickup',
          tl: 'Handa para kunin',
        );
      case RentRequestStatus.pickedUp:
        return _t(useTagalog: useTagalog, en: 'Picked up', tl: 'Nakuha na');
      case RentRequestStatus.onTheWay:
        return _t(useTagalog: useTagalog, en: 'On the way', tl: 'Papunta na');
      case RentRequestStatus.inProgress:
        return _t(useTagalog: useTagalog, en: 'In progress', tl: 'Kasalukuyan');
      case RentRequestStatus.retrieving:
        return _t(
          useTagalog: useTagalog,
          en: 'Retrieving',
          tl: 'Kinukuha pabalik',
        );
      case RentRequestStatus.returned:
        return _t(useTagalog: useTagalog, en: 'Returned', tl: 'Naibalik na');
      case RentRequestStatus.finished:
        return _t(useTagalog: useTagalog, en: 'Finished', tl: 'Tapos na');
      case RentRequestStatus.completed:
        return _t(useTagalog: useTagalog, en: 'Completed', tl: 'Nakumpleto');
      case RentRequestStatus.declined:
        return _t(useTagalog: useTagalog, en: 'Declined', tl: 'Tinanggihan');
      case RentRequestStatus.canceled:
        return _t(useTagalog: useTagalog, en: 'Cancelled', tl: 'Kinansela');
    }
  }

  static String _stageGroupLabel(
    _RenterJourneyStage stage, {
    required bool useTagalog,
  }) {
    switch (stage) {
      case _RenterJourneyStage.waitingReview:
      case _RenterJourneyStage.confirmedBooking:
      case _RenterJourneyStage.inUse:
      case _RenterJourneyStage.closingOut:
        return _t(useTagalog: useTagalog, en: 'Open now', tl: 'Bukas ngayon');
      case _RenterJourneyStage.completed:
      case _RenterJourneyStage.cancelled:
      case _RenterJourneyStage.declined:
        return _t(useTagalog: useTagalog, en: 'Closed', tl: 'Sarado');
      case _RenterJourneyStage.weatherRisk:
        return _t(useTagalog: useTagalog, en: 'Watchlist', tl: 'Watchlist');
    }
  }

  static String _stageLabel(
    _RenterJourneyStage stage, {
    required bool useTagalog,
  }) {
    switch (stage) {
      case _RenterJourneyStage.waitingReview:
        return _t(
          useTagalog: useTagalog,
          en: 'Waiting for review',
          tl: 'Naghihintay ng review',
        );
      case _RenterJourneyStage.confirmedBooking:
        return _t(
          useTagalog: useTagalog,
          en: 'Confirmed booking',
          tl: 'Kumpirmadong booking',
        );
      case _RenterJourneyStage.inUse:
        return _t(
          useTagalog: useTagalog,
          en: 'Equipment in use',
          tl: 'Kagamitang ginagamit',
        );
      case _RenterJourneyStage.closingOut:
        return _t(
          useTagalog: useTagalog,
          en: 'Return and closeout',
          tl: 'Pagbalik at pagsasara',
        );
      case _RenterJourneyStage.completed:
        return _t(
          useTagalog: useTagalog,
          en: 'Completed rentals',
          tl: 'Natapos na rental',
        );
      case _RenterJourneyStage.cancelled:
        return _t(
          useTagalog: useTagalog,
          en: 'Cancelled requests',
          tl: 'Kinanselang request',
        );
      case _RenterJourneyStage.declined:
        return _t(
          useTagalog: useTagalog,
          en: 'Declined requests',
          tl: 'Tinanggihang request',
        );
      case _RenterJourneyStage.weatherRisk:
        return _t(
          useTagalog: useTagalog,
          en: 'Weather-risk bookings',
          tl: 'Booking na may weather risk',
        );
    }
  }

  static String _stageDescription(
    _RenterJourneyStage stage, {
    required bool useTagalog,
  }) {
    switch (stage) {
      case _RenterJourneyStage.waitingReview:
        return _t(
          useTagalog: useTagalog,
          en: 'Pending requests that still need an owner decision.',
          tl: 'Mga pending request na naghihintay ng desisyon ng may-ari.',
        );
      case _RenterJourneyStage.confirmedBooking:
        return _t(
          useTagalog: useTagalog,
          en: 'Approved requests that are being prepared for pickup or delivery.',
          tl: 'Mga approved request na inihahanda para sa pickup o delivery.',
        );
      case _RenterJourneyStage.inUse:
        return _t(
          useTagalog: useTagalog,
          en: 'Rentals that are currently picked up or actively in progress.',
          tl: 'Mga rental na nakuha na o kasalukuyang ginagamit.',
        );
      case _RenterJourneyStage.closingOut:
        return _t(
          useTagalog: useTagalog,
          en: 'Rentals that are being returned or waiting for final closeout.',
          tl: 'Mga rental na ibinabalik o naghihintay ng final closeout.',
        );
      case _RenterJourneyStage.completed:
        return _t(
          useTagalog: useTagalog,
          en: 'Finished and completed rentals are both counted here.',
          tl: 'Kasama rito ang finished at completed rentals.',
        );
      case _RenterJourneyStage.cancelled:
        return _t(
          useTagalog: useTagalog,
          en: 'Requests that were cancelled before completion.',
          tl: 'Mga request na nakansela bago matapos.',
        );
      case _RenterJourneyStage.declined:
        return _t(
          useTagalog: useTagalog,
          en: 'Requests that owners declined.',
          tl: 'Mga request na tinanggihan ng may-ari.',
        );
      case _RenterJourneyStage.weatherRisk:
        return _t(
          useTagalog: useTagalog,
          en: 'Requests that were flagged by the weather monitor.',
          tl: 'Mga request na na-flag ng weather monitor.',
        );
    }
  }

  static pw.Widget _sectionTitle({
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

  static pw.Widget _metricCard({
    required String label,
    required String value,
    required pw.Font regular,
    required pw.Font bold,
    required PdfColor background,
  }) {
    return pw.Container(
      width: 165,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: background,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(font: regular, fontSize: 8.5)),
          pw.SizedBox(height: 5),
          pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 16)),
        ],
      ),
    );
  }

  static pw.Widget _infoTable({
    required List<List<String>> rows,
    required pw.Font regular,
    required pw.Font bold,
    Map<int, pw.TableColumnWidth>? columnWidths,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.7),
      columnWidths:
          columnWidths ??
          const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3)},
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

  static pw.Widget _dataTable({
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

  static pw.Widget _requestSummaryBadge({
    required String label,
    required String value,
    required pw.Font regular,
    required pw.Font bold,
    required PdfColor background,
    required PdfColor border,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: pw.BoxDecoration(
        color: background,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: border, width: 0.7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              font: regular,
              fontSize: 7.5,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 8.8)),
        ],
      ),
    );
  }

  static pw.Widget _requestDetailCard({
    required RentRequest request,
    required bool useTagalog,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    final location = _requestLocation(request);
    final statusText = _statusLabel(request.status, useTagalog: useTagalog);
    final weatherRiskText = request.weatherFlag
        ? _t(useTagalog: useTagalog, en: 'Yes', tl: 'Oo')
        : _t(useTagalog: useTagalog, en: 'No', tl: 'Hindi');

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            request.itemName,
            style: pw.TextStyle(font: bold, fontSize: 11.5),
          ),
          pw.SizedBox(height: 8),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _requestSummaryBadge(
                label: _t(useTagalog: useTagalog, en: 'Status', tl: 'Status'),
                value: statusText,
                regular: regular,
                bold: bold,
                background: PdfColors.green50,
                border: PdfColors.green200,
              ),
              _requestSummaryBadge(
                label: _t(useTagalog: useTagalog, en: 'Amount', tl: 'Halaga'),
                value: _requestAmountLabel(request),
                regular: regular,
                bold: bold,
                background: PdfColors.teal50,
                border: PdfColors.teal200,
              ),
              _requestSummaryBadge(
                label: _t(
                  useTagalog: useTagalog,
                  en: 'Weather risk',
                  tl: 'Weather risk',
                ),
                value: weatherRiskText,
                regular: regular,
                bold: bold,
                background: PdfColors.orange50,
                border: PdfColors.orange200,
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          _infoTable(
            rows: [
              [
                _t(useTagalog: useTagalog, en: 'Request ID', tl: 'Request ID'),
                _formattedRequestId(request.requestId),
              ],
              [
                _t(useTagalog: useTagalog, en: 'Submitted', tl: 'Isinumite'),
                _formatDateTime(request.createdAt),
              ],
              [
                _t(
                  useTagalog: useTagalog,
                  en: 'Rental dates',
                  tl: 'Petsa ng rental',
                ),
                _formatDateRange(request),
              ],
              [
                _t(useTagalog: useTagalog, en: 'Location', tl: 'Lokasyon'),
                location,
              ],
            ],
            regular: regular,
            bold: bold,
            columnWidths: const {
              0: pw.FlexColumnWidth(1.35),
              1: pw.FlexColumnWidth(4.65),
            },
          ),
        ],
      ),
    );
  }

  static Future<Uint8List> buildPdfBytes({
    required RenterAnalyticsReport report,
    bool useTagalog = false,
  }) async {
    final pdf = pw.Document();
    final regular = pw.Font.helvetica();
    final bold = pw.Font.helveticaBold();
    final generatedAt = _dateTime.format(report.generatedAt);
    final sortedRequests = _sortedRequests(report.requests);
    final stageRows = [
      _RenterJourneyStage.waitingReview,
      _RenterJourneyStage.confirmedBooking,
      _RenterJourneyStage.inUse,
      _RenterJourneyStage.closingOut,
      _RenterJourneyStage.completed,
      _RenterJourneyStage.cancelled,
      _RenterJourneyStage.declined,
      if (report.summary.weatherRiskBookings > 0)
        _RenterJourneyStage.weatherRisk,
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
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
            _t(
              useTagalog: useTagalog,
              en: 'My Rental Analytics Report',
              tl: 'Aking Rental Analytics Report',
            ),
            style: pw.TextStyle(
              font: bold,
              fontSize: 20,
              color: PdfColors.green800,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '${_t(useTagalog: useTagalog, en: 'Generated', tl: 'Nabuo noong')}: $generatedAt',
            style: pw.TextStyle(font: regular, fontSize: 10),
          ),
          pw.Text(
            '${_t(useTagalog: useTagalog, en: 'Total requests', tl: 'Kabuuang request')}: ${report.summary.totalRequests}',
            style: pw.TextStyle(font: regular, fontSize: 10),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.green200, width: 0.7),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  _t(
                    useTagalog: useTagalog,
                    en: 'How to read this report',
                    tl: 'Paano basahin ang report na ito',
                  ),
                  style: pw.TextStyle(font: bold, fontSize: 10),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  '1. ${_t(useTagalog: useTagalog, en: 'Only your own rental requests, completed-rental spending, and weather-risk flags are included.', tl: 'Kasama lamang dito ang sarili mong rental requests, spending sa completed rentals, at weather-risk flags.')}',
                  style: pw.TextStyle(font: regular, fontSize: 8.5),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '2. ${_t(useTagalog: useTagalog, en: 'Waiting for review means pending approval. Confirmed and active covers approved bookings, delivery steps, in-progress rentals, and closeout steps.', tl: 'Ang waiting for review ay pending approval pa lamang. Ang confirmed at active ay kasama ang approved bookings, delivery steps, in-progress rentals, at closeout steps.')}',
                  style: pw.TextStyle(font: regular, fontSize: 8.5),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  '3. ${_t(useTagalog: useTagalog, en: 'Printed request details are included because the on-screen drill-down interactions are not available on paper.', tl: 'Kasama ang printed request details dahil hindi available sa papel ang drill-down interactions sa screen.')}',
                  style: pw.TextStyle(font: regular, fontSize: 8.5),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricCard(
                label: _t(
                  useTagalog: useTagalog,
                  en: 'Waiting for review',
                  tl: 'Naghihintay ng review',
                ),
                value: report.summary.pendingRequests.toString(),
                regular: regular,
                bold: bold,
                background: PdfColors.orange50,
              ),
              _metricCard(
                label: _t(
                  useTagalog: useTagalog,
                  en: 'Confirmed and active',
                  tl: 'Kumpirmado at aktibo',
                ),
                value: report.summary.activeRentals.toString(),
                regular: regular,
                bold: bold,
                background: PdfColors.blue50,
              ),
              _metricCard(
                label: _t(
                  useTagalog: useTagalog,
                  en: 'Completed rentals',
                  tl: 'Natapos na rental',
                ),
                value: report.summary.completedRentals.toString(),
                regular: regular,
                bold: bold,
                background: PdfColors.green50,
              ),
              _metricCard(
                label: _t(
                  useTagalog: useTagalog,
                  en: 'Total spending',
                  tl: 'Kabuuang gastos',
                ),
                value: _formatCurrency(report.summary.totalSpending),
                regular: regular,
                bold: bold,
                background: PdfColors.teal50,
              ),
            ],
          ),
          _sectionTitle(
            title: _t(
              useTagalog: useTagalog,
              en: 'Request Journey',
              tl: 'Daloy ng Request',
            ),
            bold: bold,
          ),
          _dataTable(
            headers: [
              _t(useTagalog: useTagalog, en: 'Group', tl: 'Grupo'),
              _t(useTagalog: useTagalog, en: 'Stage', tl: 'Stage'),
              _t(useTagalog: useTagalog, en: 'Count', tl: 'Bilang'),
              _t(useTagalog: useTagalog, en: 'Meaning', tl: 'Kahulugan'),
            ],
            rows: stageRows
                .map(
                  (stage) => [
                    _stageGroupLabel(stage, useTagalog: useTagalog),
                    _stageLabel(stage, useTagalog: useTagalog),
                    _stageCount(report, stage).toString(),
                    _stageDescription(stage, useTagalog: useTagalog),
                  ],
                )
                .toList(),
            columnWidths: const [
              pw.FlexColumnWidth(1.1),
              pw.FlexColumnWidth(1.6),
              pw.FlexColumnWidth(0.7),
              pw.FlexColumnWidth(3.1),
            ],
            regular: regular,
            bold: bold,
          ),
        ],
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: pw.TextStyle(font: regular, fontSize: 8),
          ),
        ),
        build: (context) => [
          _sectionTitle(
            title: _t(
              useTagalog: useTagalog,
              en: 'Spending and Timing',
              tl: 'Gastos at Timing',
            ),
            bold: bold,
          ),
          _infoTable(
            rows: [
              [
                _t(
                  useTagalog: useTagalog,
                  en: 'Total requests',
                  tl: 'Kabuuang request',
                ),
                report.summary.totalRequests.toString(),
              ],
              [
                _t(
                  useTagalog: useTagalog,
                  en: 'Total spending',
                  tl: 'Kabuuang gastos',
                ),
                _formatCurrency(report.summary.totalSpending),
              ],
              [
                _t(
                  useTagalog: useTagalog,
                  en: 'Average rental duration',
                  tl: 'Karaniwang tagal ng rental',
                ),
                '${report.summary.averageRentalDurationDays.toStringAsFixed(1)} ${_t(useTagalog: useTagalog, en: 'days', tl: 'araw')}',
              ],
              [
                _t(
                  useTagalog: useTagalog,
                  en: 'First request',
                  tl: 'Unang request',
                ),
                _formatDate(report.firstRequestAt),
              ],
              [
                _t(
                  useTagalog: useTagalog,
                  en: 'Latest request',
                  tl: 'Pinakabagong request',
                ),
                _formatDate(report.lastRequestAt),
              ],
            ],
            regular: regular,
            bold: bold,
          ),
          _sectionTitle(
            title: _t(
              useTagalog: useTagalog,
              en: 'Most-used Equipment Categories',
              tl: 'Pinakaginagamit na Category ng Kagamitan',
            ),
            bold: bold,
          ),
          if (report.categoryUsage.isEmpty)
            pw.Text(
              _t(
                useTagalog: useTagalog,
                en: 'No category usage data is available yet.',
                tl: 'Wala pang available na category usage data.',
              ),
              style: pw.TextStyle(font: regular, fontSize: 9),
            )
          else
            _dataTable(
              headers: [
                _t(useTagalog: useTagalog, en: 'Category', tl: 'Category'),
                _t(useTagalog: useTagalog, en: 'Requests', tl: 'Requests'),
                _t(useTagalog: useTagalog, en: 'Completed', tl: 'Completed'),
                _t(useTagalog: useTagalog, en: 'Spending', tl: 'Spending'),
              ],
              rows: report.categoryUsage
                  .map(
                    (item) => [
                      item.categoryLabel,
                      item.requestCount.toString(),
                      item.completedRentals.toString(),
                      _formatCurrency(item.totalSpending),
                    ],
                  )
                  .toList(),
              columnWidths: const [
                pw.FlexColumnWidth(2.2),
                pw.FlexColumnWidth(1),
                pw.FlexColumnWidth(1),
                pw.FlexColumnWidth(1.2),
              ],
              regular: regular,
              bold: bold,
            ),
          _sectionTitle(
            title: _t(
              useTagalog: useTagalog,
              en: 'Request Details',
              tl: 'Detalye ng mga Request',
            ),
            bold: bold,
          ),
          pw.Text(
            _t(
              useTagalog: useTagalog,
              en: 'Printed request details are grouped into summary cards so long request references and locations stay readable.',
              tl: 'Ipinapangkat ang printed request details sa mga summary card para manatiling malinaw ang mahahabang request reference at lokasyon.',
            ),
            style: pw.TextStyle(font: regular, fontSize: 8.5),
          ),
          pw.SizedBox(height: 8),
          if (sortedRequests.isEmpty)
            pw.Text(
              _t(
                useTagalog: useTagalog,
                en: 'No request records are available.',
                tl: 'Walang available na request records.',
              ),
              style: pw.TextStyle(font: regular, fontSize: 9),
            )
          else
            ...sortedRequests.map(
              (request) => _requestDetailCard(
                request: request,
                useTagalog: useTagalog,
                regular: regular,
                bold: bold,
              ),
            ),
        ],
      ),
    );

    return pdf.save();
  }

  static Future<void> printOrSavePdf({
    required RenterAnalyticsReport report,
    bool useTagalog = false,
  }) async {
    final bytes = await buildPdfBytes(report: report, useTagalog: useTagalog);
    final fileDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'my_rental_analytics_$fileDate.pdf',
    );
  }
}
