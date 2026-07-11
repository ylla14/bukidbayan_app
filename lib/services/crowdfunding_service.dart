import 'dart:math';

import 'package:bukidbayan_app/models/campaign_report.dart';
import 'package:bukidbayan_app/services/analytics/campaign_analytics_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bukidbayan_app/models/campaign.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CrowdfundingService {
  CrowdfundingService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreOverride = firestore,
      _authOverride = auth;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  static const _campaignsPrefsKey = 'campaigns_v2';
  static const _pledgesPrefsKey = 'pledges_v1';
  static const _currentUserEmailPrefsKey = 'current_user_email';

  FirebaseFirestore? get _dbOrNull {
    if (_firestoreOverride != null) return _firestoreOverride;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseAuth? get _authOrNull {
    if (_authOverride != null) return _authOverride;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore get _db =>
      _dbOrNull ?? (throw StateError('FirebaseFirestore is unavailable.'));
  FirebaseAuth? get _auth => _authOrNull;

  CollectionReference<Map<String, dynamic>> get _campaigns =>
      _db.collection('campaigns');

  CollectionReference<Map<String, dynamic>> _pledgesRef(String campaignId) =>
      _campaigns.doc(campaignId).collection('pledges');

  String? get _uid => _auth?.currentUser?.uid;
  String? get _email => _auth?.currentUser?.email;
  String? get _displayName => _auth?.currentUser?.displayName;

  // ── Helpers ───────────────────────────────────────────────────────────────

  Campaign _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Campaign.fromJson({...doc.data()!, 'id': doc.id});

  Pledge _pledgeFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String campaignId,
  ) =>
      Pledge.fromJson({...doc.data()!, 'id': doc.id, 'campaignId': campaignId});

  bool _isOwnedByUser(
    Campaign campaign, {
    String? uid,
    String? email,
    String? displayName,
  }) {
    final u = uid ?? _uid;
    final e = email ?? _email;
    final d = displayName ?? _displayName;
    if (u != null && campaign.creatorUid == u) return true;
    if (e != null && campaign.creatorEmail == e) return true;
    if ((campaign.creatorEmail == null || campaign.creatorEmail!.isEmpty) &&
        d != null &&
        d.isNotEmpty &&
        campaign.creatorName == d) {
      return true;
    }
    return false;
  }

  bool _isCampaignEnded(Campaign campaign) =>
      campaign.status.startsWith('ended') ||
      DateTime.now().isAfter(campaign.endDate);

  Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  Future<List<Campaign>> _readLocalCampaigns() async {
    final raw = (await _prefs()).getString(_campaignsPrefsKey);
    if (raw == null || raw.trim().isEmpty) return [];
    return decodeCampaigns(raw);
  }

  Future<void> _writeLocalCampaigns(List<Campaign> campaigns) async {
    await (await _prefs()).setString(
      _campaignsPrefsKey,
      encodeCampaigns(campaigns),
    );
  }

  Future<List<Pledge>> _readLocalPledges() async {
    final raw = (await _prefs()).getString(_pledgesPrefsKey);
    if (raw == null || raw.trim().isEmpty) return [];
    return decodePledges(raw);
  }

  Future<void> _writeLocalPledges(List<Pledge> pledges) async {
    await (await _prefs()).setString(_pledgesPrefsKey, encodePledges(pledges));
  }

  Future<String?> _currentLocalEmail({String? override}) async {
    if (override != null) {
      final trimmed = override.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    final runtimeEmail = _email;
    if (runtimeEmail != null) {
      final trimmed = runtimeEmail.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    final stored = (await _prefs()).getString(_currentUserEmailPrefsKey);
    if (stored == null) return null;
    final trimmed = stored.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _sortCampaignsByRecency(List<Campaign> campaigns) {
    campaigns.sort((a, b) {
      final aTime = a.lastEditedAt ?? a.publishedAt ?? a.createdAt;
      final bTime = b.lastEditedAt ?? b.publishedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
  }

  void _upsertLocalCampaign(List<Campaign> campaigns, Campaign campaign) {
    final index = campaigns.indexWhere(
      (existing) => existing.id == campaign.id,
    );
    if (index == -1) {
      campaigns.add(campaign);
    } else {
      campaigns[index] = campaign;
    }
  }

  CampaignReport _buildCampaignReport({
    required Campaign campaign,
    required List<Pledge> campaignPledges,
  }) {
    final pledgeAmountTotal = campaignPledges.fold<int>(
      0,
      (sum, pledge) => sum + pledge.amount,
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
        totalAmount: related.fold<int>(0, (sum, pledge) => sum + pledge.amount),
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
      isEnded: _isCampaignEnded(campaign),
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
      noRewardAmount: noRewardPledges.fold<int>(
        0,
        (sum, pledge) => sum + pledge.amount,
      ),
    );
  }

  Future<void> _publishCampaignLocal(Campaign campaign) async {
    final localCampaigns = await _readLocalCampaigns();
    final now = DateTime.now();
    final published = campaign.copyWith(
      creatorEmail: campaign.creatorEmail ?? await _currentLocalEmail(),
      creatorUid: campaign.creatorUid ?? _uid,
      status: 'live',
      publishedAt: now,
      lastEditedAt: now,
    );
    _upsertLocalCampaign(localCampaigns, published);
    await _writeLocalCampaigns(localCampaigns);
  }

  void _assertAtMostOneProof(String? proofImageUrl, String? proofReferenceNumber) {
    final hasImage = proofImageUrl != null && proofImageUrl.trim().isNotEmpty;
    final hasReference =
        proofReferenceNumber != null && proofReferenceNumber.trim().isNotEmpty;
    if (hasImage && hasReference) {
      throw Exception(
        'Pumili lang ng isa: larawan o reference number, hindi pareho.',
      );
    }
  }

  Future<void> _backCampaignLocal({
    required String campaignId,
    required int amount,
    String? rewardId,
    String? backerName,
    String? backerPhone,
    String? backerNote,
    String? proofImageUrl,
    String? proofReferenceNumber,
  }) async {
    _assertAtMostOneProof(proofImageUrl, proofReferenceNumber);
    final campaigns = await _readLocalCampaigns();
    final campaignIndex = campaigns.indexWhere(
      (campaign) => campaign.id == campaignId,
    );
    if (campaignIndex == -1) throw Exception('Campaign not found.');

    final campaign = campaigns[campaignIndex];
    final email = await _currentLocalEmail();

    if (_isOwnedByUser(campaign, email: email)) {
      throw Exception('You cannot support your own campaign.');
    }
    if (DateTime.now().isAfter(campaign.endDate)) {
      throw Exception('This campaign has already ended.');
    }
    if (campaign.gcashQrImage == null ||
        campaign.gcashQrImage!.trim().isEmpty) {
      throw Exception(
        'This campaign does not have a GCash QR payment photo yet.',
      );
    }

    RewardTier? selectedReward;
    if (rewardId != null && rewardId.trim().isNotEmpty) {
      for (final tier in campaign.rewards) {
        if (tier.id == rewardId) {
          selectedReward = tier;
          break;
        }
      }
      if (selectedReward == null) {
        throw Exception('Selected reward tier is no longer available.');
      }
      if (amount < selectedReward.minPledge) {
        throw Exception(
          'Amount is below the minimum pledge for this reward tier (${selectedReward.minPledge}).',
        );
      }
    }

    final hasProof =
        (proofImageUrl != null && proofImageUrl.trim().isNotEmpty) ||
        (proofReferenceNumber != null && proofReferenceNumber.trim().isNotEmpty);

    final pledges = await _readLocalPledges();
    final isNewBacker =
        email == null ||
        pledges.every(
          (pledge) =>
              pledge.campaignId != campaignId ||
              pledge.backerEmail != email ||
              !pledge.countedInTotal,
        );
    final pledge = Pledge(
      id: 'p${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(999)}',
      campaignId: campaignId,
      backerUid: _uid,
      backerEmail: email,
      backerName: backerName?.trim().isNotEmpty == true
          ? backerName!.trim()
          : _displayName,
      backerPhone: backerPhone?.trim().isNotEmpty == true
          ? backerPhone!.trim()
          : null,
      backerNote: backerNote?.trim().isNotEmpty == true
          ? backerNote!.trim()
          : null,
      amount: amount,
      rewardId: rewardId,
      createdAt: DateTime.now(),
      proofImageUrl: proofImageUrl,
      proofReferenceNumber: proofReferenceNumber,
      proofSubmittedAt: hasProof ? DateTime.now() : null,
      countedInTotal: hasProof,
    );

    if (hasProof) {
      campaigns[campaignIndex] = campaign.copyWith(
        pledgedAmount: campaign.pledgedAmount + amount,
        backersCount: isNewBacker
            ? campaign.backersCount + 1
            : campaign.backersCount,
      );
    }
    pledges.add(pledge);

    await _writeLocalCampaigns(campaigns);
    await _writeLocalPledges(pledges);
  }

  Future<void> _submitPledgeProofLocal({
    required String campaignId,
    required String pledgeId,
    String? proofImageUrl,
    String? proofReferenceNumber,
  }) async {
    _assertAtMostOneProof(proofImageUrl, proofReferenceNumber);
    final campaigns = await _readLocalCampaigns();
    final campaignIndex = campaigns.indexWhere((c) => c.id == campaignId);
    if (campaignIndex == -1) throw Exception('Campaign not found.');

    final pledges = await _readLocalPledges();
    final pledgeIndex = pledges.indexWhere(
      (p) => p.id == pledgeId && p.campaignId == campaignId,
    );
    if (pledgeIndex == -1) throw Exception('Pledge not found.');

    final pledge = pledges[pledgeIndex];
    final email = await _currentLocalEmail();
    if (pledge.backerEmail != null && pledge.backerEmail != email) {
      throw Exception('You cannot edit another supporter\'s pledge.');
    }
    if (pledge.countedInTotal) return;

    final campaign = campaigns[campaignIndex];
    final isNewBacker = pledges.every(
      (p) =>
          p.id == pledgeId ||
          p.campaignId != campaignId ||
          p.backerEmail != pledge.backerEmail ||
          !p.countedInTotal,
    );

    pledges[pledgeIndex] = Pledge(
      id: pledge.id,
      campaignId: pledge.campaignId,
      backerUid: pledge.backerUid,
      backerEmail: pledge.backerEmail,
      backerName: pledge.backerName,
      backerPhone: pledge.backerPhone,
      backerNote: pledge.backerNote,
      amount: pledge.amount,
      rewardId: pledge.rewardId,
      createdAt: pledge.createdAt,
      proofImageUrl: proofImageUrl,
      proofReferenceNumber: proofReferenceNumber,
      proofSubmittedAt: DateTime.now(),
      countedInTotal: true,
    );
    campaigns[campaignIndex] = campaign.copyWith(
      pledgedAmount: campaign.pledgedAmount + pledge.amount,
      backersCount: isNewBacker
          ? campaign.backersCount + 1
          : campaign.backersCount,
    );

    await _writeLocalCampaigns(campaigns);
    await _writeLocalPledges(pledges);
  }

  Future<CampaignReport> _generateCampaignReportLocal({
    required String campaignId,
    String? userEmail,
  }) async {
    final campaigns = await _readLocalCampaigns();
    final campaignIndex = campaigns.indexWhere(
      (campaign) => campaign.id == campaignId,
    );
    if (campaignIndex == -1) throw Exception('Campaign not found.');

    final campaign = campaigns[campaignIndex];
    final email = await _currentLocalEmail(override: userEmail);
    if (!_isOwnedByUser(campaign, email: email)) {
      throw Exception(
        'Only the campaign owner can generate a report for this campaign.',
      );
    }

    final campaignPledges =
        (await _readLocalPledges())
            .where((pledge) => pledge.campaignId == campaignId)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return _buildCampaignReport(
      campaign: campaign,
      campaignPledges: campaignPledges,
    );
  }

  // ── Seed ─────────────────────────────────────────────────────────────────

  /// Seeds demo campaigns into Firestore if they don't already exist.
  Future<void> seedIfEmpty() async {
    if (_dbOrNull == null) return;
    final doc = await _campaigns.doc('c1').get();
    if (doc.exists) return;

    final now = DateTime.now();
    final batch = _db.batch();
    for (final c in _buildSeedCampaigns(now)) {
      batch.set(_campaigns.doc(c.id), c.toFirestore());
    }
    await batch.commit();
  }

  List<Campaign> _buildSeedCampaigns(DateTime now) => [
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
      specs: const {
        'Materials': 'Aluminum frame, polycarbonate panels',
        'Dimensions': '4m x 6m x 2.5m height',
        'Water System': 'Drip irrigation with timer',
      },
      includedItems: const [
        '1 greenhouse structure',
        'Irrigation system',
        'Basic hand tools',
        'Seedlings starter pack',
      ],
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
      shortBlurb: 'Lower electricity costs and improve irrigation reliability.',
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
      specs: const {
        'Solar Panel Capacity': '500W photovoltaic panels',
        'Pump Type': '1.5HP submersible centrifugal pump',
        'Storage': '5000L tank with float valve',
      },
      includedItems: const [
        'Solar panel array',
        'Submersible pump',
        'Storage tank',
        'Mounting hardware',
        'Installation guide',
      ],
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
      specs: const {
        'Platform':
            'Simple online ordering system compatible with mobile and desktop',
        'Inventory': 'Real-time tracking of farmer inventory and pricing',
        'Payment': 'Cash and digital payment options at pickup',
      },
      includedItems: const [
        'Website and mobile app access',
        'Pickup point setup materials',
        'Farmer onboarding training',
        'Marketing materials',
      ],
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
      specs: const {
        'Storage':
            'Temperature and humidity controlled seed vault (15-20C, 30-40% humidity)',
        'Capacity': 'Storage for 10000+ seed varieties',
        'Testing Equipment':
            'Seed germination testing kits and documentation system',
      },
      includedItems: const [
        'Climate-controlled storage unit',
        'Seed testing equipment',
        'Documentation system',
        'Preservation containers',
        'Workshop materials',
      ],
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
          notes: 'A curated collection of heirloom seeds to start your garden.',
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

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Public discover list — excludes drafts.
  Future<List<Campaign>> getCampaigns() async {
    if (_dbOrNull == null) {
      final campaigns = await _readLocalCampaigns();
      final visible = campaigns.where((campaign) {
        return campaign.status == 'live' ||
            campaign.status == 'ended_success' ||
            campaign.status == 'ended_fail';
      }).toList();
      _sortCampaignsByRecency(visible);
      return visible;
    }
    await seedIfEmpty();
    final snap = await _campaigns
        .where('status', whereIn: ['live', 'ended_success', 'ended_fail'])
        .get();
    return snap.docs.map(_fromDoc).toList();
  }

  /// Fetches a single campaign by ID. Drafts are only returned to their owner.
  Future<Campaign?> getCampaignById(String id) async {
    if (_dbOrNull == null) {
      final campaigns = await _readLocalCampaigns();
      final index = campaigns.indexWhere((campaign) => campaign.id == id);
      if (index == -1) return null;
      final campaign = campaigns[index];
      if (campaign.status == 'draft' &&
          !_isOwnedByUser(campaign, email: await _currentLocalEmail())) {
        return null;
      }
      return campaign;
    }
    final snap = await _campaigns.doc(id).get();
    if (!snap.exists) return null;
    final campaign = _fromDoc(snap);
    if (campaign.status == 'draft' && !_isOwnedByUser(campaign)) return null;
    return campaign;
  }

  Future<String?> getCurrentUserEmail() async => _currentLocalEmail();

  /// Returns all campaigns (any status) owned by the current user.
  Future<List<Campaign>> getMyCampaigns({
    String? userEmail,
    String? status,
  }) async {
    if (_dbOrNull == null) {
      final email = await _currentLocalEmail(override: userEmail);
      if (email == null) return [];
      final campaigns = (await _readLocalCampaigns())
          .where((campaign) => _isOwnedByUser(campaign, email: email))
          .toList();
      final filtered = status == null
          ? campaigns
          : campaigns.where((campaign) => campaign.status == status).toList();
      _sortCampaignsByRecency(filtered);
      return filtered;
    }
    final uid = _uid;
    if (uid == null) return [];

    Query<Map<String, dynamic>> query = _campaigns.where(
      'creatorUid',
      isEqualTo: uid,
    );
    if (status != null) query = query.where('status', isEqualTo: status);

    final snap = await query.get();
    final campaigns = snap.docs.map(_fromDoc).toList();
    campaigns.sort((a, b) {
      final aTime = a.lastEditedAt ?? a.createdAt;
      final bTime = b.lastEditedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    return campaigns;
  }

  /// Returns all pledges made by the current user across all campaigns.
  /// Requires a Firestore collectionGroup index on pledges.backerUid.
  Future<List<Pledge>> getMyPledges() async {
    if (_dbOrNull == null) {
      final email = await _currentLocalEmail();
      if (email == null) return [];
      final pledges = (await _readLocalPledges())
          .where((pledge) => pledge.backerEmail == email)
          .toList();
      pledges.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return pledges;
    }
    final uid = _uid;
    if (uid == null) return [];
    final snap = await _db
        .collectionGroup('pledges')
        .where('backerUid', isEqualTo: uid)
        .get();
    return snap.docs.map((d) {
      final campaignId = d.reference.parent.parent!.id;
      return _pledgeFromDoc(d, campaignId);
    }).toList();
  }

  Future<List<Campaign>> getDrafts({String? userEmail}) async {
    if (_dbOrNull == null) {
      final email = await _currentLocalEmail(override: userEmail);
      if (email == null) return [];
      final drafts = (await _readLocalCampaigns())
          .where(
            (campaign) =>
                campaign.status == 'draft' &&
                _isOwnedByUser(campaign, email: email),
          )
          .toList();
      _sortCampaignsByRecency(drafts);
      return drafts;
    }
    final uid = _uid;
    if (uid == null) return [];
    final snap = await _campaigns
        .where('creatorUid', isEqualTo: uid)
        .where('status', isEqualTo: 'draft')
        .get();
    final drafts = snap.docs.map(_fromDoc).toList();
    drafts.sort((a, b) {
      final aTime = a.lastEditedAt ?? a.createdAt;
      final bTime = b.lastEditedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    return drafts;
  }

  Future<Campaign?> getDraftById(String draftId) async {
    if (_dbOrNull == null) {
      final campaigns = await _readLocalCampaigns();
      final index = campaigns.indexWhere((campaign) => campaign.id == draftId);
      if (index == -1) return null;
      final campaign = campaigns[index];
      if (campaign.status != 'draft') return null;
      if (!_isOwnedByUser(campaign, email: await _currentLocalEmail())) {
        return null;
      }
      return campaign;
    }
    final snap = await _campaigns.doc(draftId).get();
    if (!snap.exists) return null;
    final campaign = _fromDoc(snap);
    if (campaign.status != 'draft') return null;
    if (!_isOwnedByUser(campaign)) return null;
    return campaign;
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> saveDraft(Campaign draft) async {
    if (_dbOrNull == null) {
      final localCampaigns = await _readLocalCampaigns();
      final saved = draft.copyWith(
        creatorEmail: draft.creatorEmail ?? await _currentLocalEmail(),
        creatorUid: draft.creatorUid ?? _uid,
        status: 'draft',
        lastEditedAt: DateTime.now(),
      );
      _upsertLocalCampaign(localCampaigns, saved);
      await _writeLocalCampaigns(localCampaigns);
      return;
    }
    final saved = draft.copyWith(
      creatorEmail: draft.creatorEmail ?? _email,
      creatorUid: draft.creatorUid ?? _uid,
      status: 'draft',
      lastEditedAt: DateTime.now(),
    );
    await _campaigns.doc(draft.id).set(saved.toFirestore());
  }

  Future<void> deleteDraft(String draftId) async {
    if (_dbOrNull == null) {
      final localCampaigns = await _readLocalCampaigns();
      final index = localCampaigns.indexWhere(
        (campaign) => campaign.id == draftId,
      );
      if (index == -1) return;
      final campaign = localCampaigns[index];
      if (campaign.status != 'draft' ||
          !_isOwnedByUser(campaign, email: await _currentLocalEmail())) {
        return;
      }
      localCampaigns.removeAt(index);
      await _writeLocalCampaigns(localCampaigns);
      return;
    }
    final snap = await _campaigns.doc(draftId).get();
    if (!snap.exists) return;
    final campaign = _fromDoc(snap);
    if (campaign.status != 'draft' || !_isOwnedByUser(campaign)) return;
    await _campaigns.doc(draftId).delete();
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
    required String gcashQrImage,
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
        gcashQrImage.isEmpty ||
        goalAmount <= 0 ||
        rewards.isEmpty) {
      throw Exception('All required fields must be filled.');
    }
    if (endDate.isBefore(DateTime.now())) {
      throw Exception('End date must be in the future.');
    }

    if (_dbOrNull == null) {
      final id =
          'c${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(9999)}';
      final campaign = Campaign(
        id: id,
        title: title,
        creatorName: creatorName,
        creatorEmail: await _currentLocalEmail(),
        creatorUid: _uid,
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
        gcashQrImage: gcashQrImage,
        productionTimeline: productionTimeline,
        warranty: warranty,
        spareParts: spareParts,
        risks: risks,
        safetyNotes: safetyNotes,
      );
      final localCampaigns = await _readLocalCampaigns();
      _upsertLocalCampaign(localCampaigns, campaign);
      await _writeLocalCampaigns(localCampaigns);
      return;
    }

    final id =
        'c${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(9999)}';
    final campaign = Campaign(
      id: id,
      title: title,
      creatorName: creatorName,
      creatorEmail: _email,
      creatorUid: _uid,
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
      gcashQrImage: gcashQrImage,
      productionTimeline: productionTimeline,
      warranty: warranty,
      spareParts: spareParts,
      risks: risks,
      safetyNotes: safetyNotes,
    );
    await _campaigns.doc(id).set(campaign.toFirestore());
  }

  /// Records a pledge atomically and increments the campaign counters
  /// (only when proof of payment is attached now — otherwise the pledge is
  /// recorded as pending and the backer can add proof later via
  /// [submitPledgeProof]).
  Future<void> backCampaign({
    required String campaignId,
    required int amount,
    String? rewardId,
    String? backerName,
    String? backerPhone,
    String? backerNote,
    String? proofImageUrl,
    String? proofReferenceNumber,
  }) async {
    if (amount <= 0) throw Exception('Amount must be greater than zero.');
    _assertAtMostOneProof(proofImageUrl, proofReferenceNumber);
    final hasProof =
        (proofImageUrl != null && proofImageUrl.trim().isNotEmpty) ||
        (proofReferenceNumber != null && proofReferenceNumber.trim().isNotEmpty);

    if (_dbOrNull == null) {
      await _backCampaignLocal(
        campaignId: campaignId,
        amount: amount,
        rewardId: rewardId,
        backerName: backerName,
        backerPhone: backerPhone,
        backerNote: backerNote,
        proofImageUrl: proofImageUrl,
        proofReferenceNumber: proofReferenceNumber,
      );
      return;
    }

    final uid = _uid;
    final email = _email;
    final displayName = _displayName;

    // Check for existing counted pledge outside the transaction (acceptable trade-off)
    final existingSnap = uid == null || !hasProof
        ? null
        : await _pledgesRef(campaignId)
            .where('backerUid', isEqualTo: uid)
            .where('countedInTotal', isEqualTo: true)
            .limit(1)
            .get();
    final isNewBacker = uid == null || (existingSnap?.docs.isEmpty ?? true);

    final pledgeId =
        'p${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(999)}';
    final campaignRef = _campaigns.doc(campaignId);
    final pledgeRef = _pledgesRef(campaignId).doc(pledgeId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(campaignRef);
      if (!snap.exists) throw Exception('Campaign not found.');
      final campaign = _fromDoc(snap);

      if (_isOwnedByUser(
        campaign,
        uid: uid,
        email: email,
        displayName: displayName,
      )) {
        throw Exception('You cannot support your own campaign.');
      }
      if (DateTime.now().isAfter(campaign.endDate)) {
        throw Exception('This campaign has already ended.');
      }
      if (campaign.gcashQrImage == null ||
          campaign.gcashQrImage!.trim().isEmpty) {
        throw Exception(
          'This campaign does not have a GCash QR payment photo yet.',
        );
      }
      RewardTier? selectedReward;
      if (rewardId != null && rewardId.trim().isNotEmpty) {
        for (final tier in campaign.rewards) {
          if (tier.id == rewardId) {
            selectedReward = tier;
            break;
          }
        }
        if (selectedReward == null) {
          throw Exception('Selected reward tier is no longer available.');
        }
        if (amount < selectedReward.minPledge) {
          throw Exception(
            'Amount is below the minimum pledge for this reward tier (${selectedReward.minPledge}).',
          );
        }
      }

      final pledge = Pledge(
        id: pledgeId,
        campaignId: campaignId,
        backerUid: uid,
        backerEmail: email,
        backerName: backerName?.trim().isNotEmpty == true
            ? backerName!.trim()
            : displayName,
        backerPhone: backerPhone?.trim().isNotEmpty == true
            ? backerPhone!.trim()
            : null,
        backerNote: backerNote?.trim().isNotEmpty == true
            ? backerNote!.trim()
            : null,
        amount: amount,
        rewardId: rewardId,
        createdAt: DateTime.now(),
        proofImageUrl: proofImageUrl,
        proofReferenceNumber: proofReferenceNumber,
        proofSubmittedAt: hasProof ? DateTime.now() : null,
        countedInTotal: hasProof,
      );

      if (hasProof) {
        tx.update(campaignRef, {
          'pledgedAmount': campaign.pledgedAmount + amount,
          'backersCount': isNewBacker
              ? campaign.backersCount + 1
              : campaign.backersCount,
        });
      }
      tx.set(pledgeRef, pledge.toFirestore());
    });
  }

  /// Attaches proof of payment to a previously created pending pledge and,
  /// if not already counted, adds its amount into the campaign totals.
  /// Idempotent — calling this again on an already-counted pledge is a no-op.
  Future<void> submitPledgeProof({
    required String campaignId,
    required String pledgeId,
    String? proofImageUrl,
    String? proofReferenceNumber,
  }) async {
    _assertAtMostOneProof(proofImageUrl, proofReferenceNumber);
    if ((proofImageUrl == null || proofImageUrl.trim().isEmpty) &&
        (proofReferenceNumber == null || proofReferenceNumber.trim().isEmpty)) {
      throw Exception('Magbigay ng larawan o reference number.');
    }

    if (_dbOrNull == null) {
      await _submitPledgeProofLocal(
        campaignId: campaignId,
        pledgeId: pledgeId,
        proofImageUrl: proofImageUrl,
        proofReferenceNumber: proofReferenceNumber,
      );
      return;
    }

    final uid = _uid;
    final campaignRef = _campaigns.doc(campaignId);
    final pledgeRef = _pledgesRef(campaignId).doc(pledgeId);

    // Preliminary, non-transactional read so we know the backer to check
    // for an existing counted pledge (Firestore transactions can only
    // `tx.get()` document references, not run queries) — the same
    // "acceptable trade-off" pattern backCampaign() uses.
    final preliminarySnap = await pledgeRef.get();
    if (!preliminarySnap.exists) throw Exception('Pledge not found.');
    final preliminaryPledge = _pledgeFromDoc(preliminarySnap, campaignId);
    if (preliminaryPledge.backerUid != null &&
        preliminaryPledge.backerUid != uid) {
      throw Exception('You cannot edit another supporter\'s pledge.');
    }
    final existingSnap = preliminaryPledge.backerUid == null
        ? null
        : await _pledgesRef(campaignId)
            .where('backerUid', isEqualTo: preliminaryPledge.backerUid)
            .where('countedInTotal', isEqualTo: true)
            .limit(1)
            .get();
    final isNewBacker =
        preliminaryPledge.backerUid == null ||
        (existingSnap?.docs.isEmpty ?? true);

    await _db.runTransaction((tx) async {
      final pledgeSnap = await tx.get(pledgeRef);
      if (!pledgeSnap.exists) throw Exception('Pledge not found.');
      final pledge = _pledgeFromDoc(pledgeSnap, campaignId);

      if (pledge.backerUid != null && pledge.backerUid != uid) {
        throw Exception('You cannot edit another supporter\'s pledge.');
      }
      if (pledge.countedInTotal) return;

      final campaignSnap = await tx.get(campaignRef);
      if (!campaignSnap.exists) throw Exception('Campaign not found.');
      final campaign = _fromDoc(campaignSnap);

      tx.update(pledgeRef, {
        'proofImageUrl': proofImageUrl,
        'proofReferenceNumber': proofReferenceNumber,
        'proofSubmittedAt': DateTime.now().toIso8601String(),
        'countedInTotal': true,
      });
      tx.update(campaignRef, {
        'pledgedAmount': campaign.pledgedAmount + pledge.amount,
        'backersCount': isNewBacker
            ? campaign.backersCount + 1
            : campaign.backersCount,
      });
    });
  }

  /// The current user's most recent pending (not-yet-counted) pledge on a
  /// specific campaign, if any — used to show a "submit proof" reminder.
  Future<Pledge?> getMyPledgeForCampaign(String campaignId) async {
    if (_dbOrNull == null) {
      final email = await _currentLocalEmail();
      if (email == null) return null;
      final pledges = (await _readLocalPledges())
          .where(
            (p) =>
                p.campaignId == campaignId &&
                p.backerEmail == email &&
                !p.countedInTotal,
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return pledges.isEmpty ? null : pledges.first;
    }
    final uid = _uid;
    if (uid == null) return null;
    final snap = await _pledgesRef(campaignId)
        .where('backerUid', isEqualTo: uid)
        .where('countedInTotal', isEqualTo: false)
        .get();
    if (snap.docs.isEmpty) return null;
    final pledges = snap.docs
        .map((d) => _pledgeFromDoc(d, campaignId))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return pledges.first;
  }

  /// All pledges for a specific campaign, newest first. Used by the
  /// admin/co-op backers view — deliberately not owner-gated the way
  /// [generateCampaignReport] is, since it only returns pledge records.
  Future<List<Pledge>> getPledgesForCampaign(String campaignId) async {
    if (_dbOrNull == null) {
      final pledges = (await _readLocalPledges())
          .where((p) => p.campaignId == campaignId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return pledges;
    }
    final snap = await _pledgesRef(campaignId).get();
    final pledges = snap.docs
        .map((d) => _pledgeFromDoc(d, campaignId))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return pledges;
  }

  Future<void> publishCampaign(Campaign campaign) async {
    final errors = validateForPublish(campaign);
    if (errors.isNotEmpty) {
      throw Exception('Cannot publish: ${errors.join(', ')}');
    }
    if (_dbOrNull == null) {
      await _publishCampaignLocal(campaign);
      return;
    }
    final now = DateTime.now();
    final published = campaign.copyWith(
      creatorEmail: campaign.creatorEmail ?? _email,
      creatorUid: campaign.creatorUid ?? _uid,
      status: 'live',
      publishedAt: now,
      lastEditedAt: now,
    );
    await _campaigns.doc(campaign.id).set(published.toFirestore());
  }

  // ── Report ────────────────────────────────────────────────────────────────

  Future<CampaignReport> generateCampaignReport({
    required String campaignId,
    String? userEmail,
  }) async {
    if (_dbOrNull == null) {
      return _generateCampaignReportLocal(
        campaignId: campaignId,
        userEmail: userEmail,
      );
    }
    return CampaignAnalyticsService(
      firestore: _db,
      auth: _auth,
    ).generateCampaignReport(campaignId: campaignId, userEmail: userEmail);
  }

  // ── Validation ────────────────────────────────────────────────────────────

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
    if (campaign.gcashQrImage == null ||
        campaign.gcashQrImage!.trim().isEmpty) {
      errors.add('Kailangan ang GCash QR photo para makatanggap ng bayad');
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
}
