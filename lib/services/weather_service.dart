import 'dart:convert';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

// ── Model ──────────────────────────────────────────────────────────────────

/// One day's forecast data from Open-Meteo (daily aggregates).
class WeatherDay {
  final DateTime date;
  final int weatherCode;
  final double precipitationMm;
  final double windSpeedMaxKmh;
  final double precipitationProbabilityMax;
  final double tempMaxC;

  const WeatherDay({
    required this.date,
    required this.weatherCode,
    required this.precipitationMm,
    required this.windSpeedMaxKmh,
    required this.precipitationProbabilityMax,
    required this.tempMaxC,
  });

  /// True when conditions cross thresholds for severe weather.
  /// Thresholds:
  ///   - WMO codes 65/67 (heavy rain), 82 (heavy showers), 95/96/99 (thunderstorm)
  ///   - ≥20 mm precipitation (PAGASA "heavy rainfall" level)
  ///   - ≥60 km/h wind (strong wind advisory level)
  bool get isBadWeather {
    const badCodes = {65, 67, 82, 95, 96, 99};
    return badCodes.contains(weatherCode) ||
        precipitationMm >= 20.0 ||
        windSpeedMaxKmh >= 60.0;
  }

  /// Human-readable description from WMO weather code.
  String get description {
    if (weatherCode == 0) return 'Clear sky';
    if (weatherCode <= 3) return 'Partly cloudy';
    if (weatherCode <= 48) return 'Foggy';
    if (weatherCode <= 57) return 'Drizzle';
    if (weatherCode <= 67) return 'Rainy';
    if (weatherCode <= 82) return 'Showers';
    if (weatherCode <= 99) return 'Thunderstorm';
    return 'Cloudy';
  }

  Map<String, dynamic> toMap() => {
        'date': Timestamp.fromDate(date),
        'weatherCode': weatherCode,
        'precipitationMm': precipitationMm,
        'windSpeedMaxKmh': windSpeedMaxKmh,
        'precipitationProbabilityMax': precipitationProbabilityMax,
        'tempMaxC': tempMaxC,
      };

  factory WeatherDay.fromMap(Map<String, dynamic> map) => WeatherDay(
        date: (map['date'] as Timestamp).toDate(),
        weatherCode: (map['weatherCode'] as num).toInt(),
        precipitationMm: (map['precipitationMm'] as num).toDouble(),
        windSpeedMaxKmh: (map['windSpeedMaxKmh'] as num).toDouble(),
        precipitationProbabilityMax:
            (map['precipitationProbabilityMax'] as num).toDouble(),
        tempMaxC: (map['tempMaxC'] as num).toDouble(),
      );
}

// ── Service ────────────────────────────────────────────────────────────────

class WeatherService {
  // Cabuyao, Laguna — matches the app's base of operations
  static const double _lat = 14.2471;
  static const double _lng = 121.1367;

  // Re-fetch at most once every 6 hours.
  static const Duration _cacheTtl = Duration(hours: 6);

  final _firestore = FirebaseFirestore.instance;

  DocumentReference get _cacheDoc =>
      _firestore.collection('system').doc('weatherCache');

  CollectionReference get _requests =>
      _firestore.collection('rentRequests');

  CollectionReference _userNotifs(String userId) =>
      _firestore.collection('notifications').doc(userId).collection('items');

  // ── Cache helpers ────────────────────────────────────────────────────────

  Future<bool> _cacheIsStale() async {
    try {
      final doc = await _cacheDoc.get();
      if (!doc.exists) return true;
      final data = doc.data() as Map<String, dynamic>?;
      final lastChecked = (data?['lastChecked'] as Timestamp?)?.toDate();
      if (lastChecked == null) return true;
      return DateTime.now().difference(lastChecked) > _cacheTtl;
    } catch (_) {
      return true;
    }
  }

