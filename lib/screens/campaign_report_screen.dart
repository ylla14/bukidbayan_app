import 'package:bukidbayan_app/models/campaign_report.dart';
import 'package:bukidbayan_app/services/campaign_report_pdf_service.dart';
import 'package:bukidbayan_app/services/crowdfunding_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/utils/money_format.dart';
import 'package:flutter/material.dart';

class CampaignReportScreen extends StatefulWidget {
  final String campaignId;
  final CrowdfundingService? serviceOverride;
  final String? userEmailOverride;

  const CampaignReportScreen({
    super.key,
    required this.campaignId,
    this.serviceOverride,
    this.userEmailOverride,
  });

  @override
  State<CampaignReportScreen> createState() => _CampaignReportScreenState();
}

class _CampaignReportScreenState extends State<CampaignReportScreen> {
  late final CrowdfundingService _service;
  late Future<CampaignReport> _future;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _service = widget.serviceOverride ?? CrowdfundingService();
    _future = _service.generateCampaignReport(
      campaignId: widget.campaignId,
      userEmail: widget.userEmailOverride,
    );
  }

  Future<void> _reload() async {
    setState(() {
      _future = _service.generateCampaignReport(
        campaignId: widget.campaignId,
        userEmail: widget.userEmailOverride,
      );
    });
    await _future;
  }

  Future<void> _printReport(CampaignReport report) async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    try {
      await CampaignReportPdfService.printOrSavePdf(report: report);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Hindi na-print ang report: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: lightColorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final campaignTheme = Theme.of(context).copyWith(
      scaffoldBackgroundColor: Colors.white,
      cardTheme: Theme.of(context).cardTheme.copyWith(
            color: Colors.white,
            surfaceTintColor: Colors.transparent,
          ),
    );

    return Theme(
      data: campaignTheme,
      child: FutureBuilder<CampaignReport>(
        future: _future,
        builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Ulat ng Kampanya'),
              backgroundColor: lightColorScheme.primary,
              foregroundColor: Colors.white,
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snapshot.error.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Subukan ulit'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final report = snapshot.data;
        if (report == null) {
          return const Scaffold(
            body: Center(child: Text('Walang report na nahanap.')),
          );
        }

        final campaign = report.campaign;
        final startDate = campaign.publishedAt ?? campaign.createdAt;
        final isOngoing = !report.isEnded;
        final differenceLabel = report.fundingDifference >= 0
            ? (isOngoing ? 'Lamang sa target' : 'Sobra')
            : (isOngoing ? 'Kulang pa sa target' : 'Kulang');
        final differenceValue = report.fundingDifference >= 0
            ? report.fundingDifference
            : -report.fundingDifference;
        final outcomeLabel = isOngoing
            ? 'Kasalukuyang Ulat'
            : (report.isSuccessful ? 'Matagumpay' : 'Hindi umabot');
        final outcomeColor = isOngoing
            ? lightColorScheme.primary
            : (report.isSuccessful ? Colors.green : Colors.red);
        final targetProgressLabel = report.fundingDifference >= 0
            ? 'Naabot na ang target'
            : 'Hindi pa abot ang target';
        final targetProgressColor =
            report.fundingDifference >= 0 ? Colors.green : Colors.orange;
        final remainingDays =
            campaign.endDate.difference(DateTime.now()).inDays.clamp(0, 99999);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isOngoing
                  ? 'Kasalukuyang Ulat ng Kampanya'
                  : 'Ulat ng Kampanya',
            ),
            backgroundColor: lightColorScheme.primary,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'Print / Save as PDF',
                onPressed: _isExporting ? null : () => _printReport(report),
                icon: _isExporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print_outlined),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          campaign.title.isEmpty
                              ? '(Walang Pamagat)'
                              : campaign.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(label: Text(campaign.category)),
                            if (isOngoing)
                              Chip(
                                label: const Text('Tumatakbo pa'),
                                backgroundColor:
                                    lightColorScheme.primary.withOpacity(0.12),
                                labelStyle: TextStyle(
                                  color: lightColorScheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                                side: BorderSide(
                                  color:
                                      lightColorScheme.primary.withOpacity(0.35),
                                ),
                              ),
                            Chip(
                              label: Text(outcomeLabel),
                              backgroundColor: outcomeColor.withOpacity(0.14),
                              labelStyle: TextStyle(
                                color: outcomeColor,
                                fontWeight: FontWeight.w700,
                              ),
                              side: BorderSide(
                                color: outcomeColor.withOpacity(0.35),
                              ),
                            ),
                            if (isOngoing)
                              Chip(
                                label: Text(targetProgressLabel),
                                backgroundColor:
                                    targetProgressColor.withOpacity(0.14),
                                labelStyle: TextStyle(
                                  color: targetProgressColor,
                                  fontWeight: FontWeight.w700,
                                ),
                                side: BorderSide(
                                  color: targetProgressColor.withOpacity(0.35),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isOngoing
                              ? 'Nakalap ngayon: ${formatPeso(report.totalRaised)} mula sa target na ${formatPeso(campaign.goalAmount)}'
                              : 'Nakalap: ${formatPeso(report.totalRaised)} mula sa target na ${formatPeso(campaign.goalAmount)}',
                        ),
                      ],
                    ),
                  ),
                ),
                if (isOngoing)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: lightColorScheme.primary.withOpacity(0.25),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Interim report ito habang tumatanggap pa ng pledges ang campaign. Maaaring magbago ang totals at metrics hanggang sa pagtatapos.',
                        style: TextStyle(color: Colors.grey.shade800),
                      ),
                    ),
                  ),
                _buildSection(
                  title: isOngoing ? 'Kasalukuyang Buod ng Pondo' : 'Buod ng Pondo',
                  children: [
                    _buildRow(
                      label: 'Kabuuang nakalap',
                      value: formatPeso(report.totalRaised),
                    ),
                    _buildRow(
                      label: 'Target na pondo',
                      value: formatPeso(campaign.goalAmount),
                    ),
                    _buildRow(
                      label: differenceLabel,
                      value: formatPeso(differenceValue),
                    ),
                    _buildRow(
                      label: 'Supporters',
                      value: report.totalBackers.toString(),
                    ),
                    _buildRow(
                      label: 'Bilang ng pledges',
                      value: report.totalPledges.toString(),
                    ),
                    _buildRow(
                      label: 'Average pledge',
                      value: formatPeso(report.averagePledge.round()),
                    ),
                  ],
                ),
                _buildSection(
                  title: 'Timeline ng Kampanya',
                  children: [
                    _buildRow(
                      label: 'Simula ng campaign',
                      value: _formatDate(startDate),
                    ),
                    _buildRow(
                      label: 'Petsa ng pagtatapos',
                      value: _formatDate(campaign.endDate),
                    ),
                    _buildRow(
                      label: 'Tagal (araw)',
                      value: report.campaignDurationDays.toString(),
                    ),
                    _buildRow(
                      label: 'Natitirang araw',
                      value: remainingDays.toString(),
                    ),
                    _buildRow(
                      label: 'Unang pledge',
                      value: _formatDate(report.firstPledgeAt),
                    ),
                    _buildRow(
                      label: 'Huling pledge',
                      value: _formatDate(report.lastPledgeAt),
                    ),
                  ],
                ),
                _buildSection(
                  title: 'Performance ng Benepisyo',
                  children: [
                    if (campaign.rewards.isEmpty)
                      const Text('Walang reward tiers sa campaign na ito.')
                    else
                      ...report.rewardBreakdown.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.grey.shade100,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.rewardTier.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Minimum: ${formatPeso(item.rewardTier.minPledge)}',
                                ),
                                Text(
                                  'Napiling pledges: ${item.pledgeCount}',
                                ),
                                Text(
                                  'Nakalap mula rito: ${formatPeso(item.totalAmount)}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (report.noRewardPledgeCount > 0) ...[
                      const SizedBox(height: 4),
                      _buildRow(
                        label: 'Pledges na walang reward',
                        value: report.noRewardPledgeCount.toString(),
                      ),
                      _buildRow(
                        label: 'Halaga (walang reward)',
                        value: formatPeso(report.noRewardAmount),
                      ),
                    ],
                  ],
                ),
                _buildSection(
                  title: 'Listahan ng Supporters',
                  children: [
                    if (report.pledges.isEmpty)
                      const Text('Walang pledge records para sa campaign na ito.')
                    else
                      ...report.pledges.map((pledge) {
                        final rewardTitle = campaign.rewards
                            .where((reward) => reward.id == pledge.rewardId)
                            .map((reward) => reward.title)
                            .cast<String?>()
                            .firstWhere(
                              (title) => title != null,
                              orElse: () => null,
                            );
                        final supporterLabel =
                            (pledge.backerName != null &&
                                pledge.backerName!.trim().isNotEmpty)
                            ? pledge.backerName!.trim()
                            : ((pledge.backerEmail != null &&
                                      pledge.backerEmail!.trim().isNotEmpty)
                                  ? pledge.backerEmail!.trim()
                                  : 'Anonymous supporter');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.grey.shade100,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  supporterLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('Halaga: ${formatPeso(pledge.amount)}'),
                                Text('Petsa: ${_formatDate(pledge.createdAt)}'),
                                if (pledge.backerEmail != null &&
                                    pledge.backerEmail!.trim().isNotEmpty)
                                  Text('Email: ${pledge.backerEmail}'),
                                if (pledge.backerPhone != null &&
                                    pledge.backerPhone!.trim().isNotEmpty)
                                  Text('Contact: ${pledge.backerPhone}'),
                                if (rewardTitle != null && rewardTitle.isNotEmpty)
                                  Text('Benepisyo: $rewardTitle'),
                                if (pledge.backerNote != null &&
                                    pledge.backerNote!.trim().isNotEmpty)
                                  Text('Tala: ${pledge.backerNote}'),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
                _buildSection(
                  title: 'Operational Notes',
                  children: [
                    _buildRow(
                      label: 'Timeline ng pagpapatupad',
                      value: campaign.productionTimeline ?? '-',
                    ),
                    _buildRow(
                      label: 'Saklaw ng delivery',
                      value: campaign.shippingCoverage ?? '-',
                    ),
                    _buildRow(
                      label: 'Paghawak sa delivery cost',
                      value: campaign.shippingCostHandling ?? '-',
                    ),
                    _buildRow(
                      label: 'Shipping notes',
                      value: campaign.shippingNotes ?? '-',
                    ),
                    _buildRow(
                      label: 'Warranty',
                      value: campaign.warranty ?? '-',
                    ),
                    _buildRow(
                      label: 'Spare parts',
                      value: campaign.spareParts ?? '-',
                    ),
                    _buildRow(
                      label: 'Mga panganib',
                      value: campaign.risks ?? '-',
                    ),
                    _buildRow(
                      label: 'Paalala sa kaligtasan',
                      value: campaign.safetyNotes ?? '-',
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
        },
      ),
    );
  }
}
