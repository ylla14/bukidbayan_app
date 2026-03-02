import 'package:flutter/material.dart';
import 'package:bukidbayan_app/services/weather_service.dart';
import 'package:bukidbayan_app/widgets/dashboard_summary_card.dart';

class SummaryCardsSection extends StatefulWidget {
  const SummaryCardsSection({super.key});

  @override
  State<SummaryCardsSection> createState() => _SummaryCardsSectionState();
}

class _SummaryCardsSectionState extends State<SummaryCardsSection> {
  WeatherDay? _today;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    try {
      final forecast = await WeatherService().getOrFetchForecast();
      final now = DateTime.now();
      final today = forecast.firstWhere(
        (d) =>
            d.date.year == now.year &&
            d.date.month == now.month &&
            d.date.day == now.day,
        orElse: () => forecast.first,
      );
      if (mounted) setState(() { _today = today; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
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
    final windValue  = _today != null ? '${_today!.windSpeedMaxKmh.round()} km/h' : '--';
    final isBad      = _today?.isBadWeather ?? false;
    final tempLabel  = _today != null
        ? (_today!.tempMaxC >= 35 ? 'Feels very hot' : _today!.tempMaxC >= 30 ? 'Feels hot' : 'Comfortable')
        : 'No data';
    final rainLabel  = _today?.description ?? 'No data';
    final windLabel  = isBad ? 'Strong winds warning' : 'Calm winds';

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
            icon: isBad ? Icons.warning_amber_rounded : Icons.air,
            title: 'Wind Speed',
            value: windValue,
            subtitle: windLabel,
            backgroundColor: isBad ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
            iconColor: isBad ? Colors.red : Colors.green,
          ),
        ],
      ),
    );
  }
}
