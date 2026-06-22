import 'package:bukidbayan_app/models/analytics_time_window.dart';
import 'package:bukidbayan_app/models/demand_forecast.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/rent_request.dart';

enum OwnerOperatorFilter { all, withOperator, withoutOperator }

extension OwnerOperatorFilterX on OwnerOperatorFilter {
  String get shortLabel {
    switch (this) {
      case OwnerOperatorFilter.all:
        return 'All';
      case OwnerOperatorFilter.withOperator:
        return 'Yes';
      case OwnerOperatorFilter.withoutOperator:
        return 'No';
    }
  }

  String? get pdfLabel {
    switch (this) {
      case OwnerOperatorFilter.all:
        return null;
      case OwnerOperatorFilter.withOperator:
        return 'Yes only';
      case OwnerOperatorFilter.withoutOperator:
        return 'No operator only';
    }
  }
}

class OwnerRentalReportFilter {
  final AnalyticsTimeWindow? timeWindow;
  final String searchQuery;
  final String? equipmentId;
  final OwnerOperatorFilter operatorFilter;
  final double? minPayment;
  final double? maxPayment;

  const OwnerRentalReportFilter({
    this.timeWindow,
    this.searchQuery = '',
    this.equipmentId,
    this.operatorFilter = OwnerOperatorFilter.all,
    this.minPayment,
    this.maxPayment,
  });

  OwnerRentalReportFilter copyWith({
    Object? timeWindow = _sentinel,
    String? searchQuery,
    Object? equipmentId = _sentinel,
    OwnerOperatorFilter? operatorFilter,
    Object? minPayment = _sentinel,
    Object? maxPayment = _sentinel,
  }) {
    return OwnerRentalReportFilter(
      timeWindow: identical(timeWindow, _sentinel)
          ? this.timeWindow
          : timeWindow as AnalyticsTimeWindow?,
      searchQuery: searchQuery ?? this.searchQuery,
      equipmentId: identical(equipmentId, _sentinel)
          ? this.equipmentId
          : equipmentId as String?,
      operatorFilter: operatorFilter ?? this.operatorFilter,
      minPayment: identical(minPayment, _sentinel)
          ? this.minPayment
          : minPayment as double?,
      maxPayment: identical(maxPayment, _sentinel)
          ? this.maxPayment
          : maxPayment as double?,
    );
  }

  bool get hasActiveFilters =>
      timeWindow != null ||
      searchQuery.trim().isNotEmpty ||
      equipmentId != null ||
      operatorFilter != OwnerOperatorFilter.all ||
      minPayment != null ||
      maxPayment != null;
}

class OwnerRentalTransactionRow {
  final RentRequest request;
  final Equipment? equipment;

  const OwnerRentalTransactionRow({
    required this.request,
    required this.equipment,
  });

  int get daysRented =>
      request.end.difference(request.start).inDays.clamp(1, 9999);

  double get estimatedBookedHours => daysRented * 24.0;

  double? get totalPayment {
    if ((request.estimatedMillingFee ?? 0) > 0) {
      return request.estimatedMillingFee;
    }
    return request.agreedPrice;
  }

  bool get withOperator => equipment?.operatorIncluded ?? false;

  String get farmLocation => request.farmAddress ?? request.address;

  String get categoryLabel {
    final category = equipment?.category?.trim();
    if (category == null || category.isEmpty) {
      return 'Uncategorized';
    }
    return category;
  }

  String get measurementDisplay {
    if (request.hectaresEntered != null) {
      return '${request.hectaresEntered!.toStringAsFixed(2)} ha';
    }
    if (request.volumeSubmitted != null) {
      return '${request.volumeSubmitted!.toStringAsFixed(1)} kg';
    }
    return '-';
  }
}

class OwnerRentalReportSource {
  final String ownerId;
  final List<OwnerRentalTransactionRow> rows;
  final List<Equipment> ownedEquipment;
  final List<RentRequest> forecastRequests;
  final Map<String, Equipment> equipmentById;

  const OwnerRentalReportSource({
    required this.ownerId,
    required this.rows,
    required this.ownedEquipment,
    this.forecastRequests = const [],
    this.equipmentById = const {},
  });
}

class OwnerRentalSummary {
  final double totalEarnings;
  final int completedRentals;
  final int uniqueFarmersServed;
  final int totalBookedDays;
  final double estimatedBookedHours;
  final double averageRentalDurationDays;

  const OwnerRentalSummary({
    required this.totalEarnings,
    required this.completedRentals,
    required this.uniqueFarmersServed,
    required this.totalBookedDays,
    required this.estimatedBookedHours,
    required this.averageRentalDurationDays,
  });
}

class OwnerRentalEquipmentPerformance {
  final String itemId;
  final String itemName;
  final String categoryLabel;
  final bool withOperator;
  final double totalEarnings;
  final int completedRentals;
  final int bookedDays;
  final double estimatedBookedHours;
  final int uniqueFarmersServed;

