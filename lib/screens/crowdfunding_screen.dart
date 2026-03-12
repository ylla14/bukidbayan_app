import 'package:bukidbayan_app/components/app_bar.dart';
import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/screens/campaign_creation/campaign_creation_screen.dart';
import 'package:bukidbayan_app/screens/campaign_detail_screen.dart';
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

  const CrowdfundingScreen({
    super.key,
    this.serviceOverride,
    this.authOverride,
    this.appBarOverride,
    this.drawerOverride,
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
  CampaignSort _sort = CampaignSort.popular;
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
      final matchesSearch = q.isEmpty ||
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
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
      final matchesSearch = q.isEmpty ||
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
    if (_isEnded(c)) return 'Ended';
    if (c.status == 'live') return 'Live';
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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CampaignCreationScreen(existingDraft: draft),
      ),
    );
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

  Future<void> _confirmDeleteDraft(Campaign draft) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Draft?'),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Delete',
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Discover Campaigns',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: lightColorScheme.primary,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openCreate(),
                      icon: const Icon(Icons.add),
                      label: const Text('Create'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: lightColorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: TextField(
                  controller: _discoverSearchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search title, category, or creator...',
                    prefixIcon: const Icon(Icons.search),
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
                            label: Text(category),
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
                            child: Text('Sort: Popular'),
                          ),
                          DropdownMenuItem(
                            value: CampaignSort.endingSoon,
                            child: Text('Sort: Ending soon'),
                          ),
                          DropdownMenuItem(
                            value: CampaignSort.newest,
                            child: Text('Sort: Newest'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _sort = value);
                        },
                        decoration: InputDecoration(
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
                      '${visible.length} result${visible.length == 1 ? '' : 's'}',
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
              else if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('No campaigns match your filters.')),
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
        onTap: () => _openCampaign(campaign),
        title: Text(
          campaign.title.isEmpty ? '(Untitled Campaign)' : campaign.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
                  Chip(label: Text(campaign.category)),
                ],
              ),
              const SizedBox(height: 4),
              Text('Goal: ${formatPeso(campaign.goalAmount)}'),
              Text(
                'Updated: ${edited.month}/${edited.day}/${edited.year}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'open') {
              await _openCampaign(campaign);
            } else if (value == 'edit') {
              await _openCreate(draft: campaign);
            } else if (value == 'delete') {
              await _confirmDeleteDraft(campaign);
            }
          },
          itemBuilder: (context) {
            final items = <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'open',
                child: Text('Open'),
              ),
            ];

            if (campaign.status == 'draft') {
              items.addAll(const [
                PopupMenuItem<String>(
                  value: 'edit',
                  child: Text('Edit Draft'),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Delete Draft'),
                ),
              ]);
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Listings',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: lightColorScheme.primary,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openCreate(),
                    icon: const Icon(Icons.add),
                    label: const Text('New'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lightColorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('All: ${listings.length}')),
                  Chip(label: Text('Drafts: $draftsCount')),
                  Chip(label: Text('Live: $liveCount')),
                  Chip(label: Text('Ended: $endedCount')),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _manageSearchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search my listings...',
                  prefixIcon: const Icon(Icons.search),
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
                    label: Text('All'),
                  ),
                  ButtonSegment<ListingFilter>(
                    value: ListingFilter.drafts,
                    label: Text('Drafts'),
                  ),
                  ButtonSegment<ListingFilter>(
                    value: ListingFilter.live,
                    label: Text('Live'),
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
              else if (listings.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'No listings yet',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create your first campaign draft to start raising funds.',
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _openCreate(),
                          icon: const Icon(Icons.add),
                          label: const Text('Create Campaign'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('No listings match the selected filter.'),
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: widget.appBarOverride ?? const CustomAppBar(),
        drawer: widget.drawerOverride ?? CustomDrawer(onLogout: logout),
        body: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: TabBar(
                labelColor: lightColorScheme.primary,
                indicatorColor: lightColorScheme.primary,
                tabs: const [
                  Tab(text: 'Discover'),
                  Tab(text: 'My Listings'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildDiscoverTab(),
                  _buildManageTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
