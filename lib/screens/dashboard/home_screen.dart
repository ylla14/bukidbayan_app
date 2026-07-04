import 'package:bukidbayan_app/components/dashboard/action_buttons_section.dart';
import 'package:bukidbayan_app/components/dashboard/asset_performance.dart';
import 'package:bukidbayan_app/components/dashboard/dashboard_calendar_section.dart';
import 'package:bukidbayan_app/components/dashboard/greeting_section.dart';
import 'package:bukidbayan_app/components/dashboard/map_section.dart';
import 'package:bukidbayan_app/components/dashboard/retirement_alert_section.dart';
import 'package:bukidbayan_app/components/dashboard/summary_cards_section.dart';
import 'package:bukidbayan_app/components/dashboard/utilization_rate.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:bukidbayan_app/components/app_bar.dart';
import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:bukidbayan_app/components/dashboard/crops_in_season_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isCalendarExpanded = false;

  Future<void> logout() async => await _auth.signOut();

  Widget _buildCalendarDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: ExpansionTile(
          key: const Key('home_smart_calendar_dropdown'),
          initiallyExpanded: _isCalendarExpanded,
          onExpansionChanged: (expanded) {
            setState(() => _isCalendarExpanded = expanded);
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: const Icon(Icons.calendar_month_rounded),
          title: const Text(
            'Smart Calendar & Suggested Actions',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            _isCalendarExpanded ? 'Tap to collapse' : 'Tap to expand',
            style: const TextStyle(fontSize: 12),
          ),
          children: [
            DashboardCalendarSection(
              currentUserId: _auth.currentUser?.uid,
              showHeader: false,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      drawer: CustomDrawer(onLogout: logout),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const GreetingSection(),
            const SizedBox(height: 16),
            const SummaryCardsSection(),
            const SizedBox(height: 24),
            ActionButtonsSection(),
            const SizedBox(height: 16),
            const RetirementAlertSection(),
            // const SizedBox(height: ),
            _buildCalendarDropdown(),
            const SizedBox(height: 24),
            MapSection(currentUserId: _auth.currentUser?.uid),
            const SizedBox(height: 20),
            const CropsInSeasonSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