  Future<List<WeatherDay>?> _loadFromCache() async {
    try {
      final doc = await _cacheDoc.get();
      if (!doc.exists) return null;
      final data = doc.data() as Map<String, dynamic>?;
      final list = data?['forecast'] as List<dynamic>?;
      if (list == null) return null;
      return list
          .map((e) => WeatherDay.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveToCache(List<WeatherDay> forecast) async {
    await _cacheDoc.set({
      'lastChecked': FieldValue.serverTimestamp(),
      'forecast': forecast.map((d) => d.toMap()).toList(),
    });
  }

  // ── Open-Meteo fetch ─────────────────────────────────────────────────────

  Future<List<WeatherDay>> _fetchFromApi() async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$_lat'
      '&longitude=$_lng'
      '&daily=weather_code,precipitation_sum,wind_speed_10m_max'
      ',precipitation_probability_max,temperature_2m_max'
      '&timezone=Asia%2FManila'
      '&forecast_days=7',
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Weather API error: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final daily = body['daily'] as Map<String, dynamic>;

    final dates = daily['time'] as List<dynamic>;
    final codes = daily['weather_code'] as List<dynamic>;
    final precip = daily['precipitation_sum'] as List<dynamic>;
    final wind = daily['wind_speed_10m_max'] as List<dynamic>;
    final prob = daily['precipitation_probability_max'] as List<dynamic>;
    final temp = daily['temperature_2m_max'] as List<dynamic>;

    return List.generate(dates.length, (i) {
      final parts = (dates[i] as String).split('-');
      return WeatherDay(
        date: DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        ),
        weatherCode: (codes[i] as num).toInt(),
        precipitationMm: (precip[i] as num?)?.toDouble() ?? 0.0,
        windSpeedMaxKmh: (wind[i] as num?)?.toDouble() ?? 0.0,
        precipitationProbabilityMax: (prob[i] as num?)?.toDouble() ?? 0.0,
        tempMaxC: (temp[i] as num?)?.toDouble() ?? 0.0,
      );
    });
  }

  // ── Public API ───────────────────────────────────────────────────────────

  /// Returns the 7-day forecast, using Firestore cache when fresh (< 6 h old).
  /// Safe to call concurrently — whichever client runs first populates the
  /// cache and subsequent calls within the TTL window just read it.
  Future<List<WeatherDay>> getOrFetchForecast() async {
    if (!await _cacheIsStale()) {
      final cached = await _loadFromCache();
      if (cached != null) return cached;
    }
    final forecast = await _fetchFromApi();
    await _saveToCache(forecast);
    return forecast;
  }

  /// Full weather check: fetch forecast → flag affected rentRequests →
  /// write in-app notifications.
  ///
  /// Safe to call fire-and-forget from app startup. Errors are swallowed
  /// so a weather API outage never breaks the rest of the app.
  Future<void> runWeatherCheck() async {
    try {
      final forecast = await getOrFetchForecast();
      await _flagAffectedRequests(forecast);
    } catch (_) {
      // Silently ignore — weather check is best-effort
    }
  }

  // ── Flagging ─────────────────────────────────────────────────────────────

  static const _activeStatuses = [
    'pending',
    'approved',
    'onTheWay',
    'inProgress',
  ];

  Future<void> _flagAffectedRequests(List<WeatherDay> forecast) async {
    final badDays = forecast.where((d) => d.isBadWeather).toList();

    final snapshot = await _requests
        .where('status', whereIn: _activeStatuses)
        .get();

    for (final doc in snapshot.docs) {
      final request = RentRequest.fromDoc(doc);

      final reqStart =
          DateTime(request.start.year, request.start.month, request.start.day);
      final reqEnd =
          DateTime(request.end.year, request.end.month, request.end.day);

      final affected = badDays.where((d) {
        final day = DateTime(d.date.year, d.date.month, d.date.day);
        return !day.isBefore(reqStart) && !day.isAfter(reqEnd);
      }).toList();

      if (affected.isNotEmpty) {
        await doc.reference.update({
          'weatherFlag': true,
          'weatherFlagDates': affected
              .map((d) => Timestamp.fromDate(d.date))
              .toList(),
          'weatherFlagUpdatedAt': FieldValue.serverTimestamp(),
        });
        await _upsertWeatherNotification(request, affected);
      } else {
        // Weather has cleared for this booking's dates — remove the flag.
        await doc.reference.update({
          'weatherFlag': false,
          'weatherFlagDates': <Timestamp>[],
          'weatherFlagUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  Future<void> _upsertWeatherNotification(
    RentRequest request,
    List<WeatherDay> affectedDays,
  ) async {
    final dateStr = affectedDays
        .map((d) => '${d.date.month}/${d.date.day}')
        .join(', ');

    final body =
        'Severe weather expected on $dateStr. Your booking for '
        '"${request.itemName}" may be affected. Please coordinate with the '
        '${_isRenter(request) ? "owner" : "renter"} to reschedule.';

    final data = {
      'type': 'weather_alert',
      'requestId': request.requestId,
      'itemName': request.itemName,
      'title': 'Weather Alert — ${request.itemName}',
      'body': body,
      'affectedDates': affectedDays
          .map((d) => Timestamp.fromDate(d.date))
          .toList(),
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    };

    // Use a stable document ID so we upsert, not spam.
    final docId = 'weather_${request.requestId}';
    await _upsertNotif(request.renterId, docId, data);
    await _upsertNotif(request.ownerId, docId, data);
  }

  Future<void> _upsertNotif(
    String userId,
    String docId,
    Map<String, dynamic> data,
  ) async {
    final ref = _userNotifs(userId).doc(docId);
    final existing = await ref.get();
    if (!existing.exists) {
      await ref.set(data);
    } else {
      await ref.update({
        'body': data['body'],
        'affectedDates': data['affectedDates'],
        'updatedAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    }
  }

  // Placeholder — the service doesn't know the current user; this is used
  // only for the notification body text direction.
  bool _isRenter(RentRequest r) => true;

  // ── Debug / testing helpers ───────────────────────────────────────────────

  /// Writes a mock forecast to the Firestore cache where every day in [dates]
  /// is marked as severe weather (thunderstorm + heavy rain + strong wind),
  /// then immediately runs the full flag-and-notify pass against all active
  /// rentRequests. Days not in [dates] are set to clear weather.
  ///
  /// Call [clearTestWeather] when done to restore real data.
  Future<void> injectTestBadWeather(List<DateTime> dates) async {
    final today = DateTime.now();
    final forecast = List.generate(7, (i) {
      final day = DateTime(today.year, today.month, today.day)
          .add(Duration(days: i));
      final isBad = dates.any(
        (d) => d.year == day.year && d.month == day.month && d.day == day.day,
      );
      return WeatherDay(
        date: day,
        weatherCode: isBad ? 95 : 0,
        precipitationMm: isBad ? 25.0 : 0.0,
        windSpeedMaxKmh: isBad ? 70.0 : 10.0,
        precipitationProbabilityMax: isBad ? 90.0 : 5.0,
        tempMaxC: 28.0,
      );
    });
    await _saveToCache(forecast);
    await _flagAffectedRequests(forecast);
  }

  /// Deletes the mock cache (so the next app open re-fetches real data from
  /// Open-Meteo) and clears all weather flags on active rentRequests.
  Future<void> clearTestWeather() async {
    await _cacheDoc.delete();
    // Pass an empty forecast → _flagAffectedRequests sees no bad days →
    // every active booking has its weatherFlag set back to false.
    await _flagAffectedRequests([]);
  }
}
