import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/screens/rent/equipment_listing_form_screen.dart';
import 'package:bukidbayan_app/screens/rent/product_page.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MyEquipment extends StatelessWidget {
  MyEquipment({super.key});

  final FirestoreService _firestoreService = FirestoreService();
  Future<void> _toggleMaintenance(Equipment equipment) async {
    final newStatus = equipment.status == EquipmentStatus.available
        ? EquipmentStatus.underMaintenance
        : EquipmentStatus.available;
    await FirebaseFirestore.instance
      .collection('equipment')
      .doc(equipment.id)
      .update({
        'status': newStatus.toValue(),
        'isAvailable': newStatus == EquipmentStatus.available, // keep in sync
      });
  }

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Equipment',
          style: TextStyle(color: lightColorScheme.onPrimary),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [lightColorScheme.primary, lightColorScheme.secondary],
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('equipment')
            .where('ownerId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No equipment listed yet.'));
          }

          final equipmentList = snapshot.data!.docs
              .map((doc) => Equipment.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: equipmentList.length,
            itemBuilder: (context, index) {
              return buildEquipmentCard(context, equipmentList[index]);
            },
          );
        },
      ),

      floatingActionButton: Align(
  alignment: Alignment.centerRight,
  child: FloatingActionButton.small(
    onPressed: () {
      showModalBottomSheet(
        context: context,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '🛠 Dev Tools',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'These are one-time migration tools. Be careful.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  migrateEquipmentStatus(context);
                },
                icon: const Icon(Icons.upload),
                label: const Text('Migrate: isAvailable → status'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  rollbackEquipmentStatus(context);
                },
                icon: const Icon(Icons.undo),
                label: const Text('Rollback: status → isAvailable'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade600),
                ),
              ),
            ],
          ),
        ),
      );
    },
    backgroundColor: Colors.black.withOpacity(0.15),
    elevation: 0,
    child: const Icon(Icons.build, size: 16, color: Colors.black45),
  ),
),
floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
    );
  }

  Widget buildEquipmentCard(BuildContext context, Equipment equipment) {
    return FutureBuilder<String?>(
      future: _firestoreService.getUserNameById(equipment.ownerId),
      builder: (context, snapshot) {
        final ownerName = snapshot.data ?? 'Unknown Owner';

        final tempItem = Equipment(
          name: equipment.name,
          imageUrls: equipment.imageUrls.isNotEmpty
              ? equipment.imageUrls
              : ['assets/images/rent1.jpg'],
          category: equipment.category ?? 'Other',
          price: equipment.price,
          availableFrom: equipment.availableFrom,
          availableUntil: equipment.availableUntil,
          brand: equipment.brand,
          yearModel: equipment.yearModel,
          power: equipment.power,
          fuelType: equipment.fuelType,
          condition: equipment.condition,
          attachments: equipment.attachments,
          operatorIncluded: equipment.operatorIncluded,
          rentRate: equipment.rentRate,
          landSizeRequirement: equipment.landSizeRequirement,
          maxCropHeightRequirement: equipment.maxCropHeightRequirement,
          id: equipment.id ?? 'UNKNOWN ID',
          description: equipment.description,
          landSizeMax: equipment.landSizeMax,
          landSizeMin: equipment.landSizeMin,
          maxCropHeight: equipment.maxCropHeight,
          ownerName: ownerName,
          rentalUnit: equipment.rentalUnit,
          ownerId: equipment.ownerId,
          status: equipment.status, // NEW
        );

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductPage(item: tempItem),
              ),
            );
          },
          child: Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: equipment.imageUrls.isNotEmpty
                        ? Image.network(
                            equipment.imageUrls.first,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholderImage(),
                          )
                        : _placeholderImage(),
                  ),
                  const SizedBox(width: 12),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          equipment.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          equipment.category ?? 'No category',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₱${equipment.price} / ${equipment.rentalUnit}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: lightColorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _statusColor(equipment.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _statusColor(equipment.status).withOpacity(0.4)),
                          ),
                          child: Text(
                            _statusLabel(equipment.status),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _statusColor(equipment.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Action Buttons
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Edit Button
                      SizedBox(
                        width: 90,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EquipmentListingScreen(
                                    existingEquipment: tempItem),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit_outlined, size: 14),
                          label: const Text('Edit',
                              style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: lightColorScheme.primary,
                            side:
                                BorderSide(color: lightColorScheme.primary),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      
                      // Maintenance Toggle Button
                      SizedBox(
  width: 100,
  child: ElevatedButton.icon(
    onPressed: equipment.status == EquipmentStatus.unavailable
        ? null
        : () async {
            if (equipment.status == EquipmentStatus.available) {
              await _scheduleMaintenance(context, equipment);
            } else {
              await _endMaintenance(context, equipment);
            }
          },
    icon: Icon(
      equipment.status == EquipmentStatus.available
          ? Icons.build_outlined
          : Icons.check_circle_outline,
      size: 14,
    ),
    label: Text(
      equipment.status == EquipmentStatus.available
          ? 'Maintenance'
          : 'Set Available',
      style: const TextStyle(fontSize: 11),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: equipment.status == EquipmentStatus.unavailable
          ? Colors.grey.shade400
          : equipment.status == EquipmentStatus.available
              ? Colors.orange.shade600
              : Colors.green.shade600,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
    ),
  ),
),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 72,
      height: 72,
      color: Colors.grey.shade200,
      child: const Icon(Icons.image_not_supported,
          color: Colors.grey, size: 28),
    );
  }

String _statusLabel(EquipmentStatus status) {
  switch (status) {
    case EquipmentStatus.available: return 'Available';
    case EquipmentStatus.underMaintenance: return 'Under Maintenance';
    case EquipmentStatus.unavailable: return 'Unavailable';
  }
}

Color _statusColor(EquipmentStatus status) {
  switch (status) {
    case EquipmentStatus.available: return Colors.green.shade700;
    case EquipmentStatus.underMaintenance: return Colors.orange.shade700;
    case EquipmentStatus.unavailable: return Colors.grey.shade600;
  }
}



// Run this to migrate all equipment docs from isAvailable (bool) to status (string)
Future<void> migrateEquipmentStatus(BuildContext context) async {

  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Run Migration?'),
      content: const Text(
        'This will add a "status" field to all equipment docs that are missing it, based on their old "isAvailable" value. Safe to run multiple times.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Run'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  final snapshot = await FirebaseFirestore.instance
      .collection('equipment')
      .get();

  int updated = 0;
  int skipped = 0;

  for (final doc in snapshot.docs) {
    final data = doc.data();

    // Skip if already migrated
    if (data['status'] != null) {
      skipped++;
      continue;
    }

    final oldIsAvailable = data['isAvailable'] is bool
        ? data['isAvailable']
        : data['isAvailable']?.toString().toLowerCase() == 'true';

    final newStatus = oldIsAvailable == true
        ? EquipmentStatus.available.toValue()
        : EquipmentStatus.unavailable.toValue();

    await doc.reference.update({'status': newStatus});
    updated++;
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Migration done. Updated: $updated, Skipped (already migrated): $skipped')),
    );
  }
}

// Reverse: removes "status" field and restores "isAvailable" bool — use only if you need to rollback
Future<void> rollbackEquipmentStatus(BuildContext context) async {  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Rollback Migration?'),
      content: const Text(
        'This will remove the "status" field and restore "isAvailable" (bool) on all equipment docs. Only use this to undo the migration.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Rollback'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  final snapshot = await FirebaseFirestore.instance
      .collection('equipment')
      .get();

  int updated = 0;

  for (final doc in snapshot.docs) {
    final data = doc.data();
    final status = data['status'];

    if (status == null) continue;

    final isAvailable = status == EquipmentStatus.available.toValue();

    await doc.reference.update({
      'isAvailable': isAvailable,
      'status': FieldValue.delete(),
    });
    updated++;
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rollback done. Restored isAvailable on $updated docs.')),
    );
  }
}
// --------------- HELPER: send in-app notification ---------------
Future<void> _sendNotification({
  required String userId,
  required String title,
  required String body,
  required String type,
  Map<String, dynamic> extra = const {},
}) async {
  await FirebaseFirestore.instance
      .collection('notifications')
      .doc(userId)
      .collection('items')
      .add({
    'title': title,
    'body': body,
    'type': type,
    'read': false,
    'createdAt': FieldValue.serverTimestamp(),
    ...extra,
  });
}

// --------------- CORE LOGIC ---------------
Future<void> _scheduleMaintenance(
  BuildContext context,
  Equipment equipment,
) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // ── Step 1: Pick maintenance end date ──────────────────────
  final picked = await showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _MaintenanceDatePicker(
      equipmentName: equipment.name,
      today: today,
    ),
  );

  if (picked == null || !context.mounted) return;

  final maintenanceEnd = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
  final durationDays = maintenanceEnd.difference(today).inDays + 1;
  final isUnforeseen = durationDays > 7;

  // ── Step 2: Confirm ──────────────────────────────────────────
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
     title: Row(
        children: [
          Icon(
            isUnforeseen ? Icons.warning_amber_rounded : Icons.build_outlined,
            color: isUnforeseen ? Colors.red : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              isUnforeseen ? 'Unforeseen Maintenance' : 'Schedule Maintenance',
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Maintenance period: ${DateFormat('MMM d').format(today)} – ${DateFormat('MMM d, yyyy').format(maintenanceEnd)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '$durationDays day${durationDays > 1 ? 's' : ''}',
            style: TextStyle(
              color: isUnforeseen ? Colors.red : lightColorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          if (isUnforeseen)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Text(
                'Maintenance exceeds 7 days. All bookings within this period will be CANCELLED.',
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: lightColorScheme.secondary,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: lightColorScheme.primary),
              ),
              child: Text(
                'Bookings within this period will be rescheduled to after maintenance ends. Bookings that fall outside the equipment\'s availability will be cancelled.',
                style: TextStyle(color: lightColorScheme.primary, fontSize: 13),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isUnforeseen ? Colors.red : lightColorScheme.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  // ── Step 3: Show loading ─────────────────────────────────────
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final db = FirebaseFirestore.instance;
    final firstDayAfterMaintenance = maintenanceEnd.add(const Duration(days: 1));
    firstDayAfterMaintenance; // used below for shifting

    // ── Step 4: Update equipment in Firestore ───────────────────
    await db.collection('equipment').doc(equipment.id).update({
      'status': EquipmentStatus.underMaintenance.toValue(),
      'isAvailable': false,
      'maintenanceStart': Timestamp.fromDate(today),
      'maintenanceEnd': Timestamp.fromDate(maintenanceEnd),
    });

    // ── Step 5: Find affected bookings ───────────────────────────
    // Active statuses that can be shifted or cancelled
    const activeStatuses = [
      'pending',
      'approved',
      'readyForPickup',
    ];

    final bookingsSnap = await db
        .collection('rentRequests')
        .where('itemId', isEqualTo: equipment.id)
        .where('status', whereIn: activeStatuses)
        .get();

    final batch = db.batch();
    final List<Future<void>> notifFutures = [];

    for (final doc in bookingsSnap.docs) {
      final request = RentRequest.fromDoc(doc);

      // Only affect bookings that overlap with maintenance window
      final bookingStart = DateTime(request.start.year, request.start.month, request.start.day);
      final bookingEnd = DateTime(request.end.year, request.end.month, request.end.day);
      final maintenanceEndDay = DateTime(maintenanceEnd.year, maintenanceEnd.month, maintenanceEnd.day);

      final overlaps = bookingStart.isBefore(maintenanceEndDay.add(const Duration(days: 1)))
          && bookingEnd.isAfter(today.subtract(const Duration(days: 1)));

      if (!overlaps) continue;

      if (isUnforeseen) {
        // Cancel all bookings — unforeseen
        batch.update(doc.reference, {
          'status': RentRequestStatus.canceled.name,
          'declineReason': 'Equipment scheduled for unforeseen maintenance from '
              '${DateFormat('MMM d').format(today)} to ${DateFormat('MMM d, yyyy').format(maintenanceEnd)}. '
              'We apologize for the inconvenience.',
        });

        notifFutures.add(_sendNotification(
          userId: request.renterId,
          title: '🔧 Booking Cancelled — Maintenance',
          body: 'Your booking for "${equipment.name}" (${DateFormat('MMM d').format(request.start)} – ${DateFormat('MMM d').format(request.end)}) '
              'has been cancelled due to unforeseen maintenance (${durationDays} days). We\'re sorry for the inconvenience.',
          type: 'maintenance_cancel',
          extra: {'requestId': request.requestId, 'equipmentId': equipment.id},
        ));
      } else {
        // Shift bookings forward
        final bookingDuration = request.end.difference(request.start);
        final newStart = DateTime(
          firstDayAfterMaintenance.year,
          firstDayAfterMaintenance.month,
          firstDayAfterMaintenance.day,
          request.start.hour,
          request.start.minute,
        );
        final newEnd = newStart.add(bookingDuration);

        // Check if shifted booking exceeds equipment's availableUntil
        final exceedsAvailability = equipment.availableUntil != null &&
            newEnd.isAfter(equipment.availableUntil!);

        if (exceedsAvailability) {
          // Cancel — shifted dates fall outside availability window
          batch.update(doc.reference, {
            'status': RentRequestStatus.canceled.name,
            'declineReason': 'Your booking could not be rescheduled after maintenance '
                '(ends ${DateFormat('MMM d, yyyy').format(maintenanceEnd)}) because the new dates '
                'exceed the equipment\'s availability window.',
          });

          notifFutures.add(_sendNotification(
            userId: request.renterId,
            title: '🔧 Booking Cancelled — Outside Availability',
            body: 'Your booking for "${equipment.name}" could not be rescheduled after maintenance '
                'because the new dates (${DateFormat('MMM d').format(newStart)} – ${DateFormat('MMM d').format(newEnd)}) '
                'fall outside the equipment\'s availability. Your booking has been cancelled.',
            type: 'maintenance_cancel',
            extra: {'requestId': request.requestId, 'equipmentId': equipment.id},
          ));
        } else {
          // Reschedule
          batch.update(doc.reference, {
            'start': Timestamp.fromDate(newStart),
            'end': Timestamp.fromDate(newEnd),
            'maintenanceRescheduled': true,
          });

          notifFutures.add(_sendNotification(
            userId: request.renterId,
            title: '📅 Booking Rescheduled — Maintenance',
            body: 'Your booking for "${equipment.name}" has been moved from '
                '${DateFormat('MMM d').format(request.start)} – ${DateFormat('MMM d').format(request.end)} '
                'to ${DateFormat('MMM d').format(newStart)} – ${DateFormat('MMM d, yyyy').format(newEnd)} '
                'due to scheduled maintenance. You may cancel if the new date doesn\'t work for you.',
            type: 'maintenance_reschedule',
            extra: {
              'requestId': request.requestId,
              'equipmentId': equipment.id,
              'canCancel': true,
              'newStart': Timestamp.fromDate(newStart),
              'newEnd': Timestamp.fromDate(newEnd),
            },
          ));
        }
      }
    }

    await batch.commit();
    await Future.wait(notifFutures);

    if (context.mounted) Navigator.pop(context); // dismiss loading

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUnforeseen
                ? '⚠️ Maintenance set. Affected bookings have been cancelled.'
                : '✅ Maintenance scheduled. Affected bookings have been rescheduled.',
          ),
          backgroundColor: isUnforeseen ? Colors.red : Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) Navigator.pop(context); // dismiss loading
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// End maintenance (mark as available)
Future<void> _endMaintenance(
  BuildContext context,
  Equipment equipment,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('End Maintenance'),
      content: const Text('Mark this equipment as available again?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Mark Available'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  await FirebaseFirestore.instance.collection('equipment').doc(equipment.id).update({
    'status': EquipmentStatus.available.toValue(),
    'isAvailable': true,
    'maintenanceStart': null,
    'maintenanceEnd': null,
  });

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Equipment is now available.'),
        backgroundColor: Colors.green,
      ),
    );
  }
}


}

