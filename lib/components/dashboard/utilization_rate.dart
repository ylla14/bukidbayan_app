import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' as math;

import 'package:bukidbayan_app/models/rent_request.dart'; // adjust path as needed

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _MonthlyUtil {
  final int year;
  final int month;
  final double utilizationPct; // 0–100
  final int daysRented;
  final int totalDays;

  const _MonthlyUtil({
    required this.year,
    required this.month,
    required this.utilizationPct,
    required this.daysRented,
    required this.totalDays,
  });

  String get label {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[month]} $year';
  }
}

class _EquipmentUtil {
  final String itemId;
  final String itemName;
  final List<_MonthlyUtil> monthly;
  final double avgUtilization;
  final List<_MonthlyUtil> peakMonths; // top demand months (for forecasting)

  const _EquipmentUtil({
    required this.itemId,
    required this.itemName,
    required this.monthly,
    required this.avgUtilization,
    required this.peakMonths,
  });
}

// Philippines has 2 seasons: Dry (Nov–Apr) and Wet (May–Oct)
enum _Season { dry, wet }

_Season _seasonOf(int month) {
  const dryMonths = {11, 12, 1, 2, 3, 4};
  return dryMonths.contains(month) ? _Season.dry : _Season.wet;
}

String _seasonLabel(_Season s) => s == _Season.dry ? 'Dry Season' : 'Wet Season';

// ─────────────────────────────────────────────────────────────────────────────
// HELPER – compute utilization from a list of RentRequests
// ─────────────────────────────────────────────────────────────────────────────

List<_MonthlyUtil> _computeMonthly(
    List<RentRequest> requests, int monthsBack) {
  final now = DateTime.now();
  final results = <_MonthlyUtil>[];

  for (int i = monthsBack - 1; i >= 0; i--) {
    final target = DateTime(now.year, now.month - i, 1);
    final year = target.year;
    final month = target.month;
    final totalDays = DateTime(year, month + 1, 0).day;
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month, totalDays, 23, 59, 59);

    final activeStatuses = {
      RentRequestStatus.approved,
      RentRequestStatus.readyForPickup,
      RentRequestStatus.pickedUp,
      RentRequestStatus.onTheWay,
      RentRequestStatus.inProgress,
      RentRequestStatus.retrieving,
      RentRequestStatus.returned,
      RentRequestStatus.finished,
      RentRequestStatus.completed,
    };

    final Set<int> rentedDayNumbers = {};

    for (final req in requests) {
      if (!activeStatuses.contains(req.status)) continue;
      final overlapStart =
          req.start.isBefore(monthStart) ? monthStart : req.start;
      final overlapEnd = req.end.isAfter(monthEnd) ? monthEnd : req.end;
      if (overlapStart.isAfter(overlapEnd)) continue;

      for (int d = overlapStart.day;
          d <= overlapEnd.day &&
              overlapStart.month == month &&
              overlapEnd.month == month;
          d++) {
        rentedDayNumbers.add(d);
      }

      if (overlapStart.month != overlapEnd.month ||
          overlapStart.year != overlapEnd.year) {
        var cursor = overlapStart;
        while (!cursor.isAfter(overlapEnd)) {
          if (cursor.year == year && cursor.month == month) {
            rentedDayNumbers.add(cursor.day);
          }
          cursor = cursor.add(const Duration(days: 1));
        }
      }
    }

    final daysRented = rentedDayNumbers.length;
    final pct = (daysRented / totalDays) * 100;

    results.add(_MonthlyUtil(
      year: year,
      month: month,
      utilizationPct: pct.clamp(0, 100),
      daysRented: daysRented,
      totalDays: totalDays,
    ));
  }

  return results;
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────

class UtilizationAnalyticsPage extends StatefulWidget {
  /// When true, renders without its own Scaffold/AppBar so it can be
  /// dropped straight into a TabBarView (e.g. inside KpiDashboardPage).
  final bool embedded;

  const UtilizationAnalyticsPage({super.key, this.embedded = false});

  @override
  State<UtilizationAnalyticsPage> createState() =>
      _UtilizationAnalyticsPageState();
}

