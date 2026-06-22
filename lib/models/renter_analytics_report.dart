import 'package:bukidbayan_app/models/rent_request.dart';

class RenterAnalyticsSummary {
  final int totalRequests;
  final int completedRentals;
  final int activeRentals;
  final int pendingRequests;
  final int cancelledRequests;
  final int declinedRequests;
  final int weatherRiskBookings;
  final double totalSpending;
  final double averageRentalDurationDays;

  const RenterAnalyticsSummary({
    required this.totalRequests,
    required this.completedRentals,
    required this.activeRentals,
    required this.pendingRequests,
    required this.cancelledRequests,
    required this.declinedRequests,
    required this.weatherRiskBookings,
    required this.totalSpending,
    required this.averageRentalDurationDays,
  });

  int get cancelledOrDeclinedRequests => cancelledRequests + declinedRequests;
}

class RenterAnalyticsCategoryUsageItem {
  final String categoryLabel;
  final int requestCount;
  final int completedRentals;
  final double totalSpending;

  const RenterAnalyticsCategoryUsageItem({
    required this.categoryLabel,
    required this.requestCount,
    required this.completedRentals,
    required this.totalSpending,
  });
}

class RenterAnalyticsReport {
  final String renterId;
  final DateTime generatedAt;
  final RenterAnalyticsSummary summary;
  final DateTime? firstRequestAt;
  final DateTime? lastRequestAt;
  final List<RenterAnalyticsCategoryUsageItem> categoryUsage;
  final List<RentRequest> requests;

  const RenterAnalyticsReport({
    required this.renterId,
    required this.generatedAt,
    required this.summary,
    required this.firstRequestAt,
    required this.lastRequestAt,
    required this.categoryUsage,
    required this.requests,
  });
}
