import 'package:bukidbayan_app/components/dashboard/map_section.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MapSection nearby QA scenarios', () {
    testWidgets('home+farm coordinates show nearby results', (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          userContext: const DashboardUserContext(
            homeAddress: 'Home',
            farmAddress: 'Farm',
            homeLatitude: 14.25,
            homeLongitude: 121.13,
            farmLatitude: 14.2470,
            farmLongitude: 121.1367,
            cropPreferences: [],
          ),
          equipment: [
            _equipment(
              id: 'nearby',
              name: 'Nearby Tractor',
              latitude: 14.2478,
              longitude: 121.1369,
            ),
            _equipment(
              id: 'far',
              name: 'Far Harvester',
              latitude: 15.2470,
              longitude: 122.1367,
            ),
          ],
        ),
      );

      await _pumpMapSection(tester);

      expect(find.text('Nearby Equipment'), findsOneWidget);
      expect(find.text('Nearby Tractor'), findsOneWidget);
      expect(find.text('Farm'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Far Harvester'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('home-only coordinates still work', (tester) async {
      await tester.pumpWidget(
        _buildHarness(
          userContext: const DashboardUserContext(
            homeAddress: 'Home',
            farmAddress: null,
            homeLatitude: 14.2470,
            homeLongitude: 121.1367,
            farmLatitude: null,
            farmLongitude: null,
            cropPreferences: [],
          ),
          equipment: [
            _equipment(
              id: 'home-only-nearby',
              name: 'Home Nearby Seeder',
              latitude: 14.2474,
              longitude: 121.1366,
            ),
          ],
        ),
      );

      await _pumpMapSection(tester);

      expect(find.text('Nearby Equipment'), findsOneWidget);
      expect(find.text('Home Nearby Seeder'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Farm'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('no coordinates show prompt and fallback works', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildHarness(
          userContext: const DashboardUserContext(
            homeAddress: null,
            farmAddress: null,
            homeLatitude: null,
            homeLongitude: null,
            farmLatitude: null,
            farmLongitude: null,
            cropPreferences: [],
          ),
          equipment: [
            _equipment(
              id: 'fallback-item',
              name: 'Fallback Planter',
              latitude: 14.2474,
              longitude: 121.1366,
            ),
          ],
        ),
      );

      await _pumpMapSection(tester);

      expect(find.text('Nearby Equipment'), findsOneWidget);
      expect(find.text('Missing location'), findsOneWidget);

      await tester.tap(find.byType(Switch).first);
      await _pumpMapSection(tester);

      expect(find.text('Fallback Planter'), findsOneWidget);
      expect(find.text('Location not set'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _buildHarness({
  required DashboardUserContext userContext,
  required List<Equipment> equipment,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: MapSection(
            currentUserId: 'test-user',
            userContextLoader: (_) async => userContext,
            equipmentStreamBuilder: () => Stream.value(equipment),
            showMapTiles: false,
          ),
        ),
      ),
    ),
  );
}

Future<void> _pumpMapSection(WidgetTester tester) async {
  await tester.pump();
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Equipment _equipment({
  required String id,
  required String name,
  required double? latitude,
  required double? longitude,
  String ownerId = 'owner',
}) {
  return Equipment(
    id: id,
    name: name,
    description: 'Description',
    category: 'Tractor',
    condition: 'Good',
    price: 1000,
    rentalUnit: 'Per Day',
    landSizeRequirement: false,
    maxCropHeightRequirement: false,
    status: EquipmentStatus.available,
    availableFrom: DateTime(2024, 1, 1),
    availableUntil: DateTime(2030, 1, 1),
    ownerId: ownerId,
    latitude: latitude,
    longitude: longitude,
  );
}
