import 'dart:async';

import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/models/payment_attempt.dart';
import 'package:bukidbayan_app/services/crowdfunding_payment_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

Campaign _campaign({
  required String id,
  required String creatorUid,
  required String creatorEmail,
}) {
  return Campaign(
    id: id,
    title: 'Payment Test Campaign',
    creatorName: 'Owner',
    creatorEmail: creatorEmail,
    creatorUid: creatorUid,
    shortBlurb: 'A valid short blurb for payment testing.',
    description:
        'A detailed description that is long enough for payment testing and checkout setup.',
    isAssetImage: true,
    image: 'assets/images/farmBg.jpg',
    category: 'Irrigation',
    goalAmount: 10000,
    pledgedAmount: 0,
    backersCount: 0,
    endDate: DateTime.now().add(const Duration(days: 5)),
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    rewards: const [
      RewardTier(
        id: 'r1',
        title: 'Reward One',
        minPledge: 500,
        discountType: 'percent',
        discountValue: 5,
        usageLimit: 1,
        validityDays: 30,
      ),
    ],
    status: 'live',
  );
}

MockFirebaseAuth _buildAuth({
  String uid = 'backer-uid',
  String email = 'backer@example.com',
  String displayName = 'Backer',
}) {
  return MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(uid: uid, email: email, displayName: displayName),
  );
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

