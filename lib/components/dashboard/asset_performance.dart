import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:bukidbayan_app/models/rent_request.dart'; // adjust path as needed

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _AssetPerformance {
  final String itemId;
  final String itemName;
  final double totalIncome;
  final int rentalCount;
  final DateTime? lastRentedAt;

  const _AssetPerformance({
    required this.itemId,
    required this.itemName,
    required this.totalIncome,
    required this.rentalCount,
    required this.lastRentedAt,
  });

  double get avgIncomePerRental =>
      rentalCount == 0 ? 0 : totalIncome / rentalCount;
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────

class AssetPerformancePage extends StatefulWidget {
  /// When true, renders without its own Scaffold/AppBar so it can be
  /// dropped straight into a TabBarView (e.g. inside KpiDashboardPage).
  final bool embedded;

  const AssetPerformancePage({super.key, this.embedded = false});

  @override
  State<AssetPerformancePage> createState() => _AssetPerformancePageState();
}

class _AssetPerformancePageState extends State<AssetPerformancePage>
    with SingleTickerProviderStateMixin {
  // Design tokens — matches utilization page palette
  static const _green = Color(0xFF21825C);
  static const _greenLight = Color(0xFF40916C);
  static const _greenPale = Color(0xFFD8F3DC);
  static const _gold = Color(0xFFF59E0B); 
  static const _bg = Color(0xFFF8FAF8);
  static const _ink = Color(0xFF1B2E1F);
  static const _inkLight = Color(0xFF6B7F6E);

  static const _terminalStatuses = {
    RentRequestStatus.returned,
    RentRequestStatus.finished,
    RentRequestStatus.completed,
  };

  // Filter window options
  static const Map<String, int?> _periods = {
    'All time': null,
    'Last 3 months': 3,
    'Last 6 months': 6,
    'Last 12 months': 12,
  };

  String _selectedPeriod = 'All time';
  String? _ownerId;
  bool _loading = true;
  String? _error;
  List<_AssetPerformance> _assets = [];

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
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('rentRequests')
          .where('ownerId', isEqualTo: _ownerId);

      final monthsBack = _periods[_selectedPeriod];
      if (monthsBack != null) {
        final cutoff = DateTime(
            DateTime.now().year, DateTime.now().month - (monthsBack - 1), 1);
        query = query.where('start',
            isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff));
      }

      final snap = await query.get();
      final allRequests =
          snap.docs.map((d) => RentRequest.fromDoc(d)).toList();

      final Map<String, List<RentRequest>> grouped = {};
      for (final r in allRequests) {
        if (!_terminalStatuses.contains(r.status)) continue;
        grouped.putIfAbsent(r.itemId, () => <RentRequest>[]).add(r);
      }

      final list = <_AssetPerformance>[];
      for (final entry in grouped.entries) {
        final reqs = entry.value;
        final income = reqs.fold<double>(
            0, (sum, r) => sum + (r.agreedPrice ?? 0));
        final lastRented = reqs
            .map((r) => r.end)
            .fold<DateTime?>(null, (latest, d) =>
                latest == null || d.isAfter(latest) ? d : latest);

        list.add(_AssetPerformance(
          itemId: entry.key,
          itemName: reqs.first.itemName,
          totalIncome: income,
          rentalCount: reqs.length,
          lastRentedAt: lastRented,
        ));
      }

      list.sort((a, b) => b.totalIncome.compareTo(a.totalIncome));

      if (!mounted) return;
      setState(() {
        _assets = list;
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

  void _onPeriodChanged(String? period) {
    if (period == null || period == _selectedPeriod) return;
    setState(() {
      _selectedPeriod = period;
      _loading = true;
    });
    _fadeCtrl.reset();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final content = _loading
        ? const Center(child: CircularProgressIndicator(color: _green))
        : _error != null
            ? _ErrorState(message: _error!)
            : _assets.isEmpty
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
          'Top Performing Equipment',
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
    final totalIncome =
        _assets.fold<double>(0, (sum, a) => sum + a.totalIncome);
    final totalRentals =
        _assets.fold<int>(0, (sum, a) => sum + a.rentalCount);
    final topAsset = _assets.first;

    return Column(
      children: [
        _buildHeader(totalIncome, totalRentals, topAsset),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionLabel(label: 'Earnings Comparison'),
                const SizedBox(height: 10),
                _EarningsBarChart(
                  assets: _assets,
                  highlightColor: _green,
                  midColor: _gold,
                  inkLight: _inkLight,
                ),
                const SizedBox(height: 24),
                _SectionLabel(label: 'Ranking'),
                const SizedBox(height: 10),
                ...List.generate(_assets.length, (i) {
                  return _AssetRankCard(
                    rank: i + 1,
                    asset: _assets[i],
                    isTop: i == 0,
                    shareOfTotal: totalIncome == 0
                        ? 0
                        : _assets[i].totalIncome / totalIncome,
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
      double totalIncome, int totalRentals, _AssetPerformance topAsset) {
    return Container(
      color: _green,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Asset Earnings Overview',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.75), fontSize: 12),
              ),
              _PeriodDropdown(
                selected: _selectedPeriod,
                options: _periods.keys.toList(),
                onChanged: _onPeriodChanged,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _HeaderStat(
                label: 'Total Earnings',
                value: '₱${_formatCurrency(totalIncome)}',
              ),
              const SizedBox(width: 12),
              _HeaderStat(
                label: 'Completed Rentals',
                value: '$totalRentals',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: _gold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Top performer',
                        style: TextStyle(
                            fontSize: 11,
                            color: _inkLight,
                            fontWeight: FontWeight.w500),
                      ),
                      Text(
                        topAsset.itemName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _ink),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₱${_formatCurrency(topAsset.totalIncome)}',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatCurrency(double value) {
  final isWhole = value == value.roundToDouble();
  final str = isWhole
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
  final parts = str.split('.');
  final intPart = parts[0];
  final buffer = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write(',');
    buffer.write(intPart[i]);
  }
  return parts.length > 1 ? '${buffer.toString()}.${parts[1]}' : buffer.toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  const _HeaderStat({required this.label, required this.value});

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
                    fontSize: 20,
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

class _PeriodDropdown extends StatelessWidget {
  final String selected;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _PeriodDropdown({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          dropdownColor: const Color(0xFF2D6A4F),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: Colors.white, size: 18),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: onChanged,
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

// ─────────────────────────────────────────────────────────────────────────────
// HORIZONTAL EARNINGS BAR CHART
// ─────────────────────────────────────────────────────────────────────────────

class _EarningsBarChart extends StatefulWidget {
  final List<_AssetPerformance> assets;
  final Color highlightColor;
  final Color midColor;
  final Color inkLight;

  const _EarningsBarChart({
    required this.assets,
    required this.highlightColor,
    required this.midColor,
    required this.inkLight,
  });

  @override
  State<_EarningsBarChart> createState() => _EarningsBarChartState();
}

class _EarningsBarChartState extends State<_EarningsBarChart>
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
    final displayed = widget.assets.take(6).toList();
    final maxIncome = displayed.isEmpty
        ? 1.0
        : displayed.map((a) => a.totalIncome).reduce((a, b) => a > b ? a : b);

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
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: displayed.asMap().entries.map((entry) {
            final i = entry.key;
            final asset = entry.value;
            final fraction = maxIncome == 0
                ? 0.0
                : (asset.totalIncome / maxIncome) * _anim.value;
            final color = i == 0
                ? widget.highlightColor
                : i == 1
                    ? widget.midColor
                    : widget.inkLight.withOpacity(0.6);

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          asset.itemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1B2E1F)),
                        ),
                      ),
                      Text(
                        '₱${_formatCurrency(asset.totalIncome)}',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Stack(
                      children: [
                        Container(
                          height: 10,
                          color: color.withOpacity(0.1),
                        ),
                        FractionallySizedBox(
                          widthFactor: fraction.clamp(0, 1),
                          child: Container(
                            height: 10,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RANKING CARD
// ─────────────────────────────────────────────────────────────────────────────

class _AssetRankCard extends StatelessWidget {
  final int rank;
  final _AssetPerformance asset;
  final bool isTop;
  final double shareOfTotal;

  const _AssetRankCard({
    required this.rank,
    required this.asset,
    required this.isTop,
    required this.shareOfTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: isTop
            ? Border.all(color: const Color(0xFFF59E0B), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isTop
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFD8F3DC),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isTop
                  ? const Icon(Icons.emoji_events_rounded,
                      color: Colors.white, size: 16)
                  : Text(
                      '$rank',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFF2D6A4F)),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.itemName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1B2E1F)),
                ),
                const SizedBox(height: 3),
                Text(
                  '${asset.rentalCount} rental${asset.rentalCount == 1 ? '' : 's'} · '
                  '₱${_formatCurrency(asset.avgIncomePerRental)} avg/rental',
                  style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFF6B7F6E)),
                ),
                if (asset.lastRentedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Last rented ${_formatDate(asset.lastRentedAt!)}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF9CAEA0)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${_formatCurrency(asset.totalIncome)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Color(0xFF2D6A4F)),
              ),
              const SizedBox(height: 2),
              Text(
                '${(shareOfTotal * 100).toStringAsFixed(0)}% of total',
                style: const TextStyle(
                    fontSize: 10.5, color: Color(0xFF9CAEA0)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime d) {
  const months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[d.month]} ${d.day}, ${d.year}';
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
              'No completed rentals yet',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: Color(0xFF1B2E1F)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Earnings ranking will appear once at least one rental '
              'has been completed for your equipment.',
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
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF6B7F6E), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}