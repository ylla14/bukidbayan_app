// ── NDVI Card ─────────────────────────────────────────────────────────────────
// Looks up the renter's registered farm polygon and fetches the latest NDVI
// reading from Agromonitoring. Renders nothing if no polygon is registered.

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
  NdviReading? _latest;
  bool _noPolygon = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNdvi();
  }

  Future<void> _loadNdvi() async {
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
      final readings = await _agroService.fetchNdvi(polygonId);
      setState(() {
        _latest = readings.isNotEmpty ? readings.first : null;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
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
    // Nothing to show when no polygon was registered or still loading.
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
          // ── Header ───────────────────────────────────────────────────────
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
                  'FARM SATELLITE DATA',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.satellite_alt_rounded,
                    size: 16, color: Colors.black38),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
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

    if (_error != null) {
      return Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: Colors.black38),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Could not load satellite data',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
        ],
      );
    }

    if (_latest == null) {
      return Row(
        children: [
          const Icon(Icons.cloud_rounded, size: 18, color: Colors.black38),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No recent clear-sky imagery available',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ),
        ],
      );
    }

    final r = _latest!;
    final ndviColor = _ndviColor(r.mean);
    final barWidth = (r.mean.clamp(0.0, 1.0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── NDVI gauge row ──────────────────────────────────────────────
        Row(
          children: [
            // Big NDVI number
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
                  // Progress bar
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
        const Divider(height: 1),
        const SizedBox(height: 10),

        // ── Meta row ────────────────────────────────────────────────────
        Row(
          children: [
            _metaChip(
              Icons.calendar_today_rounded,
              DateFormat('MMM dd, yyyy').format(r.date),
            ),
            const SizedBox(width: 8),
            _metaChip(Icons.satellite_alt_rounded, r.source),
          ],
        ),

        const SizedBox(height: 10),

        // ── Legend hint ─────────────────────────────────────────────────
        Text(
          'NDVI ranges from 0 (bare soil) to 1 (dense vegetation). '
          'Values above 0.5 indicate healthy, actively growing crops.',
          style: TextStyle(fontSize: 11, color: Colors.grey[500], height: 1.4),
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
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}