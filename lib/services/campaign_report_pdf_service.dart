import 'dart:typed_data';

import 'package:bukidbayan_app/models/campaign_report.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class CampaignReportPdfService {
  static String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String _formatCurrency(int value) {
    return NumberFormat.currency(
      symbol: 'PHP ',
      decimalDigits: 0,
    ).format(value);
  }

  static Future<Uint8List> buildPdfBytes({
    required CampaignReport report,
  }) async {
    final doc = pw.Document();
    final regular = await PdfGoogleFonts.nunitoRegular();
    final bold = await PdfGoogleFonts.nunitoBold();

    final campaign = report.campaign;
    final generatedAt = DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(DateTime.now());
    final isOngoing = !report.isEnded;
    final outcome = isOngoing
        ? 'Ongoing (interim report)'
        : (report.isSuccessful ? 'Successful' : 'Did not reach goal');
    final shortfallOrSurplus = report.fundingDifference >= 0
        ? (isOngoing
            ? 'Ahead of goal by: ${_formatCurrency(report.fundingDifference)}'
            : 'Surplus: ${_formatCurrency(report.fundingDifference)}')
        : (isOngoing
            ? 'Remaining to goal: ${_formatCurrency(-report.fundingDifference)}'
            : 'Shortfall: ${_formatCurrency(-report.fundingDifference)}');
    final remainingDays =
        campaign.endDate.difference(DateTime.now()).inDays.clamp(0, 99999);

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
            'Campaign Report',
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
          if (isOngoing) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'Note: This is an interim report while the campaign is still running.',
              style: pw.TextStyle(font: regular, fontSize: 10),
            ),
          ],
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(8),
              color: PdfColors.green50,
              border: pw.Border.all(color: PdfColors.green200),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  campaign.title.isEmpty ? '(Untitled Campaign)' : campaign.title,
                  style: pw.TextStyle(font: bold, fontSize: 14),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Category: ${campaign.category}',
                  style: pw.TextStyle(font: regular, fontSize: 10),
                ),
                pw.Text(
                  'Outcome: $outcome',
                  style: pw.TextStyle(font: regular, fontSize: 10),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            isOngoing ? 'Current Funding Summary' : 'Funding Summary',
            style: pw.TextStyle(font: bold, fontSize: 13),
          ),
          pw.SizedBox(height: 6),
          pw.Bullet(
            text: 'Total raised: ${_formatCurrency(report.totalRaised)}',
            style: pw.TextStyle(font: regular, fontSize: 10),
          ),
          pw.Bullet(
            text: 'Goal amount: ${_formatCurrency(campaign.goalAmount)}',
            style: pw.TextStyle(font: regular, fontSize: 10),
          ),
          pw.Bullet(
            text: shortfallOrSurplus,
            style: pw.TextStyle(font: regular, fontSize: 10),
          ),
          pw.Bullet(
            text:
                'Backers: ${report.totalBackers} | Pledges: ${report.totalPledges} | Avg pledge: ${_formatCurrency(report.averagePledge.round())}',
            style: pw.TextStyle(font: regular, fontSize: 10),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Timeline',
            style: pw.TextStyle(font: bold, fontSize: 13),
          ),
          pw.SizedBox(height: 6),
          pw.Bullet(
            text: 'Start: ${_formatDate(campaign.publishedAt ?? campaign.createdAt)}',
            style: pw.TextStyle(font: regular, fontSize: 10),
          ),
          pw.Bullet(
            text: 'End: ${_formatDate(campaign.endDate)}',
            style: pw.TextStyle(font: regular, fontSize: 10),
          ),
          pw.Bullet(
            text: 'Days remaining: $remainingDays',
            style: pw.TextStyle(font: regular, fontSize: 10),
          ),
          pw.Bullet(
            text:
                'First pledge: ${_formatDate(report.firstPledgeAt)} | Last pledge: ${_formatDate(report.lastPledgeAt)}',
            style: pw.TextStyle(font: regular, fontSize: 10),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Supporters',
            style: pw.TextStyle(font: bold, fontSize: 13),
          ),
          pw.SizedBox(height: 6),
          if (report.pledges.isEmpty)
            pw.Text(
              'No pledge records available.',
              style: pw.TextStyle(font: regular, fontSize: 10),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(3),
                2: pw.FlexColumnWidth(2),
                3: pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.green700),
                  children: [
                    'Name / Email',
                    'Contact / Note',
                    'Amount',
                    'Date',
                  ].map((text) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        text,
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 9,
                          color: PdfColors.white,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                ...report.pledges.map((pledge) {
                  final donor =
                      (pledge.backerName != null &&
                          pledge.backerName!.trim().isNotEmpty)
                      ? pledge.backerName!.trim()
                      : ((pledge.backerEmail != null &&
                                pledge.backerEmail!.trim().isNotEmpty)
                            ? pledge.backerEmail!.trim()
                            : 'Anonymous');
                  final contactBits = <String>[];
                  if (pledge.backerPhone != null &&
                      pledge.backerPhone!.trim().isNotEmpty) {
                    contactBits.add(pledge.backerPhone!.trim());
                  }
                  if (pledge.backerNote != null &&
                      pledge.backerNote!.trim().isNotEmpty) {
                    contactBits.add(pledge.backerNote!.trim());
                  }
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          donor,
                          style: pw.TextStyle(font: regular, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          contactBits.isEmpty ? '-' : contactBits.join(' | '),
                          style: pw.TextStyle(font: regular, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          _formatCurrency(pledge.amount),
                          style: pw.TextStyle(font: regular, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          _formatDate(pledge.createdAt),
                          style: pw.TextStyle(font: regular, fontSize: 9),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
        ],
      ),
    );

    return doc.save();
  }

  static Future<void> printOrSavePdf({
    required CampaignReport report,
  }) async {
    final bytes = await buildPdfBytes(report: report);
    final fileDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'campaign_report_$fileDate.pdf',
    );
  }
}
