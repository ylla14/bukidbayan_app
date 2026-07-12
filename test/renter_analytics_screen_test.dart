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
        totalRequests: 9,
        completedRentals: 4,
        activeRentals: 2,
        pendingRequests: 1,
        cancelledRequests: 1,
        declinedRequests: 1,
        weatherRiskBookings: 2,
        totalSpending: 12800,
        averageRentalDurationDays: 2.0,
      ),
      firstRequestAt: DateTime(2026, 1, 10),
      lastRequestAt: DateTime(2026, 6, 18),
      categoryUsage: const [
        RenterAnalyticsCategoryUsageItem(
          categoryLabel: 'Tractors',
          requestCount: 4,
          completedRentals: 2,
          totalSpending: 7000,
        ),
        RenterAnalyticsCategoryUsageItem(
          categoryLabel: 'Crop Care',
          requestCount: 3,
          completedRentals: 1,
          totalSpending: 1800,
        ),
        RenterAnalyticsCategoryUsageItem(
          categoryLabel: 'Harvesters',
          requestCount: 2,
          completedRentals: 1,
          totalSpending: 4000,
        ),
      ],
      requests: [
        RentRequest(
          requestId: 'r1',
          itemId: 'eq-1',
          itemName: 'Four-wheel Tractor',
          name: 'Farmer',
          address: 'Barangay Uno',
          start: DateTime(2026, 1, 12),
          end: DateTime(2026, 1, 14),
          status: RentRequestStatus.completed,
          renterId: 'renter-1',
          ownerId: 'owner-1',
          createdAt: DateTime(2026, 1, 10, 9),
          agreedPrice: 4000,
        ),
        RentRequest(
          requestId: 'r2',
          itemId: 'eq-2',
          itemName: 'Walk-behind Tractor',
          name: 'Farmer',
          address: 'Barangay Dos',
          start: DateTime(2026, 2, 5),
          end: DateTime(2026, 2, 7),
          status: RentRequestStatus.completed,
          renterId: 'renter-1',
          ownerId: 'owner-2',
          createdAt: DateTime(2026, 2, 1, 10),
          agreedPrice: 3000,
        ),
        RentRequest(
          requestId: 'r3',
          itemId: 'eq-3',
          itemName: 'Power Sprayer',
          name: 'Farmer',
          address: 'Barangay Tres',
          start: DateTime(2026, 3, 7),
          end: DateTime(2026, 3, 9),
          status: RentRequestStatus.completed,
          renterId: 'renter-1',
          ownerId: 'owner-3',
          createdAt: DateTime(2026, 3, 1, 11),
          agreedPrice: 1800,
          weatherFlag: true,
        ),
        RentRequest(
          requestId: 'r4',
          itemId: 'eq-4',
          itemName: 'Rice Harvester',
          name: 'Farmer',
          address: 'Barangay Quatro',
          start: DateTime(2026, 4, 9),
          end: DateTime(2026, 4, 11),
          status: RentRequestStatus.finished,
          renterId: 'renter-1',
          ownerId: 'owner-4',
          createdAt: DateTime(2026, 4, 1, 13),
          agreedPrice: 4000,
        ),
        RentRequest(
          requestId: 'r5',
          itemId: 'eq-5',
          itemName: 'Four-wheel Tractor',
          name: 'Farmer',
          address: 'Barangay Singko',
          start: DateTime(2026, 6, 21),
          end: DateTime(2026, 6, 23),
          status: RentRequestStatus.approved,
          renterId: 'renter-1',
          ownerId: 'owner-1',
          createdAt: DateTime(2026, 6, 10, 9),
          agreedPrice: 3500,
          weatherFlag: true,
        ),
        RentRequest(
          requestId: 'r6',
          itemId: 'eq-6',
          itemName: 'Backpack Sprayer',
          name: 'Farmer',
          address: 'Barangay Sais',
          start: DateTime(2026, 6, 15),
          end: DateTime(2026, 6, 17),
          status: RentRequestStatus.inProgress,
          renterId: 'renter-1',
          ownerId: 'owner-5',
          createdAt: DateTime(2026, 6, 11, 9),
          agreedPrice: 900,
        ),
        RentRequest(
          requestId: 'r7',
          itemId: 'eq-7',
          itemName: 'Seeder',
          name: 'Farmer',
          address: 'Barangay Syete',
          start: DateTime(2026, 6, 25),
          end: DateTime(2026, 6, 27),
          status: RentRequestStatus.pending,
          renterId: 'renter-1',
          ownerId: 'owner-6',
          createdAt: DateTime(2026, 6, 15, 9),
        ),
        RentRequest(
          requestId: 'r8',
          itemId: 'eq-8',
          itemName: 'Hand Tractor',
          name: 'Farmer',
          address: 'Barangay Ocho',
          start: DateTime(2026, 6, 28),
          end: DateTime(2026, 6, 29),
          status: RentRequestStatus.canceled,
          renterId: 'renter-1',
          ownerId: 'owner-7',
          createdAt: DateTime(2026, 6, 16, 9),
        ),
        RentRequest(
          requestId: 'r9',
          itemId: 'eq-9',
          itemName: 'Mini Harvester',
          name: 'Farmer',
          address: 'Barangay Nueve',
          start: DateTime(2026, 7, 2),
          end: DateTime(2026, 7, 4),
          status: RentRequestStatus.declined,
          renterId: 'renter-1',
          ownerId: 'owner-8',
          createdAt: DateTime(2026, 6, 18, 9),
        ),
      ],
    );
  }
}

void main() {
  testWidgets(
    'renter analytics screen renders the redesigned sections for the current renter',
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
      expect(find.text('How to read this page'), findsOneWidget);

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Request Journey'),
        200,
        scrollable: scrollable,
      );
      expect(find.text('Request Journey'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Recent Requests'),
        200,
        scrollable: scrollable,
      );
      expect(find.text('Recent Requests'), findsOneWidget);
      expect(
        find.byKey(const Key('renter_analytics_print_button')),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.text('Spending & Timing'),
        200,
        scrollable: scrollable,
      );
      expect(find.text('Spending & Timing'), findsOneWidget);

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

  testWidgets('tapping a journey stage opens drill-down details', (
    tester,
  ) async {
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

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('renter_analytics_stage_completed')),
      200,
      scrollable: scrollable,
    );
    await tester.ensureVisible(
      find.byKey(const Key('renter_analytics_stage_completed')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('renter_analytics_stage_completed')));
    await tester.pumpAndSettle();

    expect(find.text('Rice Harvester'), findsOneWidget);
    expect(find.text('4 requests'), findsOneWidget);
  });

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
      find.text('Request Journey'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Request Journey'), findsOneWidget);
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
