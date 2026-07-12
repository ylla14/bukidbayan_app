import 'package:bukidbayan_app/components/rent/proof_page_viewer.dart';
import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/models/campaign_report.dart';
import 'package:bukidbayan_app/services/campaign_report_pdf_service.dart';
import 'package:bukidbayan_app/services/crowdfunding_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/utils/money_format.dart';
import 'package:flutter/material.dart';

enum _SupporterSortOption {
  amountHighToLow,
  amountLowToHigh,
  newestFirst,
  oldestFirst,
}

enum _SupporterRewardFilter { all, withReward, withoutReward }

class _InfoRow {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});
}

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
  late final TextEditingController _supporterSearchController;
  bool _isExporting = false;
  _SupporterSortOption _supporterSort = _SupporterSortOption.amountHighToLow;
  _SupporterRewardFilter _supporterRewardFilter = _SupporterRewardFilter.all;
  String _supporterSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _service = widget.serviceOverride ?? CrowdfundingService();
    _supporterSearchController = TextEditingController(
      text: _supporterSearchQuery,
    );
    _future = _service.generateCampaignReport(
      campaignId: widget.campaignId,
      userEmail: widget.userEmailOverride,
    );
  }

  @override
  void dispose() {
    _supporterSearchController.dispose();
    super.dispose();
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

  String _supporterLabel(Pledge pledge) {
    if (pledge.backerName != null && pledge.backerName!.trim().isNotEmpty) {
      return pledge.backerName!.trim();
    }
    if (pledge.backerEmail != null && pledge.backerEmail!.trim().isNotEmpty) {
      return pledge.backerEmail!.trim();
    }
    return 'Anonymous supporter';
  }

  String _rewardTitleForPledge({
    required Pledge pledge,
    required Map<String, String> rewardTitleById,
  }) {
    final rewardId = pledge.rewardId;
    if (rewardId == null || rewardId.trim().isEmpty) return '-';
    final rewardTitle = rewardTitleById[rewardId];
    if (rewardTitle == null || rewardTitle.trim().isEmpty) return '-';
    return rewardTitle.trim();
  }

  String _sortOptionLabel(_SupporterSortOption option) {
    switch (option) {
      case _SupporterSortOption.amountHighToLow:
        return 'Halaga: pinakamalaki -> pinakamababa';
      case _SupporterSortOption.amountLowToHigh:
        return 'Halaga: pinakamababa -> pinakamalaki';
      case _SupporterSortOption.newestFirst:
        return 'Petsa: pinakabago muna';
      case _SupporterSortOption.oldestFirst:
        return 'Petsa: pinakaluma muna';
    }
  }

  String _rewardFilterLabel(_SupporterRewardFilter filter) {
    switch (filter) {
      case _SupporterRewardFilter.all:
        return 'Lahat';
      case _SupporterRewardFilter.withReward:
        return 'May benepisyo';
      case _SupporterRewardFilter.withoutReward:
        return 'Walang benepisyo';
    }
  }

  String _formatPercent(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  List<Pledge> _buildVisibleSupporters({
    required CampaignReport report,
    required Map<String, String> rewardTitleById,
  }) {
    final query = _supporterSearchQuery.trim().toLowerCase();

    final filtered = report.pledges.where((pledge) {
      final hasReward =
          pledge.rewardId != null && pledge.rewardId!.trim().isNotEmpty;
      if (_supporterRewardFilter == _SupporterRewardFilter.withReward &&
          !hasReward) {
        return false;
      }
      if (_supporterRewardFilter == _SupporterRewardFilter.withoutReward &&
          hasReward) {
        return false;
      }
      if (query.isEmpty) return true;

      final searchable = <String>[
        _supporterLabel(pledge),
        pledge.backerEmail ?? '',
        pledge.backerPhone ?? '',
        pledge.backerNote ?? '',
        _rewardTitleForPledge(pledge: pledge, rewardTitleById: rewardTitleById),
      ].join(' ').toLowerCase();

      return searchable.contains(query);
    }).toList();

    filtered.sort((a, b) {
      int compare;
      switch (_supporterSort) {
        case _SupporterSortOption.amountHighToLow:
          compare = b.amount.compareTo(a.amount);
          if (compare != 0) return compare;
          return b.createdAt.compareTo(a.createdAt);
        case _SupporterSortOption.amountLowToHigh:
          compare = a.amount.compareTo(b.amount);
          if (compare != 0) return compare;
          return a.createdAt.compareTo(b.createdAt);
        case _SupporterSortOption.newestFirst:
          compare = b.createdAt.compareTo(a.createdAt);
          if (compare != 0) return compare;
          return b.amount.compareTo(a.amount);
        case _SupporterSortOption.oldestFirst:
          compare = a.createdAt.compareTo(b.createdAt);
          if (compare != 0) return compare;
          return a.amount.compareTo(b.amount);
      }
    });

    return filtered;
  }

  Widget _buildInfoTable({
    required List<_InfoRow> rows,
    TextAlign valueAlign = TextAlign.right,
  }) {
    if (rows.isEmpty) {
      return const Text('-');
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
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
                    horizontal: 10,
                    vertical: 9,
                  ),
                  child: Text(
                    rows[i].label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  child: Text(rows[i].value, textAlign: valueAlign),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRewardPerformanceTable(CampaignReport report) {
    if (report.campaign.rewards.isEmpty) {
      return const Text('Walang reward tiers sa campaign na ito.');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        headingRowColor: WidgetStateProperty.resolveWith(
          (_) => lightColorScheme.primary.withValues(alpha: 0.08),
        ),
        columns: const [
          DataColumn(label: Text('Benepisyo')),
          DataColumn(label: Text('Minimum')),
          DataColumn(label: Text('Pledges')),
          DataColumn(label: Text('Nakalap')),
        ],
        rows: [
          ...report.rewardBreakdown.map(
            (item) => DataRow(
              cells: [
                DataCell(
                  SizedBox(
                    width: 210,
                    child: Text(
                      item.rewardTier.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(Text(formatPeso(item.rewardTier.minPledge))),
                DataCell(Text(item.pledgeCount.toString())),
                DataCell(Text(formatPeso(item.totalAmount))),
              ],
            ),
          ),
          if (report.noRewardPledgeCount > 0)
            DataRow(
              color: WidgetStateProperty.resolveWith(
                (_) => Colors.grey.shade100,
              ),
              cells: [
                const DataCell(
                  Text(
                    'Walang napiling benepisyo',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const DataCell(Text('-')),
                DataCell(Text(report.noRewardPledgeCount.toString())),
                DataCell(
                  Text(
                    formatPeso(report.noRewardAmount),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentFunnelSection(CampaignReport report) {
    final funnel = report.paymentFunnel;
    if (!funnel.hasAttempts) {
      return const Text('Wala pang payment attempts para sa campaign na ito.');
    }

    final pledgeCaptureRate = funnel.totalAttempts == 0
        ? 0.0
        : report.totalPledges / funnel.totalAttempts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoTable(
          rows: [
            _InfoRow(
              label: 'Kabuuang payment attempts',
              value: funnel.totalAttempts.toString(),
            ),
            _InfoRow(
              label: 'Active checkout attempts',
              value: funnel.activeCheckoutCount.toString(),
            ),
            _InfoRow(
              label: 'Paid attempts',
              value: funnel.paidCount.toString(),
            ),
            _InfoRow(
              label: 'Failed attempts',
              value: funnel.failedCount.toString(),
            ),
            _InfoRow(
              label: 'Cancelled attempts',
              value: funnel.cancelledCount.toString(),
            ),
            _InfoRow(
              label: 'Expired attempts',
              value: funnel.expiredCount.toString(),
            ),
            _InfoRow(
              label: 'Refunded attempts',
              value: funnel.refundedCount.toString(),
            ),
            _InfoRow(
              label: 'Kabuuang attempted amount',
              value: formatPeso(funnel.totalAttemptAmount),
            ),
            _InfoRow(
              label: 'Kabuuang paid amount',
              value: formatPeso(funnel.paidAttemptAmount),
            ),
            _InfoRow(
              label: 'Attempt -> paid conversion',
              value: _formatPercent(funnel.paidConversionRate),
            ),
            _InfoRow(
              label: 'Attempt -> pledge capture',
              value: _formatPercent(pledgeCaptureRate),
            ),
            _InfoRow(
              label: 'Unang payment attempt',
              value: _formatDate(funnel.firstAttemptAt),
            ),
            _InfoRow(
              label: 'Huling payment attempt',
              value: _formatDate(funnel.lastAttemptAt),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 18,
            headingRowColor: WidgetStateProperty.resolveWith(
              (_) => lightColorScheme.primary.withValues(alpha: 0.08),
            ),
            columns: const [
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Attempts'), numeric: true),
            ],
            rows: [
              DataRow(
                cells: [
                  const DataCell(Text('Created')),
                  DataCell(Text(funnel.createdCount.toString())),
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(Text('Pending checkout')),
                  DataCell(Text(funnel.pendingCheckoutCount.toString())),
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(Text('Processing')),
                  DataCell(Text(funnel.processingCount.toString())),
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(Text('Paid')),
                  DataCell(Text(funnel.paidCount.toString())),
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(Text('Failed')),
                  DataCell(Text(funnel.failedCount.toString())),
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(Text('Cancelled')),
                  DataCell(Text(funnel.cancelledCount.toString())),
                ],
              ),
              DataRow(
                cells: [
                  const DataCell(Text('Expired')),
                  DataCell(Text(funnel.expiredCount.toString())),
                ],
              ),
              if (funnel.refundedCount > 0)
                DataRow(
                  cells: [
                    const DataCell(Text('Refunded')),
                    DataCell(Text(funnel.refundedCount.toString())),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Magkaibang linya ang pledges at payment attempts. Ginagamit ang funnel para makita ang checkout conversion, hindi para palitan ang pledge totals.',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildSupportersTable(CampaignReport report) {
    if (report.pledges.isEmpty) {
      return const Text('Walang pledge records para sa campaign na ito.');
    }

    final rewardTitleById = {
      for (final reward in report.campaign.rewards) reward.id: reward.title,
    };

    final visibleSupporters = _buildVisibleSupporters(
      report: report,
      rewardTitleById: rewardTitleById,
    );

    final filteredTotalAmount = visibleSupporters
        .where((pledge) => pledge.countedInTotal)
        .fold<int>(0, (sum, pledge) => sum + pledge.amount);
    final filteredPendingAmount = visibleSupporters
        .where((pledge) => pledge.isUnresolved)
        .fold<int>(0, (sum, pledge) => sum + pledge.amount);
    final filteredInvalidAmount = visibleSupporters
        .where((pledge) => pledge.isInvalidated)
        .fold<int>(0, (sum, pledge) => sum + pledge.amount);
    final overallTotalAmount = report.pledges
        .where((pledge) => pledge.countedInTotal)
        .fold<int>(0, (sum, pledge) => sum + pledge.amount);
    final isFiltered =
        _supporterSearchQuery.trim().isNotEmpty ||
        _supporterRewardFilter != _SupporterRewardFilter.all;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final useSingleColumn = maxWidth < 700;
            final sortWidth = useSingleColumn ? maxWidth : 280.0;
            final filterWidth = useSingleColumn ? maxWidth : 210.0;
            final searchWidth = useSingleColumn ? maxWidth : 280.0;

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: sortWidth,
                  child: DropdownButtonFormField<_SupporterSortOption>(
                    key: const Key('supporter_sort_dropdown'),
                    initialValue: _supporterSort,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Ayusin ang supporters',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _SupporterSortOption.values
                        .map(
                          (option) => DropdownMenuItem(
                            value: option,
                            child: Text(
                              _sortOptionLabel(option),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _supporterSort = value);
                    },
                  ),
                ),
                SizedBox(
                  width: filterWidth,
                  child: DropdownButtonFormField<_SupporterRewardFilter>(
                    key: const Key('supporter_reward_filter_dropdown'),
                    initialValue: _supporterRewardFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Filter',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _SupporterRewardFilter.values
                        .map(
                          (option) => DropdownMenuItem(
                            value: option,
                            child: Text(
                              _rewardFilterLabel(option),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _supporterRewardFilter = value);
                    },
                  ),
                ),
                SizedBox(
                  width: searchWidth,
                  child: TextField(
                    key: const Key('supporter_search_field'),
                    controller: _supporterSearchController,
                    decoration: InputDecoration(
                      labelText: 'Hanap supporter',
                      hintText: 'Pangalan, email, benepisyo...',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: _supporterSearchQuery.trim().isNotEmpty
                          ? IconButton(
                              tooltip: 'I-clear',
                              onPressed: () {
                                _supporterSearchController.clear();
                                setState(() => _supporterSearchQuery = '');
                              },
                              icon: const Icon(Icons.close),
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() => _supporterSearchQuery = value);
                    },
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          isFiltered
              ? 'Naka-filter: ${visibleSupporters.length} sa ${report.pledges.length} pledges'
              : 'Kabuuang pledges: ${report.pledges.length}',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        if (visibleSupporters.isEmpty)
          const Text('Walang tumugmang supporter sa kasalukuyang filter.')
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 16,
              headingRowColor: WidgetStateProperty.resolveWith(
                (_) => lightColorScheme.primary.withValues(alpha: 0.1),
              ),
              columns: const [
                DataColumn(label: Text('Supporter')),
                DataColumn(label: Text('Contact')),
                DataColumn(label: Text('Benepisyo')),
                DataColumn(label: Text('Petsa')),
                DataColumn(label: Text('Halaga'), numeric: true),
                DataColumn(label: Text('Tala')),
                DataColumn(label: Text('Patunay')),
              ],
              rows: [
                ...visibleSupporters.map((pledge) {
                  final supporterLabel = _supporterLabel(pledge);
                  final rewardTitle = _rewardTitleForPledge(
                    pledge: pledge,
                    rewardTitleById: rewardTitleById,
                  );
                  final contact =
                      (pledge.backerPhone != null &&
                          pledge.backerPhone!.trim().isNotEmpty)
                      ? pledge.backerPhone!.trim()
                      : ((pledge.backerEmail != null &&
                                pledge.backerEmail!.trim().isNotEmpty)
                            ? pledge.backerEmail!.trim()
                            : '-');
                  final note =
                      (pledge.backerNote != null &&
                          pledge.backerNote!.trim().isNotEmpty)
                      ? pledge.backerNote!.trim()
                      : '-';

                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 170,
                          child: Text(
                            supporterLabel,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 180,
                          child: Text(
                            contact,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 170,
                          child: Text(
                            rewardTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text(_formatDate(pledge.createdAt))),
                      DataCell(
                        Text(
                          formatPeso(pledge.amount),
                          key: Key('supporter_amount_${pledge.id}'),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 220,
                          child: Tooltip(
                            message: note,
                            child: Text(
                              note,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      DataCell(_buildProofCell(pledge)),
                    ],
                  );
                }),
                DataRow(
                  color: WidgetStateProperty.resolveWith(
                    (_) => lightColorScheme.primary.withValues(alpha: 0.08),
                  ),
                  cells: [
                    DataCell(
                      Text(
                        'Kabuuan (${visibleSupporters.length} pledges)',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                        key: const Key('supporter_totals_label'),
                      ),
                    ),
                    const DataCell(Text('-')),
                    DataCell(
                      Text(
                        isFiltered ? 'Naka-filter' : 'Lahat',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const DataCell(Text('-')),
                    DataCell(
                      Text(
                        formatPeso(filteredTotalAmount),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                        key: const Key('supporter_totals_amount'),
                      ),
                    ),
                    DataCell(
                      Text(
                        isFiltered
                            ? 'Overall: ${report.pledges.length} pledges, ${formatPeso(overallTotalAmount)}'
                            : 'Overall total',
                      ),
                    ),
                    DataCell(
                      Text(
                        [
                              if (filteredPendingAmount > 0)
                                'Naghihintay: ${formatPeso(filteredPendingAmount)}',
                              if (filteredInvalidAmount > 0)
                                'Invalid: ${formatPeso(filteredInvalidAmount)}',
                            ].isEmpty
                            ? '-'
                            : [
                                if (filteredPendingAmount > 0)
                                  'Naghihintay: ${formatPeso(filteredPendingAmount)}',
                                if (filteredInvalidAmount > 0)
                                  'Invalid: ${formatPeso(filteredInvalidAmount)}',
                              ].join(' • '),
                        key: const Key('supporter_pending_amount'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProofCell(Pledge pledge) {
    if (pledge.isInvalidated) {
      return Chip(
        label: const Text('Invalid'),
        backgroundColor: Colors.red.shade50,
        labelStyle: TextStyle(
          color: Colors.red.shade800,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    if (pledge.isCanceled) {
      return Chip(
        label: const Text('Canceled'),
        backgroundColor: Colors.grey.shade200,
        labelStyle: TextStyle(
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    final imageUrl = pledge.proofImageUrl?.trim();
    final referenceNumber = pledge.proofReferenceNumber?.trim();

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProofViewerPage(urls: [imageUrl], initialIndex: 0),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.network(
            imageUrl,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
          ),
        ),
      );
    }

    if (referenceNumber != null && referenceNumber.isNotEmpty) {
      return Chip(
        label: Text(referenceNumber, style: const TextStyle(fontSize: 11)),
        visualDensity: VisualDensity.compact,
      );
    }

    return Chip(
      label: const Text('Naghihintay', style: TextStyle(fontSize: 11)),
      backgroundColor: Colors.grey.shade200,
      visualDensity: VisualDensity.compact,
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
                        snapshot.error.toString().replaceFirst(
                          'Exception: ',
                          '',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
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
          final targetProgressColor = report.fundingDifference >= 0
              ? Colors.green
              : Colors.orange;
          final remainingDays = campaign.endDate
              .difference(DateTime.now())
              .inDays
              .clamp(0, 99999);

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
                                  backgroundColor: lightColorScheme.primary
                                      .withValues(alpha: 0.12),
                                  labelStyle: TextStyle(
                                    color: lightColorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  side: BorderSide(
                                    color: lightColorScheme.primary.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ),
                              Chip(
                                label: Text(outcomeLabel),
                                backgroundColor: outcomeColor.withValues(
                                  alpha: 0.14,
                                ),
                                labelStyle: TextStyle(
                                  color: outcomeColor,
                                  fontWeight: FontWeight.w700,
                                ),
                                side: BorderSide(
                                  color: outcomeColor.withValues(alpha: 0.35),
                                ),
                              ),
                              if (isOngoing)
                                Chip(
                                  label: Text(targetProgressLabel),
                                  backgroundColor: targetProgressColor
                                      .withValues(alpha: 0.14),
                                  labelStyle: TextStyle(
                                    color: targetProgressColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  side: BorderSide(
                                    color: targetProgressColor.withValues(
                                      alpha: 0.35,
                                    ),
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
                          color: lightColorScheme.primary.withValues(
                            alpha: 0.25,
                          ),
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
                    title: isOngoing
                        ? 'Kasalukuyang Buod ng Pondo'
                        : 'Buod ng Pondo',
                    children: [
                      _buildInfoTable(
                        rows: [
                          _InfoRow(
                            label: 'Kabuuang nakalap',
                            value: formatPeso(report.totalRaised),
                          ),
                          _InfoRow(
                            label: 'Target na pondo',
                            value: formatPeso(campaign.goalAmount),
                          ),
                          _InfoRow(
                            label: differenceLabel,
                            value: formatPeso(differenceValue),
                          ),
                          _InfoRow(
                            label: 'Supporters',
                            value: report.totalBackers.toString(),
                          ),
                          _InfoRow(
                            label: 'Bilang ng pledges',
                            value: report.totalPledges.toString(),
                          ),
                          _InfoRow(
                            label: 'Average pledge',
                            value: formatPeso(report.averagePledge.round()),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _buildSection(
                    title: 'Payment Funnel',
                    children: [_buildPaymentFunnelSection(report)],
                  ),
                  _buildSection(
                    title: 'Timeline ng Kampanya',
                    children: [
                      _buildInfoTable(
                        rows: [
                          _InfoRow(
                            label: 'Simula ng campaign',
                            value: _formatDate(startDate),
                          ),
                          _InfoRow(
                            label: 'Petsa ng pagtatapos',
                            value: _formatDate(campaign.endDate),
                          ),
                          _InfoRow(
                            label: 'Tagal (araw)',
                            value: report.campaignDurationDays.toString(),
                          ),
                          _InfoRow(
                            label: 'Natitirang araw',
                            value: remainingDays.toString(),
                          ),
                          _InfoRow(
                            label: 'Unang pledge',
                            value: _formatDate(report.firstPledgeAt),
                          ),
                          _InfoRow(
                            label: 'Huling pledge',
                            value: _formatDate(report.lastPledgeAt),
                          ),
                        ],
                      ),
                    ],
                  ),
                  _buildSection(
                    title: 'Performance ng Benepisyo',
                    children: [_buildRewardPerformanceTable(report)],
                  ),
                  _buildSection(
                    title: 'Listahan ng Supporters',
                    children: [_buildSupportersTable(report)],
                  ),
                  _buildSection(
                    title: 'Operational Notes',
                    children: [
                      _buildInfoTable(
                        valueAlign: TextAlign.left,
                        rows: [
                          _InfoRow(
                            label: 'Timeline ng pagpapatupad',
                            value: campaign.productionTimeline ?? '-',
                          ),
                          _InfoRow(
                            label: 'Saklaw ng delivery',
                            value: campaign.shippingCoverage ?? '-',
                          ),
                          _InfoRow(
                            label: 'Paghawak sa delivery cost',
                            value: campaign.shippingCostHandling ?? '-',
                          ),
                          _InfoRow(
                            label: 'Shipping notes',
                            value: campaign.shippingNotes ?? '-',
                          ),
                          _InfoRow(
                            label: 'Warranty',
                            value: campaign.warranty ?? '-',
                          ),
                          _InfoRow(
                            label: 'Spare parts',
                            value: campaign.spareParts ?? '-',
                          ),
                          _InfoRow(
                            label: 'Mga panganib',
                            value: campaign.risks ?? '-',
                          ),
                          _InfoRow(
                            label: 'Paalala sa kaligtasan',
                            value: campaign.safetyNotes ?? '-',
                          ),
                        ],
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
