import 'package:bukidbayan_app/models/admin_analytics_report.dart';
import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/models/demand_forecast.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/payment_attempt.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/services/analytics/admin_analytics_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Equipment _equipment({
  required String id,
  required String ownerId,
  required String name,
  required String category,
  required EquipmentStatus status,
  required DateTime createdAt,
}) {
  return Equipment(
    id: id,
    name: name,
    description: '$name description',
    category: category,
    condition: 'Good',
    price: 2500,
    rentalUnit: 'Per Day',
    landSizeRequirement: false,
    maxCropHeightRequirement: false,
    ownerId: ownerId,
    status: status,
    createdAt: createdAt,
  );
}

RentRequest _request({
  required String requestId,
  required String itemId,
  required String itemName,
  required String renterId,
  required String ownerId,
  required RentRequestStatus status,
  required DateTime createdAt,
  required DateTime start,
  required DateTime end,
  bool weatherFlag = false,
  double? agreedPrice,
  double? estimatedMillingFee,
}) {
  return RentRequest(
    requestId: requestId,
    itemId: itemId,
    itemName: itemName,
    name: 'Farmer $renterId',
    address: 'Barangay Test',
    start: start,
    end: end,
    status: status,
    renterId: renterId,
    ownerId: ownerId,
    createdAt: createdAt,
    weatherFlag: weatherFlag,
    agreedPrice: agreedPrice,
    estimatedMillingFee: estimatedMillingFee,
    farmAddress: 'Barangay Test',
  );
}

Campaign _campaign({
  required String id,
  required String creatorUid,
  required DateTime createdAt,
  required DateTime endDate,
  required String status,
  int pledgedAmount = 0,
  int backersCount = 0,
}) {
  return Campaign(
    id: id,
    title: 'Campaign $id',
    creatorName: 'Owner',
    creatorUid: creatorUid,
    creatorEmail: '$creatorUid@example.com',
    shortBlurb: 'Short blurb for analytics testing.',
    description: 'Detailed campaign description for analytics testing.',
    isAssetImage: true,
    image: 'assets/images/farmBg.jpg',
    category: 'Irrigation',
    goalAmount: 10000,
    pledgedAmount: pledgedAmount,
    backersCount: backersCount,
    endDate: endDate,
    createdAt: createdAt,
    publishedAt: createdAt,
    rewards: const [],
    status: status,
  );
}

Future<void> _seedUsers(FakeFirebaseFirestore firestore) async {
  final users = {
    'coop-1': {
      'accountType': 'coop',
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    },
    'owner-1': {
      'createdAt': Timestamp.fromDate(DateTime(2026, 4, 1)),
      'barangay': 'Barangay Uno',
      'municipality': 'Tanauan City',
      'province': 'Batangas',
    },
    'owner-2': {'createdAt': Timestamp.fromDate(DateTime(2026, 6, 3))},
    'renter-1': {
      'createdAt': Timestamp.fromDate(DateTime(2026, 6, 5)),
      'barangay': 'Barangay Dos',
      'municipality': 'Los Banos',
      'province': 'Laguna',
    },
    'renter-2': {
      'createdAt': Timestamp.fromDate(DateTime(2026, 5, 15)),
      'strikeCount': 3,
      'blockedUntil': Timestamp.fromDate(DateTime(2026, 7, 5)),
      'farmBarangay': 'Barangay Tres',
      'farmMunicipality': 'Santo Tomas',
      'farmProvince': 'Batangas',
    },
    'renter-3': {'createdAt': Timestamp.fromDate(DateTime(2026, 6, 12))},
  };

  for (final entry in users.entries) {
    await firestore.collection('users').doc(entry.key).set(entry.value);
  }
}

