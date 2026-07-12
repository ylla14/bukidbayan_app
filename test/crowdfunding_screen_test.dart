import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/screens/crowdfunding_screen.dart';
import 'package:bukidbayan_app/services/crowdfunding_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCrowdfundingService extends CrowdfundingService {
  FakeCrowdfundingService({
    required this.discoverCampaigns,
    required this.myCampaigns,
  });

  final List<Campaign> discoverCampaigns;
  final List<Campaign> myCampaigns;
  final List<String> deletedDraftIds = [];

  @override
  Future<List<Campaign>> getCampaigns() async => discoverCampaigns;

  @override
  Future<List<Campaign>> getMyCampaigns({
    String? userEmail,
    String? status,
  }) async {
    if (status == null) return myCampaigns;
    return myCampaigns.where((c) => c.status == status).toList();
  }

  @override
  Future<void> deleteDraft(String draftId) async {
    deletedDraftIds.add(draftId);
  }
}

Campaign _campaign({
  required String id,
  required String title,
  required String category,
  required String status,
  DateTime? endDate,
}) {
  return Campaign(
    id: id,
    title: title,
    creatorName: 'Tester',
    creatorEmail: 'tester@example.com',
    shortBlurb: 'A valid short blurb for testing.',
    description:
        'A long enough description to satisfy campaign rendering needs.',
    isAssetImage: true,
    image: 'assets/images/farmBg.jpg',
    category: category,
    goalAmount: 10000,
    pledgedAmount: 1000,
    backersCount: 3,
    endDate: endDate ?? DateTime.now().add(const Duration(days: 12)),
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    rewards: const [],
    status: status,
  );
}

Widget _buildHarness(FakeCrowdfundingService service) {
  return _buildHarnessWithRole(service, isCoop: true);
}

Widget _buildHarnessWithRole(
  FakeCrowdfundingService service, {
  required bool isCoop,
}) {
  return MaterialApp(
    home: CrowdfundingScreen(
      serviceOverride: service,
      appBarOverride: AppBar(title: const Text('Test AppBar')),
      drawerOverride: const Drawer(child: SizedBox.shrink()),
      isCoop: isCoop,
    ),
  );
}

void main() {
  testWidgets('Discover tab filters campaigns by search text', (tester) async {
    final service = FakeCrowdfundingService(
      discoverCampaigns: [
        _campaign(
          id: 'c1',
          title: 'Solar Pump Upgrade',
          category: 'Solar/Power',
          status: 'live',
        ),
        _campaign(
          id: 'c2',
          title: 'Irrigation Hose Bundle',
          category: 'Irrigation',
          status: 'live',
        ),
      ],
      myCampaigns: const [],
    );

    await tester.pumpWidget(_buildHarnessWithRole(service, isCoop: false));
    await tester.pumpAndSettle();

    expect(find.text('2 results'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'solar');
    await tester.pumpAndSettle();

    expect(find.text('1 results'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Solar Pump Upgrade'),
      find.byType(ListView),
      const Offset(0, -250),
    );

    expect(find.text('Solar Pump Upgrade'), findsOneWidget);
  });

  testWidgets('Live tab filters listings by manage search', (tester) async {
    final service = FakeCrowdfundingService(
      discoverCampaigns: const [],
      myCampaigns: [
        _campaign(
          id: 'd1',
          title: 'Draft One Listing',
          category: 'Irrigation',
          status: 'draft',
        ),
        _campaign(
          id: 'l1',
          title: 'Live Campaign Listing',
          category: 'Solar/Power',
          status: 'live',
        ),
      ],
    );

    await tester.pumpWidget(_buildHarness(service));
    await tester.pumpAndSettle();

    expect(find.text('Live Campaign Listing'), findsOneWidget);
    expect(find.text('Draft One Listing'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'live campaign');
    await tester.pumpAndSettle();

    expect(find.text('Live Campaign Listing'), findsOneWidget);
    expect(find.byTooltip('More actions'), findsOneWidget);
  });

  testWidgets('Drafts tab shows draft-specific empty state', (tester) async {
    final service = FakeCrowdfundingService(
      discoverCampaigns: const [],
      myCampaigns: const [],
    );

    await tester.pumpWidget(_buildHarness(service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Drafts').first);
    await tester.pumpAndSettle();

    expect(find.text('No drafts yet'), findsOneWidget);
    expect(
      find.text('Create a draft to prepare your next campaign.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Ended tab shows check report and archive actions for finished campaigns',
    (tester) async {
      final service = FakeCrowdfundingService(
        discoverCampaigns: const [],
        myCampaigns: [
          _campaign(
            id: 'e1',
            title: 'Ended Campaign',
            category: 'Irrigation',
            status: 'live',
            endDate: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ],
      );

      await tester.pumpWidget(_buildHarness(service));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ended'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      expect(find.text('Check report'), findsOneWidget);
      expect(find.text('Archive'), findsWidgets);
    },
  );

  testWidgets('Archive tab shows restore action for archived campaigns', (
    tester,
  ) async {
    final service = FakeCrowdfundingService(
      discoverCampaigns: const [],
      myCampaigns: [
        _campaign(
          id: 'a1',
          title: 'Archived Campaign',
          category: 'Solar/Power',
          status: 'archived_live',
        ),
      ],
    );

    await tester.pumpWidget(_buildHarness(service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Archive').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();

    expect(find.text('Check report'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
  });
}
