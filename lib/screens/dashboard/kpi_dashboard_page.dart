import 'package:bukidbayan_app/components/dashboard/asset_performance.dart';
import 'package:bukidbayan_app/components/dashboard/equipment_reliability.dart';
import 'package:bukidbayan_app/components/dashboard/utilization_rate.dart';
import 'package:bukidbayan_app/services/app_language.dart';
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
  late final TabController _tabController;

  String _t(String en, String tl) => AppLanguage.text(en: en, tl: tl);

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
    return AppLanguageScope(
      builder: (context) => Scaffold(
        appBar: AppBar(
          backgroundColor: lightColorScheme.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            _t('Performance Dashboard', 'Dashboard ng Pagganap'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.65),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            tabs: [
              Tab(text: _t('Utilization & Uptime', 'Utilization at Uptime')),
              Tab(text: _t('Top Performing', 'Nangunguna')),
              Tab(text: _t('Reliability', 'Maaasahan')),
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
      ),
    );
  }
}
