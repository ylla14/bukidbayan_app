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
  final FirestoreService _firestoreService = FirestoreService();
  List<RentRequest> _requests = [];
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
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
      case RentRequestStatus.retrieving:
        return Colors.deepPurple;
      case RentRequestStatus.returned:
        return Colors.teal;
      case RentRequestStatus.finished:
      case RentRequestStatus.completed:
        return Colors.green;
      case RentRequestStatus.declined:
      case RentRequestStatus.canceled:
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

  /// Returns a display-friendly label for a given date.
  /// Shows "Today", "Yesterday", or a formatted date string.
  String _dateSectionLabel(DateTime date) {
    final now = DateTime.now();
    final today    = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target   = DateTime(date.year, date.month, date.day);

    if (target == today)     return 'Today';
    if (target == yesterday) return 'Yesterday';
    return DateFormat('MMMM dd, yyyy').format(date);
  }

  /// Normalises a DateTime to midnight so requests on the same calendar day
  /// collapse into the same group key.
  DateTime _dayKey(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  /// Builds a flat list of widgets — each group starts with a sticky-style
  /// date header, followed by its request cards.
  List<Widget> _buildGroupedList(List<RentRequest> requests) {
    // Sort newest-first
    final sorted = [...requests]..sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    final List<Widget> widgets = [];
    DateTime? lastKey;

    for (final request in sorted) {
      final submittedAt = request.createdAt;
      final key = submittedAt != null ? _dayKey(submittedAt) : null;

      // Insert a date header whenever the day changes
      if (key != lastKey) {
        lastKey = key;

        final label = key != null
            ? _dateSectionLabel(submittedAt!)
            : 'Unknown Date';

        widgets.add(_DateSectionHeader(label: label));
      }

      widgets.add(_RequestCard(
        request: request,
        mode: widget.mode,
        firestoreService: _firestoreService,
        requestService: _requestService,
        statusColor: _statusColor(request.status),
        statusLabel: _statusLabel(request.status),
        onDeleted: () => setState(() => _requests.remove(request)),
      ));
    }

    return widgets;
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
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return const Center(
              child: Text('No rentals to display.', style: TextStyle(fontSize: 16)),
            );
          }

          final groupedWidgets = _buildGroupedList(requests);

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: groupedWidgets.length,
            itemBuilder: (context, index) => groupedWidgets[index],
          );
        },
      ),
    );
  }
}

// ── Date Section Header ───────────────────────────────────────────────────────

class _DateSectionHeader extends StatelessWidget {
  final String label;

  const _DateSectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade400, thickness: 1.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.green.shade700,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.shade900.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month, size: 13, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade400, thickness: 1.5)),
        ],
      ),
    );
  }
}

// ── Request Card ──────────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final RentRequest request;
  final RentalsListMode mode;
  final FirestoreService firestoreService;
  final RentRequestService requestService;
  final Color statusColor;
  final String statusLabel;
  final VoidCallback onDeleted;

  const _RequestCard({
    required this.request,
    required this.mode,
    required this.firestoreService,
    required this.requestService,
    required this.statusColor,
    required this.statusLabel,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
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
          /// TOP ROW — ITEM + STATUS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  request.itemName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Text(
                  statusLabel.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          /// SUBMITTED AT
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

          /// DATE RANGE
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "${DateFormat('MMM dd, yyyy').format(request.start)} - ${DateFormat('MMM dd, yyyy').format(request.end)}",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          /// PERSON NAME
          FutureBuilder<String?>(
            future: mode == RentalsListMode.incomingRequests
                ? firestoreService.getUserNameById(request.renterId)
                : firestoreService.getUserNameById(request.ownerId),
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

          /// ADDRESS
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  request.address,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(),

          /// BUTTONS
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
                              RequestBloc()..add(LoadRequest(request.requestId)),
                          child: RequestSentPage(requestId: request.requestId),
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
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await FirestoreService()
                          .validateEquipmentAvailabilityWithNotification(request.itemId);
                      await requestService.deleteRequest(request);
                      onDeleted();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Request deleted')),
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
                  child: const Text("Delete", style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}