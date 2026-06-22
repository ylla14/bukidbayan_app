import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/services/maintenance_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MaintenanceService', () {
    test('logs usage, scheduled maintenance, and completion history', () async {
      final firestore = FakeFirebaseFirestore();
      final service = MaintenanceService(firestore: firestore);

      final equipment = Equipment(
        id: 'eq-1',
        name: 'Four-wheel Tractor',
        description: 'Equipment for testing',
        category: 'Tractor',
        condition: 'Good',
        price: 2500,
        rentalUnit: 'Per Day',
        landSizeRequirement: false,
        maxCropHeightRequirement: false,
        ownerId: 'owner-1',
        status: EquipmentStatus.available,
        hoursUsedSinceLastMaintenance: 72,
      );

      await firestore.collection('equipment').doc(equipment.id).set({
        ...equipment.toMap(),
        'hoursUsedSinceLastMaintenance': 72,
      });

      await service.logRentalUsage(
        equipmentId: equipment.id!,
        ownerId: equipment.ownerId,
        equipmentName: equipment.name,
        rentalDays: 2,
      );

      var equipmentDoc = await firestore
          .collection('equipment')
          .doc(equipment.id)
          .get();
      expect(
        (equipmentDoc.data()!['hoursUsedSinceLastMaintenance'] as num)
            .toDouble(),
        120,
      );

      await service.markEquipmentUnderMaintenance(
        equipment: equipment,
        maintenanceStart: DateTime(2026, 6, 22),
        maintenanceEnd: DateTime(2026, 6, 24, 23, 59, 59),
        isUnforeseen: false,
      );

      equipmentDoc = await firestore
          .collection('equipment')
          .doc(equipment.id)
          .get();
      expect(equipmentDoc.data()!['status'], 'under_maintenance');

      await service.completeMaintenance(equipment: equipment);

      equipmentDoc = await firestore
          .collection('equipment')
          .doc(equipment.id)
          .get();
      expect(equipmentDoc.data()!['status'], 'available');
      expect(
        (equipmentDoc.data()!['hoursUsedSinceLastMaintenance'] as num)
            .toDouble(),
        0,
      );

      final logs = await firestore
          .collection('equipment')
          .doc(equipment.id)
          .collection('maintenance_logs')
          .get();
      final eventTypes = logs.docs
          .map((doc) => doc.data()['eventType'] as String)
          .toList();

      expect(eventTypes, contains('usage_increment'));
      expect(eventTypes, contains('maintenance_scheduled'));
      expect(eventTypes, contains('maintenance_completed'));
    });
  });
}
