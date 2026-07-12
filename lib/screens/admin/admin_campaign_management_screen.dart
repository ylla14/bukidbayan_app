import 'package:bukidbayan_app/components/admin/admin_card.dart';
import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/screens/admin/admin_campaign_backers_screen.dart';
import 'package:bukidbayan_app/services/app_language.dart';
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

  String _t(String en, String tl) => AppLanguage.text(en: en, tl: tl);

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

  bool _isArchived(Campaign campaign) =>
      campaign.status.startsWith('archived_');

  String _baseStatus(Campaign campaign) {
    if (!_isArchived(campaign)) return campaign.status;
    return campaign.status.substring('archived_'.length);
  }

  bool _isEnded(Campaign c) =>
      _baseStatus(c).startsWith('ended') || DateTime.now().isAfter(c.endDate);

  String _statusLabel(Campaign c) {
    if (_isArchived(c)) return _t('Archived', 'Naka-archive');
    if (_baseStatus(c) == 'draft') return _t('Draft', 'Draft');
    if (_isEnded(c)) return _t('Ended', 'Tapos na');
    if (_baseStatus(c) == 'live') return _t('Live', 'Aktibo');
    return _baseStatus(c);
  }

  @override
  Widget build(BuildContext context) {
    return AppLanguageScope(
      builder: (context) => Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(_t('Supporter Reviews', 'Pagsusuri ng Mga Suporta')),
          backgroundColor: lightColorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: RefreshIndicator(
          onRefresh: _reload,
          child: FutureBuilder<List<Campaign>>(
            future: _future,
            builder: (context, snapshot) {
              final campaigns = (snapshot.data ?? [])
                  .where((campaign) => _baseStatus(campaign) != 'draft')
                  .toList();
              if (snapshot.connectionState == ConnectionState.waiting &&
                  campaigns.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    _t(
                      'Choose a campaign to review supporters and their payment proofs.',
                      'Piliin ang campaign para suriin ang mga tagasuporta at ang kanilang patunay ng bayad.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  if (campaigns.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          _t(
                            'You do not have any campaigns yet.',
                            'Wala ka pang campaign.',
                          ),
                        ),
                      ),
                    )
                  else
                    ...campaigns.map(
                      (campaign) => AdminCard(
                        icon: Icons.campaign_outlined,
                        title: campaign.title.isEmpty
                            ? _t('(Untitled)', '(Walang Pamagat)')
                            : campaign.title,
                        description:
                            '${_statusLabel(campaign)} | ${formatPeso(campaign.pledgedAmount)} / ${formatPeso(campaign.goalAmount)} | ${campaign.backersCount} ${_t('supporters', 'tagasuporta')}',
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
      ),
    );
  }
}
