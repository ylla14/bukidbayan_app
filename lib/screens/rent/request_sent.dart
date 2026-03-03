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
    case RentRequestStatus.retrieving:
    case RentRequestStatus.returned:
      return 2;
    case RentRequestStatus.finished: // lender finished
    case RentRequestStatus.completed: // renter left review
      return 3; // final green step
    case RentRequestStatus.declined:
    case RentRequestStatus.canceled:
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
    case RentRequestStatus.retrieving:
      return 'Owner Is Retrieving Equipment';
    case RentRequestStatus.returned:
      return 'Item Returned';
    case RentRequestStatus.finished: // lender marked finished
      return 'Rental Finished';
    case RentRequestStatus.completed: // renter left review
      return 'Rental Completed';
    case RentRequestStatus.declined:
      return 'Request Declined';
    case RentRequestStatus.canceled:
      return 'Request Cancelled';

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

            final now = DateTime.now();
            final oneDay = const Duration(days: 1);
            final isWithinReturnWindow = now.isAfter(request.start.subtract(oneDay)) && 
                                          now.isBefore(request.end.add(oneDay));
            final isOverdue = now.isAfter(request.end);

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
                      request.status == RentRequestStatus.declined || request.status == RentRequestStatus.canceled
                          ? Icons.cancel
                          : Icons.check_circle_outline,
                      color: request.status == RentRequestStatus.declined || request.status == RentRequestStatus.canceled
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
                    if (request.status != RentRequestStatus.declined && request.status != RentRequestStatus.canceled)
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

                            if (request.status == RentRequestStatus.declined &&
                                request.declineReason != null) ...[
                              const Divider(height: 24),
                              const Text(
                                'Dahilan ng Pagtanggi',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: Colors.red, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        request.declineReason!,
                                        style: TextStyle(color: Colors.red.shade800),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
                         // Replace the existing Decline ElevatedButton with this:
                          ElevatedButton(
                            onPressed: () => _showDeclineDialog(context, request.requestId),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: const Text('Decline', style: TextStyle(color: Colors.white)),
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

                      // ── RENTER: cancel (pending or within 24h of approval) ──
if (isRenter && _canRenterCancel(request))
  Padding(
    padding: const EdgeInsets.only(top: 8),
    child: OutlinedButton.icon(
      onPressed: () => _showCancelDialog(context, request.requestId, isRenter: true),
      icon: const Icon(Icons.cancel_outlined, color: Colors.red),
      label: const Text('Cancel Request', style: TextStyle(color: Colors.red)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.red),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  ),

// ── OWNER: cancel (pending or approved, up until onTheWay) ──
if (isOwner && _canOwnerCancel(request))
  Padding(
    padding: const EdgeInsets.only(top: 8),
    child: OutlinedButton.icon(
      onPressed: () => _showCancelDialog(context, request.requestId, isRenter: false),
      icon: const Icon(Icons.cancel_outlined, color: Colors.red),
      label: const Text('Cancel Request', style: TextStyle(color: Colors.red)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.red),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
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

                          if (isRenter && request.status == RentRequestStatus.inProgress) ...[

                           // Show overdue warning if past end date and not yet returned
                            if (isOverdue)
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.red.shade300),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Return period has ended. Please return the equipment immediately and contact the lender.',
                                        style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                            if (isWithinReturnWindow)
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
                                    style: ElevatedButton.styleFrom(backgroundColor: lightColorScheme.primary),
                                    child: Text('Return Equipment', style: TextStyle(color: lightColorScheme.onPrimary)),
                                  ),
                                ],
                              ),
                          ],

                          // ── RENTER: return button (within window) ──
                          if (isRenter && request.status == RentRequestStatus.inProgress) ...[
                            if (isOverdue)
                              Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.red.shade300),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Colors.red),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Return period has ended. Please return the equipment immediately and contact the lender.',
                                        style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (isWithinReturnWindow)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  ElevatedButton(
                                    onPressed: () {
                                      context.read<RequestBloc>().add(
                                        RequestStatusUpdated(request.requestId, RentRequestStatus.returned),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: lightColorScheme.primary),
                                    child: Text('Return Equipment', style: TextStyle(color: lightColorScheme.onPrimary)),
                                  ),
                                ],
                              ),
                          ],

                          // ── OWNER: on the way to retrieve (overdue) ──
                          if (isOwner && request.status == RentRequestStatus.inProgress && isOverdue)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    context.read<RequestBloc>().add(
                                      RequestStatusUpdated(request.requestId, RentRequestStatus.retrieving),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                  child: const Text('On My Way to Retrieve', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),

                          // ── RENTER: owner is coming banner ──
                          if (isRenter && request.status == RentRequestStatus.retrieving)
                            Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.orange.shade300),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.directions_car, color: Colors.orange),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text('The owner is on the way to retrieve the equipment. Please have it ready.'),
                                  ),
                                ],
                              ),
                            ),

                          // ── OWNER: confirm they got it back (PATH B) ──
                          if (isOwner && request.status == RentRequestStatus.retrieving)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    context.read<RequestBloc>().add(
                                      RequestStatusUpdated(request.requestId, RentRequestStatus.finished), // skips returned
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  child: const Text('Confirm Retrieved', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),

                          // ── OWNER: renter dropped it off themselves (PATH A) ──
                          if (isOwner && request.status == RentRequestStatus.returned)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    context.read<RequestBloc>().add(
                                      RequestStatusUpdated(request.requestId, RentRequestStatus.finished),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  child: const Text('Confirm Return', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),

                          // ── OWNER: condition report before completing ──
                          if (isOwner && request.status == RentRequestStatus.finished)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    _showEquipmentConditionDialog(context, request.requestId);
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                  child: const Text('Confirm Completion', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),

                          // ── RENTER: leave review ──
                          if (isRenter && request.status == RentRequestStatus.completed)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ReviewPage(
                                          requestId: request.requestId,
                                          lenderId: request.ownerId,
                                          itemId: request.itemId,
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

void _showDeclineDialog(BuildContext context, String requestId) {
  String? selectedReason;
  final otherController = TextEditingController();
  final requestBloc = context.read<RequestBloc>();

  final reasons = [
    'Hindi nakakatugon sa mga kinakailangan',
    'Hindi angkop ang laki ng lupa',
    'Hindi angkop ang taas ng pananim',
    'Maraming naitatalang paglabag',
    'Hindi kumpleto ang mga dokumento',
    'Kasalukuyang ginagamit ang kagamitan',
    'Hindi available sa napiling petsa',
    'Iba pang dahilan',
  ];

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (_, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Dahilan ng Pagtanggi',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Pumili ng dahilan para sa pagtanggi ng kahilingan:',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  ...reasons.map((reason) => RadioListTile<String>(
                    value: reason,
                    groupValue: selectedReason,
                    title: Text(reason, style: const TextStyle(fontSize: 13)),
                    onChanged: (val) => setState(() => selectedReason = val),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),

                  // 👇 SHOW TEXT FIELD ONLY WHEN "Iba pang dahilan" IS SELECTED
                  if (selectedReason == 'Iba pang dahilan') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: otherController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Ipaliwanag ang dahilan...',
                        hintStyle: const TextStyle(fontSize: 13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  otherController.dispose(); // 👈 clean up
                  Navigator.pop(dialogContext);
                },
                child: const Text('Kanselahin'),
              ),
              ElevatedButton(
                onPressed: selectedReason == null
                    ? null
                    : () {
                        // If "Iba pang dahilan", use the text field value (if filled), else use the selected reason
                        final finalReason = selectedReason == 'Iba pang dahilan' && otherController.text.trim().isNotEmpty
                            ? 'Iba pang dahilan: ${otherController.text.trim()}'
                            : selectedReason!;

                        Navigator.pop(dialogContext);
                        requestBloc.add(
                          RequestStatusUpdated(
                            requestId,
                            RentRequestStatus.declined,
                            declineReason: finalReason,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Tanggihan', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      );
    },
  );
}

void _showEquipmentConditionDialog(BuildContext context, String requestId) {
  bool? equipmentGood;
  final commentController = TextEditingController();
  final maintenanceDaysController = TextEditingController();
  final requestBloc = context.read<RequestBloc>();

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (_, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Equipment Condition Report',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Please fill out this form before completing the rental.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),

                  // ─── Equipment Good? ───
                  const Text(
                    'Is the equipment in good condition?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => equipmentGood = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: equipmentGood == true
                                  ? Colors.green
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: equipmentGood == true
                                    ? Colors.green
                                    : Colors.grey.shade400,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: equipmentGood == true
                                      ? Colors.white
                                      : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Yes',
                                  style: TextStyle(
                                    color: equipmentGood == true
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => equipmentGood = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: equipmentGood == false
                                  ? Colors.red
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: equipmentGood == false
                                    ? Colors.red
                                    : Colors.grey.shade400,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cancel,
                                  color: equipmentGood == false
                                      ? Colors.white
                                      : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'No',
                                  style: TextStyle(
                                    color: equipmentGood == false
                                        ? Colors.white
                                        : Colors.grey.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ─── Shown only if equipment NOT good ───
                  if (equipmentGood == false) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Describe the issue:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'e.g. Broken blade, engine not starting...',
                        hintStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Estimated maintenance duration (days):',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: maintenanceDaysController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'e.g. 3',
                        hintStyle: const TextStyle(fontSize: 12),
                        suffixText: 'days',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  commentController.dispose();
                  maintenanceDaysController.dispose();
                  Navigator.pop(dialogContext);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: equipmentGood == null
                    ? null // disabled until Y/N is selected
                    : () {
                        Navigator.pop(dialogContext);

                        // TODO: You can save equipmentGood, comment, and maintenanceDays
                        // to Firestore here if needed before dispatching the status update.
                        // Example:
                        // FirebaseFirestore.instance
                        //   .collection('requests')
                        //   .doc(requestId)
                        //   .update({
                        //     'equipmentConditionGood': equipmentGood,
                        //     'conditionComment': commentController.text.trim(),
                        //     'maintenanceDays': int.tryParse(maintenanceDaysController.text) ?? 0,
                        //   });

                        requestBloc.add(
                          RequestStatusUpdated(
                            requestId,
                            RentRequestStatus.completed,
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text(
                  'Submit & Complete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

void _showCancelDialog(BuildContext context, String requestId, {required bool isRenter}) {
  final requestBloc = context.read<RequestBloc>();

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Cancel Request', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Text(
        isRenter
            ? 'Are you sure you want to cancel this rental request? This cannot be undone.'
            : 'Are you sure you want to cancel this request? The renter will be notified.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Go Back'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            requestBloc.add(
              RequestStatusUpdated(requestId, RentRequestStatus.canceled),
            );
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

bool _canRenterCancel(RentRequest request) {
  if (request.status == RentRequestStatus.pending) return true;
  if (request.status == RentRequestStatus.approved) {
    // Allow cancel within 24 hours of approval — use createdAt as proxy if no approvedAt field
    // OR just allow while approved and not yet onTheWay
    final approvedAt = request.createdAt; // ideally you'd store approvedAt separately
    if (approvedAt != null) {
      return DateTime.now().difference(approvedAt).inHours < 24;
    }
    return true; // fallback: allow if no timestamp
  }
  return false;
}

bool _canOwnerCancel(RentRequest request) {
  return request.status == RentRequestStatus.pending ||
         request.status == RentRequestStatus.approved;
}

}
