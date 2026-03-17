import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestoreService nearby dashboard logic', () {
    final service = FirestoreService();

    test('calculateDistanceKm returns expected rough value', () {
      final km = service.calculateDistanceKm(
        fromLat: 0,
        fromLng: 0,
        toLat: 1,
        toLng: 0,
      );

      expect(km, greaterThan(110));
      expect(km, lessThan(112));
    });

    test('isEquipmentEffectivelyAvailable honors status and end date', () {
      final available = _equipment(
        id: 'available',
        status: EquipmentStatus.available,
        availableUntil: DateTime(2030, 1, 1),
      );
      final unavailableStatus = _equipment(
        id: 'unavailable_status',
        status: EquipmentStatus.unavailable,
        availableUntil: DateTime(2030, 1, 1),
      );
      final expired = _equipment(
        id: 'expired',
        status: EquipmentStatus.available,
        availableUntil: DateTime(2020, 1, 1),
      );

      expect(service.isEquipmentEffectivelyAvailable(available), isTrue);
      expect(
        service.isEquipmentEffectivelyAvailable(unavailableStatus),
        isFalse,
      );
      expect(service.isEquipmentEffectivelyAvailable(expired), isFalse);
    });

    test(
      'nearby-only excludes own, out-of-radius, and missing coordinates',
      () {
        final originLat = 14.2470;
        final originLng = 121.1367;

        final results = service.buildDashboardNearbyResults(
          equipmentList: [
            _equipment(
              id: 'own-item',
              ownerId: 'me',
              latitude: 14.2472,
              longitude: 121.1369,
            ),
            _equipment(
              id: 'near-item',
              ownerId: 'other',
              latitude: 14.2472,
              longitude: 121.1369,
            ),
            _equipment(
              id: 'far-item',
              ownerId: 'other',
              latitude: 14.6472,
              longitude: 121.5369,
            ),
            _equipment(
              id: 'no-coords',
              ownerId: 'other',
              latitude: null,
              longitude: null,
            ),
          ],
          currentUserId: 'me',
          originLat: originLat,
          originLng: originLng,
          nearbyOnly: true,
          radiusKm: 10,
          sortByDistanceWhenNearbyEnabled: true,
        );

        expect(results.length, 1);
        expect(results.first.equipment.id, 'near-item');
        expect(results.first.distanceKm, isNotNull);
      },
    );

    test('non-nearby mode can include items without coordinates', () {
      final results = service.buildDashboardNearbyResults(
        equipmentList: [
          _equipment(
            id: 'with-coords',
            ownerId: 'other',
            category: 'Tractor',
            latitude: 14.2472,
            longitude: 121.1369,
          ),
          _equipment(
            id: 'without-coords',
            ownerId: 'other',
            category: 'Tractor',
            latitude: null,
            longitude: null,
          ),
        ],
        currentUserId: 'me',
        originLat: 14.2470,
        originLng: 121.1367,
        nearbyOnly: false,
        radiusKm: 10,
        sortByDistanceWhenNearbyEnabled: true,
        allowedCategories: {'Tractor'},
        includeWithoutCoordinatesWhenNearbyDisabled: true,
      );

      expect(results.length, 2);
      expect(results.any((r) => r.equipment.id == 'without-coords'), isTrue);
      expect(
        results
            .firstWhere((r) => r.equipment.id == 'without-coords')
            .distanceKm,
        isNull,
      );
    });

    test('nearby-only sort orders items by nearest distance', () {
      final results = service.buildDashboardNearbyResults(
        equipmentList: [
          _equipment(
            id: 'mid',
            ownerId: 'other',
            latitude: 14.3000,
            longitude: 121.1367,
          ),
          _equipment(
            id: 'near',
            ownerId: 'other',
            latitude: 14.2480,
            longitude: 121.1368,
          ),
          _equipment(
            id: 'far',
            ownerId: 'other',
            latitude: 14.5000,
            longitude: 121.1367,
          ),
        ],
        currentUserId: 'me',
        originLat: 14.2470,
        originLng: 121.1367,
        nearbyOnly: true,
        radiusKm: 100,
        sortByDistanceWhenNearbyEnabled: true,
      );

      expect(results.map((r) => r.equipment.id).toList(), [
        'near',
        'mid',
        'far',
      ]);
    });
  });
}

Equipment _equipment({
  required String id,
  String ownerId = 'owner',
  EquipmentStatus status = EquipmentStatus.available,
  DateTime? availableUntil,
  String? category = 'Tractor',
  double? latitude = 14.2472,
  double? longitude = 121.1369,
}) {
  return Equipment(
    id: id,
    name: 'Equipment $id',
    description: 'Description for $id',
    category: category,
    condition: 'Good',
    price: 1000,
    rentalUnit: 'Per Day',
    landSizeRequirement: false,
    maxCropHeightRequirement: false,
    status: status,
    availableFrom: DateTime(2024, 1, 1),
    availableUntil: availableUntil ?? DateTime(2030, 1, 1),
    ownerId: ownerId,
    latitude: latitude,
    longitude: longitude,
  );
}
