import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/models/payment_attempt.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

const _kPayMongoBase = 'https://api.paymongo.com';
// Injected at build time via --dart-define=PAYMONGO_SECRET_KEY=sk_test_...
// Never commit the actual key value here.
const _kPayMongoSecretKey = String.fromEnvironment('PAYMONGO_SECRET_KEY');

// Firebase Hosting URL where paymongo-return.html is served.
const _kReturnBase =
    'https://bukidbayan-capstoners.web.app/paymongo-return.html';

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

  // ── PayMongo API ────────────────────────────────────────────────────────────

  String get _authHeader =>
      'Basic ${base64Encode(utf8.encode('$_kPayMongoSecretKey:'))}';

  Future<({String checkoutId, String checkoutUrl, bool livemode})>
  _createPayMongoSession({
    required PaymentAttempt attempt,
    required Campaign campaign,
  }) async {
    final reward = attempt.rewardId != null
        ? campaign.rewards
              .where((r) => r.id == attempt.rewardId)
              .firstOrNull
        : null;

    final successUrl =
        '$_kReturnBase?paymentStatus=success'
        '&campaignId=${campaign.id}&attemptId=${attempt.id}';
    final cancelUrl =
        '$_kReturnBase?paymentStatus=cancelled'
        '&campaignId=${campaign.id}&attemptId=${attempt.id}';

    final payload = {
      'data': {
        'attributes': {
          'billing': {
            'email': attempt.createdByEmail ?? '',
            'name': attempt.donorName,
            if (attempt.donorPhone != null && attempt.donorPhone!.isNotEmpty)
              'phone': attempt.donorPhone,
          },
          'cancel_url': cancelUrl,
          'success_url': successUrl,
          'description': campaign.shortBlurb.isNotEmpty
              ? campaign.shortBlurb
              : campaign.title,
          'line_items': [
            {
              'amount': attempt.amount * 100,
              'currency': 'PHP',
              'description': reward?.title ??
                  (campaign.shortBlurb.isNotEmpty
                      ? campaign.shortBlurb
                      : campaign.title),
              'images': (campaign.isAssetImage || campaign.image.isEmpty)
                  ? <String>[]
                  : [campaign.image],
              'name': campaign.title,
              'quantity': 1,
            },
          ],
          'metadata': {
            'campaign_id': campaign.id,
            'payment_attempt_id': attempt.id,
          },
          'payment_method_types': attempt.paymentMethodTypes.isNotEmpty
              ? attempt.paymentMethodTypes
              : ['qrph'],
          'reference_number': attempt.id,
          'send_email_receipt': false,
          'show_description': true,
          'show_line_items': true,
        },
      },
    };

    final response = await http.post(
      Uri.parse('$_kPayMongoBase/v2/checkout_sessions'),
      headers: {
        'Authorization': _authHeader,
        'Content-Type': 'application/json',
        'Idempotency-Key': attempt.id,
      },
      body: jsonEncode(payload),
    );

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200 && response.statusCode != 201) {
      final errors = (json['errors'] as List?) ?? [];
      final msg = errors.isNotEmpty
          ? ((errors.first as Map<String, dynamic>)['detail'] as String? ??
                'Hindi nagawa ang checkout session.')
          : 'Hindi nagawa ang checkout session.';
      throw Exception(msg);
    }

    final data = json['data'] as Map<String, dynamic>;
    final attrs = data['attributes'] as Map<String, dynamic>;
    return (
      checkoutId: data['id'] as String,
      checkoutUrl: attrs['checkout_url'] as String,
      livemode: attrs['livemode'] as bool? ?? false,
    );
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Creates a payment attempt in Firestore and immediately calls PayMongo to
  /// get the checkout URL. Returns the attempt with [providerCheckoutUrl] set.
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

    // 1. Write attempt to Firestore first so it exists before the API call.
    await _attemptsRef(campaignId).doc(attemptId).set(attempt.toFirestore());

    // 2. Call PayMongo directly to create the checkout session.
    late final ({String checkoutId, String checkoutUrl, bool livemode}) session;
    try {
      session = await _createPayMongoSession(attempt: attempt, campaign: campaign);
    } catch (e) {
      await _attemptsRef(campaignId).doc(attemptId).update({
        'status': PaymentAttemptStatus.failed,
        'failureReason': e.toString().replaceFirst('Exception: ', ''),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      rethrow;
    }

    // 3. Persist checkout details so the return screen can read them.
    final updatedAt = DateTime.now();
    await _attemptsRef(campaignId).doc(attemptId).update({
      'providerCheckoutId': session.checkoutId,
      'providerCheckoutUrl': session.checkoutUrl,
      'referenceNumber': attemptId,
      'status': PaymentAttemptStatus.pendingCheckout,
      'livemode': session.livemode,
      'updatedAt': updatedAt.toIso8601String(),
    });

    return attempt.copyWith(
      providerCheckoutId: session.checkoutId,
      providerCheckoutUrl: session.checkoutUrl,
      referenceNumber: attemptId,
      status: PaymentAttemptStatus.pendingCheckout,
      livemode: session.livemode,
      updatedAt: updatedAt,
    );
  }

  /// Called by the return screen after PayMongo redirects back.
  /// Verifies the checkout session with PayMongo and finalizes the pledge
  /// in Firestore if the payment was successful.
  Future<void> finalizePaymentFromRedirect({
    required String campaignId,
    required String attemptId,
  }) async {
    final attemptSnap = await _attemptsRef(campaignId).doc(attemptId).get();
    if (!attemptSnap.exists) throw Exception('Payment attempt not found.');

    final attempt = _attemptFromDoc(attemptSnap, campaignId);

    // Idempotent: already done.
    if (attempt.status == PaymentAttemptStatus.paid) return;
    if (attempt.isTerminal) return;

    final checkoutId = attempt.providerCheckoutId;
    if (checkoutId == null || checkoutId.isEmpty) {
      throw Exception('Walang checkout session ID na i-verify.');
    }

    final response = await http.get(
      Uri.parse('$_kPayMongoBase/v2/checkout_sessions/$checkoutId'),
      headers: {'Authorization': _authHeader},
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Hindi ma-verify ang status ng bayad sa PayMongo. Subukan muli.',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final attrs =
        (json['data'] as Map<String, dynamic>)['attributes']
            as Map<String, dynamic>;
    final paymentStatus = attrs['payment_status'] as String? ?? 'unpaid';
    final sessionStatus = attrs['status'] as String? ?? '';

    if (paymentStatus == 'paid') {
      await _finalizeAsPaid(
        attempt: attempt,
        campaignId: campaignId,
        sessionAttrs: attrs,
      );
    } else if (sessionStatus == 'expired') {
      await _attemptsRef(campaignId).doc(attemptId).update({
        'status': PaymentAttemptStatus.expired,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } else {
      await _attemptsRef(campaignId).doc(attemptId).update({
        'status': PaymentAttemptStatus.cancelled,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> _finalizeAsPaid({
    required PaymentAttempt attempt,
    required String campaignId,
    required Map<String, dynamic> sessionAttrs,
  }) async {
    final now = DateTime.now().toIso8601String();
    final payments = sessionAttrs['payments'] as List? ?? [];
    final paymentId = payments.isNotEmpty
        ? (payments.first as Map<String, dynamic>)['id'] as String?
        : null;

    // Avoid double-counting the same backer.
    final existingPledge = await _pledgesRef(campaignId)
        .where('backerUid', isEqualTo: attempt.createdByUid)
        .limit(1)
        .get();
    final isNewBacker = existingPledge.docs.isEmpty;

    final batch = _db.batch();

    batch.set(
      _pledgesRef(campaignId).doc(attempt.id),
      {
        'amount': attempt.amount,
        'backerEmail': attempt.createdByEmail,
        'backerName': attempt.donorName,
        'backerNote': attempt.donorNote,
        'backerPhone': attempt.donorPhone,
        'backerUid': attempt.createdByUid,
        'createdAt': now,
        'paidAt': now,
        'paymentAttemptId': attempt.id,
        'provider': attempt.provider,
        'providerPaymentId': paymentId,
        'rewardId': attempt.rewardId,
      },
    );

    final campaignUpdate = <String, dynamic>{
      'pledgedAmount': FieldValue.increment(attempt.amount),
    };
    if (isNewBacker) {
      campaignUpdate['backersCount'] = FieldValue.increment(1);
    }
    batch.update(_campaigns.doc(campaignId), campaignUpdate);

    batch.update(
      _attemptsRef(campaignId).doc(attempt.id),
      {
        'status': PaymentAttemptStatus.paid,
        'completedAt': now,
        'providerPaymentId': paymentId,
        'updatedAt': now,
      },
    );

    await batch.commit();
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
