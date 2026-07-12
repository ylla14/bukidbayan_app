import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/services/crowdfunding_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Campaign _validCampaign({
  String id = 'c_test',
  String creatorUid = 'creator-uid',
  String creatorEmail = 'tester@example.com',
  String? safetyNotes,
  List<RewardTier>? rewards,
}) {
  return Campaign(
    id: id,
    title: 'Solar Pump for Cooperative Use',
    creatorName: 'Tester',
    creatorEmail: creatorEmail,
    creatorUid: creatorUid,
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
    rewards:
        rewards ??
        const [
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
    gcashQrImage: 'data:image/png;base64,qr-test-image',
    warranty: 'Supplier warranty plus cooperative support for one year.',
    spareParts: 'Replacement parts are stocked locally at the cooperative.',
    risks: 'Potential supplier delays are mitigated with backup suppliers.',
    safetyNotes:
        safetyNotes ??
        'Operators are required to use PPE and complete handling training.',
    status: 'draft',
  );
}

MockFirebaseAuth _buildAuth({
  String uid = 'user-1',
  String email = 'tester@example.com',
  String displayName = 'Test User',
}) {
  return MockFirebaseAuth(
    signedIn: true,
    mockUser: MockUser(uid: uid, email: email, displayName: displayName),
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

void main() {
  const multiTierRewards = [
    RewardTier(
      id: 'r1',
      title: 'Supporter Discount',
      minPledge: 500,
      discountType: 'percent',
      discountValue: 5,
      usageLimit: 1,
      validityDays: 90,
    ),
    RewardTier(
      id: 'r2',
      title: 'Harvest Voucher',
      minPledge: 1000,
      discountType: 'fixed',
      discountValue: 150,
      usageLimit: 1,
      validityDays: 120,
    ),
  ];

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

    test('returns error when GCash QR is missing', () {
      final service = CrowdfundingService();
      final campaign = _validCampaign().copyWith(gcashQrImage: '');

      final errors = service.validateForPublish(campaign);

      expect(
        errors,
        contains('Kailangan ang GCash QR photo para makatanggap ng bayad'),
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
        final firestore = FakeFirebaseFirestore();
        final auth = _buildAuth();
        final service = _buildService(firestore: firestore, auth: auth);
        final campaign = _validCampaign();

        await service.publishCampaign(campaign);

        final publishedSnap = await firestore
            .collection('campaigns')
            .doc(campaign.id)
            .get();
        final published = Campaign.fromJson({
          ...publishedSnap.data()!,
          'id': publishedSnap.id,
        });

        expect(publishedSnap.exists, isTrue);
        expect(published.status, 'live');
        expect(published.publishedAt, isNotNull);
        expect(published.creatorUid, campaign.creatorUid);
      },
    );
  });

  group('CrowdfundingService local fallback queries', () {
    test(
      'getMyCampaigns returns only campaigns owned by current user email',
      () async {
        final ownedDraft = _validCampaign().copyWith(
          id: 'owned_draft',
          creatorEmail: 'tester@example.com',
          status: 'draft',
        );
        final ownedLive = _validCampaign().copyWith(
          id: 'owned_live',
          creatorEmail: 'tester@example.com',
          status: 'live',
        );
        final otherLive = _validCampaign().copyWith(
          id: 'other_live',
          creatorEmail: 'someone-else@example.com',
          status: 'live',
        );

        SharedPreferences.setMockInitialValues({
          'current_user_email': 'tester@example.com',
          'campaigns_v2': encodeCampaigns([ownedDraft, ownedLive, otherLive]),
          'pledges_v1': encodePledges(const []),
        });

        final service = CrowdfundingService();
        final myCampaigns = await service.getMyCampaigns();

        expect(
          myCampaigns.map((campaign) => campaign.id),
          containsAll(['owned_draft', 'owned_live']),
        );
        expect(
          myCampaigns.any((campaign) => campaign.id == 'other_live'),
          isFalse,
        );
      },
    );

    test(
      'getMyCampaigns applies the optional status filter in local fallback',
      () async {
        final ownedDraft = _validCampaign().copyWith(
          id: 'owned_draft',
          creatorEmail: 'tester@example.com',
          status: 'draft',
        );
        final ownedLive = _validCampaign().copyWith(
          id: 'owned_live',
          creatorEmail: 'tester@example.com',
          status: 'live',
        );

        SharedPreferences.setMockInitialValues({
          'current_user_email': 'tester@example.com',
          'campaigns_v2': encodeCampaigns([ownedDraft, ownedLive]),
          'pledges_v1': encodePledges(const []),
        });

        final service = CrowdfundingService();
        final liveCampaigns = await service.getMyCampaigns(status: 'live');

        expect(liveCampaigns.length, 1);
        expect(liveCampaigns.single.id, 'owned_live');
      },
    );
  });

  group('CrowdfundingService.backCampaign', () {
    test('rejects self-support when current user owns campaign', () async {
      final firestore = FakeFirebaseFirestore();
      final auth = _buildAuth(
        uid: 'owner-uid',
        email: 'owner@example.com',
        displayName: 'Owner Name',
      );
      final service = _buildService(firestore: firestore, auth: auth);
      final campaign = _validCampaign(
        id: 'c_owner_block',
        creatorUid: 'owner-uid',
        creatorEmail: 'owner@example.com',
      ).copyWith(status: 'live');

      await _seedCampaign(firestore, campaign);

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

    test('rejects amounts below the selected reward minimum', () async {
      final firestore = FakeFirebaseFirestore();
      final auth = _buildAuth(
        uid: 'backer-uid',
        email: 'backer@example.com',
        displayName: 'Backer Name',
      );
      final service = _buildService(firestore: firestore, auth: auth);
      final campaign = _validCampaign(
        id: 'c_reward_minimum',
        creatorUid: 'creator-uid',
        creatorEmail: 'creator@example.com',
      ).copyWith(status: 'live');

      await _seedCampaign(firestore, campaign);

      expect(
        () => service.backCampaign(
          campaignId: campaign.id,
          amount: 400,
          rewardId: 'r1',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('below the minimum pledge'),
          ),
        ),
      );
    });

    test(
      'stores supporter metadata but only counts totals once an admin confirms',
      () async {
        final firestore = FakeFirebaseFirestore();
        final auth = _buildAuth(
          uid: 'backer-uid',
          email: 'donor@example.com',
          displayName: 'Donor Display Name',
        );
        final service = _buildService(firestore: firestore, auth: auth);
        final ownerAuth = _buildAuth(
          uid: 'creator-uid',
          email: 'creator@example.com',
          displayName: 'Creator',
        );
        final ownerService = _buildService(
          firestore: firestore,
          auth: ownerAuth,
        );
        final campaign = _validCampaign(
          id: 'c_donor_meta',
          creatorUid: 'creator-uid',
          creatorEmail: 'creator@example.com',
        ).copyWith(status: 'live');

        await _seedCampaign(firestore, campaign);

        await service.backCampaign(
          campaignId: campaign.id,
          amount: 750,
          backerName: 'Juan Dela Cruz',
          backerPhone: '09171234567',
          backerNote: 'Support para sa proyekto!',
          proofReferenceNumber: 'GC123456789',
        );

        final campaignAfterPledge = await firestore
            .collection('campaigns')
            .doc(campaign.id)
            .get();
        final pledgesSnap = await firestore
            .collection('campaigns')
            .doc(campaign.id)
            .collection('pledges')
            .get();

        expect(campaignAfterPledge.data()!['pledgedAmount'], 0);
        expect(campaignAfterPledge.data()!['backersCount'], 0);
        expect(pledgesSnap.docs, hasLength(1));

        final pledge = Pledge.fromJson({
          ...pledgesSnap.docs.single.data(),
          'id': pledgesSnap.docs.single.id,
          'campaignId': campaign.id,
        });

        expect(pledge.backerUid, 'backer-uid');
        expect(pledge.backerEmail, 'donor@example.com');
        expect(pledge.backerName, 'Juan Dela Cruz');
        expect(pledge.backerPhone, '09171234567');
        expect(pledge.backerNote, 'Support para sa proyekto!');
        expect(pledge.amount, 750);
        expect(pledge.proofReferenceNumber, 'GC123456789');
        expect(pledge.countedInTotal, isFalse);
        expect(pledge.isPendingReview, isTrue);

        await ownerService.confirmContribution(
          campaignId: campaign.id,
          pledgeId: pledge.id,
        );

        final campaignAfterConfirm = await firestore
            .collection('campaigns')
            .doc(campaign.id)
            .get();
        expect(campaignAfterConfirm.data()!['pledgedAmount'], 750);
        expect(campaignAfterConfirm.data()!['backersCount'], 1);
      },
    );

    test(
      'without proof, pledge is recorded as pending and campaign totals are untouched until submitPledgeProof and confirmContribution are called',
      () async {
        final firestore = FakeFirebaseFirestore();
        final auth = _buildAuth(
          uid: 'backer-uid',
          email: 'donor@example.com',
          displayName: 'Donor Display Name',
        );
        final service = _buildService(firestore: firestore, auth: auth);
        final ownerAuth = _buildAuth(
          uid: 'creator-uid',
          email: 'creator@example.com',
          displayName: 'Creator',
        );
        final ownerService = _buildService(
          firestore: firestore,
          auth: ownerAuth,
        );
        final campaign = _validCampaign(
          id: 'c_pending_proof',
          creatorUid: 'creator-uid',
          creatorEmail: 'creator@example.com',
        ).copyWith(status: 'live');

        await _seedCampaign(firestore, campaign);

        await service.backCampaign(
          campaignId: campaign.id,
          amount: 300,
          backerName: 'Maria Santos',
        );

        final campaignAfterPledge = await firestore
            .collection('campaigns')
            .doc(campaign.id)
            .get();
        expect(campaignAfterPledge.data()!['pledgedAmount'], 0);
        expect(campaignAfterPledge.data()!['backersCount'], 0);

        final pending = await service.getMyPledgeForCampaign(campaign.id);
        expect(pending, isNotNull);
        expect(pending!.countedInTotal, isFalse);

        await service.submitPledgeProof(
          campaignId: campaign.id,
          pledgeId: pending.id,
          proofReferenceNumber: 'GC987654321',
        );

        final campaignAfterProof = await firestore
            .collection('campaigns')
            .doc(campaign.id)
            .get();
        expect(campaignAfterProof.data()!['pledgedAmount'], 0);
        expect(campaignAfterProof.data()!['backersCount'], 0);

        await ownerService.confirmContribution(
          campaignId: campaign.id,
          pledgeId: pending.id,
        );

        final campaignAfterConfirm = await firestore
            .collection('campaigns')
            .doc(campaign.id)
            .get();
        expect(campaignAfterConfirm.data()!['pledgedAmount'], 300);
        expect(campaignAfterConfirm.data()!['backersCount'], 1);

        final stillPending = await service.getMyPledgeForCampaign(campaign.id);
        expect(stillPending, isNull);
      },
    );

    test(
      'blocks a second pay-later pledge while one pending pledge already exists',
      () async {
        final firestore = FakeFirebaseFirestore();
        final auth = _buildAuth(
          uid: 'backer-uid',
          email: 'donor@example.com',
          displayName: 'Donor Display Name',
        );
        final service = _buildService(firestore: firestore, auth: auth);
        final campaign = _validCampaign(
          id: 'c_single_pending_rule',
          creatorUid: 'creator-uid',
          creatorEmail: 'creator@example.com',
        ).copyWith(status: 'live');

        await _seedCampaign(firestore, campaign);

        await service.backCampaign(
          campaignId: campaign.id,
          amount: 300,
          backerName: 'Maria Santos',
        );

        await expectLater(
          () => service.backCampaign(
            campaignId: campaign.id,
            amount: 200,
            backerName: 'Maria Santos',
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('naka-pending ka pang pledge'),
            ),
          ),
        );

        // A second attempt WITH proof is blocked too — proof no longer
        // resolves a pledge instantly, so it's just as "open" as one
        // without proof until an admin confirms or invalidates it.
        await expectLater(
          () => service.backCampaign(
            campaignId: campaign.id,
            amount: 250,
            backerName: 'Maria Santos',
            proofReferenceNumber: 'GC-ALREADY-PAID',
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('naka-pending ka pang pledge'),
            ),
          ),
        );

        final pendingPledges = await service.getMyPendingPledgesForCampaign(
          campaign.id,
        );
        expect(pendingPledges, hasLength(1));

        final campaignSnap = await firestore
            .collection('campaigns')
            .doc(campaign.id)
            .get();
        expect(campaignSnap.data()!['pledgedAmount'], 0);
        expect(campaignSnap.data()!['backersCount'], 0);
      },
    );

    test(
      'canceling a pending pledge keeps the record but removes it from active pending state',
      () async {
        final firestore = FakeFirebaseFirestore();
        final auth = _buildAuth(
          uid: 'backer-uid',
          email: 'donor@example.com',
          displayName: 'Donor Display Name',
        );
        final service = _buildService(firestore: firestore, auth: auth);
        final campaign = _validCampaign(
          id: 'c_cancel_pending',
          creatorUid: 'creator-uid',
          creatorEmail: 'creator@example.com',
        ).copyWith(status: 'live');

        await _seedCampaign(firestore, campaign);

        await service.backCampaign(
          campaignId: campaign.id,
          amount: 300,
          backerName: 'Maria Santos',
        );

        final pending = await service.getMyPledgeForCampaign(campaign.id);
        expect(pending, isNotNull);

        await service.cancelPendingPledge(
          campaignId: campaign.id,
          pledgeId: pending!.id,
        );

        final activePending = await service.getMyPledgeForCampaign(campaign.id);
        expect(activePending, isNull);

        final pledges = await service.getPledgesForCampaign(campaign.id);
        expect(pledges, hasLength(1));
        expect(pledges.single.isCanceled, isTrue);
        expect(pledges.single.countedInTotal, isFalse);

        final campaignSnap = await firestore
            .collection('campaigns')
            .doc(campaign.id)
            .get();
        expect(campaignSnap.data()!['pledgedAmount'], 0);
        expect(campaignSnap.data()!['backersCount'], 0);

        await service.backCampaign(
          campaignId: campaign.id,
          amount: 450,
          backerName: 'Maria Santos',
        );

        final nextPending = await service.getMyPendingPledgesForCampaign(
          campaign.id,
        );
        expect(nextPending, hasLength(1));
        expect(nextPending.single.amount, 450);
      },
    );

    test(
      'uses cumulative counted support when unlocking and upgrading benefits',
      () async {
        final firestore = FakeFirebaseFirestore();
        final auth = _buildAuth(
          uid: 'backer-uid',
          email: 'backer@example.com',
          displayName: 'Backer Name',
        );
        final service = _buildService(firestore: firestore, auth: auth);
        final ownerAuth = _buildAuth(
          uid: 'creator-uid',
          email: 'creator@example.com',
          displayName: 'Creator',
        );
        final ownerService = _buildService(
          firestore: firestore,
          auth: ownerAuth,
        );
        final campaign = _validCampaign(
          id: 'c_cumulative_rewards',
          creatorUid: 'creator-uid',
          creatorEmail: 'creator@example.com',
          rewards: multiTierRewards,
        ).copyWith(status: 'live');

        await _seedCampaign(firestore, campaign);

        await service.backCampaign(
          campaignId: campaign.id,
          amount: 600,
          rewardId: 'r1',
          proofReferenceNumber: 'GC-FIRST-600',
        );
        final firstPledges = await service.getPledgesForCampaign(campaign.id);
        final firstPledge = firstPledges.firstWhere(
          (pledge) => pledge.amount == 600,
        );
        await ownerService.confirmContribution(
          campaignId: campaign.id,
          pledgeId: firstPledge.id,
        );

        await expectLater(
          () => service.backCampaign(
            campaignId: campaign.id,
            amount: 250,
            rewardId: 'r2',
            proofReferenceNumber: 'GC-BAD-UPGRADE',
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('below the minimum pledge'),
            ),
          ),
        );

        await service.backCampaign(
          campaignId: campaign.id,
          amount: 400,
          rewardId: 'r2',
          proofReferenceNumber: 'GC-UPGRADE-1000',
        );
        final secondPledges = await service.getPledgesForCampaign(
          campaign.id,
        );
        final secondPledge = secondPledges.firstWhere(
          (pledge) => pledge.amount == 400,
        );
        await ownerService.confirmContribution(
          campaignId: campaign.id,
          pledgeId: secondPledge.id,
        );

        final summary = await service.getMySupportSummary(campaign.id);
        expect(summary, isNotNull);
        expect(summary!.countedContributionTotal, 1000);
        expect(summary.activeReward?.id, 'r2');

        final pledges = await service.getPledgesForCampaign(campaign.id);
        expect(
          pledges.where((pledge) => pledge.rewardId == 'r2'),
          hasLength(1),
        );
        expect(pledges.where((pledge) => pledge.rewardId == 'r1'), isEmpty);
      },
    );

    test(
      'invalidating a counted contribution removes it from totals, keeps the record, and notifies the supporter',
      () async {
        final firestore = FakeFirebaseFirestore();
        final backerAuth = _buildAuth(
          uid: 'backer-uid',
          email: 'backer@example.com',
          displayName: 'Backer Name',
        );
        final ownerAuth = _buildAuth(
          uid: 'creator-uid',
          email: 'creator@example.com',
          displayName: 'Creator Name',
        );
        final backerService = _buildService(
          firestore: firestore,
          auth: backerAuth,
        );
        final ownerService = _buildService(
          firestore: firestore,
          auth: ownerAuth,
        );
        final campaign = _validCampaign(
          id: 'c_invalidation_flow',
          creatorUid: 'creator-uid',
          creatorEmail: 'creator@example.com',
          rewards: multiTierRewards,
        ).copyWith(status: 'live');

        await _seedCampaign(firestore, campaign);

        await backerService.backCampaign(
          campaignId: campaign.id,
          amount: 700,
          rewardId: 'r1',
          proofReferenceNumber: 'GC-700',
        );
        final firstPledges = await backerService.getPledgesForCampaign(
          campaign.id,
        );
        final firstPledge = firstPledges.firstWhere(
          (pledge) => pledge.amount == 700,
        );
        await ownerService.confirmContribution(
          campaignId: campaign.id,
          pledgeId: firstPledge.id,
        );

        await backerService.backCampaign(
          campaignId: campaign.id,
          amount: 400,
          rewardId: 'r2',
          proofReferenceNumber: 'GC-400',
        );
        final secondPledges = await backerService.getPledgesForCampaign(
          campaign.id,
        );
        final secondPledge = secondPledges.firstWhere(
          (pledge) => pledge.amount == 400,
        );
        await ownerService.confirmContribution(
          campaignId: campaign.id,
          pledgeId: secondPledge.id,
        );

        final initialSummary = await backerService.getMySupportSummary(
          campaign.id,
        );
        expect(initialSummary?.countedContributionTotal, 1100);
        expect(initialSummary?.activeReward?.id, 'r2');

        final pledgesBeforeInvalidation = await ownerService
            .getPledgesForCampaign(campaign.id);
        final pledgeToInvalidate = pledgesBeforeInvalidation.firstWhere(
          (pledge) => pledge.amount == 400,
        );

        await ownerService.invalidateContribution(
          campaignId: campaign.id,
          pledgeId: pledgeToInvalidate.id,
          reason: 'Malabong proof image',
        );

        final updatedCampaignSnap = await firestore
            .collection('campaigns')
            .doc(campaign.id)
            .get();
        expect(updatedCampaignSnap.data()!['pledgedAmount'], 700);
        expect(updatedCampaignSnap.data()!['backersCount'], 1);

        final updatedPledges = await ownerService.getPledgesForCampaign(
          campaign.id,
        );
        final invalidated = updatedPledges.firstWhere(
          (pledge) => pledge.id == pledgeToInvalidate.id,
        );
        expect(invalidated.countedInTotal, isFalse);
        expect(invalidated.isInvalidated, isTrue);
        expect(invalidated.invalidationReason, 'Malabong proof image');

        final summaryAfterInvalidation = await backerService
            .getMySupportSummary(campaign.id);
        expect(summaryAfterInvalidation?.countedContributionTotal, 700);
        expect(summaryAfterInvalidation?.activeReward?.id, 'r1');

        final notificationSnap = await firestore
            .collection('notifications')
            .doc('backer-uid')
            .collection('items')
            .get();
        // Two "confirmed" notifications (one per confirmed pledge) plus the
        // "invalidated" one for the pledge that got invalidated afterward.
        final invalidatedNotifications = notificationSnap.docs.where(
          (doc) => doc.data()['type'] == 'campaign_contribution_invalidated',
        );
        expect(invalidatedNotifications, hasLength(1));
        final confirmedNotifications = notificationSnap.docs.where(
          (doc) => doc.data()['type'] == 'campaign_contribution_confirmed',
        );
        expect(confirmedNotifications, hasLength(2));
      },
    );

    test(
      'invalidating a pending-review pledge (never confirmed) leaves campaign totals untouched',
      () async {
        final firestore = FakeFirebaseFirestore();
        final backerAuth = _buildAuth(
          uid: 'backer-uid',
          email: 'backer@example.com',
          displayName: 'Backer Name',
        );
        final ownerAuth = _buildAuth(
          uid: 'creator-uid',
          email: 'creator@example.com',
          displayName: 'Creator Name',
        );
        final backerService = _buildService(
          firestore: firestore,
          auth: backerAuth,
        );
        final ownerService = _buildService(
          firestore: firestore,
          auth: ownerAuth,
        );
        final campaign = _validCampaign(
          id: 'c_invalidate_unconfirmed',
          creatorUid: 'creator-uid',
          creatorEmail: 'creator@example.com',
        ).copyWith(status: 'live');

        await _seedCampaign(firestore, campaign);

        await backerService.backCampaign(
          campaignId: campaign.id,
          amount: 500,
          backerName: 'Maria Santos',
          proofReferenceNumber: 'GC-SUSPICIOUS',
        );
        final pledges = await backerService.getPledgesForCampaign(
          campaign.id,
        );
        final pledge = pledges.firstWhere((p) => p.amount == 500);
        expect(pledge.isPendingReview, isTrue);

        await ownerService.invalidateContribution(
          campaignId: campaign.id,
          pledgeId: pledge.id,
          reason: 'Duplicate reference number',
        );

        final campaignSnap = await firestore
            .collection('campaigns')
            .doc(campaign.id)
            .get();
        expect(campaignSnap.data()!['pledgedAmount'], 0);
        expect(campaignSnap.data()!['backersCount'], 0);

        final updatedPledges = await ownerService.getPledgesForCampaign(
          campaign.id,
        );
        final invalidated = updatedPledges.firstWhere(
          (p) => p.id == pledge.id,
        );
        expect(invalidated.isInvalidated, isTrue);
        expect(invalidated.countedInTotal, isFalse);

        await expectLater(
          () => backerService.submitPledgeProof(
            campaignId: campaign.id,
            pledgeId: pledge.id,
            proofReferenceNumber: 'GC-RETRY',
          ),
          throwsA(isA<Exception>()),
        );
        await expectLater(
          () => ownerService.confirmContribution(
            campaignId: campaign.id,
            pledgeId: pledge.id,
          ),
          throwsA(isA<Exception>()),
        );
      },
    );

    test(
      'confirmContribution rejects non-owners and succeeds for the campaign owner',
      () async {
        final firestore = FakeFirebaseFirestore();
        final backerAuth = _buildAuth(
          uid: 'backer-uid',
          email: 'backer@example.com',
          displayName: 'Backer Name',
        );
        final strangerAuth = _buildAuth(
          uid: 'stranger-uid',
          email: 'stranger@example.com',
          displayName: 'Stranger',
        );
        final ownerAuth = _buildAuth(
          uid: 'creator-uid',
          email: 'creator@example.com',
          displayName: 'Creator Name',
        );
        final backerService = _buildService(
          firestore: firestore,
          auth: backerAuth,
        );
        final strangerService = _buildService(
          firestore: firestore,
          auth: strangerAuth,
        );
        final ownerService = _buildService(
          firestore: firestore,
          auth: ownerAuth,
        );
        final campaign = _validCampaign(
          id: 'c_confirm_ownership',
          creatorUid: 'creator-uid',
          creatorEmail: 'creator@example.com',
        ).copyWith(status: 'live');

        await _seedCampaign(firestore, campaign);

        await backerService.backCampaign(
          campaignId: campaign.id,
          amount: 500,
          backerName: 'Maria Santos',
          proofReferenceNumber: 'GC-500',
        );
        final pledges = await backerService.getPledgesForCampaign(
          campaign.id,
        );
        final pledge = pledges.firstWhere((p) => p.amount == 500);

        await expectLater(
          () => strangerService.confirmContribution(
            campaignId: campaign.id,
            pledgeId: pledge.id,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Only the campaign owner can confirm'),
            ),
          ),
        );

        await ownerService.confirmContribution(
          campaignId: campaign.id,
          pledgeId: pledge.id,
        );

        final campaignSnap = await firestore
            .collection('campaigns')
            .doc(campaign.id)
            .get();
        expect(campaignSnap.data()!['pledgedAmount'], 500);
        expect(campaignSnap.data()!['backersCount'], 1);
      },
    );
  });
}
