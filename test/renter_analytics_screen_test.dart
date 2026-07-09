import 'package:bukidbayan_app/components/dashboard/action_buttons_section.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/models/renter_analytics_report.dart';
import 'package:bukidbayan_app/screens/dashboard/renter_analytics_screen.dart';
import 'package:bukidbayan_app/services/analytics/renter_analytics_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRenterAnalyticsService extends RenterAnalyticsService {
  FakeRenterAnalyticsService() : super(firestore: FakeFirebaseFirestore());

  final List<String> renterIds = [];

  @override
  Future<RenterAnalyticsReport> generateReport({
    required String renterId,
    DateTime? now,
  }) async {
    renterIds.add(renterId);
    return RenterAnalyticsReport(
      renterId: renterId,
      generatedAt: now ?? DateTime(2026, 6, 22),
      summary: const RenterAnalyticsSummary(
        totalRequests: 8,
        completedRentals: 4,
        activeRentals: 2,
        pendingRequests: 1,
        cancelledRequests: 1,
        declinedRequests: 1,
        weatherRiskBookings: 2,
        totalSpending: 12800,
        averageRentalDurationDays: 1.8,
      ),
      firstRequestAt: DateTime(2026, 1, 10),
      lastRequestAt: DateTime(2026, 6, 18),
      categoryUsage: const [
        RenterAnalyticsCategoryUsageItem(
          categoryLabel: 'Tractors',
          requestCount: 3,
          completedRentals: 2,
          totalSpending: 7000,
        ),
        RenterAnalyticsCategoryUsageItem(
          categoryLabel: 'Crop Care',
          requestCount: 2,
          completedRentals: 1,
          totalSpending: 1800,
        ),
      ],
      requests: [
        RentRequest(
          requestId: 'r1',
          itemId: 'eq-1',
          itemName: 'Four-wheel Tractor',
          name: 'Farmer',
          address: 'Barangay Test',
          start: DateTime(2026, 1, 12),
          end: DateTime(2026, 1, 14),
          status: RentRequestStatus.completed,
          renterId: 'renter-1',
          ownerId: 'owner-1',
        ),
      ],
    );
  }
}

void main() {
  testWidgets(
    'renter analytics screen renders sections for the current renter',
    (tester) async {
      final service = FakeRenterAnalyticsService();

      await tester.pumpWidget(
        MaterialApp(
          home: RenterAnalyticsScreen(
            serviceOverride: service,
            renterIdOverride: 'renter-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Rental Analytics'), findsWidgets);
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Request Activity'),
        200,
        scrollable: scrollable,
      );
      expect(find.text('Request Activity'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Spending & Duration'),
        200,
        scrollable: scrollable,
      );
      expect(find.text('Spending & Duration'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Most-used Equipment Categories'),
        200,
        scrollable: scrollable,
      );
      expect(find.text('Most-used Equipment Categories'), findsOneWidget);
      expect(find.text('Tractors'), findsOneWidget);
      expect(find.text('Crop Care'), findsOneWidget);
      expect(service.renterIds, ['renter-1']);
    },
  );

  testWidgets('dashboard action button opens renter analytics screen', (
    tester,
  ) async {
    final service = FakeRenterAnalyticsService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ActionButtonsSection(
            renterAnalyticsServiceOverride: service,
            renterAnalyticsRenterIdOverride: 'renter-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('my_rental_analytics_button')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Request Activity'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Request Activity'), findsOneWidget);
    expect(service.renterIds, ['renter-1']);
  });

  testWidgets('screen shows signed-out guidance when no renter is available', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RenterAnalyticsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('No signed-in renter account was found.'), findsOneWidget);
  });
}
