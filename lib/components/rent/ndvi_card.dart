// ── Farm Field Data Card ───────────────────────────────────────────────────────
// Fetches and displays three real-time data streams for the renter's farm:
//   • NDVI   — latest satellite vegetation index (may be days old, free tier)
//   • Soil   — surface temp, 10 cm temp, moisture (real-time, Agromonitoring)
//   • Weather— temperature, humidity, wind, condition (real-time, Open-Meteo)
// Renders nothing if the renter has no registered farm polygon.

import 'package:bukidbayan_app/services/agromonitoring_service.dart';
import 'package:bukidbayan_app/services/auth_services.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NdviCard extends StatefulWidget {
  final String renterId;
  const NdviCard({super.key, required this.renterId});

  @override
  State<NdviCard> createState() => _NdviCardState();
}

class _NdviCardState extends State<NdviCard> {
  final AuthService _authService = AuthService();
  final AgromonitoringService _agroService = AgromonitoringService();

  bool _isLoading = true;

  // NDVI
  NdviReading? _latest;
  bool _noPolygon = false;
  String? _ndviError;

  // Soil
  SoilData? _soil;
  String? _soilError;

  // Weather
  FarmWeather? _weather;
  String? _weatherError;

  @override
  void initState() {
    super.initState();
    _loadFarmData();
  }

  Future<void> _loadFarmData() async {
    try {
      final userData = await _authService.getUserData(widget.renterId);
      final polygonId = userData?['farmPolygonId'] as String?;

      if (polygonId == null) {
        setState(() {
          _noPolygon = true;
          _isLoading = false;
        });
        return;
      }

      final farmLat = (userData?['farmLatitude'] as num?)?.toDouble();
      final farmLng = (userData?['farmLongitude'] as num?)?.toDouble();

      // Run all three fetches concurrently; failures are independent.
      final results = await Future.wait([
        _agroService.fetchNdvi(polygonId).then<NdviReading?>((r) => r.isNotEmpty ? r.first : null).catchError((e) {
          _ndviError = e.toString().replaceAll('Exception: ', '');
          return null;
        }),
        _agroService.fetchSoil(polygonId).then<SoilData?>((s) => s).catchError((e) {
          _soilError = e.toString().replaceAll('Exception: ', '');
          return null;
        }),
        if (farmLat != null && farmLng != null)
          _agroService.fetchFarmWeather(farmLat, farmLng).then<FarmWeather?>((w) => w).catchError((e) {
            _weatherError = e.toString().replaceAll('Exception: ', '');
            return null;
          })
        else
          Future.value(null),
      ]);

      if (!mounted) return;
      setState(() {
        _latest = results[0] as NdviReading?;
        _soil = results[1] as SoilData?;
        _weather = results[2] as FarmWeather?;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ndviError = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Color _ndviColor(double ndvi) {
    if (ndvi < 0.2) return Colors.red.shade400;
    if (ndvi < 0.35) return Colors.orange.shade400;
    if (ndvi < 0.5) return Colors.yellow.shade700;
    if (ndvi < 0.65) return const Color(0xFF4CAF50);
    return const Color(0xFF1B5E20);
  }

  @override
  Widget build(BuildContext context) {
    if (_noPolygon) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'FARM FIELD DATA',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.grass_rounded, size: 16, color: Colors.black38),
              ],
            ),
          ),

          // ── Body ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Soil moisture recommendation banner ─────────────────────────
        if (_soil != null) ...[
          _soilMoistureRecommendation(_soil!),
          const SizedBox(height: 12),
        ],

        // ── Soil section ────────────────────────────────────────────────
        _sectionHeader(Icons.thermostat_rounded, 'SOIL  ·  Real-time'),
        const SizedBox(height: 8),
        _buildSoilSection(),

        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 14),

