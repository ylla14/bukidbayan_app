import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Block durations per case (in days).
const int kBlockDurationCancelStrike = 7;   // Case 1: 3 cancel-strikes   → 1 week
const int kBlockDurationMisuse       = 14;  // Case 2/3: misuse/damage    → 2 weeks (immediate)
const int kBlockDurationLateReturn   = 7;   // Case 4: 3 late-day-strikes → 1 week

class StrikeService {
  static const int _maxStrikes = 3;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Case 1: Cancel after approval (strike-based) ───────────────────────────

  /// Increments the renter's strike count and blocks for [blockDurationDays]
  /// once 3 strikes are reached. Used for Case 1 (cancel after approval).
  Future<void> submitReport({
    required String requestId,
    required String renterId,
    required String ownerId,
    required String reason,
    required String details,
    List<String> evidenceUrls = const [],
    int blockDurationDays = kBlockDurationCancelStrike,
  }) async {
    final userRef   = _db.collection('users').doc(renterId);
    final reportRef = _db.collection('reports').doc();

    int newStrikes = 0;
    bool nowBlocked = false;
    DateTime? blockedUntil;

    await _db.runTransaction((tx) async {
      final userSnap       = await tx.get(userRef);
      final currentStrikes = (userSnap.data()?['strikeCount'] as int?) ?? 0;
      newStrikes = currentStrikes + 1;

      tx.set(reportRef, {
        'requestId'   : requestId,
        'renterId'    : renterId,
        'ownerId'     : ownerId,
        'reason'      : reason,
        'details'     : details,
        'evidenceUrls': evidenceUrls,
        'createdAt'   : FieldValue.serverTimestamp(),
      });

      final Map<String, dynamic> userUpdate = {'strikeCount': newStrikes};

      if (newStrikes >= _maxStrikes) {
        blockedUntil = DateTime.now().add(Duration(days: blockDurationDays));
        userUpdate['blockedUntil'] = Timestamp.fromDate(blockedUntil!);
        nowBlocked = true;
      }

      tx.update(userRef, userUpdate);
    });

    try {
      await _sendStrikeNotification(
        renterId         : renterId,
        strikeCount      : newStrikes,
        reason           : reason,
        nowBlocked       : nowBlocked,
        blockedUntil     : blockedUntil,
        blockDurationDays: blockDurationDays,
      );
    } catch (e) {
      debugPrint('Strike notification failed (non-fatal): $e');
    }
  }

  // ── Cases 2 & 3: Misuse / Damage (immediate ban, no strike count) ──────────

  /// Immediately bans the renter for [kBlockDurationMisuse] days without
  /// touching their strike count. Used for equipment damage and misuse reports.
  static const kDamageReasons = {'damaged_equipment', 'missing_parts', 'misuse'};
  static const kDamageRetirementThreshold = 5;

  Future<void> issueMisuseBan({
    required String requestId,
    required String renterId,
    required String ownerId,
    required String reason,
    required String details,
    String? equipmentId,
    List<String> evidenceUrls = const [],
  }) async {
    final userRef   = _db.collection('users').doc(renterId);
    final reportRef = _db.collection('reports').doc();
    final blockedUntil =
        DateTime.now().add(const Duration(days: kBlockDurationMisuse));

    await _db.runTransaction((tx) async {
      tx.set(reportRef, {
        'requestId'   : requestId,
        'renterId'    : renterId,
        'ownerId'     : ownerId,
        'reason'      : reason,
        'details'     : details,
        'evidenceUrls': evidenceUrls,
        'createdAt'   : FieldValue.serverTimestamp(),
      });

      tx.update(userRef, {
        'blockedUntil': Timestamp.fromDate(blockedUntil),
      });

      if (equipmentId != null && kDamageReasons.contains(reason)) {
        tx.update(_db.collection('equipment').doc(equipmentId), {
          'damageReportCount': FieldValue.increment(1),
        });
      }
    });

    try {
      await _sendBanNotification(
        renterId     : renterId,
        reason       : reason,
        blockedUntil : blockedUntil,
      );
    } catch (e) {
      debugPrint('Misuse ban notification failed (non-fatal): $e');
    }
  }

  // ── Case 4: per-day late-return strikes ────────────────────────────────────

