import 'package:bukidbayan_app/components/dashboard/action_buttons_section.dart.dart';
import 'package:bukidbayan_app/components/dashboard/greeting_section.dart';
import 'package:bukidbayan_app/components/dashboard/map_section.dart';
import 'package:bukidbayan_app/components/dashboard/summary_cards_section.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:bukidbayan_app/components/app_bar.dart';
import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:bukidbayan_app/components/dashboard/crops_in_season_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const LatLng _cabuyao = LatLng(14.2470, 121.1367);
  GoogleMapController? _mapController;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> logout() async => await _auth.signOut();

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
            const SizedBox(height: 24),
            MapSection(cabuyao: _cabuyao, mapController: _mapController),
            const SizedBox(height: 30),
            const CropsInSeasonSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
