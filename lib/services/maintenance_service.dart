import 'package:bukidbayan_app/models/equipment.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class MaintenanceService {
  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  MaintenanceService({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  Future<void> logRentalUsage({
    required String equipmentId,
    required String ownerId,
    required String equipmentName,
    required int rentalDays,
  }) async {
    if (rentalDays <= 0) return;

    final addedHours = rentalDays * 24.0;
    final equipRef = _db.collection('equipment').doc(equipmentId);

    double previousHours = 0;
    double newHours = 0;
    double intervalHrs = 240;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(equipRef);
      if (!snap.exists) return;

      final data = snap.data()!;
      intervalHrs = (data['maintenanceIntervalHrs'] as num?)?.toDouble() ?? 240;
      previousHours =
          (data['hoursUsedSinceLastMaintenance'] as num?)?.toDouble() ?? 0;
      newHours = previousHours + addedHours;

      tx.update(equipRef, {'hoursUsedSinceLastMaintenance': newHours});
    });

    await _logMaintenanceEvent(
      equipmentId: equipmentId,
      eventType: 'usage_increment',
      metadata: {
        'ownerId': ownerId,
        'equipmentName': equipmentName,
        'addedHours': addedHours,
        'previousHours': previousHours,
        'newHours': newHours,
        'maintenanceIntervalHrs': intervalHrs,
        'source': 'rental_completion',
      },
    );

    try {
      await _maybeNotifyOwner(
        ownerId: ownerId,
        equipmentName: equipmentName,
        intervalHrs: intervalHrs,
        previousHours: previousHours,
        newHours: newHours,
      );
    } catch (e) {
      debugPrint('Maintenance notification failed (non-fatal): $e');
    }
  }

  Future<void> resetMaintenanceHours(String equipmentId) async {
    final equipmentDoc = await _db
        .collection('equipment')
        .doc(equipmentId)
        .get();
    final previousHours =
        (equipmentDoc.data()?['hoursUsedSinceLastMaintenance'] as num?)
            ?.toDouble() ??
        0;

    await _db.collection('equipment').doc(equipmentId).update({
      'hoursUsedSinceLastMaintenance': 0,
    });

    await _logMaintenanceEvent(
      equipmentId: equipmentId,
      eventType: 'usage_reset',
      metadata: {
        'previousHours': previousHours,
        'newHours': 0,
        'source': 'manual_reset',
      },
    );
  }

  Future<void> markEquipmentUnderMaintenance({
    required Equipment equipment,
    required DateTime maintenanceStart,
    required DateTime maintenanceEnd,
    required bool isUnforeseen,
    String source = 'manual_schedule',
  }) async {
    await _db.collection('equipment').doc(equipment.id).update({
      'status': EquipmentStatus.underMaintenance.toValue(),
      'isAvailable': false,
      'maintenanceStart': Timestamp.fromDate(maintenanceStart),
      'maintenanceEnd': Timestamp.fromDate(maintenanceEnd),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _logMaintenanceEvent(
      equipmentId: equipment.id!,
      eventType: 'maintenance_scheduled',
      metadata: {
        'equipmentName': equipment.name,
        'ownerId': equipment.ownerId,
        'maintenanceStart': maintenanceStart,
        'maintenanceEnd': maintenanceEnd,
        'durationDays':
            maintenanceEnd
                .difference(
                  DateTime(
                    maintenanceStart.year,
                    maintenanceStart.month,
                    maintenanceStart.day,
                  ),
                )
                .inDays +
            1,
        'isUnforeseen': isUnforeseen,
        'source': source,
      },
    );
  }

  Future<void> completeMaintenance({
    required Equipment equipment,
    String source = 'manual_complete',
  }) async {
    final equipmentRef = _db.collection('equipment').doc(equipment.id);

    DateTime? maintenanceStart;
    DateTime? maintenanceEnd;
    double previousHours = 0;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(equipmentRef);
      if (!snap.exists) return;

      final data = snap.data()!;
      maintenanceStart = (data['maintenanceStart'] as Timestamp?)?.toDate();
      maintenanceEnd = (data['maintenanceEnd'] as Timestamp?)?.toDate();
      previousHours =
          (data['hoursUsedSinceLastMaintenance'] as num?)?.toDouble() ?? 0;

      tx.update(equipmentRef, {
        'status': EquipmentStatus.available.toValue(),
        'isAvailable': true,
        'maintenanceStart': null,
        'maintenanceEnd': null,
        'hoursUsedSinceLastMaintenance': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    await _logMaintenanceEvent(
      equipmentId: equipment.id!,
      eventType: 'maintenance_completed',
      metadata: {
        'equipmentName': equipment.name,
        'ownerId': equipment.ownerId,
        'maintenanceStart': maintenanceStart,
        'maintenanceEnd': maintenanceEnd,
        'previousHours': previousHours,
        'newHours': 0,
        'source': source,
      },
    );
  }

  Future<void> _maybeNotifyOwner({
    required String ownerId,
    required String equipmentName,
    required double intervalHrs,
    required double previousHours,
    required double newHours,
  }) async {
    final previousRemaining = intervalHrs - previousHours;
    final newRemaining = intervalHrs - newHours;

    if (newHours >= intervalHrs && previousHours < intervalHrs) {
      await _sendOwnerNotification(
        ownerId: ownerId,
        type: 'maintenance_due',
        title: 'Maintenance Required - $equipmentName',
        body:
            '"$equipmentName" ay umabot na sa ${intervalHrs.toStringAsFixed(0)} na oras ng paggamit. Kailangan na ng maintenance bago muling irenta.',
      );
      return;
    }

    if (newRemaining <= 48 && previousRemaining > 48) {
      await _sendOwnerNotification(
        ownerId: ownerId,
        type: 'maintenance_upcoming',
        title: 'Upcoming Maintenance - $equipmentName',
        body:
            '"$equipmentName" ay may natitira na ${newRemaining.toStringAsFixed(0)} na oras bago kailanganin ng maintenance (${intervalHrs.toStringAsFixed(0)}-hr interval).',
      );
    }
  }

  Future<void> _sendOwnerNotification({
    required String ownerId,
    required String type,
    required String title,
    required String body,
  }) async {
    await _db.collection('notifications').doc(ownerId).collection('items').add({
      'type': type,
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  Future<void> _logMaintenanceEvent({
    required String equipmentId,
    required String eventType,
    Map<String, dynamic> metadata = const {},
  }) async {
    await _db
        .collection('equipment')
        .doc(equipmentId)
        .collection('maintenance_logs')
        .add({
          'eventType': eventType,
          'metadata': _serializeMap(metadata),
          'capturedAt': Timestamp.fromDate(DateTime.now()),
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  Map<String, dynamic> _serializeMap(Map<String, dynamic> source) {
    return source.map((key, value) => MapEntry(key, _serializeValue(value)));
  }

  dynamic _serializeValue(dynamic value) {
    if (value is DateTime) {
      return Timestamp.fromDate(value);
    }
    if (value is Map<String, dynamic>) {
      return _serializeMap(value);
    }
    if (value is Iterable) {
      return value.map(_serializeValue).toList();
    }
    return value;
  }
}
