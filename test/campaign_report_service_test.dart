import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/services/crowdfunding_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Campaign _campaign({
  required String id,
  required String creatorEmail,
  required DateTime endDate,
  required int goalAmount,
  required int pledgedAmount,
  required int backersCount,
  String status = 'live',
}) {
  return Campaign(
    id: id,
    title: 'Report Test Campaign',
    creatorName: 'Owner',
    creatorEmail: creatorEmail,
    shortBlurb: 'A valid short blurb for report testing.',
    description:
        'A detailed description that is long enough for campaign report testing.',
    isAssetImage: true,
    image: 'assets/images/farmBg.jpg',
    category: 'Irrigation',
    goalAmount: goalAmount,
    pledgedAmount: pledgedAmount,
    backersCount: backersCount,
    endDate: endDate,
    createdAt: DateTime(2026, 1, 1),
    publishedAt: DateTime(2026, 1, 2),
    rewards: const [
      RewardTier(
        id: 'r1',
        title: 'Supporter Reward',
        minPledge: 500,
        discountType: 'percent',
        discountValue: 5,
        usageLimit: 1,
        validityDays: 90,
      ),
    ],
    specs: const {'Power': '2HP', 'Voltage': '220V', 'Flow': '50L/min'},
    includedItems: const ['Pump', 'Controller', 'Mounting kit'],
    productionTimeline: 'Week 1 procurement, Week 2 installation.',
    shippingCoverage: 'Local delivery',
    shippingCostHandling: 'included',
    warranty: 'One-year warranty with maintenance support included.',
    spareParts: 'Spare parts are stocked and available from supplier.',
    risks: 'Possible supplier delay with backup supplier available.',
    safetyNotes: 'PPE and handling training are required for operators.',
    status: status,
  );
}

void main() {
  group('CrowdfundingService.generateCampaignReport', () {
    test('returns computed report for ended campaign owned by current user', () async {
      final campaign = _campaign(
        id: 'c_report_1',
        creatorEmail: 'owner@example.com',
        endDate: DateTime.now().subtract(const Duration(days: 2)),
        goalAmount: 1000,
        pledgedAmount: 1500,
        backersCount: 2,
      );

      final pledges = [
        Pledge(
          id: 'p1',
          campaignId: campaign.id,
          backerEmail: 'a@example.com',
          amount: 1000,
          rewardId: 'r1',
          createdAt: DateTime(2026, 1, 3),
        ),
        Pledge(
          id: 'p2',
          campaignId: campaign.id,
          backerEmail: 'b@example.com',
          amount: 500,
          rewardId: null,
          createdAt: DateTime(2026, 1, 4),
        ),
      ];

      SharedPreferences.setMockInitialValues({
        'current_user_email': 'owner@example.com',
        'campaigns_v2': encodeCampaigns([campaign]),
        'pledges_v1': encodePledges(pledges),
      });

      final service = CrowdfundingService();
      final report = await service.generateCampaignReport(campaignId: campaign.id);

      expect(report.campaign.id, campaign.id);
      expect(report.isEnded, isTrue);
      expect(report.isSuccessful, isTrue);
      expect(report.totalRaised, 1500);
      expect(report.fundingDifference, 500);
      expect(report.totalPledges, 2);
      expect(report.totalBackers, 2);
      expect(report.averagePledge, 750);
      expect(report.firstPledgeAt, DateTime(2026, 1, 3));
      expect(report.lastPledgeAt, DateTime(2026, 1, 4));
      expect(report.rewardBreakdown.first.pledgeCount, 1);
      expect(report.rewardBreakdown.first.totalAmount, 1000);
      expect(report.noRewardPledgeCount, 1);
      expect(report.noRewardAmount, 500);
    });

    test('returns interim report when campaign has not ended yet', () async {
      final campaign = _campaign(
        id: 'c_report_2',
        creatorEmail: 'owner@example.com',
        endDate: DateTime.now().add(const Duration(days: 4)),
        goalAmount: 1000,
        pledgedAmount: 700,
        backersCount: 1,
      );

      SharedPreferences.setMockInitialValues({
        'current_user_email': 'owner@example.com',
        'campaigns_v2': encodeCampaigns([campaign]),
        'pledges_v1': encodePledges(const []),
      });

      final service = CrowdfundingService();
      final report = await service.generateCampaignReport(campaignId: campaign.id);

      expect(report.campaign.id, campaign.id);
      expect(report.isEnded, isFalse);
      expect(report.isSuccessful, isFalse);
      expect(report.totalRaised, 700);
      expect(report.fundingDifference, -300);
    });

    test('throws when user is not campaign owner', () async {
      final campaign = _campaign(
        id: 'c_report_3',
        creatorEmail: 'owner@example.com',
        endDate: DateTime.now().subtract(const Duration(days: 1)),
        goalAmount: 1000,
        pledgedAmount: 900,
        backersCount: 1,
      );

      SharedPreferences.setMockInitialValues({
        'current_user_email': 'other@example.com',
        'campaigns_v2': encodeCampaigns([campaign]),
        'pledges_v1': encodePledges(const []),
      });

      final service = CrowdfundingService();

      expect(
        () => service.generateCampaignReport(campaignId: campaign.id),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Only the campaign owner can generate a report'),
          ),
        ),
      );
    });
  });
}