  /// Calculates how many new overdue days have elapsed since the last strike
  /// was issued ([lastLateStrikeIssuedDate] on the request doc), issues one
  /// strike per new day, and updates the request document.
  ///
  /// Safe to call repeatedly — it only acts on days not yet accounted for.
  Future<void> issueLateDayStrikes({
    required String requestId,
    required String renterId,
    required String ownerId,
    required DateTime endDate,
    required DateTime? lastLateStrikeIssuedDate,
  }) async {
    final now = DateTime.now();
    if (!now.isAfter(endDate)) return;

    // Baseline: the end-date itself (no grace period — day 1 of lateness = day
    // after endDate). If we've issued before, use that date as baseline.
    final baseline = lastLateStrikeIssuedDate ?? endDate;
    final newDays  = now.difference(baseline).inDays;
    if (newDays <= 0) return;

    final userRef    = _db.collection('users').doc(renterId);
    final requestRef = _db.collection('rentRequests').doc(requestId);

    int finalStrikes = 0;
    bool nowBlocked  = false;
    DateTime? blockedUntil;
    int strikesBeforeThis = 0;

    await _db.runTransaction((tx) async {
      final userSnap   = await tx.get(userRef);
      strikesBeforeThis = (userSnap.data()?['strikeCount'] as int?) ?? 0;
      finalStrikes      = strikesBeforeThis + newDays;

      final Map<String, dynamic> userUpdate = {'strikeCount': finalStrikes};

      if (finalStrikes >= _maxStrikes) {
        blockedUntil =
            DateTime.now().add(const Duration(days: kBlockDurationLateReturn));
        userUpdate['blockedUntil'] = Timestamp.fromDate(blockedUntil!);
        nowBlocked = true;
      }

      tx.update(userRef, userUpdate);
      tx.update(requestRef, {
        'lastLateStrikeIssuedDate': Timestamp.fromDate(now),
      });
    });

    try {
      // Send one notification per new strike day so the renter sees each one.
      for (int i = 1; i <= newDays; i++) {
        final strikeNum = strikesBeforeThis + i;
        await _sendStrikeNotification(
          renterId         : renterId,
          strikeCount      : strikeNum,
          reason           : 'late_return',
          nowBlocked       : nowBlocked && strikeNum >= _maxStrikes,
          blockedUntil     : (nowBlocked && strikeNum >= _maxStrikes)
              ? blockedUntil
              : null,
          blockDurationDays: kBlockDurationLateReturn,
        );
      }
    } catch (e) {
      debugPrint('Late-return strike notifications failed (non-fatal): $e');
    }
  }

  // ── Admin actions ──────────────────────────────────────────────────────────

  /// Admin issues a formal warning. Increments [warningCount], sets
  /// [isDelinquent] to true, and stores [reason] as [lastDelinquencyReason].
  Future<void> issueAdminWarning({
    required String targetUid,
    required String reason,
    String? adminUid,
  }) async {
    final userRef   = _db.collection('users').doc(targetUid);
    final reportRef = _db.collection('reports').doc();

    await _db.runTransaction((tx) async {
      final snap    = await tx.get(userRef);
      final current = (snap.data()?['warningCount'] as int?) ?? 0;

      tx.update(userRef, {
        'warningCount'          : current + 1,
        'isDelinquent'          : true,
        'lastDelinquencyReason' : reason,
      });

      tx.set(reportRef, {
        'type'      : 'admin_warning',
        'renterId'  : targetUid,
        'ownerId'   : adminUid ?? '',
        'reason'    : 'admin_warning',
        'details'   : reason,
        'evidenceUrls': <String>[],
        'createdAt' : FieldValue.serverTimestamp(),
      });
    });

    try {
      await _db
          .collection('notifications')
          .doc(targetUid)
          .collection('items')
          .add({
        'type'      : 'strike',
        'title'     : 'Natanggap ang Babala mula sa Admin',
        'body'      : 'Nakatanggap ka ng opisyal na babala: "$reason". '
            'Pakisuyong sumunod sa mga alituntunin ng platform.',
        'createdAt' : FieldValue.serverTimestamp(),
        'read'      : false,
      });
    } catch (e) {
      debugPrint('Admin warning notification failed (non-fatal): $e');
    }
  }