Future<void> _seedEquipment(FakeFirebaseFirestore firestore) async {
  final items = [
    _equipment(
      id: 'eq-1',
      ownerId: 'owner-1',
      name: 'Four-wheel Tractor',
      category: 'Tractors',
      status: EquipmentStatus.available,
      createdAt: DateTime(2026, 4, 2),
    ).copyWith(
      barangay: 'Barangay Uno',
      municipality: 'Tanauan City',
      province: 'Batangas',
    ),
    _equipment(
      id: 'eq-2',
      ownerId: 'owner-1',
      name: 'Power Tiller',
      category: 'Tractors',
      status: EquipmentStatus.underMaintenance,
      createdAt: DateTime(2026, 6, 5),
    ).copyWith(
      barangay: 'Barangay Dos',
      municipality: 'Santo Tomas',
      province: 'Batangas',
    ),
    _equipment(
      id: 'eq-3',
      ownerId: 'owner-2',
      name: 'Harvester',
      category: 'Harvesters',
      status: EquipmentStatus.unavailable,
      createdAt: DateTime(2026, 6, 6),
    ),
  ];

  for (final item in items) {
    await firestore.collection('equipment').doc(item.id).set(item.toMap());
  }
}

Future<void> _seedRequests(FakeFirebaseFirestore firestore) async {
  final requests = [
    _request(
      requestId: 'rr-1',
      itemId: 'eq-1',
      itemName: 'Four-wheel Tractor',
      renterId: 'renter-1',
      ownerId: 'owner-1',
      status: RentRequestStatus.completed,
      createdAt: DateTime(2026, 6, 1),
      start: DateTime(2026, 6, 3),
      end: DateTime(2026, 6, 4),
      agreedPrice: 5000,
    ).copyWith(
      barangay: 'Barangay Uno',
      municipality: 'Tanauan City',
      province: 'Batangas',
      cropType: 'Rice',
      farmingPhase: 'Harvest',
      intendedUse: 'Harvesting',
    ),
    _request(
      requestId: 'rr-2',
      itemId: 'eq-2',
      itemName: 'Power Tiller',
      renterId: 'renter-2',
      ownerId: 'owner-1',
      status: RentRequestStatus.approved,
      createdAt: DateTime(2026, 6, 15),
      start: DateTime(2026, 6, 20),
      end: DateTime(2026, 6, 21),
      weatherFlag: true,
      agreedPrice: 2300,
    ).copyWith(
      farmBarangay: 'Barangay Dos',
      farmMunicipality: 'Santo Tomas',
      farmProvince: 'Batangas',
    ),
    _request(
      requestId: 'rr-3',
      itemId: 'eq-3',
      itemName: 'Harvester',
      renterId: 'renter-3',
      ownerId: 'owner-2',
      status: RentRequestStatus.pending,
      createdAt: DateTime(2026, 6, 18),
      start: DateTime(2026, 6, 25),
      end: DateTime(2026, 6, 26),
      agreedPrice: 1800,
    ),
    _request(
      requestId: 'rr-4',
      itemId: 'eq-3',
      itemName: 'Harvester',
      renterId: 'renter-2',
      ownerId: 'owner-2',
      status: RentRequestStatus.completed,
      createdAt: DateTime(2026, 5, 24),
      start: DateTime(2026, 5, 27),
      end: DateTime(2026, 5, 28),
      estimatedMillingFee: 1800,
    ),
  ];

  for (final request in requests) {
    await firestore.collection('rentRequests').doc(request.requestId).set({
      ...request.toMap(),
      'createdAt': Timestamp.fromDate(request.createdAt!),
      'weatherFlag': request.weatherFlag,
      'weatherFlagDates': <Timestamp>[],
    });
  }
}

