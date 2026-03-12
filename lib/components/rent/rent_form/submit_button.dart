import 'package:bukidbayan_app/blocs/request_bloc.dart';
import 'package:bukidbayan_app/blocs/request_event.dart';
import 'package:bukidbayan_app/blocs/request_state.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/screens/rent/request_sent.dart';
import 'package:bukidbayan_app/services/cloudinary_service.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:bukidbayan_app/services/rent_request_service.dart';
import 'package:bukidbayan_app/services/strike_service.dart';
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

  // ── Now lists ──────────────────────────────────────────────
  final List<XFile> landSizeProofs;
  final List<XFile> cropHeightProofs;

  final Equipment item;
  final RentRequestService requestService;
  final TextEditingController? volumeController;
  final bool keepDarak;
  final double? estimatedMillingFee;
  final String? farmAddress;
  final double? farmLatitude;
  final double? farmLongitude;
  final DeliveryMethod deliveryMethod;

  const SubmitButton({
    super.key,
    required this.isStep2Complete,
    required this.startDate,
    required this.returnDate,
    required this.name,
    required this.address,
    this.landSizeProofs = const [],
    this.cropHeightProofs = const [],
    required this.item,
    required this.requestService,
    this.volumeController,
    required this.keepDarak,
    required this.estimatedMillingFee,
    this.farmAddress,
    this.farmLatitude,
    this.farmLongitude,
    required this.deliveryMethod,
  });

  @override
  State<SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<SubmitButton> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    String _getRateSuffix(String rentRate) {
      switch (rentRate.toLowerCase()) {
        case 'per day':
          return '/day';
        case 'per hour':
          return '/hour';
        case 'per week':
          return '/week';
        case 'per month':
          return '/month';
        default:
          return '';
      }
    }

    final isHarvester = widget.item.category?.toLowerCase() == 'harvester';
    final isRiceMill =
        widget.item.category?.toLowerCase().contains('rice mill') == true;

    return Column(
      children: [
        // ── Price Summary Card ──────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            border: Border.all(color: Colors.green.shade200),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Price Summary',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),

              if (isRiceMill) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pricing Type',
                        style: TextStyle(fontSize: 15, color: Colors.black54)),
                    Text(
                      widget.keepDarak ? 'Rice + Darak' : 'Rice Only',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Rate',
                        style: TextStyle(fontSize: 15, color: Colors.black54)),
                    Text(
                      widget.keepDarak
                          ? '₱${widget.item.ricePlusDarakPricePerKg?.toStringAsFixed(2) ?? '3.00'}/kg'
                          : '₱${widget.item.riceOnlyPricePerKg?.toStringAsFixed(2) ?? '2.00'}/kg',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ],
                ),
                if (widget.estimatedMillingFee != null) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Estimated Total',
                          style:
                              TextStyle(fontSize: 15, color: Colors.black54)),
                      Text(
                        '₱${widget.estimatedMillingFee!.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                    ],
                  ),
                ],
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Rental Rate',
                        style: TextStyle(fontSize: 15, color: Colors.black54)),
                    Text(
                      '₱${widget.item.price} ${_getRateSuffix(widget.item.rentalUnit)}',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ],
                ),
                if (isHarvester) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Additional Fee',
                          style:
                              TextStyle(fontSize: 15, color: Colors.black54)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange.shade300),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '+ 12% of Crop Harvest',
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.deepOrange,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ],

              // Delivery method
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Method',
                      style: TextStyle(fontSize: 15, color: Colors.black54)),
                  Row(
                    children: [
                      Icon(
                        widget.deliveryMethod == DeliveryMethod.pickup
                            ? Icons.directions_walk_rounded
                            : Icons.local_shipping_rounded,
                        size: 16,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.deliveryMethod == DeliveryMethod.pickup
                            ? 'Pick Up'
                            : 'Delivery',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Submit button ───────────────────────────────────
        Align(
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
                          lightColorScheme.primary),
                    ),
                  )
                : Text(
                    'Submit',
                    style: TextStyle(
                      color: lightColorScheme.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSubmit(BuildContext context) async {
    final isRiceMill =
        widget.item.category?.toLowerCase().contains('rice mill') == true;

    if (!widget.isStep2Complete) {
      showErrorSnackbar(
        context: context,
        title: 'Incomplete',
        message: 'Please complete all required fields',
      );
      return;
    }

    if (widget.item.minimumVolumeRequired &&
        widget.item.minimumVolumeKg != null) {
      final entered = double.tryParse(widget.volumeController?.text ?? '') ?? 0;
      final minInUnit = widget.item.minimumVolumeUnit == 'cavans'
          ? widget.item.minimumVolumeKg! / 50
          : widget.item.minimumVolumeKg!;

      if (entered < minInUnit) {
        if (widget.item.batchingAllowed) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Hindi Sapat ang Dami'),
              content: Text(
                'Ang iyong dami (${entered.toStringAsFixed(0)} ${widget.item.minimumVolumeUnit}) '
                'ay mas mababa sa minimum na ${minInUnit.toStringAsFixed(0)} ${widget.item.minimumVolumeUnit}. '
                'Iminumungkahi ng may-ari na mag-batch kasama ang ibang magsasaka. '
                'Gusto mo pa ring i-submit?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Submit Anyway'),
                ),
              ],
            ),
          );
          if (confirm != true) return;
        } else {
          showErrorSnackbar(
            context: context,
            title: 'Hindi Sapat ang Dami',
            message:
                'Minimum ay ${minInUnit.toStringAsFixed(0)} ${widget.item.minimumVolumeUnit}.',
          );
          return;
        }
      }
    }

    if (widget.item.availableFrom == null ||
        widget.item.availableUntil == null) {
      showErrorSnackbar(
        context: context,
        title: 'Not Available',
        message: 'This equipment does not have availability dates set.',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      // Block submission if the renter has 3+ strikes
      final blockedUntil =
          await StrikeService().blockedUntil(currentUserId);
      if (blockedUntil != null) {
        if (!mounted) return;
        final unblockDate =
            '${blockedUntil.day}/${blockedUntil.month}/${blockedUntil.year}';
        showErrorSnackbar(
          context: context,
          title: 'Account Suspended',
          message:
              'Hindi ka maaaring mag-request ng kagamitan hanggang $unblockDate '
              'dahil sa 3 strikes sa iyong account.',
        );
        setState(() => _isSubmitting = false);
        return;
      }

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
          message:
              'Ang mga petsang napili ay may naka-book na. Mangyaring pumili ng ibang petsa.',
        );
        setState(() => _isSubmitting = false);
        return;
      }

      final cloudinary = CloudinaryService();

      // ── Upload all land-size proof files in parallel ───────
      final landPaths = await Future.wait(
        widget.landSizeProofs.map((f) => cloudinary.uploadImage(f)),
      );

      // ── Upload all crop-height proof files in parallel ─────
      final cropPaths = await Future.wait(
        widget.cropHeightProofs.map((f) => cloudinary.uploadImage(f)),
      );

      final request = RentRequest(
        requestId: '',
        itemId: widget.item.id ?? 'Unknown',
        itemName: widget.item.name,
        name: widget.name,
        address: widget.address,
        start: widget.startDate,
        end: widget.returnDate,
        landSizeProofPaths: landPaths,   // ← list
        cropHeightProofPaths: cropPaths, // ← list
        status: RentRequestStatus.pending,
        renterId: currentUserId,
        ownerId: widget.item.ownerId,
        volumeSubmitted:
            double.tryParse(widget.volumeController?.text ?? ''),
        keepDarak: widget.keepDarak,
        estimatedMillingFee: widget.estimatedMillingFee,
        agreedPrice: isRiceMill
            ? (widget.keepDarak
                ? widget.item.ricePlusDarakPricePerKg ?? 3.0
                : widget.item.riceOnlyPricePerKg ?? 2.0)
            : widget.item.price,
        agreedRentalUnit: widget.item.rentalUnit,
        deliveryMethod: widget.deliveryMethod,
        farmAddress: widget.farmAddress,
        farmLatitude: widget.farmLatitude,
        farmLongitude: widget.farmLongitude,
      );

      final newRequestId = await widget.requestService.saveRequest(request);

      print('🔄 Request created, validating equipment availability...');
      await FirestoreService().validateEquipmentAvailabilityWithNotification(
        widget.item.id!,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Request sent!')));

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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}