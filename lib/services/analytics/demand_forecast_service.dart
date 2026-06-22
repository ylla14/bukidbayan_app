import 'package:bukidbayan_app/models/crop_preference.dart';
import 'package:bukidbayan_app/models/demand_forecast.dart';
import 'package:bukidbayan_app/models/rent_request.dart';

class DemandForecastService {
  DemandForecastService({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  static const Set<RentRequestStatus> _excludedStatuses = {
    RentRequestStatus.declined,
    RentRequestStatus.canceled,
  };

  static const Map<String, List<String>> _phaseCategoryMap = {
    'land preparation': [
      'Tractor',
      'Hand Tractor (Kuliglig)',
      'Floating Tiller (Pagong)',
      'Implements',
    ],
    'tilling': [
      'Tractor',
      'Hand Tractor (Kuliglig)',
      'Floating Tiller (Pagong)',
      'Implements',
    ],
    'plowing': [
      'Tractor',
      'Hand Tractor (Kuliglig)',
      'Floating Tiller (Pagong)',
      'Implements',
    ],
    'planting': ['Machine', 'Hand Tool', 'Implements'],
    'seeding': ['Machine', 'Hand Tool', 'Implements'],
    'transplanting': ['Machine', 'Hand Tool'],
    'irrigation': ['Machine'],
    'fertilizing': ['Machine', 'Hand Tool'],
    'spraying': ['Machine', 'Hand Tool'],
    'harvest': ['Harvester (Halimaw)', 'Machine', 'Rice Mill (Gilingan)'],
    'harvesting': ['Harvester (Halimaw)', 'Machine', 'Rice Mill (Gilingan)'],
    'post-harvest': ['Rice Mill (Gilingan)', 'Machine', 'Hand Tool'],
    'milling': ['Rice Mill (Gilingan)', 'Machine'],
    'hauling': ['Hand Tractor (Kuliglig)', 'Tractor'],
    'transport': ['Hand Tractor (Kuliglig)', 'Tractor'],
  };

  static const Map<String, List<String>> _useCategoryMap = {
    'plow': [
      'Tractor',
      'Hand Tractor (Kuliglig)',
      'Floating Tiller (Pagong)',
      'Implements',
    ],
    'till': [
      'Tractor',
      'Hand Tractor (Kuliglig)',
      'Floating Tiller (Pagong)',
      'Implements',
    ],
    'prepare': ['Tractor', 'Hand Tractor (Kuliglig)', 'Implements'],
    'seed': ['Machine', 'Hand Tool', 'Implements'],
    'plant': ['Machine', 'Hand Tool', 'Implements'],
    'water': ['Machine'],
    'irrigat': ['Machine'],
    'pump': ['Machine'],
    'spray': ['Machine', 'Hand Tool'],
    'fertiliz': ['Machine', 'Hand Tool'],
    'harvest': ['Harvester (Halimaw)', 'Machine'],
    'thresh': ['Machine', 'Harvester (Halimaw)'],
    'mill': ['Rice Mill (Gilingan)', 'Machine'],
    'shell': ['Machine'],
    'haul': ['Hand Tractor (Kuliglig)', 'Tractor'],
    'transport': ['Hand Tractor (Kuliglig)', 'Tractor'],
  };

  static const Map<String, String> _itemNameCategoryMap = {
    'floating tiller': 'Floating Tiller (Pagong)',
    'pagong': 'Floating Tiller (Pagong)',
    'hand tractor': 'Hand Tractor (Kuliglig)',
    'kuliglig': 'Hand Tractor (Kuliglig)',
    'tractor': 'Tractor',
    'rotavator': 'Implements',
    'plow': 'Implements',
    'harvester': 'Harvester (Halimaw)',
    'halimaw': 'Harvester (Halimaw)',
    'rice mill': 'Rice Mill (Gilingan)',
    'gilingan': 'Rice Mill (Gilingan)',
    'water pump': 'Machine',
    'pump': 'Machine',
    'sprayer': 'Machine',
    'thresher': 'Machine',
    'sheller': 'Machine',
    'hoe': 'Hand Tool',
    'rake': 'Hand Tool',
    'shovel': 'Hand Tool',
    'bolo': 'Hand Tool',
  };

  DemandForecastSnapshot buildWeeklyForecast({
    required List<RentRequest> requests,
    List<String> seasonalCrops = const [],
    Map<int, List<String>> cropsByMonth = const {},
    List<String> savedCrops = const [],
    Map<String, String> equipmentCategoryByItemId = const {},
    DateTime? now,
  }) {
    final generatedAt = _dayKey(now ?? _now());
    final weekStart = generatedAt;
    final weekEnd = generatedAt.add(const Duration(days: 6));
    final season = _seasonForMonth(generatedAt.month);
    final weekCrops = _resolveWeekCrops(
      weekStart: weekStart,
      weekEnd: weekEnd,
      seasonalCrops: seasonalCrops,
      cropsByMonth: cropsByMonth,
    );
    final activeRequests = requests
        .where((request) => !_excludedStatuses.contains(request.status))
        .toList(growable: false);
    final accumulators = <String, _ForecastAccumulator>{};

    for (final crop in weekCrops) {
      final cropLabel = _normalizeCropLabel(crop, season) ?? crop.trim();
      _applySignal(
        accumulators: accumulators,
        categories: _categoriesForCrop(crop, season),
        weight: 0.35,
        cropLabel: cropLabel,
      );
    }

    for (final crop in savedCrops) {
      final cropLabel = _normalizeCropLabel(crop, season) ?? crop.trim();
      _applySignal(
        accumulators: accumulators,
        categories: _categoriesForCrop(crop, season),
        weight: 0.25,
        cropLabel: cropLabel,
      );
    }

    for (final request in activeRequests) {
      final signalDate = _requestSignalDate(request);
      final recencyWeight = _recencyWeight(
        signalDate: signalDate,
        now: weekStart,
      );
      final statusWeight = _statusWeight(request.status);
      final requestWeight = recencyWeight * statusWeight;
      final hasForecastInputs =
          _hasText(request.cropType) ||
          _hasText(request.farmingPhase) ||
          _hasText(request.intendedUse);
      final inForecastWeek = _isWithinRange(request.start, weekStart, weekEnd);
      final upcomingSoon =
          request.start.isAfter(weekEnd) &&
          !request.start.isAfter(weekEnd.add(const Duration(days: 14)));

      final cropSignal = request.cropType?.trim();
      final phaseSignal = request.farmingPhase?.trim();
      final useSignal = request.intendedUse?.trim();
      final itemSignal = request.itemName.trim();
      final knownCategory = equipmentCategoryByItemId[request.itemId]?.trim();

      final cropCategories = _categoriesForCrop(request.cropType, season);
      final phaseCategories = _categoriesForPhrase(
        request.farmingPhase,
        _phaseCategoryMap,
      );
      final useCategories = _categoriesForPhrase(
        request.intendedUse,
        _useCategoryMap,
      );
      final itemCategories = _categoriesForItemName(request.itemName);

      _applySignal(
        accumulators: accumulators,
        categories: cropCategories,
        weight: requestWeight * 0.6,
        requestId: request.requestId,
        recentRequest: recencyWeight >= 0.75,
        cropLabel: cropSignal,
        inForecastWeek: inForecastWeek,
      );
      _applySignal(
        accumulators: accumulators,
        categories: phaseCategories,
        weight: requestWeight * 0.85,
        requestId: request.requestId,
        recentRequest: recencyWeight >= 0.75,
        phaseLabel: phaseSignal,
        inForecastWeek: inForecastWeek,
      );
      _applySignal(
        accumulators: accumulators,
        categories: useCategories,
        weight: requestWeight,
        requestId: request.requestId,
        recentRequest: recencyWeight >= 0.75,
        useLabel: useSignal,
        inForecastWeek: inForecastWeek,
      );

      final hadStructuredSignal =
          cropCategories.isNotEmpty ||
          phaseCategories.isNotEmpty ||
          useCategories.isNotEmpty;
      if (!hadStructuredSignal || itemCategories.isNotEmpty) {
        _applySignal(
          accumulators: accumulators,
          categories: itemCategories,
          weight: requestWeight * (hadStructuredSignal ? 0.35 : 0.7),
          requestId: request.requestId,
          recentRequest: recencyWeight >= 0.75,
          itemLabel: itemSignal,
          inForecastWeek: inForecastWeek,
        );
      }

      if (_hasText(knownCategory)) {
        _applySignal(
          accumulators: accumulators,
          categories: [knownCategory!],
          weight: requestWeight * (hadStructuredSignal ? 2.5 : 1.8),
          requestId: request.requestId,
          recentRequest: recencyWeight >= 0.75,
          itemLabel: itemSignal,
          inForecastWeek: inForecastWeek,
        );
      }

      final bonusCategories = <String>{
        ...cropCategories,
        ...phaseCategories,
        ...useCategories,
        ...itemCategories,
        if (_hasText(knownCategory)) knownCategory!,
      };
      if (bonusCategories.isNotEmpty && inForecastWeek) {
        _applySignal(
          accumulators: accumulators,
          categories: bonusCategories,
          weight: 1.2,
          requestId: request.requestId,
          recentRequest: true,
          inForecastWeek: true,
        );
      } else if (bonusCategories.isNotEmpty && upcomingSoon) {
        _applySignal(
          accumulators: accumulators,
          categories: bonusCategories,
          weight: 0.45,
          requestId: request.requestId,
          recentRequest: recencyWeight >= 0.75,
        );
      }

      if (hasForecastInputs && bonusCategories.isNotEmpty) {
        _applySignal(
          accumulators: accumulators,
          categories: bonusCategories,
          weight: 0.2,
          requestId: request.requestId,
          recentRequest: recencyWeight >= 0.75,
        );
      }
    }

    final insights =
        accumulators.values
            .where((accumulator) => accumulator.score >= 0.8)
            .map(_buildInsight)
            .toList(growable: false)
          ..sort((a, b) {
            final scoreCompare = b.score.compareTo(a.score);
            if (scoreCompare != 0) return scoreCompare;
            final requestCompare = b.matchedRequests.compareTo(
              a.matchedRequests,
            );
            if (requestCompare != 0) return requestCompare;
            return a.equipmentCategory.compareTo(b.equipmentCategory);
          });

    final topInsights = insights.take(3).toList(growable: false);
    final locationLabel = _resolveLocationLabel(activeRequests);
    final confidence = _resolveConfidence(
      requests: activeRequests,
      insights: topInsights,
    );

    return DemandForecastSnapshot(
      generatedAt: generatedAt,
      weekStart: weekStart,
      weekEnd: weekEnd,
      locationLabel: locationLabel,
      summary: _buildSummary(
        insights: topInsights,
        locationLabel: locationLabel,
        confidence: confidence,
      ),
      confidence: confidence,
      insights: topInsights,
    );
  }

  List<String> _resolveWeekCrops({
    required DateTime weekStart,
    required DateTime weekEnd,
    required List<String> seasonalCrops,
    required Map<int, List<String>> cropsByMonth,
  }) {
    final crops = <String>{};
    for (
      DateTime day = weekStart;
      !day.isAfter(weekEnd);
      day = day.add(const Duration(days: 1))
    ) {
      final monthCrops = cropsByMonth[day.month] ?? const [];
      crops.addAll(monthCrops.where((crop) => crop.trim().isNotEmpty));
    }

    if (crops.isEmpty) {
      crops.addAll(seasonalCrops.where((crop) => crop.trim().isNotEmpty));
    }

    final cropList = crops.toList(growable: false)..sort();
    return cropList;
  }

  void _applySignal({
    required Map<String, _ForecastAccumulator> accumulators,
    required Iterable<String> categories,
    required double weight,
    String? requestId,
    bool recentRequest = false,
    bool inForecastWeek = false,
    String? cropLabel,
    String? phaseLabel,
    String? useLabel,
    String? itemLabel,
  }) {
    if (weight <= 0) return;
    final uniqueCategories = categories
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();

    for (final category in uniqueCategories) {
      final accumulator = accumulators.putIfAbsent(
        category,
        () => _ForecastAccumulator(category: category),
      );
      accumulator.score += weight;
      if (requestId != null && requestId.isNotEmpty) {
        accumulator.requestIds.add(requestId);
        if (recentRequest) {
          accumulator.recentRequestIds.add(requestId);
        }
        if (inForecastWeek) {
          accumulator.forecastWeekRequestIds.add(requestId);
        }
      }
      if (_hasText(cropLabel)) {
        accumulator.cropSignals.add(cropLabel!.trim());
      }
      if (_hasText(phaseLabel)) {
        accumulator.phaseSignals.add(phaseLabel!.trim());
      }
      if (_hasText(useLabel)) {
        accumulator.useSignals.add(useLabel!.trim());
      }
      if (_hasText(itemLabel)) {
        accumulator.itemSignals.add(itemLabel!.trim());
      }
    }
  }

  DemandForecastInsight _buildInsight(_ForecastAccumulator accumulator) {
    final drivers = <String>[];
    if (accumulator.recentRequestIds.isNotEmpty) {
      drivers.add(
        '${accumulator.recentRequestIds.length} recent request'
        '${accumulator.recentRequestIds.length == 1 ? '' : 's'}',
      );
    }
    if (accumulator.forecastWeekRequestIds.isNotEmpty) {
      drivers.add(
        '${accumulator.forecastWeekRequestIds.length} booking'
        '${accumulator.forecastWeekRequestIds.length == 1 ? '' : 's'} this week',
      );
    }
    if (accumulator.cropSignals.isNotEmpty) {
      drivers.add('Crop signal: ${accumulator.cropSignals.take(2).join(', ')}');
    }
    if (accumulator.phaseSignals.isNotEmpty) {
      drivers.add(
        'Phase signal: ${accumulator.phaseSignals.take(2).join(', ')}',
      );
    }
    if (accumulator.useSignals.isNotEmpty) {
      drivers.add('Use signal: ${accumulator.useSignals.take(2).join(', ')}');
    }
    if (drivers.isEmpty && accumulator.itemSignals.isNotEmpty) {
      drivers.add(
        'Based on tools used: ${accumulator.itemSignals.take(2).join(', ')}',
      );
    }

    final level = _resolveLevel(accumulator);
    return DemandForecastInsight(
      equipmentCategory: accumulator.category,
      score: accumulator.score,
      level: level,
      matchedRequests: accumulator.requestIds.length,
      recentRequests: accumulator.recentRequestIds.length,
      drivers: drivers.take(3).toList(growable: false),
      recommendation: _recommendationForLevel(level, accumulator.category),
    );
  }

  DemandForecastLevel _resolveLevel(_ForecastAccumulator accumulator) {
    if (accumulator.score >= 5.0 ||
        accumulator.requestIds.length >= 4 ||
        accumulator.forecastWeekRequestIds.length >= 2) {
      return DemandForecastLevel.high;
    }
    if (accumulator.score >= 2.5 ||
        accumulator.requestIds.length >= 2 ||
        accumulator.recentRequestIds.length >= 2) {
      return DemandForecastLevel.medium;
    }
    return DemandForecastLevel.low;
  }

  DemandForecastConfidence _resolveConfidence({
    required List<RentRequest> requests,
    required List<DemandForecastInsight> insights,
  }) {
    if (insights.isEmpty) return DemandForecastConfidence.low;

    final requestCount = requests.length;
    final topInsight = insights.first;
    if (requestCount >= 4 && topInsight.recentRequests >= 2) {
      return DemandForecastConfidence.high;
    }
    if (requestCount >= 2 || topInsight.drivers.length >= 2) {
      return DemandForecastConfidence.medium;
    }
    return DemandForecastConfidence.low;
  }

  String _buildSummary({
    required List<DemandForecastInsight> insights,
    required String locationLabel,
    required DemandForecastConfidence confidence,
  }) {
    if (insights.isEmpty) {
      return 'Not enough booking signals yet. Forecasts will improve as more requests, crop details, and weekly usage data are captured.';
    }

    final top = insights.first;
    final levelLabel = _levelLabel(top.level).toLowerCase();
    final confidenceLabel = _confidenceLabel(confidence).toLowerCase();
    return 'Estimated $levelLabel demand for ${top.equipmentCategory} in $locationLabel this week with $confidenceLabel confidence.';
  }

  String _recommendationForLevel(
    DemandForecastLevel level,
    String equipmentCategory,
  ) {
    switch (level) {
      case DemandForecastLevel.high:
        return 'Prepare or secure $equipmentCategory early for next week.';
      case DemandForecastLevel.medium:
        return 'Monitor availability and scheduling for $equipmentCategory.';
      case DemandForecastLevel.low:
        return 'Keep $equipmentCategory visible, but no urgent action is needed.';
    }
  }

  String _resolveLocationLabel(List<RentRequest> requests) {
    final counts = <String, int>{};
    for (final request in requests) {
      final label = _firstNonEmpty([
        request.farmBarangay,
        request.barangay,
        request.farmMunicipality,
        request.municipality,
        request.farmProvince,
        request.province,
      ]);
      if (label == null) continue;
      counts.update(label, (value) => value + 1, ifAbsent: () => 1);
    }

    if (counts.isEmpty) return 'your area';

    final ranked = counts.entries.toList(growable: false)
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;
        return a.key.compareTo(b.key);
      });
    return ranked.first.key;
  }

