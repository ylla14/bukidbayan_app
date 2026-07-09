import 'package:bukidbayan_app/models/analytics_time_window.dart';
import 'package:bukidbayan_app/models/demand_forecast.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/owner_rental_report.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/services/analytics/rental_analytics_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Equipment _equipment({
  required String id,
  required String ownerId,
  required String name,
  required String category,
  required bool operatorIncluded,
  required EquipmentStatus status,
  required double hoursUsedSinceLastMaintenance,
  DateTime? availableFrom,
  DateTime? availableUntil,
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
    operatorIncluded: operatorIncluded,
    status: status,
    availableFrom: availableFrom,
    availableUntil: availableUntil,
    ownerId: ownerId,
    createdAt: DateTime(2026, 1, 1),
    maintenanceIntervalHrs: 240,
    hoursUsedSinceLastMaintenance: hoursUsedSinceLastMaintenance,
  );
}

RentRequest _request({
  required String requestId,
  required String itemId,
  required String itemName,
  required String renterId,
  required String renterName,
  required String ownerId,
  required DateTime start,
  required DateTime end,
  double? agreedPrice,
  double? estimatedMillingFee,
  String? agreedRentalUnit = 'Per Day',
}) {
  return RentRequest(
    requestId: requestId,
    itemId: itemId,
    itemName: itemName,
    name: renterName,
    address: 'Farm address',
    start: start,
    end: end,
    status: RentRequestStatus.completed,
    renterId: renterId,
    ownerId: ownerId,
    createdAt: start.subtract(const Duration(days: 1)),
    agreedPrice: agreedPrice,
    estimatedMillingFee: estimatedMillingFee,
    agreedRentalUnit: agreedRentalUnit,
    farmAddress: 'Barangay Test',
  );
}

