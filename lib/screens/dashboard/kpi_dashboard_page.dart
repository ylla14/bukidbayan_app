import 'package:bukidbayan_app/components/dashboard/asset_performance.dart';
import 'package:bukidbayan_app/components/dashboard/equipment_reliability.dart';
import 'package:bukidbayan_app/components/dashboard/utilization_rate.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';

/// Tabbed host combining UtilizationAnalyticsPage and AssetPerformancePage
/// under one AppBar. Both pages are reused as-is via their `embedded: true`
/// flag, which just skips their own Scaffold/AppBar.
class KpiDashboardPage extends StatefulWidget {
  const KpiDashboardPage({super.key});

  @override
  State<KpiDashboardPage> createState() => _KpiDashboardPageState();
}

class _KpiDashboardPageState extends State<KpiDashboardPage>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF2D6A4F);

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: lightColorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Performance Dashboard',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.65),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Utilization & Uptime'),
            Tab(text: 'Top Performing'),
            Tab(text: 'Reliability'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          UtilizationAnalyticsPage(embedded: true),
          AssetPerformancePage(embedded: true),
          ReliabilityScorePage(embedded: true),
        ],
      ),
    );
  }
}