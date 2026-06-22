import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/models/campaign_report.dart';
import 'package:bukidbayan_app/models/payment_attempt.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CampaignAnalyticsService {
  CampaignAnalyticsService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreOverride = firestore,
      _authOverride = auth;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _campaigns =>
      _db.collection('campaigns');

  CollectionReference<Map<String, dynamic>> _pledgesRef(String campaignId) =>
      _campaigns.doc(campaignId).collection('pledges');

  CollectionReference<Map<String, dynamic>> _attemptsRef(String campaignId) =>
      _campaigns.doc(campaignId).collection('payment_attempts');

  String? get _uid => _auth.currentUser?.uid;
  String? get _email => _auth.currentUser?.email;
  String? get _displayName => _auth.currentUser?.displayName;

  Campaign _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Campaign.fromJson({...doc.data()!, 'id': doc.id});

  Pledge _pledgeFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String campaignId,
  ) =>
      Pledge.fromJson({...doc.data()!, 'id': doc.id, 'campaignId': campaignId});

  PaymentAttempt _attemptFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String campaignId,
  ) => PaymentAttempt.fromJson({
    ...doc.data()!,
    'id': doc.id,
    'campaignId': campaignId,
  });

  bool _isOwnedByUser(Campaign campaign, {String? email}) {
    final resolvedEmail = email ?? _email;
    if (_uid != null && campaign.creatorUid == _uid) return true;
    if (resolvedEmail != null && campaign.creatorEmail == resolvedEmail) {
      return true;
    }
    if ((campaign.creatorEmail == null || campaign.creatorEmail!.isEmpty) &&
        _displayName != null &&
        _displayName!.isNotEmpty &&
        campaign.creatorName == _displayName) {
      return true;
    }
    return false;
  }

  bool _isCampaignEnded(Campaign campaign) =>
      campaign.status.startsWith('ended') ||
      DateTime.now().isAfter(campaign.endDate);

  Future<CampaignReport> generateCampaignReport({
    required String campaignId,
    String? userEmail,
  }) async {
    final snap = await _campaigns.doc(campaignId).get();
    if (!snap.exists) throw Exception('Campaign not found.');
    final campaign = _fromDoc(snap);

    if (!_isOwnedByUser(campaign, email: userEmail)) {
      throw Exception(
        'Only the campaign owner can generate a report for this campaign.',
      );
    }

    final isEnded = _isCampaignEnded(campaign);

    final pledgesSnap = await _pledgesRef(campaignId).get();
    final campaignPledges =
        pledgesSnap.docs.map((doc) => _pledgeFromDoc(doc, campaignId)).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final attemptsSnap = await _attemptsRef(campaignId).get();
    final paymentAttempts =
        attemptsSnap.docs
            .map((doc) => _attemptFromDoc(doc, campaignId))
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final pledgeAmountTotal = campaignPledges.fold<int>(
      0,
      (total, pledge) => total + pledge.amount,
    );
    final totalPledges = campaignPledges.length;
    final totalRaised = campaign.pledgedAmount;
    final firstPledgeAt = totalPledges > 0
        ? campaignPledges.first.createdAt
        : null;
    final lastPledgeAt = totalPledges > 0
        ? campaignPledges.last.createdAt
        : null;
    final averagePledge = totalPledges > 0
        ? pledgeAmountTotal / totalPledges
        : (campaign.backersCount > 0
              ? campaign.pledgedAmount / campaign.backersCount
              : 0.0);

    final rewardBreakdown = campaign.rewards.map((tier) {
      final related = campaignPledges.where(
        (pledge) => pledge.rewardId == tier.id,
      );
      return CampaignRewardReportItem(
        rewardTier: tier,
        pledgeCount: related.length,
        totalAmount: related.fold<int>(
          0,
          (total, pledge) => total + pledge.amount,
        ),
      );
    }).toList();

    final noRewardPledges = campaignPledges
        .where(
          (pledge) =>
              pledge.rewardId == null || pledge.rewardId!.trim().isEmpty,
        )
        .toList();

    final campaignStart = campaign.publishedAt ?? campaign.createdAt;
    final campaignDurationDays = campaign.endDate
        .difference(campaignStart)
        .inDays
        .clamp(0, 99999);

    final isSuccessful = campaign.status == 'ended_success'
        ? true
        : campaign.status == 'ended_fail'
        ? false
        : totalRaised >= campaign.goalAmount;

    return CampaignReport(
      campaign: campaign,
      isEnded: isEnded,
      isSuccessful: isSuccessful,
      totalRaised: totalRaised,
      fundingDifference: totalRaised - campaign.goalAmount,
      totalPledges: totalPledges,
      totalBackers: campaign.backersCount,
      averagePledge: averagePledge,
      firstPledgeAt: firstPledgeAt,
      lastPledgeAt: lastPledgeAt,
      campaignDurationDays: campaignDurationDays,
      pledges: campaignPledges,
      paymentAttempts: paymentAttempts,
      paymentFunnel: _buildPaymentFunnel(paymentAttempts),
      rewardBreakdown: rewardBreakdown,
      noRewardPledgeCount: noRewardPledges.length,
      noRewardAmount: noRewardPledges.fold<int>(
        0,
        (total, pledge) => total + pledge.amount,
      ),
    );
  }

  CampaignPaymentFunnelSummary _buildPaymentFunnel(
    List<PaymentAttempt> attempts,
  ) {
    if (attempts.isEmpty) {
      return const CampaignPaymentFunnelSummary();
    }

    final counts = <String, int>{};
    var totalAttemptAmount = 0;
    var paidAttemptAmount = 0;

    for (final attempt in attempts) {
      counts.update(attempt.status, (value) => value + 1, ifAbsent: () => 1);
      totalAttemptAmount += attempt.amount;
      if (attempt.status == PaymentAttemptStatus.paid) {
        paidAttemptAmount += attempt.amount;
      }
    }

    return CampaignPaymentFunnelSummary(
      totalAttempts: attempts.length,
      totalAttemptAmount: totalAttemptAmount,
      createdCount: counts[PaymentAttemptStatus.created] ?? 0,
      pendingCheckoutCount: counts[PaymentAttemptStatus.pendingCheckout] ?? 0,
      processingCount: counts[PaymentAttemptStatus.processing] ?? 0,
      paidCount: counts[PaymentAttemptStatus.paid] ?? 0,
      failedCount: counts[PaymentAttemptStatus.failed] ?? 0,
      cancelledCount: counts[PaymentAttemptStatus.cancelled] ?? 0,
      expiredCount: counts[PaymentAttemptStatus.expired] ?? 0,
      refundedCount: counts[PaymentAttemptStatus.refunded] ?? 0,
      paidAttemptAmount: paidAttemptAmount,
      firstAttemptAt: attempts.first.createdAt,
      lastAttemptAt: attempts.last.createdAt,
    );
  }
}
