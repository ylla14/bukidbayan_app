import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Real-time soil data from the Agromonitoring soil API.
class SoilData {
  /// Surface temperature in °C.
  final double surfaceTempC;

  /// Temperature at 10 cm depth in °C.
  final double depthTempC;

  /// Volumetric soil moisture as a percentage (0–100).
  final double moisturePct;

  SoilData({
    required this.surfaceTempC,
    required this.depthTempC,
    required this.moisturePct,
  });

  factory SoilData.fromMap(Map<String, dynamic> map) {
    final t0 = (map['t0'] as num?)?.toDouble() ?? 273.15;
    final t10 = (map['t10'] as num?)?.toDouble() ?? 273.15;
    final moisture = (map['moisture'] as num?)?.toDouble() ?? 0.0;
    return SoilData(
      surfaceTempC: t0 - 273.15,
      depthTempC: t10 - 273.15,
      moisturePct: moisture * 100,
    );
  }

  /// True when moisture suggests muddy / waterlogged conditions.
  bool get isMuddy => moisturePct > 40;
}

/// Current weather at the farm location, fetched from Open-Meteo.
class FarmWeather {
  final double temperatureC;
  final int humidityPct;
  final double windSpeedKmh;
  final double precipitationMm;

  /// WMO weather interpretation code.
  final int weatherCode;

  FarmWeather({
    required this.temperatureC,
    required this.humidityPct,
    required this.windSpeedKmh,
    required this.precipitationMm,
    required this.weatherCode,
  });

  factory FarmWeather.fromMap(Map<String, dynamic> current) {
    return FarmWeather(
      temperatureC: (current['temperature_2m'] as num?)?.toDouble() ?? 0.0,
      humidityPct: (current['relative_humidity_2m'] as num?)?.toInt() ?? 0,
      windSpeedKmh: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0,
      precipitationMm: (current['precipitation'] as num?)?.toDouble() ?? 0.0,
      weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
    );
  }

  String get conditionLabel {
    if (weatherCode == 0) return 'Clear Sky';
    if (weatherCode <= 3) return 'Partly Cloudy';
    if (weatherCode <= 49) return 'Foggy';
    if (weatherCode <= 69) return 'Rain';
    if (weatherCode <= 79) return 'Snow / Sleet';
    if (weatherCode <= 99) return 'Thunderstorm';
    return 'Unknown';
  }

  IconData get conditionIcon {
    if (weatherCode == 0) return Icons.wb_sunny_rounded;
    if (weatherCode <= 3) return Icons.cloud_rounded;
    if (weatherCode <= 49) return Icons.foggy;
    if (weatherCode <= 69) return Icons.umbrella_rounded;
    if (weatherCode <= 79) return Icons.ac_unit_rounded;
    if (weatherCode <= 99) return Icons.thunderstorm_rounded;
    return Icons.help_outline_rounded;
  }
}

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

  /// Fetches real-time soil data (surface temp, 10 cm temp, moisture) for [polygonId].
  Future<SoilData> fetchSoil(String polygonId) async {
    final uri = Uri.parse(
      '$_baseUrl/soil'
      '?polyid=$polygonId'
      '&appid=$_apiKey',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to fetch soil data (${response.statusCode}): ${response.body}');
    }

    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return SoilData.fromMap(map);
  }

  /// Fetches current weather at the given [lat]/[lng] from Open-Meteo (no API key needed).
  Future<FarmWeather> fetchFarmWeather(double lat, double lng) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat'
      '&longitude=$lng'
      '&current=temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m'
      '&wind_speed_unit=kmh',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to fetch weather data (${response.statusCode}): ${response.body}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final current = body['current'] as Map<String, dynamic>;
    return FarmWeather.fromMap(current);
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