  List<String> _categoriesForCrop(String? rawCrop, String season) {
    if (!_hasText(rawCrop)) return const [];
    final key = _normalizeCropLabel(rawCrop!, season);
    if (key == null) return const [];
    return cropToolTypes[key] ?? const [];
  }

  String? _normalizeCropLabel(String rawCrop, String season) {
    final trimmed = rawCrop.trim();
    if (trimmed.isEmpty) return null;
    if (cropToolTypes.containsKey(trimmed)) return trimmed;

    final lower = trimmed.toLowerCase();
    if (lower == 'rice' || lower.contains('rice')) {
      return season == 'Wet Season' ? 'Rice (Wet Season)' : 'Rice (Dry Season)';
    }
    if (lower == 'corn' || lower.contains('corn')) {
      return 'White Corn';
    }
    if (lower == 'upo' ||
        lower.contains('bottle gourd') ||
        lower.contains('gourd')) {
      return 'Upo (Bottle Gourd)';
    }
    if (lower.contains('pechay')) return 'Pechay';
    if (lower.contains('eggplant')) return 'Eggplant';
    if (lower.contains('tomato')) return 'Tomato';
    if (lower.contains('watermelon')) return 'Watermelon';
    if (lower.contains('banana')) return 'Banana';
    if (lower.contains('squash')) return 'Squash';
    return trimmed;
  }

