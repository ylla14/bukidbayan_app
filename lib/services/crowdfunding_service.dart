import 'dart:math';

import 'package:bukidbayan_app/models/campaign_report.dart';
import 'package:bukidbayan_app/models/campaign_support_summary.dart';
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

  String? _supporterKeyFromIdentity({String? uid, String? email}) {
    return CampaignSupportSummary.supporterKeyFromIdentity(
      uid: uid,
      email: email,
    );
  }

  String? _supporterKeyForPledge(Pledge pledge) {
    return CampaignSupportSummary.supporterKeyFromPledge(pledge);
  }

  bool _isCountedPledge(Pledge pledge) => pledge.isCountedContribution;

  RewardTier? _highestEligibleReward(List<RewardTier> rewards, int total) {
    return CampaignSupportSummary.highestEligibleReward(rewards, total);
  }

  String? _normalizeEmail(String? email) {
    final trimmed = email?.trim().toLowerCase();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  int _countedContributionTotal(List<Pledge> pledges) {
    return pledges
        .where(_isCountedPledge)
        .fold<int>(0, (total, pledge) => total + pledge.amount);
  }

  RewardTier? _rewardById(List<RewardTier> rewards, String rewardId) {
    for (final reward in rewards) {
      if (reward.id == rewardId) return reward;
    }
    return null;
  }

  Future<List<Pledge>> _getSupporterPledgesForCampaign(
    String campaignId, {
    String? supporterUid,
    String? supporterEmail,
  }) async {
    final uid = supporterUid?.trim();
    final email = _normalizeEmail(supporterEmail);
    final supporterKey = _supporterKeyFromIdentity(uid: uid, email: email);
    if (supporterKey == null) return [];

    if (_dbOrNull == null) {
      final localPledges = await _readLocalPledges();
      final pledges = localPledges.where((pledge) {
        return pledge.campaignId == campaignId &&
            _supporterKeyForPledge(pledge) == supporterKey;
      }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return pledges;
    }

    final deduped = <String, Pledge>{};

    Future<void> mergeQueryResults(Query<Map<String, dynamic>> query) async {
      final snap = await query.get();
      for (final doc in snap.docs) {
        deduped[doc.id] = _pledgeFromDoc(doc, campaignId);
      }
    }

    if (uid != null && uid.isNotEmpty) {
      await mergeQueryResults(
        _pledgesRef(campaignId).where('backerUid', isEqualTo: uid),
      );
    }
    if (email != null && email.isNotEmpty) {
      await mergeQueryResults(
        _pledgesRef(campaignId).where('backerEmail', isEqualTo: email),
      );
    }

    final pledges = deduped.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return pledges;
  }

  CampaignSupportSummary? _buildSupportSummary({
    required String campaignId,
    required List<RewardTier> rewards,
    required List<Pledge> pledges,
    String? supporterUid,
    String? supporterEmail,
  }) {
    return CampaignSupportSummary.build(
      campaignId: campaignId,
      rewards: rewards,
      pledges: pledges,
      supporterUid: supporterUid,
      supporterEmail: supporterEmail,
    );
  }

  Future<void> _syncSupporterRewardAssignment({
    required String campaignId,
    required List<RewardTier> rewards,
    String? supporterUid,
    String? supporterEmail,
  }) async {
    final pledges = await _getSupporterPledgesForCampaign(
      campaignId,
      supporterUid: supporterUid,
      supporterEmail: supporterEmail,
    );
    if (pledges.isEmpty) return;

    final summary = _buildSupportSummary(
      campaignId: campaignId,
      rewards: rewards,
      pledges: pledges,
      supporterUid: supporterUid,
      supporterEmail: supporterEmail,
    );
    if (summary == null) return;

    final carrier = pledges.where(_isCountedPledge).fold<Pledge?>(null, (
      latest,
      pledge,
    ) {
      if (latest == null || pledge.createdAt.isAfter(latest.createdAt)) {
        return pledge;
      }
      return latest;
    });

    final carrierRewardId = summary.activeReward?.id;

    if (_dbOrNull == null) {
      final localPledges = await _readLocalPledges();
      var didChange = false;

      for (var i = 0; i < localPledges.length; i++) {
        final pledge = localPledges[i];
        if (pledge.campaignId != campaignId ||
            _supporterKeyForPledge(pledge) != summary.supporterKey) {
          continue;
        }

        final nextRewardId = pledge.id == carrier?.id ? carrierRewardId : null;
        if (pledge.rewardId == nextRewardId) continue;
        localPledges[i] = pledge.copyWith(
          rewardId: nextRewardId,
          clearRewardId: nextRewardId == null,
        );
        didChange = true;
      }

      if (didChange) {
        await _writeLocalPledges(localPledges);
      }
      return;
    }

    final batch = _db.batch();
    var hasUpdates = false;

    for (final pledge in pledges) {
      final nextRewardId = pledge.id == carrier?.id ? carrierRewardId : null;
      if (pledge.rewardId == nextRewardId) continue;
      batch.update(_pledgesRef(campaignId).doc(pledge.id), {
        'rewardId': nextRewardId,
      });
      hasUpdates = true;
    }

    if (hasUpdates) {
      await batch.commit();
    }
  }

  Future<void> _sendCampaignContributionInvalidatedNotification({
    required String userId,
    required String campaignId,
    required String campaignTitle,
    required int amount,
    String? reason,
  }) async {
    if (_dbOrNull == null) return;

    final trimmedReason = reason?.trim();
    final body = trimmedReason != null && trimmedReason.isNotEmpty
        ? 'Ang pledge mong halagang PHP $amount para sa "$campaignTitle" ay minarkahang invalid. Dahilan: $trimmedReason Maaari kang magsumite muli ng bagong contribution kapag handa ka na.'
        : 'Ang pledge mong halagang PHP $amount para sa "$campaignTitle" ay minarkahang invalid. Maaari kang magsumite muli ng bagong contribution kapag handa ka na.';

    await _db.collection('notifications').doc(userId).collection('items').add({
      'type': 'campaign_contribution_invalidated',
      'title': 'Na-mark invalid ang campaign contribution mo',
      'body': body,
      'campaignId': campaignId,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  CampaignReport _buildCampaignReport({
    required Campaign campaign,
    required List<Pledge> campaignPledges,
  }) {
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
        (total, pledge) => total + pledge.amount,
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

  void _assertAtMostOneProof(
    String? proofImageUrl,
    String? proofReferenceNumber,
  ) {
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

    final supporterPledges = await _getSupporterPledgesForCampaign(
      campaignId,
      supporterUid: _uid,
      supporterEmail: email,
    );
    final currentCountedTotal = _countedContributionTotal(supporterPledges);
    final currentReward = _highestEligibleReward(
      campaign.rewards,
      currentCountedTotal,
    );
    final totalAfterContribution = currentCountedTotal + amount;

    RewardTier? selectedReward;
    if (rewardId != null && rewardId.trim().isNotEmpty) {
      selectedReward = _rewardById(campaign.rewards, rewardId);
      if (selectedReward == null) {
        throw Exception('Selected reward tier is no longer available.');
      }
      if (totalAfterContribution < selectedReward.minPledge) {
        throw Exception(
          'Total contribution would still be below the minimum pledge for this reward tier (${selectedReward.minPledge}).',
        );
      }
      if (currentReward != null &&
          selectedReward.minPledge < currentReward.minPledge) {
        throw Exception(
          'You already unlocked a higher benefit for this campaign.',
        );
      }
    }

    final hasProof =
        (proofImageUrl != null && proofImageUrl.trim().isNotEmpty) ||
        (proofReferenceNumber != null &&
            proofReferenceNumber.trim().isNotEmpty);
    final hasOpenPendingPledge = supporterPledges.any(
      (pledge) => pledge.isPendingProof,
    );
    if (!hasProof && hasOpenPendingPledge) {
      throw Exception(
        'May naka-pending ka pang pledge sa campaign na ito. Kumpletuhin o kanselahin muna iyon bago gumawa ng panibagong pay-later pledge.',
      );
    }

    final pledges = await _readLocalPledges();
    final isNewBacker = !supporterPledges.any(_isCountedPledge);
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
      rewardId: null,
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
    if (hasProof) {
      await _syncSupporterRewardAssignment(
        campaignId: campaignId,
        rewards: campaign.rewards,
        supporterUid: _uid,
        supporterEmail: email,
      );
    }
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
    if (pledge.isInvalidated) {
      throw Exception(
        'This pledge was marked invalid and can no longer be completed.',
      );
    }
    if (pledge.isCanceled) {
      throw Exception(
        'This pending pledge was canceled and can no longer be completed.',
      );
    }
    if (pledge.countedInTotal) return;

    final campaign = campaigns[campaignIndex];
    final supporterPledges = await _getSupporterPledgesForCampaign(
      campaignId,
      supporterUid: pledge.backerUid,
      supporterEmail: pledge.backerEmail,
    );
    final isNewBacker = !supporterPledges.any(
      (existing) => existing.id != pledgeId && _isCountedPledge(existing),
    );

    pledges[pledgeIndex] = pledge.copyWith(
      proofImageUrl: proofImageUrl,
      proofReferenceNumber: proofReferenceNumber,
      proofSubmittedAt: DateTime.now(),
      clearRewardId: true,
      clearInvalidation: true,
      clearCancellation: true,
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
    await _syncSupporterRewardAssignment(
      campaignId: campaignId,
      rewards: campaign.rewards,
      supporterUid: pledge.backerUid,
      supporterEmail: pledge.backerEmail,
    );
  }

  Future<void> _invalidatePledgeLocal({
    required String campaignId,
    required String pledgeId,
    String? reason,
  }) async {
    final campaigns = await _readLocalCampaigns();
    final campaignIndex = campaigns.indexWhere(
      (campaign) => campaign.id == campaignId,
    );
    if (campaignIndex == -1) throw Exception('Campaign not found.');

    final campaign = campaigns[campaignIndex];
    if (!_isOwnedByUser(campaign, email: await _currentLocalEmail())) {
      throw Exception('Only the campaign owner can invalidate contributions.');
    }

    final pledges = await _readLocalPledges();
    final pledgeIndex = pledges.indexWhere(
      (pledge) => pledge.campaignId == campaignId && pledge.id == pledgeId,
    );
    if (pledgeIndex == -1) throw Exception('Pledge not found.');

    final pledge = pledges[pledgeIndex];
    if (pledge.isInvalidated) return;
    if (!pledge.isCountedContribution) {
      throw Exception('Only counted contributions can be invalidated.');
    }

    final supporterPledges = await _getSupporterPledgesForCampaign(
      campaignId,
      supporterUid: pledge.backerUid,
      supporterEmail: pledge.backerEmail,
    );
    final hasOtherCounted = supporterPledges.any(
      (existing) => existing.id != pledge.id && _isCountedPledge(existing),
    );

    pledges[pledgeIndex] = pledge.copyWith(
      invalidatedAt: DateTime.now(),
      invalidatedByUid: _uid,
      invalidatedByName: _displayName,
      invalidationReason: reason?.trim(),
      clearRewardId: true,
      countedInTotal: false,
    );
    campaigns[campaignIndex] = campaign.copyWith(
      pledgedAmount: max(0, campaign.pledgedAmount - pledge.amount),
      backersCount: hasOtherCounted
          ? campaign.backersCount
          : max(0, campaign.backersCount - 1),
    );

    await _writeLocalCampaigns(campaigns);
    await _writeLocalPledges(pledges);
    await _syncSupporterRewardAssignment(
      campaignId: campaignId,
      rewards: campaign.rewards,
      supporterUid: pledge.backerUid,
      supporterEmail: pledge.backerEmail,
    );
  }

  Future<void> _cancelPendingPledgeLocal({
    required String campaignId,
    required String pledgeId,
  }) async {
    final pledges = await _readLocalPledges();
    final pledgeIndex = pledges.indexWhere(
      (pledge) => pledge.campaignId == campaignId && pledge.id == pledgeId,
    );
    if (pledgeIndex == -1) throw Exception('Pledge not found.');

    final pledge = pledges[pledgeIndex];
    final email = await _currentLocalEmail();
    if (pledge.backerEmail != null && pledge.backerEmail != email) {
      throw Exception('You cannot cancel another supporter\'s pledge.');
    }
    if (pledge.isCanceled) return;
    if (!pledge.isPendingProof) {
      throw Exception('Only pending pledges can be canceled.');
    }

    pledges[pledgeIndex] = pledge.copyWith(
      canceledAt: DateTime.now(),
      canceledByUid: _uid,
      clearRewardId: true,
      countedInTotal: false,
    );
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
        (proofReferenceNumber != null &&
            proofReferenceNumber.trim().isNotEmpty);

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
    final campaignRef = _campaigns.doc(campaignId);
    final preliminaryCampaignSnap = await campaignRef.get();
    if (!preliminaryCampaignSnap.exists) throw Exception('Campaign not found.');
    final preliminaryCampaign = _fromDoc(preliminaryCampaignSnap);
    final supporterPledges = await _getSupporterPledgesForCampaign(
      campaignId,
      supporterUid: uid,
      supporterEmail: email,
    );
    final hasOpenPendingPledge = supporterPledges.any(
      (pledge) => pledge.isPendingProof,
    );
    final currentCountedTotal = _countedContributionTotal(supporterPledges);
    final currentReward = _highestEligibleReward(
      preliminaryCampaign.rewards,
      currentCountedTotal,
    );
    final totalAfterContribution = currentCountedTotal + amount;
    final selectedReward = rewardId == null || rewardId.trim().isEmpty
        ? null
        : _rewardById(preliminaryCampaign.rewards, rewardId);

    if (rewardId != null &&
        rewardId.trim().isNotEmpty &&
        selectedReward == null) {
      throw Exception('Selected reward tier is no longer available.');
    }
    if (selectedReward != null &&
        totalAfterContribution < selectedReward.minPledge) {
      throw Exception(
        'Total contribution would still be below the minimum pledge for this reward tier (${selectedReward.minPledge}).',
      );
    }
    if (currentReward != null &&
        selectedReward != null &&
        selectedReward.minPledge < currentReward.minPledge) {
      throw Exception(
        'You already unlocked a higher benefit for this campaign.',
      );
    }
    if (!hasProof && hasOpenPendingPledge) {
      throw Exception(
        'May naka-pending ka pang pledge sa campaign na ito. Kumpletuhin o kanselahin muna iyon bago gumawa ng panibagong pay-later pledge.',
      );
    }

    final isNewBacker = !supporterPledges.any(_isCountedPledge);

    final pledgeId =
        'p${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(999)}';
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
      final liveSelectedReward = rewardId == null || rewardId.trim().isEmpty
          ? null
          : _rewardById(campaign.rewards, rewardId);
      if (rewardId != null &&
          rewardId.trim().isNotEmpty &&
          liveSelectedReward == null) {
        throw Exception('Selected reward tier is no longer available.');
      }
      if (liveSelectedReward != null &&
          currentReward != null &&
          liveSelectedReward.minPledge < currentReward.minPledge) {
        throw Exception(
          'You already unlocked a higher benefit for this campaign.',
        );
      }
      if (liveSelectedReward != null &&
          totalAfterContribution < liveSelectedReward.minPledge) {
        throw Exception(
          'Total contribution would still be below the minimum pledge for this reward tier (${liveSelectedReward.minPledge}).',
        );
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
        rewardId: null,
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

    if (hasProof) {
      await _syncSupporterRewardAssignment(
        campaignId: campaignId,
        rewards: preliminaryCampaign.rewards,
        supporterUid: uid,
        supporterEmail: email,
      );
    }
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
    if (preliminaryPledge.isInvalidated) {
      throw Exception(
        'This pledge was marked invalid and can no longer be completed.',
      );
    }
    if (preliminaryPledge.isCanceled) {
      throw Exception(
        'This pending pledge was canceled and can no longer be completed.',
      );
    }
    final supporterPledges = await _getSupporterPledgesForCampaign(
      campaignId,
      supporterUid: preliminaryPledge.backerUid,
      supporterEmail: preliminaryPledge.backerEmail,
    );
    final isNewBacker = !supporterPledges.any(
      (pledge) => pledge.id != preliminaryPledge.id && _isCountedPledge(pledge),
    );
    final campaignSnap = await campaignRef.get();
    if (!campaignSnap.exists) throw Exception('Campaign not found.');
    final campaign = _fromDoc(campaignSnap);

    await _db.runTransaction((tx) async {
      final pledgeSnap = await tx.get(pledgeRef);
      if (!pledgeSnap.exists) throw Exception('Pledge not found.');
      final pledge = _pledgeFromDoc(pledgeSnap, campaignId);

      if (pledge.backerUid != null && pledge.backerUid != uid) {
        throw Exception('You cannot edit another supporter\'s pledge.');
      }
      if (pledge.isInvalidated) {
        throw Exception(
          'This pledge was marked invalid and can no longer be completed.',
        );
      }
      if (pledge.isCanceled) {
        throw Exception(
          'This pending pledge was canceled and can no longer be completed.',
        );
      }
      if (pledge.countedInTotal) return;

      final liveCampaignSnap = await tx.get(campaignRef);
      if (!liveCampaignSnap.exists) throw Exception('Campaign not found.');
      final liveCampaign = _fromDoc(liveCampaignSnap);

      tx.update(pledgeRef, {
        'proofImageUrl': proofImageUrl,
        'proofReferenceNumber': proofReferenceNumber,
        'proofSubmittedAt': DateTime.now().toIso8601String(),
        'invalidatedAt': null,
        'invalidatedByUid': null,
        'invalidatedByName': null,
        'invalidationReason': null,
        'canceledAt': null,
        'canceledByUid': null,
        'rewardId': null,
        'countedInTotal': true,
      });
      tx.update(campaignRef, {
        'pledgedAmount': liveCampaign.pledgedAmount + pledge.amount,
        'backersCount': isNewBacker
            ? liveCampaign.backersCount + 1
            : liveCampaign.backersCount,
      });
    });

    await _syncSupporterRewardAssignment(
      campaignId: campaignId,
      rewards: campaign.rewards,
      supporterUid: preliminaryPledge.backerUid,
      supporterEmail: preliminaryPledge.backerEmail,
    );
  }

  Future<List<Pledge>> getMyPendingPledgesForCampaign(String campaignId) async {
    if (_dbOrNull == null) {
      final email = await _currentLocalEmail();
      if (email == null) return [];
      final pledges =
          (await _readLocalPledges())
              .where(
                (p) =>
                    p.campaignId == campaignId &&
                    p.backerEmail == email &&
                    p.isPendingProof,
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return pledges;
    }
    final uid = _uid;
    if (uid == null) return [];
    final snap = await _pledgesRef(campaignId)
        .where('backerUid', isEqualTo: uid)
        .where('countedInTotal', isEqualTo: false)
        .get();
    final pledges =
        snap.docs
            .map((d) => _pledgeFromDoc(d, campaignId))
            .where((pledge) => pledge.isPendingProof)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return pledges;
  }

  /// The current user's most recent pending (not-yet-counted) pledge on a
  /// specific campaign, if any — used to show a "submit proof" reminder.
  Future<Pledge?> getMyPledgeForCampaign(String campaignId) async {
    final pledges = await getMyPendingPledgesForCampaign(campaignId);
    return pledges.isEmpty ? null : pledges.first;
  }

  Future<CampaignSupportSummary?> getMySupportSummary(String campaignId) async {
    final campaign = await getCampaignById(campaignId);
    if (campaign == null) return null;

    final supporterUid = _uid;
    final supporterEmail = _dbOrNull == null
        ? await _currentLocalEmail()
        : _email;
    final pledges = await _getSupporterPledgesForCampaign(
      campaignId,
      supporterUid: supporterUid,
      supporterEmail: supporterEmail,
    );

    return _buildSupportSummary(
      campaignId: campaignId,
      rewards: campaign.rewards,
      pledges: pledges,
      supporterUid: supporterUid,
      supporterEmail: supporterEmail,
    );
  }

  Future<void> invalidateContribution({
    required String campaignId,
    required String pledgeId,
    String? reason,
  }) async {
    if (_dbOrNull == null) {
      await _invalidatePledgeLocal(
        campaignId: campaignId,
        pledgeId: pledgeId,
        reason: reason,
      );
      return;
    }

    final campaignRef = _campaigns.doc(campaignId);
    final pledgeRef = _pledgesRef(campaignId).doc(pledgeId);
    final campaignSnap = await campaignRef.get();
    if (!campaignSnap.exists) throw Exception('Campaign not found.');
    final campaign = _fromDoc(campaignSnap);

    if (!_isOwnedByUser(campaign)) {
      throw Exception('Only the campaign owner can invalidate contributions.');
    }

    final pledgeSnap = await pledgeRef.get();
    if (!pledgeSnap.exists) throw Exception('Pledge not found.');
    final pledge = _pledgeFromDoc(pledgeSnap, campaignId);
    if (pledge.isInvalidated) return;
    if (!pledge.isCountedContribution) {
      throw Exception('Only counted contributions can be invalidated.');
    }

    final supporterPledges = await _getSupporterPledgesForCampaign(
      campaignId,
      supporterUid: pledge.backerUid,
      supporterEmail: pledge.backerEmail,
    );
    final hasOtherCounted = supporterPledges.any(
      (existing) => existing.id != pledge.id && _isCountedPledge(existing),
    );
    final invalidatedAt = DateTime.now().toIso8601String();
    final trimmedReason = reason?.trim();

    await _db.runTransaction((tx) async {
      final liveCampaignSnap = await tx.get(campaignRef);
      if (!liveCampaignSnap.exists) throw Exception('Campaign not found.');
      final liveCampaign = _fromDoc(liveCampaignSnap);

      final livePledgeSnap = await tx.get(pledgeRef);
      if (!livePledgeSnap.exists) throw Exception('Pledge not found.');
      final livePledge = _pledgeFromDoc(livePledgeSnap, campaignId);
      if (livePledge.isInvalidated) return;
      if (!livePledge.isCountedContribution) {
        throw Exception('Only counted contributions can be invalidated.');
      }

      tx.update(pledgeRef, {
        'countedInTotal': false,
        'rewardId': null,
        'invalidatedAt': invalidatedAt,
        'invalidatedByUid': _uid,
        'invalidatedByName': _displayName,
        'invalidationReason': trimmedReason,
      });
      tx.update(campaignRef, {
        'pledgedAmount': max(0, liveCampaign.pledgedAmount - livePledge.amount),
        'backersCount': hasOtherCounted
            ? liveCampaign.backersCount
            : max(0, liveCampaign.backersCount - 1),
      });
    });

    await _syncSupporterRewardAssignment(
      campaignId: campaignId,
      rewards: campaign.rewards,
      supporterUid: pledge.backerUid,
      supporterEmail: pledge.backerEmail,
    );

    if (pledge.backerUid != null && pledge.backerUid!.trim().isNotEmpty) {
      await _sendCampaignContributionInvalidatedNotification(
        userId: pledge.backerUid!.trim(),
        campaignId: campaignId,
        campaignTitle: campaign.title,
        amount: pledge.amount,
        reason: trimmedReason,
      );
    }
  }

  Future<void> cancelPendingPledge({
    required String campaignId,
    required String pledgeId,
  }) async {
    if (_dbOrNull == null) {
      await _cancelPendingPledgeLocal(
        campaignId: campaignId,
        pledgeId: pledgeId,
      );
      return;
    }

    final uid = _uid;
    final email = _email;
    final pledgeRef = _pledgesRef(campaignId).doc(pledgeId);
    final preliminarySnap = await pledgeRef.get();
    if (!preliminarySnap.exists) throw Exception('Pledge not found.');
    final preliminaryPledge = _pledgeFromDoc(preliminarySnap, campaignId);

    final belongsToCurrentUser = preliminaryPledge.backerUid != null
        ? preliminaryPledge.backerUid == uid
        : preliminaryPledge.backerEmail == email;
    if (!belongsToCurrentUser) {
      throw Exception('You cannot cancel another supporter\'s pledge.');
    }
    if (preliminaryPledge.isCanceled) return;
    if (!preliminaryPledge.isPendingProof) {
      throw Exception('Only pending pledges can be canceled.');
    }

    await pledgeRef.update({
      'canceledAt': DateTime.now().toIso8601String(),
      'canceledByUid': uid,
      'rewardId': null,
      'countedInTotal': false,
    });
  }

  /// All pledges for a specific campaign, newest first. Used by the
  /// admin/co-op backers view — deliberately not owner-gated the way
  /// [generateCampaignReport] is, since it only returns pledge records.
  Future<List<Pledge>> getPledgesForCampaign(String campaignId) async {
    if (_dbOrNull == null) {
      final pledges =
          (await _readLocalPledges())
              .where((p) => p.campaignId == campaignId)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return pledges;
    }
    final snap = await _pledgesRef(campaignId).get();
    final pledges = snap.docs.map((d) => _pledgeFromDoc(d, campaignId)).toList()
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
