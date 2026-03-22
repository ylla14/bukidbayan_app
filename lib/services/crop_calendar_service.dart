import 'dart:convert';

import 'package:http/http.dart' as http;

class CropSeasonItem {
  final String? canonicalKey;
  final String name;
  final List<String> seasons;
  final List<String> regions;
  final String? imageUrl;
  final List<int> plantingMonths;
  final List<int> harvestingMonths;
  final String? plantingPhase;
  final String? harvestingPhase;
  final String? notes;
  final Map<String, dynamic>? source;

  const CropSeasonItem({
    this.canonicalKey,
    required this.name,
    required this.seasons,
    required this.regions,
    this.imageUrl,
    this.plantingMonths = const [],
    this.harvestingMonths = const [],
    this.plantingPhase,
    this.harvestingPhase,
    this.notes,
    this.source,
  });

  bool get isYearRound => seasons.contains('Year Round');

  bool isRelevantInMonth(int month) {
    if (isYearRound) return true;
    if (plantingMonths.contains(month)) return true;
    if (harvestingMonths.contains(month)) return true;
    return false;
  }
}

class CropCalendarService {
  // Provide at build-time:
  // flutter run --dart-define=CROP_CALENDAR_API_URL=http://127.0.0.1:8088/v1/crop-calendar
  static const String _defaultApiUrl = String.fromEnvironment(
    'CROP_CALENDAR_API_URL',
    defaultValue: '',
  );
  final String _apiUrl;
  final http.Client _httpClient;

  CropCalendarService({http.Client? httpClient, String? apiUrl})
    : _httpClient = httpClient ?? http.Client(),
      _apiUrl = (apiUrl ?? _defaultApiUrl).trim();

  Future<List<CropSeasonItem>> getRegionalCrops({
    required String region,
    DateTime? now,
  }) async {
    final month = (now ?? DateTime.now()).month;
    final currentSeason = _detectSeason(month);

    final remote = await _tryFetchFromApi(region: region, month: month);
    if (remote.isNotEmpty) {
      return remote
          .where((item) => _matchesRegion(item.regions, region))
          .toList(growable: false);
    }

    return _fallbackSeaCalendar()
        .where((c) => _matchesRegion(c.regions, region))
        .toList(growable: false)
        .map((c) {
          final includesCurrent = c.seasons.contains(currentSeason);
          if (includesCurrent || c.seasons.contains('Year Round')) return c;
          return c;
        })
        .toList(growable: false);
  }

  String detectSeason(int month) => _detectSeason(month);

  String _detectSeason(int month) {
    // Philippines baseline:
    // Wet season: June-November, Dry season: December-May
    return (month >= 6 && month <= 11) ? 'Wet Season' : 'Dry Season';
  }

