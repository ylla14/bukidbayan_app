import 'dart:async';

import 'package:bukidbayan_app/models/crop_preference.dart';
import 'package:bukidbayan_app/models/dashboard_calendar.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/services/crop_calendar_service.dart';
import 'package:bukidbayan_app/services/rent_request_service.dart';
import 'package:bukidbayan_app/services/weather_service.dart';

abstract class DashboardCalendarController {
  Stream<DashboardCalendarContext> watchCalendar({
    required String userId,
    String region,
  });

  DashboardCalendarMonthData buildMonthData({
    required DateTime month,
    required DashboardCalendarContext context,
    DateTime? now,
  });
}

class DashboardCalendarService implements DashboardCalendarController {
  RentRequestService? _rentRequestService;
  WeatherService? _weatherService;
  CropCalendarService? _cropCalendarService;
  final DateTime Function() _now;

  DashboardCalendarService({
    RentRequestService? rentRequestService,
    WeatherService? weatherService,
    CropCalendarService? cropCalendarService,
    DateTime Function()? now,
  }) : _rentRequestService = rentRequestService,
       _weatherService = weatherService,
       _cropCalendarService = cropCalendarService,
       _now = now ?? DateTime.now;

  RentRequestService get _requestService =>
      _rentRequestService ??= RentRequestService();

  WeatherService get _resolvedWeatherService =>
      _weatherService ??= WeatherService();

  CropCalendarService get _resolvedCropService =>
      _cropCalendarService ??= CropCalendarService();

  @override
  Stream<DashboardCalendarContext> watchCalendar({
    required String userId,
    String region = 'philippines',
  }) {
    final controller = StreamController<DashboardCalendarContext>();

    List<RentRequest> renterRequests = const [];
    List<RentRequest> ownerRequests = const [];
    List<WeatherDay> forecast = const [];
    List<String> seasonalCrops = const [];
    Map<String, List<String>> cropsBySeason = const {};
    Map<int, List<String>> cropsByMonth = const {};
    final season = _resolvedCropService.detectSeason(_now().month);

    var hasRenter = false;
    var hasOwner = false;
    var closed = false;

    Future<void> emit() async {
      if (closed || !hasRenter || !hasOwner) return;

      final mergedRequests = _mergeRequests(renterRequests, ownerRequests);
      controller.add(
        DashboardCalendarContext(
          userId: userId,
          requests: mergedRequests,
          forecast: forecast,
          season: season,
          seasonalCrops: seasonalCrops,
          cropsBySeason: cropsBySeason,
          cropsByMonth: cropsByMonth,
        ),
      );
    }

    Future<void> loadStaticData() async {
      try {
        forecast = await _resolvedWeatherService.getOrFetchForecast(
          requestLocationPermission: false,
        );
      } catch (_) {
        forecast = const [];
      }

      try {
        final crops = await _resolvedCropService.getRegionalCrops(
          region: region,
        );
        cropsBySeason = _buildCropsBySeason(crops);
        cropsByMonth = _buildCropsByMonth(crops);
        seasonalCrops =
            cropsByMonth[_now().month] ?? cropsBySeason[season] ?? const [];
      } catch (_) {
        seasonalCrops = const [];
        cropsBySeason = const {};
        cropsByMonth = const {};
      }
      await emit();
    }

    final renterSub = _requestService.getRequestsByRenter(userId).listen((
      data,
    ) {
      renterRequests = data;
      hasRenter = true;
      unawaited(emit());
    }, onError: controller.addError);

    final ownerSub = _requestService.getRequestsByOwner(userId).listen((data) {
      ownerRequests = data;
      hasOwner = true;
      unawaited(emit());
    }, onError: controller.addError);

    unawaited(loadStaticData());

    controller.onCancel = () async {
      closed = true;
      await renterSub.cancel();
      await ownerSub.cancel();
    };

    return controller.stream;
  }

