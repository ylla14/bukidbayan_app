import 'package:bukidbayan_app/services/agromonitoring_service.dart';
import 'package:bukidbayan_app/services/auth_services.dart' show AuthService;
import 'package:bukidbayan_app/models/crop_preference.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
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
  List<String> _myCrops = const [];
  Set<String> _myToolCategories = const {};
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

  Future<List<String>> _fetchCropPreferences() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return const [];
      final crops = await FirestoreService().getCropPreferences(uid);
      return crops ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<Set<String>> _fetchOwnedToolCategories() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return const {};
      final snapshot = await FirestoreService().getEquipmentByOwner(uid).first;

      final categories = <String>{};
      for (final doc in snapshot.docs) {
        final raw = doc.data();
        if (raw is! Map<String, dynamic>) continue;
        final category = (raw['category'] as String?)?.trim();
        if (category != null && category.isNotEmpty) categories.add(category);
      }
      return categories;
    } catch (_) {
      return const {};
    }
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait<dynamic>([
        WeatherService().getOrFetchForecast(),
        _fetchSoil(),
        _fetchCropPreferences(),
        _fetchOwnedToolCategories(),
      ]);

      final forecast = results[0] as List<WeatherDay>;
      final soil = results[1] as SoilData?;
      final myCrops = results[2] as List<String>;
      final myTools = results[3] as Set<String>;

      if (forecast.isEmpty) {
        if (mounted) {
          setState(() {
            _soil = soil;
            _myCrops = myCrops;
            _myToolCategories = myTools;
            _loading = false;
          });
        }
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

      if (mounted) {
        setState(() {
          _today = today;
          _soil = soil;
          _myCrops = myCrops;
          _myToolCategories = myTools;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _moistureLabel(double pct) {
    if (pct < 20) return 'Dry soil';
    if (pct <= 40) return 'Good moisture';
    return 'Muddy / Wet';
  }

  String _seasonForMonth(int month) {
    return (month >= 6 && month <= 11) ? 'Wet Season' : 'Dry Season';
  }

  double _temperatureScore(double tempC) {
    if (tempC >= 22 && tempC <= 33) return 1.0;
    if (tempC >= 18 && tempC <= 36) return 0.6;
    return 0.2;
  }

  double _rainScore(double rainChancePct) {
    if (rainChancePct <= 35) return 1.0;
    if (rainChancePct <= 60) return 0.6;
    return 0.2;
  }

  double _moistureScore(double moisturePct) {
    if (moisturePct >= 20 && moisturePct <= 40) return 1.0;
    if ((moisturePct >= 15 && moisturePct < 20) ||
        (moisturePct > 40 && moisturePct <= 50)) {
      return 0.6;
    }
    return 0.2;
  }

  String _previewList(Iterable<String> values, {int max = 3}) {
    final list =
        values.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList()
          ..sort();
    if (list.isEmpty) return 'none';
    if (list.length <= max) return list.join(', ');
    return '${list.take(max).join(', ')} +${list.length - max} more';
  }

  _ToolReadinessInsight _buildToolReadinessInsight() {
    final season = _seasonForMonth(DateTime.now().month);
    final signals = <String>[];
    final scores = <double>[];

    if (_today != null) {
      final temp = _today!.tempMaxC;
      final rain = _today!.precipitationProbabilityMax;
      scores.add(_temperatureScore(temp));
      scores.add(_rainScore(rain));

      if (temp >= 35) {
        signals.add('Inaasahang matinding init (${temp.toStringAsFixed(1)}C).');
      } else if (temp <= 20) {
        signals.add('Malamig na kondisyon (${temp.toStringAsFixed(1)}C).');
      } else {
        signals.add('Ang temperatura ay nasa katanggap-tanggap na antas.');
      }

      if (rain >= 70) {
        signals.add(
          'Mataas na tsansa ng ulan (${rain.round()}%) na maaaring makasagabal sa trabaho sa bukid.',
        );
      } else if (rain >= 45) {
        signals.add(
          'Katamtamang tsansa ng ulan (${rain.round()}%) - mag-ingat sa pagpaplano.',
        );
      } else {
        signals.add('Ang tsansa ng ulan ay medyo mababa (${rain.round()}%).');
      }
    } else {
      signals.add('Hindi available ang weather forecast sa ngayon.');
    }

    if (_soil != null) {
      final moisture = _soil!.moisturePct;
      scores.add(_moistureScore(moisture));
      if (moisture > 40) {
        signals.add('Maputik ang lupa (${moisture.toStringAsFixed(1)}%).');
      } else if (moisture < 20) {
        signals.add('Tuyo ang lupa (${moisture.toStringAsFixed(1)}%).');
      } else {
        signals.add('Ang moisture ng lupa ay nasa angkop na antas.');
      }
    } else {
      signals.add('Hindi available ang datos ng kahalumigmigan ng lupa (walang farm polygon).');
    }

    final readinessScore = scores.isEmpty
        ? 50
        : ((scores.reduce((a, b) => a + b) / scores.length) * 100).round();

    if (_myCrops.isEmpty) {
      return _ToolReadinessInsight(
        statusLabel: 'Kailangang i-setup',
        statusColor: Colors.blueGrey,
        statusIcon: Icons.info_outline_rounded,
        season: season,
        headline: 'Idagdag ang iyong mga pananim para ma-unlock ang mga insight sa timing ng kagamitan.',
        summary:
            'Itakda ang iyong mga pananim sa seksyon ng Mga Pananim sa Panahon para makatugma sa iyong bukid.',
        signals: signals,
      );
    }

    final recommended = recommendedToolTypes(_myCrops);
    final matchingTools = _myToolCategories.intersection(recommended);

    if (_myToolCategories.isEmpty) {
      return _ToolReadinessInsight(
        statusLabel: 'Walang kagamitan',
        statusColor: Colors.orange,
        statusIcon: Icons.build_circle_outlined,
        season: season,
        headline: 'Wala pang nahanap na kategorya ng kagamitan.',
        summary:
            'Para sa iyong mga pananim (${_previewList(_myCrops)}), kasama sa mga inirerekomendang kagamitan ang ${_previewList(recommended)}.',
        signals: signals,
      );
    }

    if (matchingTools.isEmpty) {
      return _ToolReadinessInsight(
        statusLabel: 'Walang tugma',
        statusColor: Colors.orange,
        statusIcon: Icons.link_off_rounded,
        season: season,
        headline: 'Ang mga kasalukuyang kagamitan ay hindi direktang tugma sa iyong mga pananim.',
        summary:
            'Iyong mga pananim: ${_previewList(_myCrops)}. Mga kagamitan: ${_previewList(_myToolCategories)}. Mungkahi: ${_previewList(recommended)}.',
        signals: signals,
      );
    }

    if (readinessScore >= 75) {
      return _ToolReadinessInsight(
        statusLabel: 'Magandang oras',
        statusColor: Colors.green,
        statusIcon: Icons.check_circle_rounded,
        season: season,
        headline: 'Mukhang magandang pagkakataon para gamitin ang iyong mga naitugmang kagamitan.',
        summary:
            'Mga naitugmang kagamitan para sa iyong mga pananim (${_previewList(_myCrops)}): ${_previewList(matchingTools)}.',
        signals: signals,
      );
    }

    if (readinessScore >= 50) {
      return _ToolReadinessInsight(
        statusLabel: 'Mag-ingat',
        statusColor: Colors.orange,
        statusIcon: Icons.warning_amber_rounded,
        season: season,
        headline: 'Maaari kang magpatuloy, ngunit kailangan ng pag-iingat sa kondisyon ng bukid.',
        summary:
            'Mga naitugmang kagamitan: ${_previewList(matchingTools)}. Subaybayan ang panahon at lupa bago gamitin.',
        signals: signals,
      );
    }

    return _ToolReadinessInsight(
      statusLabel: 'Hindi angkop',
      statusColor: Colors.red,
      statusIcon: Icons.cancel_rounded,
      season: season,
      headline: 'Hindi ito ang pinakamainam na pagkakataon para gamitin ang mga kagamitan.',
      summary:
          'May mga naitugmang kagamitan (${_previewList(matchingTools)}), ngunit ang kondisyon ay peligroso sa ngayon.',
      signals: signals,
    );
  }

  Widget _buildInsightPanel(_ToolReadinessInsight insight) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: insight.statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: insight.statusColor.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(insight.statusIcon, color: insight.statusColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tool Readiness Insights',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: insight.statusColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  insight.statusLabel,
                  style: TextStyle(
                    color: insight.statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insight.headline,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(insight.summary, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Text(
            'Panahon: ${insight.season}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          ...insight.signals
              .take(3)
              .map(
                (signal) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, size: 7, color: insight.statusColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          signal,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 110,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final tempValue = _today != null ? '${_today!.tempMaxC.round()}°C' : '--°C';
    final rainValue = _today != null
        ? '${_today!.precipitationProbabilityMax.round()}%'
        : '--%';
    final tempLabel = _today != null
        ? (_today!.tempMaxC >= 35
              ? 'Napakaainit'
              : _today!.tempMaxC >= 30
              ? 'Mainit'
              : 'Komportable')
        : 'No data';
    final rainLabel = _today?.description ?? 'No data';

    final hasSoil = _soil != null;
    final moistureValue = hasSoil ? '${_soil!.moisturePct.round()}%' : '--';
    final moistureLabel = hasSoil
        ? _moistureLabel(_soil!.moisturePct)
        : 'Walang nairehistrong bukid';
    final isMuddy = hasSoil && _soil!.isMuddy;
    final insight = _buildToolReadinessInsight();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              DashboardSummaryCard(
                icon: Icons.thermostat,
                title: 'Temperatura',
                value: tempValue,
                subtitle: tempLabel,
                backgroundColor: const Color(0xFFFFF3E0),
                iconColor: Colors.deepOrange,
              ),
              const SizedBox(width: 12),
              DashboardSummaryCard(
                icon: Icons.water_drop,
                title: 'Tsansa ng Ulan',
                value: rainValue,
                subtitle: rainLabel,
                backgroundColor: const Color(0xFFE3F2FD),
                iconColor: Colors.blue,
              ),
              const SizedBox(width: 12),
              DashboardSummaryCard(
                icon: isMuddy
                    ? Icons.warning_amber_rounded
                    : Icons.grass_rounded,
                title: 'Moisture ng Lupa',
                value: moistureValue,
                subtitle: moistureLabel,
                backgroundColor: isMuddy
                    ? const Color(0xFFFFEBEE)
                    : const Color(0xFFE8F5E9),
                iconColor: isMuddy
                    ? Colors.red
                    : (hasSoil ? Colors.green : Colors.grey),
              ),
            ],
          ),
        ),
        _buildInsightPanel(insight),
      ],
    );
  }
}

class _ToolReadinessInsight {
  final String statusLabel;
  final Color statusColor;
  final IconData statusIcon;
  final String season;
  final String headline;
  final String summary;
  final List<String> signals;

  const _ToolReadinessInsight({
    required this.statusLabel,
    required this.statusColor,
    required this.statusIcon,
    required this.season,
    required this.headline,
    required this.summary,
    required this.signals,
  });
}
