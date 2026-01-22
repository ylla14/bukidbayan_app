import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/services/crowdfunding_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/campaign_card.dart' hide formatPeso;
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/utils/money_format.dart';

class CampaignDetailScreen extends StatefulWidget {
  final String campaignId;

  const CampaignDetailScreen({super.key, required this.campaignId});

  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> {
  final CrowdfundingService service = CrowdfundingService();
  late Future<Campaign?> _future;

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

  void _openBackSheet(Campaign campaign, {RewardTier? preselect}) {
    RewardTier? selected = preselect ?? (campaign.rewards.isNotEmpty ? campaign.rewards.first : null);
    final amountCtrl = TextEditingController(
      text: selected == null ? '' : selected.minPledge.toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Back this project',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: lightColorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              if (campaign.rewards.isNotEmpty) ...[
                const Text('Choose a reward'),
                const SizedBox(height: 8),
                ...campaign.rewards.map((r) {
                  final isSelected = selected?.id == r.id;
                  return Card(
                    elevation: 0,
                    color: isSelected ? lightColorScheme.secondary.withOpacity(0.35) : Colors.white,
                    child: ListTile(
                      title: Text('${r.title} (min ${formatPeso(r.minPledge)})'),
                      subtitle: Text(r.description),
                      trailing: isSelected ? const Icon(Icons.check_circle) : null,
                      onTap: () {
                        selected = r;
                        amountCtrl.text = r.minPledge.toString();
                        setState(() {});
                      },
                    ),
                  );
                }),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Pledge amount (PHP)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final raw = int.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (raw <= 0) {
                      showErrorSnackbar(
                        context: context,
                        title: 'Invalid',
                        message: 'Enter a valid amount.',
                      );
                      return;
                    }
                    if (selected != null && raw < selected!.minPledge) {
                      showErrorSnackbar(
                        context: context,
                        title: 'Too low',
                        message: 'Minimum for this reward is ${formatPeso(selected!.minPledge)}.',
                      );
                      return;
                    }

                    try {
                      await service.backCampaign(
                        campaignId: campaign.id,
                        amount: raw,
                        rewardId: selected?.id,
                      );
                      if (mounted) Navigator.pop(context);
                      showConfirmSnackbar(
                        context: context,
                        title: 'Thank you!',
                        message: 'Pledge received.',
                      );
                      _reload();
                    } catch (e) {
                      showErrorSnackbar(
                        context: context,
                        title: 'Error',
                        message: e.toString().replaceFirst('Exception: ', ''),
                      );
                    }
                  },
                  child: const Text('Confirm pledge'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Campaign?>(
      future: _future,
      builder: (context, snapshot) {
        final c = snapshot.data;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (c == null) {
          return const Scaffold(
            body: Center(child: Text('Campaign not found.')),
          );
        }

        final progress = c.progress.clamp(0.0, 1.0);

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
                child: c.isAssetImage
                    ? Image.asset(c.image, fit: BoxFit.cover)
                    : Image.network(c.image, fit: BoxFit.cover),
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
                  'By ${c.creatorName} • ${c.category}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                          '${formatPeso(c.pledgedAmount)} pledged',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text('Goal: ${formatPeso(c.goalAmount)}'),
                        const SizedBox(height: 4),
                        Text('${c.backersCount} backers • ${c.daysLeft} days left'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Text(
                  'About',
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
                  'Rewards',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: lightColorScheme.primary,
                  ),
                ),
              ),
              ...c.rewards.map((r) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${r.title} (min ${formatPeso(r.minPledge)})',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(r.description),
                          const SizedBox(height: 10),
                          Text('Estimated delivery: ${r.estimatedDelivery}'),
                          Text('Shipping: ${r.shipping}'),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _openBackSheet(c, preselect: r),
                              child: const Text('Select this reward'),
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
                child: ElevatedButton(
                  onPressed: () => _openBackSheet(c),
                  child: const Text('Back this project'),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
