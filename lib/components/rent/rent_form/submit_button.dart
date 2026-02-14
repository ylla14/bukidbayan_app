import 'package:bukidbayan_app/blocs/request_bloc.dart';
import 'package:bukidbayan_app/blocs/request_event.dart';
import 'package:bukidbayan_app/blocs/request_state.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/screens/rent/request_sent.dart';
import 'package:bukidbayan_app/services/cloudinary_service.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:bukidbayan_app/services/rent_request_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/custom_snackbars.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

class SubmitButton extends StatefulWidget {
  final bool isStep2Complete;
  final DateTime startDate;
  final DateTime returnDate;
  final String name;
  final String address;
  final XFile? landSizeProof;
  final XFile? cropHeightProof;
  final Equipment item;
  final RentRequestService requestService;

  const SubmitButton({
    super.key,
    required this.isStep2Complete,
    required this.startDate,
    required this.returnDate,
    required this.name,
    required this.address,
    this.landSizeProof,
    this.cropHeightProof,
    required this.item,
    required this.requestService,
  });

  @override
  State<SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<SubmitButton> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: OutlinedButton(
        onPressed: _isSubmitting ? null : () => _handleSubmit(context),
        child: _isSubmitting
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    lightColorScheme.primary,
                  ),
                ),
              )
            : Text(
                'Submit',
                style: TextStyle(
                  color: lightColorScheme.primary,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }

  // In submit_button.dart - Line 59
Future<void> _handleSubmit(BuildContext context) async {
  // Step 1: Basic validation
  if (!widget.isStep2Complete) {
    showErrorSnackbar(
      context: context,
      title: 'Incomplete',
      message: 'Please complete all required fields',
    );
    return;
  }

  // Step 1.5: Check if equipment has availability dates
  if (widget.item.availableFrom == null || widget.item.availableUntil == null) {
    showErrorSnackbar(
      context: context,
      title: 'Not Available',
      message: 'This equipment does not have availability dates set.',
    );
    return;
  }

  setState(() => _isSubmitting = true);

    try {
      // Step 2: Check for date conflicts
      final firestoreService = FirestoreService();
      final hasConflict = await firestoreService.hasBookingConflict(
        widget.item.id!,
        widget.startDate,
        widget.returnDate,
      );

      if (hasConflict) {
        if (!mounted) return;
        showErrorSnackbar(
          context: context,
          title: 'Date Conflict',
          message: 'Ang mga petsang napili ay may naka-book na. Mangyaring pumili ng ibang petsa.',
        );
        setState(() => _isSubmitting = false);
        return;
      }

      // Step 3: Upload proof files to Cloudinary
      String? landPath;
      String? cropPath;
      final cloudinary = CloudinaryService();

      if (widget.landSizeProof != null) {
        landPath = await cloudinary.uploadImage(widget.landSizeProof!);
      }
      if (widget.cropHeightProof != null) {
        cropPath = await cloudinary.uploadImage(widget.cropHeightProof!);
      }

      // Step 4: Create request object
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      final request = RentRequest(
        requestId: '',
        itemId: widget.item.id ?? 'Unknown',
        itemName: widget.item.name,
        name: widget.name,
        address: widget.address,
        start: widget.startDate,
        end: widget.returnDate,
        landSizeProofPath: landPath,
        cropHeightProofPath: cropPath,
        status: RentRequestStatus.pending,
        renterId: currentUserId,
        ownerId: widget.item.ownerId,
      );

      // Step 5: Save request to Firestore
      final newRequestId = await widget.requestService.saveRequest(request);

       print('🔄 Request created, validating equipment availability...');
      await FirestoreService().validateEquipmentAvailabilityWithNotification(widget.item.id!);

      if (!mounted) return;

      // Step 6: Show success and navigate
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent!')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => RequestBloc()..add(LoadRequest(newRequestId)),
            child: BlocBuilder<RequestBloc, RequestState>(
              builder: (context, state) {
                if (state is RequestLoaded) {
                  return RequestSentPage(requestId: newRequestId);
                } else if (state is RequestLoading) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                } else if (state is RequestError) {
                  return Scaffold(
                    body: Center(child: Text('Error: ${state.message}')),
                  );
                } else {
                  return const Scaffold(
                    body: Center(child: Text('Unknown state')),
                  );
                }
              },
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      showErrorSnackbar(
        context: context,
        title: 'Error',
        message: 'Failed to submit request: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}