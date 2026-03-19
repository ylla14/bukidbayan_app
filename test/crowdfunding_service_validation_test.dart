import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/services/crowdfunding_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Campaign _validCampaign({String? safetyNotes}) {
  return Campaign(
    id: 'c_test',
    title: 'Solar Pump for Cooperative Use',
    creatorName: 'Tester',
    creatorEmail: 'tester@example.com',
    shortBlurb: 'Help us fund a shared solar pump for irrigation access.',
    description:
        'This campaign funds a shared solar pump that cooperative members can rent to improve irrigation reliability and reduce costs.',
    isAssetImage: true,
    image: 'assets/images/farmBg.jpg',
    category: 'Solar/Power',
    goalAmount: 50000,
    pledgedAmount: 0,
    backersCount: 0,
    endDate: DateTime.now().add(const Duration(days: 30)),
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    rewards: const [
      RewardTier(
        id: 'r1',
        title: 'Supporter Discount',
        minPledge: 500,
        discountType: 'percent',
        discountValue: 5,
        usageLimit: 1,
        validityDays: 90,
      ),
    ],
    specs: const {'Power': '2HP', 'Voltage': '220V', 'Flow rate': '50 L/min'},
    includedItems: const ['Pump unit', 'Controller', 'Mounting kit'],
    productionTimeline: 'Week 1 procurement, Week 2 delivery, Week 3 setup.',
    shippingCoverage: 'Local delivery',
    shippingCostHandling: 'included',
    warranty: 'Supplier warranty plus cooperative support for one year.',
    spareParts: 'Replacement parts are stocked locally at the cooperative.',
    risks: 'Potential supplier delays are mitigated with backup suppliers.',
    safetyNotes:
        safetyNotes ??
        'Operators are required to use PPE and complete handling training.',
    status: 'draft',
  );
}

