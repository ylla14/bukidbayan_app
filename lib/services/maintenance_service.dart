import 'package:bukidbayan_app/models/equipment.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class MaintenanceAffectedBooking {
  final String requestId;
  final String renterId;
  final String renterName;
  final DateTime start;
  final DateTime end;
  final bool willBeCancelled;
  final DateTime? newStart;
  final DateTime? newEnd;

  const MaintenanceAffectedBooking({
    required this.requestId,
    required this.renterId,
    required this.renterName,
    required this.start,
    required this.end,
    required this.willBeCancelled,
    this.newStart,
    this.newEnd,
  });
}

class MaintenanceService {
  MaintenanceService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

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
      'maintenanceCount': FieldValue.increment(1),
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
        'maintenanceCount': FieldValue.increment(1),
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

  Future<List<MaintenanceAffectedBooking>> fetchAffectedBookings({
    required String equipmentId,
    required DateTime today,
    required DateTime maintenanceEnd,
    required bool isUnforeseen,
    DateTime? availableUntil,
  }) async {
    const activeStatuses = ['pending', 'approved', 'readyForPickup'];
    final snap = await _db
        .collection('rentRequests')
        .where('itemId', isEqualTo: equipmentId)
        .where('status', whereIn: activeStatuses)
        .get();

    final maintenanceEndDay = DateTime(
      maintenanceEnd.year,
      maintenanceEnd.month,
      maintenanceEnd.day,
    );
    final sortedDocs = snap.docs.toList()
      ..sort((a, b) {
        final aStart = (a.data()['start'] as Timestamp).toDate();
        final bStart = (b.data()['start'] as Timestamp).toDate();
        return aStart.compareTo(bStart);
      });

    final results = <MaintenanceAffectedBooking>[];
    DateTime blockedUntil = maintenanceEndDay;

    for (final doc in sortedDocs) {
      final data = doc.data();
      final reqStart = (data['start'] as Timestamp).toDate();
      final reqEnd = (data['end'] as Timestamp).toDate();
      final renterName = data['name'] as String? ?? 'Unknown';
      final renterId = data['renterId'] as String? ?? '';
      final bookingStart = DateTime(
        reqStart.year,
        reqStart.month,
        reqStart.day,
      );
      final bookingEnd = DateTime(reqEnd.year, reqEnd.month, reqEnd.day);

      if (isUnforeseen) {
        final overlaps =
            bookingStart.isBefore(
              maintenanceEndDay.add(const Duration(days: 1)),
            ) &&
            bookingEnd.isAfter(today.subtract(const Duration(days: 1)));
        if (!overlaps) continue;
        results.add(
          MaintenanceAffectedBooking(
            requestId: doc.id,
            renterId: renterId,
            renterName: renterName,
            start: reqStart,
            end: reqEnd,
            willBeCancelled: true,
          ),
        );
      } else {
        if (bookingStart.isAfter(blockedUntil)) continue;
        final duration = reqEnd.difference(reqStart);
        final newStart = DateTime(
          blockedUntil.year,
          blockedUntil.month,
          blockedUntil.day,
          reqStart.hour,
          reqStart.minute,
        ).add(const Duration(days: 1));
        final newEnd = newStart.add(duration);
        final exceedsAvailability =
            availableUntil != null && newEnd.isAfter(availableUntil);

        if (exceedsAvailability) {
          results.add(
            MaintenanceAffectedBooking(
              requestId: doc.id,
              renterId: renterId,
              renterName: renterName,
              start: reqStart,
              end: reqEnd,
              willBeCancelled: true,
            ),
          );
        } else {
          results.add(
            MaintenanceAffectedBooking(
              requestId: doc.id,
              renterId: renterId,
              renterName: renterName,
              start: reqStart,
              end: reqEnd,
              willBeCancelled: false,
              newStart: newStart,
              newEnd: newEnd,
            ),
          );
          blockedUntil = DateTime(newEnd.year, newEnd.month, newEnd.day);
        }
      }
    }
    results.sort((a, b) => a.start.compareTo(b.start));
    return results;
  }