  List<String> _categoriesForPhrase(
    String? rawValue,
    Map<String, List<String>> phraseMap,
  ) {
    if (!_hasText(rawValue)) return const [];
    final lower = rawValue!.trim().toLowerCase();
    final matches = <String>{};
    for (final entry in phraseMap.entries) {
      if (lower.contains(entry.key)) {
        matches.addAll(entry.value);
      }
    }
    return matches.toList(growable: false);
  }

  List<String> _categoriesForItemName(String itemName) {
    final lower = itemName.trim().toLowerCase();
    if (lower.isEmpty) return const [];
    final matches = <String>{};
    for (final entry in _itemNameCategoryMap.entries) {
      if (lower.contains(entry.key)) {
        matches.add(entry.value);
      }
    }
    return matches.toList(growable: false);
  }

  double _recencyWeight({required DateTime signalDate, required DateTime now}) {
    final normalizedSignal = _dayKey(signalDate);
    if (normalizedSignal.isAfter(now)) return 1.0;

    final ageDays = now.difference(normalizedSignal).inDays;
    if (ageDays <= 30) return 1.0;
    if (ageDays <= 90) return 0.75;
    if (ageDays <= 180) return 0.5;
    return 0.25;
  }

  double _statusWeight(RentRequestStatus status) {
    switch (status) {
      case RentRequestStatus.completed:
      case RentRequestStatus.finished:
      case RentRequestStatus.returned:
      case RentRequestStatus.inProgress:
        return 1.0;
      case RentRequestStatus.approved:
      case RentRequestStatus.readyForPickup:
      case RentRequestStatus.pickedUp:
      case RentRequestStatus.onTheWay:
      case RentRequestStatus.retrieving:
        return 0.85;
      case RentRequestStatus.pending:
        return 0.7;
      case RentRequestStatus.declined:
      case RentRequestStatus.canceled:
        return 0;
    }
  }

