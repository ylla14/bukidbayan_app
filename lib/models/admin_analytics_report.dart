import 'package:bukidbayan_app/models/analytics_time_window.dart';
import 'package:bukidbayan_app/models/demand_forecast.dart';

enum AdminAnalyticsTimePreset {
  allTime,
  last30Days,
  currentMonth,
  currentQuarter,
}

extension AdminAnalyticsTimePresetX on AdminAnalyticsTimePreset {
  String get label {
    switch (this) {
      case AdminAnalyticsTimePreset.allTime:
        return 'All-time';
      case AdminAnalyticsTimePreset.last30Days:
        return 'Last 30 days';
      case AdminAnalyticsTimePreset.currentMonth:
        return 'Current month';
      case AdminAnalyticsTimePreset.currentQuarter:
        return 'Current quarter';
    }
  }

  String get helperText {
    switch (this) {
      case AdminAnalyticsTimePreset.allTime:
        return 'Shows overall totals and the current platform snapshot.';
      case AdminAnalyticsTimePreset.last30Days:
        return 'Filters activity metrics to the last 30 days.';
      case AdminAnalyticsTimePreset.currentMonth:
        return 'Filters activity metrics to the current calendar month.';
      case AdminAnalyticsTimePreset.currentQuarter:
        return 'Filters activity metrics to the current calendar quarter.';
    }
  }

  AnalyticsTimeWindow? resolveWindow(DateTime now) {
    final end = DateTime(now.year, now.month, now.day);
    switch (this) {
      case AdminAnalyticsTimePreset.allTime:
        return null;
      case AdminAnalyticsTimePreset.last30Days:
        return AnalyticsTimeWindow(
          start: end.subtract(const Duration(days: 29)),
          end: end,
        );
      case AdminAnalyticsTimePreset.currentMonth:
        return AnalyticsTimeWindow(
          start: DateTime(now.year, now.month, 1),
          end: end,
        );
      case AdminAnalyticsTimePreset.currentQuarter:
        final quarterStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return AnalyticsTimeWindow(
          start: DateTime(now.year, quarterStartMonth, 1),
          end: end,
        );
    }
  }
}

class AdminAnalyticsPlatformSnapshot {
  final int totalUsers;
  final int coopAccounts;
  final int newUsersInWindow;
  final int totalEquipment;
  final int newEquipmentInWindow;
  final int equipmentOwners;
  final int availableEquipment;
  final int unavailableEquipment;
  final int underMaintenanceEquipment;

  const AdminAnalyticsPlatformSnapshot({
    required this.totalUsers,
    required this.coopAccounts,
    required this.newUsersInWindow,
    required this.totalEquipment,
    required this.newEquipmentInWindow,
    required this.equipmentOwners,
    required this.availableEquipment,
    required this.unavailableEquipment,
    required this.underMaintenanceEquipment,
  });
}

class AdminAnalyticsRentalSnapshot {
  final int activeRentals;
  final int pendingRentals;
  final int completedRentals;
  final int weatherRiskBookings;
  final int uniqueFarmersServed;
  final double completedRentalValue;

  const AdminAnalyticsRentalSnapshot({
    required this.activeRentals,
    required this.pendingRentals,
    required this.completedRentals,
    required this.weatherRiskBookings,
    required this.uniqueFarmersServed,
    required this.completedRentalValue,
  });
}

class AdminAnalyticsCrowdfundingSnapshot {
  final int liveCampaigns;
  final int campaignsCreatedInWindow;
  final int totalPledges;
  final int totalPledgedAmount;
  final int totalPaidAmount;
  final int uniqueSupporters;
  final int paidAttempts;
  final int failedAttempts;
  final int expiredAttempts;

  const AdminAnalyticsCrowdfundingSnapshot({
    required this.liveCampaigns,
    required this.campaignsCreatedInWindow,
    required this.totalPledges,
    required this.totalPledgedAmount,
    required this.totalPaidAmount,
    required this.uniqueSupporters,
    required this.paidAttempts,
    required this.failedAttempts,
    required this.expiredAttempts,
  });
}

class AdminAnalyticsWatchlistSnapshot {
  final int blockedRenters;
  final int weatherRiskBookings;
  final int underMaintenanceEquipment;
  final int pendingRentals;
  final int failedPaymentAttempts;

  const AdminAnalyticsWatchlistSnapshot({
    required this.blockedRenters,
    required this.weatherRiskBookings,
    required this.underMaintenanceEquipment,
    required this.pendingRentals,
    required this.failedPaymentAttempts,
  });
}

class AdminAnalyticsImpactSnapshot {
  final int totalFarmersServed;
  final int totalEquipmentOwners;
  final int totalCampaignSupporters;
  final int totalCompletedRentals;

  const AdminAnalyticsImpactSnapshot({
    required this.totalFarmersServed,
    required this.totalEquipmentOwners,
    required this.totalCampaignSupporters,
    required this.totalCompletedRentals,
  });
}

class AdminAnalyticsSystemHealthSnapshot {
  final String currentStatus;
  final DateTime? lastHeartbeatAt;
  final String? lastHeartbeatSource;
  final DateTime? lastAppOpenAt;
  final DateTime? lastBackgroundTaskAt;
  final String? lastBackgroundTaskName;
  final String? lastBackgroundTaskStatus;
  final int telemetryEventsInWindow;
  final int appOpensInWindow;
  final int loginFailuresInWindow;
  final int backgroundTaskFailuresInWindow;
  final int heartbeatEventsInWindow;

