import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Displays "Farmers Served", "Hectares Covered", and "Total Rentals"
/// for a single equipment listing.
///
/// Counts ALL terminal-status requests so nothing is missed:
///   returned → finished → completed (plus the older "returned" mid-flow step)
class CommunityImpactBar extends StatelessWidget {
  final String equipmentId;

  const CommunityImpactBar({super.key, required this.equipmentId});

  // Every status that means "this rental actually happened / wrapped up".
  // Firestore whereIn supports up to 30 values so this is fine.
  static const _doneStatuses = [
    'finished',   // owner marked job done
    'completed',  // renter confirmed completion
  ];

  Future<Map<String, dynamic>> _fetchImpact() async {
    // Firestore whereIn max is 10 per clause, but we only have 3 so one query suffices.
    final snap = await FirebaseFirestore.instance
        .collection('rentRequests')
        .where('itemId', isEqualTo: equipmentId)
        .where('status', whereIn: _doneStatuses)
        .get();

    final docs = snap.docs;

    // Use a Set so the same farmer renting 5× still counts as 1 farmer served.
    final uniqueRenters = <String>{};
    double totalHectares = 0.0;

    for (final doc in docs) {
      final data = doc.data();

      final renterId = data['renterId'] as String?;
      if (renterId != null) uniqueRenters.add(renterId);

      // hectaresEntered is only filled for tractor-type bookings; 0 elsewhere.
      totalHectares +=
          (data['hectaresEntered'] as num?)?.toDouble() ?? 0.0;
    }

    return {
      'farmersServed': uniqueRenters.length,
      'hectaresCovered': totalHectares,
      'totalRentals': docs.length, // raw transaction count (same farmer = multiple)
    };
  }

  static Widget _divider() => Container(
        width: 1,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        color: Colors.black12,
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchImpact(),
      builder: (context, snap) {
        final farmersServed = (snap.data?['farmersServed'] as int?) ?? 0;
        final hectares      = (snap.data?['hectaresCovered'] as double?) ?? 0.0;
        final totalRentals  = (snap.data?['totalRentals'] as int?) ?? 0;
        final loading       = !snap.hasData;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF2E8B57).withOpacity(0.08),
                const Color(0xFF6B8E23).withOpacity(0.05),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            border: Border.all(
              color: const Color(0xFF2E8B57).withOpacity(0.25),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────
              Row(
                children: const [
                  Icon(Icons.bar_chart_rounded,
                      size: 15, color: Color(0xFF2E8B57)),
                  SizedBox(width: 6),
                  Text(
                    'Community Impact',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E8B57),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Stats row ────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Total rentals — raw transaction count
                  _ImpactStat(
                    icon: Icons.receipt_long_rounded,
                    label: 'Total Rentals',
                    value: loading ? '—' : '$totalRentals',
                    color: const Color(0xFF9370DB),
                  ),

                  _divider(),

                  // Farmers served — unique renters (1 farmer renting 3× = 1)
                  Tooltip(
                    message: 'Unique farmers who rented this equipment',
                    child: _ImpactStat(
                      icon: Icons.people_alt_rounded,
                      label: 'Farmers Served',
                      value: loading ? '—' : '$farmersServed',
                      color: const Color(0xFF1E90FF),
                    ),
                  ),

                  _divider(),

                  // Hectares covered — sum of hectaresEntered across all done rentals
                  _ImpactStat(
                    icon: Icons.landscape_rounded,
                    label: 'Ha. Covered',
                    value: loading
                        ? '—'
                        : hectares > 0
                            ? hectares.toStringAsFixed(1)
                            : '0',
                    color: const Color(0xFF6B8E23),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Small stat cell ───────────────────────────────────────────────────────
class _ImpactStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ImpactStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
                height: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.black45,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}