  Future<List<CropSeasonItem>> _tryFetchFromApi({
    required String region,
    required int month,
  }) async {
    if (_apiUrl.isEmpty) return const [];

    try {
      final uri = Uri.parse(_apiUrl).replace(
        queryParameters: {
          'country': 'PHL',
          'region': region,
          'month': month.toString(),
        },
      );

      final response = await _httpClient.get(uri);
      if (response.statusCode != 200) return const [];

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];

      final items = <CropSeasonItem>[];
      final seenKeys = <String>{};
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;

        final canonicalKey = _nullableText(
          entry['canonicalKey'] ?? entry['canonical_key'],
        );
        final rawName = (entry['name'] ?? '').toString().trim();
        if (rawName.isEmpty && canonicalKey == null) continue;
        final name = _resolveDisplayName(
          canonicalKey: canonicalKey,
          rawName: rawName,
        );
        if (name.isEmpty) continue;

        final dedupeKey = canonicalKey ?? name.toLowerCase();
        if (!seenKeys.add(dedupeKey)) continue;

        final regions = _asStringList(entry['regions']);
        final plantingMonths = _asMonthList(
          entry['plantingMonths'] ?? entry['planting_months'],
        );
        final harvestingMonths = _asMonthList(
          entry['harvestingMonths'] ??
              entry['harvestMonths'] ??
              entry['harvesting_months'] ??
              entry['harvest_months'],
        );

        var seasons = _normalizeSeasons(entry['seasons']);
        if (seasons.isEmpty) {
          seasons = _seasonsFromMonths([
            ...plantingMonths,
            ...harvestingMonths,
            ..._asMonthList(entry['months']),
          ]);
        }
        if (seasons.isEmpty) seasons = const ['Year Round'];

        items.add(
          CropSeasonItem(
            canonicalKey: canonicalKey,
            name: name,
            seasons: seasons,
            regions: regions.isEmpty ? <String>[region] : regions,
            imageUrl: _nullableText(entry['imageUrl'] ?? entry['image_url']),
            plantingMonths: plantingMonths,
            harvestingMonths: harvestingMonths,
            plantingPhase: _nullableText(
              entry['plantingPhase'] ?? entry['planting_phase'],
            ),
            harvestingPhase: _nullableText(
              entry['harvestingPhase'] ?? entry['harvesting_phase'],
            ),
            notes: _nullableText(entry['notes']),
            source: _asMap(entry['source']),
          ),
        );
      }