  const AdminAnalyticsSystemHealthSnapshot({
    required this.currentStatus,
    required this.lastHeartbeatAt,
    required this.lastHeartbeatSource,
    required this.lastAppOpenAt,
    required this.lastBackgroundTaskAt,
    required this.lastBackgroundTaskName,
    required this.lastBackgroundTaskStatus,
    required this.telemetryEventsInWindow,
    required this.appOpensInWindow,
    required this.loginFailuresInWindow,
    required this.backgroundTaskFailuresInWindow,
    required this.heartbeatEventsInWindow,
  });
}

class AdminAnalyticsDataReadinessSnapshot {
  final int memberProfilesWithGeography;
  final int totalMemberProfiles;
  final int equipmentWithGeography;
  final int totalEquipment;
  final int requestsWithNormalizedGeography;
  final int requestsWithForecastInputs;
  final int requestsWithStatusHistory;
  final int requestsWithTimelineEvents;
  final int totalRequests;
  final int equipmentWithMaintenanceLogs;
  final int maintenanceLogEntries;
  final int benchmarkRows;

  const AdminAnalyticsDataReadinessSnapshot({
    required this.memberProfilesWithGeography,
    required this.totalMemberProfiles,
    required this.equipmentWithGeography,
    required this.totalEquipment,
    required this.requestsWithNormalizedGeography,
    required this.requestsWithForecastInputs,
    required this.requestsWithStatusHistory,
    required this.requestsWithTimelineEvents,
    required this.totalRequests,
    required this.equipmentWithMaintenanceLogs,
    required this.maintenanceLogEntries,
    required this.benchmarkRows,
  });

  double get memberProfileCoverageRate => totalMemberProfiles == 0
      ? 0
      : memberProfilesWithGeography / totalMemberProfiles;

  double get equipmentGeographyCoverageRate =>
      totalEquipment == 0 ? 0 : equipmentWithGeography / totalEquipment;

  double get requestGeographyCoverageRate =>
      totalRequests == 0 ? 0 : requestsWithNormalizedGeography / totalRequests;

  double get forecastInputCoverageRate =>
      totalRequests == 0 ? 0 : requestsWithForecastInputs / totalRequests;

  double get requestHistoryCoverageRate =>
      totalRequests == 0 ? 0 : requestsWithStatusHistory / totalRequests;

  double get requestTimelineCoverageRate =>
      totalRequests == 0 ? 0 : requestsWithTimelineEvents / totalRequests;

  double get maintenanceLogCoverageRate =>
      totalEquipment == 0 ? 0 : equipmentWithMaintenanceLogs / totalEquipment;
}

class AdminAnalyticsCategoryDemandItem {
  final String categoryLabel;
  final int requestCount;
  final int completedRequestCount;
  final int uniqueRenters;

  const AdminAnalyticsCategoryDemandItem({
    required this.categoryLabel,
    required this.requestCount,
    required this.completedRequestCount,
    required this.uniqueRenters,
  });

  double get completionRate =>
      requestCount == 0 ? 0 : completedRequestCount / requestCount;
}

class AdminAnalyticsForecastLocationItem {
  final String locationLabel;
  final String equipmentCategory;
  final DemandForecastLevel demandLevel;
  final DemandForecastConfidence confidence;
  final int matchedRequests;
  final int recentRequests;
  final String summary;

  const AdminAnalyticsForecastLocationItem({
    required this.locationLabel,
    required this.equipmentCategory,
    required this.demandLevel,
    required this.confidence,
    required this.matchedRequests,
    required this.recentRequests,
    required this.summary,
  });
}

class AdminAnalyticsForecastSnapshot {
  final int requestsWithForecastLocation;
  final int requestsWithForecastInputsAndLocation;
  final int locationsAnalyzed;
  final int hotspotCount;
  final int highDemandHotspots;
  final int highConfidenceHotspots;
  final List<AdminAnalyticsForecastLocationItem> hotspots;

  const AdminAnalyticsForecastSnapshot({
    required this.requestsWithForecastLocation,
    required this.requestsWithForecastInputsAndLocation,
    required this.locationsAnalyzed,
    required this.hotspotCount,
    required this.highDemandHotspots,
    required this.highConfidenceHotspots,
    required this.hotspots,
  });

  double get locationCoverageRate => requestsWithForecastLocation == 0
      ? 0
      : requestsWithForecastInputsAndLocation / requestsWithForecastLocation;
}

class AdminAnalyticsReport {
  final DateTime generatedAt;
  final AdminAnalyticsTimePreset preset;
  final AnalyticsTimeWindow? timeWindow;
  final AdminAnalyticsPlatformSnapshot platform;
  final AdminAnalyticsRentalSnapshot rentals;
  final AdminAnalyticsCrowdfundingSnapshot crowdfunding;
  final AdminAnalyticsWatchlistSnapshot watchlist;
  final AdminAnalyticsImpactSnapshot impact;
  final AdminAnalyticsSystemHealthSnapshot systemHealth;
  final AdminAnalyticsDataReadinessSnapshot dataReadiness;
  final AdminAnalyticsForecastSnapshot forecasting;
  final List<AdminAnalyticsCategoryDemandItem> topDemandCategories;

  const AdminAnalyticsReport({
    required this.generatedAt,
    required this.preset,
    required this.timeWindow,
    required this.platform,
    required this.rentals,
    required this.crowdfunding,
    required this.watchlist,
    required this.impact,
    required this.systemHealth,
    required this.dataReadiness,
    required this.forecasting,
    required this.topDemandCategories,
  });
}
