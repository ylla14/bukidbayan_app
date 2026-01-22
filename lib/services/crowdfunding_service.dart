import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bukidbayan_app/models/campaign.dart';

class CrowdfundingService {
  static const String _campaignsKey = 'campaigns_v1';
  static const String _pledgesKey = 'pledges_v1';
  static const String _currentUserKey = 'current_user_email'; // from auth

  Future<void> seedIfEmpty() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_campaignsKey);
    if (existing != null && existing.isNotEmpty) return;

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
        category: 'Agriculture',
        goalAmount: 50000,
        pledgedAmount: 18500,
        backersCount: 62,
        endDate: now.add(const Duration(days: 18)),
        createdAt: now.subtract(const Duration(days: 5)),
        rewards: const [
          RewardTier(
            id: 'r1',
            title: 'Thank you shoutout',
            description: 'We will feature your name in our supporter list.',
            minPledge: 200,
            estimatedDelivery: 'Next week',
            shipping: 'No shipping',
          ),
          RewardTier(
            id: 'r2',
            title: 'Seedling starter pack',
            description: 'A small pack of vegetable seedlings (pickup).',
            minPledge: 600,
            estimatedDelivery: 'Next month',
            shipping: 'Pickup only',
          ),
          RewardTier(
            id: 'r3',
            title: 'Harvest basket',
            description: 'A seasonal basket of produce from the greenhouse.',
            minPledge: 1500,
            estimatedDelivery: '2-3 months',
            shipping: 'Metro Manila only',
          ),
        ],
      ),
      Campaign(
        id: 'c2',
        title: 'Solar-Powered Water Pump for a Small Farm',
        creatorName: 'Ka-Agri Team',
        shortBlurb: 'Lower electricity costs and improve irrigation reliability.',
        description:
            'This project installs a solar-powered pump and a simple storage system. '
            'It reduces downtime during power interruptions and supports consistent watering.',
        isAssetImage: true,
        image: 'assets/images/bg1.png',
        category: 'Sustainability',
        goalAmount: 120000,
        pledgedAmount: 42000,
        backersCount: 113,
        endDate: now.add(const Duration(days: 30)),
        createdAt: now.subtract(const Duration(days: 12)),
        rewards: const [
          RewardTier(
            id: 'r1',
            title: 'Digital thank you card',
            description: 'A personalized card from our team.',
            minPledge: 300,
            estimatedDelivery: 'Next week',
            shipping: 'No shipping',
          ),
          RewardTier(
            id: 'r2',
            title: 'Farm tour slot',
            description: 'Join a guided tour and see the system in action.',
            minPledge: 2000,
            estimatedDelivery: '2 months',
            shipping: 'On-site',
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
        rewards: const [
          RewardTier(
            id: 'r1',
            title: 'Supporter badge',
            description: 'A supporter badge displayed in your profile (demo).',
            minPledge: 150,
            estimatedDelivery: 'Instant',
            shipping: 'No shipping',
          ),
          RewardTier(
            id: 'r2',
            title: 'Discount voucher',
            description: 'A small voucher for your first pickup order.',
            minPledge: 500,
            estimatedDelivery: 'Next month',
            shipping: 'Digital',
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
    return decodeCampaigns(jsonStr);
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

  Future<List<Pledge>> getMyPledges() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_currentUserKey);
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
    if (DateTime.now().isAfter(campaign.endDate)) {
      throw Exception('This campaign has already ended.');
    }

    final pledgesJson = prefs.getString(_pledgesKey);
    final pledges = (pledgesJson == null || pledgesJson.isEmpty)
        ? <Pledge>[]
        : decodePledges(pledgesJson);

    final email = prefs.getString(_currentUserKey);

    final isNewBacker = email == null
        ? true
        : !pledges.any((p) => p.campaignId == campaignId && p.backerEmail == email);

    final pledge = Pledge(
      id: 'p${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(999)}',
      campaignId: campaignId,
      backerEmail: email,
      amount: amount,
      rewardId: rewardId,
      createdAt: DateTime.now(),
    );

    pledges.add(pledge);

    final updatedCampaign = campaign.copyWith(
      pledgedAmount: campaign.pledgedAmount + amount,
      backersCount: isNewBacker ? campaign.backersCount + 1 : campaign.backersCount,
    );

    campaigns[idx] = updatedCampaign;

    await prefs.setString(_campaignsKey, encodeCampaigns(campaigns));
    await prefs.setString(_pledgesKey, encodePledges(pledges));
  }
}
