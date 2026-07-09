import 'package:bukidbayan_app/models/analytics_time_window.dart';
import 'package:bukidbayan_app/models/demand_forecast.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/owner_rental_report.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/services/analytics/demand_forecast_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RentalAnalyticsService {
  final FirebaseFirestore _firestore;
  final DemandForecastService _demandForecastService;
  final DateTime Function() _now;

  RentalAnalyticsService({
    FirebaseFirestore? firestore,
    DemandForecastService? demandForecastService,
    DateTime Function()? now,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _demandForecastService =
           demandForecastService ?? DemandForecastService(),
       _now = now ?? DateTime.now;

  Future<OwnerRentalReportSource> loadOwnerReportSource({
    required String ownerId,
  }) async {
    final requestsFuture = _firestore
        .collection('rentRequests')
        .where('ownerId', isEqualTo: ownerId)
        .get();
    final equipmentFuture = _firestore
        .collection('equipment')
        .where('ownerId', isEqualTo: ownerId)
        .get();

    final requestSnapshot = await requestsFuture;
    final equipmentSnapshot = await equipmentFuture;

    final ownedEquipment =
        equipmentSnapshot.docs.map(Equipment.fromFirestore).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    final equipmentById = <String, Equipment>{
      for (final equipment in ownedEquipment)
        if (equipment.id != null) equipment.id!: equipment,
    };

    final allRequests = requestSnapshot.docs.map(RentRequest.fromDoc).toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    final requests = allRequests
        .where((request) => request.status == RentRequestStatus.completed)
        .toList(growable: false);

    final missingEquipmentIds = allRequests
        .map((request) => request.itemId)
        .where((itemId) => !equipmentById.containsKey(itemId))
        .toSet()
        .toList();

    if (missingEquipmentIds.isNotEmpty) {
      final missingDocs = await Future.wait(
        missingEquipmentIds.map(
          (itemId) => _firestore.collection('equipment').doc(itemId).get(),
        ),
      );
      for (final doc in missingDocs) {
        if (!doc.exists) continue;
        final equipment = Equipment.fromFirestore(doc);
        if (equipment.id != null) {
          equipmentById[equipment.id!] = equipment;
        }
      }
    }

    final rows =
        requests
            .map(
              (request) => OwnerRentalTransactionRow(
                request: request,
                equipment: equipmentById[request.itemId],
              ),
            )
            .toList()
          ..sort((a, b) => b.request.start.compareTo(a.request.start));

    return OwnerRentalReportSource(
      ownerId: ownerId,
      rows: rows,
      ownedEquipment: ownedEquipment,
      forecastRequests: allRequests
          .where((request) => !_isForecastExcludedStatus(request.status))
          .toList(growable: false),
      equipmentById: equipmentById,
    );
  }

  Future<OwnerRentalReport> generateOwnerRentalReport({
    required String ownerId,
    OwnerRentalReportFilter filter = const OwnerRentalReportFilter(),
  }) async {
    final source = await loadOwnerReportSource(ownerId: ownerId);
    return buildOwnerRentalReport(source: source, filter: filter);
  }

  OwnerRentalReport buildOwnerRentalReport({
    required OwnerRentalReportSource source,
    OwnerRentalReportFilter filter = const OwnerRentalReportFilter(),
  }) {
    final filteredRows = source.rows
        .where((row) => _matchesRowFilter(row: row, filter: filter))
        .toList();
    final scopedEquipment = _scopeEquipment(
      ownedEquipment: source.ownedEquipment,
      filter: filter,
    );
    final utilizationWindow = _resolveUtilizationWindow(
      source: source,
      filter: filter,
    );

    return OwnerRentalReport(
      filter: filter,
      allRows: source.rows,
      filteredRows: filteredRows,
      scopedEquipment: scopedEquipment,
      summary: _buildSummary(filteredRows),
      equipmentPerformance: _buildEquipmentPerformance(filteredRows),
      categoryPerformance: _buildCategoryPerformance(filteredRows),
      utilizationItems: _buildUtilizationItems(
        rows: filteredRows,
        scopedEquipment: scopedEquipment,
        window: utilizationWindow,
      ),
      maintenanceSnapshot: _buildMaintenanceSnapshot(scopedEquipment),
      forecastSnapshot: _buildForecastSnapshot(
        source: source,
        scopedEquipment: scopedEquipment,
        filter: filter,
      ),
      utilizationWindow: utilizationWindow,
    );
  }

  bool _matchesRowFilter({
    required OwnerRentalTransactionRow row,
    required OwnerRentalReportFilter filter,
  }) {
    final query = filter.searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      final matchesName = row.request.name.toLowerCase().contains(query);
      final matchesItem = row.request.itemName.toLowerCase().contains(query);
      final matchesLocation = row.farmLocation.toLowerCase().contains(query);
      if (!matchesName && !matchesItem && !matchesLocation) {
        return false;
      }
    }

    if (filter.timeWindow != null) {
      final start = filter.timeWindow!.startOfDay;
      final endExclusive = filter.timeWindow!.endExclusive;
      final rentedAt = row.request.start;
      if (rentedAt.isBefore(start) || !rentedAt.isBefore(endExclusive)) {
        return false;
      }
    }

    if (filter.equipmentId != null &&
        row.request.itemId != filter.equipmentId) {
      return false;
    }

    switch (filter.operatorFilter) {
      case OwnerOperatorFilter.all:
        break;
      case OwnerOperatorFilter.withOperator:
        if (!row.withOperator) return false;
        break;
      case OwnerOperatorFilter.withoutOperator:
        if (row.withOperator) return false;
        break;
    }

    final payment = row.totalPayment ?? 0;
    if (filter.minPayment != null && payment < filter.minPayment!) {
      return false;
    }
    if (filter.maxPayment != null && payment > filter.maxPayment!) {
      return false;
    }

    return true;
  }

  List<Equipment> _scopeEquipment({
    required List<Equipment> ownedEquipment,
    required OwnerRentalReportFilter filter,
  }) {
    final scoped =
        ownedEquipment.where((equipment) {
          if (filter.equipmentId != null &&
              equipment.id != filter.equipmentId) {
            return false;
          }

          switch (filter.operatorFilter) {
            case OwnerOperatorFilter.all:
              break;
            case OwnerOperatorFilter.withOperator:
              if (!equipment.operatorIncluded) return false;
              break;
            case OwnerOperatorFilter.withoutOperator:
              if (equipment.operatorIncluded) return false;
              break;
          }

          return true;
        }).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    return scoped;
  }

  OwnerRentalSummary _buildSummary(List<OwnerRentalTransactionRow> rows) {
    final totalEarnings = rows.fold<double>(
      0,
      (total, row) => total + (row.totalPayment ?? 0),
    );
    final totalBookedDays = rows.fold<int>(
      0,
      (total, row) => total + row.daysRented,
    );
    final estimatedBookedHours = rows.fold<double>(
      0,
      (total, row) => total + row.estimatedBookedHours,
    );
    final uniqueFarmersServed = rows
        .map((row) => row.request.renterId)
        .toSet()
        .length;
    final completedRentals = rows.length;
    final averageRentalDurationDays = completedRentals == 0
        ? 0.0
        : totalBookedDays / completedRentals;

    return OwnerRentalSummary(
      totalEarnings: totalEarnings,
      completedRentals: completedRentals,
      uniqueFarmersServed: uniqueFarmersServed,
      totalBookedDays: totalBookedDays,
      estimatedBookedHours: estimatedBookedHours,
      averageRentalDurationDays: averageRentalDurationDays,
    );
  }

  List<OwnerRentalEquipmentPerformance> _buildEquipmentPerformance(
    List<OwnerRentalTransactionRow> rows,
  ) {
    final grouped = <String, List<OwnerRentalTransactionRow>>{};

    for (final row in rows) {
      grouped.putIfAbsent(row.request.itemId, () => []).add(row);
    }

    final performance =
        grouped.entries.map((entry) {
          final groupRows = entry.value;
          final sample = groupRows.first;
          final totalEarnings = groupRows.fold<double>(
            0,
            (total, row) => total + (row.totalPayment ?? 0),
          );
          final bookedDays = groupRows.fold<int>(
            0,
            (total, row) => total + row.daysRented,
          );
          final estimatedBookedHours = groupRows.fold<double>(
            0,
            (total, row) => total + row.estimatedBookedHours,
          );
          final uniqueFarmersServed = groupRows
              .map((row) => row.request.renterId)
              .toSet()
              .length;

          return OwnerRentalEquipmentPerformance(
            itemId: entry.key,
            itemName: sample.request.itemName,
            categoryLabel: sample.categoryLabel,
            withOperator: sample.withOperator,
            totalEarnings: totalEarnings,
            completedRentals: groupRows.length,
            bookedDays: bookedDays,
            estimatedBookedHours: estimatedBookedHours,
            uniqueFarmersServed: uniqueFarmersServed,
          );
        }).toList()..sort((a, b) {
          final earningsCompare = b.totalEarnings.compareTo(a.totalEarnings);
          if (earningsCompare != 0) return earningsCompare;
          final rentalCompare = b.completedRentals.compareTo(
            a.completedRentals,
          );
          if (rentalCompare != 0) return rentalCompare;
          return a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase());
        });

    return performance;
  }

  List<OwnerRentalCategoryPerformance> _buildCategoryPerformance(
    List<OwnerRentalTransactionRow> rows,
  ) {
    final grouped = <String, List<OwnerRentalTransactionRow>>{};

    for (final row in rows) {
      grouped.putIfAbsent(row.categoryLabel, () => []).add(row);
    }

    final performance =
        grouped.entries.map((entry) {
          final groupRows = entry.value;
          final totalEarnings = groupRows.fold<double>(
            0,
            (total, row) => total + (row.totalPayment ?? 0),
          );
          final bookedDays = groupRows.fold<int>(
            0,
            (total, row) => total + row.daysRented,
          );
          final estimatedBookedHours = groupRows.fold<double>(
            0,
            (total, row) => total + row.estimatedBookedHours,
          );
          final uniqueFarmersServed = groupRows
              .map((row) => row.request.renterId)
              .toSet()
              .length;

          return OwnerRentalCategoryPerformance(
            categoryLabel: entry.key,
            totalEarnings: totalEarnings,
            completedRentals: groupRows.length,
            bookedDays: bookedDays,
            estimatedBookedHours: estimatedBookedHours,
            uniqueFarmersServed: uniqueFarmersServed,
          );
        }).toList()..sort((a, b) {
          final earningsCompare = b.totalEarnings.compareTo(a.totalEarnings);
          if (earningsCompare != 0) return earningsCompare;
          return a.categoryLabel.toLowerCase().compareTo(
            b.categoryLabel.toLowerCase(),
          );
        });

    return performance;
  }

  List<OwnerRentalUtilizationItem> _buildUtilizationItems({
    required List<OwnerRentalTransactionRow> rows,
    required List<Equipment> scopedEquipment,
    required AnalyticsTimeWindow window,
  }) {
    final bookedHoursByEquipment = <String, double>{};

    for (final row in rows) {
      bookedHoursByEquipment.update(
        row.request.itemId,
        (value) => value + row.estimatedBookedHours,
        ifAbsent: () => row.estimatedBookedHours,
      );
    }

    final items =
        scopedEquipment.where((equipment) => equipment.id != null).map((
          equipment,
        ) {
          final equipmentId = equipment.id!;
          final bookedHours = bookedHoursByEquipment[equipmentId] ?? 0;
          final schedulableHours = _estimateSchedulableHours(
            equipment: equipment,
            window: window,
          );
          final utilizationRate = schedulableHours <= 0
              ? 0
              : bookedHours / schedulableHours;

          return OwnerRentalUtilizationItem(
            equipmentId: equipmentId,
            equipmentName: equipment.name,
            categoryLabel: _equipmentCategoryLabel(equipment),
            withOperator: equipment.operatorIncluded,
            bookedHours: bookedHours,
            schedulableHours: schedulableHours,
            utilizationRate: utilizationRate.clamp(0, 1).toDouble(),
            isUnderMaintenance:
                equipment.status == EquipmentStatus.underMaintenance,
            isMaintenanceDue: equipment.isForMaintenance,
            isMaintenanceUpcoming: equipment.isUpcomingMaintenance,
          );
        }).toList()..sort((a, b) {
          final utilizationCompare = b.utilizationRate.compareTo(
            a.utilizationRate,
          );
          if (utilizationCompare != 0) return utilizationCompare;
          final bookedCompare = b.bookedHours.compareTo(a.bookedHours);
          if (bookedCompare != 0) return bookedCompare;
          return a.equipmentName.toLowerCase().compareTo(
            b.equipmentName.toLowerCase(),
          );
        });

    return items;
  }

  double _estimateSchedulableHours({
    required Equipment equipment,
    required AnalyticsTimeWindow window,
  }) {
    final rawStart =
        equipment.availableFrom ?? equipment.createdAt ?? window.startOfDay;
    final rawEnd = equipment.availableUntil ?? window.end;

    final start = _maxDate(
      DateTime(rawStart.year, rawStart.month, rawStart.day),
      window.startOfDay,
    );
    final endExclusive = _minDate(
      DateTime(
        rawEnd.year,
        rawEnd.month,
        rawEnd.day,
      ).add(const Duration(days: 1)),
      window.endExclusive,
    );

    if (!endExclusive.isAfter(start)) {
      return 0;
    }

    return endExclusive.difference(start).inHours.toDouble();
  }

  OwnerMaintenanceSnapshot _buildMaintenanceSnapshot(
    List<Equipment> equipment,
  ) {
    final dueEquipment =
        equipment.where((item) => item.isForMaintenance).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    final upcomingEquipment =
        equipment.where((item) => item.isUpcomingMaintenance).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    final underMaintenanceEquipment =
        equipment
            .where((item) => item.status == EquipmentStatus.underMaintenance)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    return OwnerMaintenanceSnapshot(
      totalOwnedEquipment: equipment.length,
      availableCount: equipment
          .where((item) => item.status == EquipmentStatus.available)
          .length,
      unavailableCount: equipment
          .where((item) => item.status == EquipmentStatus.unavailable)
          .length,
      underMaintenanceCount: underMaintenanceEquipment.length,
      dueCount: dueEquipment.length,
      upcomingCount: upcomingEquipment.length,
      dueEquipment: dueEquipment,
      upcomingEquipment: upcomingEquipment,
      underMaintenanceEquipment: underMaintenanceEquipment,
    );
  }

  OwnerRentalForecastSnapshot _buildForecastSnapshot({
    required OwnerRentalReportSource source,
    required List<Equipment> scopedEquipment,
    required OwnerRentalReportFilter filter,
  }) {
    final equipmentById = source.equipmentById;
    final filteredRequests = source.forecastRequests
        .where((request) {
          final row = OwnerRentalTransactionRow(
            request: request,
            equipment: equipmentById[request.itemId],
          );
          return _matchesRowFilter(row: row, filter: filter);
        })
        .toList(growable: false);

    final scopedCategoryMap = <String, String>{
      for (final equipment in scopedEquipment)
        if (equipment.id != null &&
            equipment.category != null &&
            equipment.category!.trim().isNotEmpty)
          equipment.id!: equipment.category!.trim(),
    };

    final demandSnapshot = _demandForecastService.buildWeeklyForecast(
      requests: filteredRequests,
      equipmentCategoryByItemId: scopedCategoryMap,
      maxInsights: 12,
    );

    final categoryInsights = demandSnapshot.insights
        .where(
          (insight) => scopedEquipment.any(
            (equipment) =>
                equipment.category?.trim() == insight.equipmentCategory,
          ),
        )
        .toList(growable: false);
    final equipmentMatches = _buildForecastEquipmentMatches(
      scopedEquipment: scopedEquipment,
      insights: categoryInsights,
    );
    final equipmentTrends = _buildForecastEquipmentTrends(
      scopedEquipment: scopedEquipment,
      requests: filteredRequests,
    );

    return OwnerRentalForecastSnapshot(
      requestsConsidered: filteredRequests.length,
      requestsWithForecastInputs: filteredRequests
          .where(_hasForecastInputs)
          .length,
      confidence: demandSnapshot.confidence,
      summary: demandSnapshot.summary,
      categoryInsights: categoryInsights,
      equipmentMatches: equipmentMatches,
      equipmentTrends: equipmentTrends,
    );
  }

  List<OwnerRentalForecastEquipmentMatch> _buildForecastEquipmentMatches({
    required List<Equipment> scopedEquipment,
    required List<DemandForecastInsight> insights,
  }) {
    final matches = <OwnerRentalForecastEquipmentMatch>[];
    final seenEquipmentIds = <String>{};

    for (final insight in insights) {
      for (final equipment in scopedEquipment) {
        final equipmentId = equipment.id;
        final category = equipment.category?.trim();
        if (equipmentId == null || category != insight.equipmentCategory) {
          continue;
        }
        if (!seenEquipmentIds.add(equipmentId)) continue;

        matches.add(
          OwnerRentalForecastEquipmentMatch(
            equipmentId: equipmentId,
            equipmentName: equipment.name,
            categoryLabel: insight.equipmentCategory,
            demandLevel: insight.level,
            isAvailable: equipment.status == EquipmentStatus.available,
            isUnderMaintenance:
                equipment.status == EquipmentStatus.underMaintenance,
            recommendation: _buildEquipmentRecommendation(
              equipment: equipment,
              insight: insight,
            ),
          ),
        );
      }
    }

    matches.sort((a, b) {
      final demandCompare = _forecastLevelRank(
        b.demandLevel,
      ).compareTo(_forecastLevelRank(a.demandLevel));
      if (demandCompare != 0) return demandCompare;
      final maintenanceCompare = a.isUnderMaintenance == b.isUnderMaintenance
          ? 0
          : (a.isUnderMaintenance ? 1 : -1);
      if (maintenanceCompare != 0) return maintenanceCompare;
      return a.equipmentName.toLowerCase().compareTo(
        b.equipmentName.toLowerCase(),
      );
    });

    return matches.take(5).toList(growable: false);
  }

  String _buildEquipmentRecommendation({
    required Equipment equipment,
    required DemandForecastInsight insight,
  }) {
    if (equipment.status == EquipmentStatus.underMaintenance) {
      return 'Demand is building for this tool, but it is currently under maintenance.';
    }
    if (equipment.status == EquipmentStatus.unavailable) {
      return 'Demand is building for this tool. Review availability dates and relist it when ready.';
    }
    return insight.recommendation;
  }

  List<OwnerRentalDemandTrendItem> _buildForecastEquipmentTrends({
    required List<Equipment> scopedEquipment,
    required List<RentRequest> requests,
  }) {
    final today = _dayKey(_now());
    final currentMonth = today.month;
    final recentWindowStart = today.subtract(const Duration(days: 29));
    final previousWindowStart = today.subtract(const Duration(days: 59));
    final previousWindowEndExclusive = recentWindowStart;
    final grouped = <String, List<RentRequest>>{};

    for (final request in requests) {
      grouped.putIfAbsent(request.itemId, () => <RentRequest>[]).add(request);
    }

    final trends = <OwnerRentalDemandTrendItem>[];
    for (final equipment in scopedEquipment) {
      final equipmentId = equipment.id;
      if (equipmentId == null) continue;
      final equipmentRequests = grouped[equipmentId] ?? const [];
      if (equipmentRequests.isEmpty) continue;

      var recentCount = 0;
      var previousCount = 0;
      var sameMonthHistoricalCount = 0;
      final sameMonthYears = <int>{};
      final countsByCalendarMonth = <int, int>{};
      final activeYearMonths = <int>{};
      DateTime? latestRequestAt;

      for (final request in equipmentRequests) {
        final signalDate = _dayKey(request.createdAt ?? request.start);
        if (latestRequestAt == null || signalDate.isAfter(latestRequestAt)) {
          latestRequestAt = signalDate;
        }
        countsByCalendarMonth.update(
          signalDate.month,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        activeYearMonths.add(signalDate.year * 100 + signalDate.month);
        if (signalDate.month == currentMonth) {
          sameMonthHistoricalCount += 1;
          sameMonthYears.add(signalDate.year);
        }
        if (!_isBeforeDay(signalDate, recentWindowStart) &&
            !_isAfterDay(signalDate, today)) {
          recentCount += 1;
          continue;
        }
        if (!_isBeforeDay(signalDate, previousWindowStart) &&
            signalDate.isBefore(previousWindowEndExclusive)) {
          previousCount += 1;
        }
      }

      if (recentCount == 0 && previousCount == 0) continue;

      final trend = _resolveDemandTrend(
        recentCount: recentCount,
        previousCount: previousCount,
      );
      final peakMonthEntry = countsByCalendarMonth.entries.toList()
        ..sort((a, b) {
          final countCompare = b.value.compareTo(a.value);
          if (countCompare != 0) return countCompare;
          return a.key.compareTo(b.key);
        });
      final peakMonth = peakMonthEntry.first.key;
      final peakMonthRequestCount = peakMonthEntry.first.value;
      final totalHistoricalRequests = equipmentRequests.length;
      final activeHistoricalMonths = activeYearMonths.length;
      final averageRequestsPerActiveMonth = activeHistoricalMonths == 0
          ? 0.0
          : totalHistoricalRequests / activeHistoricalMonths;

      trends.add(
        OwnerRentalDemandTrendItem(
          equipmentId: equipmentId,
          equipmentName: equipment.name,
          categoryLabel: _equipmentCategoryLabel(equipment),
          trend: trend,
          recentRequestCount: recentCount,
          previousRequestCount: previousCount,
          totalHistoricalRequests: totalHistoricalRequests,
          activeHistoricalMonths: activeHistoricalMonths,
          averageRequestsPerActiveMonth: averageRequestsPerActiveMonth,
          sameMonthHistoricalCount: sameMonthHistoricalCount,
          sameMonthHistoricalYears: sameMonthYears.length,
          sameMonthLabel: _monthLabel(currentMonth),
          peakMonth: peakMonth,
          peakMonthLabel: _monthLabel(peakMonth),
          peakMonthRequestCount: peakMonthRequestCount,
          latestRequestAt: latestRequestAt,
          note: _buildTrendNote(
            equipmentName: equipment.name,
            trend: trend,
            recentCount: recentCount,
            previousCount: previousCount,
            totalHistoricalRequests: totalHistoricalRequests,
            activeHistoricalMonths: activeHistoricalMonths,
            averageRequestsPerActiveMonth: averageRequestsPerActiveMonth,
            sameMonthHistoricalCount: sameMonthHistoricalCount,
            sameMonthHistoricalYears: sameMonthYears.length,
            sameMonthLabel: _monthLabel(currentMonth),
            peakMonthLabel: _monthLabel(peakMonth),
            peakMonthRequestCount: peakMonthRequestCount,
          ),
        ),
      );
    }

    trends.sort((a, b) {
      final trendCompare = _forecastTrendRank(
        b.trend,
      ).compareTo(_forecastTrendRank(a.trend));
      if (trendCompare != 0) return trendCompare;
      final recentCompare = b.recentRequestCount.compareTo(
        a.recentRequestCount,
      );
      if (recentCompare != 0) return recentCompare;
      return a.equipmentName.toLowerCase().compareTo(
        b.equipmentName.toLowerCase(),
      );
    });

    return trends.take(5).toList(growable: false);
  }

  OwnerRentalDemandTrend _resolveDemandTrend({
    required int recentCount,
    required int previousCount,
  }) {
    if (previousCount == 0 && recentCount > 0) {
      return OwnerRentalDemandTrend.emerging;
    }
    if (recentCount > previousCount) {
      return OwnerRentalDemandTrend.rising;
    }
    if (recentCount < previousCount) {
      return OwnerRentalDemandTrend.softening;
    }
    return OwnerRentalDemandTrend.steady;
  }

  String _buildTrendNote({
    required String equipmentName,
    required OwnerRentalDemandTrend trend,
    required int recentCount,
    required int previousCount,
    required int totalHistoricalRequests,
    required int activeHistoricalMonths,
    required double averageRequestsPerActiveMonth,
    required int sameMonthHistoricalCount,
    required int sameMonthHistoricalYears,
    required String sameMonthLabel,
    required String peakMonthLabel,
    required int peakMonthRequestCount,
  }) {
    final base = switch (trend) {
      OwnerRentalDemandTrend.emerging =>
        '$equipmentName is seeing new demand in the last 30 days.',
      OwnerRentalDemandTrend.rising =>
        '$equipmentName has more requests in the last 30 days than the prior 30 days.',
      OwnerRentalDemandTrend.steady =>
        '$equipmentName has held a steady request pattern across the last two 30-day windows.',
      OwnerRentalDemandTrend.softening =>
        '$equipmentName has fewer recent requests than the prior 30-day window.',
    };

    final notes = <String>[base];

    if (sameMonthHistoricalCount >= 2) {
      final yearsLabel = sameMonthHistoricalYears <= 1
          ? 'the current records'
          : '$sameMonthHistoricalYears different year${sameMonthHistoricalYears == 1 ? '' : 's'}';
      notes.add(
        '$equipmentName was also rented $sameMonthHistoricalCount time${sameMonthHistoricalCount == 1 ? '' : 's'} in $sameMonthLabel across $yearsLabel.',
      );
    }

    if (peakMonthRequestCount >= 2) {
      if (peakMonthLabel == sameMonthLabel) {
        notes.add(
          '$sameMonthLabel is historically a peak month for $equipmentName.',
        );
      } else {
        notes.add(
          '$equipmentName usually peaks in $peakMonthLabel with $peakMonthRequestCount recorded request${peakMonthRequestCount == 1 ? '' : 's'}.',
        );
      }
    }

    if (averageRequestsPerActiveMonth > 0 &&
        sameMonthHistoricalCount >= averageRequestsPerActiveMonth * 1.25 &&
        totalHistoricalRequests >= 3 &&
        activeHistoricalMonths >= 2) {
      notes.add(
        '$sameMonthLabel is running above this tool\'s usual monthly average of ${averageRequestsPerActiveMonth.toStringAsFixed(1)} requests.',
      );
    }

    return notes.join(' ');
  }

  AnalyticsTimeWindow _resolveUtilizationWindow({
    required OwnerRentalReportSource source,
    required OwnerRentalReportFilter filter,
  }) {
    if (filter.timeWindow != null) {
      return filter.timeWindow!;
    }

    final now = DateTime.now();
    DateTime? earliest;

    for (final row in source.rows) {
      if (earliest == null || row.request.start.isBefore(earliest)) {
        earliest = row.request.start;
      }
    }

    for (final equipment in source.ownedEquipment) {
      final candidate = equipment.availableFrom ?? equipment.createdAt;
      if (candidate == null) continue;
      if (earliest == null || candidate.isBefore(earliest)) {
        earliest = candidate;
      }
    }

    final resolvedStart = earliest ?? now;
    return AnalyticsTimeWindow(start: resolvedStart, end: now);
  }

  String _equipmentCategoryLabel(Equipment equipment) {
    final category = equipment.category?.trim();
    if (category == null || category.isEmpty) {
      return 'Uncategorized';
    }
    return category;
  }

  DateTime _maxDate(DateTime left, DateTime right) {
    return left.isAfter(right) ? left : right;
  }

  DateTime _minDate(DateTime left, DateTime right) {
    return left.isBefore(right) ? left : right;
  }

  DateTime _dayKey(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _isBeforeDay(DateTime value, DateTime reference) =>
      value.isBefore(_dayKey(reference));

  bool _isAfterDay(DateTime value, DateTime reference) =>
      value.isAfter(_dayKey(reference));

  bool _isForecastExcludedStatus(RentRequestStatus status) =>
      status == RentRequestStatus.declined ||
      status == RentRequestStatus.canceled;

  bool _hasForecastInputs(RentRequest request) {
    return _hasNonEmptyString(request.cropType) ||
        _hasNonEmptyString(request.farmingPhase) ||
        _hasNonEmptyString(request.intendedUse);
  }

  bool _hasNonEmptyString(String? value) =>
      value != null && value.trim().isNotEmpty;

  String _monthLabel(int month) {
    const labels = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return labels[(month - 1).clamp(0, 11)];
  }

  int _forecastLevelRank(DemandForecastLevel level) {
    switch (level) {
      case DemandForecastLevel.high:
        return 3;
      case DemandForecastLevel.medium:
        return 2;
      case DemandForecastLevel.low:
        return 1;
    }
  }

  int _forecastTrendRank(OwnerRentalDemandTrend trend) {
    switch (trend) {
      case OwnerRentalDemandTrend.emerging:
        return 4;
      case OwnerRentalDemandTrend.rising:
        return 3;
      case OwnerRentalDemandTrend.steady:
        return 2;
      case OwnerRentalDemandTrend.softening:
        return 1;
    }
  }
}
