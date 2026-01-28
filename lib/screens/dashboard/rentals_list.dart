import 'dart:io';
import 'package:bukidbayan_app/components/app_bar.dart';
import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/screens/rent/request_sent.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/custom_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/services/rent_request_service.dart';
import 'package:intl/intl.dart'; // For date formatting

class RentalsList extends StatefulWidget {
  const RentalsList({super.key});

  @override
  State<RentalsList> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<RentalsList> {
  final RentRequestService _requestService = RentRequestService();
  List<RentRequest> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final requests = await _requestService.getAllRequests();
    setState(() => _requests = requests);
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [lightColorScheme.primary, lightColorScheme.secondary],
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  title: Text(request.itemName,
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Item ID: ${request.itemId}'),
                  childrenPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

                    /// DELETE BUTTON
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      child: Row(
                        children: [
                    
                          // View Button
                          OutlinedButton(
                            onPressed: () {
                              // Navigate to request details page
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RequestSentPage(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: lightColorScheme.primary),
                            ),
                            child: Text(
                              'View',
                              style: TextStyle(color: lightColorScheme.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                    
                          // Delete Button
                          OutlinedButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Confirm Delete'),
                                  content: const Text(
                                      'Are you sure you want to delete this rental request?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                    
                              if (confirm == true) {
                                // Remove from list
                                setState(() {
                                  _requests = List<RentRequest>.from(_requests)..remove(request);
                                });
                    
                                // Save updated list
                                await _requestService.saveAllRequests(_requests);
                    
                                // Delete proof images if any
                                if (request.landSizeProofPath != null) {
                                  final file = File(request.landSizeProofPath!);
                                  if (await file.exists()) await file.delete();
                                }
                                if (request.cropHeightProofPath != null) {
                                  final file = File(request.cropHeightProofPath!);
                                  if (await file.exists()) await file.delete();
                                }
                    
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Request deleted!')),
                                );
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                            ),
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
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