  const OwnerRentalEquipmentPerformance({
    required this.itemId,
    required this.itemName,
    required this.categoryLabel,
    required this.withOperator,
    required this.totalEarnings,
    required this.completedRentals,
    required this.bookedDays,
    required this.estimatedBookedHours,
    required this.uniqueFarmersServed,
  });
}

class OwnerRentalCategoryPerformance {
  final String categoryLabel;
  final double totalEarnings;
  final int completedRentals;
  final int bookedDays;
  final double estimatedBookedHours;
  final int uniqueFarmersServed;

  const OwnerRentalCategoryPerformance({
    required this.categoryLabel,
    required this.totalEarnings,
    required this.completedRentals,
    required this.bookedDays,
    required this.estimatedBookedHours,
    required this.uniqueFarmersServed,
  });
}

class OwnerRentalUtilizationItem {
  final String equipmentId;
  final String equipmentName;
  final String categoryLabel;
  final bool withOperator;
  final double bookedHours;
  final double schedulableHours;
  final double utilizationRate;
  final bool isUnderMaintenance;
  final bool isMaintenanceDue;
  final bool isMaintenanceUpcoming;

  const OwnerRentalUtilizationItem({
    required this.equipmentId,
    required this.equipmentName,
    required this.categoryLabel,
    required this.withOperator,
    required this.bookedHours,
    required this.schedulableHours,
    required this.utilizationRate,
    required this.isUnderMaintenance,
    required this.isMaintenanceDue,
    required this.isMaintenanceUpcoming,
  });
}

class OwnerMaintenanceSnapshot {
  final int totalOwnedEquipment;
  final int availableCount;
  final int unavailableCount;
  final int underMaintenanceCount;
  final int dueCount;
  final int upcomingCount;
  final List<Equipment> dueEquipment;
  final List<Equipment> upcomingEquipment;
  final List<Equipment> underMaintenanceEquipment;

  const OwnerMaintenanceSnapshot({
    required this.totalOwnedEquipment,
    required this.availableCount,
    required this.unavailableCount,
    required this.underMaintenanceCount,
    required this.dueCount,
    required this.upcomingCount,
    required this.dueEquipment,
    required this.upcomingEquipment,
    required this.underMaintenanceEquipment,
  });
}

class OwnerRentalForecastEquipmentMatch {
  final String equipmentId;
  final String equipmentName;
  final String categoryLabel;
  final DemandForecastLevel demandLevel;
  final bool isAvailable;
  final bool isUnderMaintenance;
  final String recommendation;

  const OwnerRentalForecastEquipmentMatch({
    required this.equipmentId,
    required this.equipmentName,
    required this.categoryLabel,
    required this.demandLevel,
    required this.isAvailable,
    required this.isUnderMaintenance,
    required this.recommendation,
  });
}

class OwnerRentalForecastSnapshot {
  final int requestsConsidered;
  final int requestsWithForecastInputs;
  final DemandForecastConfidence confidence;
  final String summary;
  final List<DemandForecastInsight> categoryInsights;
  final List<OwnerRentalForecastEquipmentMatch> equipmentMatches;

  const OwnerRentalForecastSnapshot({
    required this.requestsConsidered,
    required this.requestsWithForecastInputs,
    required this.confidence,
    required this.summary,
    this.categoryInsights = const [],
    this.equipmentMatches = const [],
  });

  bool get hasInsights => categoryInsights.isNotEmpty;

  double get forecastInputCoverageRate => requestsConsidered == 0
      ? 0
      : requestsWithForecastInputs / requestsConsidered;
}

class OwnerRentalReport {
  final OwnerRentalReportFilter filter;
  final List<OwnerRentalTransactionRow> allRows;
  final List<OwnerRentalTransactionRow> filteredRows;
  final List<Equipment> scopedEquipment;
  final OwnerRentalSummary summary;
  final List<OwnerRentalEquipmentPerformance> equipmentPerformance;
  final List<OwnerRentalCategoryPerformance> categoryPerformance;
  final List<OwnerRentalUtilizationItem> utilizationItems;
  final OwnerMaintenanceSnapshot maintenanceSnapshot;
  final OwnerRentalForecastSnapshot forecastSnapshot;
  final AnalyticsTimeWindow utilizationWindow;

  const OwnerRentalReport({
    required this.filter,
    required this.allRows,
    required this.filteredRows,
    required this.scopedEquipment,
    required this.summary,
    required this.equipmentPerformance,
    required this.categoryPerformance,
    required this.utilizationItems,
    required this.maintenanceSnapshot,
    required this.forecastSnapshot,
    required this.utilizationWindow,
  });

  String? resolveEquipmentName(String? equipmentId) {
    if (equipmentId == null) return null;

    for (final equipment in scopedEquipment) {
      if (equipment.id == equipmentId) {
        return equipment.name;
      }
    }

    for (final row in allRows) {
      if (row.request.itemId == equipmentId) {
        return row.request.itemName;
      }
    }

    return null;
  }
}

const Object _sentinel = Object();
