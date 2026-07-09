import 'package:bukidbayan_app/models/admin_analytics_report.dart';
import 'package:bukidbayan_app/models/demand_forecast.dart';
import 'package:bukidbayan_app/screens/admin/admin_analytics_screen.dart';
import 'package:bukidbayan_app/screens/admin/admin_screen.dart';
import 'package:bukidbayan_app/services/analytics/admin_analytics_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAdminAnalyticsService extends AdminAnalyticsService {
  FakeAdminAnalyticsService() : super(firestore: FakeFirebaseFirestore());

  final List<AdminAnalyticsTimePreset> calls = [];

  @override
  Future<AdminAnalyticsReport> generateReport({
    AdminAnalyticsTimePreset preset = AdminAnalyticsTimePreset.allTime,
    DateTime? now,
  }) async {
    calls.add(preset);
    final generatedAt = now ?? DateTime(2026, 6, 20);
    return AdminAnalyticsReport(
      generatedAt: generatedAt,
      preset: preset,
      timeWindow: preset.resolveWindow(generatedAt),
      platform: const AdminAnalyticsPlatformSnapshot(
        totalUsers: 12,
        coopAccounts: 1,
        newUsersInWindow: 4,
        totalEquipment: 9,
        newEquipmentInWindow: 3,
        equipmentOwners: 5,
        availableEquipment: 4,
        unavailableEquipment: 3,
        underMaintenanceEquipment: 2,
      ),
      rentals: const AdminAnalyticsRentalSnapshot(
        activeRentals: 3,
        pendingRentals: 2,
        completedRentals: 5,
        weatherRiskBookings: 1,
        uniqueFarmersServed: 4,
        completedRentalValue: 18500,
      ),
      crowdfunding: const AdminAnalyticsCrowdfundingSnapshot(
        liveCampaigns: 2,
        campaignsCreatedInWindow: 1,
        totalPledges: 6,
        totalPledgedAmount: 5400,
        totalPaidAmount: 4200,
        uniqueSupporters: 5,
        paidAttempts: 4,
        failedAttempts: 1,
        expiredAttempts: 0,
      ),
      watchlist: const AdminAnalyticsWatchlistSnapshot(
        blockedRenters: 1,
        weatherRiskBookings: 1,
        underMaintenanceEquipment: 2,
        pendingRentals: 2,
        failedPaymentAttempts: 1,
      ),
      impact: const AdminAnalyticsImpactSnapshot(
        totalFarmersServed: 9,
        totalEquipmentOwners: 5,
        totalCampaignSupporters: 11,
        totalCompletedRentals: 14,
      ),
      systemHealth: const AdminAnalyticsSystemHealthSnapshot(
        currentStatus: 'healthy',
        lastHeartbeatAt: null,
        lastHeartbeatSource: 'app_startup',
        lastAppOpenAt: null,
        lastBackgroundTaskAt: null,
        lastBackgroundTaskName: 'weather_check',
        lastBackgroundTaskStatus: 'success',
        telemetryEventsInWindow: 6,
        appOpensInWindow: 2,
        loginFailuresInWindow: 1,
        backgroundTaskFailuresInWindow: 0,
        heartbeatEventsInWindow: 2,
      ),
      dataReadiness: const AdminAnalyticsDataReadinessSnapshot(
        memberProfilesWithGeography: 7,
        totalMemberProfiles: 12,
        equipmentWithGeography: 6,
        totalEquipment: 9,
        requestsWithNormalizedGeography: 5,
        requestsWithForecastInputs: 4,
        requestsWithStatusHistory: 6,
        requestsWithTimelineEvents: 5,
        totalRequests: 8,
        equipmentWithMaintenanceLogs: 3,
        maintenanceLogEntries: 9,
        benchmarkRows: 5,
      ),
      forecasting: const AdminAnalyticsForecastSnapshot(
        requestsWithForecastLocation: 5,
        requestsWithForecastInputsAndLocation: 4,
        locationsAnalyzed: 3,
        hotspotCount: 2,
        highDemandHotspots: 1,
        highConfidenceHotspots: 1,
        hotspots: [
          AdminAnalyticsForecastLocationItem(
            locationLabel: 'Barangay Uno',
            equipmentCategory: 'Tractors',
            demandLevel: DemandForecastLevel.high,
            confidence: DemandForecastConfidence.high,
            matchedRequests: 3,
            recentRequests: 2,
            summary:
                'Estimated high demand for Tractors in Barangay Uno this week with high confidence.',
          ),
          AdminAnalyticsForecastLocationItem(
            locationLabel: 'Barangay Dos',
            equipmentCategory: 'Harvesters',
            demandLevel: DemandForecastLevel.medium,
            confidence: DemandForecastConfidence.medium,
            matchedRequests: 2,
            recentRequests: 1,
            summary:
                'Estimated medium demand for Harvesters in Barangay Dos this week with medium confidence.',
          ),
        ],
      ),
      topDemandCategories: const [
        AdminAnalyticsCategoryDemandItem(
          categoryLabel: 'Tractors',
          requestCount: 4,
          completedRequestCount: 3,
          uniqueRenters: 4,
        ),
      ],
    );
  }
}

