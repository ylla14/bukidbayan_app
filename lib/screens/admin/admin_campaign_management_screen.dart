import 'package:bukidbayan_app/components/admin/admin_card.dart';
import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/screens/admin/admin_campaign_backers_screen.dart';
import 'package:bukidbayan_app/services/crowdfunding_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/utils/money_format.dart';
import 'package:flutter/material.dart';

/// Lists the co-op's own campaigns so an admin can drill into a campaign's
/// backer list and proof-of-payment status (see [AdminCampaignBackersScreen]).
class AdminCampaignManagementScreen extends StatefulWidget {
  final CrowdfundingService? serviceOverride;

  const AdminCampaignManagementScreen({super.key, this.serviceOverride});

  @override
  State<AdminCampaignManagementScreen> createState() =>
      _AdminCampaignManagementScreenState();
}

class _AdminCampaignManagementScreenState
    extends State<AdminCampaignManagementScreen> {
  late final CrowdfundingService _service;
  late Future<List<Campaign>> _future;

  @override
  void initState() {
    super.initState();
    _service = widget.serviceOverride ?? CrowdfundingService();
    _future = _service.getMyCampaigns();
  }

  Future<void> _reload() async {
    setState(() => _future = _service.getMyCampaigns());
    await _future;
  }

  bool _isEnded(Campaign c) =>
      c.status.startsWith('ended') || DateTime.now().isAfter(c.endDate);

  String _statusLabel(Campaign c) {
    if (c.status == 'draft') return 'Draft';
    if (_isEnded(c)) return 'Tapos na';
    if (c.status == 'live') return 'Aktibo';
    return c.status;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Campaign Management'),
        backgroundColor: lightColorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Campaign>>(
          future: _future,
          builder: (context, snapshot) {
            final campaigns = snapshot.data ?? [];
            if (snapshot.connectionState == ConnectionState.waiting &&
                campaigns.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Piliin ang campaign para makita ang mga backer at ang kanilang patunay ng bayad.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                if (campaigns.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Wala ka pang campaign.')),
                  )
                else
                  ...campaigns.map(
                    (campaign) => AdminCard(
                      icon: Icons.campaign_outlined,
                      title: campaign.title.isEmpty
                          ? '(Walang Pamagat)'
                          : campaign.title,
                      description:
                          '${_statusLabel(campaign)} • ${formatPeso(campaign.pledgedAmount)} / ${formatPeso(campaign.goalAmount)} • ${campaign.backersCount} backers',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AdminCampaignBackersScreen(
                              campaignId: campaign.id,
                              campaignTitle: campaign.title,
                              serviceOverride: _service,
                            ),
                          ),
                        );
                      },
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
