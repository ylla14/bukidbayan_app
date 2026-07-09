import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/services/crowdfunding_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/utils/money_format.dart';
import 'package:bukidbayan_app/widgets/campaign_cover_image.dart';
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    var hasConfirmedGcashPayment = false;

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
            if (selected != null) {
              suggestedAmounts.add(selected!.minPledge);
            }
            final sortedSuggestions = suggestedAmounts.toList()..sort();
            final minRequired = selected?.minPledge;
            final parsedAmount = int.tryParse(amountCtrl.text.trim());
            final isBelowMinimum =
                minRequired != null &&
                parsedAmount != null &&
                parsedAmount < minRequired;
            final qrAmount = parsedAmount != null && parsedAmount > 0
                ? parsedAmount
                : minRequired;

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
                          'Pumili ng benepisyo (opsyonal), ilagay ang halaga, i-scan ang GCash QR, at kumpirmahin lang kapag naipadala mo na ang bayad.',
                    ),
                    const SizedBox(height: 12),
                    _buildGcashPaymentCard(campaign, amount: qrAmount),
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
                              ? lightColorScheme.secondary.withValues(
                                  alpha: 0.35,
                                )
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
                    CheckboxListTile(
                      value: hasConfirmedGcashPayment,
                      onChanged: (value) {
                        setModalState(() {
                          hasConfirmedGcashPayment = value ?? false;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Naipadala ko na ang bayad sa GCash QR na ito.',
                      ),
                      subtitle: const Text(
                        'Pindutin lang ito pagkatapos mong mag-transfer dahil mabibilang agad ang pledge kapag kinumpirma mo.',
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
                          if (!hasConfirmedGcashPayment) {
                            showErrorSnackbar(
                              context: context,
                              title: 'Hindi pa kumpirmado ang bayad',
                              message:
                                  'I-scan muna ang GCash QR at i-check ang kumpirmasyon bago maitala ang pledge.',
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
                              message:
                                  'Nairecord na ang pledge mo bilang GCash payment para sa campaign na ito.',
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
                        icon: const Icon(Icons.volunteer_activism_outlined),
                        label: Text(
                          'Kinumpirma ko ang GCash payment',
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
