import 'dart:async';
import 'dart:math';

import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/models/payment_attempt.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CrowdfundingPaymentService {
  CrowdfundingPaymentService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreOverride = firestore,
      _authOverride = auth;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _campaigns =>
      _db.collection('campaigns');

  CollectionReference<Map<String, dynamic>> _attemptsRef(String campaignId) =>
      _campaigns.doc(campaignId).collection('payment_attempts');

  CollectionReference<Map<String, dynamic>> _pledgesRef(String campaignId) =>
      _campaigns.doc(campaignId).collection('pledges');

  String? get _uid => _auth.currentUser?.uid;
  String? get _email => _auth.currentUser?.email;
  String? get _displayName => _auth.currentUser?.displayName;

  Campaign _campaignFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Campaign.fromJson({...doc.data()!, 'id': doc.id});

  PaymentAttempt _attemptFromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String campaignId,
  ) => PaymentAttempt.fromJson({
    ...doc.data()!,
    'id': doc.id,
    'campaignId': campaignId,
  });

  bool _isOwnedByUser(Campaign campaign) {
    if (_uid != null && campaign.creatorUid == _uid) return true;
    if (_email != null && campaign.creatorEmail == _email) return true;
    if ((campaign.creatorEmail == null || campaign.creatorEmail!.isEmpty) &&
        _displayName != null &&
        _displayName!.isNotEmpty &&
        campaign.creatorName == _displayName) {
      return true;
    }
    return false;
  }

  Future<Campaign> _loadAndValidateCampaign({
    required String campaignId,
    required int amount,
    String? rewardId,
  }) async {
    final snap = await _campaigns.doc(campaignId).get();
    if (!snap.exists) {
      throw Exception('Campaign not found.');
    }

    final campaign = _campaignFromDoc(snap);
    if (_isOwnedByUser(campaign)) {
      throw Exception('You cannot support your own campaign.');
    }
    if (campaign.status.startsWith('ended') ||
        DateTime.now().isAfter(campaign.endDate)) {
      throw Exception('This campaign has already ended.');
    }
    if (amount <= 0) {
      throw Exception('Amount must be greater than zero.');
    }
    if (rewardId != null && rewardId.trim().isNotEmpty) {
      RewardTier? selectedReward;
      for (final reward in campaign.rewards) {
        if (reward.id == rewardId) {
          selectedReward = reward;
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

    return campaign;
  }

  Future<PaymentAttempt> createCheckoutAttempt({
    required String campaignId,
    required int amount,
    required String donorName,
    String? rewardId,
    String? donorPhone,
    String? donorNote,
    String provider = PaymentProvider.payMongoCheckout,
    List<String> paymentMethodTypes = const ['qrph'],
  }) async {
    final uid = _uid;
    if (uid == null) {
      throw Exception('You must be signed in to support a campaign.');
    }

    final trimmedName = donorName.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Supporter name is required.');
    }

    final campaign = await _loadAndValidateCampaign(
      campaignId: campaignId,
      amount: amount,
      rewardId: rewardId,
    );

    final now = DateTime.now();
    final attemptId = 'pa${now.millisecondsSinceEpoch}${Random().nextInt(999)}';
    final attempt = PaymentAttempt(
      id: attemptId,
      campaignId: campaignId,
      createdByUid: uid,
      createdByEmail: _email,
      donorName: trimmedName,
      donorPhone: donorPhone?.trim().isNotEmpty == true
          ? donorPhone!.trim()
          : null,
      donorNote: donorNote?.trim().isNotEmpty == true
          ? donorNote!.trim()
          : null,
      rewardId: rewardId,
      amount: amount,
      provider: provider,
      paymentMethodTypes: paymentMethodTypes,
      status: PaymentAttemptStatus.created,
      createdAt: now,
      updatedAt: now,
      metadata: {
        'campaignTitle': campaign.title,
        'campaignOwner': campaign.creatorName,
      },
    );

    await _attemptsRef(campaignId).doc(attemptId).set(attempt.toFirestore());
    return attempt;
  }

  Future<PaymentAttempt?> getPaymentAttempt({
    required String campaignId,
    required String attemptId,
  }) async {
    final snap = await _attemptsRef(campaignId).doc(attemptId).get();
    if (!snap.exists) return null;
    return _attemptFromDoc(snap, campaignId);
  }

  Stream<PaymentAttempt?> watchPaymentAttempt({
    required String campaignId,
    required String attemptId,
  }) {
    return _attemptsRef(campaignId).doc(attemptId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return _attemptFromDoc(snap, campaignId);
    });
  }

  Stream<PaymentAttempt?> watchLatestAttemptForCurrentUser({
    required String campaignId,
  }) {
    final uid = _uid;
    if (uid == null) {
      return Stream.value(null);
    }

    return _attemptsRef(
      campaignId,
    ).where('createdByUid', isEqualTo: uid).snapshots().map((snap) {
      if (snap.docs.isEmpty) return null;

      final attempts =
          snap.docs.map((doc) => _attemptFromDoc(doc, campaignId)).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return attempts.first;
    });
  }

  Future<PaymentAttempt> waitForCheckoutReady({
    required String campaignId,
    required String attemptId,
    Duration timeout = const Duration(seconds: 45),
    Duration pollInterval = const Duration(seconds: 1),
  }) async {
    final deadline = DateTime.now().add(timeout);
    PaymentAttempt? latestAttempt;

    while (DateTime.now().isBefore(deadline)) {
      latestAttempt = await getPaymentAttempt(
        campaignId: campaignId,
        attemptId: attemptId,
      );

      if (latestAttempt == null) {
        throw Exception('Payment attempt was not found.');
      }

      if (latestAttempt.providerCheckoutUrl?.trim().isNotEmpty == true) {
        return latestAttempt;
      }

      if (latestAttempt.isTerminal) {
        return latestAttempt;
      }

      await Future.delayed(pollInterval);
    }

    throw Exception(
      latestAttempt?.failureReason ??
          'Timed out while preparing the secure checkout session.',
    );
  }

  Future<bool> hasExistingPaidPledge({
    required String campaignId,
    required String backerUid,
  }) async {
    final existingSnap = await _pledgesRef(
      campaignId,
    ).where('backerUid', isEqualTo: backerUid).limit(1).get();
    return existingSnap.docs.isNotEmpty;
  }
}
