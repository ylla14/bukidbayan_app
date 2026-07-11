import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/services/analytics/renter_analytics_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Equipment _equipment({
  required String id,
  required String ownerId,
  required String name,
  required String category,
}) {
  return Equipment(
    id: id,
    name: name,
    description: '$name description',
    category: category,
    condition: 'Good',
    price: 2500,
    rentalUnit: 'Per Day',
    landSizeRequirement: false,
    maxCropHeightRequirement: false,
    ownerId: ownerId,
    createdAt: DateTime(2026, 1, 1),
  );
}

RentRequest _request({
  required String requestId,
  required String itemId,
  required String itemName,
  required String renterId,
  required String ownerId,
  required RentRequestStatus status,
  required DateTime createdAt,
  required DateTime start,
  required DateTime end,
  bool weatherFlag = false,
  double? agreedPrice,
  double? estimatedMillingFee,
}) {
  return RentRequest(
    requestId: requestId,
    itemId: itemId,
    itemName: itemName,
    name: 'Farmer $renterId',
    address: 'Barangay Test',
    start: start,
    end: end,
    status: status,
    renterId: renterId,
    ownerId: ownerId,
    createdAt: createdAt,
    weatherFlag: weatherFlag,
    agreedPrice: agreedPrice,
    estimatedMillingFee: estimatedMillingFee,
    farmAddress: 'Barangay Test',
  );
}

Future<void> _seedRequest(
  FakeFirebaseFirestore firestore,
  RentRequest request,
) async {
  await firestore.collection('rentRequests').doc(request.requestId).set({
    ...request.toMap(),
    'createdAt': Timestamp.fromDate(request.createdAt!),
    'weatherFlag': request.weatherFlag,
    'weatherFlagDates': <Timestamp>[],
  });
}

void main() {
  group('RenterAnalyticsService.generateReport', () {
    test('computes renter summary, spending, and category usage', () async {
      final firestore = FakeFirebaseFirestore();
      final service = RenterAnalyticsService(firestore: firestore);

      final tractor = _equipment(
        id: 'eq-1',
        ownerId: 'owner-1',
        name: 'Four-wheel Tractor',
        category: 'Tractors',
      );
      final harvester = _equipment(
        id: 'eq-2',
        ownerId: 'owner-2',
        name: 'Combine Harvester',
        category: 'Harvesters',
      );
      final sprayer = _equipment(
        id: 'eq-3',
        ownerId: 'owner-3',
        name: 'Power Sprayer',
        category: 'Crop Care',
      );

      await firestore
          .collection('equipment')
          .doc(tractor.id)
          .set(tractor.toMap());
      await firestore
          .collection('equipment')
          .doc(harvester.id)
          .set(harvester.toMap());
      await firestore
          .collection('equipment')
          .doc(sprayer.id)
          .set(sprayer.toMap());

      await _seedRequest(
        firestore,
        _request(
          requestId: 'r1',
          itemId: tractor.id!,
          itemName: tractor.name,
          renterId: 'renter-1',
          ownerId: 'owner-1',
          status: RentRequestStatus.completed,
          createdAt: DateTime(2026, 4, 1),
          start: DateTime(2026, 4, 5),
          end: DateTime(2026, 4, 7),
          agreedPrice: 5000,
        ),
      );
      await _seedRequest(
        firestore,
        _request(
          requestId: 'r2',
          itemId: harvester.id!,
          itemName: harvester.name,
          renterId: 'renter-1',
          ownerId: 'owner-2',
          status: RentRequestStatus.finished,
          createdAt: DateTime(2026, 4, 10),
          start: DateTime(2026, 4, 12),
          end: DateTime(2026, 4, 13),
          estimatedMillingFee: 1800,
        ),
      );
      await _seedRequest(
        firestore,
        _request(
          requestId: 'r3',
          itemId: sprayer.id!,
          itemName: sprayer.name,
          renterId: 'renter-1',
          ownerId: 'owner-3',
          status: RentRequestStatus.approved,
          createdAt: DateTime(2026, 4, 14),
          start: DateTime(2026, 4, 16),
          end: DateTime(2026, 4, 17),
          weatherFlag: true,
          agreedPrice: 900,
        ),
      );
      await _seedRequest(
        firestore,
        _request(
          requestId: 'r4',
          itemId: tractor.id!,
          itemName: tractor.name,
          renterId: 'renter-1',
          ownerId: 'owner-1',
          status: RentRequestStatus.canceled,
          createdAt: DateTime(2026, 4, 15),
          start: DateTime(2026, 4, 18),
          end: DateTime(2026, 4, 19),
        ),
      );
      await _seedRequest(
        firestore,
        _request(
          requestId: 'r5',
          itemId: sprayer.id!,
          itemName: sprayer.name,
          renterId: 'renter-1',
          ownerId: 'owner-3',
          status: RentRequestStatus.declined,
          createdAt: DateTime(2026, 4, 16),
          start: DateTime(2026, 4, 20),
          end: DateTime(2026, 4, 21),
        ),
      );
      await _seedRequest(
        firestore,
        _request(
          requestId: 'r6',
          itemId: sprayer.id!,
          itemName: sprayer.name,
          renterId: 'other-renter',
          ownerId: 'owner-3',
          status: RentRequestStatus.completed,
          createdAt: DateTime(2026, 4, 18),
          start: DateTime(2026, 4, 19),
          end: DateTime(2026, 4, 21),
          agreedPrice: 7000,
        ),
      );

      final report = await service.generateReport(renterId: 'renter-1');

      expect(report.renterId, 'renter-1');
      expect(report.summary.totalRequests, 5);
      expect(report.summary.completedRentals, 2);
      expect(report.summary.activeRentals, 1);
      expect(report.summary.pendingRequests, 0);
      expect(report.summary.cancelledRequests, 1);
      expect(report.summary.declinedRequests, 1);
      expect(report.summary.cancelledOrDeclinedRequests, 2);
      expect(report.summary.weatherRiskBookings, 1);
      expect(report.summary.totalSpending, 6800);
      expect(report.summary.averageRentalDurationDays, closeTo(1.5, 0.01));
      expect(report.firstRequestAt, DateTime(2026, 4, 1));
      expect(report.lastRequestAt, DateTime(2026, 4, 16));

      expect(report.categoryUsage.length, 3);
      expect(report.categoryUsage.first.categoryLabel, 'Tractors');
      expect(report.categoryUsage.first.requestCount, 2);
      expect(report.categoryUsage.first.completedRentals, 1);
      expect(report.categoryUsage.first.totalSpending, 5000);

      expect(report.categoryUsage[1].categoryLabel, 'Crop Care');
      expect(report.categoryUsage[1].requestCount, 2);
      expect(report.categoryUsage[1].completedRentals, 0);
      expect(report.categoryUsage[1].totalSpending, 0);

      expect(report.categoryUsage[2].categoryLabel, 'Harvesters');
      expect(report.categoryUsage[2].requestCount, 1);
      expect(report.categoryUsage[2].completedRentals, 1);
      expect(report.categoryUsage[2].totalSpending, 1800);
    });

    test('returns empty analytics for renters with no requests', () async {
      final firestore = FakeFirebaseFirestore();
      final service = RenterAnalyticsService(firestore: firestore);

      final report = await service.generateReport(renterId: 'missing-renter');

      expect(report.summary.totalRequests, 0);
      expect(report.summary.completedRentals, 0);
      expect(report.summary.totalSpending, 0);
      expect(report.categoryUsage, isEmpty);
      expect(report.firstRequestAt, isNull);
      expect(report.lastRequestAt, isNull);
    });
  });
}