void main() {
  testWidgets(
    'admin analytics screen renders report sections and reloads window',
    (tester) async {
      final service = FakeAdminAnalyticsService();

      await tester.pumpWidget(
        MaterialApp(
          home: AdminAnalyticsScreen(isCoop: true, serviceOverride: service),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Admin Analytics'), findsWidgets);
      expect(service.calls, [AdminAnalyticsTimePreset.allTime]);

      await tester.tap(
        find.byKey(const Key('admin_analytics_preset_dropdown')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Current month').last);
      await tester.pumpAndSettle();

      expect(service.calls.last, AdminAnalyticsTimePreset.currentMonth);
      expect(
        find.textContaining(
          'Filters activity metrics to the current calendar month.',
        ),
        findsOneWidget,
      );

      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Platform Overview'),
        200,
        scrollable: scrollable,
      );
      expect(find.text('Platform Overview'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('System Health'),
        200,
        scrollable: scrollable,
      );
      expect(find.text('System Health'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Demand Proxy by Category'),
        200,
        scrollable: scrollable,
      );
      expect(find.text('Demand Proxy by Category'), findsOneWidget);
      expect(find.text('Tractors'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Demand Forecast Hotspots'),
        200,
        scrollable: scrollable,
      );
      expect(find.text('Demand Forecast Hotspots'), findsOneWidget);
      expect(find.text('Barangay Uno'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Crowdfunding Overview'),
        200,
        scrollable: scrollable,
      );
      expect(find.text('Crowdfunding Overview'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Risk & Watchlist'),
        200,
        scrollable: scrollable,
      );
      expect(find.text('Risk & Watchlist'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Data Readiness'),
        200,
        scrollable: scrollable,
      );
      expect(find.text('Data Readiness'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Impact Summary'),
        200,
        scrollable: scrollable,
      );
      expect(find.text('Impact Summary'), findsOneWidget);
    },
  );

  testWidgets('admin dashboard opens analytics screen from the reports card', (
    tester,
  ) async {
    final service = FakeAdminAnalyticsService();

    await tester.pumpWidget(
      MaterialApp(
        home: AdminScreen(
          isCoop: true,
          authOverride: MockFirebaseAuth(),
          appBarOverride: AppBar(title: const Text('Admin')),
          drawerOverride: const SizedBox(),
          adminAnalyticsServiceOverride: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Analytics & Reports'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Platform Overview'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Platform Overview'), findsOneWidget);
    expect(service.calls, isNotEmpty);
  });

  testWidgets('non-coop users see restricted admin analytics access', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdminAnalyticsScreen(isCoop: false)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Restricted Access'), findsOneWidget);
  });
}
