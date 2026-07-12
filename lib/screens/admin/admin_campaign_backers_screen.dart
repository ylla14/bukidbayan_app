import 'package:bukidbayan_app/components/rent/proof_page_viewer.dart';
import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/models/campaign_support_summary.dart';
import 'package:bukidbayan_app/services/crowdfunding_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/utils/money_format.dart';
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';
import 'package:flutter/material.dart';

class AdminCampaignBackersScreen extends StatefulWidget {
  final String campaignId;
  final String campaignTitle;
  final CrowdfundingService? serviceOverride;

  const AdminCampaignBackersScreen({
    super.key,
    required this.campaignId,
    required this.campaignTitle,
    this.serviceOverride,
  });

  @override
  State<AdminCampaignBackersScreen> createState() =>
      _AdminCampaignBackersScreenState();
}

class _AdminCampaignBackersData {
  final Campaign? campaign;
  final List<Pledge> pledges;

  const _AdminCampaignBackersData({
    required this.campaign,
    required this.pledges,
  });
}

class _SupporterGroup {
  final String key;
  final String displayName;
  final String contactLabel;
  final CampaignSupportSummary summary;
  final List<Pledge> pledges;

  const _SupporterGroup({
    required this.key,
    required this.displayName,
    required this.contactLabel,
    required this.summary,
    required this.pledges,
  });
}

