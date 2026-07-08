import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;

import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/rent_request.dart'; // adjust path as needed

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _EquipmentReliability {
  final String itemId;
  final String itemName;
  final int totalRentals;        // completed rentals
  final int totalBreakdowns;     // damageReportCount — ALL reports (major + minor)
  final int majorBreakdowns;     // majorBreakdownCount — capital/major breakdowns only
  final int maintenanceCount;    // lifetime maintenance events
  final bool retirementFlagged;  // retirementFlaggedByAdmin

  const _EquipmentReliability({
    required this.itemId,
    required this.itemName,
    required this.totalRentals,
    required this.totalBreakdowns,
    required this.majorBreakdowns,
    required this.maintenanceCount,
    required this.retirementFlagged,
  });

  /// Non-major reports, derived (damageReportCount includes majors already).
  int get minorBreakdowns =>
      (totalBreakdowns - majorBreakdowns) < 0 ? 0 : totalBreakdowns - majorBreakdowns;

  /// Majors hurt the score 3x harder than minors — a major breakdown is a much
  /// stronger reliability signal than a minor one.
  int get _weightedBreakdowns => (majorBreakdowns * 3) + minorBreakdowns;

  /// The core metric: average rentals completed between (weighted) breakdowns.
  /// Null means "no breakdowns yet" — can't divide, and that's a good thing.
  double? get rentalsPerBreakdown =>
      _weightedBreakdowns == 0 ? null : totalRentals / _weightedBreakdowns;
}

enum _Tier { excellent, good, attention, critical, unknown }

_Tier _tierFor(_EquipmentReliability r) {
  if (r.totalRentals == 0) return _Tier.unknown;

  // 3-strike rule: 3+ major breakdowns (or admin-flagged) = overhaul,
  // regardless of how good the ratio looks otherwise.
  if (r.majorBreakdowns >= 3 || r.retirementFlagged) return _Tier.critical;

  if (r.totalBreakdowns == 0) return _Tier.excellent;
  final rpb = r.rentalsPerBreakdown!;
  if (rpb >= 8) return _Tier.excellent;
  if (rpb >= 4) return _Tier.good;
  if (rpb >= 2) return _Tier.attention;
  return _Tier.critical;
}

