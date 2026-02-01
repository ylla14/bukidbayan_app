import 'dart:io';
import 'package:bukidbayan_app/components/app_bar.dart';
import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/screens/dashboard/rentals_list.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/custom_icon_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/services/rent_request_service.dart';
import 'package:intl/intl.dart'; // For date formatting


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RentRequestService _requestService = RentRequestService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> logout() async {
    await _auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      drawer: CustomDrawer(onLogout: logout),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: CustomIconButton(
                icon: const Icon(Icons.add_box_rounded),
                label: const Text('My Rental Requests'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RentalsList(mode: RentalsListMode.myRequests),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8), // spacing between buttons
            SizedBox(
              width: double.infinity,
              child: CustomIconButton(
                icon: const Icon(Icons.inbox_rounded),
                label: const Text('Requests for My Equipment'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RentalsList(mode: RentalsListMode.incomingRequests),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
