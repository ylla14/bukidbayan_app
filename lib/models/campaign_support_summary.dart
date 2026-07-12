import 'package:bukidbayan_app/models/campaign.dart';

class CampaignSupportSummary {
  final String campaignId;
  final String supporterKey;
  final String? supporterUid;
  final String? supporterEmail;
  final int countedContributionTotal;
  final int awaitingProofContributionTotal;
  final int awaitingReviewContributionTotal;
  final int invalidContributionTotal;
  final int countedPledgeCount;
  final int awaitingProofPledgeCount;
  final int awaitingReviewPledgeCount;
  final int invalidPledgeCount;
  final RewardTier? activeReward;
  final DateTime? lastContributionAt;

  const CampaignSupportSummary({
    required this.campaignId,
    required this.supporterKey,
    required this.supporterUid,
    required this.supporterEmail,
    required this.countedContributionTotal,
    required this.awaitingProofContributionTotal,
    required this.awaitingReviewContributionTotal,
    required this.invalidContributionTotal,
    required this.countedPledgeCount,
    required this.awaitingProofPledgeCount,
    required this.awaitingReviewPledgeCount,
    required this.invalidPledgeCount,
    required this.activeReward,
    required this.lastContributionAt,
  });

  int get pendingContributionTotal =>
      awaitingProofContributionTotal + awaitingReviewContributionTotal;
  int get pendingPledgeCount =>
      awaitingProofPledgeCount + awaitingReviewPledgeCount;

  int get trackedContributionTotal =>
      countedContributionTotal +
      pendingContributionTotal +
      invalidContributionTotal;

  bool get hasActiveReward => activeReward != null;

  static String? supporterKeyFromIdentity({String? uid, String? email}) {
    final trimmedUid = uid?.trim();
    if (trimmedUid != null && trimmedUid.isNotEmpty) {
      return 'uid:$trimmedUid';
    }
    final trimmedEmail = email?.trim().toLowerCase();
    if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
      return 'email:$trimmedEmail';
    }
    return null;
  }

  static String? supporterKeyFromPledge(Pledge pledge) {
    return supporterKeyFromIdentity(
      uid: pledge.backerUid,
      email: pledge.backerEmail,
    );
  }

  static RewardTier? highestEligibleReward(List<RewardTier> rewards, int total) {
    RewardTier? best;
    final sortedRewards = [...rewards]
      ..sort((a, b) => a.minPledge.compareTo(b.minPledge));
    for (final reward in sortedRewards) {
      if (total >= reward.minPledge) {
        best = reward;
      }
    }
    return best;
  }

  static CampaignSupportSummary? build({
    required String campaignId,
    required List<RewardTier> rewards,
    required List<Pledge> pledges,
    String? supporterUid,
    String? supporterEmail,
  }) {
    if (pledges.isEmpty) return null;

    final supporterKey = supporterKeyFromIdentity(
          uid: supporterUid ?? pledges.first.backerUid,
          email: supporterEmail ?? pledges.first.backerEmail,
        ) ??
        supporterKeyFromPledge(pledges.first);
    if (supporterKey == null) return null;

    var countedContributionTotal = 0;
    var awaitingProofContributionTotal = 0;
    var awaitingReviewContributionTotal = 0;
    var invalidContributionTotal = 0;
    var countedPledgeCount = 0;
    var awaitingProofPledgeCount = 0;
    var awaitingReviewPledgeCount = 0;
    var invalidPledgeCount = 0;
    DateTime? lastContributionAt;

    for (final pledge in pledges) {
      if (lastContributionAt == null ||
          pledge.createdAt.isAfter(lastContributionAt)) {
        lastContributionAt = pledge.createdAt;
      }

      if (pledge.isInvalidated) {
        invalidContributionTotal += pledge.amount;
        invalidPledgeCount += 1;
        continue;
      }

      if (pledge.isCountedContribution) {
        countedContributionTotal += pledge.amount;
        countedPledgeCount += 1;
        continue;
      }

      if (pledge.isPendingReview) {
        awaitingReviewContributionTotal += pledge.amount;
        awaitingReviewPledgeCount += 1;
        continue;
      }

      awaitingProofContributionTotal += pledge.amount;
      awaitingProofPledgeCount += 1;
    }

    return CampaignSupportSummary(
      campaignId: campaignId,
      supporterKey: supporterKey,
      supporterUid: supporterUid ?? pledges.first.backerUid,
      supporterEmail: supporterEmail ?? pledges.first.backerEmail,
      countedContributionTotal: countedContributionTotal,
      awaitingProofContributionTotal: awaitingProofContributionTotal,
      awaitingReviewContributionTotal: awaitingReviewContributionTotal,
      invalidContributionTotal: invalidContributionTotal,
      countedPledgeCount: countedPledgeCount,
      awaitingProofPledgeCount: awaitingProofPledgeCount,
      awaitingReviewPledgeCount: awaitingReviewPledgeCount,
      invalidPledgeCount: invalidPledgeCount,
      activeReward: highestEligibleReward(rewards, countedContributionTotal),
      lastContributionAt: lastContributionAt,
    );
  }
}