void main() {
  group('CrowdfundingPaymentService', () {
    test('creates a payment attempt instead of a pledge', () async {
      final firestore = FakeFirebaseFirestore();
      final auth = _buildAuth();
      final campaign = _campaign(
        id: 'c_payment_attempt',
        creatorUid: 'owner-uid',
        creatorEmail: 'owner@example.com',
      );
      final service = CrowdfundingPaymentService(
        firestore: firestore,
        auth: auth,
      );

      await _seedCampaign(firestore, campaign);

      final attempt = await service.createCheckoutAttempt(
        campaignId: campaign.id,
        amount: 750,
        donorName: 'Juan Dela Cruz',
        donorPhone: '09171234567',
        donorNote: 'Support para sa proyekto!',
        rewardId: 'r1',
      );

      final attemptSnap = await firestore
          .collection('campaigns')
          .doc(campaign.id)
          .collection('payment_attempts')
          .doc(attempt.id)
          .get();
      final pledgesSnap = await firestore
          .collection('campaigns')
          .doc(campaign.id)
          .collection('pledges')
          .get();

      expect(attempt.status, PaymentAttemptStatus.created);
      expect(attempt.provider, PaymentProvider.payMongoCheckout);
      expect(attemptSnap.exists, isTrue);
      expect(attemptSnap.data()!['donorName'], 'Juan Dela Cruz');
      expect(attemptSnap.data()!['amount'], 750);
      expect(pledgesSnap.docs, isEmpty);
    });

    test('waits for backend checkout details before returning', () async {
      final firestore = FakeFirebaseFirestore();
      final auth = _buildAuth();
      final campaign = _campaign(
        id: 'c_checkout_ready',
        creatorUid: 'owner-uid',
        creatorEmail: 'owner@example.com',
      );
      final service = CrowdfundingPaymentService(
        firestore: firestore,
        auth: auth,
      );

      await _seedCampaign(firestore, campaign);

      final attempt = await service.createCheckoutAttempt(
        campaignId: campaign.id,
        amount: 800,
        donorName: 'Juan Dela Cruz',
      );

      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 20), () async {
          await firestore
              .collection('campaigns')
              .doc(campaign.id)
              .collection('payment_attempts')
              .doc(attempt.id)
              .update({
                'status': PaymentAttemptStatus.pendingCheckout,
                'providerCheckoutId': 'cs_test_123',
                'providerCheckoutUrl':
                    'https://checkout.paymongo.com/cs_test_123',
                'updatedAt': DateTime.now().toIso8601String(),
              });
        }),
      );

      final readyAttempt = await service.waitForCheckoutReady(
        campaignId: campaign.id,
        attemptId: attempt.id,
        timeout: const Duration(seconds: 1),
        pollInterval: const Duration(milliseconds: 10),
      );

      expect(readyAttempt.status, PaymentAttemptStatus.pendingCheckout);
      expect(
        readyAttempt.providerCheckoutUrl,
        'https://checkout.paymongo.com/cs_test_123',
      );
    });

    test(
      'watches the latest attempt for the current user on a campaign',
      () async {
        final firestore = FakeFirebaseFirestore();
        final auth = _buildAuth(uid: 'watcher-uid');
        final campaign = _campaign(
          id: 'c_latest_attempt',
          creatorUid: 'owner-uid',
          creatorEmail: 'owner@example.com',
        );
        final service = CrowdfundingPaymentService(
          firestore: firestore,
          auth: auth,
        );

        await _seedCampaign(firestore, campaign);

        await firestore
            .collection('campaigns')
            .doc(campaign.id)
            .collection('payment_attempts')
            .doc('older')
            .set(
              PaymentAttempt(
                id: 'older',
                campaignId: campaign.id,
                createdByUid: 'watcher-uid',
                donorName: 'Older Attempt',
                amount: 500,
                provider: PaymentProvider.payMongoCheckout,
                status: PaymentAttemptStatus.created,
                createdAt: DateTime(2026, 6, 20, 10),
                updatedAt: DateTime(2026, 6, 20, 10),
              ).toFirestore(),
            );

        await firestore
            .collection('campaigns')
            .doc(campaign.id)
            .collection('payment_attempts')
            .doc('newer')
            .set(
              PaymentAttempt(
                id: 'newer',
                campaignId: campaign.id,
                createdByUid: 'watcher-uid',
                donorName: 'Newer Attempt',
                amount: 700,
                provider: PaymentProvider.payMongoCheckout,
                status: PaymentAttemptStatus.pendingCheckout,
                createdAt: DateTime(2026, 6, 21, 10),
                updatedAt: DateTime(2026, 6, 21, 10),
              ).toFirestore(),
            );

        await expectLater(
          service.watchLatestAttemptForCurrentUser(campaignId: campaign.id),
          emits(
            isA<PaymentAttempt>()
                .having((attempt) => attempt.id, 'id', 'newer')
                .having((attempt) => attempt.amount, 'amount', 700),
          ),
        );
      },
    );

    test(
      'returns the recoverable attempt even when a newer failed attempt exists',
      () async {
        final firestore = FakeFirebaseFirestore();
        final auth = _buildAuth(uid: 'watcher-uid');
        final campaign = _campaign(
          id: 'c_recoverable_attempt',
          creatorUid: 'owner-uid',
          creatorEmail: 'owner@example.com',
        );
        final service = CrowdfundingPaymentService(
          firestore: firestore,
          auth: auth,
        );

        await _seedCampaign(firestore, campaign);

        await firestore
            .collection('campaigns')
            .doc(campaign.id)
            .collection('payment_attempts')
            .doc('pending')
            .set(
              PaymentAttempt(
                id: 'pending',
                campaignId: campaign.id,
                createdByUid: 'watcher-uid',
                donorName: 'Pending Attempt',
                amount: 500,
                provider: PaymentProvider.payMongoCheckout,
                status: PaymentAttemptStatus.pendingCheckout,
                providerCheckoutUrl: 'https://checkout.paymongo.com/pending',
                createdAt: DateTime(2026, 6, 21, 10),
                updatedAt: DateTime(2026, 6, 21, 10),
              ).toFirestore(),
            );

        await firestore
            .collection('campaigns')
            .doc(campaign.id)
            .collection('payment_attempts')
            .doc('failed')
            .set(
              PaymentAttempt(
                id: 'failed',
                campaignId: campaign.id,
                createdByUid: 'watcher-uid',
                donorName: 'Failed Attempt',
                amount: 700,
                provider: PaymentProvider.payMongoCheckout,
                status: PaymentAttemptStatus.failed,
                failureReason: 'Duplicate attempt',
                createdAt: DateTime(2026, 6, 21, 11),
                updatedAt: DateTime(2026, 6, 21, 11),
              ).toFirestore(),
            );

        final recoverableAttempt = await service
            .getRecoverableAttemptForCurrentUser(campaignId: campaign.id);

        expect(recoverableAttempt, isNotNull);
        expect(recoverableAttempt!.id, 'pending');
        expect(recoverableAttempt.providerCheckoutUrl, isNotEmpty);
      },
    );
  });
}
