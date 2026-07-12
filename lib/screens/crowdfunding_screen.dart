import 'package:bukidbayan_app/components/app_bar.dart';
import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/screens/campaign_creation/campaign_creation_screen.dart';
import 'package:bukidbayan_app/screens/campaign_detail_screen.dart';
import 'package:bukidbayan_app/screens/campaign_report_screen.dart';
import 'package:bukidbayan_app/services/app_language.dart';
import 'package:bukidbayan_app/services/crowdfunding_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/utils/money_format.dart';
import 'package:bukidbayan_app/widgets/campaign_card.dart' hide formatPeso;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum CampaignSort { popular, endingSoon, newest }

enum CampaignManagementTab { live, ended, drafts, archive }

class CrowdfundingScreen extends StatefulWidget {
  final CrowdfundingService? serviceOverride;
  final FirebaseAuth? authOverride;
  final PreferredSizeWidget? appBarOverride;
  final Widget? drawerOverride;

  /// True when the logged-in user is the co-op account.
  /// Shows campaign management tabs and create actions.
  /// Prosumers see only the public discover feed.
  final bool isCoop;

  const CrowdfundingScreen({
    super.key,
    this.serviceOverride,
    this.authOverride,
    this.appBarOverride,
    this.drawerOverride,
    this.isCoop = false,
  });

  @override
  State<CrowdfundingScreen> createState() => _CrowdfundingScreenState();
}

