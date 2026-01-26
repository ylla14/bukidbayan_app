import 'package:bukidbayan_app/components/app_bar.dart';
import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/services/rent_request_service.dart';
import 'package:bukidbayan_app/models/rentModel.dart';
import 'package:intl/intl.dart'; // For date formatting

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RentRequestService _requestService = RentRequestService();
  List<RentRequest> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  void _loadRequests() async {
    final requests = await _requestService.getAllRequests();
    setState(() {
      _requests = requests;
    });
  }

  void doSomething() {
    print("Home function called!");
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      drawer: CustomDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text('Welcome to HomeScreen', style: TextStyle(fontSize: 20)),
            // const SizedBox(height: 12),
            // ElevatedButton(
            //   onPressed: doSomething,
            //   child: Text('Do something'),
            // ),
            // const SizedBox(height: 20),
            Text('Submitted Rentals',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),

            /// ---------- Expandable List of Submitted Rentals ----------
            if (_requests.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No rentals submitted yet.'),
              ),
            ..._requests.map((request) {
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  title: Text(request.name, style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Item ID: ${request.itemId}'),
                  childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    ListTile(
                      dense: true,
                      title: Text('Address'),
                      subtitle: Text(request.address),
                    ),
                    ListTile(
                      dense: true,
                      title: Text('Start'),
                      subtitle: Text(_formatDate(request.start)),
                    ),
                    ListTile(
                      dense: true,
                      title: Text('End'),
                      subtitle: Text(_formatDate(request.end)),
                    ),
                    if (request.landSizeProofPath != null)
                      ListTile(
                        dense: true,
                        leading: Icon(Icons.check_circle, color: Colors.green),
                        title: Text('Land Proof Uploaded'),
                        subtitle: Text(request.landSizeProofPath!),
                      ),
                    if (request.cropHeightProofPath != null)
                      ListTile(
                        dense: true,
                        leading: Icon(Icons.check_circle, color: Colors.green),
                        title: Text('Crop Height Proof Uploaded'),
                        subtitle: Text(request.cropHeightProofPath!),
                      ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
