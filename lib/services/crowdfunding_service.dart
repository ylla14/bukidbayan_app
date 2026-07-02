import 'dart:math';
import 'package:bukidbayan_app/firebase_local_emulator.dart';
import 'package:bukidbayan_app/models/campaign_report.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bukidbayan_app/models/campaign.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CrowdfundingService {
  CrowdfundingService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreOverride = firestore,
      _authOverride = auth;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;
  static const Set<String> _seedCampaignIds = {'c1', 'c2', 'c3', 'c4'};

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _campaigns =>
      _db.collection('campaigns');

  CollectionReference<Map<String, dynamic>> _pledgesRef(String campaignId) =>
      _campaigns.doc(campaignId).collection('pledges');

  String? get _uid => _auth.currentUser?.uid;
  String? get _email => _auth.currentUser?.email;
  String? get _displayName => _auth.currentUser?.displayName;

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

  // ── Seed ─────────────────────────────────────────────────────────────────

  /// Seeds demo campaigns into Firestore if they don't already exist.
  Future<void> seedIfEmpty() async {
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
    final snap = await _campaigns
        .where('status', whereIn: ['live', 'ended_success', 'ended_fail'])
        .get();
    return snap.docs
        .map(_fromDoc)
        .where(
          (campaign) =>
              includeSeedCrowdfundingCampaigns ||
              !_seedCampaignIds.contains(campaign.id),
        )
        .toList();
  }

  /// Fetches a single campaign by ID. Drafts are only returned to their owner.
  Future<Campaign?> getCampaignById(String id) async {
    final snap = await _campaigns.doc(id).get();
    if (!snap.exists) return null;
    final campaign = _fromDoc(snap);
    if (campaign.status == 'draft' && !_isOwnedByUser(campaign)) return null;
    return campaign;
  }

  Future<String?> getCurrentUserEmail() async => _email;

  /// Returns all campaigns (any status) owned by the current user.
  Future<List<Campaign>> getMyCampaigns({
    String? userEmail,
    String? status,
  }) async {
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
    final snap = await _campaigns.doc(draftId).get();
    if (!snap.exists) return null;
    final campaign = _fromDoc(snap);
    if (campaign.status != 'draft') return null;
    if (!_isOwnedByUser(campaign)) return null;
    return campaign;
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> saveDraft(Campaign draft) async {
    final saved = draft.copyWith(
      creatorEmail: draft.creatorEmail ?? _email,
      creatorUid: draft.creatorUid ?? _uid,
      status: 'draft',
      lastEditedAt: DateTime.now(),
    );
    await _campaigns.doc(draft.id).set(saved.toFirestore());
  }

  Future<void> deleteDraft(String draftId) async {
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
      productionTimeline: productionTimeline,
      warranty: warranty,
      spareParts: spareParts,
      risks: risks,
      safetyNotes: safetyNotes,
    );
    await _campaigns.doc(id).set(campaign.toFirestore());
  }

  /// Records a pledge atomically and increments the campaign counters.
  Future<void> backCampaign({
    required String campaignId,
    required int amount,
    String? rewardId,
    String? backerName,
    String? backerPhone,
    String? backerNote,
  }) async {
    if (amount <= 0) throw Exception('Amount must be greater than zero.');

    final uid = _uid;
    final email = _email;
    final displayName = _displayName;

    // Check for existing pledge outside the transaction (acceptable trade-off)
    final existingSnap = uid == null
        ? null
        : await _pledgesRef(
            campaignId,
          ).where('backerUid', isEqualTo: uid).limit(1).get();
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
      );

      tx.update(campaignRef, {
        'pledgedAmount': campaign.pledgedAmount + amount,
        'backersCount': isNewBacker
            ? campaign.backersCount + 1
            : campaign.backersCount,
      });
      tx.set(pledgeRef, pledge.toFirestore());
    });
  }

  Future<void> publishCampaign(Campaign campaign) async {
    final errors = validateForPublish(campaign);
    if (errors.isNotEmpty) {
      throw Exception('Cannot publish: ${errors.join(', ')}');
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
    final snap = await _campaigns.doc(campaignId).get();
    if (!snap.exists) throw Exception('Campaign not found.');
    final campaign = _fromDoc(snap);

    if (!_isOwnedByUser(campaign, email: userEmail)) {
      throw Exception(
        'Only the campaign owner can generate a report for this campaign.',
      );
    }
    final isEnded = _isCampaignEnded(campaign);

    final pledgesSnap = await _pledgesRef(
      campaignId,
    ).orderBy('createdAt').get();
    final campaignPledges = pledgesSnap.docs
        .map((d) => _pledgeFromDoc(d, campaignId))
        .toList();

    final pledgeAmountTotal = campaignPledges.fold<int>(
      0,
      (s, p) => s + p.amount,
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
      final related = campaignPledges.where((p) => p.rewardId == tier.id);
      return CampaignRewardReportItem(
        rewardTier: tier,
        pledgeCount: related.length,
        totalAmount: related.fold<int>(0, (s, p) => s + p.amount),
      );
    }).toList();

    final noRewardPledges = campaignPledges
        .where((p) => p.rewardId == null || p.rewardId!.trim().isEmpty)
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
      rewardBreakdown: rewardBreakdown,
      noRewardPledgeCount: noRewardPledges.length,
      noRewardAmount: noRewardPledges.fold<int>(0, (s, p) => s + p.amount),
    );
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
