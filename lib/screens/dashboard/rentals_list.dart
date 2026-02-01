/// RentalsList is a UI screen responsible for displaying rental requests
/// based on the currently authenticated user.
///
/// This file does NOT directly send rental requests to the lender. Instead,
/// it controls how existing rent requests are fetched and presented:
///
/// - Fetches all rent requests from [RentRequestService].
/// - Filters requests based on the logged-in user:
///   • [RentalsListMode.myRequests] → requests submitted by the user (renter)
///   • [RentalsListMode.incomingRequests] → requests submitted *to* the user
///     as the equipment owner (lender)
/// - Displays each request with expandable details and proof uploads.
/// - Uses [RequestBloc] when navigating to the detailed request view to
///   load and react to request status updates.
///
/// In short, this screen acts as the *view controller* that determines
/// which rental requests are visible to a renter vs. a lender, based on
/// authentication context.
/// 
/// try mo ivisit si user a a and fine motion for tractor 2 request



import 'dart:io';
import 'package:bukidbayan_app/blocs/request_bloc.dart';
import 'package:bukidbayan_app/blocs/request_event.dart';
import 'package:bukidbayan_app/blocs/request_state.dart';
import 'package:bukidbayan_app/components/app_bar.dart';
import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/screens/rent/request_sent.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/services/rent_request_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:firebase_auth/firebase_auth.dart';

enum RentalsListMode {
  myRequests,       // Rentals I submitted
  incomingRequests, // Rentals submitted for my equipment
}

class RentalsList extends StatefulWidget {
  final RentalsListMode mode;

  const RentalsList({super.key, required this.mode});

  @override
  State<RentalsList> createState() => _RentalsListState();
}

class _RentalsListState extends State<RentalsList> {
  final RentRequestService _requestService = RentRequestService();
  List<RentRequest> _requests = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final allRequests = await _requestService.getAllRequests();
    final currentUserId = _auth.currentUser!.uid;

    setState(() {
      if (widget.mode == RentalsListMode.myRequests) {
        _requests = allRequests
            .where((r) => r.renterId == currentUserId)
            .toList();
      } else {
        _requests = allRequests
            .where((r) => r.ownerId == currentUserId)
            .toList();
      }
    });
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  String get _title {
    return widget.mode == RentalsListMode.myRequests
        ? 'My Rental Requests'
        : 'Requests for My Equipment';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title, style: TextStyle(color: lightColorScheme.onPrimary),),
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
            if (_requests.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('No rentals to display.'),
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
                      title: Text('Renter ID'),
                      subtitle: Text(request.renterId),
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
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                      child: Row(
                        children: [
                          // View Button
                          OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider(
                                    create: (_) =>
                                        RequestBloc()..add(LoadRequest(request.itemId)),
                                    child: BlocBuilder<RequestBloc, RequestState>(
                                      builder: (context, state) {
                                        if (state is RequestLoaded) {
                                          return RequestSentPage(
                                              requestId: request.itemId);
                                        } else if (state is RequestLoading) {
                                          return const Scaffold(
                                            body: Center(
                                                child:
                                                    CircularProgressIndicator()),
                                          );
                                        } else if (state is RequestError) {
                                          return Scaffold(
                                            body: Center(
                                                child: Text(
                                                    'Error: ${state.message}')),
                                          );
                                        } else {
                                          return const Scaffold(
                                            body: Center(
                                                child:
                                                    Text('Unknown state')),
                                          );
                                        }
                                      },
                                    ),
                                  ),
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
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
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
                                  _requests =
                                      List<RentRequest>.from(_requests)
                                        ..remove(request);
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
                                  const SnackBar(
                                      content: Text('Request deleted!')),
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
