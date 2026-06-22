import 'dart:math' as math;

import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/models/renter_analytics_report.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RenterAnalyticsService {
  RenterAnalyticsService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _rentRequests =>
      _db.collection('rentRequests');

  Future<RenterAnalyticsReport> generateReport({
    required String renterId,
    DateTime? now,
  }) async {
    final generatedAt = now ?? DateTime.now();
    final requestSnapshot = await _rentRequests
        .where('renterId', isEqualTo: renterId)
        .get();

    final requests = requestSnapshot.docs.map(RentRequest.fromDoc).toList()
      ..sort((a, b) {
        final aDate = a.createdAt ?? a.start;
        final bDate = b.createdAt ?? b.start;
        return aDate.compareTo(bDate);
      });

    final equipmentById = await _loadEquipmentMap(requests);
    final completedRequests = requests
        .where((request) => request.status == RentRequestStatus.completed)
        .toList();
    final activeRentals = requests
        .where((request) => _activeStatuses.contains(request.status))
        .length;
    final pendingRequests = requests
        .where((request) => request.status == RentRequestStatus.pending)
        .length;
    final cancelledRequests = requests
        .where((request) => request.status == RentRequestStatus.canceled)
        .length;
    final declinedRequests = requests
        .where((request) => request.status == RentRequestStatus.declined)
        .length;
    final weatherRiskBookings = requests
        .where((request) => request.weatherFlag)
        .length;
    final totalSpending = completedRequests.fold<double>(
      0,
      (total, request) => total + _requestValue(request),
    );
    final totalCompletedDays = completedRequests.fold<int>(
      0,
      (total, request) => total + _rentalDays(request),
    );

    final categoryAccumulators = <String, _CategoryUsageAccumulator>{};
    for (final request in requests) {
      final equipment = equipmentById[request.itemId];
      final categoryLabel = (equipment?.category?.trim().isNotEmpty ?? false)
          ? equipment!.category!.trim()
          : 'Uncategorized';
      final accumulator = categoryAccumulators.putIfAbsent(
        categoryLabel,
        () => _CategoryUsageAccumulator(categoryLabel: categoryLabel),
      );
      accumulator.requestCount += 1;
      if (request.status == RentRequestStatus.completed) {
        accumulator.completedRentals += 1;
        accumulator.totalSpending += _requestValue(request);
      }
    }

    final categoryUsage =
        categoryAccumulators.values
            .map(
              (item) => RenterAnalyticsCategoryUsageItem(
                categoryLabel: item.categoryLabel,
                requestCount: item.requestCount,
                completedRentals: item.completedRentals,
                totalSpending: item.totalSpending,
              ),
            )
            .toList()
          ..sort((a, b) {
            final requestCompare = b.requestCount.compareTo(a.requestCount);
            if (requestCompare != 0) return requestCompare;
            final completedCompare = b.completedRentals.compareTo(
              a.completedRentals,
            );
            if (completedCompare != 0) return completedCompare;
            return a.categoryLabel.compareTo(b.categoryLabel);
          });

    return RenterAnalyticsReport(
      renterId: renterId,
      generatedAt: generatedAt,
      summary: RenterAnalyticsSummary(
        totalRequests: requests.length,
        completedRentals: completedRequests.length,
        activeRentals: activeRentals,
        pendingRequests: pendingRequests,
        cancelledRequests: cancelledRequests,
        declinedRequests: declinedRequests,
        weatherRiskBookings: weatherRiskBookings,
        totalSpending: totalSpending,
        averageRentalDurationDays: completedRequests.isEmpty
            ? 0
            : totalCompletedDays / completedRequests.length,
      ),
      firstRequestAt: requests.isEmpty
          ? null
          : (requests.first.createdAt ?? requests.first.start),
      lastRequestAt: requests.isEmpty
          ? null
          : (requests.last.createdAt ?? requests.last.start),
      categoryUsage: categoryUsage,
      requests: requests,
    );
  }

  Future<Map<String, Equipment>> _loadEquipmentMap(
    List<RentRequest> requests,
  ) async {
    final itemIds = requests
        .map((request) => request.itemId.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    if (itemIds.isEmpty) return const {};

    final equipmentById = <String, Equipment>{};
    for (var i = 0; i < itemIds.length; i += 30) {
      final chunk = itemIds.sublist(i, math.min(i + 30, itemIds.length));
      final snapshot = await _db
          .collection('equipment')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snapshot.docs) {
        equipmentById[doc.id] = Equipment.fromFirestore(doc);
      }
    }

    return equipmentById;
  }

  int _rentalDays(RentRequest request) =>
      math.max(1, request.end.difference(request.start).inDays);

  double _requestValue(RentRequest request) {
    if (request.agreedPrice != null) return request.agreedPrice!;
    if (request.estimatedMillingFee != null) {
      return request.estimatedMillingFee!;
    }
    return 0;
  }

  static const Set<RentRequestStatus> _activeStatuses = {
    RentRequestStatus.approved,
    RentRequestStatus.readyForPickup,
    RentRequestStatus.pickedUp,
    RentRequestStatus.onTheWay,
    RentRequestStatus.inProgress,
    RentRequestStatus.retrieving,
    RentRequestStatus.returned,
    RentRequestStatus.finished,
  };
}

class _CategoryUsageAccumulator {
  _CategoryUsageAccumulator({required this.categoryLabel});

  final String categoryLabel;
  int requestCount = 0;
  int completedRentals = 0;
  double totalSpending = 0;
}
