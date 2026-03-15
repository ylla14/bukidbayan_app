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
}
