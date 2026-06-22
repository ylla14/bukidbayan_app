import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/models/payment_attempt.dart';

class CampaignRewardReportItem {
  final RewardTier rewardTier;
  final int pledgeCount;
  final int totalAmount;

  const CampaignRewardReportItem({
    required this.rewardTier,
    required this.pledgeCount,
    required this.totalAmount,
  });
}

class CampaignPaymentFunnelSummary {
  final int totalAttempts;
  final int totalAttemptAmount;
  final int createdCount;
  final int pendingCheckoutCount;
  final int processingCount;
  final int paidCount;
  final int failedCount;
  final int cancelledCount;
  final int expiredCount;
  final int refundedCount;
  final int paidAttemptAmount;
  final DateTime? firstAttemptAt;
  final DateTime? lastAttemptAt;

  const CampaignPaymentFunnelSummary({
    this.totalAttempts = 0,
    this.totalAttemptAmount = 0,
    this.createdCount = 0,
    this.pendingCheckoutCount = 0,
    this.processingCount = 0,
    this.paidCount = 0,
    this.failedCount = 0,
    this.cancelledCount = 0,
    this.expiredCount = 0,
    this.refundedCount = 0,
    this.paidAttemptAmount = 0,
    this.firstAttemptAt,
    this.lastAttemptAt,
  });

  bool get hasAttempts => totalAttempts > 0;

  int get activeCheckoutCount =>
      createdCount + pendingCheckoutCount + processingCount;

  int get droppedOffCount =>
      failedCount + cancelledCount + expiredCount + refundedCount;

  double get paidConversionRate =>
      totalAttempts == 0 ? 0 : paidCount / totalAttempts;
}

class CampaignReport {
  final Campaign campaign;
  final bool isEnded;
  final bool isSuccessful;
  final int totalRaised;
  final int fundingDifference;
  final int totalPledges;
  final int totalBackers;
  final double averagePledge;
  final DateTime? firstPledgeAt;
  final DateTime? lastPledgeAt;
  final int campaignDurationDays;
  final List<Pledge> pledges;
  final List<PaymentAttempt> paymentAttempts;
  final CampaignPaymentFunnelSummary paymentFunnel;
  final List<CampaignRewardReportItem> rewardBreakdown;
  final int noRewardPledgeCount;
  final int noRewardAmount;

  const CampaignReport({
    required this.campaign,
    required this.isEnded,
    required this.isSuccessful,
    required this.totalRaised,
    required this.fundingDifference,
    required this.totalPledges,
    required this.totalBackers,
    required this.averagePledge,
    required this.firstPledgeAt,
    required this.lastPledgeAt,
    required this.campaignDurationDays,
    required this.pledges,
    this.paymentAttempts = const [],
    this.paymentFunnel = const CampaignPaymentFunnelSummary(),
    required this.rewardBreakdown,
    required this.noRewardPledgeCount,
    required this.noRewardAmount,
  });
}
