import 'package:bukidbayan_app/models/demand_forecast.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/services/analytics/demand_forecast_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DemandForecastService', () {
    test('prioritizes rice mill demand from recent post-harvest requests', () {
      final service = DemandForecastService(now: () => DateTime(2026, 10, 15));

      final snapshot = service.buildWeeklyForecast(
        requests: [
          _request(
            requestId: 'req-1',
            itemName: 'Rice Mill',
            start: DateTime(2026, 10, 18),
            createdAt: DateTime(2026, 10, 10),
            farmBarangay: 'Barangay San Jose',
            cropType: 'Rice',
            farmingPhase: 'Post-harvest',
            intendedUse: 'Milling',
          ),
          _request(
            requestId: 'req-2',
            itemName: 'Rice Mill',
            start: DateTime(2026, 10, 20),
            createdAt: DateTime(2026, 10, 12),
            farmBarangay: 'Barangay San Jose',
            cropType: 'Rice',
            farmingPhase: 'Post-harvest',
            intendedUse: 'Milling',
          ),
        ],
        seasonalCrops: const ['Rice (Wet Season)'],
      );

      expect(snapshot.locationLabel, 'Barangay San Jose');
      expect(snapshot.insights, isNotEmpty);
      expect(snapshot.insights.first.equipmentCategory, 'Rice Mill (Gilingan)');
      expect(snapshot.insights.first.level, DemandForecastLevel.high);
      expect(snapshot.insights.first.matchedRequests, 2);
      expect(snapshot.summary, contains('Rice Mill (Gilingan)'));
    });

    test('returns early forecast when booking signals are still missing', () {
      final service = DemandForecastService(now: () => DateTime(2026, 4, 5));

      final snapshot = service.buildWeeklyForecast(
        requests: const [],
        seasonalCrops: const [],
      );

      expect(snapshot.confidence, DemandForecastConfidence.low);
      expect(snapshot.insights, isEmpty);
      expect(snapshot.summary, contains('Not enough booking signals yet'));
    });

    test('combines saved crops and item history for low-data users', () {
      final service = DemandForecastService(now: () => DateTime(2026, 7, 8));

      final snapshot = service.buildWeeklyForecast(
        requests: [
          _request(
            requestId: 'req-1',
            itemName: 'Hand Tractor',
            start: DateTime(2026, 7, 9),
            createdAt: DateTime(2026, 7, 6),
          ),
        ],
        seasonalCrops: const ['Rice (Wet Season)'],
        savedCrops: const ['Rice (Wet Season)'],
      );

      expect(snapshot.insights, isNotEmpty);
      expect(
        snapshot.insights.first.equipmentCategory,
        'Hand Tractor (Kuliglig)',
      );
      expect(snapshot.summary, contains('Hand Tractor (Kuliglig)'));
    });
  });
}

RentRequest _request({
  required String requestId,
  required String itemName,
  required DateTime start,
  DateTime? createdAt,
  String? farmBarangay,
  String? cropType,
  String? farmingPhase,
  String? intendedUse,
}) {
  return RentRequest(
    requestId: requestId,
    itemId: 'item-$requestId',
    itemName: itemName,
    name: 'Requester',
    address: 'Laguna',
    start: start,
    end: start.add(const Duration(days: 1)),
    status: RentRequestStatus.completed,
    renterId: 'renter-1',
    ownerId: 'owner-1',
    createdAt: createdAt,
    farmBarangay: farmBarangay,
    cropType: cropType,
    farmingPhase: farmingPhase,
    intendedUse: intendedUse,
  );
}