Future<void> _seedDeferredAnalyticsData(FakeFirebaseFirestore firestore) async {
  await firestore.collection('app_events').doc('event-1').set({
    'eventType': 'app_open',
    'status': 'success',
    'createdAt': Timestamp.fromDate(DateTime(2026, 6, 20, 7, 55)),
  });
  await firestore.collection('app_events').doc('event-2').set({
    'eventType': 'login',
    'status': 'failure',
    'createdAt': Timestamp.fromDate(DateTime(2026, 6, 18, 12)),
  });
  await firestore.collection('app_events').doc('event-3').set({
    'eventType': 'background_task',
    'status': 'failure',
    'createdAt': Timestamp.fromDate(DateTime(2026, 6, 19, 8)),
  });
  await firestore.collection('app_events').doc('event-4').set({
    'eventType': 'background_task',
    'status': 'success',
    'createdAt': Timestamp.fromDate(DateTime(2026, 5, 10, 8)),
  });

  await firestore.collection('system_health').doc('current').set({
    'status': 'healthy',
    'lastHeartbeatAt': Timestamp.fromDate(DateTime(2026, 6, 20, 8)),
    'lastHeartbeatSource': 'app_startup',
    'lastAppOpenAt': Timestamp.fromDate(DateTime(2026, 6, 20, 7, 55)),
    'lastBackgroundTaskAt': Timestamp.fromDate(DateTime(2026, 6, 20, 8, 5)),
    'lastBackgroundTaskName': 'weather_check',
    'lastBackgroundTaskStatus': 'failure',
  });
  await firestore
      .collection('system_health')
      .doc('current')
      .collection('heartbeats')
      .doc('hb-1')
      .set({
        'status': 'healthy',
        'createdAt': Timestamp.fromDate(DateTime(2026, 6, 20, 8)),
      });
  await firestore
      .collection('system_health')
      .doc('current')
      .collection('heartbeats')
      .doc('hb-2')
      .set({
        'status': 'healthy',
        'createdAt': Timestamp.fromDate(DateTime(2026, 5, 30, 9)),
      });

  await firestore.collection('commercial_rate_benchmarks').doc('b-1').set({
    'categoryLabel': 'Tractor',
    'createdAt': Timestamp.fromDate(DateTime(2026, 6, 1)),
  });
  await firestore.collection('commercial_rate_benchmarks').doc('b-2').set({
    'categoryLabel': 'Harvester',
    'createdAt': Timestamp.fromDate(DateTime(2026, 6, 1)),
  });
  await firestore.collection('commercial_rate_benchmarks').doc('b-3').set({
    'categoryLabel': 'Rice Mill',
    'createdAt': Timestamp.fromDate(DateTime(2026, 6, 1)),
  });

  await firestore
      .collection('rentRequests')
      .doc('rr-1')
      .collection('status_history')
      .doc('sh-1')
      .set({
        'toStatus': 'completed',
        'changedAt': Timestamp.fromDate(DateTime(2026, 6, 4)),
      });
  await firestore
      .collection('rentRequests')
      .doc('rr-1')
      .collection('timeline_events')
      .doc('tl-1')
      .set({
        'eventType': 'request_created',
        'createdAt': Timestamp.fromDate(DateTime(2026, 6, 1)),
      });
  await firestore
      .collection('rentRequests')
      .doc('rr-2')
      .collection('status_history')
      .doc('sh-2')
      .set({
        'toStatus': 'approved',
        'changedAt': Timestamp.fromDate(DateTime(2026, 6, 15)),
      });

  await firestore
      .collection('equipment')
      .doc('eq-2')
      .collection('maintenance_logs')
      .doc('ml-1')
      .set({
        'eventType': 'maintenance_scheduled',
        'createdAt': Timestamp.fromDate(DateTime(2026, 6, 15)),
      });
  await firestore
      .collection('equipment')
      .doc('eq-3')
      .collection('maintenance_logs')
      .doc('ml-2')
      .set({
        'eventType': 'usage_increment',
        'createdAt': Timestamp.fromDate(DateTime(2026, 5, 27)),
      });
  await firestore
      .collection('equipment')
      .doc('eq-3')
      .collection('maintenance_logs')
      .doc('ml-3')
      .set({
        'eventType': 'maintenance_completed',
        'createdAt': Timestamp.fromDate(DateTime(2026, 5, 28)),
      });
}