class _UtilizationAnalyticsPageState extends State<UtilizationAnalyticsPage>
    with SingleTickerProviderStateMixin {
  static const _monthsBack = 12;

  // Design tokens
  static const _green = Color(0xFF2D6A4F);
  static const _greenLight = Color(0xFF52B788);
  static const _greenPale = Color(0xFFD8F3DC);
  static const _amber = Color(0xFFE9C46A);
  static const _red = Color(0xFFE76F51);
  static const _bg = Color(0xFFF8FAF8);
  static const _surface = Color(0xFFFFFFFF);
  static const _ink = Color(0xFF1B2E1F);
  static const _inkLight = Color(0xFF6B7F6E);

  String? _ownerId;
  bool _loading = true;
  String? _error;
  List<_EquipmentUtil> _equipmentList = [];
  int _selectedIndex = 0;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
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
      final cutoff = DateTime(
          DateTime.now().year, DateTime.now().month - (_monthsBack - 1), 1);

      final snap = await FirebaseFirestore.instance
          .collection('rentRequests')
          .where('ownerId', isEqualTo: _ownerId)
          .where('start',
              isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff))
          .get();

      final allRequests =
          snap.docs.map((d) => RentRequest.fromDoc(d)).toList();

      final Map<String, List<RentRequest>> grouped = {};
      for (final r in allRequests) {
        grouped.putIfAbsent(r.itemId, () => []).add(r);
      }

      final list = <_EquipmentUtil>[];
      for (final entry in grouped.entries) {
        final monthly = _computeMonthly(entry.value, _monthsBack);
        final avg = monthly.isEmpty
            ? 0.0
            : monthly.map((m) => m.utilizationPct).reduce((a, b) => a + b) /
                monthly.length;
        final name = entry.value.first.itemName;

        final sortedByDemand = [...monthly]
          ..sort((a, b) => b.utilizationPct.compareTo(a.utilizationPct));
        final peaks = sortedByDemand.take(3).where((m) => m.utilizationPct > 0).toList();

        list.add(_EquipmentUtil(
          itemId: entry.key,
          itemName: name,
          monthly: monthly,
          avgUtilization: avg,
          peakMonths: peaks,
        ));
      }

      list.sort((a, b) => b.avgUtilization.compareTo(a.avgUtilization));

      if (!mounted) return;
      setState(() {
        _equipmentList = list;
        _loading = false;
      });
      _fadeCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load data: $e';
        _loading = false;
      });
    }
  }

  Color _utilizationColor(double pct) {
    if (pct >= 70) return _green;
    if (pct >= 40) return _amber;
    return _red;
  }

  String _utilizationLabel(double pct) {
    if (pct >= 70) return 'High';
    if (pct >= 40) return 'Moderate';
    return 'Idle';
  }

  @override
  Widget build(BuildContext context) {
    final content = _loading
        ? const Center(
            child: CircularProgressIndicator(color: _green),
          )
        : _error != null
            ? _ErrorState(message: _error!)
            : _equipmentList.isEmpty
                ? _EmptyState(onRefresh: _load)
                : FadeTransition(
                    opacity: _fadeAnim,
                    child: _buildBody(),
                  );

    // Embedded mode: no own Scaffold/AppBar — parent (e.g. tab host) owns chrome.
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
          'Utilization & Uptime',
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
    return Column(
      children: [
        _buildHeader(),
        _buildEquipmentTabs(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: _buildEquipmentDetail(_equipmentList[_selectedIndex]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final allAvg = _equipmentList.isEmpty
        ? 0.0
        : _equipmentList
                .map((e) => e.avgUtilization)
                .reduce((a, b) => a + b) /
            _equipmentList.length;

    return Container(
      color: _green,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fleet Overview · Last $_monthsBack months',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.75), fontSize: 12),
              ),
              // In embedded mode there's no AppBar action, so give a way to refresh here.
              if (widget.embedded)
                InkWell(
                  onTap: () {
                    setState(() => _loading = true);
                    _fadeCtrl.reset();
                    _load();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _HeaderStat(
                label: 'Fleet Avg Utilization',
                value: '${allAvg.toStringAsFixed(1)}%',
                color: _greenPale,
              ),
              const SizedBox(width: 12),
              _HeaderStat(
                label: 'Equipment Tracked',
                value: '${_equipmentList.length}',
                color: _greenPale,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentTabs() {
    return Container(
      color: _green,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(
          children: List.generate(_equipmentList.length, (i) {
            final eq = _equipmentList[i];
            final selected = i == _selectedIndex;
            return GestureDetector(
              onTap: () => setState(() => _selectedIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  eq.itemName,
                  style: TextStyle(
                    color: selected ? _green : Colors.white,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildEquipmentDetail(_EquipmentUtil eq) {
    final current = eq.monthly.isNotEmpty ? eq.monthly.last : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),

        if (current != null) ...[
          _SectionLabel(label: 'This Month'),
          const SizedBox(height: 10),
          _CurrentMonthCard(
            util: current,
            color: _utilizationColor(current.utilizationPct),
            statusLabel: _utilizationLabel(current.utilizationPct),
          ),
          const SizedBox(height: 20),
        ],

        _SectionLabel(label: '${_monthsBack}-Month Trend'),
        const SizedBox(height: 10),
        _BarChart(
          monthly: eq.monthly,
          utilizationColor: _utilizationColor,
          avgUtilization: eq.avgUtilization,
        ),
        const SizedBox(height: 20),

        _SectionLabel(label: 'Demand Forecast'),
        const SizedBox(height: 10),
        _ForecastCard(itemName: eq.itemName, peakMonths: eq.peakMonths),
        const SizedBox(height: 20),

        _SectionLabel(label: 'Monthly Breakdown'),
        const SizedBox(height: 10),
        ...eq.monthly.reversed.map(
          (m) => _MonthRow(
            util: m,
            barColor: _utilizationColor(m.utilizationPct),
          ),
        ),
        const SizedBox(height: 20),

        _Legend(),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeaderStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.75), fontSize: 11)),
          ],
        ),
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

class _CurrentMonthCard extends StatelessWidget {
  final _MonthlyUtil util;
  final Color color;
  final String statusLabel;

  const _CurrentMonthCard({
    required this.util,
    required this.color,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _RingIndicator(pct: util.utilizationPct, color: color),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _StatRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Days rented',
                    value: '${util.daysRented} / ${util.totalDays} days'),
                const SizedBox(height: 6),
                _StatRow(
                    icon: Icons.hourglass_bottom_rounded,
                    label: 'Idle days',
                    value:
                        '${util.totalDays - util.daysRented} days'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingIndicator extends StatefulWidget {
  final double pct;
  final Color color;
  const _RingIndicator({required this.pct, required this.color});

  @override
  State<_RingIndicator> createState() => _RingIndicatorState();
}

class _RingIndicatorState extends State<_RingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim = Tween<double>(
        begin: 0,
        end: 1,
      ).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Curves.easeOutCubic,
        ),
      );
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => SizedBox(
        width: 90,
        height: 90,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(90, 90),
              painter: _RingPainter(
                progress: (widget.pct / 100) * _anim.value,
                color: widget.color,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(widget.pct * _anim.value).toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: widget.color),
                ),
                const Text('uptime',
                    style: TextStyle(fontSize: 10, color: Color(0xFF6B7F6E))),
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
    final radius = cx - 6;
    const strokeWidth = 10.0;

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
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF6B7F6E)),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                        color: Color(0xFF6B7F6E), fontSize: 12)),
                TextSpan(
                    text: value,
                    style: const TextStyle(
                        color: Color(0xFF1B2E1F),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BAR CHART (custom painted, no extra package needed)
// ─────────────────────────────────────────────────────────────────────────────

class _BarChart extends StatefulWidget {
  final List<_MonthlyUtil> monthly;
  final Color Function(double) utilizationColor;
  final double avgUtilization;

  const _BarChart({
    required this.monthly,
    required this.utilizationColor,
    required this.avgUtilization,
  });

  @override
  State<_BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<_BarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 24,
                  height: 2,
                  color: const Color(0xFF6B7F6E)),
              const SizedBox(width: 6),
              Text(
                'Avg ${widget.avgUtilization.toStringAsFixed(1)}%',
                style: const TextStyle(
                    color: Color(0xFF6B7F6E), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: _anim,
            builder: (_, __) => CustomPaint(
              size: const Size(double.infinity, 160),
              painter: _BarChartPainter(
                monthly: widget.monthly,
                progress: _anim.value,
                avgPct: widget.avgUtilization,
                colorFn: widget.utilizationColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<_MonthlyUtil> monthly;
  final double progress;
  final double avgPct;
  final Color Function(double) colorFn;

  _BarChartPainter({
    required this.monthly,
    required this.progress,
    required this.avgPct,
    required this.colorFn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (monthly.isEmpty) return;

    const labelH = 28.0;
    final chartH = size.height - labelH;
    final gap = monthly.length > 8 ? 4.0 : 8.0;
    final barW = (size.width - (monthly.length - 1) * gap) / monthly.length;
    const maxPct = 100.0;

    final avgY = chartH - (avgPct / maxPct) * chartH;
    final dashPaint = Paint()
      ..color = const Color(0xFF6B7F6E).withOpacity(0.5)
      ..strokeWidth = 1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, avgY), Offset(x + 6, avgY), dashPaint);
      x += 10;
    }

    for (int i = 0; i < monthly.length; i++) {
      final m = monthly[i];
      final barX = i * (barW + gap);
      final barH = (m.utilizationPct / maxPct) * chartH * progress;
      final barY = chartH - barH;
      final color = colorFn(m.utilizationPct);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barX + 2, barY + 2, barW, barH),
          const Radius.circular(6),
        ),
        Paint()..color = color.withOpacity(0.15),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(barX, barY, barW, barH),
          const Radius.circular(6),
        ),
        Paint()..color = color,
      );

      if (progress > 0.7 && monthly.length <= 8) {
        final pctText =
            '${m.utilizationPct.toStringAsFixed(0)}%';
        final tp = TextPainter(
          text: TextSpan(
            text: pctText,
            style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
            canvas,
            Offset(barX + (barW - tp.width) / 2,
                math.max(0, barY - tp.height - 2)));
      }

      final labelText = _shortMonth(m.month);
      final ltp = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(
              color: Color(0xFF6B7F6E),
              fontSize: 9,
              fontWeight: FontWeight.w500),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      ltp.paint(
          canvas,
          Offset(
              barX + (barW - ltp.width) / 2, chartH + 6));
    }
  }

  String _shortMonth(int m) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[m];
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.progress != progress || old.monthly != monthly;
}

// ─────────────────────────────────────────────────────────────────────────────
// MONTHLY BREAKDOWN ROW
// ─────────────────────────────────────────────────────────────────────────────

class _MonthRow extends StatelessWidget {
  final _MonthlyUtil util;
  final Color barColor;

  const _MonthRow({required this.util, required this.barColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                util.label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFF1B2E1F)),
              ),
              Text(
                '${util.daysRented} / ${util.totalDays} days · '
                '${util.utilizationPct.toStringAsFixed(1)}%',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF6B7F6E)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: util.utilizationPct / 100,
              minHeight: 6,
              backgroundColor: barColor.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DEMAND FORECAST CARD (seasonal insight from past bookings)
// ─────────────────────────────────────────────────────────────────────────────

class _ForecastCard extends StatelessWidget {
  final String itemName;
  final List<_MonthlyUtil> peakMonths;

  const _ForecastCard({required this.itemName, required this.peakMonths});

  @override
  Widget build(BuildContext context) {
    if (peakMonths.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8EFE9)),
        ),
        child: const Text(
          'Not enough booking history yet to forecast demand. '
          'Once a full year of data builds up, peak months will show here.',
          style: TextStyle(color: Color(0xFF6B7F6E), fontSize: 12),
        ),
      );
    }

    final dryCount =
        peakMonths.where((m) => _seasonOf(m.month) == _Season.dry).length;
    final wetCount = peakMonths.length - dryCount;
    final dominantSeason = dryCount >= wetCount ? _Season.dry : _Season.wet;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D6A4F), Color(0xFF40916C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                dominantSeason == _Season.dry
                    ? Icons.wb_sunny_rounded
                    : Icons.water_drop_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$itemName peaks during ${_seasonLabel(dominantSeason)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: peakMonths.map((m) {
              final season = _seasonOf(m.month);
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      season == _Season.dry
                          ? Icons.wb_sunny_rounded
                          : Icons.water_drop_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${m.label} · ${m.utilizationPct.toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            'Based on past bookings, plan ahead for these months — '
            'consider reserving maintenance windows outside peak demand.',
            style: TextStyle(
                color: Colors.white.withOpacity(0.85), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEGEND
// ─────────────────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8EFE9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Utilization Guide',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: Color(0xFF1B2E1F))),
          const SizedBox(height: 10),
          _LegendRow(
              color: const Color(0xFF2D6A4F),
              label: 'High (≥70%)',
              desc: "Machine is earning its keep."),
          const SizedBox(height: 6),
          _LegendRow(
              color: const Color(0xFFE9C46A),
              label: 'Moderate (40–69%)',
              desc: 'Decent, but room to grow.'),
          const SizedBox(height: 6),
          _LegendRow(
              color: const Color(0xFFE76F51),
              label: 'Idle (<40%)',
              desc: 'Consider pricing review or maintenance check.'),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final String desc;

  const _LegendRow(
      {required this.color, required this.label, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 3),
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                    text: '$label  ',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
                TextSpan(
                    text: desc,
                    style: const TextStyle(
                        color: Color(0xFF6B7F6E), fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }
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
            const Icon(Icons.bar_chart_rounded,
                size: 64, color: Color(0xFFB7D4BC)),
            const SizedBox(height: 16),
            const Text(
              'No rental data yet',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Color(0xFF1B2E1F)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Utilization charts will appear once your equipment has been booked at least once.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7F6E), fontSize: 13),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2D6A4F),
                  side: const BorderSide(color: Color(0xFF2D6A4F))),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFFE76F51)),
            const SizedBox(height: 12),
            const Text('Something went wrong',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF6B7F6E), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}