  Future<void> scheduleMaintenanceForEquipment({
    required String equipmentId,
    required String equipmentName,
    String? ownerId,
    required DateTime today,
    required DateTime maintenanceEnd,
    DateTime? availableUntil,
  }) async {
    final durationDays = maintenanceEnd.difference(today).inDays + 1;
    final isUnforeseen = durationDays > 7;
    final maintenanceEndDay = DateTime(
      maintenanceEnd.year,
      maintenanceEnd.month,
      maintenanceEnd.day,
    );

    await _db.collection('equipment').doc(equipmentId).update({
      'status': 'under_maintenance',
      'isAvailable': false,
      'maintenanceStart': Timestamp.fromDate(today),
      'maintenanceEnd': Timestamp.fromDate(maintenanceEnd),
    });

    const activeStatuses = ['pending', 'approved', 'readyForPickup'];
    final bookingsSnap = await _db
        .collection('rentRequests')
        .where('itemId', isEqualTo: equipmentId)
        .where('status', whereIn: activeStatuses)
        .get();

    final batch = _db.batch();
    final notifFutures = <Future<void>>[];
    DateTime blockedUntil = maintenanceEndDay;

    final sortedDocs = bookingsSnap.docs.toList()
      ..sort((a, b) {
        final aStart = (a.data()['start'] as Timestamp).toDate();
        final bStart = (b.data()['start'] as Timestamp).toDate();
        return aStart.compareTo(bStart);
      });

    for (final doc in sortedDocs) {
      final data = doc.data();
      final reqStart = (data['start'] as Timestamp).toDate();
      final reqEnd = (data['end'] as Timestamp).toDate();
      final renterId = data['renterId'] as String? ?? '';
      final bookingStart = DateTime(
        reqStart.year,
        reqStart.month,
        reqStart.day,
      );
      final bookingEnd = DateTime(reqEnd.year, reqEnd.month, reqEnd.day);

      if (isUnforeseen) {
        final overlaps =
            bookingStart.isBefore(
              maintenanceEndDay.add(const Duration(days: 1)),
            ) &&
            bookingEnd.isAfter(today.subtract(const Duration(days: 1)));
        if (!overlaps) continue;
        batch.update(doc.reference, {
          'status': 'canceled',
          'declineReason':
              'Ang kagamitan ay naka-schedule para sa hindi inaasahang '
              'maintenance mula ${DateFormat('MMM d').format(today)} hanggang '
              '${DateFormat('MMM d, yyyy').format(maintenanceEnd)}. '
              'Paumanhin sa abala.',
        });
        notifFutures.add(
          _sendRenterNotification(
            userId: renterId,
            title: 'Maintenance canceled booking',
            body:
                'Ang iyong booking para sa "$equipmentName" '
                '(${DateFormat('MMM d').format(reqStart)} - '
                '${DateFormat('MMM d').format(reqEnd)}) ay kinansela dahil sa '
                'hindi inaasahang maintenance ($durationDays na araw).',
            type: 'maintenance_cancel',
            extra: {'requestId': doc.id, 'equipmentId': equipmentId},
          ),
        );
      } else {
        if (bookingStart.isAfter(blockedUntil)) continue;
        final duration = reqEnd.difference(reqStart);
        final newStart = DateTime(
          blockedUntil.year,
          blockedUntil.month,
          blockedUntil.day,
          reqStart.hour,
          reqStart.minute,
        ).add(const Duration(days: 1));
        final newEnd = newStart.add(duration);
        final exceedsAvailability =
            availableUntil != null && newEnd.isAfter(availableUntil);

        if (exceedsAvailability) {
          batch.update(doc.reference, {
            'status': 'canceled',
            'declineReason':
                'Hindi ma-reschedule ang booking pagkatapos ng maintenance.',
          });
          notifFutures.add(
            _sendRenterNotification(
              userId: renterId,
              title: 'Maintenance canceled booking',
              body:
                  'Hindi ma-reschedule ang iyong booking para sa '
                  '"$equipmentName" pagkatapos ng maintenance. '
                  'Kinansela na ang iyong booking.',
              type: 'maintenance_cancel',
              extra: {'requestId': doc.id, 'equipmentId': equipmentId},
            ),
          );
        } else {
          batch.update(doc.reference, {
            'start': Timestamp.fromDate(newStart),
            'end': Timestamp.fromDate(newEnd),
            'originalStart': Timestamp.fromDate(reqStart),
            'originalEnd': Timestamp.fromDate(reqEnd),
            'maintenanceRescheduled': true,
          });
          notifFutures.add(
            _sendRenterNotification(
              userId: renterId,
              title: 'Maintenance rescheduled booking',
              body:
                  'Ang iyong booking para sa "$equipmentName" ay inilipat mula '
                  '${DateFormat('MMM d').format(reqStart)} - '
                  '${DateFormat('MMM d').format(reqEnd)} patungong '
                  '${DateFormat('MMM d').format(newStart)} - '
                  '${DateFormat('MMM d, yyyy').format(newEnd)}.',
              type: 'maintenance_reschedule',
              extra: {
                'requestId': doc.id,
                'equipmentId': equipmentId,
                'ownerId': ownerId,
                'canCancel': true,
                'canAccept': true,
                'newStart': Timestamp.fromDate(newStart),
                'newEnd': Timestamp.fromDate(newEnd),
              },
            ),
          );
          blockedUntil = DateTime(newEnd.year, newEnd.month, newEnd.day);
        }
      }
    }

    await batch.commit();
    await Future.wait(notifFutures);
  }

  Future<void> _sendRenterNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic> extra = const {},
  }) async {
    await _db.collection('notifications').doc(userId).collection('items').add({
      'type': type,
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
      ...extra,
    });
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