      return items;
    } catch (_) {
      return const [];
    }
  }

  List<String> _asStringList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return <String>[raw.trim()];
    }
    return const [];
  }

  List<String> _normalizeSeasons(dynamic raw) {
    final values = _asStringList(raw);
    final normalized = <String>{};
    for (final value in values) {
      final lower = value.toLowerCase().replaceAll('-', ' ').trim();
      if (lower == 'wet season' || lower == 'wet') {
        normalized.add('Wet Season');
      } else if (lower == 'dry season' || lower == 'dry') {
        normalized.add('Dry Season');
      } else if (lower == 'year round' ||
          lower == 'yearround' ||
          lower == 'all year' ||
          lower == 'perennial') {
        normalized.add('Year Round');
      }
    }
    return normalized.toList(growable: false);
  }

  List<int> _asMonthList(dynamic raw) {
    final output = <int>{};

    if (raw is List) {
      for (final value in raw) {
        final parsed = _parseMonth(value);
        if (parsed != null) output.add(parsed);
      }
    } else {
      final parsed = _parseMonth(raw);
      if (parsed != null) output.add(parsed);
    }

    final result = output.toList(growable: false)..sort();
    return result;
  }

  int? _parseMonth(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) {
      if (raw >= 1 && raw <= 12) return raw;
      return null;
    }
    if (raw is num) {
      final month = raw.toInt();
      if (month >= 1 && month <= 12) return month;
      return null;
    }

    final text = raw.toString().trim();
    if (text.isEmpty) return null;

    final direct = int.tryParse(text);
    if (direct != null && direct >= 1 && direct <= 12) return direct;

    const months = <String, int>{
      'jan': 1,
      'january': 1,
      'feb': 2,
      'february': 2,
      'mar': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'may': 5,
      'jun': 6,
      'june': 6,
      'jul': 7,
      'july': 7,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'sept': 9,
      'september': 9,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'dec': 12,
      'december': 12,
    };

    return months[text.toLowerCase()];
  }

  String? _nullableText(dynamic raw) {
    final text = raw?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    return null;
  }

  String _resolveDisplayName({String? canonicalKey, required String rawName}) {
    final key = canonicalKey?.trim().toLowerCase();
    if (key != null && _displayNameByCanonicalKey.containsKey(key)) {
      return _displayNameByCanonicalKey[key]!;
    }

    final normalizedName = rawName.trim();
    if (normalizedName.isEmpty) return '';

    final aliasKey = _normalizeAliasKey(normalizedName);
    final mappedAlias = _canonicalKeyByAlias[aliasKey];
    if (mappedAlias != null &&
        _displayNameByCanonicalKey.containsKey(mappedAlias)) {
      return _displayNameByCanonicalKey[mappedAlias]!;
    }
    return normalizedName;
  }

  String _normalizeAliasKey(String value) {
    final lower = value.toLowerCase();
    final buffer = StringBuffer();
    for (final code in lower.codeUnits) {
      final isAlphaNum =
          (code >= 97 && code <= 122) || (code >= 48 && code <= 57);
      buffer.write(isAlphaNum ? String.fromCharCode(code) : ' ');
    }
    return buffer
        .toString()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .join(' ');
  }

  bool _matchesRegion(List<String> regions, String region) {
    final normalizedRegion = region.trim().toLowerCase();
    if (normalizedRegion.isEmpty) return true;
    return regions.any((r) => r.trim().toLowerCase() == normalizedRegion);
  }

  List<String> _seasonsFromMonths(List<int> months) {
    if (months.isEmpty) return const [];
    if (months.length >= 10) return const ['Year Round'];

    var hasWet = false;
    var hasDry = false;

    for (final month in months) {
      if (month >= 6 && month <= 11) {
        hasWet = true;
      } else {
        hasDry = true;
      }
    }

    if (hasWet && hasDry) return const ['Wet Season', 'Dry Season'];
    if (hasWet) return const ['Wet Season'];
    return const ['Dry Season'];
  }

  List<CropSeasonItem> _fallbackSeaCalendar() {
    // Fallback crop calendar aligned to BukidBayan farm usage guidance.
    const regions = <String>['philippines'];
    const allMonths = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

    return const [
      CropSeasonItem(
        canonicalKey: 'rice_wet',
        name: 'Rice (Wet Season)',
        seasons: ['Wet Season'],
        regions: regions,
        plantingMonths: [6, 7],
        harvestingMonths: [10, 11],
        plantingPhase: 'June-July',
        harvestingPhase: 'October-November',
        notes:
            'Main crop for rainy months; suitable for rain-fed or irrigated systems.',
        imageUrl:
            'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1773064316/rice_eix9px.jpg',
      ),
      CropSeasonItem(
        canonicalKey: 'rice_dry',
        name: 'Rice (Dry Season)',
        seasons: ['Dry Season'],
        regions: regions,
        plantingMonths: [11, 12, 1],
        harvestingMonths: [3, 4],
        plantingPhase: 'November-January',
        harvestingPhase: 'March-April',
        notes:
            'Known locally as Palagad; stable irrigation support is recommended.',
        imageUrl:
            'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1773064316/rice_eix9px.jpg',
      ),
      CropSeasonItem(
        canonicalKey: 'tomato',
        name: 'Tomato',
        seasons: ['Dry Season'],
        regions: regions,
        plantingMonths: [10, 11, 12, 1, 2],
        harvestingMonths: [1, 2, 3, 4, 5],
        plantingPhase: 'October-February',
        harvestingPhase: 'January-May',
        notes: 'Avoid peak wet months to reduce bacterial wilt risk.',
        imageUrl:
            'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1773064317/tomato_vycvfc.jpg',
      ),
      CropSeasonItem(
        canonicalKey: 'watermelon',
        name: 'Watermelon',
        seasons: ['Dry Season'],
        regions: regions,
        plantingMonths: [10, 11, 12, 1],
        harvestingMonths: [1, 2, 3, 4],
        plantingPhase: 'October-January',
        harvestingPhase: 'January-April',
        notes: 'Dry conditions help improve fruit sugar concentration.',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/4/40/Watermelons.jpg',
      ),
      CropSeasonItem(
        canonicalKey: 'squash',
        name: 'Squash',
        seasons: ['Dry Season'],
        regions: regions,
        plantingMonths: [10, 11, 12],
        harvestingMonths: [1, 2, 3],
        plantingPhase: 'October-December',
        harvestingPhase: 'January-March',
        notes: 'Performs best in well-drained soil and low waterlogging.',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/b/bb/YellowSquash.jpg',
      ),
      CropSeasonItem(
        canonicalKey: 'white_corn',
        name: 'White Corn',
        seasons: ['Year Round'],
        regions: regions,
        plantingMonths: [5, 6, 10, 11, 12],
        harvestingMonths: [1, 2, 3, 8, 9],
        plantingPhase: 'May-June or October-December',
        harvestingPhase: 'August-September or January-March',
        notes: 'Often rotated between rice cycles for better land use.',
        imageUrl:
            'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1773064316/corn_d6al6c.jpg',
      ),
      CropSeasonItem(
        canonicalKey: 'pechay',
        name: 'Pechay',
        seasons: ['Year Round'],
        regions: regions,
        plantingMonths: allMonths,
        harvestingMonths: allMonths,
        plantingPhase: 'Any month (best October-December)',
        harvestingPhase: '30-45 days after sowing',
        notes:
            'Fast growth cycle and manageable even in small plots or containers.',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/6/61/Bokchoy.jpg',
      ),
      CropSeasonItem(
        canonicalKey: 'upo_bottle_gourd',
        name: 'Upo (Bottle Gourd)',
        seasons: ['Year Round'],
        regions: regions,
        plantingMonths: [10, 11, 12, 1],
        harvestingMonths: allMonths,
        plantingPhase: 'October-January',
        harvestingPhase: '60-80 days after sowing',
        notes: 'Can be grown year-round but generally peaks in dry months.',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/2/28/Gourds_-_grown_in_the_garden.JPG',
      ),
      CropSeasonItem(
        canonicalKey: 'eggplant',
        name: 'Eggplant',
        seasons: ['Year Round'],
        regions: regions,
        plantingMonths: [10, 11, 12, 1, 2, 5, 6],
        harvestingMonths: allMonths,
        plantingPhase: 'October-February or May-June',
        harvestingPhase: '60-90 days after transplant',
        notes: 'Resilient crop with tolerance for moderate rain and heat.',
        imageUrl:
            'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1773064315/eggplant_mnxhhf.jpg',
      ),
      CropSeasonItem(
        canonicalKey: 'banana',
        name: 'Banana',
        seasons: ['Year Round'],
        regions: regions,
        plantingMonths: [5, 6],
        harvestingMonths: allMonths,
        plantingPhase: 'May-June establishment',
        harvestingPhase: 'Year-round',
        notes:
            'Perennial crop, usually producing first harvest around 10-12 months.',
        imageUrl:
            'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1773064315/banana_m4uiy8.jpg',
      ),
    ];
  }

  static const Map<String, String> _displayNameByCanonicalKey = {
    'rice_wet': 'Rice (Wet Season)',
    'rice_dry': 'Rice (Dry Season)',
    'white_corn': 'White Corn',
    'squash': 'Squash',
    'upo_bottle_gourd': 'Upo (Bottle Gourd)',
    'pechay': 'Pechay',
    'eggplant': 'Eggplant',
    'tomato': 'Tomato',
    'watermelon': 'Watermelon',
    'banana': 'Banana',
  };

  static const Map<String, String> _canonicalKeyByAlias = {
    'rice wet': 'rice_wet',
    'rice wet season': 'rice_wet',
    'rice dry': 'rice_dry',
    'rice dry season': 'rice_dry',
    'white corn': 'white_corn',
    'corn': 'white_corn',
    'squash': 'squash',
    'upo': 'upo_bottle_gourd',
    'bottle gourd': 'upo_bottle_gourd',
    'upo bottle gourd': 'upo_bottle_gourd',
    'pechay': 'pechay',
    'eggplant': 'eggplant',
    'tomato': 'tomato',
    'watermelon': 'watermelon',
    'banana': 'banana',
  };
}
