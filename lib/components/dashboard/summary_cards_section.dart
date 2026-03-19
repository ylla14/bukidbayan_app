import 'package:bukidbayan_app/services/agromonitoring_service.dart';
import 'package:bukidbayan_app/services/auth_services.dart' show AuthService;
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/services/weather_service.dart';
import 'package:bukidbayan_app/widgets/dashboard_summary_card.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SummaryCardsSection extends StatefulWidget {
  const SummaryCardsSection({super.key});

  @override
  State<SummaryCardsSection> createState() => _SummaryCardsSectionState();
}

class _SummaryCardsSectionState extends State<SummaryCardsSection> {
  WeatherDay? _today;
  SoilData? _soil;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<SoilData?> _fetchSoil() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;
      final userData = await AuthService().getUserData(uid);
      final polygonId = userData?['farmPolygonId'] as String?;
      if (polygonId == null) return null;
      return await AgromonitoringService().fetchSoil(polygonId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait<dynamic>([
        WeatherService().getOrFetchForecast(),
        _fetchSoil(),
      ]);

      final forecast = results[0] as List<WeatherDay>;
      final soil = results[1] as SoilData?;

      if (forecast.isEmpty) {
        if (mounted) setState(() { _soil = soil; _loading = false; });
        return;
      }

      final now = DateTime.now();
      final today = forecast.firstWhere(
        (d) =>
            d.date.year == now.year &&
            d.date.month == now.month &&
            d.date.day == now.day,
        orElse: () => forecast[0],
      );

      if (mounted) setState(() { _today = today; _soil = soil; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _moistureLabel(double pct) {
    if (pct < 20) return 'Dry soil';
    if (pct <= 40) return 'Good moisture';
    return 'Muddy / Wet';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 110,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final tempValue  = _today != null ? '${_today!.tempMaxC.round()}°C' : '--°C';
    final rainValue  = _today != null ? '${_today!.precipitationProbabilityMax.round()}%' : '--%';
    final tempLabel  = _today != null
        ? (_today!.tempMaxC >= 35 ? 'Feels very hot' : _today!.tempMaxC >= 30 ? 'Feels hot' : 'Comfortable')
        : 'No data';
    final rainLabel  = _today?.description ?? 'No data';

    final hasSoil       = _soil != null;
    final moistureValue = hasSoil ? '${_soil!.moisturePct.round()}%' : '--';
    final moistureLabel = hasSoil ? _moistureLabel(_soil!.moisturePct) : 'No farm registered';
    final isMuddy       = hasSoil && _soil!.isMuddy;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          DashboardSummaryCard(
            icon: Icons.thermostat,
            title: 'Temperature',
            value: tempValue,
            subtitle: tempLabel,
            backgroundColor: const Color(0xFFFFF3E0),
            iconColor: Colors.deepOrange,
          ),
          const SizedBox(width: 12),
          DashboardSummaryCard(
            icon: Icons.water_drop,
            title: 'Rain Chance',
            value: rainValue,
            subtitle: rainLabel,
            backgroundColor: const Color(0xFFE3F2FD),
            iconColor: Colors.blue,
          ),
          const SizedBox(width: 12),
          DashboardSummaryCard(
            icon: isMuddy ? Icons.warning_amber_rounded : Icons.grass_rounded,
            title: 'Soil Moisture',
            value: moistureValue,
            subtitle: moistureLabel,
            backgroundColor: isMuddy ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
            iconColor: isMuddy ? Colors.red : (hasSoil ? Colors.green : Colors.grey),
          ),
        ],
      ),
    );
  }
}