Future<void> _seedCampaigns(FakeFirebaseFirestore firestore) async {
  final campaigns = [
    _campaign(
      id: 'campaign-live',
      creatorUid: 'owner-1',
      createdAt: DateTime(2026, 6, 10),
      endDate: DateTime(2026, 7, 10),
      status: 'live',
      pledgedAmount: 400,
      backersCount: 1,
    ),
    _campaign(
      id: 'campaign-ended',
      creatorUid: 'owner-2',
      createdAt: DateTime(2026, 5, 1),
      endDate: DateTime(2026, 5, 30),
      status: 'ended_success',
      pledgedAmount: 800,
      backersCount: 1,
    ),
  ];

  for (final campaign in campaigns) {
    await firestore
        .collection('campaigns')
        .doc(campaign.id)
        .set(campaign.toFirestore());
  }

  final pledges = [
    Pledge(
      id: 'pledge-1',
      campaignId: 'campaign-live',
      backerUid: 'renter-1',
      backerEmail: 'r1@example.com',
      amount: 400,
      rewardId: null,
      createdAt: DateTime(2026, 6, 16),
      paidAt: DateTime(2026, 6, 16, 1),
    ),
    Pledge(
      id: 'pledge-2',
      campaignId: 'campaign-live',
      backerEmail: 'supporter@example.com',
      amount: 600,
      rewardId: null,
      createdAt: DateTime(2026, 6, 17),
      proofReferenceNumber: 'REF-600',
      proofSubmittedAt: DateTime(2026, 6, 18, 9),
      countedInTotal: false,
    ),
    Pledge(
      id: 'pledge-4',
      campaignId: 'campaign-live',
      backerUid: 'renter-4',
      backerEmail: 'r4@example.com',
      amount: 250,
      rewardId: null,
      createdAt: DateTime(2026, 6, 18),
      proofReferenceNumber: 'REF-250',
      proofSubmittedAt: DateTime(2026, 6, 18, 10),
      invalidatedAt: DateTime(2026, 6, 19, 8),
      invalidatedByUid: 'coop-1',
      invalidationReason: 'Proof did not match the submitted amount.',
      countedInTotal: false,
    ),
    Pledge(
      id: 'pledge-5',
      campaignId: 'campaign-live',
      backerUid: 'renter-5',
      backerEmail: 'r5@example.com',
      amount: 150,
      rewardId: null,
      createdAt: DateTime(2026, 6, 19),
      canceledAt: DateTime(2026, 6, 19, 11),
      canceledByUid: 'renter-5',
      countedInTotal: false,
    ),
    Pledge(
      id: 'pledge-6',
      campaignId: 'campaign-live',
      backerUid: 'renter-6',
      backerEmail: 'r6@example.com',
      amount: 300,
      rewardId: null,
      createdAt: DateTime(2026, 6, 20),
      countedInTotal: false,
    ),
    Pledge(
      id: 'pledge-3',
      campaignId: 'campaign-ended',
      backerUid: 'renter-2',
      backerEmail: 'r2@example.com',
      amount: 800,
      rewardId: null,
      createdAt: DateTime(2026, 5, 10),
      paidAt: DateTime(2026, 5, 10, 1),
    ),
  ];

  for (final pledge in pledges) {
    await firestore
        .collection('campaigns')
        .doc(pledge.campaignId)
        .collection('pledges')
        .doc(pledge.id)
        .set(pledge.toFirestore());
  }

  final attempts = [
    PaymentAttempt(
      id: 'attempt-1',
      campaignId: 'campaign-live',
      createdByUid: 'renter-1',
      createdByEmail: 'r1@example.com',
      donorName: 'Renter One',
      amount: 400,
      provider: PaymentProvider.gcashManual,
      status: PaymentAttemptStatus.paid,
      createdAt: DateTime(2026, 6, 16),
      updatedAt: DateTime(2026, 6, 16, 1),
      completedAt: DateTime(2026, 6, 16, 1),
    ),
    PaymentAttempt(
      id: 'attempt-2',
      campaignId: 'campaign-live',
      createdByUid: 'renter-3',
      donorName: 'Renter Three',
      amount: 600,
      provider: PaymentProvider.gcashManual,
      status: PaymentAttemptStatus.failed,
      createdAt: DateTime(2026, 6, 17),
      updatedAt: DateTime(2026, 6, 17, 1),
    ),
    PaymentAttempt(
      id: 'attempt-3',
      campaignId: 'campaign-ended',
      createdByUid: 'renter-2',
      createdByEmail: 'r2@example.com',
      donorName: 'Renter Two',
      amount: 800,
      provider: PaymentProvider.gcashManual,
      status: PaymentAttemptStatus.paid,
      createdAt: DateTime(2026, 5, 10),
      updatedAt: DateTime(2026, 5, 10, 1),
      completedAt: DateTime(2026, 5, 10, 1),
    ),
  ];

  for (final attempt in attempts) {
    await firestore
        .collection('campaigns')
        .doc(attempt.campaignId)
        .collection('payment_attempts')
        .doc(attempt.id)
        .set(attempt.toFirestore());
  }
}

