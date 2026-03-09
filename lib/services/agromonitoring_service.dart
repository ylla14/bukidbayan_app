import 'dart:convert';
import 'package:http/http.dart' as http;

/// A single NDVI reading from the Agromonitoring API.
class NdviReading {
  final DateTime date;
  final double mean;
  final double? median;
  final String source;

  /// Data coverage percentage (0–100). High values mean clear sky.
  final double dataCoverage;

  /// Cloud coverage percentage (0–100). Low values are better.
  final double cloudCoverage;

  NdviReading({
    required this.date,
    required this.mean,
    this.median,
    required this.source,
    required this.dataCoverage,
    required this.cloudCoverage,
  });

  factory NdviReading.fromMap(Map<String, dynamic> map) {
    final data = map['data'] as Map<String, dynamic>? ?? {};
    return NdviReading(
      date: DateTime.fromMillisecondsSinceEpoch((map['dt'] as int) * 1000),
      mean: (data['mean'] as num?)?.toDouble() ?? 0.0,
      median: (data['median'] as num?)?.toDouble(),
      source: map['source'] as String? ?? 'Unknown',
      dataCoverage: (map['dc'] as num?)?.toDouble() ?? 0.0,
      cloudCoverage: (map['cl'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Human-readable crop health label based on NDVI mean value.
  String get healthLabel {
    if (mean < 0.1) return 'No Vegetation / Water';
    if (mean < 0.2) return 'Bare Soil';
    if (mean < 0.35) return 'Sparse Vegetation';
    if (mean < 0.5) return 'Moderate Vegetation';
    if (mean < 0.65) return 'Healthy Crops';
    return 'Dense / Mature Crops';
  }
}

class AgromonitoringService {
  static const String _apiKey = 'c29d38bbd0b5c57c78ffde8ccfc963da';
  static const String _baseUrl = 'https://api.agromonitoring.com/agro/1.0';

  /// Creates a small bounding polygon (~111m radius) around [lat]/[lng].
  /// Returns the Agromonitoring polygon ID on success.
  Future<String> createPolygon(double lat, double lng, String name) async {
    const double delta = 0.001; // ≈ 111 m at the equator
    final uri = Uri.parse('$_baseUrl/polygons?appid=$_apiKey');

    final body = jsonEncode({
      'name': name,
      'geo_json': {
        'type': 'Feature',
        'properties': {},
        'geometry': {
          'type': 'Polygon',
          'coordinates': [
            [
              [lng - delta, lat - delta],
              [lng + delta, lat - delta],
              [lng + delta, lat + delta],
              [lng - delta, lat + delta],
              [lng - delta, lat - delta], // close the ring
            ]
          ],
        },
      },
    });

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      throw Exception(
          'Failed to create farm polygon (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['id'] as String;
  }

  /// Fetches NDVI readings for [polygonId] over the last [days] days.
  /// Readings with >50% cloud coverage are filtered out.
  /// Results are sorted newest-first.
  Future<List<NdviReading>> fetchNdvi(String polygonId, {int days = 60}) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: days));
    final dtstart = start.millisecondsSinceEpoch ~/ 1000;
    final dtend = now.millisecondsSinceEpoch ~/ 1000;

    final uri = Uri.parse(
      '$_baseUrl/ndvi/polygon'
      '?polyid=$polygonId'
      '&appid=$_apiKey'
      '&dtstart=$dtstart'
      '&dtend=$dtend',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to fetch NDVI data (${response.statusCode}): ${response.body}');
    }

    final List<dynamic> list = jsonDecode(response.body);
    return list
        .map((e) => NdviReading.fromMap(e as Map<String, dynamic>))
        .where((r) => r.cloudCoverage < 50) // skip cloudy readings
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // newest first
  }
}
