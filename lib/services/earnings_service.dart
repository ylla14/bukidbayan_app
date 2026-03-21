// lib/services/earnings_service.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/models/equipment.dart';

class EarningsPdfService {
  // ── Shared PDF builder — used by both download and print ──
  static Future<Uint8List> buildPdfBytes({
    required List<({RentRequest request, Equipment? equipment})> rows,
    required double totalEarnings,
    required String ownerName,
    DateTimeRange? dateRange,
    String? searchQuery,
    String? equipmentFilter,
    String? operatorFilter,
    double? minPayment,
    double? maxPayment,
  }) async {
    final pdf = pw.Document();
    final currency = NumberFormat.currency(symbol: 'PHP ', decimalDigits: 2);
    final dateFormat = DateFormat('MMM d, yyyy');
    final now = DateFormat('MMMM d, yyyy – hh:mm a').format(DateTime.now());

    // ── Fonts ──────────────────────────────────────────────
    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final fontItalic = await PdfGoogleFonts.nunitoItalic();

    // ── Styles ─────────────────────────────────────────────
    final styleTitle = pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.green800);
    final styleSubtitle = pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700);
    final styleHeaderCell = pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white);
    final styleBodyCell = pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey900);
    final styleMoney = pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.green800);
    final styleSummaryLabel = pw.TextStyle(font: fontRegular, fontSize: 10, color: PdfColors.grey700);
    final styleSummaryValue = pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.green900);
    final styleFooter = pw.TextStyle(font: fontItalic, fontSize: 7, color: PdfColors.grey500);
    final styleFilterLabel = pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.amber900);
    final styleFilterValue = pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey800);

    // ── Column headers ─────────────────────────────────────
    const headers = [
      '#',
      'Date Rented',
      'Farmer Name',
      'Farm Location',
      'Equipment',
      'Price Rate',      // NEW — was 'W/ Operator'
      'Rate Unit',
      'Days',
      'Area / Vol.',
      'Payment',
    ];

    // ── Build rows ─────────────────────────────────────────
    final dataRows = rows.map((r) {
  final req = r.request;
  final eq = r.equipment;
  final days = req.end.difference(req.start).inDays.clamp(1, 9999);

  // Price rate: ₱X.XX / rentalUnit
  final priceRate = eq != null
      ? '${currency.format(eq.price)}'
      : '—';

  String measurement = '—';
  if (req.hectaresEntered != null) {
    measurement = '${req.hectaresEntered!.toStringAsFixed(2)} ha';
  } else if (req.volumeSubmitted != null) {
    measurement = '${req.volumeSubmitted!.toStringAsFixed(1)} kg';
  }

  final isPerDay = req.agreedRentalUnit?.toLowerCase().contains('day') == true;

  double? totalPayment;
  if (req.estimatedMillingFee != null && req.estimatedMillingFee! > 0) {
    totalPayment = req.estimatedMillingFee;
  } else {
    totalPayment = req.agreedPrice;
  }

  return [
    '',                                                          // # (filled later)
    dateFormat.format(req.start),                               // Date
    req.name,                                                    // Farmer
    req.farmAddress ?? req.address,                             // Location
    req.itemName,                                               // Equipment
    priceRate,                                                   // Price Rate (NEW)
    req.agreedRentalUnit ?? '—',                                // Rate Unit
    isPerDay ? '$days d' : '—',                                 // Days
    measurement,                                                 // Area/Vol
    totalPayment != null ? currency.format(totalPayment) : '—', // Payment
  ];
}).toList();

    // Fill index column
    for (int i = 0; i < dataRows.length; i++) {
      dataRows[i][0] = '${i + 1}';
    }

    // ── Column flex widths ─────────────────────────────────
    const colWidths = [3, 9, 13, 15, 13, 12, 8, 5, 8, 11];
    // ── Check if any filters are active ───────────────────
    final hasFilters = searchQuery != null ||
        equipmentFilter != null ||
        operatorFilter != null ||
        minPayment != null ||
        maxPayment != null ||
        dateRange != null;

    // ── Build page ─────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}  •  Generated: $now',
            style: styleFooter,
          ),
        ),
        build: (context) => [
          // ── Header ───────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Earnings Report', style: styleTitle),
                    pw.SizedBox(height: 4),
                    pw.Text('Owner: $ownerName', style: styleSubtitle),
                    if (dateRange != null)
                      pw.Text(
                        'Period: ${dateFormat.format(dateRange.start)} – ${dateFormat.format(dateRange.end)}',
                        style: styleSubtitle,
                      )
                    else
                      pw.Text('Period: All time', style: styleSubtitle),
                    pw.Text('Generated: $now', style: styleSubtitle),

                    // ── Active filters block ──────────────
                    if (hasFilters) ...[
                      pw.SizedBox(height: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.amber50,
                          borderRadius: pw.BorderRadius.circular(6),
                          border: pw.Border.all(color: PdfColors.amber200),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Filters Applied to This Report:',
                                style: styleFilterLabel),
                            pw.SizedBox(height: 4),
                            if (dateRange != null)
                              pw.Text(
                                '• Date Range: ${dateFormat.format(dateRange.start)} – ${dateFormat.format(dateRange.end)}',
                                style: styleFilterValue,
                              ),
                            if (searchQuery != null)
                              pw.Text(
                                '• Search Keyword: "$searchQuery"',
                                style: styleFilterValue,
                              ),
                            if (equipmentFilter != null)
                              pw.Text(
                                '• Equipment: $equipmentFilter',
                                style: styleFilterValue,
                              ),
                            if (operatorFilter != null)
                              pw.Text(
                                '• With Operator: ${operatorFilter == 'yes' ? 'Yes only' : 'No operator only'}',
                                style: styleFilterValue,
                              ),
                            if (minPayment != null || maxPayment != null)
                              pw.Text(
                                '• Payment Range: ${minPayment != null ? currency.format(minPayment) : 'any'} – ${maxPayment != null ? currency.format(maxPayment) : 'any'}',
                                style: styleFilterValue,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              // ── Summary box ──────────────────────────────
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green800,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Total Earnings',
                        style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 9,
                            color: PdfColors.white)),
                    pw.SizedBox(height: 2),
                    pw.Text(currency.format(totalEarnings),
                        style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 16,
                            color: PdfColors.white)),
                    pw.SizedBox(height: 6),
                    pw.Text('Transactions',
                        style: pw.TextStyle(
                            font: fontRegular,
                            fontSize: 9,
                            color: PdfColors.white)),
                    pw.SizedBox(height: 2),
                    pw.Text('${rows.length}',
                        style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 16,
                            color: PdfColors.white)),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 16),
          pw.Divider(color: PdfColors.green200, thickness: 1),
          pw.SizedBox(height: 10),

          // ── Table ─────────────────────────────────────────
          pw.Table(
            columnWidths: {
              for (int i = 0; i < colWidths.length; i++)
                i: pw.FlexColumnWidth(colWidths[i].toDouble()),
            },
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              // Header row
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.green800),
                children: headers
                    .map(
                      (h) => pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4, vertical: 5),
                        child: pw.Text(h, style: styleHeaderCell),
                      ),
                    )
                    .toList(),
              ),
              // Data rows
              ...dataRows.asMap().entries.map((entry) {
                final isEven = entry.key % 2 == 0;
                final cells = entry.value;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: isEven ? PdfColors.white : PdfColors.green50,
                  ),
                  children: cells.asMap().entries.map((c) {
                    final isPayment = c.key == 9;
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      child: pw.Text(
                        c.value,
                        style: isPayment ? styleMoney : styleBodyCell,
                        textAlign: isPayment
                            ? pw.TextAlign.right
                            : pw.TextAlign.left,
                      ),
                    );
                  }).toList(),
                );
              }),
            ],
          ),

          pw.SizedBox(height: 14),

          // ── Totals footer ─────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.green200),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Text(
                  'Total Earnings from ${rows.length} Completed Rental${rows.length != 1 ? 's' : ''}:  ',
                  style: styleSummaryLabel,
                ),
                pw.Text(currency.format(totalEarnings),
                    style: styleSummaryValue),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ── Convenience wrapper — kept for any legacy calls ────────
  static Future<void> generateAndShare({
    required List<({RentRequest request, Equipment? equipment})> rows,
    required double totalEarnings,
    required String ownerName,
    DateTimeRange? dateRange,
    String? searchQuery,
    String? equipmentFilter,
    String? operatorFilter,
    double? minPayment,
    double? maxPayment,
  }) async {
    final bytes = await buildPdfBytes(
      rows: rows,
      totalEarnings: totalEarnings,
      ownerName: ownerName,
      dateRange: dateRange,
      searchQuery: searchQuery,
      equipmentFilter: equipmentFilter,
      operatorFilter: operatorFilter,
      minPayment: minPayment,
      maxPayment: maxPayment,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'earnings_report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
    );
  }
}