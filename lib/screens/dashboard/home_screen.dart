import 'dart:io';
import 'package:bukidbayan_app/components/app_bar.dart';
import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/screens/dashboard/rentals_list.dart';
import 'package:bukidbayan_app/widgets/custom_icon_button.dart';
import 'package:bukidbayan_app/widgets/dashboard_summary_card.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/services/rent_request_service.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:google_maps_flutter/google_maps_flutter.dart';



class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const LatLng _cabuyao = LatLng(14.2470, 121.1367);
  GoogleMapController? _mapController;
  final RentRequestService _requestService = RentRequestService();
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

            // 👋 Greeting or Dashboard title
            Text(
              "Dashboard",
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            // 📊 Summary Cards (scrollable horizontally)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  DashboardSummaryCard(
                    icon: Icons.thermostat,
                    title: 'Temperature',
                    value: '32°C',
                    subtitle: 'Feels hot',
                    backgroundColor: const Color(0xFFFFF3E0),
                    iconColor: Colors.deepOrange,
                  ),
                  const SizedBox(width: 12),
                  DashboardSummaryCard(
                    icon: Icons.water_drop,
                    title: 'Humidity',
                    value: '78%',
                    subtitle: 'High humidity',
                    backgroundColor: const Color(0xFFE3F2FD),
                    iconColor: Colors.blue,
                  ),
                  const SizedBox(width: 12),
                  DashboardSummaryCard(
                    icon: Icons.cloudy_snowing,
                    title: 'Rain Chance',
                    value: '60%',
                    subtitle: 'Possible showers',
                    backgroundColor: const Color(0xFFE8F5E9),
                    iconColor: Colors.green,
                  ),
                ],
              ),
            ),


            const SizedBox(height: 24),

            // 🔘 Action Buttons
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomIconButton(
                  icon: const Icon(Icons.add_box_rounded),
                  label: const Text('My Rental Requests'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            RentalsList(mode: RentalsListMode.myRequests),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                CustomIconButton(
                  icon: const Icon(Icons.inbox_rounded),
                  label: const Text('Requests for My Equipment'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            RentalsList(mode: RentalsListMode.incomingRequests),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 🗺️ Map Section
            Text(
              "Nearby Equipment",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _cabuyao,
                  zoom: 13,
                ),
                onMapCreated: (controller) => _mapController = controller,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
