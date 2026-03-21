import 'dart:convert';

import 'package:http/http.dart' as http;

class CropSeasonItem {
  final String name;
  final List<String> seasons;
  final List<String> regions;
  final String? imageUrl; 

  const CropSeasonItem({
    required this.name,
    required this.seasons,
    required this.regions,
    this.imageUrl,
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

      // Added 5-second timeout to prevent infinite loading spinners
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
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
      // --- Integrated Lowland Crops from Agricultural Data ---
      
      // Separated Rice into Wet and Dry seasons
      CropSeasonItem(name: 'Rice (Wet Season)', seasons: ['Wet Season'], regions: regions,
        imageUrl: 'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1773064316/rice_eix9px.jpg'),
      CropSeasonItem(name: 'Rice (Dry Season)', seasons: ['Dry Season'], regions: regions,
        imageUrl: 'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1773064316/rice_eix9px.jpg'),
        
      CropSeasonItem(name: 'White Corn', seasons: ['Year Round'], regions: regions,
        imageUrl: 'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1773064316/corn_d6al6c.jpg'),
      CropSeasonItem(name: 'Squash', seasons: ['Dry Season'], regions: regions,
        imageUrl: 'https://images.unsplash.com/photo-1570586437263-ab629fccc818?auto=format&fit=crop&w=500&q=80'),
      CropSeasonItem(name: 'Pechay', seasons: ['Year Round'], regions: regions,
        imageUrl: 'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1774103775/pechay_mosaey.jpg'),
      CropSeasonItem(name: 'Upo (Bottle Gourd)', seasons: ['Year Round'], regions: regions,
        imageUrl: 'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1774103775/upo_w1l52q.jpg'),
      CropSeasonItem(name: 'Eggplant', seasons: ['Year Round'], regions: regions, 
        imageUrl: 'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1773064315/eggplant_mnxhhf.jpg'),
      CropSeasonItem(name: 'Tomato', seasons: ['Dry Season'], regions: regions, 
        imageUrl: 'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1773064317/tomato_vycvfc.jpg'),
      CropSeasonItem(name: 'Watermelon', seasons: ['Dry Season'], regions: regions,
        imageUrl: 'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1774103776/watermelon_squ5ma.jpg'),
      CropSeasonItem(name: 'Banana', seasons: ['Year Round'], regions: regions,
        imageUrl: 'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1773064315/banana_m4uiy8.jpg'),
        
      // --- Original Crops preserved ---
      // CropSeasonItem(name: 'Mung Bean', seasons: ['Dry Season'], regions: regions,
      //   imageUrl: 'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1773064317/mungbean_skpwcu.jpg'),
      // CropSeasonItem(name: 'Cassava', seasons: ['Year Round'], regions: regions,
      //   imageUrl: 'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1773064315/cassava_ujjade.jpg'),
      // CropSeasonItem(name: 'Sugarcane', seasons: ['Dry Season'], regions: regions,
      //   imageUrl: 'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1773064317/sugarcane_c3ucmj.jpg'),
      // CropSeasonItem(name: 'Coconut', seasons: ['Year Round'], regions: regions,
      //   imageUrl: 'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1773064315/coconut_ewh9w7.jpg'),
      // CropSeasonItem(name: 'Peanut', seasons: ['Dry Season'], regions: regions,
      //   imageUrl: 'https://res.cloudinary.com/ddgxxpdt9/image/upload/v1773064316/peanut_jok3iv.jpg'),
    ];
  }
}