  DateTime _requestSignalDate(RentRequest request) =>
      request.createdAt ?? request.start;

  bool _isWithinRange(DateTime value, DateTime start, DateTime end) {
    final normalized = _dayKey(value);
    return !normalized.isBefore(start) && !normalized.isAfter(end);
  }

  String _seasonForMonth(int month) =>
      (month >= 6 && month <= 11) ? 'Wet Season' : 'Dry Season';

  String _levelLabel(DemandForecastLevel level) {
    switch (level) {
      case DemandForecastLevel.high:
        return 'High';
      case DemandForecastLevel.medium:
        return 'Medium';
      case DemandForecastLevel.low:
        return 'Low';
    }
  }

  String _confidenceLabel(DemandForecastConfidence confidence) {
    switch (confidence) {
      case DemandForecastConfidence.high:
        return 'High';
      case DemandForecastConfidence.medium:
        return 'Medium';
      case DemandForecastConfidence.low:
        return 'Early';
    }
  }

  static DateTime _dayKey(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _hasText(String? value) => value != null && value.trim().isNotEmpty;

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (_hasText(value)) return value!.trim();
    }
    return null;
  }
}

class _ForecastAccumulator {
  _ForecastAccumulator({required this.category});

  final String category;
  double score = 0;
  final Set<String> requestIds = <String>{};
  final Set<String> recentRequestIds = <String>{};
  final Set<String> forecastWeekRequestIds = <String>{};
  final Set<String> cropSignals = <String>{};
  final Set<String> phaseSignals = <String>{};
  final Set<String> useSignals = <String>{};
  final Set<String> itemSignals = <String>{};
}
