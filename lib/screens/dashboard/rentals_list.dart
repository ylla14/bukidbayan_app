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

import 'package:bukidbayan_app/blocs/request_bloc.dart';
import 'package:bukidbayan_app/blocs/request_event.dart';
import 'package:bukidbayan_app/blocs/request_state.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/screens/rent/request_sent.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/services/rent_request_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum RentalsListMode {
  myRequests, // Rentals I submitted
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
  final FirestoreService _firestoreService = FirestoreService();
  List<RentRequest> _requests = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    // _loadRequests();
  }

  // Future<void> _loadRequests() async {
  //   final allRequests = await _requestService.getAllRequests();
  //   final currentUserId = _auth.currentUser!.uid;

  //   setState(() {
  //     if (widget.mode == RentalsListMode.myRequests) {
  //       _requests = allRequests
  //           .where((r) => r.renterId == currentUserId)
  //           .toList();
  //     } else {
  //       _requests = allRequests
  //           .where((r) => r.ownerId == currentUserId)
  //           .toList();
  //     }
  //   });
  // }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }

  String get _title {
    return widget.mode == RentalsListMode.myRequests
        ? 'My Rental Requests'
        : 'Requests for My Equipment';
  }

  Color _statusColor(RentRequestStatus status) {
    switch (status) {
      case RentRequestStatus.pending:
        return Colors.orange;
      case RentRequestStatus.approved:
        return Colors.blue;
      case RentRequestStatus.onTheWay:
        return Colors.indigo;
      case RentRequestStatus.inProgress:
        return Colors.deepPurple;
      case RentRequestStatus.returned:
        return Colors.teal;
      case RentRequestStatus.finished:
      case RentRequestStatus.completed:
        return Colors.green;
      case RentRequestStatus.declined:
        return Colors.red;
    }
  }

  String _statusLabel(RentRequestStatus status) {
    switch (status) {
      case RentRequestStatus.onTheWay:
        return "On The Way";
      case RentRequestStatus.inProgress:
        return "In Progress";
      default:
        return status.name[0].toUpperCase() + status.name.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _title,
          style: TextStyle(color: lightColorScheme.onPrimary, fontSize: 16),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [lightColorScheme.primary, lightColorScheme.secondary],
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<RentRequest>>(
        stream: widget.mode == RentalsListMode.myRequests
            ? _requestService.getRequestsByRenter(_auth.currentUser!.uid)
            : _requestService.getRequestsByOwner(_auth.currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return const Center(
              child: Text(
                'No rentals to display.',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final statusColor = _statusColor(request.status);

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// 🔹 TOP ROW — ITEM + STATUS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            request.itemName,
                            style: const TextStyle(
                              fontSize: 18, // was 16
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Text(
                            _statusLabel(request.status).toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13, // slightly bigger
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                     /// 🔹 SUBMITTED AT (NEW)
                    if (request.createdAt != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.schedule, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              "Submitted: ${DateFormat('MMM dd, yyyy • hh:mm a').format(request.createdAt!)}",
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),


                    /// 🔹 DATE RANGE
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "${DateFormat('MMM dd, yyyy').format(request.start)} - ${DateFormat('MMM dd, yyyy').format(request.end)}",
                            style: const TextStyle(
                              fontSize: 15, // bigger
                              fontWeight: FontWeight.w500,
                              color: Colors.black87, // darker
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    FutureBuilder<String?>(
                      future: widget.mode == RentalsListMode.incomingRequests
                          ? _firestoreService.getUserNameById(request.renterId)
                          : _firestoreService.getUserNameById(request.ownerId),
                      builder: (context, snapshot) {
                        final name = snapshot.data ?? "Loading name...";

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.person, size: 18, color: Colors.black87),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 6),

                    /// 🔹 ADDRESS
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            request.address,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    const Divider(),

                    /// 🔹 BUTTONS
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider(
                                    create: (_) =>
                                        RequestBloc()
                                          ..add(LoadRequest(request.requestId)),
                                    child: RequestSentPage(
                                      requestId: request.requestId,
                                    ),
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: lightColorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text("View"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Delete Request'),
                                  content: const Text(
                                    'Are you sure you want to delete this rental request?',
                                  ),
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
                                await _requestService.deleteRequest(request);

                                setState(() {
                                  _requests.remove(request);
                                });

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Request deleted'),
                                    ),
                                  );
                                }
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              "Delete",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}