import 'package:bukidbayan_app/blocs/request_bloc.dart';
import 'package:bukidbayan_app/blocs/request_event.dart';
import 'package:bukidbayan_app/blocs/request_state.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/screens/rent/review_page.dart';
import 'package:bukidbayan_app/services/auth_services.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';

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
    case RentRequestStatus.onTheWay:
    case RentRequestStatus.inProgress:
    case RentRequestStatus.returned:
      return 2;
    case RentRequestStatus.finished: // lender finished
    case RentRequestStatus.completed: // renter left review
      return 3; // final green step
    case RentRequestStatus.declined:
      return -1;
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

Widget _proofImage(String? url, String label, BuildContext context) {
  if (url == null || url.isEmpty) return const SizedBox.shrink();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (_) => Dialog(
              insetPadding: const EdgeInsets.all(10),
              backgroundColor: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: PhotoView(
                    imageProvider: NetworkImage(url),
                    backgroundDecoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.9),
                    ),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3,
                  ),
                ),
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            height: 120,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
      ),
    ],
  );
}


String _statusHeadline(RentRequestStatus status) {
  switch (status) {
    case RentRequestStatus.pending:
      return 'Request Received';
    case RentRequestStatus.approved:
      return 'Request Approved';
    case RentRequestStatus.onTheWay:
      return 'Item Is On The Way';
    case RentRequestStatus.inProgress:
      return 'Rental In Progress';
    case RentRequestStatus.returned:
      return 'Item Returned';
    case RentRequestStatus.finished: // lender marked finished
      return 'Rental Finished';
    case RentRequestStatus.completed: // renter left review
      return 'Rental Completed';
    case RentRequestStatus.declined:
      return 'Request Declined';
  }
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
                      _statusHeadline(request.status),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 24),

                     /// 🔹 STEP PROGRESS
                    if (request.status != RentRequestStatus.declined)
                      /// 🔹 STATUS + PROGRESS (Grab-style)
                      Column(
                        children: [
                         _grabStyleStepper(
                          currentStep: currentStep,
                          icons: const [
                            Icons.receipt_long,
                            Icons.sync,
                            Icons.local_shipping,
                            Icons.home_filled,
                          ],
                          status: request.status, 
                        ),


                          const SizedBox(height: 8),

                          // Row(
                          //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          //   children: const [
                          //     Text('Requested', style: TextStyle(fontSize: 12)),
                          //     Text(
                          //       'Processing',
                          //       style: TextStyle(fontSize: 12),
                          //     ),
                          //     Text(
                          //       'In Progress',
                          //       style: TextStyle(fontSize: 12),
                          //     ),
                          //     Text('Completed', style: TextStyle(fontSize: 12)),
                          //   ],
                          // ),
                        ],
                      ),

                    const SizedBox(height: 16),

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

                            _proofImage(request.landSizeProofPath, 'Land Size Proof', context),
                            _proofImage(request.cropHeightProofPath, 'Crop Height Proof', context),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

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

                      if (isOwner && request.status == RentRequestStatus.approved)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              context.read<RequestBloc>().add(
                                RequestStatusUpdated(request.requestId, RentRequestStatus.onTheWay),
                              );
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: const Text('On The Way'),
                          ),
                        ],
                      ),

                      if (isRenter && request.status == RentRequestStatus.onTheWay)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                context.read<RequestBloc>().add(
                                  RequestStatusUpdated(
                                    request.requestId,
                                    RentRequestStatus.inProgress,
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              child: Text('Equipment Received', style: TextStyle(color: Colors.white),),
                            ),
                          ],
                        ),

                        if (isOwner && request.status == RentRequestStatus.onTheWay)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Waiting for renter to confirm equipment receipt',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),

                          if (isRenter && request.status == RentRequestStatus.inProgress)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    context.read<RequestBloc>().add(
                                      RequestStatusUpdated(
                                        request.requestId,
                                        RentRequestStatus.returned,
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                  child: const Text('Return Equipment'),
                                ),
                              ],
                            ),
                           
                            if (isOwner && request.status == RentRequestStatus.returned)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      context.read<RequestBloc>().add(
                                        RequestStatusUpdated(
                                          request.requestId,
                                          RentRequestStatus.finished,
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                    child: const Text('Confirm Return'),
                                  ),
                                ],
                              ),

                              /// 🔹 OWNER ACTION BUTTONS FOR COMPLETION
                                if (isOwner && request.status == RentRequestStatus.finished)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () {
                                          context.read<RequestBloc>().add(
                                            RequestStatusUpdated(
                                              request.requestId,
                                              RentRequestStatus.completed,
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                        child: const Text('Confirm Completion'),
                                      ),
                                    ],
                                  ),

                                /// 🔹 RENTER ACTION BUTTON FOR REVIEW
                                if (isRenter && request.status == RentRequestStatus.completed)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () {
                                          // Navigate to review page or open review dialog
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ReviewPage(
                                                requestId: request.requestId,
                                                lenderId: request.ownerId,
                                              ),
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                        child: const Text('Leave Review', style: TextStyle(color: Colors.white)),
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

  Widget _grabStyleStepper({
  required int currentStep,
  required List<IconData> icons,
  required RentRequestStatus status, // <- pass status
}) {
  return Row(
    children: List.generate(icons.length * 2 - 1, (index) {
      // ICON
      if (index.isEven) {
        final stepIndex = index ~/ 2;
        final isCompleted = stepIndex < currentStep || status == RentRequestStatus.completed;
        final isCurrent = stepIndex == currentStep && status != RentRequestStatus.completed;

        Color color;
        if (isCompleted) {
          color = Colors.green;
        } else if (isCurrent) {
          color = Colors.orange;
        } else {
          color = Colors.grey;
        }

        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.15),
          ),
          child: Icon(
            icons[stepIndex],
            color: color,
            size: 26,
          ),
        );
      }

      // LINE BETWEEN ICONS
      else {
        final lineIndex = (index - 1) ~/ 2;
        final isActive = lineIndex < currentStep || status == RentRequestStatus.completed;

        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            height: 4,
            decoration: BoxDecoration(
              color: isActive ? Colors.green : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }
    }),
  );
}


}