// ============================================================
// PART 3: Bottom sheet date picker widget
// ============================================================

class _MaintenanceDatePicker extends StatefulWidget {
  final String equipmentName;
  final DateTime today;

  const _MaintenanceDatePicker({
    required this.equipmentName,
    required this.today,
  });

  @override
  State<_MaintenanceDatePicker> createState() => _MaintenanceDatePickerState();
}

class _MaintenanceDatePickerState extends State<_MaintenanceDatePicker> {
  DateTime? _selectedEnd;

  int get _durationDays =>
      _selectedEnd == null ? 0 : _selectedEnd!.difference(widget.today).inDays + 1;

  bool get _isUnforeseen => _durationDays > 7;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.build_outlined, color: lightColorScheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Schedule Maintenance',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.equipmentName,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Start date (fixed = today)
          _DateRow(
            label: 'Start Date',
            value: DateFormat('EEEE, MMM d, yyyy').format(widget.today),
            icon: Icons.today,
            color: Colors.blue,
            isFixed: true,
          ),
          const SizedBox(height: 12),

          // End date picker
          _DateRow(
            label: 'End Date',
            value: _selectedEnd != null
                ? DateFormat('EEEE, MMM d, yyyy').format(_selectedEnd!)
                : 'Tap to select',
            icon: Icons.event,
            color: Colors.orange,
            isFixed: false,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: widget.today.add(const Duration(days: 1)),
                firstDate: widget.today.add(const Duration(days: 1)),
                lastDate: widget.today.add(const Duration(days: 365)),
                helpText: 'Select maintenance end date',
              );
              if (picked != null) {
                setState(() => _selectedEnd = picked);
              }
            },
          ),

          // Duration indicator
          if (_selectedEnd != null) ...[
            const SizedBox(height: 16),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _isUnforeseen ? Colors.red.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isUnforeseen ? Colors.red.shade300 : Colors.orange.shade300,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isUnforeseen ? Icons.warning_amber_rounded : Icons.info_outline,
                    color: _isUnforeseen ? Colors.red : Colors.orange.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isUnforeseen
                          ? '$_durationDays days — Unforeseen maintenance. All bookings will be CANCELLED.'
                          : '$_durationDays day${_durationDays > 1 ? 's' : ''} — Bookings will be rescheduled after maintenance.',
                      style: TextStyle(
                        color: _isUnforeseen ? Colors.red.shade700 : Colors.orange.shade800,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedEnd == null
                      ? null
                      : () => Navigator.pop(context, _selectedEnd),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isUnforeseen
                        ? Colors.red
                        : Colors.orange.shade600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isFixed;
  final VoidCallback? onTap;

  const _DateRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isFixed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isFixed ? Colors.grey.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isFixed ? Colors.grey.shade300 : color.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isFixed ? Colors.grey.shade600 : Colors.black87,
                  ),
                ),
              ],
            ),
            if (!isFixed) ...[
              const Spacer(),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}