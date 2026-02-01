import 'dart:io';

import 'package:bukidbayan_app/blocs/request_bloc.dart';
import 'package:bukidbayan_app/blocs/request_event.dart';
import 'package:bukidbayan_app/blocs/request_state.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/services/auth_services.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class RequestSentPage extends StatelessWidget {
  final String requestId;

  const RequestSentPage({super.key, required this.requestId});

  // Format DateTime nicely
  String _formatDate(DateTime date) =>
      DateFormat('MMM dd, yyyy • hh:mm a').format(date);

  // Map status to step index
  int _getCurrentStep(RentRequestStatus status) {
    switch (status) {
      case RentRequestStatus.pending:
        return 0;
      case RentRequestStatus.approved:
        return 1;
      case RentRequestStatus.inProgress:
        return 2;
      case RentRequestStatus.completed:
        return 3;
      case RentRequestStatus.declined:
        return -1; // special case
    }
  }

  Widget _detailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

Widget _proofImage(String? path, String label) {
  if (path == null || path.isEmpty) return const SizedBox.shrink();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(path),
          height: 120,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    ],
  );
}


  @override
  Widget build(BuildContext context) {
    final steps = [
      'Request Received',
      'Being Processed',
      'In Progress',
      'Completed',
    ];


    return BlocProvider(
      create: (_) => RequestBloc()..add(LoadRequest(requestId)),
      child: BlocBuilder<RequestBloc, RequestState>(
        builder: (context, state) {
          if (state is RequestLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state is RequestError) {
            return Scaffold(
              body: Center(child: Text('Error loading request: ${state.message}')),
            );
          }

          if (state is RequestLoaded) {
            final request = state.request;
            final currentStep = _getCurrentStep(request.status);
            final currentUser = AuthService().currentUser;
            final isOwner = currentUser?.uid == request.ownerId; // <-- check owner
            final isRenter = currentUser?.uid == request.renterId;

            // Only show buttons if the user is the owner AND the request is not completed or declined
            // final showButtons = isOwner &&
            //     request.status != RentRequestStatus.completed &&
            //     request.status != RentRequestStatus.declined;

            final showButtons = isOwner && request.status == RentRequestStatus.pending;




            print('Current user: ${currentUser?.uid}, Renter ID: ${request.renterId}, isRenter: $isRenter');


            return Scaffold(
             appBar: AppBar(
              title: Text('Request Status', style: TextStyle(color: lightColorScheme.onPrimary)),
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      request.status == RentRequestStatus.declined
                          ? Icons.cancel
                          : Icons.check_circle_outline,
                      color: request.status == RentRequestStatus.declined
                          ? Colors.red
                          : lightColorScheme.primary,
                      size: 80,
                    ),
                    const SizedBox(height: 16),

                    Text(
                      request.status == RentRequestStatus.declined
                          ? 'Your request was declined.'
                          : 'Your request is being processed!',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),

                    /// 🔹 DETAILS SECTION
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Request Details',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),

                            _detailRow('Item', request.itemName),
                            _detailRow(
                              'Rental Period',
                              '${_formatDate(request.start)} → ${_formatDate(request.end)}',
                            ),

                            const Divider(height: 24),

                            const Text(
                              'Renter Information',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),

                            _detailRow('Name', request.name),
                            _detailRow('Address', request.address),

                            _proofImage(request.landSizeProofPath, 'Land Size Proof'),
                            _proofImage(request.cropHeightProofPath, 'Crop Height Proof'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    /// 🔹 STEP PROGRESS
                    if (request.status != RentRequestStatus.declined)
                      Column(
                        children: List.generate(steps.length, (index) {
                          final completed = index < currentStep;
                          final inProgress = index == currentStep;

                          return ListTile(
                            leading: Icon(
                              completed
                                  ? Icons.check_circle
                                  : inProgress
                                      ? Icons.autorenew
                                      : Icons.radio_button_unchecked,
                              color: completed
                                  ? Colors.green
                                  : inProgress
                                      ? Colors.orange
                                      : Colors.grey,
                            ),
                            title: Text(
                              steps[index],
                              style: TextStyle(
                                color: completed
                                    ? Colors.green
                                    : inProgress
                                        ? Colors.orange
                                        : Colors.grey,
                                fontWeight: inProgress ? FontWeight.bold : null,
                              ),
                            ),
                          );
                        }),
                      ),

                    const SizedBox(height: 16),

                    /// 🔹 OWNER ACTION BUTTONS
                    if (showButtons)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              context.read<RequestBloc>().add(
                                RequestStatusUpdated(request.requestId, RentRequestStatus.approved),
                              );
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('Approve'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              context.read<RequestBloc>().add(
                                RequestStatusUpdated(request.requestId, RentRequestStatus.declined),
                              );
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Decline'),
                          ),
                        ],
                      ),


                    const SizedBox(height: 16),

                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Back to Home'),
                    ),
                  ],
                ),
              ),


            );
          }

          return const Scaffold(
            body: Center(child: Text('Unknown state')),
          );
        },
      ),
    );
  }
}
