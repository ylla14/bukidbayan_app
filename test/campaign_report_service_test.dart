import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/models/payment_attempt.dart';
import 'package:bukidbayan_app/services/crowdfunding_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

Campaign _campaign({
  required String id,
  required String creatorUid,
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
    creatorUid: creatorUid,
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

MockFirebaseAuth _buildAuth({required String uid, required String email}) {
  return MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(uid: uid, email: email, displayName: 'Owner'),
  );
}

CrowdfundingService _buildService({
  required FakeFirebaseFirestore firestore,
  required MockFirebaseAuth auth,
}) {
  return CrowdfundingService(firestore: firestore, auth: auth);
}

Future<void> _seedCampaign(
  FakeFirebaseFirestore firestore,
  Campaign campaign,
) async {
  await firestore
      .collection('campaigns')
      .doc(campaign.id)
      .set(campaign.toFirestore());
}

Future<void> _seedPledges(
  FakeFirebaseFirestore firestore, {
  required String campaignId,
  required List<Pledge> pledges,
}) async {
  for (final pledge in pledges) {
    await firestore
        .collection('campaigns')
        .doc(campaignId)
        .collection('pledges')
        .doc(pledge.id)
        .set(pledge.toFirestore());
  }
}

Future<void> _seedPaymentAttempts(
  FakeFirebaseFirestore firestore, {
  required String campaignId,
  required List<PaymentAttempt> attempts,
}) async {
  for (final attempt in attempts) {
    await firestore
        .collection('campaigns')
        .doc(campaignId)
        .collection('payment_attempts')
        .doc(attempt.id)
        .set(attempt.toFirestore());
  }
}

void main() {
  group('CrowdfundingService.generateCampaignReport', () {
    test(
      'returns computed report for ended campaign owned by current user',
      () async {
        final firestore = FakeFirebaseFirestore();
        final auth = _buildAuth(uid: 'owner-uid', email: 'owner@example.com');
        final service = _buildService(firestore: firestore, auth: auth);
        final campaign = _campaign(
          id: 'c_report_1',
          creatorUid: 'owner-uid',
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
            backerUid: 'backer-a',
            backerEmail: 'a@example.com',
            amount: 1000,
            rewardId: 'r1',
            createdAt: DateTime(2026, 1, 3),
          ),
          Pledge(
            id: 'p2',
            campaignId: campaign.id,
            backerUid: 'backer-b',
            backerEmail: 'b@example.com',
            amount: 500,
            rewardId: null,
            createdAt: DateTime(2026, 1, 4),
          ),
        ];
        final attempts = [
          PaymentAttempt(
            id: 'a1',
            campaignId: campaign.id,
            createdByUid: 'backer-a',
            createdByEmail: 'a@example.com',
            donorName: 'Backer A',
            amount: 1000,
            provider: PaymentProvider.payMongoCheckout,
            status: PaymentAttemptStatus.paid,
            createdAt: DateTime(2026, 1, 3),
            updatedAt: DateTime(2026, 1, 3, 1),
            completedAt: DateTime(2026, 1, 3, 1),
          ),
          PaymentAttempt(
            id: 'a2',
            campaignId: campaign.id,
            createdByUid: 'backer-b',
            createdByEmail: 'b@example.com',
            donorName: 'Backer B',
            amount: 500,
            provider: PaymentProvider.payMongoCheckout,
            status: PaymentAttemptStatus.failed,
            createdAt: DateTime(2026, 1, 4),
            updatedAt: DateTime(2026, 1, 4, 1),
          ),
          PaymentAttempt(
            id: 'a3',
            campaignId: campaign.id,
            createdByUid: 'backer-c',
            createdByEmail: 'c@example.com',
            donorName: 'Backer C',
            amount: 700,
            provider: PaymentProvider.payMongoCheckout,
            status: PaymentAttemptStatus.pendingCheckout,
            createdAt: DateTime(2026, 1, 5),
            updatedAt: DateTime(2026, 1, 5, 1),
          ),
        ];

        await _seedCampaign(firestore, campaign);
        await _seedPledges(
          firestore,
          campaignId: campaign.id,
          pledges: pledges,
        );
        await _seedPaymentAttempts(
          firestore,
          campaignId: campaign.id,
          attempts: attempts,
        );

        final report = await service.generateCampaignReport(
          campaignId: campaign.id,
        );

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
        expect(report.paymentAttempts.length, 3);
        expect(report.paymentFunnel.totalAttempts, 3);
        expect(report.paymentFunnel.paidCount, 1);
        expect(report.paymentFunnel.failedCount, 1);
        expect(report.paymentFunnel.pendingCheckoutCount, 1);
        expect(report.paymentFunnel.totalAttemptAmount, 2200);
        expect(report.paymentFunnel.paidAttemptAmount, 1000);
      },
    );

    test('returns interim report when campaign has not ended yet', () async {
      final firestore = FakeFirebaseFirestore();
      final auth = _buildAuth(uid: 'owner-uid', email: 'owner@example.com');
      final service = _buildService(firestore: firestore, auth: auth);
      final campaign = _campaign(
        id: 'c_report_2',
        creatorUid: 'owner-uid',
        creatorEmail: 'owner@example.com',
        endDate: DateTime.now().add(const Duration(days: 4)),
        goalAmount: 1000,
        pledgedAmount: 700,
        backersCount: 1,
      );

      await _seedCampaign(firestore, campaign);

      final report = await service.generateCampaignReport(
        campaignId: campaign.id,
      );

      expect(report.campaign.id, campaign.id);
      expect(report.isEnded, isFalse);
      expect(report.isSuccessful, isFalse);
      expect(report.totalRaised, 700);
      expect(report.fundingDifference, -300);
    });

    test('throws when user is not campaign owner', () async {
      final firestore = FakeFirebaseFirestore();
      final auth = _buildAuth(uid: 'other-uid', email: 'other@example.com');
      final service = _buildService(firestore: firestore, auth: auth);
      final campaign = _campaign(
        id: 'c_report_3',
        creatorUid: 'owner-uid',
        creatorEmail: 'owner@example.com',
        endDate: DateTime.now().subtract(const Duration(days: 1)),
        goalAmount: 1000,
        pledgedAmount: 900,
        backersCount: 1,
      );

      await _seedCampaign(firestore, campaign);

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

    test('keeps counter total separate from pledge-history totals', () async {
      final firestore = FakeFirebaseFirestore();
      final auth = _buildAuth(uid: 'owner-uid', email: 'owner@example.com');
      final service = _buildService(firestore: firestore, auth: auth);
      final campaign = _campaign(
        id: 'c_report_drift',
        creatorUid: 'owner-uid',
        creatorEmail: 'owner@example.com',
        endDate: DateTime.now().subtract(const Duration(days: 1)),
        goalAmount: 1000,
        pledgedAmount: 900,
        backersCount: 2,
      );
      final pledges = [
        Pledge(
          id: 'p1',
          campaignId: campaign.id,
          backerUid: 'backer-a',
          backerEmail: 'a@example.com',
          amount: 300,
          rewardId: null,
          createdAt: DateTime(2026, 1, 3),
        ),
      ];
      final attempts = [
        PaymentAttempt(
          id: 'a1',
          campaignId: campaign.id,
          createdByUid: 'backer-a',
          createdByEmail: 'a@example.com',
          donorName: 'Backer A',
          amount: 300,
          provider: PaymentProvider.payMongoCheckout,
          status: PaymentAttemptStatus.paid,
          createdAt: DateTime(2026, 1, 3),
          updatedAt: DateTime(2026, 1, 3, 1),
          completedAt: DateTime(2026, 1, 3, 1),
        ),
        PaymentAttempt(
          id: 'a2',
          campaignId: campaign.id,
          createdByUid: 'backer-b',
          createdByEmail: 'b@example.com',
          donorName: 'Backer B',
          amount: 600,
          provider: PaymentProvider.payMongoCheckout,
          status: PaymentAttemptStatus.paid,
          createdAt: DateTime(2026, 1, 4),
          updatedAt: DateTime(2026, 1, 4, 1),
          completedAt: DateTime(2026, 1, 4, 1),
        ),
      ];

      await _seedCampaign(firestore, campaign);
      await _seedPledges(firestore, campaignId: campaign.id, pledges: pledges);
      await _seedPaymentAttempts(
        firestore,
        campaignId: campaign.id,
        attempts: attempts,
      );

      final report = await service.generateCampaignReport(
        campaignId: campaign.id,
      );

      expect(report.totalRaised, 900);
      expect(report.totalPledges, 1);
      expect(report.pledges.single.amount, 300);
      expect(report.paymentFunnel.totalAttempts, 2);
      expect(report.paymentFunnel.paidCount, 2);
      expect(report.paymentFunnel.paidAttemptAmount, 900);
    });
  });
}
