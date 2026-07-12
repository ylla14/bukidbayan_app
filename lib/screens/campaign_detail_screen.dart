import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/models/campaign_support_summary.dart';
import 'package:bukidbayan_app/services/cloudinary_service.dart';
import 'package:bukidbayan_app/services/crowdfunding_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/utils/money_format.dart';
import 'package:bukidbayan_app/widgets/campaign_cover_image.dart';
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class CampaignDetailScreen extends StatefulWidget {
  final String campaignId;

  const CampaignDetailScreen({super.key, required this.campaignId});

  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  static const Map<String, String> _categoryLabels = {
    'Irrigation': 'Patubig',
    'Crop Care': 'Pangangalaga ng Pananim',
    'Post-harvest': 'Pagkatapos ng Ani',
    'Mechanized Tools': 'Mekanikal na Kagamitan',
    'Livestock': 'Alagang Hayop',
    'Solar/Power': 'Solar/Kuryente',
    'Hand Tools': 'Kagamitang Kamay',
    'Other': 'Iba pa',
  };

  final CrowdfundingService service = CrowdfundingService();
  late Future<Campaign?> _future;
  Future<List<Pledge>>? _pendingPledgesFuture;
  Future<CampaignSupportSummary?>? _supportSummaryFuture;

  String _categoryLabel(String value) => _categoryLabels[value] ?? value;

  TextStyle _sectionTitleStyle(BuildContext context) {
    return Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: lightColorScheme.primary,
        ) ??
        TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: lightColorScheme.primary,
        );
  }

  TextStyle _actionLabelStyle(BuildContext context, {Color? color}) {
    return Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: color,
        ) ??
        TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: color,
        );
  }

  @override
  void initState() {
    super.initState();
    _future = service.getCampaignById(widget.campaignId);
    _pendingPledgesFuture = service.getMyPendingPledgesForCampaign(
      widget.campaignId,
    );
    _supportSummaryFuture = service.getMySupportSummary(widget.campaignId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = service.getCampaignById(widget.campaignId);
      _pendingPledgesFuture = service.getMyPendingPledgesForCampaign(
        widget.campaignId,
      );
      _supportSummaryFuture = service.getMySupportSummary(widget.campaignId);
    });
    await _future;
  }

  bool _isCampaignEnded(Campaign campaign) {
    return campaign.status.startsWith('ended') ||
        DateTime.now().isAfter(campaign.endDate);
  }

  bool _hasGcashQr(Campaign campaign) =>
      campaign.gcashQrImage?.trim().isNotEmpty == true;

  bool _isOwnedByCurrentUser(Campaign campaign) {
    String? email;
    String? displayName;
    try {
      email = FirebaseAuth.instance.currentUser?.email;
      displayName = FirebaseAuth.instance.currentUser?.displayName;
    } catch (_) {
      email = null;
      displayName = null;
    }

    if (email != null &&
        campaign.creatorEmail != null &&
        campaign.creatorEmail == email) {
      return true;
    }
    if ((campaign.creatorEmail == null || campaign.creatorEmail!.isEmpty) &&
        displayName != null &&
        displayName.isNotEmpty &&
        campaign.creatorName == displayName) {
      return true;
    }
    return false;
  }

  String? _supportDisabledReason(Campaign campaign) {
    if (_isCampaignEnded(campaign)) {
      return 'Tapos na ang campaign na ito.';
    }
    if (_isOwnedByCurrentUser(campaign)) {
      return 'Hindi ka puwedeng mag-support sa sarili mong campaign.';
    }
    if (!_hasGcashQr(campaign)) {
      return 'Wala pang GCash QR ang campaign na ito. Pakisabihan muna ang manager bago tumanggap ng support.';
    }
    return null;
  }

  String _formatPendingDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$month/$day/${value.year}';
  }

  Widget _buildGuideCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: lightColorScheme.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: lightColorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: lightColorScheme.onSurface,
                      ) ??
                      const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style:
                      textTheme.bodySmall?.copyWith(
                        height: 1.35,
                        color: lightColorScheme.onSurface.withValues(
                          alpha: 0.9,
                        ),
                      ) ??
                      const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGcashPaymentCard(Campaign campaign, {int? amount}) {
    final qrPath = campaign.gcashQrImage?.trim() ?? '';
    final amountLabel = amount != null && amount > 0
        ? formatPeso(amount)
        : 'ang halagang napili mo';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: lightColorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_2_outlined, color: lightColorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Paraan ng bayad: GCash QR',
                  style: _sectionTitleStyle(context).copyWith(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'I-scan ang QR at ipadala muna ang $amountLabel bago mo kumpirmahin ang pledge.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 1,
              child: CampaignCoverImage(
                imagePath: qrPath,
                isAssetImage: false,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelPendingPledge(Pledge pledge) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Kanselahin ang Pending Pledge?'),
          content: Text(
            'Hindi mabibilang ang ${formatPeso(pledge.amount)} na ito sa campaign hangga\'t walang patunay ng bayad. Gusto mo ba talagang kanselahin ang pending pledge na ito?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Huwag muna'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Kanselahin ang Pledge'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await service.cancelPendingPledge(
        campaignId: pledge.campaignId,
        pledgeId: pledge.id,
      );
      if (!mounted) return;
      showConfirmSnackbar(
        context: context,
        title: 'Nakansela ang pending pledge',
        message:
            'Napanatili ang record, pero hindi na ito naghihintay ng patunay ng bayad.',
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(
        context: context,
        title: 'Hindi makansela',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Widget _buildPendingProofBanner(List<Pledge> pendingPledges) {
    final hasMultiple = pendingPledges.length > 1;
    return Card(
      color: lightColorScheme.secondary.withValues(alpha: 0.25),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: lightColorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.hourglass_top_outlined, color: lightColorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasMultiple
                        ? 'May ${pendingPledges.length} pending pledges ka sa campaign na ito'
                        : 'May naka-pending kang pledge na ${formatPeso(pendingPledges.first.amount)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasMultiple
                        ? 'Piliin kung aling pending pledge ang gusto mong bayaran ngayon, o kanselahin ang hindi mo itutuloy.'
                        : 'Isumite ang patunay ng bayad para maidagdag ito sa kabuuang nalikom ng campaign.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  ...pendingPledges.map((pledge) {
                    final note = pledge.backerNote?.trim();
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: lightColorScheme.primary.withValues(
                            alpha: 0.16,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatPeso(pledge.amount),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ginawa noong ${_formatPendingDate(pledge.createdAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          if (note != null && note.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              note,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _openSubmitProofDialog(pledge),
                                icon: const Icon(Icons.receipt_long_outlined),
                                label: Text(
                                  'Magsumite ng Patunay',
                                  style: _actionLabelStyle(context),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => _cancelPendingPledge(pledge),
                                icon: const Icon(Icons.close_rounded),
                                label: const Text('Kanselahin'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                  Text(
                    'Habang may open pending pledge ka rito, hindi muna available ang panibagong "pay later" pledge.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportSummaryBanner(CampaignSupportSummary summary) {
    final reward = summary.activeReward;
    return Card(
      color: lightColorScheme.primary.withValues(alpha: 0.07),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: lightColorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.workspace_premium_outlined,
              color: lightColorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'May nauna ka nang support sa campaign na ito',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Counted support: ${formatPeso(summary.countedContributionTotal)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (reward != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Current benefit: ${reward.title}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                  if (summary.pendingContributionTotal > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Pending proof: ${formatPeso(summary.pendingContributionTotal)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSubmitProofDialog(Pledge pledge) async {
    String? imageUrl;
    String? referenceNumber;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Magsumite ng Patunay ng Bayad'),
          content: SingleChildScrollView(
            child: _ProofOfPaymentField(
              allowSkip: false,
              onChanged: (result) {
                imageUrl = result.imageUrl;
                referenceNumber = result.referenceNumber;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Bumalik'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Isumite'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if ((imageUrl == null || imageUrl!.trim().isEmpty) &&
        (referenceNumber == null || referenceNumber!.trim().isEmpty)) {
      if (!mounted) return;
      showErrorSnackbar(
        context: context,
        title: 'Kulang ang detalye',
        message: 'Magbigay ng larawan o reference number.',
      );
      return;
    }

    try {
      await service.submitPledgeProof(
        campaignId: pledge.campaignId,
        pledgeId: pledge.id,
        proofImageUrl: imageUrl,
        proofReferenceNumber: referenceNumber,
      );
      if (!mounted) return;
      showConfirmSnackbar(
        context: context,
        title: 'Salamat!',
        message: 'Naidagdag na ang pledge mo sa kabuuang nalikom.',
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(
        context: context,
        title: 'May problema',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _openBackSheet(
    Campaign campaign, {
    RewardTier? preselect,
  }) async {
    final disabledReason = _supportDisabledReason(campaign);
    if (disabledReason != null) {
      showErrorSnackbar(
        context: context,
        title: 'Hindi puwede ngayon',
        message: disabledReason,
      );
      return;
    }

    final supportSummary = await service.getMySupportSummary(campaign.id);
    final existingPendingPledges = await service.getMyPendingPledgesForCampaign(
      campaign.id,
    );
    if (!mounted) return;
    final currentTotal = supportSummary?.countedContributionTotal ?? 0;
    final baselineReward = supportSummary?.activeReward;
    final hasOpenPendingPledge = existingPendingPledges.isNotEmpty;
    final sortedRewards = [...campaign.rewards]
      ..sort((a, b) => a.minPledge.compareTo(b.minPledge));

    String? fallbackName;
    try {
      fallbackName = FirebaseAuth.instance.currentUser?.displayName;
    } catch (_) {
      fallbackName = null;
    }

    RewardTier? highestEligibleReward(int contributionAmount) {
      if (contributionAmount <= 0) return baselineReward;
      return CampaignSupportSummary.highestEligibleReward(
        sortedRewards,
        currentTotal + contributionAmount,
      );
    }

    int minimumContributionFor(RewardTier? reward) {
      if (reward == null) return 1;
      final remaining = reward.minPledge - currentTotal;
      return remaining <= 1 ? 1 : remaining;
    }

    RewardTier? resolveSelectedReward({
      required int contributionAmount,
      required RewardTier? currentSelection,
    }) {
      final autoReward = highestEligibleReward(contributionAmount);
      RewardTier? resolved = autoReward;

      if (currentSelection != null &&
          contributionAmount > 0 &&
          currentTotal + contributionAmount >= currentSelection.minPledge) {
        if (resolved == null ||
            currentSelection.minPledge > resolved.minPledge) {
          resolved = currentSelection;
        }
      }

      if (baselineReward != null) {
        if (resolved == null || resolved.minPledge < baselineReward.minPledge) {
          return baselineReward;
        }
      }
      return resolved;
    }

    RewardTier? initialSelection;
    if (preselect != null &&
        (baselineReward == null ||
            preselect.minPledge >= baselineReward.minPledge)) {
      initialSelection = preselect;
    } else if (baselineReward != null) {
      initialSelection = baselineReward;
    } else if (sortedRewards.isNotEmpty) {
      initialSelection = sortedRewards.first;
    }

    RewardTier? selected = initialSelection;
    final initialAmount = preselect == null && baselineReward != null
        ? ''
        : (selected == null ? '' : minimumContributionFor(selected).toString());
    final amountCtrl = TextEditingController(text: initialAmount);
    final donorNameCtrl = TextEditingController(text: fallbackName ?? '');
    final donorPhoneCtrl = TextEditingController();
    final donorNoteCtrl = TextEditingController();
    var paymentChoice = _ContributionPaymentChoice.paidAlready;
    String? proofImageUrl;
    String? proofReferenceNumber;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void syncSelectionFromAmount() {
              final parsed = int.tryParse(amountCtrl.text.trim()) ?? 0;
              selected = resolveSelectedReward(
                contributionAmount: parsed,
                currentSelection: selected,
              );
            }

            syncSelectionFromAmount();

            final suggestedAmounts = <int>{500, 1000, 2000, 5000};
            if (selected != null) {
              suggestedAmounts.add(minimumContributionFor(selected));
            }
            for (final reward in sortedRewards) {
              suggestedAmounts.add(minimumContributionFor(reward));
            }
            final sortedSuggestions = suggestedAmounts.toList()..sort();
            final minRequired = minimumContributionFor(selected);
            final parsedAmount = int.tryParse(amountCtrl.text.trim());
            final isBelowMinimum =
                parsedAmount != null && parsedAmount < minRequired;
            final qrAmount = parsedAmount != null && parsedAmount > 0
                ? parsedAmount
                : (selected == null ? null : minRequired);
            final hasPaidAlready =
                paymentChoice == _ContributionPaymentChoice.paidAlready;
            RewardTier? nextReward;
            for (final reward in sortedRewards) {
              final isUpgradeFromSelection =
                  selected == null || reward.minPledge > selected!.minPledge;
              if (isUpgradeFromSelection && reward.minPledge > currentTotal) {
                nextReward = reward;
                break;
              }
            }

            Widget buildPaymentChoiceCard({
              required _ContributionPaymentChoice value,
              required IconData icon,
              required String title,
              required String description,
              bool enabled = true,
            }) {
              final isSelected = paymentChoice == value;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: !enabled
                      ? Colors.grey.shade100
                      : isSelected
                      ? lightColorScheme.primary.withValues(alpha: 0.08)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: !enabled
                        ? Colors.grey.shade300
                        : isSelected
                        ? lightColorScheme.primary
                        : Colors.grey.shade300,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: !enabled
                        ? null
                        : () {
                            if (paymentChoice == value) return;
                            setModalState(() {
                              paymentChoice = value;
                              if (paymentChoice ==
                                  _ContributionPaymentChoice.payLater) {
                                proofImageUrl = null;
                                proofReferenceNumber = null;
                              }
                            });
                          },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: isSelected
                                ? lightColorScheme.primary
                                : (enabled
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade400),
                          ),
                          const SizedBox(width: 10),
                          Icon(
                            icon,
                            color: !enabled
                                ? Colors.grey.shade500
                                : isSelected
                                ? lightColorScheme.primary
                                : Colors.grey.shade700,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: enabled
                                        ? null
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  description,
                                  style: TextStyle(
                                    color: enabled
                                        ? null
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 10,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Suportahan ang proyektong ito',
                      style: _sectionTitleStyle(context),
                    ),
                    const SizedBox(height: 10),
                    _buildGuideCard(
                      icon: Icons.info_outline,
                      title: 'Paano sumuporta',
                      description:
                          'Ang benepisyo ay naka-base sa total counted support mo sa campaign na ito. Kapag naabot mo ang mas mataas na threshold, automatic na maa-upgrade ang benepisyo mo.',
                    ),
                    const SizedBox(height: 12),
                    _buildGcashPaymentCard(campaign, amount: qrAmount),
                    if (supportSummary != null) ...[
                      const SizedBox(height: 12),
                      _buildSupportSummaryBanner(supportSummary),
                    ],
                    const SizedBox(height: 12),
                    if (campaign.rewards.isNotEmpty) ...[
                      const Text(
                        'Pumili ng benepisyo',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ...campaign.rewards.map((r) {
                        final isSelected = selected?.id == r.id;
                        final isLowerThanBaseline =
                            baselineReward != null &&
                            r.minPledge < baselineReward.minPledge;
                        final requiredTopUp = minimumContributionFor(r);
                        final discountDisplay = r.discountType == 'percent'
                            ? '${r.discountValue.toStringAsFixed(0)}% na diskuwento'
                            : '${formatPeso(r.discountValue.round())} na diskuwento';
                        return Card(
                          elevation: 0,
                          color: isSelected
                              ? lightColorScheme.secondary.withValues(
                                  alpha: 0.35,
                                )
                              : Colors.white,
                          child: ListTile(
                            title: Text(
                              '${r.title} (minimum ${formatPeso(r.minPledge)})',
                            ),
                            subtitle: Text(
                              currentTotal >= r.minPledge
                                  ? '$discountDisplay • Na-unlock mo na ito'
                                  : '$discountDisplay • Kailangan pa ng ${formatPeso(requiredTopUp)}',
                            ),
                            trailing: isLowerThanBaseline
                                ? const Icon(Icons.lock_outline)
                                : (isSelected
                                      ? const Icon(Icons.check_circle)
                                      : null),
                            onTap: isLowerThanBaseline
                                ? null
                                : () {
                                    setModalState(() {
                                      selected = r;
                                      final currentAmount =
                                          int.tryParse(
                                            amountCtrl.text.trim(),
                                          ) ??
                                          0;
                                      final minimumAmount =
                                          minimumContributionFor(r);
                                      amountCtrl.text =
                                          currentAmount < minimumAmount
                                          ? minimumAmount.toString()
                                          : currentAmount.toString();
                                      syncSelectionFromAmount();
                                    });
                                  },
                          ),
                        );
                      }),
                      const SizedBox(height: 10),
                    ],
                    const Text(
                      'Mabilis na halaga',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: sortedSuggestions
                          .map(
                            (amount) => ChoiceChip(
                              label: Text(formatPeso(amount)),
                              selected:
                                  amountCtrl.text.trim() == amount.toString(),
                              onSelected: amount < minRequired
                                  ? null
                                  : (_) {
                                      setModalState(() {
                                        amountCtrl.text = amount.toString();
                                        syncSelectionFromAmount();
                                      });
                                    },
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) {
                        setModalState(() {
                          syncSelectionFromAmount();
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Halaga ng pledge (PHP)',
                        helperText: selected == null
                            ? 'Maglagay ng halagang nais mong ibigay.'
                            : currentTotal >= selected!.minPledge
                            ? 'Naka-lock na ang ${selected!.title}. Puwede ka lang manatili rito o mag-upgrade.'
                            : 'Dagdag na kailangan para sa ${selected!.title}: ${formatPeso(minRequired)}',
                        errorText: isBelowMinimum
                            ? 'Dapat hindi bababa sa ${formatPeso(minRequired)}.'
                            : null,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (selected != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Selected benefit: ${selected!.title}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: lightColorScheme.primary,
                        ),
                      ),
                      if (nextReward != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Next upgrade: ${nextReward.title} at ${formatPeso((nextReward.minPledge - currentTotal) <= 1 ? 1 : nextReward.minPledge - currentTotal)}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: donorNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Pangalan ng supporter*',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: donorPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contact number (opsyonal)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: donorNoteCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Mensahe / Tala (opsyonal)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: qrAmount == null
                          ? null
                          : () async {
                              await Clipboard.setData(
                                ClipboardData(text: qrAmount.toString()),
                              );
                              if (!sheetContext.mounted) {
                                return;
                              }
                              showConfirmSnackbar(
                                context: sheetContext,
                                title: 'Nakopya ang halaga',
                                message:
                                    'Nakopya na ang ${formatPeso(qrAmount)} para madali mong ma-paste sa GCash.',
                              );
                            },
                      icon: const Icon(Icons.copy_all_outlined),
                      label: Text(
                        'Kopyahin ang Halaga',
                        style: _actionLabelStyle(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Piliin ang status ng bayad mo',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    buildPaymentChoiceCard(
                      value: _ContributionPaymentChoice.paidAlready,
                      icon: Icons.check_circle_outline,
                      title: 'Bayad na ako',
                      description:
                          'Naipadala mo na ang bayad sa GCash QR. Magbigay ng reference number o larawan ng resibo para mabilang agad ang pledge.',
                    ),
                    buildPaymentChoiceCard(
                      value: _ContributionPaymentChoice.payLater,
                      icon: Icons.schedule_outlined,
                      title: 'Magbabayad pa lang ako',
                      description:
                          'Mare-record muna ang pledge mo bilang pending. Bumalik sa campaign na ito kapag handa ka nang magsumite ng patunay ng bayad.',
                      enabled: !hasOpenPendingPledge,
                    ),
                    if (hasOpenPendingPledge)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'May open pending pledge ka na sa campaign na ito. Kumpletuhin o kanselahin muna iyon bago gumawa ng panibagong pay-later pledge.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    const SizedBox(height: 2),
                    if (hasPaidAlready) ...[
                      _ProofOfPaymentField(
                        allowSkip: false,
                        onChanged: (result) {
                          proofImageUrl = result.imageUrl;
                          proofReferenceNumber = result.referenceNumber;
                        },
                      ),
                    ] else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          'Hindi pa ito mabibilang sa total ng campaign hangga\'t hindi ka pa nakakapag-submit ng reference number o resibo.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final raw = int.tryParse(amountCtrl.text.trim()) ?? 0;
                          if (raw <= 0) {
                            showErrorSnackbar(
                              context: context,
                              title: 'Hindi valid',
                              message: 'Maglagay ng wastong halaga.',
                            );
                            return;
                          }
                          if (raw < minRequired) {
                            showErrorSnackbar(
                              context: context,
                              title: 'Masyadong mababa',
                              message:
                                  'Ang minimum para sa benepisyong ito ay ${formatPeso(minRequired)}.',
                            );
                            return;
                          }

                          final donorName = donorNameCtrl.text.trim();
                          if (donorName.isEmpty) {
                            showErrorSnackbar(
                              context: context,
                              title: 'Kulang ang detalye',
                              message:
                                  'Pakilagay ang pangalan ng supporter bago kumpirmahin.',
                            );
                            return;
                          }
                          final hasProof =
                              (proofImageUrl?.isNotEmpty ?? false) ||
                              (proofReferenceNumber?.isNotEmpty ?? false);
                          if (hasPaidAlready && !hasProof) {
                            showErrorSnackbar(
                              context: context,
                              title: 'Kulang ang patunay',
                              message:
                                  'Magbigay ng reference number o larawan ng resibo para sa bayad na pledge.',
                            );
                            return;
                          }

                          try {
                            await service.backCampaign(
                              campaignId: campaign.id,
                              amount: raw,
                              rewardId: selected?.id,
                              backerName: donorName,
                              backerPhone: donorPhoneCtrl.text.trim(),
                              backerNote: donorNoteCtrl.text.trim(),
                              proofImageUrl: hasPaidAlready
                                  ? proofImageUrl
                                  : null,
                              proofReferenceNumber: hasPaidAlready
                                  ? proofReferenceNumber
                                  : null,
                            );
                            if (!mounted) {
                              return;
                            }
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                            showConfirmSnackbar(
                              context: this.context,
                              title: 'Salamat!',
                              message: hasPaidAlready
                                  ? 'Naidagdag na ang pledge mo sa kabuuang nalikom.'
                                  : 'Nairecord ang pledge mo bilang pending. Bumalik dito anumang oras para magsumite ng patunay ng bayad.',
                            );
                            _reload();
                          } catch (e) {
                            if (!sheetContext.mounted) {
                              return;
                            }
                            showErrorSnackbar(
                              context: sheetContext,
                              title: 'May problema',
                              message: e.toString().replaceFirst(
                                'Exception: ',
                                '',
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                        ),
                        icon: const Icon(Icons.volunteer_activism_outlined),
                        label: Text(
                          hasPaidAlready
                              ? 'Bayad na, isumite ang pledge'
                              : 'I-record muna ang pledge',
                          style: _actionLabelStyle(
                            context,
                            color: lightColorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
    );

    return Theme(
      data: campaignTheme,
      child: FutureBuilder<Campaign?>(
        future: _future,
        builder: (context, snapshot) {
          final c = snapshot.data;

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Detalye ng Kampanya'),
                backgroundColor: lightColorScheme.primary,
                foregroundColor: Colors.white,
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'May problema sa pag-load ng kampanya.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          'Subukan muli',
                          style: _actionLabelStyle(
                            context,
                            color: lightColorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (c == null) {
            return const Scaffold(
              body: Center(child: Text('Hindi nakita ang kampanya.')),
            );
          }

          final progress = c.progress.clamp(0.0, 1.0);
          final progressPercent = (progress * 100).round();
          final safeDaysLeft = c.daysLeft < 0 ? 0 : c.daysLeft;
          final supportDisabledReason = _supportDisabledReason(c);
          final canSupport = supportDisabledReason == null;

          return Scaffold(
            appBar: AppBar(
              title: Text(c.title),
              backgroundColor: lightColorScheme.primary,
              foregroundColor: Colors.white,
            ),
            body: ListView(
              padding: const EdgeInsets.only(bottom: 90),
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CampaignCoverImage(
                    imagePath: c.image,
                    isAssetImage: c.isAssetImage,
                    fit: BoxFit.cover,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text(
                    c.shortBlurb,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.black87,
                      height: 1.35,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'Ni ${c.creatorName} | ${_categoryLabel(c.category)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                  ),
                ),
                FutureBuilder<List<Pledge>>(
                  future: _pendingPledgesFuture,
                  builder: (context, pendingSnapshot) {
                    final pendingPledges =
                        pendingSnapshot.data ?? const <Pledge>[];
                    if (pendingPledges.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _buildPendingProofBanner(pendingPledges),
                    );
                  },
                ),
                FutureBuilder<CampaignSupportSummary?>(
                  future: _supportSummaryFuture,
                  builder: (context, summarySnapshot) {
                    final summary = summarySnapshot.data;
                    if (summary == null ||
                        summary.countedContributionTotal <= 0) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: _buildSupportSummaryBanner(summary),
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildGuideCard(
                    icon: Icons.lightbulb_outline,
                    title: 'Bago sumuporta',
                    description:
                        'Basahin ang target, benepisyo, at panganib para malinaw ang iyong desisyon.',
                  ),
                ),
                if (_hasGcashQr(c))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: _buildGcashPaymentCard(c),
                  ),
                if (!canSupport)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Card(
                      color: Colors.grey.shade100,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                supportDisabledReason,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor: Colors.black12,
                            color: lightColorScheme.primary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${formatPeso(c.pledgedAmount)} naipon',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Target: ${formatPeso(c.goalAmount)} ($progressPercent% kumpleto)',
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${c.backersCount} supporters | $safeDaysLeft araw na lang',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  child: Text(
                    'Tungkol sa Kampanya',
                    style: _sectionTitleStyle(context),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(c.description),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text(
                    'Mga Benepisyo',
                    style: _sectionTitleStyle(context),
                  ),
                ),
                if (c.rewards.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(14),
                        child: Text(
                          'Walang nakatalagang benepisyo sa ngayon. Maaari ka pa ring sumuporta gamit ang kahit anong halaga.',
                        ),
                      ),
                    ),
                  )
                else
                  ...c.rewards.map((r) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${r.title} (minimum ${formatPeso(r.minPledge)})',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                r.discountType == 'percent'
                                    ? '${r.discountValue.toStringAsFixed(0)}% na diskuwento sa renta'
                                    : '${formatPeso(r.discountValue.round())} na diskuwento sa renta',
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Balido sa loob ng ${r.validityDays} araw matapos makuha',
                              ),
                              if (r.notes != null) ...[
                                const SizedBox(height: 8),
                                Text(r.notes!),
                              ],
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: canSupport
                                      ? () => _openBackSheet(c, preselect: r)
                                      : null,
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: Text(
                                    'Piliin ang benepisyong ito',
                                    style: _actionLabelStyle(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: canSupport ? () => _openBackSheet(c) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                    ),
                    icon: const Icon(Icons.volunteer_activism_outlined),
                    label: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Suportahan ang proyektong ito',
                        style: _actionLabelStyle(
                          context,
                          color: lightColorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _ContributionPaymentChoice { paidAlready, payLater }

enum _ProofMode { none, image, reference }

/// Mutually-exclusive proof-of-payment input: an uploaded image OR a typed
/// reference number, never both. Reports whichever one is set (or neither)
/// via [onChanged]. Used both when pledging and when submitting proof later
/// for a pending pledge.
class _ProofOfPaymentField extends StatefulWidget {
  final ValueChanged<({String? imageUrl, String? referenceNumber})> onChanged;

  /// When false, the "wala pa" (skip) segment is omitted — used when the
  /// backer has explicitly chosen to submit proof now and must pick one.
  final bool allowSkip;

  const _ProofOfPaymentField({required this.onChanged, this.allowSkip = true});

  @override
  State<_ProofOfPaymentField> createState() => _ProofOfPaymentFieldState();
}

class _ProofOfPaymentFieldState extends State<_ProofOfPaymentField> {
  late _ProofMode _mode = widget.allowSkip ? _ProofMode.none : _ProofMode.image;
  final _referenceController = TextEditingController();
  final _picker = ImagePicker();
  final _cloudinary = CloudinaryService();
  String? _imageUrl;
  bool _uploading = false;

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged((
      imageUrl: _mode == _ProofMode.image ? _imageUrl : null,
      referenceNumber:
          _mode == _ProofMode.reference &&
              _referenceController.text.trim().isNotEmpty
          ? _referenceController.text.trim()
          : null,
    ));
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
    } catch (e) {
      if (!mounted) return;
      showErrorSnackbar(
        context: context,
        title: 'Hindi na-pick',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
      return;
    }
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final url = await _cloudinary.uploadImage(
        file,
        folder: 'bukidbayan/campaign_proofs',
        tags: 'bukidbayan,campaign,proof',
      );
      if (!mounted) return;
      setState(() {
        _imageUrl = url;
        _uploading = false;
      });
      _emit();
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      showErrorSnackbar(
        context: context,
        title: 'Hindi na-upload',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Patunay ng Bayad',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        SegmentedButton<_ProofMode>(
          segments: [
            if (widget.allowSkip)
              const ButtonSegment(
                value: _ProofMode.none,
                label: Text('Wala pa'),
              ),
            const ButtonSegment(value: _ProofMode.image, label: Text('Resibo')),
            const ButtonSegment(
              value: _ProofMode.reference,
              label: Text('Reference #'),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (selection) {
            setState(() {
              _mode = selection.first;
              if (_mode != _ProofMode.image) _imageUrl = null;
              if (_mode != _ProofMode.reference) _referenceController.clear();
            });
            _emit();
          },
        ),
        const SizedBox(height: 8),
        if (_mode == _ProofMode.none)
          Text(
            'Puwede mo itong isumite sa ibang pagkakataon — bumalik lang sa campaign na ito.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          )
        else if (_mode == _ProofMode.image) ...[
          if (_imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _imageUrl!,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pickAndUploadImage,
            icon: _uploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_outlined),
            label: Text(
              _imageUrl == null ? 'Mag-upload ng Resibo' : 'Palitan ang Resibo',
            ),
          ),
        ] else
          TextField(
            controller: _referenceController,
            onChanged: (_) => _emit(),
            decoration: const InputDecoration(
              labelText: 'GCash Reference Number',
              border: OutlineInputBorder(),
            ),
          ),
      ],
    );
  }
}
