import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/services/crowdfunding_payment_service.dart';
import 'package:bukidbayan_app/services/crowdfunding_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/utils/money_format.dart';
import 'package:bukidbayan_app/widgets/campaign_cover_image.dart';
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final CrowdfundingPaymentService paymentService =
      CrowdfundingPaymentService();
  late Future<Campaign?> _future;

  String _categoryLabel(String value) => _categoryLabels[value] ?? value;

  @override
  void initState() {
    super.initState();
    _future = service.getCampaignById(widget.campaignId);
  }

  Future<void> _reload() async {
    setState(() {
      _future = service.getCampaignById(widget.campaignId);
    });
    await _future;
  }

  bool _isCampaignEnded(Campaign campaign) {
    return campaign.status.startsWith('ended') ||
        DateTime.now().isAfter(campaign.endDate);
  }

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
    return null;
  }

  Widget _buildGuideCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: lightColorScheme.primary.withOpacity(0.28)),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(description, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openBackSheet(Campaign campaign, {RewardTier? preselect}) {
    final disabledReason = _supportDisabledReason(campaign);
    if (disabledReason != null) {
      showErrorSnackbar(
        context: context,
        title: 'Hindi puwede ngayon',
        message: disabledReason,
      );
      return;
    }

    String? fallbackName;
    try {
      fallbackName = FirebaseAuth.instance.currentUser?.displayName;
    } catch (_) {
      fallbackName = null;
    }

    RewardTier? selected =
        preselect ??
        (campaign.rewards.isNotEmpty ? campaign.rewards.first : null);

    final amountCtrl = TextEditingController(
      text: selected == null ? '' : selected.minPledge.toString(),
    );
    final donorNameCtrl = TextEditingController(text: fallbackName ?? '');
    final donorPhoneCtrl = TextEditingController();
    final donorNoteCtrl = TextEditingController();
    var isSubmitting = false;
    String? checkoutStatusMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final suggestedAmounts = <int>{500, 1000, 2000, 5000};
            final selectedReward = selected;
            if (selectedReward != null) {
              suggestedAmounts.add(selectedReward.minPledge);
            }
            final sortedSuggestions = suggestedAmounts.toList()..sort();
            final minRequired = selectedReward?.minPledge;
            final parsedAmount = int.tryParse(amountCtrl.text.trim());
            final isBelowMinimum =
                minRequired != null &&
                parsedAmount != null &&
                parsedAmount < minRequired;

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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: lightColorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildGuideCard(
                      icon: Icons.info_outline,
                      title: 'Paano sumuporta',
                      description:
                          'Pumili ng benepisyo (opsyonal), ilagay ang halaga, at magpatuloy sa secure checkout.',
                    ),
                    const SizedBox(height: 12),
                    if (campaign.rewards.isNotEmpty) ...[
                      const Text(
                        'Pumili ng benepisyo',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ...campaign.rewards.map((r) {
                        final isSelected = selected?.id == r.id;
                        final discountDisplay = r.discountType == 'percent'
                            ? '${r.discountValue.toStringAsFixed(0)}% na diskuwento'
                            : '${formatPeso(r.discountValue.round())} na diskuwento';
                        return Card(
                          elevation: 0,
                          color: isSelected
                              ? lightColorScheme.secondary.withOpacity(0.35)
                              : Colors.white,
                          child: ListTile(
                            title: Text(
                              '${r.title} (minimum ${formatPeso(r.minPledge)})',
                            ),
                            subtitle: Text(discountDisplay),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle)
                                : null,
                            onTap: () {
                              setModalState(() {
                                selected = r;
                                final currentAmount =
                                    int.tryParse(amountCtrl.text.trim()) ?? 0;
                                amountCtrl.text = currentAmount < r.minPledge
                                    ? r.minPledge.toString()
                                    : currentAmount.toString();
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
                              onSelected:
                                  minRequired != null && amount < minRequired
                                  ? null
                                  : (_) {
                                      setModalState(() {
                                        amountCtrl.text = amount.toString();
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
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Halaga ng pledge (PHP)',
                        helperText: minRequired == null
                            ? 'Maglagay ng halagang nais mong ibigay.'
                            : 'Minimum para sa napiling benepisyo: ${formatPeso(minRequired)}',
                        errorText: isBelowMinimum
                            ? 'Dapat hindi bababa sa ${formatPeso(minRequired)}.'
                            : null,
                        border: const OutlineInputBorder(),
                      ),
                    ),
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
                    if (checkoutStatusMessage != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: lightColorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: lightColorScheme.primary.withOpacity(0.18),
                          ),
                        ),
                        child: Text(
                          checkoutStatusMessage!,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final raw =
                                    int.tryParse(amountCtrl.text.trim()) ?? 0;
                                if (raw <= 0) {
                                  showErrorSnackbar(
                                    context: context,
                                    title: 'Hindi valid',
                                    message: 'Maglagay ng wastong halaga.',
                                  );
                                  return;
                                }
                                if (minRequired != null && raw < minRequired) {
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

                                try {
                                  setModalState(() {
                                    isSubmitting = true;
                                    checkoutStatusMessage =
                                        'Inihahanda ang secure checkout...';
                                  });

                                  final attempt = await paymentService
                                      .createCheckoutAttempt(
                                        campaignId: campaign.id,
                                        amount: raw,
                                        rewardId: selected?.id,
                                        donorName: donorName,
                                        donorPhone: donorPhoneCtrl.text.trim(),
                                        donorNote: donorNoteCtrl.text.trim(),
                                      );

                                  final checkoutUrl =
                                      attempt.providerCheckoutUrl;
                                  if (checkoutUrl == null ||
                                      checkoutUrl.isEmpty) {
                                    throw Exception(
                                      'Hindi nagawa ang checkout session. Subukan muli.',
                                    );
                                  }

                                  final launched = await launchUrl(
                                    Uri.parse(checkoutUrl),
                                    mode: LaunchMode.externalApplication,
                                  );
                                  if (!launched) {
                                    throw Exception(
                                      'Nagawa ang checkout pero hindi ito mabuksan sa device na ito.',
                                    );
                                  }

                                  if (!mounted || !sheetContext.mounted) {
                                    return;
                                  }

                                  Navigator.pop(sheetContext);
                                  showConfirmSnackbar(
                                    context: this.context,
                                    title: 'Checkout handa na',
                                    message:
                                        'Binuksan ang PayMongo checkout. Bumalik sa app pagkatapos ng bayad para makita ang kumpirmasyon.',
                                  );
                                } catch (e) {
                                  setModalState(() {
                                    isSubmitting = false;
                                    checkoutStatusMessage = null;
                                  });
                                  if (!mounted) return;
                                  showErrorSnackbar(
                                    context: this.context,
                                    title: 'May problema',
                                    message: e.toString().replaceFirst(
                                      'Exception: ',
                                      '',
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.volunteer_activism_outlined),
                        label: Text(
                          isSubmitting
                              ? 'Inihahanda ang checkout...'
                              : 'Magpatuloy sa secure checkout',
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
                        label: const Text('Subukan ulit'),
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
          final disabledMessage = supportDisabledReason;
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
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'Ni ${c.creatorName} | ${_categoryLabel(c.category)}',
                    style: const TextStyle(color: Colors.black54),
                  ),
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
                if (!canSupport && disabledMessage != null)
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
                                disabledMessage,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: lightColorScheme.primary,
                    ),
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: lightColorScheme.primary,
                    ),
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
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
                                  label: const Text(
                                    'Piliin ang benepisyong ito',
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
                    icon: const Icon(Icons.volunteer_activism_outlined),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text('Suportahan ang proyektong ito'),
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
