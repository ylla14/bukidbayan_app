import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class MaintenanceService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Usage logging ──────────────────────────────────────────────────────────

  /// Called when a rental completes. Adds [rentalDays] × 24 hours to the
  /// equipment's accumulated usage counter and sends the owner a notification
  /// if an "Upcoming Maintenance" or "For Maintenance" threshold is crossed.
  Future<void> logRentalUsage({
    required String equipmentId,
    required String ownerId,
    required String equipmentName,
    required int rentalDays,
  }) async {
    if (rentalDays <= 0) return;

    final addedHours = rentalDays * 24.0;
    final equipRef   = _db.collection('equipment').doc(equipmentId);

    double previousHours   = 0;
    double newHours        = 0;
    double intervalHrs     = 240;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(equipRef);
      if (!snap.exists) return;

      final data = snap.data()!;
      intervalHrs   = (data['maintenanceIntervalHrs'] as num?)?.toDouble() ?? 240;
      previousHours = (data['hoursUsedSinceLastMaintenance'] as num?)?.toDouble() ?? 0;
      newHours      = previousHours + addedHours;

      tx.update(equipRef, {
        'hoursUsedSinceLastMaintenance': newHours,
      });
    });

    // Notify owner if a threshold was just crossed (non-critical).
    try {
      await _maybeNotifyOwner(
        ownerId      : ownerId,
        equipmentName: equipmentName,
        intervalHrs  : intervalHrs,
        previousHours: previousHours,
        newHours     : newHours,
      );
    } catch (e) {
      debugPrint('Maintenance notification failed (non-fatal): $e');
    }
  }

  // ── Reset ──────────────────────────────────────────────────────────────────

  /// Resets the usage counter to 0 when the owner marks maintenance as done.
  Future<void> resetMaintenanceHours(String equipmentId) async {
    await _db.collection('equipment').doc(equipmentId).update({
      'hoursUsedSinceLastMaintenance': 0,
    });
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  Future<void> _maybeNotifyOwner({
    required String ownerId,
    required String equipmentName,
    required double intervalHrs,
    required double previousHours,
    required double newHours,
  }) async {
    final previousRemaining = intervalHrs - previousHours;
    final newRemaining      = intervalHrs - newHours;

    // "For Maintenance" threshold crossed (remaining just hit 0 or below).
    if (newHours >= intervalHrs && previousHours < intervalHrs) {
      await _sendOwnerNotification(
        ownerId      : ownerId,
        type         : 'maintenance_due',
        title        : 'Maintenance Required — $equipmentName',
        body         : '"$equipmentName" ay umabot na sa ${intervalHrs.toStringAsFixed(0)} '
            'na oras ng paggamit. Kailangan na ng maintenance bago muling irenta.',
      );
      return;
    }

    // "Upcoming Maintenance" threshold crossed (remaining just dropped to ≤ 48).
    if (newRemaining <= 48 && previousRemaining > 48) {
      await _sendOwnerNotification(
        ownerId      : ownerId,
        type         : 'maintenance_upcoming',
        title        : 'Upcoming Maintenance — $equipmentName',
        body         : '"$equipmentName" ay may natitira na ${newRemaining.toStringAsFixed(0)} '
            'na oras bago kailanganin ng maintenance (${intervalHrs.toStringAsFixed(0)}-hr interval).',
      );
    }
  }

  Future<void> _sendOwnerNotification({
    required String ownerId,
    required String type,
    required String title,
    required String body,
  }) async {
    await _db
        .collection('notifications')
        .doc(ownerId)
        .collection('items')
        .add({
      'type'     : type,
      'title'    : title,
      'body'     : body,
      'createdAt': FieldValue.serverTimestamp(),
      'read'     : false,
    });
  }
}
