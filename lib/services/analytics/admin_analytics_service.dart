import 'package:bukidbayan_app/models/admin_analytics_report.dart';
import 'package:bukidbayan_app/models/analytics_time_window.dart';
import 'package:bukidbayan_app/models/campaign.dart';
import 'package:bukidbayan_app/models/demand_forecast.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/payment_attempt.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/services/analytics/demand_forecast_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAnalyticsService {
  AdminAnalyticsService({
    FirebaseFirestore? firestore,
    DemandForecastService? demandForecastService,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _demandForecastService =
           demandForecastService ?? DemandForecastService();

  final FirebaseFirestore _db;
  final DemandForecastService _demandForecastService;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _equipment =>
      _db.collection('equipment');
  CollectionReference<Map<String, dynamic>> get _rentRequests =>
      _db.collection('rentRequests');
  CollectionReference<Map<String, dynamic>> get _campaigns =>
      _db.collection('campaigns');
  CollectionReference<Map<String, dynamic>> get _appEvents =>
      _db.collection('app_events');
  CollectionReference<Map<String, dynamic>> get _benchmarks =>
      _db.collection('commercial_rate_benchmarks');
  DocumentReference<Map<String, dynamic>> get _systemHealthCurrent =>
      _db.collection('system_health').doc('current');
  CollectionReference<Map<String, dynamic>> get _systemHeartbeats =>
      _systemHealthCurrent.collection('heartbeats');

  static const Set<RentRequestStatus> _activeRentalStatuses = {
    RentRequestStatus.approved,
    RentRequestStatus.readyForPickup,
    RentRequestStatus.pickedUp,
    RentRequestStatus.onTheWay,
    RentRequestStatus.inProgress,
    RentRequestStatus.retrieving,
    RentRequestStatus.returned,
    RentRequestStatus.finished,
  };

  Future<AdminAnalyticsReport> generateReport({
    AdminAnalyticsTimePreset preset = AdminAnalyticsTimePreset.allTime,
    DateTime? now,
  }) async {
    final generatedAt = now ?? DateTime.now();
    final timeWindow = preset.resolveWindow(generatedAt);
    final appEventFuture = _appEvents.get();
    final systemHealthCurrentFuture = _systemHealthCurrent.get();
    final heartbeatFuture = _systemHeartbeats.get();
    final benchmarkFuture = _benchmarks.get();

    final snapshots = await Future.wait<QuerySnapshot<Map<String, dynamic>>>([
      _users.get(),
      _equipment.get(),
      _rentRequests.get(),
      _campaigns.get(),
    ]);

    final userSnapshot = snapshots[0];
    final equipmentSnapshot = snapshots[1];
    final rentRequestSnapshot = snapshots[2];
    final campaignSnapshot = snapshots[3];
    final appEventSnapshot = await appEventFuture;
    final systemHealthCurrent = await systemHealthCurrentFuture;
    final heartbeatSnapshot = await heartbeatFuture;
    final benchmarkSnapshot = await benchmarkFuture;

    final users = userSnapshot.docs.map((doc) => doc.data()).toList();
    final equipmentItems = equipmentSnapshot.docs
        .map(Equipment.fromFirestore)
        .toList();
    final requests = rentRequestSnapshot.docs.map(RentRequest.fromDoc).toList();
    final campaigns = campaignSnapshot.docs.map(_campaignFromDoc).toList();
    final campaignFinance = await _loadCampaignFinance(campaignSnapshot.docs);

    final memberUsers = users.where((user) => !_isCoopUser(user)).toList();
    final coopUsers = users.where(_isCoopUser).toList();
    final equipmentById = {
      for (final item in equipmentItems)
        if (item.id != null) item.id!: item,
    };
    final requestHistoryCoverage = await _loadRequestHistoryCoverage(
      rentRequestSnapshot.docs,
    );
    final maintenanceLogCoverage = await _loadMaintenanceLogCoverage(
      equipmentSnapshot.docs,
    );
    final appEvents = appEventSnapshot.docs.map((doc) => doc.data()).toList();
    final heartbeats = heartbeatSnapshot.docs.map((doc) => doc.data()).toList();
    final systemHealthData = systemHealthCurrent.data() ?? <String, dynamic>{};
    final lastHeartbeatAt = _readDate(
      systemHealthData['lastHeartbeatAt'] ??
          systemHealthData['lastHeartbeatClientAt'],
    );
    final lastAppOpenAt = _readDate(
      systemHealthData['lastAppOpenAt'] ??
          systemHealthData['lastAppOpenClientAt'],
    );
    final lastBackgroundTaskAt = _readDate(
      systemHealthData['lastBackgroundTaskAt'] ??
          systemHealthData['lastBackgroundTaskClientAt'],
    );

    final completedRequests = requests
        .where((request) => request.status == RentRequestStatus.completed)
        .toList();
    final completedRequestsInWindow = completedRequests
        .where((request) => _isWithinWindow(request.end, timeWindow))
        .toList();
    final demandRequestsInWindow = requests
        .where((request) => !_isDemandExcludedStatus(request.status))
        .where(
          (request) =>
              _isWithinWindow(request.createdAt ?? request.start, timeWindow),
        )
        .toList();
    final pledgesInWindow = campaignFinance.pledges
        .where((pledge) => _isWithinWindow(pledge.createdAt, timeWindow))
        .toList();
    final paidAttemptsInWindow = campaignFinance.attempts
        .where((attempt) => attempt.status == PaymentAttemptStatus.paid)
        .where(
          (attempt) => _isWithinWindow(
            attempt.completedAt ?? attempt.updatedAt,
            timeWindow,
          ),
        )
        .toList();
    final failedAttemptsInWindow = campaignFinance.attempts
        .where((attempt) => attempt.status == PaymentAttemptStatus.failed)
        .where((attempt) => _isWithinWindow(attempt.updatedAt, timeWindow))
        .toList();
    final expiredAttemptsInWindow = campaignFinance.attempts
        .where((attempt) => attempt.status == PaymentAttemptStatus.expired)
        .where(
          (attempt) => _isWithinWindow(
            attempt.expiredAt ?? attempt.updatedAt,
            timeWindow,
          ),
        )
        .toList();

    final activeRentals = requests
        .where((request) => _activeRentalStatuses.contains(request.status))
        .length;
    final pendingRentals = requests
        .where((request) => request.status == RentRequestStatus.pending)
        .length;
    final weatherRiskBookings = requests
        .where((request) => request.weatherFlag)
        .where((request) => _isCurrentlyTrackedRiskStatus(request.status))
        .length;
    final blockedRenters = memberUsers
        .where((user) => _isBlockedUser(user, generatedAt))
        .length;

    final topDemandCategories = _buildTopDemandCategories(
      requests: demandRequestsInWindow,
      equipmentById: equipmentById,
    );
    final forecastHotspots = _buildForecastHotspots(
      requests: demandRequestsInWindow,
      equipmentById: equipmentById,
      now: generatedAt,
    );
    final requestsWithForecastLocation = demandRequestsInWindow
        .where((request) => _requestForecastLocationLabel(request) != null)
        .length;
    final locationGroups = _groupRequestsByForecastLocation(
      demandRequestsInWindow,
    );

    final uniqueFarmersServedInWindow = completedRequestsInWindow
        .map((request) => request.renterId.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .length;
    final uniqueFarmersServedAllTime = completedRequests
        .map((request) => request.renterId.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .length;
    final uniqueCampaignSupportersAllTime = campaignFinance.pledges
        .map(_supporterKey)
        .whereType<String>()
        .toSet()
        .length;
    final uniqueSupportersInWindow = pledgesInWindow
        .map(_supporterKey)
        .whereType<String>()
        .toSet()
        .length;
    final telemetryEventsInWindow = appEvents
        .where((event) => _isWithinWindow(_eventDate(event), timeWindow))
        .length;
    final appOpensInWindow = appEvents
        .where((event) => event['eventType'] == 'app_open')
        .where((event) => _isWithinWindow(_eventDate(event), timeWindow))
        .length;
    final loginFailuresInWindow = appEvents
        .where((event) => event['eventType'] == 'login')
        .where((event) => (event['status'] as String?) == 'failure')
        .where((event) => _isWithinWindow(_eventDate(event), timeWindow))
        .length;
    final backgroundTaskFailuresInWindow = appEvents
        .where((event) => event['eventType'] == 'background_task')
        .where((event) => (event['status'] as String?) == 'failure')
        .where((event) => _isWithinWindow(_eventDate(event), timeWindow))
        .length;
    final heartbeatEventsMatchingWindow = heartbeats
        .where((event) => _isWithinWindow(_heartbeatDate(event), timeWindow))
        .length;
    final heartbeatEventsInWindow = timeWindow == null
        ? heartbeats.length
        : (heartbeatEventsMatchingWindow > 0
              ? heartbeatEventsMatchingWindow
              : (lastHeartbeatAt != null &&
                        _isWithinWindow(lastHeartbeatAt, timeWindow)
                    ? 1
                    : 0));

    return AdminAnalyticsReport(
      generatedAt: generatedAt,
      preset: preset,
      timeWindow: timeWindow,
      platform: AdminAnalyticsPlatformSnapshot(
        totalUsers: memberUsers.length,
        coopAccounts: coopUsers.length,
        newUsersInWindow: memberUsers
            .where(
              (user) =>
                  _isWithinWindow(_readDate(user['createdAt']), timeWindow),
            )
            .length,
        totalEquipment: equipmentItems.length,
        newEquipmentInWindow: equipmentItems
            .where((item) => _isWithinWindow(item.createdAt, timeWindow))
            .length,
        equipmentOwners: equipmentItems
            .map((item) => item.ownerId.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .length,
        availableEquipment: equipmentItems
            .where((item) => item.status == EquipmentStatus.available)
            .length,
        unavailableEquipment: equipmentItems
            .where((item) => item.status == EquipmentStatus.unavailable)
            .length,
        underMaintenanceEquipment: equipmentItems
            .where((item) => item.status == EquipmentStatus.underMaintenance)
            .length,
      ),
      rentals: AdminAnalyticsRentalSnapshot(
        activeRentals: activeRentals,
        pendingRentals: pendingRentals,
        completedRentals: completedRequestsInWindow.length,
        weatherRiskBookings: weatherRiskBookings,
        uniqueFarmersServed: uniqueFarmersServedInWindow,
        completedRentalValue: completedRequestsInWindow.fold<double>(
          0,
          (total, request) => total + _requestValue(request),
        ),
      ),
      crowdfunding: AdminAnalyticsCrowdfundingSnapshot(
        liveCampaigns: campaigns
            .where((campaign) => _isLiveCampaign(campaign, generatedAt))
            .length,
        campaignsCreatedInWindow: campaigns
            .where(
              (campaign) => _isWithinWindow(
                campaign.publishedAt ?? campaign.createdAt,
                timeWindow,
              ),
            )
            .length,
        totalPledges: pledgesInWindow.length,
        totalPledgedAmount: pledgesInWindow.fold<int>(
          0,
          (total, pledge) => total + pledge.amount,
        ),
        totalPaidAmount: paidAttemptsInWindow.fold<int>(
          0,
          (total, attempt) => total + attempt.amount,
        ),
        uniqueSupporters: uniqueSupportersInWindow,
        paidAttempts: paidAttemptsInWindow.length,
        failedAttempts: failedAttemptsInWindow.length,
        expiredAttempts: expiredAttemptsInWindow.length,
      ),
      watchlist: AdminAnalyticsWatchlistSnapshot(
        blockedRenters: blockedRenters,
        weatherRiskBookings: weatherRiskBookings,
        underMaintenanceEquipment: equipmentItems
            .where((item) => item.status == EquipmentStatus.underMaintenance)
            .length,
        pendingRentals: pendingRentals,
        failedPaymentAttempts: failedAttemptsInWindow.length,
      ),
      impact: AdminAnalyticsImpactSnapshot(
        totalFarmersServed: uniqueFarmersServedAllTime,
        totalEquipmentOwners: equipmentItems
            .map((item) => item.ownerId.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .length,
        totalCampaignSupporters: uniqueCampaignSupportersAllTime,
        totalCompletedRentals: completedRequests.length,
      ),
      systemHealth: AdminAnalyticsSystemHealthSnapshot(
        currentStatus: (systemHealthData['status'] as String?) ?? 'unknown',
        lastHeartbeatAt: lastHeartbeatAt,
        lastHeartbeatSource: systemHealthData['lastHeartbeatSource'] as String?,
        lastAppOpenAt: lastAppOpenAt,
        lastBackgroundTaskAt: lastBackgroundTaskAt,
        lastBackgroundTaskName:
            systemHealthData['lastBackgroundTaskName'] as String?,
        lastBackgroundTaskStatus:
            systemHealthData['lastBackgroundTaskStatus'] as String?,
        telemetryEventsInWindow: telemetryEventsInWindow,
        appOpensInWindow: appOpensInWindow,
        loginFailuresInWindow: loginFailuresInWindow,
        backgroundTaskFailuresInWindow: backgroundTaskFailuresInWindow,
        heartbeatEventsInWindow: heartbeatEventsInWindow,
      ),
      dataReadiness: AdminAnalyticsDataReadinessSnapshot(
        memberProfilesWithGeography: memberUsers
            .where((user) => _hasNormalizedUserGeography(user))
            .length,
        totalMemberProfiles: memberUsers.length,
        equipmentWithGeography: equipmentItems
            .where(_hasNormalizedEquipmentGeography)
            .length,
        totalEquipment: equipmentItems.length,
        requestsWithNormalizedGeography: requests
            .where(_hasNormalizedRequestGeography)
            .length,
        requestsWithForecastInputs: requests.where(_hasForecastInputs).length,
        requestsWithStatusHistory:
            requestHistoryCoverage.requestsWithStatusHistory,
        requestsWithTimelineEvents:
            requestHistoryCoverage.requestsWithTimelineEvents,
        totalRequests: requests.length,
        equipmentWithMaintenanceLogs:
            maintenanceLogCoverage.equipmentWithMaintenanceLogs,
        maintenanceLogEntries: maintenanceLogCoverage.maintenanceLogEntries,
        benchmarkRows: benchmarkSnapshot.docs.length,
      ),
      forecasting: AdminAnalyticsForecastSnapshot(
        requestsWithForecastLocation: requestsWithForecastLocation,
        requestsWithForecastInputsAndLocation: demandRequestsInWindow
            .where(_hasForecastInputs)
            .where((request) => _requestForecastLocationLabel(request) != null)
            .length,
        locationsAnalyzed: locationGroups.length,
        hotspotCount: forecastHotspots.length,
        highDemandHotspots: forecastHotspots
            .where((item) => item.demandLevel == DemandForecastLevel.high)
            .length,
        highConfidenceHotspots: forecastHotspots
            .where((item) => item.confidence == DemandForecastConfidence.high)
            .length,
        hotspots: forecastHotspots,
      ),
      topDemandCategories: topDemandCategories,
    );
  }

  Campaign _campaignFromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Campaign.fromJson({...doc.data()!, 'id': doc.id});

  Pledge _pledgeFromDoc(
    String campaignId,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) => Pledge.fromJson({...doc.data(), 'id': doc.id, 'campaignId': campaignId});

  PaymentAttempt _attemptFromDoc(
    String campaignId,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) => PaymentAttempt.fromJson({
    ...doc.data(),
    'id': doc.id,
    'campaignId': campaignId,
  });

  Future<_CampaignFinanceLoadResult> _loadCampaignFinance(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> campaignDocs,
  ) async {
    if (campaignDocs.isEmpty) {
      return const _CampaignFinanceLoadResult(pledges: [], attempts: []);
    }

    final pledgeSnapshots = await Future.wait(
      campaignDocs.map((doc) => doc.reference.collection('pledges').get()),
    );
    final attemptSnapshots = await Future.wait(
      campaignDocs.map(
        (doc) => doc.reference.collection('payment_attempts').get(),
      ),
    );

    final pledges = <Pledge>[];
    for (var i = 0; i < campaignDocs.length; i++) {
      final campaignId = campaignDocs[i].id;
      for (final doc in pledgeSnapshots[i].docs) {
        pledges.add(_pledgeFromDoc(campaignId, doc));
      }
    }

    final attempts = <PaymentAttempt>[];
    for (var i = 0; i < campaignDocs.length; i++) {
      final campaignId = campaignDocs[i].id;
      for (final doc in attemptSnapshots[i].docs) {
        attempts.add(_attemptFromDoc(campaignId, doc));
      }
    }

    return _CampaignFinanceLoadResult(pledges: pledges, attempts: attempts);
  }

  List<AdminAnalyticsCategoryDemandItem> _buildTopDemandCategories({
    required List<RentRequest> requests,
    required Map<String, Equipment> equipmentById,
  }) {
    final accumulators = <String, _CategoryDemandAccumulator>{};

    for (final request in requests) {
      final equipment = equipmentById[request.itemId];
      final categoryLabel = (equipment?.category?.trim().isNotEmpty ?? false)
          ? equipment!.category!.trim()
          : 'Uncategorized';
      final accumulator = accumulators.putIfAbsent(
        categoryLabel,
        () => _CategoryDemandAccumulator(categoryLabel: categoryLabel),
      );
      accumulator.requestCount += 1;
      if (request.status == RentRequestStatus.completed) {
        accumulator.completedRequestCount += 1;
      }
      final renterId = request.renterId.trim();
      if (renterId.isNotEmpty) {
        accumulator.uniqueRenterIds.add(renterId);
      }
    }

    final items = accumulators.values
        .map(
          (item) => AdminAnalyticsCategoryDemandItem(
            categoryLabel: item.categoryLabel,
            requestCount: item.requestCount,
            completedRequestCount: item.completedRequestCount,
            uniqueRenters: item.uniqueRenterIds.length,
          ),
        )
        .toList();

    items.sort((a, b) {
      final requestCompare = b.requestCount.compareTo(a.requestCount);
      if (requestCompare != 0) return requestCompare;
      final completedCompare = b.completedRequestCount.compareTo(
        a.completedRequestCount,
      );
      if (completedCompare != 0) return completedCompare;
      return a.categoryLabel.compareTo(b.categoryLabel);
    });

    return items.take(5).toList();
  }

  List<AdminAnalyticsForecastLocationItem> _buildForecastHotspots({
    required List<RentRequest> requests,
    required Map<String, Equipment> equipmentById,
    required DateTime now,
  }) {
    final grouped = _groupRequestsByForecastLocation(requests);
    final equipmentCategoryByItemId = {
      for (final entry in equipmentById.entries)
        if (_hasNonEmptyString(entry.value.category))
          entry.key: entry.value.category!.trim(),
    };
    final hotspots = <AdminAnalyticsForecastLocationItem>[];

    for (final entry in grouped.entries) {
      final snapshot = _demandForecastService.buildWeeklyForecast(
        requests: entry.value,
        equipmentCategoryByItemId: equipmentCategoryByItemId,
        now: now,
      );
      if (!snapshot.hasInsights) continue;

      final topInsight = snapshot.insights.first;
      hotspots.add(
        AdminAnalyticsForecastLocationItem(
          locationLabel: entry.key,
          equipmentCategory: topInsight.equipmentCategory,
          demandLevel: topInsight.level,
          confidence: snapshot.confidence,
          matchedRequests: topInsight.matchedRequests,
          recentRequests: topInsight.recentRequests,
          summary: snapshot.summary,
        ),
      );
    }

    hotspots.sort((a, b) {
      final demandCompare = _forecastLevelRank(
        b.demandLevel,
      ).compareTo(_forecastLevelRank(a.demandLevel));
      if (demandCompare != 0) return demandCompare;
      final confidenceCompare = _forecastConfidenceRank(
        b.confidence,
      ).compareTo(_forecastConfidenceRank(a.confidence));
      if (confidenceCompare != 0) return confidenceCompare;
      final requestCompare = b.matchedRequests.compareTo(a.matchedRequests);
      if (requestCompare != 0) return requestCompare;
      return a.locationLabel.compareTo(b.locationLabel);
    });

    return hotspots.take(5).toList(growable: false);
  }

  Map<String, List<RentRequest>> _groupRequestsByForecastLocation(
    Iterable<RentRequest> requests,
  ) {
    final groups = <String, List<RentRequest>>{};
    for (final request in requests) {
      final location = _requestForecastLocationLabel(request);
      if (location == null) continue;
      groups.putIfAbsent(location, () => <RentRequest>[]).add(request);
    }
    return groups;
  }

  String? _requestForecastLocationLabel(RentRequest request) {
    return _firstNonEmptyString([
      request.farmBarangay,
      request.barangay,
      request.farmMunicipality,
      request.municipality,
      request.farmProvince,
      request.province,
      request.farmRegion,
      request.region,
    ]);
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

  int _forecastConfidenceRank(DemandForecastConfidence confidence) {
    switch (confidence) {
      case DemandForecastConfidence.high:
        return 3;
      case DemandForecastConfidence.medium:
        return 2;
      case DemandForecastConfidence.low:
        return 1;
    }
  }

  bool _isCurrentlyTrackedRiskStatus(RentRequestStatus status) =>
      status != RentRequestStatus.completed &&
      status != RentRequestStatus.declined &&
      status != RentRequestStatus.canceled;

  bool _isDemandExcludedStatus(RentRequestStatus status) =>
      status == RentRequestStatus.declined ||
      status == RentRequestStatus.canceled;

  bool _isLiveCampaign(Campaign campaign, DateTime now) =>
      campaign.status == 'live' && !campaign.endDate.isBefore(now);

  bool _isCoopUser(Map<String, dynamic> user) =>
      (user['accountType'] as String?)?.toLowerCase() == 'coop';

  bool _isBlockedUser(Map<String, dynamic> user, DateTime now) {
    final blockedUntil = _readDate(user['blockedUntil']);
    return blockedUntil != null && blockedUntil.isAfter(now);
  }

  bool _isWithinWindow(DateTime? value, AnalyticsTimeWindow? window) {
    if (window == null) return true;
    if (value == null) return false;
    return !value.isBefore(window.startOfDay) &&
        value.isBefore(window.endExclusive);
  }

  DateTime? _readDate(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    try {
      final dynamic dynamicValue = value;
      final converted = dynamicValue.toDate();
      if (converted is DateTime) return converted;
    } catch (_) {
      // Ignore non timestamp-like values.
    }
    return null;
  }

  String? _supporterKey(Pledge pledge) {
    final backerUid = pledge.backerUid?.trim();
    if (backerUid != null && backerUid.isNotEmpty) return 'uid:$backerUid';
    final email = pledge.backerEmail?.trim().toLowerCase();
    if (email != null && email.isNotEmpty) return 'email:$email';
    return null;
  }

  double _requestValue(RentRequest request) {
    if (request.agreedPrice != null) return request.agreedPrice!;
    if (request.estimatedMillingFee != null) {
      return request.estimatedMillingFee!;
    }
    return 0;
  }

  DateTime? _eventDate(Map<String, dynamic> event) =>
      _readDate(event['createdAt'] ?? event['capturedAt']);

  DateTime? _heartbeatDate(Map<String, dynamic> heartbeat) =>
      _readDate(heartbeat['createdAt'] ?? heartbeat['capturedAt']);

  bool _hasNormalizedUserGeography(Map<String, dynamic> user) {
    return _hasNonEmptyString(user['barangay']) ||
        _hasNonEmptyString(user['municipality']) ||
        _hasNonEmptyString(user['province']) ||
        _hasNonEmptyString(user['region']) ||
        _hasNonEmptyString(user['farmBarangay']) ||
        _hasNonEmptyString(user['farmMunicipality']) ||
        _hasNonEmptyString(user['farmProvince']) ||
        _hasNonEmptyString(user['farmRegion']);
  }

  bool _hasNormalizedEquipmentGeography(Equipment item) {
    return _hasNonEmptyString(item.barangay) ||
        _hasNonEmptyString(item.municipality) ||
        _hasNonEmptyString(item.province) ||
        _hasNonEmptyString(item.region);
  }

  bool _hasNormalizedRequestGeography(RentRequest request) {
    return _hasNonEmptyString(request.barangay) ||
        _hasNonEmptyString(request.municipality) ||
        _hasNonEmptyString(request.province) ||
        _hasNonEmptyString(request.region) ||
        _hasNonEmptyString(request.farmBarangay) ||
        _hasNonEmptyString(request.farmMunicipality) ||
        _hasNonEmptyString(request.farmProvince) ||
        _hasNonEmptyString(request.farmRegion);
  }

  bool _hasForecastInputs(RentRequest request) {
    return _hasNonEmptyString(request.cropType) ||
        _hasNonEmptyString(request.farmingPhase) ||
        _hasNonEmptyString(request.intendedUse);
  }

  bool _hasNonEmptyString(Object? value) =>
      value is String && value.trim().isNotEmpty;

  String? _firstNonEmptyString(Iterable<String?> values) {
    for (final value in values) {
      if (_hasNonEmptyString(value)) return value!.trim();
    }
    return null;
  }

  Future<_RequestHistoryCoverageResult> _loadRequestHistoryCoverage(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> requestDocs,
  ) async {
    if (requestDocs.isEmpty) {
      return const _RequestHistoryCoverageResult(
        requestsWithStatusHistory: 0,
        requestsWithTimelineEvents: 0,
      );
    }

    final statusHistorySnapshots = await Future.wait(
      requestDocs.map(
        (doc) => doc.reference.collection('status_history').get(),
      ),
    );
    final timelineSnapshots = await Future.wait(
      requestDocs.map(
        (doc) => doc.reference.collection('timeline_events').get(),
      ),
    );

    final requestsWithStatusHistory = statusHistorySnapshots
        .where((snapshot) => snapshot.docs.isNotEmpty)
        .length;
    final requestsWithTimelineEvents = timelineSnapshots
        .where((snapshot) => snapshot.docs.isNotEmpty)
        .length;

    return _RequestHistoryCoverageResult(
      requestsWithStatusHistory: requestsWithStatusHistory,
      requestsWithTimelineEvents: requestsWithTimelineEvents,
    );
  }

  Future<_MaintenanceLogCoverageResult> _loadMaintenanceLogCoverage(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> equipmentDocs,
  ) async {
    if (equipmentDocs.isEmpty) {
      return const _MaintenanceLogCoverageResult(
        equipmentWithMaintenanceLogs: 0,
        maintenanceLogEntries: 0,
      );
    }

    final maintenanceSnapshots = await Future.wait(
      equipmentDocs.map(
        (doc) => doc.reference.collection('maintenance_logs').get(),
      ),
    );

    final equipmentWithMaintenanceLogs = maintenanceSnapshots
        .where((snapshot) => snapshot.docs.isNotEmpty)
        .length;
    final maintenanceLogEntries = maintenanceSnapshots.fold<int>(
      0,
      (total, snapshot) => total + snapshot.docs.length,
    );

    return _MaintenanceLogCoverageResult(
      equipmentWithMaintenanceLogs: equipmentWithMaintenanceLogs,
      maintenanceLogEntries: maintenanceLogEntries,
    );
  }
}

class _CampaignFinanceLoadResult {
  final List<Pledge> pledges;
  final List<PaymentAttempt> attempts;

  const _CampaignFinanceLoadResult({
    required this.pledges,
    required this.attempts,
  });
}

class _CategoryDemandAccumulator {
  _CategoryDemandAccumulator({required this.categoryLabel});

  final String categoryLabel;
  int requestCount = 0;
  int completedRequestCount = 0;
  final Set<String> uniqueRenterIds = <String>{};
}

class _RequestHistoryCoverageResult {
  final int requestsWithStatusHistory;
  final int requestsWithTimelineEvents;

  const _RequestHistoryCoverageResult({
    required this.requestsWithStatusHistory,
    required this.requestsWithTimelineEvents,
  });
}

class _MaintenanceLogCoverageResult {
  final int equipmentWithMaintenanceLogs;
  final int maintenanceLogEntries;

  const _MaintenanceLogCoverageResult({
    required this.equipmentWithMaintenanceLogs,
    required this.maintenanceLogEntries,
  });
}
