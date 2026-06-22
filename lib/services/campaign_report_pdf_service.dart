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

  static String _formatPercent(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  static pw.Widget _buildSectionTitle({
    required String title,
    required pw.Font bold,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6, top: 12),
      child: pw.Text(title, style: pw.TextStyle(font: bold, fontSize: 13)),
    );
  }

  static pw.Widget _buildInfoTable({
    required List<List<String>> rows,
    required pw.Font regular,
    required pw.Font bold,
  }) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.7),
      columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3)},
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

  static Future<Uint8List> buildPdfBytes({
    required CampaignReport report,
  }) async {
    final doc = pw.Document();
    final regular = await PdfGoogleFonts.nunitoRegular();
    final bold = await PdfGoogleFonts.nunitoBold();

    final campaign = report.campaign;
    final generatedAt = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
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
    final remainingDays = campaign.endDate
        .difference(DateTime.now())
        .inDays
        .clamp(0, 99999);

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
                  campaign.title.isEmpty
                      ? '(Untitled Campaign)'
                      : campaign.title,
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
          _buildSectionTitle(
            title: isOngoing ? 'Current Funding Summary' : 'Funding Summary',
            bold: bold,
          ),
          _buildInfoTable(
            rows: [
              ['Total raised', _formatCurrency(report.totalRaised)],
              ['Goal amount', _formatCurrency(campaign.goalAmount)],
              [
                isOngoing ? 'Current status' : 'Final result',
                shortfallOrSurplus,
              ],
              ['Supporters', report.totalBackers.toString()],
              ['Pledges', report.totalPledges.toString()],
              ['Average pledge', _formatCurrency(report.averagePledge.round())],
            ],
            regular: regular,
            bold: bold,
          ),
          _buildSectionTitle(title: 'Payment Funnel', bold: bold),
          if (!report.paymentFunnel.hasAttempts)
            pw.Text(
              'No payment attempts available for this campaign.',
              style: pw.TextStyle(font: regular, fontSize: 10),
            )
          else ...[
            _buildInfoTable(
              rows: [
                [
                  'Total payment attempts',
                  report.paymentFunnel.totalAttempts.toString(),
                ],
                [
                  'Active checkout attempts',
                  report.paymentFunnel.activeCheckoutCount.toString(),
                ],
                ['Paid attempts', report.paymentFunnel.paidCount.toString()],
                [
                  'Failed attempts',
                  report.paymentFunnel.failedCount.toString(),
                ],
                [
                  'Cancelled attempts',
                  report.paymentFunnel.cancelledCount.toString(),
                ],
                [
                  'Expired attempts',
                  report.paymentFunnel.expiredCount.toString(),
                ],
                [
                  'Refunded attempts',
                  report.paymentFunnel.refundedCount.toString(),
                ],
                [
                  'Total attempted amount',
                  _formatCurrency(report.paymentFunnel.totalAttemptAmount),
                ],
                [
                  'Total paid amount',
                  _formatCurrency(report.paymentFunnel.paidAttemptAmount),
                ],
                [
                  'Attempt -> paid conversion',
                  _formatPercent(report.paymentFunnel.paidConversionRate),
                ],
                [
                  'Attempt -> pledge capture',
                  _formatPercent(
                    report.paymentFunnel.totalAttempts == 0
                        ? 0
                        : report.totalPledges /
                              report.paymentFunnel.totalAttempts,
                  ),
                ],
                [
                  'First payment attempt',
                  _formatDate(report.paymentFunnel.firstAttemptAt),
                ],
                [
                  'Last payment attempt',
                  _formatDate(report.paymentFunnel.lastAttemptAt),
                ],
              ],
              regular: regular,
              bold: bold,
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Pledges and payment attempts are tracked separately. The funnel shows checkout conversion and does not replace pledge totals.',
              style: pw.TextStyle(
                font: regular,
                fontSize: 9,
                color: PdfColors.grey700,
              ),
            ),
          ],
          _buildSectionTitle(title: 'Timeline', bold: bold),
          _buildInfoTable(
            rows: [
              [
                'Start',
                _formatDate(campaign.publishedAt ?? campaign.createdAt),
              ],
              ['End', _formatDate(campaign.endDate)],
              ['Days remaining', remainingDays.toString()],
              ['First pledge', _formatDate(report.firstPledgeAt)],
              ['Last pledge', _formatDate(report.lastPledgeAt)],
            ],
            regular: regular,
            bold: bold,
          ),
          _buildSectionTitle(title: 'Reward Performance', bold: bold),
          if (campaign.rewards.isEmpty)
            pw.Text(
              'No reward tiers in this campaign.',
              style: pw.TextStyle(font: regular, fontSize: 10),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
              columnWidths: const {
                0: pw.FlexColumnWidth(3),
                1: pw.FlexColumnWidth(1.5),
                2: pw.FlexColumnWidth(1.4),
                3: pw.FlexColumnWidth(1.8),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.green700),
                  children: ['Reward', 'Minimum', 'Pledges', 'Amount'].map((
                    text,
                  ) {
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
                ...report.rewardBreakdown.map((item) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          item.rewardTier.title,
                          style: pw.TextStyle(font: regular, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          _formatCurrency(item.rewardTier.minPledge),
                          style: pw.TextStyle(font: regular, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          item.pledgeCount.toString(),
                          style: pw.TextStyle(font: regular, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          _formatCurrency(item.totalAmount),
                          style: pw.TextStyle(font: regular, fontSize: 9),
                        ),
                      ),
                    ],
                  );
                }),
                if (report.noRewardPledgeCount > 0)
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'No selected reward',
                          style: pw.TextStyle(font: bold, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          '-',
                          style: pw.TextStyle(font: regular, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          report.noRewardPledgeCount.toString(),
                          style: pw.TextStyle(font: regular, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          _formatCurrency(report.noRewardAmount),
                          style: pw.TextStyle(font: bold, fontSize: 9),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          _buildSectionTitle(title: 'Supporters', bold: bold),
          if (report.pledges.isEmpty)
            pw.Text(
              'No pledge records available.',
              style: pw.TextStyle(font: regular, fontSize: 10),
            )
          else ...[
            () {
              final rewardTitleById = {
                for (final reward in campaign.rewards) reward.id: reward.title,
              };
              final supporters = [...report.pledges]
                ..sort((a, b) {
                  final amountCompare = b.amount.compareTo(a.amount);
                  if (amountCompare != 0) return amountCompare;
                  return b.createdAt.compareTo(a.createdAt);
                });
              final totalAmount = supporters.fold<int>(
                0,
                (sum, pledge) => sum + pledge.amount,
              );

              return pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.6,
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(2.4),
                  1: pw.FlexColumnWidth(2.1),
                  2: pw.FlexColumnWidth(2.0),
                  3: pw.FlexColumnWidth(1.4),
                  4: pw.FlexColumnWidth(1.6),
                  5: pw.FlexColumnWidth(2.5),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.green700,
                    ),
                    children:
                        [
                          'Supporter',
                          'Contact',
                          'Reward',
                          'Date',
                          'Amount',
                          'Note',
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
                  ...supporters.map((pledge) {
                    final donor =
                        (pledge.backerName != null &&
                            pledge.backerName!.trim().isNotEmpty)
                        ? pledge.backerName!.trim()
                        : ((pledge.backerEmail != null &&
                                  pledge.backerEmail!.trim().isNotEmpty)
                              ? pledge.backerEmail!.trim()
                              : 'Anonymous');
                    final contact =
                        (pledge.backerPhone != null &&
                            pledge.backerPhone!.trim().isNotEmpty)
                        ? pledge.backerPhone!.trim()
                        : ((pledge.backerEmail != null &&
                                  pledge.backerEmail!.trim().isNotEmpty)
                              ? pledge.backerEmail!.trim()
                              : '-');
                    final rewardTitle =
                        (pledge.rewardId == null || pledge.rewardId!.isEmpty)
                        ? '-'
                        : (rewardTitleById[pledge.rewardId] ?? '-');
                    final note =
                        (pledge.backerNote != null &&
                            pledge.backerNote!.trim().isNotEmpty)
                        ? pledge.backerNote!.trim()
                        : '-';

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
                            contact,
                            style: pw.TextStyle(font: regular, fontSize: 9),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            rewardTitle,
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
                            note,
                            style: pw.TextStyle(font: regular, fontSize: 9),
                          ),
                        ),
                      ],
                    );
                  }),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.green50,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'TOTAL (${supporters.length} pledges)',
                          style: pw.TextStyle(font: bold, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          '-',
                          style: pw.TextStyle(font: regular, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          '-',
                          style: pw.TextStyle(font: regular, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          '-',
                          style: pw.TextStyle(font: regular, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          _formatCurrency(totalAmount),
                          style: pw.TextStyle(font: bold, fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Overall total',
                          style: pw.TextStyle(font: regular, fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }(),
          ],
          _buildSectionTitle(title: 'Operational Notes', bold: bold),
          _buildInfoTable(
            rows: [
              ['Production timeline', campaign.productionTimeline ?? '-'],
              ['Shipping coverage', campaign.shippingCoverage ?? '-'],
              ['Shipping cost handling', campaign.shippingCostHandling ?? '-'],
              ['Shipping notes', campaign.shippingNotes ?? '-'],
              ['Warranty', campaign.warranty ?? '-'],
              ['Spare parts', campaign.spareParts ?? '-'],
              ['Risks', campaign.risks ?? '-'],
              ['Safety notes', campaign.safetyNotes ?? '-'],
            ],
            regular: regular,
            bold: bold,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Supporter table in PDF is sorted by amount (highest to lowest).',
            style: pw.TextStyle(
              font: regular,
              fontSize: 9,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static Future<void> printOrSavePdf({required CampaignReport report}) async {
    final bytes = await buildPdfBytes(report: report);
    final fileDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'campaign_report_$fileDate.pdf',
    );
  }
}
