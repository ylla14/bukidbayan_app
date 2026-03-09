import 'dart:convert';

import 'package:http/http.dart' as http;

class CropSeasonItem {
  final String name;
  final List<String> seasons;
  final List<String> regions;

  const CropSeasonItem({
    required this.name,
    required this.seasons,
    required this.regions,
  });
}

class CropCalendarService {
  // Provide at build-time:
  // flutter run --dart-define=CROP_CALENDAR_API_URL=https://your-api/crops
  static const String _apiUrl =
      String.fromEnvironment('CROP_CALENDAR_API_URL', defaultValue: '');

  Future<List<CropSeasonItem>> getRegionalCrops({
    required String region,
    DateTime? now,
  }) async {
    final month = (now ?? DateTime.now()).month;
    final currentSeason = _detectSeason(month);

    final remote = await _tryFetchFromApi(region: region, month: month);
    if (remote.isNotEmpty) {
      return remote;
    }

    return _fallbackSeaCalendar()
        .where((c) => c.regions.contains(region))
        .toList(growable: false)
        .map((c) {
      final includesCurrent = c.seasons.contains(currentSeason);
      if (includesCurrent || c.seasons.contains('Year Round')) return c;
      return c;
    }).toList(growable: false);
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
      final uri = Uri.parse(_apiUrl).replace(queryParameters: {
        'region': region,
        'month': month.toString(),
      });

      final response = await http.get(uri);
      if (response.statusCode != 200) return const [];

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];

      final items = <CropSeasonItem>[];
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;

        final name = (entry['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        final regionsRaw = entry['regions'];
        final seasonsRaw = entry['seasons'];
        final monthsRaw = entry['months'];

        final regions = _asStringList(regionsRaw);
        var seasons = _asStringList(seasonsRaw);

        if (seasons.isEmpty && monthsRaw is List) {
          final monthInts = monthsRaw
              .map((m) => int.tryParse(m.toString()))
              .whereType<int>()
              .toList(growable: false);
          seasons = _seasonsFromMonths(monthInts);
        }

        if (seasons.isEmpty) {
          seasons = const ['Year Round'];
        }

        items.add(
          CropSeasonItem(
            name: name,
            seasons: seasons,
            regions: regions.isEmpty ? <String>[region] : regions,
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
    // Seed data for Philippines + nearby SEA countries.
    const regions = <String>[
      'philippines',
      'indonesia',
      'vietnam',
      'thailand',
      'malaysia',
    ];

    return const [
      CropSeasonItem(name: 'Rice', seasons: ['Wet Season'], regions: regions),
      CropSeasonItem(name: 'Corn', seasons: ['Dry Season'], regions: regions),
      CropSeasonItem(name: 'Tomato', seasons: ['Year Round'], regions: regions),
      CropSeasonItem(name: 'Eggplant', seasons: ['Wet Season'], regions: regions),
      CropSeasonItem(name: 'Mung Bean', seasons: ['Dry Season'], regions: regions),
      CropSeasonItem(name: 'Cassava', seasons: ['Year Round'], regions: regions),
      CropSeasonItem(name: 'Banana', seasons: ['Year Round'], regions: regions),
      CropSeasonItem(name: 'Sugarcane', seasons: ['Dry Season'], regions: regions),
      CropSeasonItem(name: 'Coconut', seasons: ['Year Round'], regions: regions),
      CropSeasonItem(name: 'Peanut', seasons: ['Dry Season'], regions: regions),
    ];
  }
}