  /// Admin suspends a user for [days] days with a stated [reason].
  Future<void> issueAdminSuspension({
    required String targetUid,
    required int days,
    required String reason,
    String? adminUid,
  }) async {
    final userRef      = _db.collection('users').doc(targetUid);
    final reportRef    = _db.collection('reports').doc();
    final blockedUntil = DateTime.now().add(Duration(days: days));

    await _db.runTransaction((tx) async {
      tx.update(userRef, {
        'blockedUntil'          : Timestamp.fromDate(blockedUntil),
        'isDelinquent'          : true,
        'lastDelinquencyReason' : reason,
      });

      tx.set(reportRef, {
        'type'        : 'admin_suspension',
        'renterId'    : targetUid,
        'ownerId'     : adminUid ?? '',
        'reason'      : 'admin_suspension',
        'details'     : reason,
        'evidenceUrls': <String>[],
        'createdAt'   : FieldValue.serverTimestamp(),
      });
    });

    try {
      final d           = blockedUntil;
      final unblockDate = '${d.day}/${d.month}/${d.year}';
      await _db
          .collection('notifications')
          .doc(targetUid)
          .collection('items')
          .add({
        'type'      : 'strike',
        'title'     : 'Nasuspinde ang Iyong Account',
        'body'      : 'Ang iyong account ay sinuspinde ng admin sa loob ng '
            '$days na araw dahil sa: "$reason". '
            'Hindi ka makakapaghiram ng kagamitan hanggang $unblockDate.',
        'createdAt' : FieldValue.serverTimestamp(),
        'read'      : false,
      });
    } catch (e) {
      debugPrint('Admin suspension notification failed (non-fatal): $e');
    }
  }

  /// Admin clears all delinquency state for a user.
  Future<void> clearDelinquency({required String targetUid}) async {
    await _db.collection('users').doc(targetUid).update({
      'isDelinquent'          : false,
      'warningCount'          : 0,
      'strikeCount'           : 0,
      'lastDelinquencyReason' : FieldValue.delete(),
      'blockedUntil'          : FieldValue.delete(),
    });
  }

  // ── Block checks ───────────────────────────────────────────────────────────

  Future<bool> isRenterBlocked(String userId) async {
    final doc  = await _db.collection('users').doc(userId).get();
    final data = doc.data();
    if (data == null) return false;
    final until = (data['blockedUntil'] as Timestamp?)?.toDate();
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  Future<DateTime?> blockedUntil(String userId) async {
    final doc  = await _db.collection('users').doc(userId).get();
    final data = doc.data();
    if (data == null) return null;
    final until = (data['blockedUntil'] as Timestamp?)?.toDate();
    if (until == null) return null;
    return DateTime.now().isBefore(until) ? until : null;
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  Future<void> _sendBanNotification({
    required String renterId,
    required String reason,
    required DateTime blockedUntil,
  }) async {
    final d = blockedUntil;
    final unblockDate = '${d.day}/${d.month}/${d.year}';
    final reasonLabel = _reasonLabel(reason);
    await _db
        .collection('notifications')
        .doc(renterId)
        .collection('items')
        .add({
      'type'     : 'strike',
      'title'    : 'Pansamantalang Nasuspinde',
      'body'     : 'Ang iyong account ay pansamantalang sinuspinde sa loob ng '
          '$kBlockDurationMisuse na araw dahil sa: "$reasonLabel". '
          'Hindi ka makakapaghiram ng kagamitan hanggang $unblockDate.',
      'createdAt': FieldValue.serverTimestamp(),
      'read'     : false,
    });
  }

  Future<void> _sendStrikeNotification({
    required String renterId,
    required int strikeCount,
    required String reason,
    required bool nowBlocked,
    DateTime? blockedUntil,
    int blockDurationDays = kBlockDurationCancelStrike,
  }) async {
    final reasonLabel = _reasonLabel(reason);
    final String body;

    if (nowBlocked && blockedUntil != null) {
      final d = blockedUntil;
      final unblockDate = '${d.day}/${d.month}/${d.year}';
      body = 'Nakatanggap ka ng paglabag ($strikeCount/$_maxStrikes) dahil sa: '
          '"$reasonLabel". Pansamantalang hindi ka makakapaghiram ng kagamitan '
          'hanggang $unblockDate ($blockDurationDays na araw).';
    } else {
      body = 'Nakatanggap ka ng paglabag ($strikeCount/$_maxStrikes) dahil sa: '
          '"$reasonLabel". Sa $_maxStrikes na paglabag, '
          'maaari kang pansamantalang masuspinde mula sa paghihiram.';
    }

    await _db
        .collection('notifications')
        .doc(renterId)
        .collection('items')
        .add({
      'type'     : 'strike',
      'title'    : 'Nakatanggap ka ng Paglabag',
      'body'     : body,
      'createdAt': FieldValue.serverTimestamp(),
      'read'     : false,
    });
  }

  String _reasonLabel(String reason) {
    switch (reason) {
      case 'damaged_equipment'    : return 'Nasirang Kagamitan';
      case 'late_return'          : return 'Nahuling Ibalik';
      case 'missing_parts'        : return 'Nawawalang Parte / Accessories';
      case 'misuse'               : return 'Maling Paggamit ng Kagamitan';
      case 'cancel_after_approval': return 'Kinansela Pagkatapos ng Pag-apruba';
      default                     : return 'Iba pa';
    }
  }
}