class _AdminCampaignBackersScreenState
    extends State<AdminCampaignBackersScreen> {
  late final CrowdfundingService _service;
  late Future<_AdminCampaignBackersData> _future;

  @override
  void initState() {
    super.initState();
    _service = widget.serviceOverride ?? CrowdfundingService();
    _future = _loadData();
  }

  Future<_AdminCampaignBackersData> _loadData() async {
    final campaign = await _service.getCampaignById(widget.campaignId);
    final pledges = await _service.getPledgesForCampaign(widget.campaignId);
    return _AdminCampaignBackersData(campaign: campaign, pledges: pledges);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _loadData();
    });
    await _future;
  }

  String _formatDate(DateTime date) {
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

  String _contactLabel(Pledge pledge) {
    final phone = pledge.backerPhone?.trim();
    if (phone != null && phone.isNotEmpty) return phone;
    final email = pledge.backerEmail?.trim();
    if (email != null && email.isNotEmpty) return email;
    return 'No contact info';
  }

  CampaignSupportSummary _summaryForGroup({
    required List<Pledge> pledges,
    required List<RewardTier> rewards,
    required String groupKey,
  }) {
    final built = CampaignSupportSummary.build(
      campaignId: widget.campaignId,
      rewards: rewards,
      pledges: pledges,
      supporterUid: pledges.first.backerUid,
      supporterEmail: pledges.first.backerEmail,
    );
    if (built != null) return built;

    var countedAmount = 0;
    var pendingAmount = 0;
    var invalidAmount = 0;
    var countedCount = 0;
    var pendingCount = 0;
    var invalidCount = 0;
    DateTime? lastContributionAt;

    for (final pledge in pledges) {
      if (lastContributionAt == null ||
          pledge.createdAt.isAfter(lastContributionAt)) {
        lastContributionAt = pledge.createdAt;
      }
      if (pledge.isInvalidated) {
        invalidAmount += pledge.amount;
        invalidCount += 1;
      } else if (pledge.isCountedContribution) {
        countedAmount += pledge.amount;
        countedCount += 1;
      } else {
        pendingAmount += pledge.amount;
        pendingCount += 1;
      }
    }

    return CampaignSupportSummary(
      campaignId: widget.campaignId,
      supporterKey: groupKey,
      supporterUid: pledges.first.backerUid,
      supporterEmail: pledges.first.backerEmail,
      countedContributionTotal: countedAmount,
      pendingContributionTotal: pendingAmount,
      invalidContributionTotal: invalidAmount,
      countedPledgeCount: countedCount,
      pendingPledgeCount: pendingCount,
      invalidPledgeCount: invalidCount,
      activeReward: CampaignSupportSummary.highestEligibleReward(
        rewards,
        countedAmount,
      ),
      lastContributionAt: lastContributionAt,
    );
  }

  List<_SupporterGroup> _buildGroups(_AdminCampaignBackersData data) {
    final grouped = <String, List<Pledge>>{};

    for (final pledge in data.pledges) {
      final key =
          CampaignSupportSummary.supporterKeyFromPledge(pledge) ??
          'anonymous:${pledge.id}';
      grouped.putIfAbsent(key, () => []).add(pledge);
    }

    final groups = grouped.entries.map((entry) {
      final pledges = [...entry.value]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final first = pledges.first;
      return _SupporterGroup(
        key: entry.key,
        displayName: _supporterLabel(first),
        contactLabel: _contactLabel(first),
        summary: _summaryForGroup(
          pledges: pledges,
          rewards: data.campaign?.rewards ?? const [],
          groupKey: entry.key,
        ),
        pledges: pledges,
      );
    }).toList();

    groups.sort((a, b) {
      final amountCompare = b.summary.countedContributionTotal.compareTo(
        a.summary.countedContributionTotal,
      );
      if (amountCompare != 0) return amountCompare;
      final aDate = a.summary.lastContributionAt ?? DateTime(1970);
      final bDate = b.summary.lastContributionAt ?? DateTime(1970);
      return bDate.compareTo(aDate);
    });

    return groups;
  }

  Color _statusColor(Pledge pledge) {
    if (pledge.isInvalidated) return Colors.red.shade700;
    if (pledge.isCanceled) return Colors.grey.shade700;
    if (pledge.isPendingProof) return Colors.orange.shade800;
    return Colors.green.shade700;
  }

  String _statusLabel(Pledge pledge) {
    if (pledge.isInvalidated) return 'Invalidated';
    if (pledge.isCanceled) return 'Canceled';
    if (pledge.isPendingProof) return 'Pending proof';
    return 'Counted';
  }

  Future<void> _markContributionInvalid(Pledge pledge) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Mark Contribution Invalid'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will remove ${formatPeso(pledge.amount)} from the campaign totals but keep the record for review.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  hintText: 'Halimbawa: malabong screenshot o maling reference',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Mark Invalid'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _service.invalidateContribution(
        campaignId: widget.campaignId,
        pledgeId: pledge.id,
        reason: reasonController.text.trim(),
      );
      if (!mounted) return;
      showConfirmSnackbar(
        context: context,
        title: 'Contribution invalidated',
        message:
            'The contribution record was kept, removed from totals, and the supporter was notified.',
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(
        context: context,
        title: 'Could not invalidate',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      reasonController.dispose();
    }
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildProofPreview(Pledge pledge) {
    final imageUrl = pledge.proofImageUrl?.trim();
    final referenceNumber = pledge.proofReferenceNumber?.trim();

    if (pledge.isCanceled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Canceled'),
      );
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      return InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProofViewerPage(urls: [imageUrl], initialIndex: 0),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imageUrl,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 72,
              height: 72,
              color: Colors.grey.shade100,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
      );
    }

    if (referenceNumber != null && referenceNumber.isNotEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Ref: $referenceNumber',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text('No proof yet'),
    );
  }

  Widget _buildContributionCard(Pledge pledge) {
    final reason = pledge.invalidationReason?.trim();
    final note = pledge.backerNote?.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatPeso(pledge.amount),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submitted ${_formatDate(pledge.createdAt)}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(pledge).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(pledge),
                  style: TextStyle(
                    color: _statusColor(pledge),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildProofPreview(pledge),
              if (note != null && note.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Text(
                    note,
                    style: TextStyle(color: Colors.grey.shade800, height: 1.35),
                  ),
                ),
            ],
          ),
          if (pledge.isInvalidated && reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Reason: $reason',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (pledge.isCountedContribution) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _markContributionInvalid(pledge),
                icon: const Icon(Icons.gpp_bad_outlined),
                label: const Text('Mark Invalid'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade200),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupporterCard(_SupporterGroup group) {
    final reward = group.summary.activeReward;
    final lastContributionAt = group.summary.lastContributionAt;

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: lightColorScheme.primary.withValues(
                    alpha: 0.1,
                  ),
                  foregroundColor: lightColorScheme.primary,
                  child: Text(
                    group.displayName.trim().isEmpty
                        ? '?'
                        : group.displayName.trim()[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        group.contactLabel,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      if (lastContributionAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Latest contribution: ${_formatDate(lastContributionAt)}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Counted ${formatPeso(group.summary.countedContributionTotal)}',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (group.summary.pendingContributionTotal > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Pending ${formatPeso(group.summary.pendingContributionTotal)}',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (group.summary.invalidContributionTotal > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Invalid ${formatPeso(group.summary.invalidContributionTotal)}',
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (reward != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: lightColorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Active benefit: ${reward.title}',
                      style: TextStyle(
                        color: lightColorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Column(
              children: [
                for (var i = 0; i < group.pledges.length; i++) ...[
                  _buildContributionCard(group.pledges[i]),
                  if (i != group.pledges.length - 1) const SizedBox(height: 10),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.campaignTitle.isEmpty
              ? 'Campaign Backers'
              : widget.campaignTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: lightColorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<_AdminCampaignBackersData>(
          future: _future,
          builder: (context, snapshot) {
            final data = snapshot.data;
            final pledges = data?.pledges ?? const <Pledge>[];
            if (snapshot.connectionState == ConnectionState.waiting &&
                pledges.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final groups = data == null
                ? const <_SupporterGroup>[]
                : _buildGroups(data);
            final countedAmount = groups.fold<int>(
              0,
              (sum, group) => sum + group.summary.countedContributionTotal,
            );
            final pendingAmount = groups.fold<int>(
              0,
              (sum, group) => sum + group.summary.pendingContributionTotal,
            );
            final invalidAmount = groups.fold<int>(
              0,
              (sum, group) => sum + group.summary.invalidContributionTotal,
            );
            final activeSupporters = groups
                .where((group) => group.summary.countedPledgeCount > 0)
                .length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Review each supporter’s proof, contribution history, and active benefit. Invalid contributions stay on record but can be removed from the totals instantly.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 900
                        ? (constraints.maxWidth - 24) / 4
                        : constraints.maxWidth >= 600
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: width,
                          child: _buildMetricCard(
                            label: 'Active supporters',
                            value: activeSupporters.toString(),
                            icon: Icons.people_alt_outlined,
                            color: lightColorScheme.primary,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _buildMetricCard(
                            label: 'Counted amount',
                            value: formatPeso(countedAmount),
                            icon: Icons.payments_outlined,
                            color: Colors.green.shade700,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _buildMetricCard(
                            label: 'Pending proof',
                            value: formatPeso(pendingAmount),
                            icon: Icons.hourglass_top_rounded,
                            color: Colors.orange.shade800,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _buildMetricCard(
                            label: 'Invalidated amount',
                            value: formatPeso(invalidAmount),
                            icon: Icons.gpp_bad_outlined,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                if (groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text('Wala pang backer para sa campaign na ito.'),
                    ),
                  )
                else
                  ...groups.map(
                    (group) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildSupporterCard(group),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