void main() {
  group('RentalAnalyticsService.buildOwnerRentalReport', () {
    test(
      'computes summary, maintenance, grouping, and utilization metrics',
      () {
        final service = RentalAnalyticsService(
          firestore: FakeFirebaseFirestore(),
          now: () => DateTime(2026, 1, 31),
        );

        final tractor = _equipment(
          id: 'eq-1',
          ownerId: 'owner-1',
          name: 'Four-wheel Tractor',
          category: 'Mechanized Tools',
          operatorIncluded: true,
          status: EquipmentStatus.available,
          hoursUsedSinceLastMaintenance: 250,
          availableFrom: DateTime(2026, 1, 1),
          availableUntil: DateTime(2026, 1, 31),
        );
        final mill = _equipment(
          id: 'eq-2',
          ownerId: 'owner-1',
          name: 'Rice Mill',
          category: 'Post-harvest',
          operatorIncluded: false,
          status: EquipmentStatus.underMaintenance,
          hoursUsedSinceLastMaintenance: 210,
          availableFrom: DateTime(2026, 1, 1),
          availableUntil: DateTime(2026, 1, 31),
        );

        final source = OwnerRentalReportSource(
          ownerId: 'owner-1',
          rows: [
            OwnerRentalTransactionRow(
              request: _request(
                requestId: 'r1',
                itemId: tractor.id!,
                itemName: tractor.name,
                renterId: 'farmer-a',
                renterName: 'Ana Farmer',
                ownerId: 'owner-1',
                start: DateTime(2026, 1, 2),
                end: DateTime(2026, 1, 4),
                agreedPrice: 5000,
              ),
              equipment: tractor,
            ),
            OwnerRentalTransactionRow(
              request: _request(
                requestId: 'r2',
                itemId: tractor.id!,
                itemName: tractor.name,
                renterId: 'farmer-b',
                renterName: 'Ben Grower',
                ownerId: 'owner-1',
                start: DateTime(2026, 1, 10),
                end: DateTime(2026, 1, 11),
                agreedPrice: 2500,
              ),
              equipment: tractor,
            ),
            OwnerRentalTransactionRow(
              request: _request(
                requestId: 'r3',
                itemId: mill.id!,
                itemName: mill.name,
                renterId: 'farmer-a',
                renterName: 'Ana Farmer',
                ownerId: 'owner-1',
                start: DateTime(2026, 1, 15),
                end: DateTime(2026, 1, 16),
                estimatedMillingFee: 1800,
                agreedRentalUnit: 'Per KG',
              ),
              equipment: mill,
            ),
          ],
          ownedEquipment: [tractor, mill],
          forecastRequests: [
            _request(
              requestId: 'r1',
              itemId: tractor.id!,
              itemName: tractor.name,
              renterId: 'farmer-a',
              renterName: 'Ana Farmer',
              ownerId: 'owner-1',
              start: DateTime(2026, 1, 2),
              end: DateTime(2026, 1, 4),
              agreedPrice: 5000,
            ).copyWith(
              cropType: 'Rice',
              farmingPhase: 'Land preparation',
              intendedUse: 'Plowing',
            ),
            _request(
              requestId: 'r2',
              itemId: tractor.id!,
              itemName: tractor.name,
              renterId: 'farmer-b',
              renterName: 'Ben Grower',
              ownerId: 'owner-1',
              start: DateTime(2026, 1, 10),
              end: DateTime(2026, 1, 11),
              agreedPrice: 2500,
            ),
            _request(
              requestId: 'r3',
              itemId: mill.id!,
              itemName: mill.name,
              renterId: 'farmer-a',
              renterName: 'Ana Farmer',
              ownerId: 'owner-1',
              start: DateTime(2026, 1, 15),
              end: DateTime(2026, 1, 16),
              estimatedMillingFee: 1800,
              agreedRentalUnit: 'Per KG',
            ).copyWith(
              cropType: 'Rice',
              farmingPhase: 'Post-harvest',
              intendedUse: 'Milling',
            ),
          ],
          equipmentById: {tractor.id!: tractor, mill.id!: mill},
        );

        final report = service.buildOwnerRentalReport(
          source: source,
          filter: OwnerRentalReportFilter(
            timeWindow: AnalyticsTimeWindow(
              start: DateTime(2026, 1, 1),
              end: DateTime(2026, 1, 31),
            ),
          ),
        );

        expect(report.summary.totalEarnings, 9300);
        expect(report.summary.completedRentals, 3);
        expect(report.summary.uniqueFarmersServed, 2);
        expect(report.summary.totalBookedDays, 4);
        expect(report.summary.estimatedBookedHours, 96);
        expect(report.summary.averageRentalDurationDays, closeTo(1.33, 0.01));

        expect(report.maintenanceSnapshot.totalOwnedEquipment, 2);
        expect(report.maintenanceSnapshot.dueCount, 1);
        expect(report.maintenanceSnapshot.upcomingCount, 1);
        expect(report.maintenanceSnapshot.underMaintenanceCount, 1);

        expect(report.equipmentPerformance.length, 2);
        expect(report.equipmentPerformance.first.itemId, 'eq-1');
        expect(report.equipmentPerformance.first.totalEarnings, 7500);
        expect(report.equipmentPerformance.first.completedRentals, 2);
        expect(report.equipmentPerformance.first.bookedDays, 3);
        expect(report.equipmentPerformance.first.estimatedBookedHours, 72);

        expect(report.categoryPerformance.length, 2);
        expect(
          report.categoryPerformance.first.categoryLabel,
          'Mechanized Tools',
        );
        expect(report.categoryPerformance.first.totalEarnings, 7500);

        expect(report.utilizationItems.length, 2);
        expect(
          report.utilizationItems.first.utilizationRate,
          closeTo(72 / 744, 0.0001),
        );
        expect(report.utilizationItems.first.schedulableHours, 744);

        expect(report.forecastSnapshot.requestsConsidered, 3);
        expect(report.forecastSnapshot.requestsWithForecastInputs, 2);
        expect(
          report.forecastSnapshot.confidence,
          DemandForecastConfidence.medium,
        );
        expect(report.forecastSnapshot.hasInsights, isTrue);
        expect(
          report.forecastSnapshot.categoryInsights.any(
            (item) => item.equipmentCategory == 'Mechanized Tools',
          ),
          isTrue,
        );
        expect(
          report.forecastSnapshot.equipmentMatches.any(
            (item) => item.equipmentId == 'eq-1',
          ),
          isTrue,
        );
        expect(
          report.forecastSnapshot.equipmentTrends.any(
            (item) =>
                item.equipmentId == 'eq-1' &&
                item.trend == OwnerRentalDemandTrend.steady,
          ),
          isTrue,
        );
      },
    );

    test('applies equipment, operator, payment, and search filters', () {
      final service = RentalAnalyticsService(
        firestore: FakeFirebaseFirestore(),
        now: () => DateTime(2026, 2, 10),
      );

      final tractor = _equipment(
        id: 'eq-1',
        ownerId: 'owner-1',
        name: 'Four-wheel Tractor',
        category: 'Mechanized Tools',
        operatorIncluded: true,
        status: EquipmentStatus.available,
        hoursUsedSinceLastMaintenance: 120,
      );
      final mill = _equipment(
        id: 'eq-2',
        ownerId: 'owner-1',
        name: 'Rice Mill',
        category: 'Post-harvest',
        operatorIncluded: false,
        status: EquipmentStatus.available,
        hoursUsedSinceLastMaintenance: 50,
      );

      final source = OwnerRentalReportSource(
        ownerId: 'owner-1',
        rows: [
          OwnerRentalTransactionRow(
            request: _request(
              requestId: 'r1',
              itemId: 'eq-1',
              itemName: 'Four-wheel Tractor',
              renterId: 'farmer-a',
              renterName: 'Ana Farmer',
              ownerId: 'owner-1',
              start: DateTime(2026, 2, 1),
              end: DateTime(2026, 2, 3),
              agreedPrice: 5000,
            ),
            equipment: tractor,
          ),
          OwnerRentalTransactionRow(
            request: _request(
              requestId: 'r2',
              itemId: 'eq-1',
              itemName: 'Four-wheel Tractor',
              renterId: 'farmer-b',
              renterName: 'Ben Grower',
              ownerId: 'owner-1',
              start: DateTime(2026, 2, 5),
              end: DateTime(2026, 2, 6),
              agreedPrice: 2200,
            ),
            equipment: tractor,
          ),
          OwnerRentalTransactionRow(
            request: _request(
              requestId: 'r3',
              itemId: 'eq-2',
              itemName: 'Rice Mill',
              renterId: 'farmer-c',
              renterName: 'Cara Miller',
              ownerId: 'owner-1',
              start: DateTime(2026, 2, 7),
              end: DateTime(2026, 2, 8),
              estimatedMillingFee: 1800,
              agreedRentalUnit: 'Per KG',
            ),
            equipment: mill,
          ),
        ],
        ownedEquipment: [tractor, mill],
      );

      final report = service.buildOwnerRentalReport(
        source: source,
        filter: OwnerRentalReportFilter(
          searchQuery: 'Ana',
          equipmentId: 'eq-1',
          operatorFilter: OwnerOperatorFilter.withOperator,
          minPayment: 3000,
        ),
      );

      expect(report.filteredRows.length, 1);
      expect(report.summary.totalEarnings, 5000);
      expect(report.summary.completedRentals, 1);
      expect(report.scopedEquipment.length, 1);
      expect(report.scopedEquipment.single.id, 'eq-1');
      expect(report.forecastSnapshot.requestsConsidered, 0);
    });

    test('builds demand trends per owner tool from recent windows', () {
      final service = RentalAnalyticsService(
        firestore: FakeFirebaseFirestore(),
        now: () => DateTime(2026, 6, 23),
      );

      final tractor = _equipment(
        id: 'eq-1',
        ownerId: 'owner-1',
        name: 'Four-wheel Tractor',
        category: 'Mechanized Tools',
        operatorIncluded: true,
        status: EquipmentStatus.available,
        hoursUsedSinceLastMaintenance: 120,
      );
      final mill = _equipment(
        id: 'eq-2',
        ownerId: 'owner-1',
        name: 'Rice Mill',
        category: 'Post-harvest',
        operatorIncluded: false,
        status: EquipmentStatus.available,
        hoursUsedSinceLastMaintenance: 80,
      );

      final source = OwnerRentalReportSource(
        ownerId: 'owner-1',
        rows: const [],
        ownedEquipment: [tractor, mill],
        forecastRequests: [
          _request(
            requestId: 'recent-1',
            itemId: 'eq-1',
            itemName: tractor.name,
            renterId: 'farmer-a',
            renterName: 'Ana Farmer',
            ownerId: 'owner-1',
            start: DateTime(2026, 6, 10),
            end: DateTime(2026, 6, 11),
            agreedPrice: 3000,
          ),
          _request(
            requestId: 'historical-june',
            itemId: 'eq-1',
            itemName: tractor.name,
            renterId: 'farmer-z',
            renterName: 'Zed Farmer',
            ownerId: 'owner-1',
            start: DateTime(2025, 6, 9),
            end: DateTime(2025, 6, 10),
            agreedPrice: 2600,
          ),
          _request(
            requestId: 'recent-2',
            itemId: 'eq-1',
            itemName: tractor.name,
            renterId: 'farmer-b',
            renterName: 'Ben Grower',
            ownerId: 'owner-1',
            start: DateTime(2026, 6, 18),
            end: DateTime(2026, 6, 19),
            agreedPrice: 2800,
          ),
          _request(
            requestId: 'previous-1',
            itemId: 'eq-1',
            itemName: tractor.name,
            renterId: 'farmer-c',
            renterName: 'Cara Farmer',
            ownerId: 'owner-1',
            start: DateTime(2026, 5, 8),
            end: DateTime(2026, 5, 9),
            agreedPrice: 2500,
          ),
          _request(
            requestId: 'previous-2',
            itemId: 'eq-2',
            itemName: mill.name,
            renterId: 'farmer-d',
            renterName: 'Dino Miller',
            ownerId: 'owner-1',
            start: DateTime(2026, 5, 12),
            end: DateTime(2026, 5, 13),
            estimatedMillingFee: 1600,
            agreedRentalUnit: 'Per KG',
          ),
          _request(
            requestId: 'previous-3',
            itemId: 'eq-2',
            itemName: mill.name,
            renterId: 'farmer-e',
            renterName: 'Ella Miller',
            ownerId: 'owner-1',
            start: DateTime(2026, 5, 20),
            end: DateTime(2026, 5, 21),
            estimatedMillingFee: 1700,
            agreedRentalUnit: 'Per KG',
          ),
          _request(
            requestId: 'recent-mill',
            itemId: 'eq-2',
            itemName: mill.name,
            renterId: 'farmer-f',
            renterName: 'Faye Miller',
            ownerId: 'owner-1',
            start: DateTime(2026, 6, 5),
            end: DateTime(2026, 6, 6),
            estimatedMillingFee: 1750,
            agreedRentalUnit: 'Per KG',
          ),
        ],
        equipmentById: {tractor.id!: tractor, mill.id!: mill},
      );

      final report = service.buildOwnerRentalReport(source: source);

      expect(report.forecastSnapshot.equipmentTrends.length, 2);
      expect(report.forecastSnapshot.risingTrendCount, 1);
      expect(report.forecastSnapshot.softeningTrendCount, 1);
      expect(
        report.forecastSnapshot.equipmentTrends.any(
          (item) =>
              item.equipmentId == 'eq-1' &&
              item.trend == OwnerRentalDemandTrend.rising &&
              item.recentRequestCount == 2 &&
              item.previousRequestCount == 1 &&
              item.sameMonthHistoricalCount == 3 &&
              item.peakMonthLabel == 'June' &&
              item.peakMonthRequestCount == 3 &&
              item.isCurrentMonthPeak &&
              item.isCurrentMonthAboveAverage &&
              item.note.contains('June'),
        ),
        isTrue,
      );
      expect(
        report.forecastSnapshot.equipmentTrends.any(
          (item) =>
              item.equipmentId == 'eq-2' &&
              item.trend == OwnerRentalDemandTrend.softening &&
              item.recentRequestCount == 1 &&
              item.previousRequestCount == 2,
        ),
        isTrue,
      );
    });
  });

  group('RentalAnalyticsService.loadOwnerReportSource', () {
    test(
      'loads only completed rentals and owned equipment for the owner',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = RentalAnalyticsService(firestore: firestore);

        final tractor = _equipment(
          id: 'eq-1',
          ownerId: 'owner-1',
          name: 'Four-wheel Tractor',
          category: 'Mechanized Tools',
          operatorIncluded: true,
          status: EquipmentStatus.available,
          hoursUsedSinceLastMaintenance: 100,
        );
        final otherEquipment = _equipment(
          id: 'eq-2',
          ownerId: 'owner-2',
          name: 'Seeder',
          category: 'Crop Care',
          operatorIncluded: false,
          status: EquipmentStatus.available,
          hoursUsedSinceLastMaintenance: 20,
        );

        await firestore
            .collection('equipment')
            .doc(tractor.id)
            .set(tractor.toMap());
        await firestore
            .collection('equipment')
            .doc(otherEquipment.id)
            .set(otherEquipment.toMap());

        final completedRequest = _request(
          requestId: 'r1',
          itemId: tractor.id!,
          itemName: tractor.name,
          renterId: 'farmer-a',
          renterName: 'Ana Farmer',
          ownerId: 'owner-1',
          start: DateTime(2026, 3, 1),
          end: DateTime(2026, 3, 2),
          agreedPrice: 3000,
        );
        final pendingRequest = completedRequest.copyWith(
          requestId: 'r2',
          status: RentRequestStatus.pending,
        );
        final otherOwnerRequest = _request(
          requestId: 'r3',
          itemId: otherEquipment.id!,
          itemName: otherEquipment.name,
          renterId: 'farmer-b',
          renterName: 'Ben Grower',
          ownerId: 'owner-2',
          start: DateTime(2026, 3, 2),
          end: DateTime(2026, 3, 4),
          agreedPrice: 1500,
        );

        Future<void> seedRequest(RentRequest request) {
          return firestore
              .collection('rentRequests')
              .doc(request.requestId)
              .set({
                ...request.toMap(),
                'createdAt': Timestamp.fromDate(
                  request.createdAt ??
                      request.start.subtract(const Duration(days: 1)),
                ),
              });
        }

        await seedRequest(completedRequest);
        await seedRequest(pendingRequest);
        await seedRequest(otherOwnerRequest);

        final source = await service.loadOwnerReportSource(ownerId: 'owner-1');

        expect(source.ownedEquipment.length, 1);
        expect(source.ownedEquipment.single.id, tractor.id);
        expect(source.rows.length, 1);
        expect(source.rows.single.request.requestId, 'r1');
        expect(source.forecastRequests.length, 2);
        expect(
          source.forecastRequests.any((request) => request.requestId == 'r2'),
          isTrue,
        );
      },
    );
  });
}
