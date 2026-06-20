import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/services/strike_service.dart';
import 'package:bukidbayan_app/screens/rent/my_equipment.dart';
import 'package:bukidbayan_app/theme/theme.dart';

/// Shows a dismissible retirement-suggestion banner on the dashboard whenever
/// the owner has at least one piece of equipment with
/// damageReportCount ≥ StrikeService.kDamageRetirementThreshold (3).
///
/// Tapping "View Equipment" navigates to MyEquipment.
class RetirementAlertSection extends StatefulWidget {
  const RetirementAlertSection({super.key});

  @override
  State<RetirementAlertSection> createState() => _RetirementAlertSectionState();
}

class _RetirementAlertSectionState extends State<RetirementAlertSection>
    with SingleTickerProviderStateMixin {
  bool _dismissed = false;
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('equipment')
          .where('ownerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final retiring = snapshot.data!.docs
            .map((doc) => Equipment.fromFirestore(doc))
            .where((e) =>
                e.damageReportCount >=
                StrikeService.kDamageRetirementThreshold)
            .toList();

        if (retiring.isEmpty) return const SizedBox.shrink();

        return _RetirementBanner(
          retiring: retiring,
          pulseAnim: _pulseAnim,
          onDismiss: () => setState(() => _dismissed = true),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner widget (kept separate so the stream builder stays lean)
// ─────────────────────────────────────────────────────────────────────────────

class _RetirementBanner extends StatelessWidget {
  final List<Equipment> retiring;
  final Animation<double> pulseAnim;
  final VoidCallback onDismiss;

  const _RetirementBanner({
    required this.retiring,
    required this.pulseAnim,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final count = retiring.length;
    final isSingle = count == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: lightColorScheme.error.withOpacity(0.01),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lightColorScheme.error, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pulsing icon
                ScaleTransition(
                  scale: pulseAnim,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: lightColorScheme.error.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.archive_rounded,
                      color:lightColorScheme.error,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isSingle
                                ? 'Retirement Suggested'
                                : '$count Equipment Need Attention',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: lightColorScheme.error,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: lightColorScheme.error,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isSingle
                            ? '"${retiring.first.name}" has received '
                              '${retiring.first.damageReportCount} damage report'
                              '${retiring.first.damageReportCount == 1 ? '' : 's'}. '
                              'Consider retiring it from service.'
                            : '$count of your equipment have reached the damage '
                              'report threshold. Consider retiring them.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: lightColorScheme.error,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                // Dismiss button
                IconButton(
                  icon: Icon(Icons.close,
                      size: 18, color: lightColorScheme.error),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Dismiss',
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),

          // ── Equipment chips (if multiple) ────────────────────────────────
          if (!isSingle) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: retiring.map((e) {
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: lightColorScheme.error,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: lightColorScheme.error, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.agriculture_rounded,
                            size: 12,
                            color: lightColorScheme.error),
                        const SizedBox(width: 4),
                        Text(
                          e.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${e.damageReportCount})',
                          style: TextStyle(
                            fontSize: 10,
                            color: lightColorScheme.error
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // ── Divider + CTA ────────────────────────────────────────────────
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Equipment with ${StrikeService.kDamageRetirementThreshold}+ '
                    'damage reports should be inspected or retired.',
                    style: TextStyle(
                      fontSize: 11,
                      color: lightColorScheme.error,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyEquipment(),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                  label: const Text('View Equipment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: lightColorScheme.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}