void main() {
  group('CrowdfundingService.validateForPublish', () {
    test('returns error when safety notes are missing', () {
      final service = CrowdfundingService();
      final campaign = _validCampaign(safetyNotes: '');

      final errors = service.validateForPublish(campaign);

      expect(
        errors,
        contains(
          'Ang paalala sa kaligtasan ay dapat hindi bababa sa 10 character',
        ),
      );
    });

    test('returns no safety-note error when campaign is valid', () {
      final service = CrowdfundingService();
      final campaign = _validCampaign();

      final errors = service.validateForPublish(campaign);

      expect(
        errors.any(
          (e) => e.contains(
            'Ang paalala sa kaligtasan ay dapat hindi bababa sa 10 character',
          ),
        ),
        isFalse,
      );
    });

    test(
      'publishCampaign saves a new live campaign even if draft was never saved',
      () async {
        SharedPreferences.setMockInitialValues({
          'current_user_email': 'tester@example.com',
        });
        final service = CrowdfundingService();
        final campaign = _validCampaign();

        await service.publishCampaign(campaign);
        final campaigns = await service.getCampaigns();

        expect(campaigns.any((c) => c.id == campaign.id), isTrue);
        final published = campaigns.firstWhere((c) => c.id == campaign.id);
        expect(published.status, 'live');
        expect(published.publishedAt, isNotNull);
      },
    );
  });

  group('CrowdfundingService test-account campaign guards', () {
    test('creates both active and ended campaigns for emails starting with 12312312312', () async {
      SharedPreferences.setMockInitialValues({
        'current_user_email': '12312312312_test@example.com',
      });
      final service = CrowdfundingService();

      final myCampaigns = await service.getMyCampaigns();

      expect(
        myCampaigns.any(
          (c) => c.status == 'live' && c.endDate.isAfter(DateTime.now()),
        ),
        isTrue,
      );
      expect(
        myCampaigns.any((c) => c.status.startsWith('ended') || c.endDate.isBefore(DateTime.now())),
        isTrue,
      );
    });

    test('refreshes dedicated test campaign when it is already ended', () async {
      final endedTestCampaign = Campaign(
        id: 'test_active_campaign_12312312312',
        title: 'Testing Campaign (Auto Active)',
        creatorName: 'QA Test Account',
        creatorEmail: '12312312312_test@example.com',
        shortBlurb: 'Auto campaign',
        description: 'Auto campaign for QA.',
        isAssetImage: true,
        image: 'assets/images/farmBg.jpg',
        category: 'Irrigation',
        goalAmount: 20000,
        pledgedAmount: 0,
        backersCount: 0,
        endDate: DateTime.now().subtract(const Duration(days: 2)),
        createdAt: DateTime.now().subtract(const Duration(days: 40)),
        rewards: const [],
        status: 'live',
        publishedAt: DateTime.now().subtract(const Duration(days: 40)),
      );

      SharedPreferences.setMockInitialValues({
        'current_user_email': '12312312312_test@example.com',
        'campaigns_v2': encodeCampaigns([endedTestCampaign]),
        'pledges_v1': encodePledges(const []),
      });

      final service = CrowdfundingService();
      final myCampaigns = await service.getMyCampaigns();

      final refreshed = myCampaigns.firstWhere(
        (c) => c.id == 'test_active_campaign_12312312312',
      );
      expect(refreshed.status, 'live');
      expect(refreshed.endDate.isAfter(DateTime.now()), isTrue);
    });

    test('can generate a report from the auto-ended campaign', () async {
      SharedPreferences.setMockInitialValues({
        'current_user_email': '12312312312_test@example.com',
      });
      final service = CrowdfundingService();

      await service.getMyCampaigns();
      final report = await service.generateCampaignReport(
        campaignId: 'test_ended_campaign_12312312312',
      );

      expect(report.isEnded, isTrue);
      expect(report.totalPledges, greaterThan(0));
    });

    test('does not inject test campaigns for non-matching emails', () async {
      SharedPreferences.setMockInitialValues({
        'current_user_email': 'normal_user@example.com',
      });
      final service = CrowdfundingService();

      final myCampaigns = await service.getMyCampaigns();

      expect(
        myCampaigns.any((c) => c.id == 'test_active_campaign_12312312312'),
        isFalse,
      );
      expect(
        myCampaigns.any((c) => c.id == 'test_ended_campaign_12312312312'),
        isFalse,
      );
    });
  });

  group('CrowdfundingService.backCampaign supporter data', () {
    Campaign _liveCampaign({
      required String id,
      required String creatorEmail,
    }) {
      return Campaign(
        id: id,
        title: 'Live campaign for backing tests',
        creatorName: 'Creator',
        creatorEmail: creatorEmail,
        shortBlurb: 'Backing test campaign.',
        description: 'A valid campaign description used for backing tests.',
        isAssetImage: true,
        image: 'assets/images/farmBg.jpg',
        category: 'Irrigation',
        goalAmount: 10000,
        pledgedAmount: 0,
        backersCount: 0,
        endDate: DateTime.now().add(const Duration(days: 10)),
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        rewards: const [],
        status: 'live',
      );
    }

    test('rejects self-support when current user owns campaign', () async {
      final campaign = _liveCampaign(
        id: 'c_owner_block',
        creatorEmail: 'owner@example.com',
      );
      SharedPreferences.setMockInitialValues({
        'current_user_email': 'owner@example.com',
        'campaigns_v2': encodeCampaigns([campaign]),
        'pledges_v1': encodePledges(const []),
      });

      final service = CrowdfundingService();

      expect(
        () => service.backCampaign(campaignId: campaign.id, amount: 500),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('cannot support your own campaign'),
          ),
        ),
      );
    });

    test('stores supporter name, phone, and note in pledge record', () async {
      final campaign = _liveCampaign(
        id: 'c_donor_meta',
        creatorEmail: 'creator@example.com',
      );
      SharedPreferences.setMockInitialValues({
        'current_user_email': 'donor@example.com',
        'campaigns_v2': encodeCampaigns([campaign]),
        'pledges_v1': encodePledges(const []),
      });

      final service = CrowdfundingService();
      await service.backCampaign(
        campaignId: campaign.id,
        amount: 750,
        backerName: 'Juan Dela Cruz',
        backerPhone: '09171234567',
        backerNote: 'Support para sa proyekto!',
      );

      final prefs = await SharedPreferences.getInstance();
      final pledgesJson = prefs.getString('pledges_v1');
      expect(pledgesJson, isNotNull);
      final pledges = decodePledges(pledgesJson!);
      final pledge = pledges.firstWhere((p) => p.campaignId == campaign.id);

      expect(pledge.backerEmail, 'donor@example.com');
      expect(pledge.backerName, 'Juan Dela Cruz');
      expect(pledge.backerPhone, '09171234567');
      expect(pledge.backerNote, 'Support para sa proyekto!');
      expect(pledge.amount, 750);
    });
  });
}
