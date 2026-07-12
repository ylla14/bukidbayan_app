import 'package:bukidbayan_app/models/analytics_time_window.dart';
import 'package:bukidbayan_app/models/demand_forecast.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/owner_rental_report.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/services/earnings_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds an owner analytics PDF with forecast content', () async {
    final equipment = Equipment(
      id: 'eq-1',
      name: 'Four-wheel Tractor',
      description: 'Heavy-duty tractor',
      category: 'Tractors',
      condition: 'Good',
      price: 2500,
      rentalUnit: 'day',
      landSizeRequirement: false,
      maxCropHeightRequirement: false,
      ownerId: 'owner-1',
      operatorIncluded: true,
      maintenanceRequired: true,
      maintenanceIntervalHrs: 240,
      hoursUsedSinceLastMaintenance: 120,
    );

    final request = RentRequest(
      requestId: 'rent-1',
      itemId: 'eq-1',
      itemName: 'Four-wheel Tractor',
      name: 'Farmer One',
      address: 'Barangay Uno',
      farmAddress: 'Sitio Maligaya',
      start: DateTime(2026, 7, 1),
      end: DateTime(2026, 7, 3),
      status: RentRequestStatus.completed,
      renterId: 'renter-1',
      ownerId: 'owner-1',
      createdAt: DateTime(2026, 6, 28, 8),
      agreedPrice: 5000,
      agreedRentalUnit: 'day',
      cropType: 'Rice',
      farmingPhase: 'Land Preparation',
      intendedUse: 'Primary tillage',
      hectaresEntered: 2.5,
    );

    final report = OwnerRentalReport(
      filter: OwnerRentalReportFilter(
        timeWindow: AnalyticsTimeWindow(
          start: DateTime(2026, 7, 1),
          end: DateTime(2026, 7, 31),
        ),
      ),
      allRows: [
        OwnerRentalTransactionRow(request: request, equipment: equipment),
      ],
      filteredRows: [
        OwnerRentalTransactionRow(request: request, equipment: equipment),
      ],
      scopedEquipment: [equipment],
      summary: const OwnerRentalSummary(
        totalEarnings: 5000,
        completedRentals: 1,
        uniqueFarmersServed: 1,
        totalBookedDays: 2,
        estimatedBookedHours: 48,
        averageRentalDurationDays: 2,
      ),
      equipmentPerformance: const [
        OwnerRentalEquipmentPerformance(
          itemId: 'eq-1',
          itemName: 'Four-wheel Tractor',
          categoryLabel: 'Tractors',
          withOperator: true,
          totalEarnings: 5000,
          completedRentals: 1,
          bookedDays: 2,
          estimatedBookedHours: 48,
          uniqueFarmersServed: 1,
        ),
      ],
      categoryPerformance: const [
        OwnerRentalCategoryPerformance(
          categoryLabel: 'Tractors',
          totalEarnings: 5000,
          completedRentals: 1,
          bookedDays: 2,
          estimatedBookedHours: 48,
          uniqueFarmersServed: 1,
        ),
      ],
      utilizationItems: const [
        OwnerRentalUtilizationItem(
          equipmentId: 'eq-1',
          equipmentName: 'Four-wheel Tractor',
          categoryLabel: 'Tractors',
          withOperator: true,
          bookedHours: 48,
          schedulableHours: 144,
          utilizationRate: 0.3333,
          isUnderMaintenance: false,
          isMaintenanceDue: false,
          isMaintenanceUpcoming: false,
        ),
      ],
      maintenanceSnapshot: OwnerMaintenanceSnapshot(
        totalOwnedEquipment: 1,
        availableCount: 1,
        unavailableCount: 0,
        underMaintenanceCount: 0,
        dueCount: 0,
        upcomingCount: 0,
        dueEquipment: const [],
        upcomingEquipment: const [],
        underMaintenanceEquipment: const [],
      ),
      forecastSnapshot: OwnerRentalForecastSnapshot(
        requestsConsidered: 4,
        requestsWithForecastInputs: 3,
        confidence: DemandForecastConfidence.high,
        summary:
            'Tractor demand is strengthening based on recent owner-side request signals.',
        categoryInsights: [
          DemandForecastInsight(
            equipmentCategory: 'Tractors',
            score: 0.92,
            level: DemandForecastLevel.high,
            matchedRequests: 3,
            recentRequests: 2,
            drivers: [
              'Repeated rice land preparation requests',
              'Peak seasonal demand pattern',
            ],
            recommendation:
                'Keep the tractor available this month and prioritize fast confirmations.',
          ),
        ],
        equipmentMatches: [
          OwnerRentalForecastEquipmentMatch(
            equipmentId: 'eq-1',
            equipmentName: 'Four-wheel Tractor',
            categoryLabel: 'Tractors',
            demandLevel: DemandForecastLevel.high,
            isAvailable: true,
            isUnderMaintenance: false,
            recommendation:
                'Prepare this tool for immediate dispatch to capture demand.',
          ),
        ],
        equipmentTrends: [
          OwnerRentalDemandTrendItem(
            equipmentId: 'eq-1',
            equipmentName: 'Four-wheel Tractor',
            categoryLabel: 'Tractors',
            trend: OwnerRentalDemandTrend.rising,
            recentRequestCount: 2,
            previousRequestCount: 1,
            totalHistoricalRequests: 8,
            activeHistoricalMonths: 4,
            averageRequestsPerActiveMonth: 2,
            sameMonthHistoricalCount: 3,
            sameMonthHistoricalYears: 2,
            sameMonthLabel: 'July',
            peakMonth: 7,
            peakMonthLabel: 'July',
            peakMonthRequestCount: 3,
            latestRequestAt: DateTime(2026, 7, 4),
            note:
                'Recent demand is trending up and aligns with historical July activity.',
          ),
        ],
      ),
      utilizationWindow: AnalyticsTimeWindow(
        start: DateTime(2026, 7, 1),
        end: DateTime(2026, 7, 31),
      ),
    );

    final bytes = await EarningsPdfService.buildPdfBytes(
      report: report,
      ownerName: 'Owner One',
    );

    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(1000));
  });

  test(
    'builds large all-time earnings PDFs without too many pages exceptions',
    () async {
      final equipment = Equipment(
        id: 'eq-1',
        name: 'Four-wheel Tractor',
        description: 'Heavy-duty tractor',
        category: 'Tractors',
        condition: 'Good',
        price: 2500,
        rentalUnit: 'day',
        landSizeRequirement: false,
        maxCropHeightRequirement: false,
        ownerId: 'owner-1',
        operatorIncluded: true,
        maintenanceRequired: true,
        maintenanceIntervalHrs: 240,
        hoursUsedSinceLastMaintenance: 120,
      );

      final rows = List.generate(260, (index) {
        final start = DateTime(2025, 1, 1).add(Duration(days: index * 3));
        final request = RentRequest(
          requestId: 'rent-$index',
          itemId: 'eq-1',
          itemName: 'Four-wheel Tractor',
          name: 'Farmer ${index + 1}',
          address: 'Barangay ${index + 1}',
          farmAddress: 'Sitio ${index + 1}, Cabuyao, Laguna',
          start: start,
          end: start.add(const Duration(days: 2)),
          status: RentRequestStatus.completed,
          renterId: 'renter-$index',
          ownerId: 'owner-1',
          createdAt: start.subtract(const Duration(days: 2)),
          agreedPrice: 4000 + index.toDouble(),
          agreedRentalUnit: 'day',
          hectaresEntered: 1.5 + (index % 3),
        );

        return OwnerRentalTransactionRow(
          request: request,
          equipment: equipment,
        );
      });

      final totalEarnings = rows.fold<double>(
        0,
        (sum, row) => sum + (row.totalPayment ?? 0),
      );
      final totalBookedDays = rows.fold<int>(
        0,
        (sum, row) => sum + row.daysRented,
      );
      final totalBookedHours = rows.fold<double>(
        0,
        (sum, row) => sum + row.estimatedBookedHours,
      );

      final report = OwnerRentalReport(
        filter: const OwnerRentalReportFilter(),
        allRows: rows,
        filteredRows: rows,
        scopedEquipment: [equipment],
        summary: OwnerRentalSummary(
          totalEarnings: totalEarnings,
          completedRentals: rows.length,
          uniqueFarmersServed: rows.length,
          totalBookedDays: totalBookedDays,
          estimatedBookedHours: totalBookedHours,
          averageRentalDurationDays: totalBookedDays / rows.length,
        ),
        equipmentPerformance: [
          OwnerRentalEquipmentPerformance(
            itemId: 'eq-1',
            itemName: 'Four-wheel Tractor',
            categoryLabel: 'Tractors',
            withOperator: true,
            totalEarnings: totalEarnings,
            completedRentals: rows.length,
            bookedDays: totalBookedDays,
            estimatedBookedHours: totalBookedHours,
            uniqueFarmersServed: rows.length,
          ),
        ],
        categoryPerformance: [
          OwnerRentalCategoryPerformance(
            categoryLabel: 'Tractors',
            totalEarnings: totalEarnings,
            completedRentals: rows.length,
            bookedDays: totalBookedDays,
            estimatedBookedHours: totalBookedHours,
            uniqueFarmersServed: rows.length,
          ),
        ],
        utilizationItems: [
          OwnerRentalUtilizationItem(
            equipmentId: 'eq-1',
            equipmentName: 'Four-wheel Tractor',
            categoryLabel: 'Tractors',
            withOperator: true,
            bookedHours: totalBookedHours,
            schedulableHours: totalBookedHours * 2,
            utilizationRate: 0.5,
            isUnderMaintenance: false,
            isMaintenanceDue: false,
            isMaintenanceUpcoming: false,
          ),
        ],
        maintenanceSnapshot: OwnerMaintenanceSnapshot(
          totalOwnedEquipment: 1,
          availableCount: 1,
          unavailableCount: 0,
          underMaintenanceCount: 0,
          dueCount: 0,
          upcomingCount: 0,
          dueEquipment: const [],
          upcomingEquipment: const [],
          underMaintenanceEquipment: const [],
        ),
        forecastSnapshot: OwnerRentalForecastSnapshot(
          requestsConsidered: rows.length,
          requestsWithForecastInputs: rows.length,
          confidence: DemandForecastConfidence.high,
          summary:
              'All-time demand remains healthy and this tool has consistent activity across the report window.',
          categoryInsights: const [
            DemandForecastInsight(
              equipmentCategory: 'Tractors',
              score: 0.88,
              level: DemandForecastLevel.high,
              matchedRequests: 260,
              recentRequests: 14,
              drivers: [
                'Consistent historical land preparation demand',
                'Stable request volume across seasons',
              ],
              recommendation:
                  'Keep this equipment available and prioritize maintenance around quieter periods.',
            ),
          ],
          equipmentMatches: const [
            OwnerRentalForecastEquipmentMatch(
              equipmentId: 'eq-1',
              equipmentName: 'Four-wheel Tractor',
              categoryLabel: 'Tractors',
              demandLevel: DemandForecastLevel.high,
              isAvailable: true,
              isUnderMaintenance: false,
              recommendation:
                  'This tool continues to match strong demand signals in the owner history.',
            ),
          ],
          equipmentTrends: [
            OwnerRentalDemandTrendItem(
              equipmentId: 'eq-1',
              equipmentName: 'Four-wheel Tractor',
              categoryLabel: 'Tractors',
              trend: OwnerRentalDemandTrend.rising,
              recentRequestCount: 14,
              previousRequestCount: 11,
              totalHistoricalRequests: rows.length,
              activeHistoricalMonths: 18,
              averageRequestsPerActiveMonth: 14.4,
              sameMonthHistoricalCount: 16,
              sameMonthHistoricalYears: 2,
              sameMonthLabel: 'January',
              peakMonth: 3,
              peakMonthLabel: 'March',
              peakMonthRequestCount: 19,
              latestRequestAt: rows.first.request.createdAt,
              note:
                  'Recent demand remains high enough that the all-time export should still paginate cleanly.',
            ),
          ],
        ),
        utilizationWindow: AnalyticsTimeWindow(
          start: DateTime(2025, 1, 1),
          end: DateTime(2027, 12, 31),
        ),
      );

      final legacyBytes = await EarningsPdfService.buildLegacyPdfBytes(
        report: report,
        ownerName: 'Owner One',
      );
      final analyticsBytes = await EarningsPdfService.buildPdfBytes(
        report: report,
        ownerName: 'Owner One',
      );

      expect(legacyBytes, isNotEmpty);
      expect(analyticsBytes, isNotEmpty);
      expect(legacyBytes.length, greaterThan(1000));
      expect(analyticsBytes.length, greaterThan(1000));
    },
  );
}
