import 'package:bukidbayan_app/components/app_bar.dart';
import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/screens/campaign_creation/campaign_creation_screen.dart';
import 'package:bukidbayan_app/screens/campaign_detail_screen.dart';
import 'package:bukidbayan_app/screens/campaign_report_screen.dart';
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
  static const Map<String, String> _categoryLabels = {
    'All': 'Lahat',
    'Irrigation': 'Patubig',
    'Crop Care': 'Pangangalaga ng Pananim',
    'Post-harvest': 'Pagkatapos ng Ani',
    'Mechanized Tools': 'Mekanikal na Kagamitan',
    'Livestock': 'Alagang Hayop',
    'Solar/Power': 'Solar/Kuryente',
    'Hand Tools': 'Kagamitang Kamay',
    'Other': 'Iba pa',
  };

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

  String _categoryLabel(String value) => _categoryLabels[value] ?? value;

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
                Text(
                  description,
                  style: const TextStyle(fontSize: 13),
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
    if (c.status == 'draft') return 'Draft';
    if (_isEnded(c)) return 'Tapos na';
    if (c.status == 'live') return 'Aktibo';
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
            title: const Text('Burahin ang Draft?'),
            content: const Text('Hindi na ito maibabalik kapag nabura.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Burahin',
                  style: TextStyle(color: Colors.red),
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
                            'Tuklasin ang mga Kampanya',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: lightColorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Pumili ng kampanyang nais suportahan o gumawa ng bago.',
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
                        label: const Text('Gumawa'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: lightColorScheme.primary,
                          foregroundColor: Colors.white,
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
                  title: 'Madaling gabay',
                  description:
                      '1) Maghanap o pumili ng kategorya. 2) Pindutin ang card. 3) Basahin ang detalye bago sumuporta.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: TextField(
                  controller: _discoverSearchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Maghanap ng kampanya',
                    hintText: 'Maghanap ng pamagat, kategorya, o gumawa...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _discoverSearchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _discoverSearchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear),
                            tooltip: 'Linisin ang hanap',
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
                        items: const [
                          DropdownMenuItem(
                            value: CampaignSort.popular,
                            child: Text('Ayos: Pinakasikat'),
                          ),
                          DropdownMenuItem(
                            value: CampaignSort.endingSoon,
                            child: Text('Ayos: Malapit matapos'),
                          ),
                          DropdownMenuItem(
                            value: CampaignSort.newest,
                            child: Text('Ayos: Pinakabago'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _sort = value);
                        },
                        decoration: InputDecoration(
                          labelText: 'Ayusin ang resulta',
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
                      '${visible.length} resulta',
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
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text('May problema sa pag-load. Hilahin pababa para subukan ulit.'),
                  ),
                )
              else if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text('Walang kampanyang tugma sa napiling filter.'),
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
                        label: const Text('I-reset ang filter'),
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
          campaign.title.isEmpty ? '(Walang Pamagat)' : campaign.title,
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
              Text('Target: ${formatPeso(campaign.goalAmount)}'),
              const SizedBox(height: 2),
              const Text(
                'Pindutin ang card para buksan at i-manage.',
                style: TextStyle(fontSize: 12),
              ),
              Text(
                'Huling update: ${edited.month}/${edited.day}/${edited.year}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'Higit pang aksyon',
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
              const PopupMenuItem<String>(value: 'open', child: Text('Buksan')),
            ];

            if (campaign.status == 'draft') {
              items.addAll(const [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Edit Draft'),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Burahin ang Draft'),
                ),
              ]);
            } else {
              items.add(
                PopupMenuItem<String>(
                  value: 'report',
                  child: Text(
                    _isEnded(campaign)
                        ? 'Gumawa ng Ulat'
                        : 'Kasalukuyang Ulat',
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
                          'Aking Mga Kampanya',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: lightColorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Dito mo makikita ang draft, aktibo, at tapos na kampanya.',
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
                      label: const Text('Bago'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: lightColorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              _buildGuideCard(
                icon: Icons.task_alt_outlined,
                title: 'Mabilis na pamamahala',
                description:
                    'Gamitin ang status filter para makita agad kung alin ang draft, aktibo, o tapos na.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('Lahat: ${listings.length}')),
                  Chip(label: Text('Draft: $draftsCount')),
                  Chip(label: Text('Aktibo: $liveCount')),
                  Chip(label: Text('Tapos na: $endedCount')),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _manageSearchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Hanapin sa mga kampanya ko',
                  hintText: 'Hanapin ang mga kampanya ko...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _manageSearchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _manageSearchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                          tooltip: 'Linisin ang hanap',
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
                segments: const [
                  ButtonSegment<ListingFilter>(
                    value: ListingFilter.all,
                    label: Text('Lahat'),
                  ),
                  ButtonSegment<ListingFilter>(
                    value: ListingFilter.drafts,
                    label: Text('Draft'),
                  ),
                  ButtonSegment<ListingFilter>(
                    value: ListingFilter.live,
                    label: Text('Aktibo'),
                  ),
                  ButtonSegment<ListingFilter>(
                    value: ListingFilter.ended,
                    label: Text('Ended'),
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
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text('May problema sa pag-load. Hilahin pababa para subukan ulit.'),
                  ),
                )
              else if (listings.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Wala ka pang kampanya',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Gumawa ng unang draft ng kampanya para makapagsimulang mangalap ng pondo.',
                        ),
                        if (widget.isCoop) ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => _openCreate(),
                            icon: const Icon(Icons.add),
                            label: const Text('Gumawa ng Kampanya'),
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
                        const Text('Walang kampanyang tugma sa napiling filter.'),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            _manageSearchController.clear();
                            setState(() => _listingFilter = ListingFilter.all);
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Ipakita lahat'),
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
      return Theme(
        data: campaignTheme,
        child: Scaffold(
          appBar: widget.appBarOverride ?? const CustomAppBar(),
          drawer: widget.drawerOverride ?? CustomDrawer(onLogout: logout),
          body: _buildDiscoverTab(),
        ),
      );
    }

    return Theme(
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
                  tabs: const [
                    Tab(text: 'Tuklasin'),
                    Tab(text: 'Aking Mga Kampanya'),
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
    );
  }
}
