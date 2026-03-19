import 'package:bukidbayan_app/models/campaign.dart';

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
    required this.rewardBreakdown,
    required this.noRewardPledgeCount,
    required this.noRewardAmount,
  });
}
