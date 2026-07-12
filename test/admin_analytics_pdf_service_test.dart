import 'package:bukidbayan_app/models/admin_analytics_report.dart';
import 'package:bukidbayan_app/models/demand_forecast.dart';
import 'package:bukidbayan_app/services/admin_analytics_pdf_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a printable admin analytics PDF', () async {
    final report = AdminAnalyticsReport(
      generatedAt: DateTime(2026, 7, 12, 9, 30),
      preset: AdminAnalyticsTimePreset.currentMonth,
      timeWindow: AdminAnalyticsTimePreset.currentMonth.resolveWindow(
        DateTime(2026, 7, 12),
      ),
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
        campaignsPublishedInWindow: 1,
        totalPledges: 6,
        totalPledgedAmount: 5900,
        totalReceivedAmount: 4200,
        uniqueSupporters: 5,
        pendingProofPledges: 1,
        pendingProofAmount: 700,
        pendingReviewPledges: 1,
        pendingReviewAmount: 500,
        invalidatedPledges: 1,
        invalidatedAmount: 500,
        canceledPledges: 0,
        canceledAmount: 0,
      ),
      watchlist: const AdminAnalyticsWatchlistSnapshot(
        blockedRenters: 1,
        weatherRiskBookings: 1,
        underMaintenanceEquipment: 2,
        pendingRentals: 2,
        contributionProofsAwaitingReview: 1,
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
            summary: 'High tractor demand expected this week.',
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

    final bytes = await AdminAnalyticsPdfService.buildPdfBytes(report: report);

    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(1000));
  });
}
