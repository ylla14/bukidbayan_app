import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:bukidbayan_app/firebase_local_emulator.dart';
import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/models/payment_attempt.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

class CrowdfundingPaymentService {
  CrowdfundingPaymentService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    http.Client? httpClient,
    Uri Function(String functionName)? functionUriBuilder,
  }) : _firestoreOverride = firestore,
       _authOverride = auth,
       _httpOverride = httpClient,
       _functionUriBuilder = functionUriBuilder;

  static const String _functionsRegion = 'asia-southeast1';
  static const String _cancelAttemptFunctionName =
      'cancelCrowdfundingPaymentAttempt';

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;
  final http.Client? _httpOverride;
  final Uri Function(String functionName)? _functionUriBuilder;

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

  Uri _functionsUri(String functionName) {
    final uriOverride = _functionUriBuilder;
    if (uriOverride != null) {
      return uriOverride(functionName);
    }

    final projectId = Firebase.app().options.projectId;
    if (projectId.trim().isEmpty) {
      throw Exception('Firebase project is not configured.');
    }

    if (kUseFirebaseEmulators) {
      return Uri.http(
        '$firebaseEmulatorHost:$kFunctionsEmulatorPort',
        '$projectId/$_functionsRegion/$functionName',
      );
    }

    return Uri.https(
      '$_functionsRegion-$projectId.cloudfunctions.net',
      functionName,
    );
  }

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

  List<PaymentAttempt> _sortedAttemptsByCreatedAt(
    Iterable<PaymentAttempt> attempts,
  ) {
    final sorted = attempts.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  PaymentAttempt? _latestRecoverableAttempt(Iterable<PaymentAttempt> attempts) {
    final recoverable = attempts.where((attempt) => attempt.isActive);
    final sorted = _sortedAttemptsByCreatedAt(recoverable);
    return sorted.isEmpty ? null : sorted.first;
  }

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

      final attempts = _sortedAttemptsByCreatedAt(
        snap.docs.map((doc) => _attemptFromDoc(doc, campaignId)),
      );

      return attempts.first;
    });
  }

  Stream<PaymentAttempt?> watchRecoverableAttemptForCurrentUser({
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
      return _latestRecoverableAttempt(
        snap.docs.map((doc) => _attemptFromDoc(doc, campaignId)),
      );
    });
  }

  Future<PaymentAttempt?> getLatestAttemptForCurrentUser({
    required String campaignId,
  }) async {
    final uid = _uid;
    if (uid == null) {
      return null;
    }

    final snap = await _attemptsRef(
      campaignId,
    ).where('createdByUid', isEqualTo: uid).get();
    if (snap.docs.isEmpty) return null;

    final attempts = _sortedAttemptsByCreatedAt(
      snap.docs.map((doc) => _attemptFromDoc(doc, campaignId)),
    );
    return attempts.first;
  }

  Future<PaymentAttempt?> getRecoverableAttemptForCurrentUser({
    required String campaignId,
  }) async {
    final uid = _uid;
    if (uid == null) {
      return null;
    }

    final snap = await _attemptsRef(
      campaignId,
    ).where('createdByUid', isEqualTo: uid).get();
    if (snap.docs.isEmpty) return null;

    return _latestRecoverableAttempt(
      snap.docs.map((doc) => _attemptFromDoc(doc, campaignId)),
    );
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

  Future<bool> currentUserHasPaidPledge({required String campaignId}) async {
    final uid = _uid;
    if (uid == null) {
      return false;
    }

    return hasExistingPaidPledge(campaignId: campaignId, backerUid: uid);
  }

  Future<String?> cancelCheckoutAttempt({
    required String campaignId,
    required String attemptId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('You must be signed in to cancel this checkout.');
    }

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.trim().isEmpty) {
      throw Exception('Unable to verify your session. Please sign in again.');
    }

    final uri = _functionsUri(_cancelAttemptFunctionName);
    final response =
        await (_httpOverride?.post(
              uri,
              headers: {
                'Authorization': 'Bearer $idToken',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'attemptId': attemptId,
                'campaignId': campaignId,
              }),
            ) ??
            http.post(
              uri,
              headers: {
                'Authorization': 'Bearer $idToken',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'attemptId': attemptId,
                'campaignId': campaignId,
              }),
            ));

    Map<String, dynamic>? payload;
    if (response.body.trim().isNotEmpty) {
      try {
        payload = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        payload = null;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          payload?['error'] as String? ??
          'Unable to cancel the checkout attempt right now.';
      throw Exception(message);
    }

    return payload?['status'] as String?;
  }
}
