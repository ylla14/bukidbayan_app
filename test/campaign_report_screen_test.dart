import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/models/campaign_report.dart';
import 'package:bukidbayan_app/screens/campaign_report_screen.dart';
import 'package:bukidbayan_app/services/crowdfunding_service.dart';
import 'package:bukidbayan_app/utils/money_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCampaignReportService extends CrowdfundingService {
  FakeCampaignReportService(this.report);

  final CampaignReport report;

  @override
  Future<CampaignReport> generateCampaignReport({
    required String campaignId,
    String? userEmail,
  }) async {
    return report;
  }
}

Campaign _buildCampaign() {
  return Campaign(
    id: 'campaign_report_test',
    title: 'Test Campaign',
    creatorName: 'Owner',
    creatorEmail: 'owner@example.com',
    shortBlurb: 'Short blurb for report screen test',
    description: 'Long description for report screen widget test coverage.',
    isAssetImage: true,
    image: 'assets/images/farmBg.jpg',
    category: 'Irrigation',
    goalAmount: 10000,
    pledgedAmount: 1700,
    backersCount: 3,
    endDate: DateTime.now().add(const Duration(days: 7)),
    createdAt: DateTime(2026, 3, 1),
    publishedAt: DateTime(2026, 3, 2),
    rewards: const [
      RewardTier(
        id: 'r1',
        title: 'Reward One',
        minPledge: 300,
        discountType: 'percent',
        discountValue: 5,
        usageLimit: 1,
        validityDays: 30,
      ),
    ],
    specs: const {'Spec1': 'A', 'Spec2': 'B', 'Spec3': 'C'},
    includedItems: const ['Item1', 'Item2'],
    productionTimeline: 'Week 1 to Week 2 implementation',
    shippingCoverage: 'Local delivery',
    shippingCostHandling: 'included',
    warranty: 'One year warranty support',
    spareParts: 'Spare parts ready',
    risks: 'Possible weather delays',
    safetyNotes: 'Follow safety guidelines',
    status: 'live',
  );
}

CampaignReport _buildReport() {
  final campaign = _buildCampaign();
  final pledges = [
    Pledge(
      id: 'p1',
      campaignId: campaign.id,
      backerEmail: 'small@example.com',
      backerName: 'Munting Donor',
      amount: 200,
      rewardId: null,
      createdAt: DateTime(2026, 3, 10),
    ),
    Pledge(
      id: 'p2',
      campaignId: campaign.id,
      backerEmail: 'big@example.com',
      backerName: 'Malaking Donor',
      amount: 1000,
      rewardId: 'r1',
      createdAt: DateTime(2026, 3, 11),
    ),
    Pledge(
      id: 'p3',
      campaignId: campaign.id,
      backerEmail: 'mid@example.com',
      backerName: 'Gitnang Donor',
      amount: 500,
      rewardId: null,
      createdAt: DateTime(2026, 3, 9),
    ),
  ];

  return CampaignReport(
    campaign: campaign,
    isEnded: false,
    isSuccessful: false,
    totalRaised: 1700,
    fundingDifference: -8300,
    totalPledges: pledges.length,
    totalBackers: 3,
    averagePledge: 566.67,
    firstPledgeAt: DateTime(2026, 3, 9),
    lastPledgeAt: DateTime(2026, 3, 11),
    campaignDurationDays: 14,
    pledges: pledges,
    rewardBreakdown: const [
      CampaignRewardReportItem(
        rewardTier: RewardTier(
          id: 'r1',
          title: 'Reward One',
          minPledge: 300,
          discountType: 'percent',
          discountValue: 5,
          usageLimit: 1,
          validityDays: 30,
        ),
        pledgeCount: 1,
        totalAmount: 1000,
      ),
    ],
    noRewardPledgeCount: 2,
    noRewardAmount: 700,
  );
}

void main() {
  testWidgets(
    'supporter table defaults to highest amount and supports sorting/filtering',
    (tester) async {
      final report = _buildReport();
      final service = FakeCampaignReportService(report);

      await tester.pumpWidget(
        MaterialApp(
          home: CampaignReportScreen(
            campaignId: report.campaign.id,
            serviceOverride: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.byKey(const Key('supporter_sort_dropdown')),
        find.byType(ListView),
        const Offset(0, -250),
      );

      final highestDefaultY = tester.getTopLeft(find.text('Malaking Donor')).dy;
      final lowestDefaultY = tester.getTopLeft(find.text('Munting Donor')).dy;
      expect(highestDefaultY, lessThan(lowestDefaultY));

      await tester.tap(find.byKey(const Key('supporter_sort_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Halaga: pinakamababa -> pinakamalaki').last);
      await tester.pumpAndSettle();

      final highestAfterSortY = tester
          .getTopLeft(find.text('Malaking Donor'))
          .dy;
      final lowestAfterSortY = tester.getTopLeft(find.text('Munting Donor')).dy;
      expect(lowestAfterSortY, lessThan(highestAfterSortY));

      await tester.enterText(
        find.byKey(const Key('supporter_search_field')),
        'Munting',
      );
      await tester.pumpAndSettle();

      expect(find.text('Munting Donor'), findsOneWidget);
      expect(find.text('Malaking Donor'), findsNothing);
      expect(find.text('Gitnang Donor'), findsNothing);
      expect(find.byKey(const Key('supporter_totals_label')), findsOneWidget);
      expect(find.text(formatPeso(200)), findsWidgets);
    },
  );
}
