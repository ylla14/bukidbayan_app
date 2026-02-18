import 'package:bukidbayan_app/components/app_bar.dart';
import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/screens/campaign_detail_screen.dart';
import 'package:bukidbayan_app/screens/campaign_creation/campaign_creation_screen.dart';
import 'package:bukidbayan_app/services/crowdfunding_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/campaign_card.dart' hide formatPeso;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/utils/money_format.dart';

enum CampaignSort { popular, endingSoon, newest }

class CrowdfundingScreen extends StatefulWidget {
  const CrowdfundingScreen({super.key});

  @override
  State<CrowdfundingScreen> createState() => _CrowdfundingScreenState();
}

class _CrowdfundingScreenState extends State<CrowdfundingScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CrowdfundingService service = CrowdfundingService();
  final TextEditingController searchController = TextEditingController();

  late Future<List<Campaign>> _future;
  late Future<List<Campaign>> _draftsFuture;
  String _category = 'All';
  CampaignSort _sort = CampaignSort.popular;

  @override
  void initState() {
    super.initState();
    _future = service.getCampaigns();
    _draftsFuture = service.getDrafts();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = service.getCampaigns();
      _draftsFuture = service.getDrafts();
    });
    await Future.wait([_future, _draftsFuture]);
  }

  List<String> _buildCategories(List<Campaign> campaigns) {
    final set = <String>{'All'};
    for (final c in campaigns) {
      set.add(c.category);
    }
    return set.toList();
  }

  List<Campaign> _applyFilters(List<Campaign> campaigns) {
    final q = searchController.text.trim().toLowerCase();

    var filtered = campaigns.where((c) {
      final matchesSearch = q.isEmpty ||
          c.title.toLowerCase().contains(q) ||
          c.shortBlurb.toLowerCase().contains(q) ||
          c.creatorName.toLowerCase().contains(q);

      final matchesCategory = _category == 'All' || c.category == _category;

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

  Future<void> logout() async {
  await _auth.signOut();
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      drawer: CustomDrawer(onLogout: logout,),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Campaign>>(
              future: _future,
              builder: (context, snapshot) {
                final campaigns = snapshot.data ?? [];
                final categories = _buildCategories(campaigns);
                final visible = _applyFilters(campaigns);

                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 20),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Crowdfund',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: lightColorScheme.primary,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CampaignCreationScreen(),
                                  ),
                                ).then((_) => _refresh());
                              },
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
                      // My Drafts Section
                      FutureBuilder<List<Campaign>>(
                        future: _draftsFuture,
                        builder: (context, draftSnapshot) {
                          final drafts = draftSnapshot.data ?? [];
                          if (drafts.isNotEmpty) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'My Drafts',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: lightColorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...drafts.map((draft) {
                                    final lastEdited = draft.lastEditedAt ?? draft.createdAt;
                                    final lastEditedText =
                                        '${lastEdited.month}/${lastEdited.day}/${lastEdited.year}';
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: ListTile(
                                        title: Text(
                                          draft.title.isEmpty
                                              ? '(Untitled Draft)'
                                              : draft.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          'Last edited: $lastEditedText',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                        trailing: PopupMenuButton<String>(
                                          onSelected: (value) async {
                                            if (value == 'edit') {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      CampaignCreationScreen(
                                                        existingDraft: draft,
                                                      ),
                                                ),
                                              ).then((_) => _refresh());
                                            } else if (value == 'delete') {
                                              showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                  title: const Text(
                                                      'Delete Draft?'),
                                                  content: const Text(
                                                    'This action cannot be undone.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context),
                                                      child:
                                                          const Text('Cancel'),
                                                    ),
                                                    TextButton(
                                                      onPressed: () async {
                                                        await service
                                                            .deleteDraft(
                                                                draft.id);
                                                        Navigator.pop(
                                                            context);
                                                        _refresh();
                                                      },
                                                      child: const Text(
                                                        'Delete',
                                                        style: TextStyle(
                                                            color:
                                                                Colors.red),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }
                                          },
                                          itemBuilder: (BuildContext context) =>
                                              <PopupMenuEntry<String>>[
                                            const PopupMenuItem<String>(
                                              value: 'edit',
                                              child: Text('Edit'),
                                            ),
                                            const PopupMenuItem<String>(
                                              value: 'delete',
                                              child: Text('Delete'),
                                            ),
                                          ],
                                        ),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  CampaignCreationScreen(
                                                    existingDraft: draft,
                                                  ),
                                            ),
                                          ).then((_) => _refresh());
                                        },
                                      ),
                                    );
                                  }).toList(),
                                  const Divider(height: 24),
                                ],
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                        child: TextField(
                          controller: searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search projects...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _category,
                                items: categories
                                    .map((c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(c),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _category = v);
                                },
                                decoration: InputDecoration(
                                  labelText: 'Category',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<CampaignSort>(
                                value: _sort,
                                items: const [
                                  DropdownMenuItem(
                                    value: CampaignSort.popular,
                                    child: Text('Popular'),
                                  ),
                                  DropdownMenuItem(
                                    value: CampaignSort.endingSoon,
                                    child: Text('Ending soon'),
                                  ),
                                  DropdownMenuItem(
                                    value: CampaignSort.newest,
                                    child: Text('Newest'),
                                  ),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _sort = v);
                                },
                                decoration: InputDecoration(
                                  labelText: 'Sort',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (visible.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: Text('No projects found.')),
                        )
                      else
                        ...visible.map(
                          (c) => CampaignCard(
                            campaign: c,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      CampaignDetailScreen(campaignId: c.id),
                                ),
                              ).then((_) => _refresh());
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