void main() {
  group('AdminAnalyticsService.generateReport', () {
    late FakeFirebaseFirestore firestore;
    late AdminAnalyticsService service;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      service = AdminAnalyticsService(firestore: firestore);
      await _seedUsers(firestore);
      await _seedEquipment(firestore);
      await _seedRequests(firestore);
      await _seedCampaigns(firestore);
      await _seedDeferredAnalyticsData(firestore);
    });

    test('computes current-month admin analytics across collections', () async {
      final report = await service.generateReport(
        preset: AdminAnalyticsTimePreset.currentMonth,
        now: DateTime(2026, 6, 20),
      );

      expect(report.platform.totalUsers, 5);
      expect(report.platform.coopAccounts, 1);
      expect(report.platform.newUsersInWindow, 3);
      expect(report.platform.totalEquipment, 3);
      expect(report.platform.newEquipmentInWindow, 2);
      expect(report.platform.equipmentOwners, 2);
      expect(report.platform.availableEquipment, 1);
      expect(report.platform.unavailableEquipment, 1);
      expect(report.platform.underMaintenanceEquipment, 1);

      expect(report.rentals.activeRentals, 1);
      expect(report.rentals.pendingRentals, 1);
      expect(report.rentals.completedRentals, 1);
      expect(report.rentals.weatherRiskBookings, 1);
      expect(report.rentals.uniqueFarmersServed, 1);
      expect(report.rentals.completedRentalValue, 5000);

      expect(report.crowdfunding.liveCampaigns, 1);
      expect(report.crowdfunding.campaignsPublishedInWindow, 1);
      expect(report.crowdfunding.totalPledges, 5);
      expect(report.crowdfunding.totalPledgedAmount, 1700);
      expect(report.crowdfunding.totalReceivedAmount, 400);
      expect(report.crowdfunding.uniqueSupporters, 5);
      expect(report.crowdfunding.pendingProofPledges, 1);
      expect(report.crowdfunding.pendingProofAmount, 300);
      expect(report.crowdfunding.pendingReviewPledges, 1);
      expect(report.crowdfunding.pendingReviewAmount, 600);
      expect(report.crowdfunding.invalidatedPledges, 1);
      expect(report.crowdfunding.invalidatedAmount, 250);
      expect(report.crowdfunding.canceledPledges, 1);
      expect(report.crowdfunding.canceledAmount, 150);

      expect(report.watchlist.blockedRenters, 1);
      expect(report.watchlist.underMaintenanceEquipment, 1);
      expect(report.watchlist.weatherRiskBookings, 1);
      expect(report.watchlist.pendingRentals, 1);
      expect(report.watchlist.contributionProofsAwaitingReview, 1);

      expect(report.impact.totalFarmersServed, 2);
      expect(report.impact.totalEquipmentOwners, 2);
      expect(report.impact.totalCampaignSupporters, 6);
      expect(report.impact.totalCompletedRentals, 2);

      expect(report.systemHealth.currentStatus, 'healthy');
      expect(report.systemHealth.appOpensInWindow, 1);
      expect(report.systemHealth.loginFailuresInWindow, 1);
      expect(report.systemHealth.backgroundTaskFailuresInWindow, 1);
      expect(report.systemHealth.telemetryEventsInWindow, 3);
      expect(report.systemHealth.lastHeartbeatSource, 'app_startup');

      expect(report.dataReadiness.totalMemberProfiles, 5);
      expect(report.dataReadiness.memberProfilesWithGeography, 3);
      expect(report.dataReadiness.equipmentWithGeography, 2);
      expect(report.dataReadiness.requestsWithNormalizedGeography, 2);
      expect(report.dataReadiness.requestsWithForecastInputs, 1);
      expect(report.dataReadiness.requestsWithStatusHistory, 2);
      expect(report.dataReadiness.requestsWithTimelineEvents, 1);
      expect(report.dataReadiness.equipmentWithMaintenanceLogs, 2);
      expect(report.dataReadiness.maintenanceLogEntries, 3);
      expect(report.dataReadiness.benchmarkRows, 3);

      expect(report.forecasting.requestsWithForecastLocation, 2);
      expect(report.forecasting.requestsWithForecastInputsAndLocation, 1);
      expect(report.forecasting.locationsAnalyzed, 2);
      expect(report.forecasting.hotspotCount, 2);
      expect(report.forecasting.highDemandHotspots, 0);
      expect(
        report.forecasting.hotspots.any(
          (item) =>
              item.locationLabel == 'Barangay Uno' &&
              item.equipmentCategory == 'Tractors' &&
              item.demandLevel == DemandForecastLevel.medium,
        ),
        isTrue,
      );
      expect(
        report.forecasting.hotspots.any(
          (item) => item.locationLabel == 'Barangay Dos',
        ),
        isTrue,
      );

      expect(report.topDemandCategories.length, 2);
      expect(report.topDemandCategories.first.categoryLabel, 'Tractors');
      expect(report.topDemandCategories.first.requestCount, 2);
      expect(report.topDemandCategories.first.completedRequestCount, 1);
      expect(report.topDemandCategories.first.uniqueRenters, 2);
      expect(report.topDemandCategories[1].categoryLabel, 'Harvesters');
      expect(report.topDemandCategories[1].requestCount, 1);
    });

    test(
      'returns all-time activity totals when all-time preset is used',
      () async {
        final report = await service.generateReport(
          preset: AdminAnalyticsTimePreset.allTime,
          now: DateTime(2026, 6, 20),
        );

        expect(report.platform.newUsersInWindow, 5);
        expect(report.platform.newEquipmentInWindow, 3);
        expect(report.rentals.completedRentals, 2);
        expect(report.rentals.uniqueFarmersServed, 2);
        expect(report.rentals.completedRentalValue, 6800);
        expect(report.crowdfunding.campaignsPublishedInWindow, 2);
        expect(report.crowdfunding.totalPledges, 6);
        expect(report.crowdfunding.totalPledgedAmount, 2500);
        expect(report.crowdfunding.totalReceivedAmount, 1200);
        expect(report.crowdfunding.uniqueSupporters, 6);
        expect(report.crowdfunding.pendingProofPledges, 1);
        expect(report.crowdfunding.pendingReviewPledges, 1);
        expect(report.crowdfunding.invalidatedPledges, 1);
        expect(report.crowdfunding.canceledPledges, 1);
        expect(report.systemHealth.telemetryEventsInWindow, 4);
        expect(report.systemHealth.heartbeatEventsInWindow, 2);
        expect(report.dataReadiness.requestsWithStatusHistory, 2);
        expect(report.dataReadiness.maintenanceLogEntries, 3);
        expect(report.forecasting.locationsAnalyzed, 2);
        expect(report.forecasting.hotspots, isNotEmpty);
      },
    );
  });
}
