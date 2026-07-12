import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/models/renter_analytics_report.dart';
import 'package:bukidbayan_app/services/renter_analytics_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a printable renter analytics PDF', () async {
    final report = RenterAnalyticsReport(
      renterId: 'renter-1',
      generatedAt: DateTime(2026, 7, 12, 10, 30),
      summary: const RenterAnalyticsSummary(
        totalRequests: 5,
        completedRentals: 2,
        activeRentals: 1,
        pendingRequests: 1,
        cancelledRequests: 1,
        declinedRequests: 0,
        weatherRiskBookings: 1,
        totalSpending: 5800,
        averageRentalDurationDays: 2.0,
      ),
      firstRequestAt: DateTime(2026, 2, 1),
      lastRequestAt: DateTime(2026, 7, 1),
      categoryUsage: const [
        RenterAnalyticsCategoryUsageItem(
          categoryLabel: 'Tractors',
          requestCount: 3,
          completedRentals: 2,
          totalSpending: 5800,
        ),
      ],
      requests: [
        RentRequest(
          requestId: 'JX0jGivpVC0qezpuJCPF9LQ2hR1s82K',
          itemId: 'eq-1',
          itemName: 'Four-wheel Tractor',
          name: 'Farmer One',
          address:
              'National Highway 1, Pulo, San Isidro, Cabuyao, Laguna, Calabarzon, 4025, Philippines',
          start: DateTime(2026, 2, 3),
          end: DateTime(2026, 2, 5),
          status: RentRequestStatus.completed,
          renterId: 'renter-1',
          ownerId: 'owner-1',
          createdAt: DateTime(2026, 2, 1, 9),
          agreedPrice: 3200,
          farmAddress:
              'National Highway 1, Pulo, San Isidro, Cabuyao, Laguna, Calabarzon, 4025, Philippines',
        ),
        RentRequest(
          requestId: 'r2',
          itemId: 'eq-2',
          itemName: 'Rice Harvester',
          name: 'Farmer One',
          address: 'Barangay Dos',
          start: DateTime(2026, 3, 10),
          end: DateTime(2026, 3, 12),
          status: RentRequestStatus.finished,
          renterId: 'renter-1',
          ownerId: 'owner-2',
          createdAt: DateTime(2026, 3, 6, 8),
          agreedPrice: 2600,
        ),
        RentRequest(
          requestId: 'r3',
          itemId: 'eq-3',
          itemName: 'Seeder',
          name: 'Farmer One',
          address: 'Barangay Tres',
          start: DateTime(2026, 6, 15),
          end: DateTime(2026, 6, 17),
          status: RentRequestStatus.approved,
          renterId: 'renter-1',
          ownerId: 'owner-3',
          createdAt: DateTime(2026, 6, 10, 8),
          weatherFlag: true,
        ),
        RentRequest(
          requestId: 'r4',
          itemId: 'eq-4',
          itemName: 'Power Sprayer',
          name: 'Farmer One',
          address: 'Barangay Quatro',
          start: DateTime(2026, 6, 20),
          end: DateTime(2026, 6, 22),
          status: RentRequestStatus.pending,
          renterId: 'renter-1',
          ownerId: 'owner-4',
          createdAt: DateTime(2026, 6, 16, 8),
        ),
        RentRequest(
          requestId: 'r5',
          itemId: 'eq-5',
          itemName: 'Hand Tractor',
          name: 'Farmer One',
          address: 'Barangay Singko',
          start: DateTime(2026, 7, 3),
          end: DateTime(2026, 7, 4),
          status: RentRequestStatus.canceled,
          renterId: 'renter-1',
          ownerId: 'owner-5',
          createdAt: DateTime(2026, 7, 1, 8),
        ),
      ],
    );

    final bytes = await RenterAnalyticsPdfService.buildPdfBytes(report: report);

    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(1000));
  });
}
