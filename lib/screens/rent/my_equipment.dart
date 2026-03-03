import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/screens/rent/equipment_listing_form_screen.dart';
import 'package:bukidbayan_app/screens/rent/product_page.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
                      // Maintenance Toggle Button
SizedBox(
  width: 90,
  child: ElevatedButton.icon(
   onPressed: equipment.status == EquipmentStatus.unavailable
    ? null
    : () async {
        final action = equipment.status == EquipmentStatus.available
            ? 'set to maintenance'
            : 'mark as available';
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Confirm'),
                content: Text(
                    'Do you want to $action this equipment?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Confirm'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await _toggleMaintenance(equipment);
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
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 6),
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

}