  @override
  DashboardCalendarMonthData buildMonthData({
    required DateTime month,
    required DashboardCalendarContext context,
    DateTime? now,
  }) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 0);
    final today = _dayKey(now ?? _now());
    final monthSeason = _seasonForMonth(monthStart.month);
    final monthSeasonalCrops = _seasonalCropsForMonth(
      month: monthStart.month,
      fallbackSeason: monthSeason,
      context: context,
    );

    final daysByDate = <DateTime, DashboardCalendarDayData>{
      for (
        DateTime day = monthStart;
        !day.isAfter(monthEnd);
        day = day.add(const Duration(days: 1))
      )
        // Season context is day-based, not "today"-based.
        // This keeps months like July correctly marked as Wet Season.
        day: DashboardCalendarDayData(
          date: day,
          events: [
            DashboardCalendarEvent(
              type: DashboardCalendarEventType.season,
              title: _seasonForMonth(day.month),
              subtitle: _seasonSubtitle(
                season: _seasonForMonth(day.month),
                seasonalCrops: _seasonalCropsForMonth(
                  month: day.month,
                  fallbackSeason: _seasonForMonth(day.month),
                  context: context,
                ),
              ),
            ),
          ],
        ),
    };

    final badWeatherDays = <DateTime>{};
    for (final weather in context.forecast) {
      final weatherDay = _dayKey(weather.date);
      if (weather.isBadWeather) {
        badWeatherDays.add(weatherDay);
      }
      if (!_isInMonth(weatherDay, monthStart)) continue;

      if (weather.isBadWeather) {
        _addEvent(
          daysByDate: daysByDate,
          date: weatherDay,
          event: DashboardCalendarEvent(
            type: DashboardCalendarEventType.weatherRisk,
            title: 'Weather Risk',
            subtitle:
                '${weather.description} - ${weather.precipitationProbabilityMax.round()}% rain',
          ),
        );
      }
    }

    final suggestionKeys = <String>{};

    for (final request in context.requests) {
      final role = _resolveRole(request, context.userId);
      final start = _dayKey(request.start);
      final end = _dayKey(request.end);
      final weatherFlagDays = request.weatherFlagDates.map(_dayKey).toSet();
      final statusLabel = _statusLabel(request.status);

      for (final day in _daysInRange(start, end)) {
        if (!_isInMonth(day, monthStart)) continue;
        final daySeason = _seasonForMonth(day.month);
        final daySeasonalCrops = _seasonalCropsForMonth(
          month: day.month,
          fallbackSeason: daySeason,
          context: context,
        );

        _addEvent(
          daysByDate: daysByDate,
          date: day,
          event: DashboardCalendarEvent(
            type: DashboardCalendarEventType.booking,
            title: request.itemName,
            subtitle: '$statusLabel - ${_roleLabel(role)}',
            requestId: request.requestId,
          ),
        );

        final hasWeatherRisk =
            badWeatherDays.contains(day) || weatherFlagDays.contains(day);

        if (hasWeatherRisk) {
          _addEvent(
            daysByDate: daysByDate,
            date: day,
            event: DashboardCalendarEvent(
              type: DashboardCalendarEventType.weatherRisk,
              title: 'Booking weather overlap',
              subtitle: '${request.itemName} may be affected',
              requestId: request.requestId,
            ),
          );
        }

        final daySuggestions = _buildSuggestionsForDay(
          day: day,
          today: today,
          role: role,
          request: request,
          hasWeatherRisk: hasWeatherRisk,
          season: daySeason,
          seasonalCrops: daySeasonalCrops,
        );

        for (final suggestion in daySuggestions) {
          final dedupeKey =
              '${day.toIso8601String()}-${request.requestId}-${suggestion.type.name}';
          if (!suggestionKeys.add(dedupeKey)) continue;
          _addSuggestion(
            daysByDate: daysByDate,
            date: day,
            suggestion: suggestion,
          );
        }
      }

      if (today.isAfter(end) &&
          request.status == RentRequestStatus.inProgress &&
          _isInMonth(today, monthStart)) {
        final todaySeason = _seasonForMonth(today.month);
        final todaySeasonalCrops = _seasonalCropsForMonth(
          month: today.month,
          fallbackSeason: todaySeason,
          context: context,
        );
        final overdueSuggestions = _buildSuggestionsForDay(
          day: today,
          today: today,
          role: role,
          request: request,
          hasWeatherRisk: false,
          season: todaySeason,
          seasonalCrops: todaySeasonalCrops,
        );

        for (final suggestion in overdueSuggestions) {
          final dedupeKey =
              '${today.toIso8601String()}-${request.requestId}-${suggestion.type.name}';
          if (!suggestionKeys.add(dedupeKey)) continue;
          _addSuggestion(
            daysByDate: daysByDate,
            date: today,
            suggestion: suggestion,
          );
        }
      }
    }

    if (daysByDate.containsKey(today)) {
      final todaySeason = _seasonForMonth(today.month);
      final todaySeasonalCrops = _seasonalCropsForMonth(
        month: today.month,
        fallbackSeason: todaySeason,
        context: context,
      );
      final seasonSuggestion = DashboardCalendarSuggestion(
        type: DashboardCalendarSuggestionType.seasonalPlanning,
        title: 'Seasonal planning',
        description: todaySeasonalCrops.isEmpty
            ? 'Review your requests for ${todaySeason.toLowerCase()}.'
            : 'Plan equipment for ${todaySeason.toLowerCase()} crops: '
                  '${todaySeasonalCrops.take(3).join(', ')}.',
        priority: DashboardCalendarSuggestionPriority.low,
        actionTarget: DashboardCalendarActionTarget(
          kind: DashboardCalendarActionKind.openEquipmentCatalog,
          label: 'Browse Equipment',
          categoryFilter: _primaryToolCategoryForSeasonalCrops(
            season: todaySeason,
            seasonalCrops: todaySeasonalCrops,
          ),
          searchQuery: todaySeasonalCrops.isNotEmpty
              ? todaySeasonalCrops.first
              : null,
          recommendedOnly: true,
        ),
      );
      _addSuggestion(
        daysByDate: daysByDate,
        date: today,
        suggestion: seasonSuggestion,
      );
    }

    return DashboardCalendarMonthData(
      month: monthStart,
      daysByDate: daysByDate,
      season: monthSeason,
      seasonalCrops: monthSeasonalCrops,
    );
  }

  List<DashboardCalendarSuggestion> _buildSuggestionsForDay({
    required DateTime day,
    required DateTime today,
    required _RequestRole role,
    required RentRequest request,
    required bool hasWeatherRisk,
    required String season,
    required List<String> seasonalCrops,
  }) {
    final suggestions = <DashboardCalendarSuggestion>[];
    final requestStart = _dayKey(request.start);
    final requestEnd = _dayKey(request.end);

    const weatherSensitive = {
      RentRequestStatus.pending,
      RentRequestStatus.approved,
      RentRequestStatus.readyForPickup,
      RentRequestStatus.onTheWay,
    };

    if (hasWeatherRisk && weatherSensitive.contains(request.status)) {
      suggestions.add(
        DashboardCalendarSuggestion(
          type: DashboardCalendarSuggestionType.weatherRisk,
          title: 'Weather risk on booking day',
          description:
              'Check "${request.itemName}" and coordinate schedule changes if needed.',
          priority: DashboardCalendarSuggestionPriority.high,
          actionTarget: DashboardCalendarActionTarget(
            kind: DashboardCalendarActionKind.openRequest,
            label: 'Open Request',
            requestId: request.requestId,
          ),
          secondaryActionTarget: DashboardCalendarActionTarget(
            kind: DashboardCalendarActionKind.openEquipmentItem,
            label: 'View Tool',
            equipmentId: request.itemId,
          ),
        ),
      );
    }

    if ((role == _RequestRole.owner || role == _RequestRole.both) &&
        request.status == RentRequestStatus.pending &&
        day == requestStart) {
      suggestions.add(
        DashboardCalendarSuggestion(
          type: DashboardCalendarSuggestionType.incomingRequestReview,
          title: 'Incoming request needs review',
          description: 'Review and approve/decline this rental request.',
          priority: DashboardCalendarSuggestionPriority.medium,
          actionTarget: const DashboardCalendarActionTarget(
            kind: DashboardCalendarActionKind.openIncomingRequests,
            label: 'Open Incoming Requests',
          ),
          secondaryActionTarget: DashboardCalendarActionTarget(
            kind: DashboardCalendarActionKind.openEquipmentItem,
            label: 'View Tool',
            equipmentId: request.itemId,
          ),
        ),
      );
    }

    if ((role == _RequestRole.renter || role == _RequestRole.both) &&
        (request.status == RentRequestStatus.approved ||
            request.status == RentRequestStatus.readyForPickup ||
            request.status == RentRequestStatus.onTheWay) &&
        day == requestStart) {
      suggestions.add(
        DashboardCalendarSuggestion(
          type: DashboardCalendarSuggestionType.bookingPreparation,
          title: 'Prepare for booking start',
          description:
              'Confirm logistics for "${request.itemName}" before start.',
          priority: DashboardCalendarSuggestionPriority.medium,
          actionTarget: DashboardCalendarActionTarget(
            kind: DashboardCalendarActionKind.openRequest,
            label: 'Open Request',
            requestId: request.requestId,
          ),
          secondaryActionTarget: DashboardCalendarActionTarget(
            kind: DashboardCalendarActionKind.openEquipmentItem,
            label: 'View Tool',
            equipmentId: request.itemId,
          ),
        ),
      );
    }

    if (day == today &&
        request.status == RentRequestStatus.inProgress &&
        today.isAfter(requestEnd)) {
      if (role == _RequestRole.renter || role == _RequestRole.both) {
        suggestions.add(
          DashboardCalendarSuggestion(
            type: DashboardCalendarSuggestionType.overdueReturn,
            title: 'Return is overdue',
            description:
                'Mark "${request.itemName}" as returned as soon as possible.',
            priority: DashboardCalendarSuggestionPriority.high,
            actionTarget: DashboardCalendarActionTarget(
              kind: DashboardCalendarActionKind.openRequest,
              label: 'Open Request',
              requestId: request.requestId,
            ),
            secondaryActionTarget: DashboardCalendarActionTarget(
              kind: DashboardCalendarActionKind.openEquipmentItem,
              label: 'View Tool',
              equipmentId: request.itemId,
            ),
          ),
        );
      }
      if (role == _RequestRole.owner || role == _RequestRole.both) {
        suggestions.add(
          DashboardCalendarSuggestion(
            type: DashboardCalendarSuggestionType.overdueRetrieval,
            title: 'Retrieval follow-up needed',
            description: 'Begin retrieval workflow for "${request.itemName}".',
            priority: DashboardCalendarSuggestionPriority.high,
            actionTarget: DashboardCalendarActionTarget(
              kind: DashboardCalendarActionKind.openRequest,
              label: 'Open Request',
              requestId: request.requestId,
            ),
            secondaryActionTarget: DashboardCalendarActionTarget(
              kind: DashboardCalendarActionKind.openEquipmentItem,
              label: 'View Tool',
              equipmentId: request.itemId,
            ),
          ),
        );
      }
    }

    return suggestions;
  }

  String _seasonSubtitle({
    required String season,
    required List<String> seasonalCrops,
  }) {
    if (seasonalCrops.isEmpty) {
      return 'Plan tasks for ${season.toLowerCase()}';
    }
    return '${seasonalCrops.take(3).join(', ')} in season';
  }

  bool _isInMonth(DateTime day, DateTime monthStart) =>
      day.year == monthStart.year && day.month == monthStart.month;

  void _addEvent({
    required Map<DateTime, DashboardCalendarDayData> daysByDate,
    required DateTime date,
    required DashboardCalendarEvent event,
  }) {
    final existing = daysByDate[date];
    if (existing == null) return;
    daysByDate[date] = DashboardCalendarDayData(
      date: existing.date,
      events: [...existing.events, event],
      suggestions: existing.suggestions,
    );
  }

  void _addSuggestion({
    required Map<DateTime, DashboardCalendarDayData> daysByDate,
    required DateTime date,
    required DashboardCalendarSuggestion suggestion,
  }) {
    final existing = daysByDate[date];
    if (existing == null) return;
    daysByDate[date] = DashboardCalendarDayData(
      date: existing.date,
      events: existing.events,
      suggestions: [...existing.suggestions, suggestion],
    );
  }

  static DateTime _dayKey(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  Iterable<DateTime> _daysInRange(DateTime start, DateTime end) sync* {
    for (
      DateTime day = start;
      !day.isAfter(end);
      day = day.add(const Duration(days: 1))
    ) {
      yield day;
    }
  }

  _RequestRole _resolveRole(RentRequest request, String userId) {
    final isRenter = request.renterId == userId;
    final isOwner = request.ownerId == userId;
    if (isRenter && isOwner) return _RequestRole.both;
    if (isOwner) return _RequestRole.owner;
    return _RequestRole.renter;
  }

  List<RentRequest> _mergeRequests(
    List<RentRequest> renterRequests,
    List<RentRequest> ownerRequests,
  ) {
    final byId = <String, RentRequest>{};
    for (final request in [...renterRequests, ...ownerRequests]) {
      byId[request.requestId] = request;
    }
    final list = byId.values.toList(growable: false);
    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  String _seasonForMonth(int month) {
    return (month >= 6 && month <= 11) ? 'Wet Season' : 'Dry Season';
  }

  String? _primaryToolCategoryForSeasonalCrops({
    required String season,
    required List<String> seasonalCrops,
  }) {
    final categories = <String>{};

    for (final crop in seasonalCrops) {
      for (final key in _cropPreferenceKeysFor(crop, season)) {
        final mapped = cropToolTypes[key];
        if (mapped != null) categories.addAll(mapped);
      }
    }

    if (categories.isEmpty) return null;
    return categories.first;
  }

  List<String> _cropPreferenceKeysFor(String cropName, String season) {
    final trimmed = cropName.trim();
    if (trimmed.isEmpty) return const [];
    if (cropToolTypes.containsKey(trimmed)) return [trimmed];

    final lower = trimmed.toLowerCase();
    if (lower == 'rice' || lower.contains('rice')) {
      final riceKey = season == 'Wet Season'
          ? 'Rice (Wet Season)'
          : 'Rice (Dry Season)';
      return [riceKey];
    }
    if (lower == 'corn' || lower.contains('corn')) {
      return const ['White Corn'];
    }
    if (lower == 'upo' ||
        lower.contains('upo') ||
        lower.contains('bottle gourd')) {
      return const ['Upo (Bottle Gourd)'];
    }
    return const [];
  }

  List<String> _seasonalCropsForSeason({
    required String season,
    required DashboardCalendarContext context,
  }) {
    if (context.cropsBySeason.isNotEmpty) {
      return context.cropsBySeason[season] ?? const [];
    }
    if (season == context.season) return context.seasonalCrops;
    return const [];
  }

  List<String> _seasonalCropsForMonth({
    required int month,
    required String fallbackSeason,
    required DashboardCalendarContext context,
  }) {
    if (context.cropsByMonth.isNotEmpty) {
      final monthCrops = context.cropsByMonth[month];
      if (monthCrops != null && monthCrops.isNotEmpty) return monthCrops;
    }
    return _seasonalCropsForSeason(season: fallbackSeason, context: context);
  }

  Map<String, List<String>> _buildCropsBySeason(List<CropSeasonItem> crops) {
    final wet = <String>{};
    final dry = <String>{};
    final yearRound = <String>{};

    for (final crop in crops) {
      final seasons = crop.seasons.map((s) => s.trim()).toSet();
      final name = crop.name.trim();
      if (name.isEmpty) continue;

      if (seasons.contains('Year Round')) {
        wet.add(name);
        dry.add(name);
        yearRound.add(name);
      }
      if (seasons.contains('Wet Season')) {
        wet.add(name);
      }
      if (seasons.contains('Dry Season')) {
        dry.add(name);
      }
      yearRound.add(name);
    }

    final wetList = wet.toList()..sort();
    final dryList = dry.toList()..sort();
    final yearRoundList = yearRound.toList()..sort();

    return {
      'Wet Season': wetList,
      'Dry Season': dryList,
      'Year Round': yearRoundList,
    };
  }

  Map<int, List<String>> _buildCropsByMonth(List<CropSeasonItem> crops) {
    final monthBuckets = <int, Set<String>>{
      for (var month = 1; month <= 12; month++) month: <String>{},
    };

    for (final crop in crops) {
      final name = crop.name.trim();
      if (name.isEmpty) continue;

      final months = <int>{};

      if (crop.seasons.contains('Year Round')) {
        months.addAll(monthBuckets.keys);
      }
      months.addAll(crop.plantingMonths);
      months.addAll(crop.harvestingMonths);

      if (months.isEmpty) {
        final seasons = crop.seasons.map((s) => s.trim()).toSet();
        if (seasons.contains('Wet Season')) {
          months.addAll(const {6, 7, 8, 9, 10, 11});
        }
        if (seasons.contains('Dry Season')) {
          months.addAll(const {12, 1, 2, 3, 4, 5});
        }
      }

      for (final month in months) {
        if (month >= 1 && month <= 12) {
          monthBuckets[month]!.add(name);
        }
      }
    }

    return {
      for (final entry in monthBuckets.entries)
        entry.key: (entry.value.toList(growable: false)..sort()),
    };
  }

  String _roleLabel(_RequestRole role) {
    switch (role) {
      case _RequestRole.owner:
        return 'Lender';
      case _RequestRole.both:
        return 'Both';
      case _RequestRole.renter:
        return 'Renter';
    }
  }

  String _statusLabel(RentRequestStatus status) {
    switch (status) {
      case RentRequestStatus.onTheWay:
        return 'On The Way';
      case RentRequestStatus.inProgress:
        return 'In Progress';
      case RentRequestStatus.readyForPickup:
        return 'Ready for Pick Up';
      case RentRequestStatus.pickedUp:
        return 'Picked Up';
      default:
        return status.name[0].toUpperCase() + status.name.substring(1);
    }
  }
}

enum _RequestRole { renter, owner, both }