        // ── Weather section ─────────────────────────────────────────────
        _sectionHeader(Icons.wb_cloudy_outlined, 'WEATHER  ·  Real-time'),
        const SizedBox(height: 8),
        _buildWeatherSection(),

        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 14),

        // ── NDVI section ─────────────────────────────────────────────────
        _sectionHeader(Icons.satellite_alt_rounded, 'NDVI  ·  Satellite (may be delayed)'),
        const SizedBox(height: 8),
        _buildNdviSection(),
      ],
    );
  }

  // ── Soil moisture recommendation ────────────────────────────────────────────

  Widget _soilMoistureRecommendation(SoilData soil) {
    final muddy = soil.isMuddy;
    final pct   = soil.moisturePct.toStringAsFixed(1);

    final bgColor     = muddy ? Colors.red.shade50    : Colors.green.shade50;
    final borderColor = muddy ? Colors.red.shade300   : Colors.green.shade300;
    final iconColor   = muddy ? Colors.red.shade700   : Colors.green.shade700;
    final textColor   = muddy ? Colors.red.shade800   : Colors.green.shade800;
    final icon        = muddy ? Icons.warning_rounded : Icons.check_circle_rounded;
    final message     = muddy
        ? 'Soil moisture is $pct% — the soil is muddy. Machine operation '
          'is not recommended under these conditions.'
        : 'Soil moisture is $pct% — the soil is not muddy. Conditions '
          'are suitable for machine operation.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section header ───────────────────────────────────────────────────────────

  Widget _sectionHeader(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.black38),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.black38,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  // ── Soil section ─────────────────────────────────────────────────────────────

  Widget _buildSoilSection() {
    if (_soilError != null) {
      return _inlineError('Could not load soil data');
    }
    if (_soil == null) {
      return _inlineError('No soil data available');
    }

    final s = _soil!;
    final moistureColor = s.isMuddy ? Colors.red.shade700 : Colors.green.shade700;

    return Row(
      children: [
        Expanded(
          child: _statTile(
            icon: Icons.device_thermostat_rounded,
            iconColor: Colors.red.shade300,
            label: 'Surface Temp',
            value: '${s.surfaceTempC.toStringAsFixed(1)}°C',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            icon: Icons.thermostat_rounded,
            iconColor: Colors.deepOrange.shade300,
            label: '10 cm Depth',
            value: '${s.depthTempC.toStringAsFixed(1)}°C',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            icon: Icons.water_drop_rounded,
            iconColor: moistureColor,
            label: 'Moisture',
            value: '${s.moisturePct.toStringAsFixed(1)}%',
            valueColor: moistureColor,
          ),
        ),
      ],
    );
  }

  // ── Weather section ──────────────────────────────────────────────────────────

  Widget _buildWeatherSection() {
    if (_weatherError != null) {
      return _inlineError('Could not load weather data');
    }
    if (_weather == null) {
      return _inlineError('No weather data available');
    }

    final w = _weather!;

    return Row(
      children: [
        Expanded(
          child: _statTile(
            icon: w.conditionIcon,
            iconColor: Colors.amber.shade600,
            label: w.conditionLabel,
            value: '${w.temperatureC.toStringAsFixed(1)}°C',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            icon: Icons.water_rounded,
            iconColor: Colors.blue.shade300,
            label: 'Humidity',
            value: '${w.humidityPct}%',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            icon: Icons.air_rounded,
            iconColor: Colors.blueGrey,
            label: 'Wind',
            value: '${w.windSpeedKmh.toStringAsFixed(1)} km/h',
          ),
        ),
      ],
    );
  }

  // ── NDVI section ─────────────────────────────────────────────────────────────

  Widget _buildNdviSection() {
    if (_ndviError != null) {
      return _inlineError('Could not load satellite data');
    }

    if (_latest == null) {
      return _inlineError('No recent clear-sky imagery available');
    }

    final r = _latest!;
    final ndviColor = _ndviColor(r.mean);
    final barWidth = r.mean.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Big NDVI number + health label + bar
        Row(
          children: [
            Text(
              r.mean.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: ndviColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.healthLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ndviColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: barWidth,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(ndviColor),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('0', style: TextStyle(fontSize: 10, color: Colors.black38)),
                      Text('1', style: TextStyle(fontSize: 10, color: Colors.black38)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Date + source chips
        Row(
          children: [
            _metaChip(Icons.calendar_today_rounded, DateFormat('MMM dd, yyyy').format(r.date)),
            const SizedBox(width: 8),
            _metaChip(Icons.satellite_alt_rounded, r.source),
          ],
        ),

        const SizedBox(height: 10),

        Text(
          'NDVI ranges from 0 (bare soil) to 1 (dense vegetation). '
          'Values above 0.5 indicate healthy, actively growing crops.',
          style: TextStyle(fontSize: 11, color: Colors.grey[500], height: 1.4),
        ),
      ],
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────────

  Widget _statTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: valueColor ?? Colors.black87,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.black45),
          ),
        ],
      ),
    );
  }

  Widget _inlineError(String message) {
    return Row(
      children: [
        const Icon(Icons.cloud_off_rounded, size: 16, color: Colors.black38),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
      ],
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.black45),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}