// Severity used for sorting: worst first so problems surface immediately.
int _severity(_Tier t) {
  switch (t) {
    case _Tier.critical: return 0;
    case _Tier.attention: return 1;
    case _Tier.good: return 2;
    case _Tier.excellent: return 3;
    case _Tier.unknown: return 4;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────

class ReliabilityScorePage extends StatefulWidget {
  /// When true, renders without its own Scaffold/AppBar so it can be
  /// dropped into a TabBarView (e.g. alongside the other KPI pages).
  final bool embedded;

  const ReliabilityScorePage({super.key, this.embedded = false});

  @override
  State<ReliabilityScorePage> createState() => _ReliabilityScorePageState();
}

class _ReliabilityScorePageState extends State<ReliabilityScorePage>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF21825C);
  static const _greenLight = Color(0xFF52B788);
  static const _greenPale = Color(0xFFD8F3DC);
  static const _amber = Color(0xFFBA1A1A);
  static const _red = Color(0xFFE76F51);
  static const _bg = Color(0xFFF8FAF8);
  static const _ink = Color(0xFF1B2E1F);
  static const _inkLight = Color(0xFF6B7F6E);
  static const _border = Color(0xFFE8EFE9);

  static const _terminalStatuses = {
    RentRequestStatus.returned,
    RentRequestStatus.finished,
    RentRequestStatus.completed,
  };

  String? _ownerId;
  bool _loading = true;
  String? _error;
  List<_EquipmentReliability> _items = [];

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _ownerId = FirebaseAuth.instance.currentUser?.uid;
    _load();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_ownerId == null) {
      setState(() {
        _error = 'Not logged in.';
        _loading = false;
      });
      return;
    }

    try {
      final equipSnap = await FirebaseFirestore.instance
          .collection('equipment')
          .where('ownerId', isEqualTo: _ownerId)
          .get();
      final equipmentList = equipSnap.docs.map((d) => Equipment.fromFirestore(d)).toList();

      final rentSnap = await FirebaseFirestore.instance
          .collection('rentRequests')
          .where('ownerId', isEqualTo: _ownerId)
          .get();
      final allRequests = rentSnap.docs.map((d) => RentRequest.fromDoc(d)).toList();

      final Map<String, int> rentalCounts = {};
      for (final r in allRequests) {
        if (!_terminalStatuses.contains(r.status)) continue;
        rentalCounts[r.itemId] = (rentalCounts[r.itemId] ?? 0) + 1;
      }

      final list = equipmentList.map((eq) {
        return _EquipmentReliability(
          itemId: eq.id ?? '',
          itemName: eq.name,
          totalRentals: rentalCounts[eq.id] ?? 0,
          totalBreakdowns: eq.damageReportCount,
          majorBreakdowns: eq.majorBreakdownCount,
          maintenanceCount: eq.maintenanceCount,
          retirementFlagged: eq.retirementFlaggedByAdmin,
        );
      }).toList();

      list.sort((a, b) {
        final sevCompare = _severity(_tierFor(a)).compareTo(_severity(_tierFor(b)));
        if (sevCompare != 0) return sevCompare;
        final ra = a.rentalsPerBreakdown ?? double.infinity;
        final rb = b.rentalsPerBreakdown ?? double.infinity;
        return ra.compareTo(rb);
      });

      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
      _fadeCtrl.forward(from: 0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load data: $e';
        _loading = false;
      });
    }
  }

  Color _tierColor(_Tier t) {
    switch (t) {
      case _Tier.excellent: return _green;
      case _Tier.good: return _greenLight;
      case _Tier.attention: return _amber;
      case _Tier.critical: return _red;
      case _Tier.unknown: return _inkLight;
    }
  }

  String _tierLabel(_Tier t) {
    switch (t) {
      case _Tier.excellent: return 'Excellent';
      case _Tier.good: return 'Good';
      case _Tier.attention: return 'Needs Attention';
      case _Tier.critical: return 'Overhaul Recommended';
      case _Tier.unknown: return 'No Data Yet';
    }
  }

  String _insightFor(_EquipmentReliability r, _Tier t) {
    // 3-strike rule gets its own message, takes priority over tier text.
    if (r.majorBreakdowns >= 3 || r.retirementFlagged) {
      return 'Hit ${r.majorBreakdowns} major breakdown${r.majorBreakdowns == 1 ? '' : 's'} — flagged for retirement under the 3-strike rule.';
    }

    switch (t) {
      case _Tier.unknown:
        return 'No completed rentals yet — reliability data will appear once this equipment has rental history.';
      case _Tier.excellent:
        if (r.totalBreakdowns == 0) {
          return 'No breakdowns reported across ${r.totalRentals} completed rental${r.totalRentals == 1 ? '' : 's'}.';
        }
        return '${r.majorBreakdowns} major, ${r.minorBreakdowns} minor breakdown${r.totalBreakdowns == 1 ? '' : 's'} across ${r.totalRentals} rentals — holding up well.';
      case _Tier.good:
        return '${r.majorBreakdowns} major, ${r.minorBreakdowns} minor breakdown${r.totalBreakdowns == 1 ? '' : 's'} so far. Worth a routine check-up.';
      case _Tier.attention:
        return '${r.majorBreakdowns} major, ${r.minorBreakdowns} minor breakdown${r.totalBreakdowns == 1 ? '' : 's'}. Consider a closer inspection soon.';
      case _Tier.critical:
        return '${r.majorBreakdowns} major, ${r.minorBreakdowns} minor breakdown${r.totalBreakdowns == 1 ? '' : 's'} — this may need a major overhaul or replacement rather than quick fixes.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _loading
        ? const Center(child: CircularProgressIndicator(color: _green))
        : _error != null
            ? _ErrorState(message: _error!, onRetry: _load)
            : _items.isEmpty
                ? _EmptyState(onRefresh: _load)
                : FadeTransition(opacity: _fadeAnim, child: _buildBody());

    if (widget.embedded) {
      return Container(color: _bg, child: content);
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Reliability Score',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              setState(() => _loading = true);
              _fadeCtrl.reset();
              _load();
            },
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildBody() {
    final withData = _items.where((r) => r.totalRentals > 0).toList();
    final withBreakdowns = withData.where((r) => r.totalBreakdowns > 0).toList();
    final avgRpb = withBreakdowns.isEmpty
        ? null
        : withBreakdowns.map((r) => r.rentalsPerBreakdown!).reduce((a, b) => a + b) /
            withBreakdowns.length;
    final flagged = _items.where((r) {
      final t = _tierFor(r);
      return t == _Tier.critical || t == _Tier.attention;
    }).toList();
    final totalMajor = _items.fold<int>(0, (sum, r) => sum + r.majorBreakdowns);
    final totalMinor = _items.fold<int>(0, (sum, r) => sum + r.minorBreakdowns);

    return Column(
      children: [
        _buildHeader(avgRpb, flagged.length, totalMajor, totalMinor),

        if (flagged.isNotEmpty) _buildFlaggedBanner(flagged),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: _items.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SectionLabel(label: 'Reliability Ranking'),
                );
              }
              final r = _items[i - 1];
              final tier = _tierFor(r);
              return _ReliabilityCard(
                reliability: r,
                tier: tier,
                color: _tierColor(tier),
                tierLabel: _tierLabel(tier),
                insight: _insightFor(r, tier),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(double? avgRpb, int flaggedCount, int totalMajor, int totalMinor) {
    return Container(
      color: _green,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Breakdown Frequency Overview',
            style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: 'Avg Rentals / Breakdown',
                  value: avgRpb == null ? '—' : avgRpb.toStringAsFixed(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatChip(
                  label: 'Flagged Equipment',
                  value: '$flaggedCount',
                  valueColor: flaggedCount > 0 ? _amber : Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  label: 'Total Major Breakdowns',
                  value: '$totalMajor',
                  valueColor: totalMajor > 0 ? _red : Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatChip(
                  label: 'Total Minor Breakdowns',
                  value: '$totalMinor',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFlaggedBanner(List<_EquipmentReliability> flagged) {
    return Container(
      width: double.infinity,
      color: _green,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.build_circle_rounded, color: _red, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${flagged.length} equipment may need attention',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    flagged.map((e) => e.itemName).take(3).join(', ') +
                        (flagged.length > 3 ? ', and ${flagged.length - 3} more' : ''),
                    style: const TextStyle(fontSize: 12, color: _inkLight),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _StatChip({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  color: valueColor ?? Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 11)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF6B7F6E),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _ReliabilityCard extends StatelessWidget {
  final _EquipmentReliability reliability;
  final _Tier tier;
  final Color color;
  final String tierLabel;
  final String insight;

  const _ReliabilityCard({
    required this.reliability,
    required this.tier,
    required this.color,
    required this.tierLabel,
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    final r = reliability;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: tier == _Tier.critical ? Border.all(color: color, width: 1.2) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReliabilityRing(reliability: r, color: color),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.itemName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1B2E1F)),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tierLabel,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  insight,
                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7F6E), height: 1.35),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _MiniStat(label: 'Rentals', value: '${r.totalRentals}'),
                    _MiniStat(label: 'Major breakdowns', value: '${r.majorBreakdowns}'),
                    _MiniStat(label: 'Minor breakdowns', value: '${r.minorBreakdowns}'),
                    _MiniStat(label: 'Maintenance events', value: '${r.maintenanceCount}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
              text: '$value ',
              style: const TextStyle(color: Color(0xFF1B2E1F), fontSize: 12, fontWeight: FontWeight.w700)),
          TextSpan(text: label, style: const TextStyle(color: Color(0xFF9CAEA0), fontSize: 11)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RING — shows the rentals-per-breakdown count, capped visually at 10
// ─────────────────────────────────────────────────────────────────────────────

class _ReliabilityRing extends StatefulWidget {
  final _EquipmentReliability reliability;
  final Color color;
  const _ReliabilityRing({required this.reliability, required this.color});

  @override
  State<_ReliabilityRing> createState() => _ReliabilityRingState();
}

class _ReliabilityRingState extends State<_ReliabilityRing> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reliability;
    const cap = 10.0;
    final fillTarget = r.totalRentals == 0
        ? 0.0
        : (r.rentalsPerBreakdown == null ? 1.0 : (r.rentalsPerBreakdown! / cap).clamp(0.0, 1.0));

    String centerText;
    String subtitle;
    if (r.totalRentals == 0) {
      centerText = '–';
      subtitle = 'no data';
    } else if (r.rentalsPerBreakdown == null) {
      centerText = '—';
      subtitle = 'no\nbreakdowns';
    } else {
      centerText = r.rentalsPerBreakdown!.toStringAsFixed(1);
      subtitle = 'rentals/\nbreakdown';
    }

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => SizedBox(
        width: 74,
        height: 74,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(74, 74),
              painter: _RingPainter(progress: fillTarget * _anim.value, color: widget.color),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  centerText,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: widget.color),
                ),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 8, color: Color(0xFF6B7F6E), height: 1.1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = cx - 5;
    const strokeWidth = 8.0;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = color.withOpacity(0.12)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY / ERROR STATES
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.build_circle_outlined, size: 64, color: Color(0xFFB7D4BC)),
            const SizedBox(height: 16),
            const Text(
              'No equipment tracked yet',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF1B2E1F)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Reliability scores will appear once your equipment has rental history.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7F6E), fontSize: 13),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2D6A4F), side: const BorderSide(color: Color(0xFF2D6A4F))),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFE76F51)),
            const SizedBox(height: 12),
            const Text('Something went wrong', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7F6E), fontSize: 12)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2D6A4F), side: const BorderSide(color: Color(0xFF2D6A4F))),
            ),
          ],
        ),
      ),
    );
  }
}