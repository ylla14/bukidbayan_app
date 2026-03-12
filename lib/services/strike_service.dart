import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class StrikeService {
  static const int _maxStrikes = 3;
  static const int _blockDurationDays = 3;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Saves a report to Firestore, increments the renter's strike counter
  /// atomically, sets [blockedUntil] if strikes reach [_maxStrikes], and
  /// sends an in-app notification to the renter.
  Future<void> submitReport({
    required String requestId,
    required String renterId,
    required String ownerId,
    required String reason,
    required String details,
    List<String> evidenceUrls = const [],
  }) async {
    final userRef = _db.collection('users').doc(renterId);
    final reportRef = _db.collection('reports').doc();

    int newStrikes = 0;
    bool nowBlocked = false;
    DateTime? blockedUntil;

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final currentStrikes = (userSnap.data()?['strikeCount'] as int?) ?? 0;
      newStrikes = currentStrikes + 1;

      // Save the report document
      tx.set(reportRef, {
        'requestId': requestId,
        'renterId': renterId,
        'ownerId': ownerId,
        'reason': reason,
        'details': details,
        'evidenceUrls': evidenceUrls,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update the renter's strike count
      final Map<String, dynamic> userUpdate = {'strikeCount': newStrikes};
      if (newStrikes >= _maxStrikes) {
        blockedUntil =
            DateTime.now().add(const Duration(days: _blockDurationDays));
        userUpdate['blockedUntil'] = Timestamp.fromDate(blockedUntil!);
        nowBlocked = true;
      }
      tx.update(userRef, userUpdate);
    });

    // Notify the renter (outside the transaction — non-critical)
    try {
      await _sendStrikeNotification(
        renterId: renterId,
        strikeCount: newStrikes,
        reason: reason,
        nowBlocked: nowBlocked,
        blockedUntil: blockedUntil,
      );
    } catch (e) {
      debugPrint('Strike notification failed (non-fatal): $e');
    }
  }

  /// Returns true if the renter is currently blocked from making new requests.
  Future<bool> isRenterBlocked(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    final data = doc.data();
    if (data == null) return false;
    final blockedUntil = (data['blockedUntil'] as Timestamp?)?.toDate();
    if (blockedUntil == null) return false;
    return DateTime.now().isBefore(blockedUntil);
  }

  /// Returns the [DateTime] when the block expires, or null if not blocked.
  Future<DateTime?> blockedUntil(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    final data = doc.data();
    if (data == null) return null;
    final until = (data['blockedUntil'] as Timestamp?)?.toDate();
    if (until == null) return null;
    return DateTime.now().isBefore(until) ? until : null;
  }

  Future<void> _sendStrikeNotification({
    required String renterId,
    required int strikeCount,
    required String reason,
    required bool nowBlocked,
    DateTime? blockedUntil,
  }) async {
    final reasonLabel = _reasonLabel(reason);
    final String body;

    if (nowBlocked && blockedUntil != null) {
      final unblockDate =
          '${blockedUntil.day}/${blockedUntil.month}/${blockedUntil.year}';
      body = 'Nakatanggap ka ng strike ($strikeCount/$_maxStrikes) dahil sa: '
          '"$reasonLabel". Dahil umabot na sa $_maxStrikes ang iyong mga strike, '
          'pansamantalang hindi ka makakapaghiram ng kagamitan hanggang $unblockDate.';
    } else {
      body = 'Nakatanggap ka ng strike ($strikeCount/$_maxStrikes) dahil sa: '
          '"$reasonLabel". Sa $_maxStrikes na strikes, '
          'maaari kang pansamantalang masuspinde mula sa paghihiram.';
    }

    await _db
        .collection('notifications')
        .doc(renterId)
        .collection('items')
        .add({
      'type': 'strike',
      'title': 'Nakatanggap ka ng Strike',
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  String _reasonLabel(String reason) {
    switch (reason) {
      case 'damaged_equipment':
        return 'Nasirang Kagamitan';
      case 'late_return':
        return 'Nahuling Ibalik';
      case 'missing_parts':
        return 'Nawawalang Parte / Accessories';
      case 'misuse':
        return 'Maling Paggamit ng Kagamitan';
      default:
        return 'Iba pa';
    }
  }
}