class _CrowdfundingScreenState extends State<CrowdfundingScreen>
    with SingleTickerProviderStateMixin {
  late final CrowdfundingService _service;
  late final TabController _manageTabController;
  FirebaseAuth? _auth;

  final TextEditingController _discoverSearchController =
      TextEditingController();
  final TextEditingController _manageSearchController = TextEditingController();

  late Future<List<Campaign>> _discoverFuture;
  late Future<List<Campaign>> _myListingsFuture;

  String _discoverCategory = 'All';
  CampaignSort _sort = CampaignSort.newest;

  @override
  void initState() {
    super.initState();
    _service = widget.serviceOverride ?? CrowdfundingService();
    _manageTabController =
        TabController(length: CampaignManagementTab.values.length, vsync: this)
          ..addListener(() {
            if (!mounted) return;
            setState(() {});
          });
    _auth = widget.authOverride;
    if (_auth == null) {
      try {
        _auth = FirebaseAuth.instance;
      } catch (_) {
        _auth = null;
      }
    }
    _reloadFutures();
  }

  @override
  void dispose() {
    _discoverSearchController.dispose();
    _manageSearchController.dispose();
    _manageTabController.dispose();
    super.dispose();
  }

  void _reloadFutures() {
    _discoverFuture = _service.getCampaigns();
    _myListingsFuture = _service.getMyCampaigns();
  }

  String _t(String en, String tl) => AppLanguage.text(en: en, tl: tl);

  String _categoryLabel(String value) {
    switch (value) {
      case 'All':
        return _t('All', 'Lahat');
      case 'Irrigation':
        return _t('Irrigation', 'Patubig');
      case 'Crop Care':
        return _t('Crop Care', 'Pangangalaga ng Pananim');
      case 'Post-harvest':
        return _t('Post-harvest', 'Pagkatapos ng Ani');
      case 'Mechanized Tools':
        return _t('Mechanized Tools', 'Mekanikal na Kagamitan');
      case 'Livestock':
        return _t('Livestock', 'Alagang Hayop');
      case 'Solar/Power':
        return _t('Solar/Power', 'Solar/Kuryente');
      case 'Hand Tools':
        return _t('Hand Tools', 'Kagamitang Kamay');
      case 'Other':
        return _t('Other', 'Iba pa');
      default:
        return value;
    }
  }

  TextStyle _sectionTitleStyle(BuildContext context) {
    return Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: lightColorScheme.primary,
        ) ??
        TextStyle(
          fontSize: 24,
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

  Future<void> _refresh() async {
    setState(_reloadFutures);
    await Future.wait([_discoverFuture, _myListingsFuture]);
  }

  List<String> _buildCategories(List<Campaign> campaigns) {
    final set = <String>{'All'};
    for (final c in campaigns) {
      if (c.category.trim().isNotEmpty) set.add(c.category);
    }
    final categories = set.toList();
    categories.sort((a, b) {
      if (a == 'All') return -1;
      if (b == 'All') return 1;
      return a.compareTo(b);
    });
    return categories;
  }

  List<Campaign> _applyDiscoverFilters(List<Campaign> campaigns) {
    final q = _discoverSearchController.text.trim().toLowerCase();

    final filtered = campaigns.where((c) {
      final matchesSearch =
          q.isEmpty ||
          c.title.toLowerCase().contains(q) ||
          c.shortBlurb.toLowerCase().contains(q) ||
          c.creatorName.toLowerCase().contains(q) ||
          c.category.toLowerCase().contains(q);

      final matchesCategory =
          _discoverCategory == 'All' || c.category == _discoverCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    switch (_sort) {
      case CampaignSort.popular:
        filtered.sort((a, b) => b.pledgedAmount.compareTo(a.pledgedAmount));
        break;
      case CampaignSort.endingSoon:
        filtered.sort((a, b) => a.endDate.compareTo(b.endDate));
        break;
      case CampaignSort.newest:
        filtered.sort((a, b) {
          final aTime = a.publishedAt ?? a.createdAt;
          final bTime = b.publishedAt ?? b.createdAt;
          return bTime.compareTo(aTime);
        });
        break;
    }

    return filtered;
  }

  bool _isArchived(Campaign campaign) =>
      campaign.status.startsWith('archived_');

  String _baseStatus(Campaign campaign) {
    if (!_isArchived(campaign)) return campaign.status;
    return campaign.status.substring('archived_'.length);
  }

  bool _isDraft(Campaign campaign) => _baseStatus(campaign) == 'draft';

  bool _isEnded(Campaign campaign) {
    return _baseStatus(campaign).startsWith('ended') ||
        DateTime.now().isAfter(campaign.endDate);
  }

  bool _isLiveTabCampaign(Campaign campaign) {
    return !_isArchived(campaign) && !_isDraft(campaign) && !_isEnded(campaign);
  }

  bool _isEndedTabCampaign(Campaign campaign) {
    return !_isArchived(campaign) && !_isDraft(campaign) && _isEnded(campaign);
  }

  bool _isDraftTabCampaign(Campaign campaign) {
    return !_isArchived(campaign) && _isDraft(campaign);
  }

  bool _isArchiveTabCampaign(Campaign campaign) => _isArchived(campaign);

  List<Campaign> _applyManageFilters(
    List<Campaign> listings,
    CampaignManagementTab tab,
  ) {
    final q = _manageSearchController.text.trim().toLowerCase();

    final filtered = listings.where((c) {
      final matchesSearch =
          q.isEmpty ||
          c.title.toLowerCase().contains(q) ||
          c.shortBlurb.toLowerCase().contains(q) ||
          c.category.toLowerCase().contains(q);

      bool matchesFilter;
      switch (tab) {
        case CampaignManagementTab.live:
          matchesFilter = _isLiveTabCampaign(c);
          break;
        case CampaignManagementTab.ended:
          matchesFilter = _isEndedTabCampaign(c);
          break;
        case CampaignManagementTab.drafts:
          matchesFilter = _isDraftTabCampaign(c);
          break;
        case CampaignManagementTab.archive:
          matchesFilter = _isArchiveTabCampaign(c);
          break;
      }

      return matchesSearch && matchesFilter;
    }).toList();

    filtered.sort((a, b) {
      final aTime = a.lastEditedAt ?? a.createdAt;
      final bTime = b.lastEditedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });

    return filtered;
  }

  String _statusLabel(Campaign campaign) {
    if (_isArchived(campaign)) return _t('Archived', 'Naka-archive');
    if (_isDraft(campaign)) return _t('Draft', 'Draft');
    if (_isEnded(campaign)) return _t('Ended', 'Tapos na');
    if (_baseStatus(campaign) == 'live') return _t('Live', 'Aktibo');
    return _baseStatus(campaign);
  }

  Color _statusColor(Campaign campaign) {
    if (_isArchived(campaign)) return Colors.blueGrey;
    if (_isDraft(campaign)) return Colors.orange;
    if (_isEnded(campaign)) return Colors.grey;
    if (_baseStatus(campaign) == 'live') return Colors.green;
    return lightColorScheme.primary;
  }

  String _tabTitle(CampaignManagementTab tab) {
    switch (tab) {
      case CampaignManagementTab.live:
        return _t('Live Campaigns', 'Mga Aktibong Kampanya');
      case CampaignManagementTab.ended:
        return _t('Ended Campaigns', 'Mga Natapos na Kampanya');
      case CampaignManagementTab.drafts:
        return _t('Draft Campaigns', 'Mga Draft na Kampanya');
      case CampaignManagementTab.archive:
        return _t('Archived Campaigns', 'Mga Naka-archive na Kampanya');
    }
  }

  String _tabLabel(CampaignManagementTab tab) {
    switch (tab) {
      case CampaignManagementTab.live:
        return _t('Live', 'Aktibo');
      case CampaignManagementTab.ended:
        return _t('Ended', 'Natapos');
      case CampaignManagementTab.drafts:
        return _t('Drafts', 'Mga Draft');
      case CampaignManagementTab.archive:
        return _t('Archive', 'Naka-archive');
    }
  }

  String _tabDescription(CampaignManagementTab tab) {
    switch (tab) {
      case CampaignManagementTab.live:
        return _t(
          'These campaigns are still active for supporters and can be archived when needed.',
          'Aktibo pa ang mga kampanyang ito para sa mga tagasuporta at maaari silang i-archive kung kinakailangan.',
        );
      case CampaignManagementTab.ended:
        return _t(
          'Finished campaigns stay here so you can review outcomes and check reports without mixing them into active ones.',
          'Mananatili rito ang mga natapos na kampanya para masuri mo ang kinalabasan at matingnan ang mga ulat nang hindi nahahalo sa mga aktibo.',
        );
      case CampaignManagementTab.drafts:
        return _t(
          'Continue unfinished campaign drafts here before publishing them.',
          'Ipagpatuloy dito ang mga hindi pa tapos na draft bago i-publish.',
        );
      case CampaignManagementTab.archive:
        return _t(
          'Archived campaigns stay in your records and are hidden from the public list.',
          'Mananatili sa records ang mga naka-archive at nakatago sila sa public list.',
        );
    }
  }

  int _campaignCountForTab(CampaignManagementTab tab, List<Campaign> listings) {
    switch (tab) {
      case CampaignManagementTab.live:
        return listings.where(_isLiveTabCampaign).length;
      case CampaignManagementTab.ended:
        return listings.where(_isEndedTabCampaign).length;
      case CampaignManagementTab.drafts:
        return listings.where(_isDraftTabCampaign).length;
      case CampaignManagementTab.archive:
        return listings.where(_isArchiveTabCampaign).length;
    }
  }

  Widget _buildManagementTabChip({
    required CampaignManagementTab tab,
    required List<Campaign> listings,
    required bool showCount,
    required bool selected,
  }) {
    final count = _campaignCountForTab(tab, listings);
    final foreground = selected
        ? lightColorScheme.primary
        : lightColorScheme.onSurface.withValues(alpha: 0.72);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.symmetric(
        horizontal: selected ? 16 : 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: selected
            ? lightColorScheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _tabLabel(tab),
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: foreground,
            ),
          ),
          if (selected && showCount) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: lightColorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManagementTabBar(
    List<Campaign> listings, {
    bool showCount = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: TabBar(
        controller: _manageTabController,
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        indicatorColor: Colors.transparent,
        dividerColor: Colors.transparent,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return lightColorScheme.primary.withValues(alpha: 0.08);
          }
          return null;
        }),
        tabs: List.generate(CampaignManagementTab.values.length, (index) {
          final tab = CampaignManagementTab.values[index];
          final selected = _manageTabController.index == index;
          return Tab(
            child: _buildManagementTabChip(
              tab: tab,
              listings: listings,
              showCount: showCount,
              selected: selected,
            ),
          );
        }),
      ),
    );
  }

  String _emptyStateTitle(CampaignManagementTab tab) {
    switch (tab) {
      case CampaignManagementTab.live:
        return _t('No live campaigns yet', 'Wala pang live na kampanya');
      case CampaignManagementTab.ended:
        return _t('No ended campaigns yet', 'Wala pang natapos na kampanya');
      case CampaignManagementTab.drafts:
        return _t('No drafts yet', 'Wala pang draft');
      case CampaignManagementTab.archive:
        return _t('No archived campaigns yet', 'Wala pang naka-archive');
    }
  }

  String _emptyStateDescription(CampaignManagementTab tab) {
    switch (tab) {
      case CampaignManagementTab.live:
        return _t(
          'Publish a draft to make it visible to supporters here.',
          'Mag-publish ng draft para lumabas ito rito para sa mga tagasuporta.',
        );
      case CampaignManagementTab.ended:
        return _t(
          'Campaigns that finish or reach their deadline will appear here.',
          'Lalabas dito ang mga kampanyang natapos na o umabot na sa deadline.',
        );
      case CampaignManagementTab.drafts:
        return _t(
          'Create a draft to prepare your next campaign.',
          'Gumawa ng draft para ihanda ang susunod mong kampanya.',
        );
      case CampaignManagementTab.archive:
        return _t(
          'Archived campaigns will appear here once you move them out of the live or draft lists.',
          'Lalabas dito ang mga kampanya kapag inilipat mo sila mula sa live o draft lists.',
        );
    }
  }

  Future<void> logout() async {
    if (_auth == null) return;
    await _auth!.signOut();
  }

  Future<void> _openCreate({Campaign? draft}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CampaignCreationScreen(existingDraft: draft),
      ),
    );
    if (result == true) {
      _discoverSearchController.clear();
      _discoverCategory = 'All';
      _sort = CampaignSort.newest;
    }
    await _refresh();
  }

  Future<void> _openCampaign(Campaign campaign) async {
    if (_isDraft(campaign)) {
      await _openCreate(draft: campaign);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CampaignDetailScreen(campaignId: campaign.id),
      ),
    );
    await _refresh();
  }

  Future<void> _openReport(Campaign campaign) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CampaignReportScreen(campaignId: campaign.id),
      ),
    );
    await _refresh();
  }

  Future<void> _confirmArchiveCampaign(Campaign campaign) async {
    final shouldArchive =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(_t('Archive campaign?', 'I-archive ang kampanya?')),
            content: Text(
              _t(
                'Archived campaigns are hidden from the public list but kept in your records.',
                'Ang mga naka-archive na kampanya ay tatago sa public list pero mananatili sa iyong records.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  _t('Cancel', 'I-cancel'),
                  style: _actionLabelStyle(
                    context,
                    color: lightColorScheme.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  _t('Archive', 'I-archive'),
                  style: _actionLabelStyle(context, color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldArchive) return;

    try {
      await _service.archiveCampaign(campaign);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Campaign moved to archive.',
              'Nailipat na sa archive ang kampanya.',
            ),
          ),
        ),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _confirmRestoreCampaign(Campaign campaign) async {
    final shouldRestore =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(_t('Restore campaign?', 'Ibalik ang kampanya?')),
            content: Text(
              _t(
                'The campaign will return to its previous list and become manageable there again.',
                'Babalik ang kampanya sa dati nitong listahan at maaari mo ulit itong pamahalaan doon.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  _t('Cancel', 'I-cancel'),
                  style: _actionLabelStyle(
                    context,
                    color: lightColorScheme.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  _t('Restore', 'Ibalik'),
                  style: _actionLabelStyle(
                    context,
                    color: lightColorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldRestore) return;

    try {
      await _service.restoreCampaign(campaign);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_t('Campaign restored.', 'Naibalik na ang kampanya.')),
        ),
      );
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _handleCampaignAction(String value, Campaign campaign) async {
    switch (value) {
      case 'report':
        await _openReport(campaign);
        break;
      case 'archive':
        await _confirmArchiveCampaign(campaign);
        break;
      case 'restore':
        await _confirmRestoreCampaign(campaign);
        break;
    }
  }

  List<PopupMenuEntry<String>> _buildCampaignMenuItems(Campaign campaign) {
    final items = <PopupMenuEntry<String>>[];

    if (_isArchived(campaign)) {
      if (!_isDraft(campaign)) {
        items.add(
          PopupMenuItem<String>(
            value: 'report',
            child: Text(_t('Check report', 'Tingnan ang ulat')),
          ),
        );
      }
      items.add(
        PopupMenuItem<String>(
          value: 'restore',
          child: Text(_t('Restore', 'Ibalik')),
        ),
      );
      return items;
    }

    if (!_isDraft(campaign)) {
      items.add(
        PopupMenuItem<String>(
          value: 'report',
          child: Text(_t('Check report', 'Tingnan ang ulat')),
        ),
      );
    }

    items.add(
      PopupMenuItem<String>(
        value: 'archive',
        child: Text(_t('Archive', 'I-archive')),
      ),
    );

    return items;
  }

  Widget _buildDiscoverTab() {
    return FutureBuilder<List<Campaign>>(
      future: _discoverFuture,
      builder: (context, snapshot) {
        final campaigns = snapshot.data ?? [];
        final categories = _buildCategories(campaigns);

        if (!categories.contains(_discoverCategory)) {
          _discoverCategory = 'All';
        }

        final visible = _applyDiscoverFilters(campaigns);

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t(
                              'Discover Campaigns',
                              'Tuklasin ang mga Kampanya',
                            ),
                            style: _sectionTitleStyle(context),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _t(
                              'Choose a campaign to support or create a new one.',
                              'Pumili ng kampanyang nais suportahan o gumawa ng bago.',
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (widget.isCoop) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _openCreate(),
                        icon: const Icon(Icons.add),
                        label: Text(
                          _t('Create', 'Gumawa'),
                          style: _actionLabelStyle(
                            context,
                            color: lightColorScheme.onPrimary,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: lightColorScheme.primary,
                          foregroundColor: lightColorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: _buildGuideCard(
                  icon: Icons.touch_app_outlined,
                  title: _t('Quick guide', 'Madaling gabay'),
                  description: _t(
                    '1) Search or choose a category. 2) Tap the card. 3) Read the details before supporting.',
                    '1) Maghanap o pumili ng kategorya. 2) Pindutin ang card. 3) Basahin ang detalye bago sumuporta.',
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: TextField(
                  controller: _discoverSearchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: _t('Search campaigns', 'Maghanap ng kampanya'),
                    hintText: _t(
                      'Search title, category, or creator...',
                      'Maghanap ng pamagat, kategorya, o gumawa...',
                    ),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _discoverSearchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _discoverSearchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear),
                            tooltip: _t('Clear search', 'Linisin ang hanap'),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              if (categories.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categories.map((category) {
                        final selected = category == _discoverCategory;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(_categoryLabel(category)),
                            selected: selected,
                            onSelected: (_) {
                              setState(() => _discoverCategory = category);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<CampaignSort>(
                        initialValue: _sort,
                        items: [
                          DropdownMenuItem(
                            value: CampaignSort.popular,
                            child: Text(
                              _t('Sort: Most Popular', 'Ayos: Pinakasikat'),
                            ),
                          ),
                          DropdownMenuItem(
                            value: CampaignSort.endingSoon,
                            child: Text(
                              _t('Sort: Ending Soon', 'Ayos: Malapit matapos'),
                            ),
                          ),
                          DropdownMenuItem(
                            value: CampaignSort.newest,
                            child: Text(_t('Sort: Newest', 'Ayos: Pinakabago')),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _sort = value);
                        },
                        decoration: InputDecoration(
                          labelText: _t('Sort results', 'Ayusin ang resulta'),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _t(
                        '${visible.length} results',
                        '${visible.length} resulta',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  campaigns.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      AppLanguage.text(
                        en: 'There was a problem loading campaigns. Pull down to try again.',
                        tl: 'May problema sa pag-load. Hilahin pababa para subukan ulit.',
                      ),
                    ),
                  ),
                )
              else if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        _t(
                          'No campaigns match the selected filters.',
                          'Walang kampanyang tugma sa napiling filter.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          _discoverSearchController.clear();
                          setState(() {
                            _discoverCategory = 'All';
                            _sort = CampaignSort.newest;
                          });
                        },
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          _t('Reset filters', 'I-reset ang filter'),
                          style: _actionLabelStyle(context),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...visible.map(
                  (campaign) => CampaignCard(
                    campaign: campaign,
                    onTap: () => _openCampaign(campaign),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCampaignMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: lightColorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: lightColorScheme.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: lightColorScheme.primary),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildListingCard(Campaign campaign) {
    final statusColor = _statusColor(campaign);
    final statusLabel = _statusLabel(campaign);
    final edited = campaign.lastEditedAt ?? campaign.createdAt;
    final progress = campaign.goalAmount <= 0
        ? 0.0
        : (campaign.pledgedAmount / campaign.goalAmount).clamp(0.0, 1.0);
    final title = campaign.title.isEmpty
        ? _t('(Untitled)', '(Walang Pamagat)')
        : campaign.title;
    final category = campaign.category.trim().isEmpty
        ? _t('Uncategorized', 'Walang Kategorya')
        : _categoryLabel(campaign.category);
    final helperText = _isArchived(campaign)
        ? _t(
            'Tap to review this archived campaign.',
            'Pindutin para tingnan ang naka-archive na kampanyang ito.',
          )
        : _isDraft(campaign)
        ? _t(
            'Tap to continue editing this draft.',
            'Pindutin para ipagpatuloy ang pag-edit sa draft na ito.',
          )
        : _t(
            'Tap to open this campaign and review its details.',
            'Pindutin para buksan ang kampanya at tingnan ang mga detalye nito.',
          );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openCampaign(campaign),
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ) ??
                              const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        if (campaign.shortBlurb.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            campaign.shortBlurb,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: _t('More actions', 'Higit pang aksyon'),
                    onSelected: (value) =>
                        _handleCampaignAction(value, campaign),
                    itemBuilder: (_) => _buildCampaignMenuItems(campaign),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(statusLabel),
                    backgroundColor: statusColor.withValues(alpha: 0.14),
                    labelStyle: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                    side: BorderSide(
                      color: statusColor.withValues(alpha: 0.35),
                    ),
                  ),
                  Chip(label: Text(category)),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
              const SizedBox(height: 8),
              Text(
                '${formatPeso(campaign.pledgedAmount)} / ${formatPeso(campaign.goalAmount)}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCampaignMetric(
                    icon: Icons.flag_outlined,
                    label: _t('Goal', 'Target'),
                    value: formatPeso(campaign.goalAmount),
                  ),
                  _buildCampaignMetric(
                    icon: Icons.people_outline,
                    label: _t('Backers', 'Mga Backer'),
                    value: '${campaign.backersCount}',
                  ),
                  _buildCampaignMetric(
                    icon: Icons.update_outlined,
                    label: _t('Updated', 'Na-update'),
                    value: '${edited.month}/${edited.day}/${edited.year}',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                helperText,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManageTab(CampaignManagementTab tab) {
    return FutureBuilder<List<Campaign>>(
      future: _myListingsFuture,
      builder: (context, snapshot) {
        final listings = snapshot.data ?? [];
        final visible = _applyManageFilters(listings, tab);
        final guideIcon = switch (tab) {
          CampaignManagementTab.live => Icons.public_outlined,
          CampaignManagementTab.ended => Icons.event_busy_outlined,
          CampaignManagementTab.drafts => Icons.edit_note_outlined,
          CampaignManagementTab.archive => Icons.archive_outlined,
        };
        final guideDescription = switch (tab) {
          CampaignManagementTab.live => _t(
            'Use the three-dot menu to check reports or archive a campaign when it should leave the public list.',
            'Gamitin ang three-dot menu para tingnan ang ulat o i-archive ang kampanya kapag dapat na itong alisin sa public list.',
          ),
          CampaignManagementTab.ended => _t(
            'Ended campaigns stay separate here so reports are easier to review without mixing them into active ones.',
            'Nakahiwalay rito ang mga natapos na kampanya para mas madaling suriin ang mga ulat nang hindi nahahalo sa mga aktibo.',
          ),
          CampaignManagementTab.drafts => _t(
            'Tap a draft tile to keep editing it, or archive it if you want to set it aside for now.',
            'Pindutin ang draft tile para magpatuloy sa pag-edit, o i-archive ito kung nais mo muna itong itabi.',
          ),
          CampaignManagementTab.archive => _t(
            'Restore archived campaigns from the menu when you need to manage them again.',
            'Ibalik mula sa menu ang mga naka-archive kapag kailangan mo ulit silang pamahalaan.',
          ),
        };

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _tabTitle(tab),
                          style: _sectionTitleStyle(context),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _tabDescription(tab),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _openCreate(),
                    icon: const Icon(Icons.add),
                    label: Text(
                      _t('New', 'Bago'),
                      style: _actionLabelStyle(
                        context,
                        color: lightColorScheme.onPrimary,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lightColorScheme.primary,
                      foregroundColor: lightColorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildGuideCard(
                icon: guideIcon,
                title: _t('Campaign tools', 'Mga tool ng kampanya'),
                description: guideDescription,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _manageSearchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: _t('Search campaigns', 'Hanapin ang mga kampanya'),
                  hintText: _t(
                    'Search campaigns...',
                    'Maghanap ng kampanya...',
                  ),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _manageSearchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _manageSearchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                          tooltip: _t('Clear search', 'Linisin ang hanap'),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 14),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  listings.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      AppLanguage.text(
                        en: 'There was a problem loading campaigns. Pull down to try again.',
                        tl: 'May problema sa pag-load. Hilahin pababa para subukan ulit.',
                      ),
                    ),
                  ),
                )
              else if (visible.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _emptyStateTitle(tab),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ) ??
                              const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          listings.isEmpty
                              ? _emptyStateDescription(tab)
                              : _t(
                                  'No campaigns in this tab match your search right now.',
                                  'Walang kampanya sa tab na ito ang tugma sa hinahanap mo ngayon.',
                                ),
                        ),
                        const SizedBox(height: 12),
                        if (listings.isEmpty ||
                            _manageSearchController.text.isEmpty)
                          ElevatedButton.icon(
                            onPressed: () => _openCreate(),
                            icon: const Icon(Icons.add),
                            label: Text(
                              _t('Create Campaign', 'Gumawa ng Kampanya'),
                              style: _actionLabelStyle(
                                context,
                                color: lightColorScheme.onPrimary,
                              ),
                            ),
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: () {
                              _manageSearchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.refresh),
                            label: Text(
                              _t('Clear search', 'Linisin ang hanap'),
                              style: _actionLabelStyle(context),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              else
                ...visible.map(_buildListingCard),
            ],
          ),
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
    );

    if (!widget.isCoop) {
      // Prosumers only see the public discover feed.
      return AppLanguageScope(
        builder: (context) => Theme(
          data: campaignTheme,
          child: Scaffold(
            appBar: widget.appBarOverride ?? const CustomAppBar(),
            drawer: widget.drawerOverride ?? CustomDrawer(onLogout: logout),
            body: _buildDiscoverTab(),
          ),
        ),
      );
    }

    return AppLanguageScope(
      builder: (context) => Theme(
        data: campaignTheme,
        child: Scaffold(
          appBar: widget.appBarOverride ?? const CustomAppBar(),
          drawer: widget.drawerOverride ?? CustomDrawer(onLogout: logout),
          body: Column(
            children: [
              FutureBuilder<List<Campaign>>(
                future: _myListingsFuture,
                builder: (context, snapshot) {
                  final listings = snapshot.data ?? const <Campaign>[];
                  final showCount =
                      snapshot.connectionState != ConnectionState.waiting ||
                      snapshot.hasData;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: _buildManagementTabBar(
                      listings,
                      showCount: showCount,
                    ),
                  );
                },
              ),
              Expanded(
                child: TabBarView(
                  controller: _manageTabController,
                  children: [
                    _buildManageTab(CampaignManagementTab.live),
                    _buildManageTab(CampaignManagementTab.ended),
                    _buildManageTab(CampaignManagementTab.drafts),
                    _buildManageTab(CampaignManagementTab.archive),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
