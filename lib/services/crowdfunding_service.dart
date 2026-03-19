import 'dart:math';
import 'package:bukidbayan_app/models/campaign_report.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bukidbayan_app/models/campaign.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CrowdfundingService {
  static const String _campaignsKey = 'campaigns_v2';
  static const String _legacyCampaignsKey = 'campaigns_v1';
  static const String _pledgesKey = 'pledges_v1';
  static const String _currentUserKey = 'current_user_email'; // from auth
  static const String _alwaysActiveTestAccountPrefix = '12312312312';
  static const String _alwaysActiveTestCampaignId =
      'test_active_campaign_12312312312';
  static const String _alwaysEndedTestCampaignId =
      'test_ended_campaign_12312312312';
  static const String _alwaysEndedTestRewardId = 'test_ended_reward_12312312312';

  Future<void> seedIfEmpty() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_campaignsKey);
    if (existing != null && existing.isNotEmpty) return;

    // Lightweight migration path for older local builds.
    final legacy = prefs.getString(_legacyCampaignsKey);
    if (legacy != null && legacy.isNotEmpty) {
      await prefs.setString(_campaignsKey, legacy);
      return;
    }

    final now = DateTime.now();

    final campaigns = <Campaign>[
      Campaign(
        id: 'c1',
        title: 'Community Greenhouse for Urban Farmers',
        creatorName: 'BukidBayan Co-op',
        shortBlurb:
            'A shared greenhouse so more families can grow food sustainably.',
        description:
            'We are building a small greenhouse with basic irrigation, seedlings, and training. '
            'Funds will cover materials, tools, and starter kits for community members.',
        isAssetImage: true,
        image: 'assets/images/farmBg.jpg',
        category: 'Irrigation',
        goalAmount: 50000,
        pledgedAmount: 18500,
        backersCount: 62,
        endDate: now.add(const Duration(days: 18)),
        createdAt: now.subtract(const Duration(days: 5)),
        status: 'live',
        publishedAt: now.subtract(const Duration(days: 5)),
        equipmentType: 'Other',
        specs: {
          'Materials': 'Aluminum frame, polycarbonate panels',
          'Dimensions': '4m x 6m x 2.5m height',
          'Water System': 'Drip irrigation with timer',
        },
        includedItems: [
          '1 greenhouse structure',
          'Irrigation system',
          'Basic hand tools',
          'Seedlings starter pack',
        ],
        chosenVariant: null,
        productionTimeline:
            'Week 1-2: Material sourcing and site prep, Week 3-4: Construction and setup, Week 5: Installation and training',
        shippingCoverage: 'Local delivery',
        shippingCostHandling: 'included',
        shippingNotes: 'Delivered and assembled at co-op site',
        warranty:
            '1-year manufacturer warranty on all materials. Co-op provides ongoing maintenance support.',
        spareParts:
            'Replacement polycarbonate panels, drip lines, and valve parts stocked at co-op office.',
        risks:
            'Weather delays during construction. Alternative: Indoor seedling setup if greenhouse cannot be built.',
        safetyNotes:
            'PPE required during assembly. Training provided for irrigation system maintenance.',
        rewards: const [
          RewardTier(
            id: 'r1',
            title: 'Thank you shoutout',
            minPledge: 200,
            discountType: 'percent',
            discountValue: 5,
            usageLimit: 1,
            validityDays: 30,
            notes: 'We will feature your name in our supporter list.',
          ),
          RewardTier(
            id: 'r2',
            title: 'Seedling starter pack',
            minPledge: 600,
            discountType: 'percent',
            discountValue: 10,
            usageLimit: 1,
            validityDays: 90,
            notes: 'A small pack of vegetable seedlings (pickup only).',
          ),
          RewardTier(
            id: 'r3',
            title: 'Harvest basket',
            minPledge: 1500,
            discountType: 'fixed',
            discountValue: 200,
            usageLimit: 4,
            validityDays: 365,
            notes: 'A seasonal basket of produce from the greenhouse.',
          ),
        ],
      ),
      Campaign(
        id: 'c2',
        title: 'Solar-Powered Water Pump for a Small Farm',
        creatorName: 'Ka-Agri Team',
        shortBlurb:
            'Lower electricity costs and improve irrigation reliability.',
        description:
            'This project installs a solar-powered pump and a simple storage system. '
            'It reduces downtime during power interruptions and supports consistent watering.',
        isAssetImage: true,
        image: 'assets/images/bg1.png',
        category: 'Solar/Power',
        goalAmount: 120000,
        pledgedAmount: 42000,
        backersCount: 113,
        endDate: now.add(const Duration(days: 30)),
        createdAt: now.subtract(const Duration(days: 12)),
        status: 'live',
        publishedAt: now.subtract(const Duration(days: 12)),
        equipmentType: 'Pump',
        specs: {
          'Solar Panel Capacity': '500W photovoltaic panels',
          'Pump Type': '1.5HP submersible centrifugal pump',
          'Storage': '5000L tank with float valve',
        },
        includedItems: [
          'Solar panel array',
          'Submersible pump',
          'Storage tank',
          'Mounting hardware',
          'Installation guide',
        ],
        chosenVariant: null,
        productionTimeline:
            'Week 1: Procurement and site assessment, Week 2-3: Installation of panels and tank, Week 4: Pump setup and testing, Week 5: Training and handover',
        shippingCoverage: 'Nationwide delivery',
        shippingCostHandling: 'included',
        shippingNotes:
            'Delivered to farm site. Professional installation included.',
        warranty:
            '5-year manufacturer warranty on solar panels. 2-year warranty on pump and components.',
        spareParts:
            'Replacement pump available from local agricultural suppliers. Panel repair kits stocked.',
        risks:
            'Weather delays in installation. Fallback: temporary generator rental during setup.',
        safetyNotes:
            'Electrical safety training provided. PPE required. High-voltage warning signs installed.',
        rewards: const [
          RewardTier(
            id: 'r1',
            title: 'Digital thank you card',
            minPledge: 300,
            discountType: 'percent',
            discountValue: 5,
            usageLimit: 1,
            validityDays: 30,
            notes: 'A personalized card from our team.',
          ),
          RewardTier(
            id: 'r2',
            title: 'Farm tour slot',
            minPledge: 2000,
            discountType: 'percent',
            discountValue: 15,
            usageLimit: 1,
            validityDays: 60,
            notes: 'Join a guided tour and see the system in action.',
          ),
        ],
      ),
      Campaign(
        id: 'c3',
        title: 'Local Food Hub: Buy Direct from Farmers',
        creatorName: 'Bayan Market',
        shortBlurb:
            'A small online + pickup system for fresher produce and fairer prices.',
        description:
            'We want to set up a basic ordering site, pickup point signage, and onboarding materials '
            'so partner farmers can sell directly to consumers.',
        isAssetImage: true,
        image: 'assets/images/loopyBg.jpg',
        category: 'Marketplace',
        goalAmount: 80000,
        pledgedAmount: 7600,
        backersCount: 21,
        endDate: now.add(const Duration(days: 9)),
        createdAt: now.subtract(const Duration(days: 2)),
        status: 'live',
        publishedAt: now.subtract(const Duration(days: 2)),
        equipmentType: 'Other',
        specs: {
          'Platform':
              'Simple online ordering system compatible with mobile and desktop',
          'Inventory': 'Real-time tracking of farmer inventory and pricing',
          'Payment': 'Cash and digital payment options at pickup',
        },
        includedItems: [
          'Website and mobile app access',
          'Pickup point setup materials',
          'Farmer onboarding training',
          'Marketing materials',
        ],
        chosenVariant: null,
        productionTimeline:
            'Week 1: Platform development finalization, Week 2: Farmer recruitment and training, Week 3: Pickup point setup, Week 4: Soft launch and testing',
        shippingCoverage: 'Pickup',
        shippingCostHandling: 'included',
        shippingNotes:
            'Customers pick up at designated co-op location. Hub operates Saturdays 6am-10am.',
        warranty:
            'Platform support and maintenance included for first year. Dedicated support team available.',
        spareParts:
            'Signage and display materials can be reprinted as needed from local printers.',
        risks:
            'Low farmer adoption initially. Mitigation: Guaranteed market for first 50 farmers.',
        safetyNotes:
            'Food handling best practices training required for all handlers. Cold storage available.',
        rewards: const [
          RewardTier(
            id: 'r1',
            title: 'Supporter badge',
            minPledge: 150,
            discountType: 'percent',
            discountValue: 5,
            usageLimit: 1,
            validityDays: 90,
            notes: 'A supporter badge displayed in your profile (demo).',
          ),
          RewardTier(
            id: 'r2',
            title: 'Discount voucher',
            minPledge: 500,
            discountType: 'fixed',
            discountValue: 100,
            usageLimit: 5,
            validityDays: 180,
            notes: 'A small voucher for your first pickup order.',
          ),
        ],
      ),
      Campaign(
        id: 'c4',
        title: 'Organic Seed Bank Initiative',
        creatorName: 'Farming Collective',
        shortBlurb:
            'Preserve heirloom and native crop varieties through community seed banking.',
        description:
            'Our goal is to create a safe, climate-controlled seed storage facility and conduct workshops '
            'on seed saving techniques. This preserves biodiversity and helps farmers become more self-sufficient.',
        isAssetImage: true,
        image: 'assets/images/farmBg.jpg',
        category: 'Crop Care',
        goalAmount: 75000,
        pledgedAmount: 28400,
        backersCount: 89,
        endDate: now.add(const Duration(days: 25)),
        createdAt: now.subtract(const Duration(days: 8)),
        status: 'live',
        publishedAt: now.subtract(const Duration(days: 8)),
        equipmentType: 'Other',
        specs: {
          'Storage':
              'Temperature and humidity controlled seed vault (15-20C, 30-40% humidity)',
          'Capacity': 'Storage for 10000+ seed varieties',
          'Testing Equipment':
              'Seed germination testing kits and documentation system',
        },
        includedItems: [
          'Climate-controlled storage unit',
          'Seed testing equipment',
          'Documentation system',
          'Preservation containers',
          'Workshop materials',
        ],
        chosenVariant: null,
        productionTimeline:
            'Week 1-2: Facility setup and equipment installation, Week 3: Collection drives with local farmers, Week 4: Cataloging and storage, Week 5: Launch first workshop',
        shippingCoverage: 'Local delivery',
        shippingCostHandling: 'included',
        shippingNotes:
            'Facility located at central co-op location. Seeds distributed via workshops.',
        warranty:
            'Equipment warranty through manufacturers. 2-year seed viability guarantee for stored seeds.',
        spareParts:
            'Replacement storage containers and preservation supplies available quarterly.',
        risks:
            'Seed sourcing delays possible. Mitigation: Partner with 5 regional seed savers.',
        safetyNotes:
            'Proper storage handling training required. PPE provided for seed collection activities.',
        rewards: const [
          RewardTier(
            id: 'r1',
            title: 'Seed packet collection',
            minPledge: 400,
            discountType: 'percent',
            discountValue: 8,
            usageLimit: 1,
            validityDays: 60,
            notes:
                'A curated collection of heirloom seeds to start your garden.',
          ),
          RewardTier(
            id: 'r2',
            title: 'Seed saving workshop',
            minPledge: 1000,
            discountType: 'fixed',
            discountValue: 150,
            usageLimit: 3,
            validityDays: 120,
            notes:
                'Hands-on training session on proper seed collection and storage.',
          ),
          RewardTier(
            id: 'r3',
            title: 'Annual seed membership',
            minPledge: 2500,
            discountType: 'percent',
            discountValue: 20,
            usageLimit: 2,
            validityDays: 365,
            notes:
                'Full year access to our seed bank library and monthly seed shares.',
          ),
        ],
      ),
    ];

    await prefs.setString(_campaignsKey, encodeCampaigns(campaigns));
    await prefs.setString(_pledgesKey, encodePledges(const []));
  }

  Future<List<Campaign>> getCampaigns() async {
    final prefs = await SharedPreferences.getInstance();
    await seedIfEmpty();
    final jsonStr = prefs.getString(_campaignsKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    final campaigns = decodeCampaigns(jsonStr);
    // Public browse list excludes drafts.
    return campaigns.where((c) => c.status != 'draft').toList();
  }

  Future<Campaign?> getCampaignById(String id) async {
    final all = await getCampaigns();
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getCurrentUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentUserKey);
  }

  bool _isOwnedByUser(Campaign campaign, {String? email, String? displayName}) {
    if (email != null &&
        campaign.creatorEmail != null &&
        campaign.creatorEmail == email) {
      return true;
    }
    if ((campaign.creatorEmail == null || campaign.creatorEmail!.isEmpty) &&
        displayName != null &&
        displayName.isNotEmpty &&
        campaign.creatorName == displayName) {
      return true;
    }
    return false;
  }

  bool _isCampaignEnded(Campaign campaign) {
    return campaign.status.startsWith('ended') ||
        DateTime.now().isAfter(campaign.endDate);
  }

  bool _isAlwaysActiveTestAccount(String? email) {
    if (email == null || email.isEmpty) return false;
    return email.toLowerCase().startsWith(
      _alwaysActiveTestAccountPrefix.toLowerCase(),
    );
  }

  Future<void> _ensureAlwaysActiveCampaignForTestAccount({
    required SharedPreferences prefs,
    required String? email,
    required String? displayName,
  }) async {
    if (!_isAlwaysActiveTestAccount(email)) return;

    final campaignsJson = prefs.getString(_campaignsKey);
    final campaigns = (campaignsJson == null || campaignsJson.isEmpty)
        ? <Campaign>[]
        : decodeCampaigns(campaignsJson);
    final pledgesJson = prefs.getString(_pledgesKey);
    final pledges = (pledgesJson == null || pledgesJson.isEmpty)
        ? <Pledge>[]
        : decodePledges(pledgesJson);
    var campaignsChanged = false;
    var pledgesChanged = false;
    final now = DateTime.now();

    final hasOwnedActiveCampaign = campaigns.any(
      (campaign) =>
          _isOwnedByUser(campaign, email: email, displayName: displayName) &&
          campaign.status == 'live' &&
          !_isCampaignEnded(campaign),
    );
    if (!hasOwnedActiveCampaign) {
      final existingIdx = campaigns.indexWhere(
        (campaign) => campaign.id == _alwaysActiveTestCampaignId,
      );

      if (existingIdx >= 0) {
        final existing = campaigns[existingIdx];
        campaigns[existingIdx] = existing.copyWith(
          creatorName:
              (displayName != null && displayName.isNotEmpty)
              ? displayName
              : existing.creatorName,
          creatorEmail: email,
          status: 'live',
          endDate: now.add(const Duration(days: 30)),
          publishedAt: existing.publishedAt ?? now,
          lastEditedAt: now,
        );
      } else {
        campaigns.add(
          Campaign(
            id: _alwaysActiveTestCampaignId,
            title: 'Testing Campaign (Auto Active)',
            creatorName:
                (displayName != null && displayName.isNotEmpty)
                ? displayName
                : 'QA Test Account',
            creatorEmail: email,
            shortBlurb:
                'Auto-maintained campaign for testing active campaign flows.',
            description:
                'This campaign is automatically kept active for the designated test account '
                'so QA can consistently verify active-listing behavior.',
            isAssetImage: true,
            image: 'assets/images/farmBg.jpg',
            category: 'Irrigation',
            goalAmount: 20000,
            pledgedAmount: 0,
            backersCount: 0,
            endDate: now.add(const Duration(days: 30)),
            createdAt: now,
            rewards: const [],
            status: 'live',
            publishedAt: now,
            lastEditedAt: now,
          ),
        );
      }
      campaignsChanged = true;
    }

    final hasOwnedEndedCampaign = campaigns.any(
      (campaign) =>
          _isOwnedByUser(campaign, email: email, displayName: displayName) &&
          _isCampaignEnded(campaign),
    );
    if (!hasOwnedEndedCampaign) {
      final existingEndedIdx = campaigns.indexWhere(
        (campaign) => campaign.id == _alwaysEndedTestCampaignId,
      );
      final endedCreatedAt = now.subtract(const Duration(days: 50));
      final endedPublishedAt = now.subtract(const Duration(days: 45));
      final endedDate = now.subtract(const Duration(days: 12));

      if (existingEndedIdx >= 0) {
        final existing = campaigns[existingEndedIdx];
        campaigns[existingEndedIdx] = existing.copyWith(
          creatorName:
              (displayName != null && displayName.isNotEmpty)
              ? displayName
              : existing.creatorName,
          creatorEmail: email,
          status: 'ended_success',
          goalAmount: 8000,
          pledgedAmount: 9000,
          backersCount: 3,
          endDate: endedDate,
          publishedAt: existing.publishedAt ?? endedPublishedAt,
          lastEditedAt: now,
          rewards: const [
            RewardTier(
              id: _alwaysEndedTestRewardId,
              title: 'Tester Reward Tier',
              minPledge: 500,
              discountType: 'percent',
              discountValue: 10,
              usageLimit: 1,
              validityDays: 60,
              notes: 'Autogenerated reward tier for report testing.',
            ),
          ],
        );
      } else {
        campaigns.add(
          Campaign(
            id: _alwaysEndedTestCampaignId,
            title: 'Testing Campaign (Ended for Report)',
            creatorName:
                (displayName != null && displayName.isNotEmpty)
                ? displayName
                : 'QA Test Account',
            creatorEmail: email,
            shortBlurb:
                'Autogenerated finished campaign so report generation can be tested anytime.',
            description:
                'This campaign is intentionally created as already finished so the designated '
                'test account can always generate a campaign report without manual setup.',
            isAssetImage: true,
            image: 'assets/images/loopyBg.jpg',
            category: 'Solar/Power',
            goalAmount: 8000,
            pledgedAmount: 9000,
            backersCount: 3,
            endDate: endedDate,
            createdAt: endedCreatedAt,
            rewards: const [
              RewardTier(
                id: _alwaysEndedTestRewardId,
                title: 'Tester Reward Tier',
                minPledge: 500,
                discountType: 'percent',
                discountValue: 10,
                usageLimit: 1,
                validityDays: 60,
                notes: 'Autogenerated reward tier for report testing.',
              ),
            ],
            status: 'ended_success',
            publishedAt: endedPublishedAt,
            lastEditedAt: now,
            specs: const {
              'Mode': 'QA seed',
              'Purpose': 'Report generation test',
              'Lifecycle': 'Finished',
            },
            includedItems: const ['Report sample equipment', 'QA checklist'],
            productionTimeline:
                'Week 1: Setup, Week 2: Launch, Week 3: Completion.',
            shippingCoverage: 'Local delivery',
            shippingCostHandling: 'included',
            shippingNotes: 'Seeded for testing report flow.',
            warranty: 'Seeded test warranty details for report display.',
            spareParts: 'Seeded spare parts details for report display.',
            risks: 'Seeded risk notes for report display.',
            safetyNotes: 'Seeded safety notes for report display.',
          ),
        );
      }
      campaignsChanged = true;
    }

    final hasEndedCampaignPledges = pledges.any(
      (pledge) => pledge.campaignId == _alwaysEndedTestCampaignId,
    );
    if (!hasEndedCampaignPledges && email != null && email.isNotEmpty) {
      pledges.addAll([
        Pledge(
          id: 'p_test_ended_123_1',
          campaignId: _alwaysEndedTestCampaignId,
          backerEmail: '${_alwaysActiveTestAccountPrefix}_backer1@test.local',
          backerName: 'Test Supporter 1',
          backerPhone: '09170000001',
          amount: 3000,
          rewardId: _alwaysEndedTestRewardId,
          createdAt: now.subtract(const Duration(days: 40)),
        ),
        Pledge(
          id: 'p_test_ended_123_2',
          campaignId: _alwaysEndedTestCampaignId,
          backerEmail: '${_alwaysActiveTestAccountPrefix}_backer2@test.local',
          backerName: 'Test Supporter 2',
          backerPhone: '09170000002',
          amount: 2500,
          rewardId: _alwaysEndedTestRewardId,
          createdAt: now.subtract(const Duration(days: 32)),
        ),
        Pledge(
          id: 'p_test_ended_123_3',
          campaignId: _alwaysEndedTestCampaignId,
          backerEmail: '${_alwaysActiveTestAccountPrefix}_backer3@test.local',
          backerName: 'Test Supporter 3',
          backerPhone: '09170000003',
          backerNote: 'Seeded donor note for report QA.',
          amount: 3500,
          rewardId: null,
          createdAt: now.subtract(const Duration(days: 20)),
        ),
      ]);
      pledgesChanged = true;
    }

    if (campaignsChanged) {
      await prefs.setString(_campaignsKey, encodeCampaigns(campaigns));
    }
    if (pledgesChanged) {
      await prefs.setString(_pledgesKey, encodePledges(pledges));
    }
  }

  Future<CampaignReport> generateCampaignReport({
    required String campaignId,
    String? userEmail,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await seedIfEmpty();

    final campaignsJson = prefs.getString(_campaignsKey);
    if (campaignsJson == null || campaignsJson.isEmpty) {
      throw Exception('No campaigns found.');
    }

    final campaigns = decodeCampaigns(campaignsJson);
    final idx = campaigns.indexWhere((c) => c.id == campaignId);
    if (idx == -1) {
      throw Exception('Campaign not found.');
    }

    final campaign = campaigns[idx];

    String? firebaseEmail;
    String? firebaseDisplayName;
    try {
      firebaseEmail = FirebaseAuth.instance.currentUser?.email;
      firebaseDisplayName = FirebaseAuth.instance.currentUser?.displayName;
    } catch (_) {
      firebaseEmail = null;
      firebaseDisplayName = null;
    }

    final resolvedEmail =
        userEmail ?? prefs.getString(_currentUserKey) ?? firebaseEmail;
    final displayName = firebaseDisplayName;

    final isOwner = _isOwnedByUser(
      campaign,
      email: resolvedEmail,
      displayName: displayName,
    );
    if (!isOwner) {
      throw Exception(
        'Only the campaign owner can generate a report for this campaign.',
      );
    }

    if (!_isCampaignEnded(campaign)) {
      throw Exception(
        'Campaign report can only be generated after the campaign has ended.',
      );
    }

    final pledgesJson = prefs.getString(_pledgesKey);
    final pledges = (pledgesJson == null || pledgesJson.isEmpty)
        ? <Pledge>[]
        : decodePledges(pledgesJson);

    final campaignPledges = pledges
        .where((p) => p.campaignId == campaign.id)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final pledgeAmountTotal = campaignPledges.fold<int>(
      0,
      (sum, p) => sum + p.amount,
    );
    final totalPledges = campaignPledges.length;
    final totalRaised = campaign.pledgedAmount;
    final firstPledgeAt = totalPledges > 0 ? campaignPledges.first.createdAt : null;
    final lastPledgeAt = totalPledges > 0 ? campaignPledges.last.createdAt : null;
    final averagePledge = totalPledges > 0
        ? pledgeAmountTotal / totalPledges
        : (campaign.backersCount > 0
              ? campaign.pledgedAmount / campaign.backersCount
              : 0.0);

    final rewardBreakdown = campaign.rewards.map((rewardTier) {
      final related = campaignPledges.where((p) => p.rewardId == rewardTier.id);
      final amount = related.fold<int>(0, (sum, p) => sum + p.amount);
      final count = related.length;
      return CampaignRewardReportItem(
        rewardTier: rewardTier,
        pledgeCount: count,
        totalAmount: amount,
      );
    }).toList();

    final noRewardPledges = campaignPledges
        .where((p) => p.rewardId == null || p.rewardId!.trim().isEmpty)
        .toList();
    final noRewardAmount = noRewardPledges.fold<int>(
      0,
      (sum, p) => sum + p.amount,
    );
    final campaignStart = campaign.publishedAt ?? campaign.createdAt;
    final campaignDurationDays = max(
      0,
      campaign.endDate.difference(campaignStart).inDays,
    );

    final isSuccessful = campaign.status == 'ended_success'
        ? true
        : campaign.status == 'ended_fail'
        ? false
        : totalRaised >= campaign.goalAmount;

    return CampaignReport(
      campaign: campaign,
      isEnded: true,
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
      rewardBreakdown: rewardBreakdown,
      noRewardPledgeCount: noRewardPledges.length,
      noRewardAmount: noRewardAmount,
    );
  }

  Future<List<Campaign>> getMyCampaigns({
    String? userEmail,
    String? status,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await seedIfEmpty();
    final resolvedEmail =
        userEmail ??
        prefs.getString(_currentUserKey) ??
        FirebaseAuth.instance.currentUser?.email;
    final displayName = FirebaseAuth.instance.currentUser?.displayName;
    await _ensureAlwaysActiveCampaignForTestAccount(
      prefs: prefs,
      email: resolvedEmail,
      displayName: displayName,
    );
    final campaignsJson = prefs.getString(_campaignsKey);
    if (campaignsJson == null || campaignsJson.isEmpty) return [];

    final campaigns = decodeCampaigns(campaignsJson).where((c) {
      final matchesOwner = _isOwnedByUser(
        c,
        email: resolvedEmail,
        displayName: displayName,
      );
      if (!matchesOwner) return false;
      if (status != null) return c.status == status;
      return true;
    }).toList();

    campaigns.sort((a, b) {
      final aTime = a.lastEditedAt ?? a.createdAt;
      final bTime = b.lastEditedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });

    return campaigns;
  }

  Future<List<Pledge>> getMyPledges() async {
    final prefs = await SharedPreferences.getInstance();
    final email =
        prefs.getString(_currentUserKey) ??
        FirebaseAuth.instance.currentUser?.email;
    final jsonStr = prefs.getString(_pledgesKey);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    final pledges = decodePledges(jsonStr);
    if (email == null) return pledges; // fallback: show all in demo mode
    return pledges.where((p) => p.backerEmail == email).toList();
  }

  Future<void> backCampaign({
    required String campaignId,
    required int amount,
    String? rewardId,
    String? backerName,
    String? backerPhone,
    String? backerNote,
  }) async {
    if (amount <= 0) {
      throw Exception('Amount must be greater than zero.');
    }

    final prefs = await SharedPreferences.getInstance();

    final campaignsJson = prefs.getString(_campaignsKey);
    if (campaignsJson == null || campaignsJson.isEmpty) {
      throw Exception('No campaigns found.');
    }

    final campaigns = decodeCampaigns(campaignsJson);
    final idx = campaigns.indexWhere((c) => c.id == campaignId);
    if (idx == -1) throw Exception('Campaign not found.');

    final campaign = campaigns[idx];

    String? firebaseEmail;
    String? firebaseDisplayName;
    try {
      firebaseEmail = FirebaseAuth.instance.currentUser?.email;
      firebaseDisplayName = FirebaseAuth.instance.currentUser?.displayName;
    } catch (_) {
      firebaseEmail = null;
      firebaseDisplayName = null;
    }

    final email = prefs.getString(_currentUserKey) ?? firebaseEmail;
    final displayName = firebaseDisplayName;
    final isOwner = _isOwnedByUser(
      campaign,
      email: email,
      displayName: displayName,
    );
    if (isOwner) {
      throw Exception('You cannot support your own campaign.');
    }

    if (DateTime.now().isAfter(campaign.endDate)) {
      throw Exception('This campaign has already ended.');
    }

    final pledgesJson = prefs.getString(_pledgesKey);
    final pledges = (pledgesJson == null || pledgesJson.isEmpty)
        ? <Pledge>[]
        : decodePledges(pledgesJson);

    final isNewBacker = email == null
        ? true
        : !pledges.any(
            (p) => p.campaignId == campaignId && p.backerEmail == email,
          );

    final normalizedBackerName = backerName?.trim().isNotEmpty == true
        ? backerName!.trim()
        : displayName;
    final normalizedBackerPhone = backerPhone?.trim().isNotEmpty == true
        ? backerPhone!.trim()
        : null;
    final normalizedBackerNote = backerNote?.trim().isNotEmpty == true
        ? backerNote!.trim()
        : null;

    final pledge = Pledge(
      id: 'p${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(999)}',
      campaignId: campaignId,
      backerEmail: email,
      backerName: normalizedBackerName,
      backerPhone: normalizedBackerPhone,
      backerNote: normalizedBackerNote,
      amount: amount,
      rewardId: rewardId,
      createdAt: DateTime.now(),
    );

    pledges.add(pledge);

    final updatedCampaign = campaign.copyWith(
      pledgedAmount: campaign.pledgedAmount + amount,
      backersCount: isNewBacker
          ? campaign.backersCount + 1
          : campaign.backersCount,
    );

    campaigns[idx] = updatedCampaign;

    await prefs.setString(_campaignsKey, encodeCampaigns(campaigns));
    await prefs.setString(_pledgesKey, encodePledges(pledges));
  }

  Future<void> createCampaign({
    required String title,
    required String creatorName,
    required String shortBlurb,
    required String description,
    required bool isAssetImage,
    required String image,
    required String category,
    required int goalAmount,
    required DateTime endDate,
    required List<RewardTier> rewards,
    String? productionTimeline,
    String? warranty,
    String? spareParts,
    String? risks,
    String? safetyNotes,
  }) async {
    if (title.isEmpty ||
        shortBlurb.isEmpty ||
        description.isEmpty ||
        image.isEmpty ||
        goalAmount <= 0 ||
        rewards.isEmpty) {
      throw Exception('All required fields must be filled.');
    }

    if (endDate.isBefore(DateTime.now())) {
      throw Exception('End date must be in the future.');
    }

    final prefs = await SharedPreferences.getInstance();
    final creatorEmail =
        prefs.getString(_currentUserKey) ??
        FirebaseAuth.instance.currentUser?.email;

    final campaignsJson = prefs.getString(_campaignsKey);
    final campaigns = (campaignsJson == null || campaignsJson.isEmpty)
        ? <Campaign>[]
        : decodeCampaigns(campaignsJson);

    final newCampaign = Campaign(
      id: 'c${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(9999)}',
      title: title,
      creatorName: creatorName,
      creatorEmail: creatorEmail,
      shortBlurb: shortBlurb,
      description: description,
      isAssetImage: isAssetImage,
      image: image,
      category: category,
      goalAmount: goalAmount,
      pledgedAmount: 0,
      backersCount: 0,
      endDate: endDate,
      createdAt: DateTime.now(),
      rewards: rewards,
      productionTimeline: productionTimeline,
      warranty: warranty,
      spareParts: spareParts,
      risks: risks,
      safetyNotes: safetyNotes,
    );

    campaigns.add(newCampaign);

    await prefs.setString(_campaignsKey, encodeCampaigns(campaigns));
  }

  // DRAFT MANAGEMENT METHODS

  /// Save a campaign draft locally with lastEditedAt timestamp
  Future<void> saveDraft(Campaign draft) async {
    final prefs = await SharedPreferences.getInstance();
    final currentEmail =
        prefs.getString(_currentUserKey) ??
        FirebaseAuth.instance.currentUser?.email;

    final campaignsJson = prefs.getString(_campaignsKey);
    final campaigns = (campaignsJson == null || campaignsJson.isEmpty)
        ? <Campaign>[]
        : decodeCampaigns(campaignsJson);

    final draftToSave = draft.copyWith(
      creatorEmail: draft.creatorEmail ?? currentEmail,
      status: 'draft',
      lastEditedAt: DateTime.now(),
    );

    // Update existing draft or add new one
    final idx = campaigns.indexWhere((d) => d.id == draft.id);
    if (idx >= 0) {
      campaigns[idx] = draftToSave;
    } else {
      campaigns.add(draftToSave);
    }

    await prefs.setString(_campaignsKey, encodeCampaigns(campaigns));
  }

  /// Get all saved drafts for current user
  Future<List<Campaign>> getDrafts({String? userEmail}) async {
    final prefs = await SharedPreferences.getInstance();
    await seedIfEmpty();
    final resolvedEmail =
        userEmail ??
        prefs.getString(_currentUserKey) ??
        FirebaseAuth.instance.currentUser?.email;
    final displayName = FirebaseAuth.instance.currentUser?.displayName;
    final campaignsJson = prefs.getString(_campaignsKey);
    if (campaignsJson == null || campaignsJson.isEmpty) return [];

    final campaigns = decodeCampaigns(campaignsJson);
    final hasIdentity =
        (resolvedEmail != null && resolvedEmail.isNotEmpty) ||
        (displayName != null && displayName.isNotEmpty);

    final drafts = campaigns.where((c) {
      if (c.status != 'draft') return false;
      if (!hasIdentity) return true;
      return _isOwnedByUser(c, email: resolvedEmail, displayName: displayName);
    }).toList();

    drafts.sort((a, b) {
      final aTime = a.lastEditedAt ?? a.createdAt;
      final bTime = b.lastEditedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });

    return drafts;
  }

  /// Get a specific draft by ID
  Future<Campaign?> getDraftById(String draftId) async {
    final prefs = await SharedPreferences.getInstance();
    final email =
        prefs.getString(_currentUserKey) ??
        FirebaseAuth.instance.currentUser?.email;
    final displayName = FirebaseAuth.instance.currentUser?.displayName;
    final campaignsJson = prefs.getString(_campaignsKey);
    if (campaignsJson == null || campaignsJson.isEmpty) return null;

    final campaigns = decodeCampaigns(campaignsJson);
    try {
      return campaigns.firstWhere((c) {
        if (c.id != draftId || c.status != 'draft') return false;
        final hasIdentity =
            (email != null && email.isNotEmpty) ||
            (displayName != null && displayName.isNotEmpty);
        if (!hasIdentity) return true;
        return _isOwnedByUser(c, email: email, displayName: displayName);
      });
    } catch (_) {
      return null;
    }
  }

  /// Delete a draft
  Future<void> deleteDraft(String draftId) async {
    final prefs = await SharedPreferences.getInstance();
    final email =
        prefs.getString(_currentUserKey) ??
        FirebaseAuth.instance.currentUser?.email;
    final displayName = FirebaseAuth.instance.currentUser?.displayName;
    final campaignsJson = prefs.getString(_campaignsKey);
    if (campaignsJson == null || campaignsJson.isEmpty) return;

    final campaigns = decodeCampaigns(campaignsJson);
    campaigns.removeWhere((c) {
      if (c.id != draftId || c.status != 'draft') return false;
      final hasIdentity =
          (email != null && email.isNotEmpty) ||
          (displayName != null && displayName.isNotEmpty);
      if (!hasIdentity) return true;
      return _isOwnedByUser(c, email: email, displayName: displayName);
    });

    await prefs.setString(_campaignsKey, encodeCampaigns(campaigns));
  }

  /// Validate campaign for publishing - returns list of errors
  List<String> validateForPublish(Campaign campaign) {
    final errors = <String>[];

    if (campaign.title.isEmpty ||
        campaign.title.length < 8 ||
        campaign.title.length > 70) {
      errors.add('Ang pamagat ay dapat nasa pagitan ng 8 at 70 character');
    }
    if (campaign.category.isEmpty) {
      errors.add('Kailangan ang kategorya');
    }
    if (campaign.image.isEmpty) {
      errors.add('Kailangan ang cover photo o video');
    }
    if (campaign.shortBlurb.isEmpty || campaign.shortBlurb.length < 10) {
      errors.add('Ang maikling buod ay dapat hindi bababa sa 10 character');
    }
    if (campaign.description.isEmpty || campaign.description.length < 50) {
      errors.add(
        'Ang buong paglalarawan ay dapat hindi bababa sa 50 character',
      );
    }
    if (campaign.specs.isEmpty || campaign.specs.length < 3) {
      errors.add('Kailangan ang hindi bababa sa 3 detalye ng kagamitan');
    }
    if (campaign.includedItems.isEmpty ||
        campaign.includedItems.join().isEmpty ||
        campaign.includedItems.join().length < 10) {
      errors.add(
        'Ang saklaw ng bibilhin ay dapat hindi bababa sa 10 character',
      );
    }
    if (campaign.goalAmount < 1000) {
      errors.add('Ang target na pondo ay dapat hindi bababa sa ₱1,000');
    }
    if (campaign.endDate.isBefore(DateTime.now())) {
      errors.add('Ang petsa ng pagtatapos ay dapat nasa hinaharap');
    }
    if (campaign.productionTimeline == null ||
        campaign.productionTimeline!.isEmpty ||
        campaign.productionTimeline!.length < 10) {
      errors.add(
        'Ang timeline ng pagpapatupad ay dapat hindi bababa sa 10 character',
      );
    }
    if (campaign.rewards.isEmpty) {
      errors.add('Kailangan ang hindi bababa sa isang antas ng benepisyo');
    } else {
      // Validate reward tiers
      for (final reward in campaign.rewards) {
        if (reward.title.isEmpty) {
          errors.add('Kailangang may pamagat ang bawat antas ng benepisyo');
        }
        if (reward.minPledge <= 0) {
          errors.add(
            'Kailangang higit sa zero ang minimum na pledge ng bawat benepisyo',
          );
        }
        if (reward.discountValue <= 0) {
          errors.add(
            'Kailangang higit sa zero ang halaga ng diskuwento ng bawat benepisyo',
          );
        }
      }
    }
    if (campaign.shippingCoverage == null ||
        campaign.shippingCoverage!.isEmpty) {
      errors.add('Kailangan ang saklaw ng delivery');
    }
    if (campaign.shippingCostHandling == null ||
        campaign.shippingCostHandling!.isEmpty) {
      errors.add('Kailangan kung paano isasama ang gastos sa delivery');
    }
    if (campaign.warranty == null ||
        campaign.warranty!.isEmpty ||
        campaign.warranty!.length < 10) {
      errors.add(
        'Ang warranty at suporta ay dapat hindi bababa sa 10 character',
      );
    }
    if (campaign.spareParts == null ||
        campaign.spareParts!.isEmpty ||
        campaign.spareParts!.length < 10) {
      errors.add(
        'Ang plano sa spare parts ay dapat hindi bababa sa 10 character',
      );
    }
    if (campaign.risks == null ||
        campaign.risks!.isEmpty ||
        campaign.risks!.length < 10) {
      errors.add('Ang mga panganib ay dapat hindi bababa sa 10 character');
    }
    if (campaign.safetyNotes == null ||
        campaign.safetyNotes!.isEmpty ||
        campaign.safetyNotes!.length < 10) {
      errors.add(
        'Ang paalala sa kaligtasan ay dapat hindi bababa sa 10 character',
      );
    }

    return errors;
  }

  /// Publish a campaign from draft
  Future<void> publishCampaign(Campaign campaign) async {
    final errors = validateForPublish(campaign);
    if (errors.isNotEmpty) {
      throw Exception('Cannot publish: ${errors.join(', ')}');
    }

    final prefs = await SharedPreferences.getInstance();
    final currentEmail =
        prefs.getString(_currentUserKey) ??
        FirebaseAuth.instance.currentUser?.email;

    // Update draft to live
    final campaignsJson = prefs.getString(_campaignsKey);
    final campaigns = (campaignsJson == null || campaignsJson.isEmpty)
        ? <Campaign>[]
        : decodeCampaigns(campaignsJson);

    final idx = campaigns.indexWhere((c) => c.id == campaign.id);
    final publishedCampaign = campaign.copyWith(
      creatorEmail: campaign.creatorEmail ?? currentEmail,
      status: 'live',
      publishedAt: DateTime.now(),
      lastEditedAt: DateTime.now(),
    );

    if (idx >= 0) {
      campaigns[idx] = publishedCampaign;
    } else {
      campaigns.add(publishedCampaign);
    }

    await prefs.setString(_campaignsKey, encodeCampaigns(campaigns));
  }
}
