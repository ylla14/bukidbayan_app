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

enum ListingFilter { all, drafts, live, ended }

class CrowdfundingScreen extends StatefulWidget {
  final CrowdfundingService? serviceOverride;
  final FirebaseAuth? authOverride;
  final PreferredSizeWidget? appBarOverride;
  final Widget? drawerOverride;

  /// True when the logged-in user is the co-op account.
  /// Shows both tabs and create buttons. Prosumers see only the Discover tab.
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

class _CrowdfundingScreenState extends State<CrowdfundingScreen> {
  late final CrowdfundingService _service;
  FirebaseAuth? _auth;

  final TextEditingController _discoverSearchController =
      TextEditingController();
  final TextEditingController _manageSearchController = TextEditingController();

  late Future<List<Campaign>> _discoverFuture;
  late Future<List<Campaign>> _myListingsFuture;

  String _discoverCategory = 'All';
  CampaignSort _sort = CampaignSort.newest;
  ListingFilter _listingFilter = ListingFilter.all;

  @override
  void initState() {
    super.initState();
    _service = widget.serviceOverride ?? CrowdfundingService();
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

  bool _isEnded(Campaign c) {
    return c.status.startsWith('ended') || DateTime.now().isAfter(c.endDate);
  }

  List<Campaign> _applyManageFilters(List<Campaign> listings) {
    final q = _manageSearchController.text.trim().toLowerCase();

    final filtered = listings.where((c) {
      final matchesSearch =
          q.isEmpty ||
          c.title.toLowerCase().contains(q) ||
          c.shortBlurb.toLowerCase().contains(q) ||
          c.category.toLowerCase().contains(q);

      bool matchesFilter;
      switch (_listingFilter) {
        case ListingFilter.all:
          matchesFilter = true;
          break;
        case ListingFilter.drafts:
          matchesFilter = c.status == 'draft';
          break;
        case ListingFilter.live:
          matchesFilter = c.status == 'live' && !_isEnded(c);
          break;
        case ListingFilter.ended:
          matchesFilter = _isEnded(c);
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

  String _statusLabel(Campaign c) {
    if (c.status == 'draft') return _t('Draft', 'Draft');
    if (_isEnded(c)) return _t('Ended', 'Tapos na');
    if (c.status == 'live') return _t('Live', 'Aktibo');
    return c.status;
  }

  Color _statusColor(Campaign c) {
    if (c.status == 'draft') return Colors.orange;
    if (_isEnded(c)) return Colors.grey;
    if (c.status == 'live') return Colors.green;
    return lightColorScheme.primary;
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
    if (campaign.status == 'draft') {
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

  Future<void> _confirmDeleteDraft(Campaign draft) async {
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(_t('Delete Draft?', 'Burahin ang Draft?')),
            content: Text(
              _t(
                'This cannot be undone after deletion.',
                'Hindi na ito maibabalik kapag nabura.',
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
                  _t('Delete', 'Burahin'),
                  style: _actionLabelStyle(context, color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;

    await _service.deleteDraft(draft.id);
    await _refresh();
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
                        value: _sort,
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

  Widget _buildListingCard(Campaign campaign) {
    final statusColor = _statusColor(campaign);
    final statusLabel = _statusLabel(campaign);
    final edited = campaign.lastEditedAt ?? campaign.createdAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minVerticalPadding: 10,
        onTap: () => _openCampaign(campaign),
        title: Text(
          campaign.title.isEmpty
              ? _t('(Untitled)', '(Walang Pamagat)')
              : campaign.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text(statusLabel),
                    backgroundColor: statusColor.withOpacity(0.14),
                    labelStyle: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: statusColor.withOpacity(0.35)),
                  ),
                  Chip(label: Text(_categoryLabel(campaign.category))),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_t('Target', 'Target')}: ${formatPeso(campaign.goalAmount)}',
              ),
              const SizedBox(height: 2),
              Text(
                _t(
                  'Tap the card to open and manage it.',
                  'Pindutin ang card para buksan at i-manage.',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.black54),
              ),
              Text(
                '${_t('Last updated', 'Huling update')}: ${edited.month}/${edited.day}/${edited.year}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: _t('More actions', 'Higit pang aksyon'),
          onSelected: (value) async {
            if (value == 'open') {
              await _openCampaign(campaign);
            } else if (value == 'edit') {
              await _openCreate(draft: campaign);
            } else if (value == 'delete') {
              await _confirmDeleteDraft(campaign);
            } else if (value == 'report') {
              await _openReport(campaign);
            }
          },
          itemBuilder: (context) {
            final items = <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'open',
                child: Text(_t('Open', 'Buksan')),
              ),
            ];

            if (campaign.status == 'draft') {
              items.addAll([
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Text(_t('Edit Draft', 'I-edit ang Draft')),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text(_t('Delete Draft', 'Burahin ang Draft')),
                ),
              ]);
            } else {
              items.add(
                PopupMenuItem<String>(
                  value: 'report',
                  child: Text(
                    _isEnded(campaign)
                        ? _t('Open Report', 'Gumawa ng Ulat')
                        : _t('Current Report', 'Kasalukuyang Ulat'),
                  ),
                ),
              );
            }

            return items;
          },
        ),
      ),
    );
  }

  Widget _buildManageTab() {
    return FutureBuilder<List<Campaign>>(
      future: _myListingsFuture,
      builder: (context, snapshot) {
        final listings = snapshot.data ?? [];
        final draftsCount = listings.where((c) => c.status == 'draft').length;
        final liveCount = listings
            .where((c) => c.status == 'live' && !_isEnded(c))
            .length;
        final endedCount = listings.where(_isEnded).length;

        final visible = _applyManageFilters(listings);

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
                          _t('My Campaigns', 'Aking Mga Kampanya'),
                          style: _sectionTitleStyle(context),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _t(
                            'View your draft, live, and ended campaigns here.',
                            'Dito mo makikita ang draft, aktibo, at tapos na kampanya.',
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
                ],
              ),
              const SizedBox(height: 12),
              _buildGuideCard(
                icon: Icons.task_alt_outlined,
                title: _t('Quick management', 'Mabilis na pamamahala'),
                description: _t(
                  'Use the status filter to quickly find drafts, live, or ended campaigns.',
                  'Gamitin ang status filter para makita agad kung alin ang draft, aktibo, o tapos na.',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text('${_t('All', 'Lahat')}: ${listings.length}'),
                  ),
                  Chip(label: Text('${_t('Draft', 'Draft')}: $draftsCount')),
                  Chip(label: Text('${_t('Live', 'Aktibo')}: $liveCount')),
                  Chip(label: Text('${_t('Ended', 'Tapos na')}: $endedCount')),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _manageSearchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: _t(
                    'Search my campaigns',
                    'Hanapin sa mga kampanya ko',
                  ),
                  hintText: _t(
                    'Search my campaigns...',
                    'Hanapin ang mga kampanya ko...',
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
              const SizedBox(height: 12),
              SegmentedButton<ListingFilter>(
                segments: [
                  ButtonSegment<ListingFilter>(
                    value: ListingFilter.all,
                    label: Text(
                      _t('All', 'Lahat'),
                      style: _actionLabelStyle(context),
                    ),
                  ),
                  ButtonSegment<ListingFilter>(
                    value: ListingFilter.drafts,
                    label: Text(
                      _t('Draft', 'Draft'),
                      style: _actionLabelStyle(context),
                    ),
                  ),
                  ButtonSegment<ListingFilter>(
                    value: ListingFilter.live,
                    label: Text(
                      _t('Live', 'Aktibo'),
                      style: _actionLabelStyle(context),
                    ),
                  ),
                  ButtonSegment<ListingFilter>(
                    value: ListingFilter.ended,
                    label: Text(
                      _t('Ended', 'Tapos na'),
                      style: _actionLabelStyle(context),
                    ),
                  ),
                ],
                selected: {_listingFilter},
                onSelectionChanged: (selection) {
                  setState(() => _listingFilter = selection.first);
                },
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
              else if (listings.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t(
                            'You do not have any campaigns yet',
                            'Wala ka pang kampanya',
                          ),
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
                          _t(
                            'Create your first campaign draft to start gathering support.',
                            'Gumawa ng unang draft ng kampanya para makapagsimulang mangalap ng pondo.',
                          ),
                        ),
                        if (widget.isCoop) ...[
                          const SizedBox(height: 12),
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
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
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
                            _manageSearchController.clear();
                            setState(() => _listingFilter = ListingFilter.all);
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            _t('Show all', 'Ipakita lahat'),
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
      // Prosumers only see the Discover tab — no tab bar needed.
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
        child: DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: widget.appBarOverride ?? const CustomAppBar(),
            drawer: widget.drawerOverride ?? CustomDrawer(onLogout: logout),
            body: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: TabBar(
                    isScrollable: true,
                    labelColor: lightColorScheme.primary,
                    unselectedLabelColor: Colors.black54,
                    indicatorColor: lightColorScheme.primary,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                    tabs: [
                      Tab(text: _t('Discover', 'Tuklasin')),
                      Tab(text: _t('My Campaigns', 'Aking Mga Kampanya')),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [_buildDiscoverTab(), _buildManageTab()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
