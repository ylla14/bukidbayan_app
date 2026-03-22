import 'package:bukidbayan_app/blocs/request_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bukidbayan_app/blocs/request_event.dart';
import 'package:bukidbayan_app/blocs/request_state.dart';
import 'package:bukidbayan_app/components/rent/ndvi_card.dart';
import 'package:bukidbayan_app/components/rent/proof_page_viewer.dart';
import 'package:bukidbayan_app/models/equipment.dart';
import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/screens/rent/report_renter_page.dart';
import 'package:bukidbayan_app/screens/rent/review_page.dart';
import 'package:bukidbayan_app/services/auth_services.dart';
import 'package:bukidbayan_app/services/maintenance_service.dart';
import 'package:bukidbayan_app/services/rent_request_service.dart';
import 'package:bukidbayan_app/services/strike_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';

class RequestSentPage extends StatefulWidget {
  final String requestId;

  const RequestSentPage({super.key, required this.requestId});

  @override
  State<RequestSentPage> createState() => _RequestSentPageState();
}

/// GDrive PDF manual links keyed by equipment category name.
const Map<String, String> _equipmentManuals = {
  'Tractor'               : 'https://drive.google.com/file/d/1YaSltUq4k_opJgI4nLuvoJDGQvykPKaL/view?usp=sharing',
  'Harvester (Halimaw)'   : 'https://drive.google.com/file/d/1D3v2BXKderLv-kTOUmY4nE4hVgjZD_Gf/view?usp=sharing',
  'Floating Tiller (Pagong)': 'https://drive.google.com/file/d/18ICD5LJTUg9LJLjsqciVypuTSHHNxIKr/view?usp=sharing',
  'Hand Tractor (Kuliglig)': 'https://drive.google.com/file/d/1Iq4D7xfAoCtS5CqKEQivsHXQu_B-Yn7w/view?usp=sharing',
};

/// YouTube tutorial links keyed by equipment category.
/// Only shown for equipment rented WITHOUT an operator.
const Map<String, String> _equipmentTutorials = {
  'Tractor'                 : 'https://youtu.be/H66et2wlv08?si=f1wnpzYOi-JXOjIw',
  'Hand Tractor (Kuliglig)' : 'https://youtu.be/gSlqgjwvnkE?si=5d7dRWxUBljb1yYk',
  'Harvester (Halimaw)'     : 'https://youtu.be/gSlqgjwvnkE?si=5d7dRWxUBljb1yYk',
  'Floating Tiller (Pagong)': 'https://youtu.be/S1VAxvalLBg?si=h7xGEpT3chPnuBCJ',
};

class _RequestSentPageState extends State<RequestSentPage> {
  /// Prevents issuing late-strikes more than once per screen session.
  bool _lateStrikesChecked = false;

  String _formatDate(DateTime date) =>
      DateFormat('MMM dd, yyyy • hh:mm a').format(date);

  String _formatDateShort(DateTime date) =>
      DateFormat('MMM dd, yyyy').format(date);

  int _getCurrentStep(RentRequestStatus status) {
  switch (status) {
    case RentRequestStatus.pending:
      return 0;
    case RentRequestStatus.approved:
      return 1;
    case RentRequestStatus.readyForPickup: // ✅
    case RentRequestStatus.pickedUp:       // ✅
    case RentRequestStatus.onTheWay:
    case RentRequestStatus.inProgress:
    case RentRequestStatus.retrieving:
    case RentRequestStatus.returned:
      return 2;
    case RentRequestStatus.finished:
    case RentRequestStatus.completed:
      return 3;
    case RentRequestStatus.declined:
    case RentRequestStatus.canceled:
      return -1;
  }
}

  Color _statusColor(RentRequestStatus status) {
    switch (status) {
      case RentRequestStatus.pending:
        return const Color(0xFFF59E0B);
      case RentRequestStatus.approved:
        return const Color(0xFF3B82F6);
      case RentRequestStatus.readyForPickup: // ✅
      case RentRequestStatus.pickedUp:       // ✅
      case RentRequestStatus.onTheWay:
      case RentRequestStatus.inProgress:
        return const Color(0xFF8B5CF6);
      case RentRequestStatus.retrieving:
      case RentRequestStatus.returned:
        return const Color(0xFF06B6D4);
      case RentRequestStatus.finished:
      case RentRequestStatus.completed:
        return const Color(0xFF10B981);
      case RentRequestStatus.declined:
      case RentRequestStatus.canceled:
        return const Color(0xFFEF4444);
    }
  }

  IconData _statusIcon(RentRequestStatus status) {
    switch (status) {
      case RentRequestStatus.pending:
        return Icons.hourglass_empty_rounded;
      case RentRequestStatus.approved:
        return Icons.check_circle_rounded;
      case RentRequestStatus.readyForPickup: // ✅
        return Icons.store_rounded;
      case RentRequestStatus.pickedUp:       // ✅
        return Icons.directions_walk_rounded;
      case RentRequestStatus.onTheWay:
        return Icons.local_shipping_rounded;
      case RentRequestStatus.inProgress:
        return Icons.agriculture_rounded;
      case RentRequestStatus.retrieving:
        return Icons.directions_car_rounded;
      case RentRequestStatus.returned:
        return Icons.assignment_return_rounded;
      case RentRequestStatus.finished:
        return Icons.task_alt_rounded;
      case RentRequestStatus.completed:
        return Icons.star_rounded;
      case RentRequestStatus.declined:
        return Icons.cancel_rounded;
      case RentRequestStatus.canceled:
        return Icons.remove_circle_rounded;
    }
  }

  String _statusHeadline(RentRequestStatus status) {
    switch (status) {
      case RentRequestStatus.pending:
        return 'Request Received';
      case RentRequestStatus.approved:
        return 'Request Approved';
      case RentRequestStatus.readyForPickup: // ✅
        return 'Ready for Pick Up';
      case RentRequestStatus.pickedUp:       // ✅
        return 'Equipment Picked Up';
      case RentRequestStatus.onTheWay:
        return 'Item Is On The Way';
      case RentRequestStatus.inProgress:
        return 'Rental In Progress';
      case RentRequestStatus.retrieving:
        return 'Owner Is Retrieving Equipment';
      case RentRequestStatus.returned:
        return 'Item Returned';
      case RentRequestStatus.finished:
        return 'Rental Finished';
      case RentRequestStatus.completed:
        return 'Rental Completed';
      case RentRequestStatus.declined:
        return 'Request Declined';
      case RentRequestStatus.canceled:
        return 'Request Cancelled';
    }
  }

  String _statusSubtitle(RentRequestStatus status) {
    switch (status) {
      case RentRequestStatus.pending:
        return 'Waiting for owner to review your request';
      case RentRequestStatus.approved:
        return 'The owner has approved your rental request';
      case RentRequestStatus.readyForPickup: // ✅
        return 'The equipment is ready — head over to collect it';
      case RentRequestStatus.pickedUp:       // ✅
        return 'You have collected the equipment. Rental is now active';
      case RentRequestStatus.onTheWay:
        return 'The equipment is being delivered to you';
      case RentRequestStatus.inProgress:
        return 'Your rental is currently active';
      case RentRequestStatus.retrieving:
        return 'The owner is coming to retrieve the equipment';
      case RentRequestStatus.returned:
        return 'Equipment has been returned to the owner';
      case RentRequestStatus.finished:
        return 'The owner has confirmed completion';
      case RentRequestStatus.completed:
        return 'This rental has been successfully completed';
      case RentRequestStatus.declined:
        return 'The owner has declined this request';
      case RentRequestStatus.canceled:
        return 'This request has been cancelled';
    }
  }

  String _getRateSuffix(String rentRate) {
    switch (rentRate.toLowerCase()) {
      case 'per day': return '/day';
      case 'per hour': return '/hr';
      case 'per week': return '/week';
      case 'per month': return '/mo';
      case 'per kg': return '/kg';
      case 'per hectare':
        return '/ha';
      default: return '';
    }
  }

  Widget _infoTile(IconData icon, String label, String value, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children, Color? accentColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                if (accentColor != null)
                  Container(
                    width: 3,
                    height: 16,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                        letterSpacing: 0.8)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resourceCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required String buttonLabel,
    required IconData buttonIcon,
    required String url,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2563EB), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1D4ED8),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E40AF),
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: Icon(buttonIcon, size: 16),
            label: Text(buttonLabel),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF2563EB),
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required VoidCallback onPressed,
    required Color color,
    IconData? icon,
    bool outlined = false,
  }) {
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon ?? Icons.close, color: color, size: 18),
          label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: color.withOpacity(0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.check, color: Colors.white, size: 18),
        label: Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _proofImage(String? url, String label, BuildContext context) {
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
                letterSpacing: 0.5)),
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
                      backgroundDecoration:
                          BoxDecoration(color: Colors.black.withOpacity(0.9)),
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 3,
                    ),
                  ),
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Image.network(url,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.zoom_in, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text('Tap to view',
                            style: TextStyle(color: Colors.white, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Add this near the top of the class (alongside other helpers)
Future<Map<String, dynamic>?> _fetchOwnerProfile(String ownerId) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')       // ← adjust to your users collection name
      .doc(ownerId)
      .get();
  return doc.exists ? doc.data() as Map<String, dynamic> : null;
}

Future<bool> _hasLeftReview(String requestId) async {
  final doc = await FirebaseFirestore.instance
      .collection('reviews')  // adjust to your collection name
      .where('requestId', isEqualTo: requestId)
      .where('renterId', isEqualTo: AuthService().currentUser?.uid)
      .limit(1)
      .get();
  return doc.docs.isNotEmpty;
}

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => RequestBloc()..add(LoadRequest(widget.requestId)),
      child: BlocBuilder<RequestBloc, RequestState>(
        builder: (context, state) {
          if (state is RequestLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (state is RequestError) {
            return Scaffold(
              body: Center(child: Text('Error: ${state.message}')),
            );
          }

          if (state is RequestLoaded) {
            final request = state.request;
            final currentStep = _getCurrentStep(request.status);
            final currentUser = AuthService().currentUser;
            final isOwner = currentUser?.uid == request.ownerId;
            final isRenter = currentUser?.uid == request.renterId;
            final statusColor = _statusColor(request.status);

            final now = DateTime.now();
            final isWithinReturnWindow =
                now.isAfter(request.start.subtract(const Duration(days: 1))) &&
                now.isBefore(request.end.add(const Duration(days: 1)));
            final isOverdue = now.isAfter(request.end);
            final daysOverdue = isOverdue
                ? now.difference(request.end).inDays
                : 0;

            // ── Late-return strike check (Case 4) ─────────────────────────
            if (!_lateStrikesChecked &&
                isOverdue &&
                request.status == RentRequestStatus.inProgress) {
              _lateStrikesChecked = true;
              StrikeService().issueLateDayStrikes(
                requestId               : widget.requestId,
                renterId                : request.renterId,
                ownerId                 : request.ownerId,
                endDate                 : request.end,
                lastLateStrikeIssuedDate: request.lastLateStrikeIssuedDate,
              );
            }
            final isTerminal = request.status == RentRequestStatus.declined ||
                request.status == RentRequestStatus.canceled;
            final showApproveDecline =
                isOwner && request.status == RentRequestStatus.pending;

            return Scaffold(
              backgroundColor: const Color(0xFFF5F7FA),
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [lightColorScheme.primary, lightColorScheme.secondary],
                    ),
                  ),
                ),
                title: const Text('Request Status',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 17)),
                centerTitle: true,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    // ── HERO STATUS BANNER ──
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [lightColorScheme.primary, lightColorScheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          // Stepper inside banner
                          if (!isTerminal)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: _grabStyleStepper(
                                currentStep: currentStep,
                                icons: const [
                                  Icons.receipt_long_rounded,
                                  Icons.sync_rounded,
                                  Icons.local_shipping_rounded,
                                  Icons.home_rounded,
                                ],
                                status: request.status,
                              ),
                            ),
                          const SizedBox(height: 20),
                          // Status icon
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _statusIcon(request.status),
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _statusHeadline(request.status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              _statusSubtitle(request.status),
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Item name pill
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.agriculture_rounded,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  request.itemName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── CONTENT ──
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── RENTAL PERIOD ──
                          _sectionCard(
                            title: 'RENTAL PERIOD',
                            accentColor: statusColor,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _dateBox(
                                        'Start', request.start, Icons.play_circle_outline, Colors.green),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _dateBox(
                                        'End', request.end, Icons.stop_circle_outlined, Colors.red),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // ── PRICING ──
                          _sectionCard(
                            title: 'PRICING',
                            accentColor: const Color(0xFF10B981),
                            children: [
                              if (request.agreedRentalUnit?.toLowerCase() == 'per kg' ||
                                  request.estimatedMillingFee != null) ...[
                                _infoTile(
                                  Icons.grain,
                                  'PRICING TYPE',
                                  request.keepDarak == true ? 'Rice + Darak' : 'Rice Only',
                                  const Color(0xFF10B981),
                                ),
                                _infoTile(
                                  Icons.payments_outlined,
                                  'RATE',
                                  '₱${request.agreedPrice?.toStringAsFixed(2) ?? '—'}/kg',
                                  const Color(0xFF10B981),
                                ),
                                if (request.volumeSubmitted != null)
                                  _infoTile(
                                    Icons.scale,
                                    'VOLUME SUBMITTED',
                                    '${request.volumeSubmitted!.toStringAsFixed(0)} cavans',
                                    const Color(0xFF10B981),
                                  ),
                                if (request.estimatedMillingFee != null) ...[
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Estimated Total',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15)),
                                      Text(
                                        '₱${request.estimatedMillingFee!.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF10B981)),
                                      ),
                                    ],
                                  ),
                                ],
                              ] else ...[
                                _infoTile(
                                  Icons.payments_outlined,
                                  'RENTAL RATE',
                                  '₱${request.agreedPrice?.toStringAsFixed(2) ?? '—'}${_getRateSuffix(request.agreedRentalUnit ?? '')}',
                                  const Color(0xFF10B981),
                                ),
                              ],
                            ],
                          ),

                          // ── LENDER INFORMATION ──
                          FutureBuilder<Map<String, dynamic>?>(
                            future: _fetchOwnerProfile(request.ownerId),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return _sectionCard(
                                  title: 'LENDER INFORMATION',
                                  accentColor: const Color(0xFFF59E0B),
                                  children: const [
                                    Center(child: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 8),
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )),
                                  ],
                                );
                              }

                              final owner = snapshot.data;
                              if (owner == null) return const SizedBox.shrink();

                              return _sectionCard(
                                title: 'LENDER INFORMATION',
                                accentColor: const Color(0xFFF59E0B),
                                children: [
                                  if (owner['firstName'] != null || owner['lastName'] != null)
                                    _infoTile(
                                      Icons.person_outline,
                                      'NAME',
                                      '${owner['firstName'] ?? ''} ${owner['lastName'] ?? ''}'.trim().isNotEmpty
                                          ? '${owner['firstName'] ?? ''} ${owner['lastName'] ?? ''}'.trim()
                                          : '—',
                                      const Color(0xFFF59E0B),
                                    ),
                                  if (owner['phoneNumber'] != null || owner['contactNumber'] != null)
                                    _infoTile(Icons.phone_outlined, 'CONTACT',
                                      owner?['phoneNumber'] ?? '—', const Color(0xFFF59E0B)),
                                  if (owner['address'] != null)
                                    _infoTile(Icons.location_on_outlined, 'ADDRESS',
                                        owner?['address'] ?? '—', const Color(0xFFF59E0B)),
                                ],
                              );
                            },
),

                         // ── RENTER INFO ──
                        _sectionCard(
                          title: 'RENTER INFORMATION',
                          accentColor: const Color(0xFF3B82F6),
                          children: [
                            _infoTile(Icons.person_outline, 'NAME',
                                request.name, const Color(0xFF3B82F6)),
                            _infoTile(Icons.location_on_outlined, 'ADDRESS',
                                request.address, const Color(0xFF3B82F6)),
                            _infoTile(Icons.location_on_outlined, 'CONTACT',
                                request.phoneNumber ?? 'Unknown', const Color(0xFF3B82F6)),

                            // // ── Land size proofs ──────────────────────────────────
                            // if (request.landSizeProofPaths.isNotEmpty) ...[
                            //   const SizedBox(height: 4),
                            //   _proofImages(
                            //     request.landSizeProofPaths,
                            //     'LAND SIZE PROOF',
                            //     context,
                            //   ),
                            // ],

                            if (request.hectaresEntered != null) ...[
                              () {
                                final totalDays = request.end.difference(request.start).inDays + 1;
                                final haPerDay = request.hectaresEntered! / totalDays;
                                return Column(
                                  children: [
                                    _infoTile(
                                      Icons.crop_square_rounded,
                                      'LAND AREA',
                                      '${request.hectaresEntered! % 1 == 0 ? request.hectaresEntered!.toInt() : request.hectaresEntered} hectares',
                                      const Color(0xFF3B82F6),
                                    ),
                                    _infoTile(
                                      Icons.calendar_month_rounded,
                                      'DURATION',
                                      '$totalDays day${totalDays == 1 ? '' : 's'}',
                                      const Color(0xFF3B82F6),
                                    ),
                                    _infoTile(
                                      Icons.speed_rounded,
                                      'COVERAGE RATE',
                                      '${haPerDay % 1 == 0 ? haPerDay.toInt() : haPerDay.toStringAsFixed(1)} ha/day',
                                      const Color(0xFF3B82F6),
                                    ),
                                  ],
                                );
                              }(),
                            ] else if (request.landSizeProofPaths.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              _proofImages(
                                request.landSizeProofPaths,
                                'LAND SIZE PROOF',
                                context,
                              ),
                            ],

                            // ── Crop height proofs ────────────────────────────────
                            if (request.cropHeightProofPaths.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              _proofImages(
                                request.cropHeightProofPaths,
                                'GRASS HEIGHT PROOF',
                                context,
                              ),
                            ],

                            // ── Crop condition proofs ─────────────────────────────
                            if (request.cropConditionProofPaths.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              _proofImages(
                                request.cropConditionProofPaths,
                                'CROP CONDITION PROOF',
                                context,
                              ),
                            ],
                          ],
                        ),


                          // ── DECLINE REASON ──
                          if (request.status == RentRequestStatus.declined &&
                              request.declineReason != null)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.red.shade400, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Reason for Decline',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.red.shade700,
                                                fontSize: 13)),
                                        const SizedBox(height: 4),
                                        Text(request.declineReason!,
                                            style: TextStyle(
                                                color: Colors.red.shade800,
                                                fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // ── OVERDUE WARNING ──
                          if (isRenter && isOverdue &&
                              request.status == RentRequestStatus.inProgress)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: Colors.orange.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: Colors.orange.shade600, size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Return period has ended. Please return the equipment immediately.',
                                      style: TextStyle(
                                          color: Colors.orange.shade800,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (isOwner && isOverdue &&
                              request.status == RentRequestStatus.inProgress)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.red.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded,
                                          color: Colors.red.shade600, size: 22),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Equipment Not Returned',
                                          style: TextStyle(
                                              color: Colors.red.shade800,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade600,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          daysOverdue == 0
                                              ? 'Due today'
                                              : '$daysOverdue ${daysOverdue == 1 ? 'day' : 'days'} late',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Hindi pa ibinalik ng nangupahan ang kagamitan. '
                                    'Ang mga susunod na booking ay inililipat ng 1 araw para sa bawat araw na naantala. '
                                    'Ang nangupahan ay tumatanggap ng isang paglabag bawat araw hanggang maibalik ang kagamitan.',
                                    style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 12),
                                  ),
                                ],
                              ),
                            ),

                          // ── OWNER RETRIEVING BANNER (renter view) ──
                          if (isRenter &&
                              request.status == RentRequestStatus.retrieving)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.directions_car_rounded,
                                      color: Colors.blue.shade600, size: 22),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'The owner is on the way to retrieve the equipment. Please have it ready.',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // ── WAITING FOR RECEIPT BANNER (owner view) ──
                          if (isOwner &&
                              request.status == RentRequestStatus.onTheWay)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: Colors.purple.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time_rounded,
                                      color: Colors.purple.shade400, size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Waiting for renter to confirm equipment receipt',
                                      style: TextStyle(
                                          color: Colors.purple.shade700,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // // Renter: notify on readyForPickup (info banner)
                          //   if (isRenter && request.status == RentRequestStatus.readyForPickup)
                          //     Container(
                          //       margin: const EdgeInsets.only(bottom: 12),
                          //       padding: const EdgeInsets.all(14),
                          //       decoration: BoxDecoration(
                          //         color: Colors.blue.shade50,
                          //         borderRadius: BorderRadius.circular(16),
                          //         border: Border.all(color: Colors.blue.shade200),
                          //       ),
                          //       child: Row(
                          //         children: [
                          //           Icon(Icons.store_rounded, color: Colors.blue.shade600, size: 22),
                          //           const SizedBox(width: 10),
                          //           const Expanded(
                          //             child: Text(
                          //               'The equipment is ready for pick up at the owner\'s location.',
                          //               style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          //             ),
                          //           ),
                          //         ],
                          //       ),
                          //     ),

                          // Renter: just an info banner while waiting for owner confirmation
                          if (isRenter && request.status == RentRequestStatus.readyForPickup)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.purple.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time_rounded, color: Colors.purple.shade400, size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Waiting for the owner to confirm your pick up.',
                                      style: TextStyle(
                                          color: Colors.purple.shade700,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // ── EQUIPMENT MANUAL & TUTORIAL ──
                          if (isRenter)
                            FutureBuilder<(String?, bool)>(
                              future: FirebaseFirestore.instance
                                  .collection('equipment')
                                  .doc(request.itemId)
                                  .get()
                                  .then((d) {
                                    final data = d.data();
                                    return (
                                      data?['category'] as String?,
                                      data?['operatorIncluded'] as bool? ?? false,
                                    );
                                  }),
                              builder: (context, snap) {
                                final category         = snap.data?.$1;
                                final operatorIncluded = snap.data?.$2 ?? false;
                                // Manual always shown if the category has one.
                                final manualUrl = category != null ? _equipmentManuals[category] : null;
                                // Tutorial only shown for equipment without an operator.
                                final videoId   = (!operatorIncluded && category != null)
                                    ? _equipmentTutorials[category]
                                    : null;
                                if (manualUrl == null && videoId == null) return const SizedBox.shrink();
                                return Column(
                                  children: [
                                    if (manualUrl != null)
                                      _resourceCard(
                                        icon: Icons.menu_book_rounded,
                                        label: 'EQUIPMENT MANUAL',
                                        subtitle: category!,
                                        buttonLabel: 'View PDF',
                                        buttonIcon: Icons.open_in_new_rounded,
                                        url: manualUrl,
                                      ),
                                    if (videoId != null)
                                      _resourceCard(
                                        icon: Icons.play_circle_rounded,
                                        label: 'HOW TO OPERATE',
                                        subtitle: category!,
                                        buttonLabel: 'Watch Video',
                                        buttonIcon: Icons.open_in_new_rounded,
                                        url: videoId,
                                      ),
                                  ],
                                );
                              },
                            ),

                          // ── FARM SATELLITE DATA ──
                          NdviCard(
                            renterId: request.renterId,
                            equipmentId: request.itemId,
                          ),

                          // ── ACTION BUTTONS ──
                          const SizedBox(height: 4),

                          // Owner: Approve / Decline
                          // Owner: Approve / Decline
if (showApproveDecline && now.isBefore(request.start))
  Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.amber.shade50,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.amber.shade300),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded,
            color: Colors.amber.shade700, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                  fontSize: 13, color: Colors.amber.shade900),
              children: [
                const TextSpan(
                  text: 'Note: ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(
                  text: 'If you approve this request, the rental will still begin on ',
                ),
                TextSpan(
                  text: DateFormat('MMMM dd, yyyy').format(request.start),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(
                  text: ' as scheduled by the renter.',
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
                          if (showApproveDecline)
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      context.read<RequestBloc>().add(
                                            RequestStatusUpdated(
                                                request.requestId,
                                                RentRequestStatus.approved),
                                          );
                                    },
                                    icon: const Icon(Icons.check_rounded,
                                        color: Colors.white, size: 18),
                                    label: const Text('Approve',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _showDeclineDialog(
                                        context, request.requestId),
                                    icon: const Icon(Icons.close_rounded,
                                        color: Colors.white, size: 18),
                                    label: const Text('Decline',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFFEF4444),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                          if (isOwner &&
                              request.status == RentRequestStatus.approved &&
                              request.deliveryMethod == DeliveryMethod.pickup)
                             if (now.isBefore(request.start)) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.event_rounded, color: Colors.blue.shade600, size: 22),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Rental Not Started Yet',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.blue.shade700,
                                                  fontSize: 13)),
                                          const SizedBox(height: 2),
                                          Text(
                                            'You can mark "On The Way" starting ${DateFormat('MMM dd, yyyy').format(request.start)}.',
                                            style: TextStyle(color: Colors.blue.shade600, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ]  else ...[
                              _actionButton(
                                label: 'Mark as Ready for Pick Up',
                                icon: Icons.store_rounded,
                                color: const Color(0xFF0EA5E9),
                                onPressed: () {
                                  context.read<RequestBloc>().add(
                                    RequestStatusUpdated(request.requestId, RentRequestStatus.readyForPickup),
                                  );
                                },
                              ),
                            ],

                          // // Renter: Confirm Picked Up
                          // if (isRenter && request.status == RentRequestStatus.readyForPickup)
                          //   _actionButton(
                          //     label: 'I\'ve Picked It Up',
                          //     icon: Icons.directions_walk_rounded,
                          //     color: const Color(0xFF8B5CF6),
                          //     onPressed: () {
                          //       context.read<RequestBloc>().add(
                          //         RequestStatusUpdated(request.requestId, RentRequestStatus.inProgress),
                          //       );
                          //     },
                          //   ),

                          if (isOwner && request.status == RentRequestStatus.readyForPickup)
                            _actionButton(
                              label: 'Confirm Pick Up',
                              icon: Icons.check_circle_rounded,
                              color: const Color(0xFF8B5CF6),
                              onPressed: () {
                                context.read<RequestBloc>().add(
                                  RequestStatusUpdated(request.requestId, RentRequestStatus.inProgress),
                                );
                              },
                            ),

                          // Owner: On The Way (delivery)
                          if (isOwner && request.status == RentRequestStatus.approved && request.deliveryMethod == DeliveryMethod.delivery)
                            if (now.isBefore(request.start)) ...[
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.event_rounded, color: Colors.blue.shade600, size: 22),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Rental Not Started Yet',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.blue.shade700,
                                                  fontSize: 13)),
                                          const SizedBox(height: 2),
                                          Text(
                                            'You can mark "On The Way" starting ${DateFormat('MMM dd, yyyy').format(request.start)}.',
                                            style: TextStyle(color: Colors.blue.shade600, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              _actionButton(
                                label: 'Mark As On The Way',
                                icon: Icons.local_shipping_rounded,
                                color: const Color(0xFF3B82F6),
                                onPressed: () {
                                  context.read<RequestBloc>().add(
                                    RequestStatusUpdated(request.requestId, RentRequestStatus.onTheWay),
                                  );
                                },
                              ),
                            ],

                          // Renter: approved but not started yet
                          if (isRenter && request.status == RentRequestStatus.approved && now.isBefore(request.start))
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Request Approved!',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Colors.green.shade700,
                                                fontSize: 13)),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Your rental is scheduled to start on ${DateFormat('MMM dd, yyyy').format(request.start)}.',
                                          style: TextStyle(color: Colors.green.shade600, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Renter: Equipment Received
                          if (isRenter &&
                              request.status == RentRequestStatus.onTheWay)
                            _actionButton(
                              label: 'Equipment Received',
                              icon: Icons.check_circle_rounded,
                              color: const Color(0xFF8B5CF6),
                              onPressed: () {
                                context.read<RequestBloc>().add(
                                      RequestStatusUpdated(request.requestId,
                                          RentRequestStatus.inProgress),
                                    );
                              },
                            ),

                          // Renter: Return Equipment
                          if (isRenter &&
                              request.status == RentRequestStatus.inProgress &&
                              isWithinReturnWindow &&
                              request.deliveryMethod == DeliveryMethod.pickup)
                            _actionButton(
                              label: 'Return Equipment',
                              icon: Icons.assignment_return_rounded,
                              color: lightColorScheme.primary,
                              onPressed: () {
                                context.read<RequestBloc>().add(
                                      RequestStatusUpdated(request.requestId,
                                          RentRequestStatus.returned),
                                    );
                              },
                            ),

                          // Owner: On My Way to Retrieve (overdue)
                         if (isOwner &&
                            request.status == RentRequestStatus.inProgress &&
                            request.deliveryMethod == DeliveryMethod.delivery)
                            _actionButton(
                              label: 'On My Way to Retrieve',
                              icon: Icons.directions_car_rounded,
                              color: Colors.orange,
                              onPressed: () {
                                context.read<RequestBloc>().add(
                                      RequestStatusUpdated(request.requestId,
                                          RentRequestStatus.retrieving),
                                    );
                              },
                            ),

                          // Owner: Confirm Retrieved (Path B — forced retrieval)
                          if (isOwner &&
                            request.status == RentRequestStatus.retrieving)
                          _actionButton(
                            label: 'Confirm Retrieved',
                            icon: Icons.task_alt_rounded,
                            color: const Color(0xFF10B981),
                            onPressed: () async {
                              final days = DateTime.now()
                                  .difference(request.end)
                                  .inDays
                                  .clamp(0, 9999);
                              if (days > 0) {
                                await RentRequestService()
                                    .shiftQueuedBookingsForEquipment(
                                  equipmentId: request.itemId,
                                  daysLate: days,
                                );
                              }
                              if (context.mounted) {
                                context.read<RequestBloc>().add(
                                      RequestStatusUpdated(request.requestId,
                                          RentRequestStatus.finished),
                                    );
                              }
                            },
                          ),

                          // Owner: Confirm Return (Path A — renter self-returns)
                          if (isOwner &&
                              request.status == RentRequestStatus.returned)
                            _actionButton(
                              label: 'Confirm Return',
                              icon: Icons.task_alt_rounded,
                              color: lightColorScheme.primary,
                              onPressed: () async {
                                final days = DateTime.now()
                                    .difference(request.end)
                                    .inDays
                                    .clamp(0, 9999);
                                if (days > 0) {
                                  await RentRequestService()
                                      .shiftQueuedBookingsForEquipment(
                                    equipmentId: request.itemId,
                                    daysLate   : days,
                                  );
                                }
                                if (context.mounted) {
                                  context.read<RequestBloc>().add(
                                        RequestStatusUpdated(request.requestId,
                                            RentRequestStatus.finished),
                                      );
                                }
                              },
                            ),

                          // Owner: Confirm Completion
                          if (isOwner &&
                              request.status == RentRequestStatus.finished)
                            _actionButton(
                              label: 'Confirm Completion',
                              icon: Icons.verified_rounded,
                              color: lightColorScheme.primary,
                             onPressed: () async {
                                final doc = await FirebaseFirestore.instance
                                    .collection('equipment')
                                    .doc(request.itemId)
                                    .get();
                                final equipment = Equipment.fromFirestore(doc);
                                if (context.mounted) {
                                  _showEquipmentConditionDialog(
                                    context,
                                    request.requestId,
                                    equipment,
                                    rentalStart: request.start,
                                    rentalEnd  : request.end,
                                    ownerId    : request.ownerId,
                                  );
                                }
                              },
                            ),

                          // Renter: Leave Review
                          if (isRenter && request.status == RentRequestStatus.completed)
                            FutureBuilder<bool>(
                              future: _hasLeftReview(request.requestId),
                              builder: (context, snapshot) {
                                if (snapshot.data == true) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.amber.shade200),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.star_rounded, color: Colors.amber.shade600, size: 22),
                                        const SizedBox(width: 10),
                                        Text(
                                          'You have already left a review.',
                                          style: TextStyle(
                                            color: Colors.amber.shade800,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return _actionButton(
                                  label: 'Leave a Review',
                                  icon: Icons.star_rounded,
                                  color: const Color(0xFFF59E0B),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ReviewPage(
                                          requestId: request.requestId,
                                          lenderId: request.ownerId,
                                          itemId: request.itemId,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),

                          // Owner: Report Renter
                          if (isOwner &&
                              request.status == RentRequestStatus.completed)
                            _actionButton(
                              label: 'Report Renter',
                              icon: Icons.flag_rounded,
                              color: lightColorScheme.error, // 
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReportRenterPage(
                                      requestId: request.requestId,
                                      renterId: request.renterId,
                                      renterName: request.name,   
                                      itemName: request.itemName,
                                    ),
                                  ),
                                );
                              },
                            ),

                          // Renter: Cancel
                          if (isRenter && _canRenterCancel(request))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _actionButton(
                                label: 'Cancel Request',
                                icon: Icons.cancel_outlined,
                                color: const Color(0xFFEF4444),
                                outlined: true,
                                onPressed: () => _showCancelDialog(context,
                                    request,
                                    isRenter: true),
                              ),
                            ),

                          // Owner: Cancel
                          if (isOwner && !showApproveDecline && _canOwnerCancel(request))
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: _actionButton(
                                label: 'Cancel Request',
                                icon: Icons.cancel_outlined,
                                color: const Color(0xFFEF4444),
                                outlined: true,
                                onPressed: () => _showCancelDialog(context,
                                    request,
                                    isRenter: false),
                              ),
                            ),

                          const SizedBox(height: 24),
                        ],
                      ),
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

  Widget _dateBox(
      String label, DateTime date, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('MMM dd').format(date),
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          Text(
            DateFormat('yyyy').format(date),
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _grabStyleStepper({
    required int currentStep,
    required List<IconData> icons,
    required RentRequestStatus status,
  }) {
    return Row(
      children: List.generate(icons.length * 2 - 1, (index) {
        if (index.isEven) {
          final stepIndex = index ~/ 2;
          final isCompleted = stepIndex < currentStep ||
              status == RentRequestStatus.completed;
          final isCurrent = stepIndex == currentStep &&
              status != RentRequestStatus.completed;

          Color color;
          if (isCompleted) {
            color = Colors.white;
          } else if (isCurrent) {
            color = Colors.white;
          } else {
            color = Colors.white.withOpacity(0.35);
          }

          return Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted || isCurrent
                  ? Colors.white.withOpacity(0.25)
                  : Colors.white.withOpacity(0.1),
            ),
            child: Icon(icons[stepIndex], color: color, size: 22),
          );
        } else {
          final lineIndex = (index - 1) ~/ 2;
          final isActive = lineIndex < currentStep ||
              status == RentRequestStatus.completed;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              height: 3,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withOpacity(0.8)
                    : Colors.white.withOpacity(0.25),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text('Dahilan ng Pagtanggi',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                        'Pumili ng dahilan para sa pagtanggi ng kahilingan:',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 12),
                    ...reasons.map((reason) => RadioListTile<String>(
                          value: reason,
                          groupValue: selectedReason,
                          title:
                              Text(reason, style: const TextStyle(fontSize: 13)),
                          onChanged: (val) =>
                              setState(() => selectedReason = val),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        )),
                    if (selectedReason == 'Iba pang dahilan') ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: otherController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Ipaliwanag ang dahilan...',
                          hintStyle: const TextStyle(fontSize: 13),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
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
                    otherController.dispose();
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Kanselahin'),
                ),
                ElevatedButton(
                  onPressed: selectedReason == null
                      ? null
                      : () {
                          final finalReason = selectedReason ==
                                      'Iba pang dahilan' &&
                                  otherController.text.trim().isNotEmpty
                              ? 'Iba pang dahilan: ${otherController.text.trim()}'
                              : selectedReason!;
                          Navigator.pop(dialogContext);
                          requestBloc.add(RequestStatusUpdated(
                              requestId, RentRequestStatus.declined,
                              declineReason: finalReason));
                        },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red),
                  child: const Text('Tanggihan',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

void _showEquipmentConditionDialog(
  BuildContext context,
  String requestId,
  Equipment equipment, {
  required DateTime rentalStart,
  required DateTime rentalEnd,
  required String ownerId,
}) {
  bool? equipmentGood;
  final commentController = TextEditingController();
  final maintenanceDaysController = TextEditingController();
  final requestBloc = context.read<RequestBloc>();

  // Maintenance state
  DateTime? maintenanceEndDate;
  List<Map<String, dynamic>>? affectedBookings;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (_, setState) {
          final durationDays = maintenanceEndDate != null
              ? maintenanceEndDate!.difference(today).inDays + 1
              : 0;
          final isUnforeseen = durationDays > 7;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Ulat ng Kondisyon ng Kagamitan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Punan ang form na ito bago tapusin ang rental.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Nasa maayos na kondisyon ba ang kagamitan?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  // ── Yes / No toggle ──────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            equipmentGood = true;
                            // Clear maintenance if they switch back to Yes
                            maintenanceEndDate = null;
                            maintenanceDaysController.clear();
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: equipmentGood == true ? Colors.green : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: equipmentGood == true ? Colors.green : Colors.grey.shade400,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle,
                                    color: equipmentGood == true ? Colors.white : Colors.grey,
                                    size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  'Oo',
                                  style: TextStyle(
                                    color: equipmentGood == true ? Colors.white : Colors.grey.shade700,
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
                              color: equipmentGood == false ? Colors.red : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: equipmentGood == false ? Colors.red : Colors.grey.shade400,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cancel,
                                    color: equipmentGood == false ? Colors.white : Colors.grey,
                                    size: 20),
                                const SizedBox(width: 6),
                                Text(
                                  'Hindi',
                                  style: TextStyle(
                                    color: equipmentGood == false ? Colors.white : Colors.grey.shade700,
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

                  // ── No branch ────────────────────────────────────
                  if (equipmentGood == false) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Ilarawan ang problema:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'hal. Sirang talim, hindi umaandar ang makina...',
                        hintStyle: const TextStyle(fontSize: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Maintenance section ──────────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: lightColorScheme.secondary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: lightColorScheme.secondary),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.build_outlined, color: lightColorScheme.primary, size: 16),
                              const SizedBox(width: 6),
                              const Text(
                                'I-schedule ang Maintenance',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          if (equipment.maintenanceStart != null || equipment.maintenanceEnd != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: lightColorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: lightColorScheme.outlineVariant),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: lightColorScheme.primary, size: 16),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Kasalukuyang nasa maintenance'
                                      '${equipment.maintenanceStart != null ? ' mula ${DateFormat('MMM d').format(equipment.maintenanceStart!)}' : ''}'
                                      '${equipment.maintenanceEnd != null ? ' hanggang ${DateFormat('MMM d, yyyy').format(equipment.maintenanceEnd!)}' : ''}.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: lightColorScheme.onSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            _buildDateRow(
                              label: 'Simula',
                              value: DateFormat('MMM d, yyyy').format(today),
                              icon: Icons.today,
                              color: lightColorScheme.primary,
                              isFixed: true,
                              onTap: null,
                            ),
                            const SizedBox(height: 8),
                            _buildDateRow(
                              label: 'Katapusan',
                              value: maintenanceEndDate != null
                                  ? DateFormat('MMM d, yyyy').format(maintenanceEndDate!)
                                  : 'Pindutin para pumili ng petsa',
                              icon: Icons.event,
                              color: lightColorScheme.primary,
                              isFixed: false,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: dialogContext,
                                  initialDate: today.add(const Duration(days: 1)),
                                  firstDate: today.add(const Duration(days: 1)),
                                  lastDate: today.add(const Duration(days: 365)),
                                  helpText: 'Pumili ng petsa ng katapusan ng maintenance',
                                );
                                if (picked != null) {
                                  final newEnd = DateTime(
                                      picked.year, picked.month, picked.day, 23, 59, 59);
                                  final bookings =
                                      await _fetchConditionReportAffectedBookings(
                                    equipmentId: equipment.id!,
                                    today: today,
                                    maintenanceEnd: newEnd,
                                    availableUntil: equipment.availableUntil,
                                  );
                                  setState(() {
                                    maintenanceEndDate = newEnd;
                                    affectedBookings = bookings;
                                  });
                                }
                              },
                            ),
                            if (maintenanceEndDate != null) ...[
                              const SizedBox(height: 10),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isUnforeseen
                                      ? lightColorScheme.error.withOpacity(0.08)
                                      : lightColorScheme.secondary.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isUnforeseen
                                        ? lightColorScheme.error
                                        : lightColorScheme.primary,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isUnforeseen ? Icons.warning_amber_rounded : Icons.info_outline,
                                      color: isUnforeseen ? lightColorScheme.error : lightColorScheme.primary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        isUnforeseen
                                            ? '$durationDays na araw — Hindi Inaasahan. Lahat ng booking ay IKAKANSELA.'
                                            : '$durationDays na araw — Ang mga booking ay ire-reschedule.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isUnforeseen
                                              ? lightColorScheme.error
                                              : lightColorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (affectedBookings != null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Mga Apektadong Booking',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (affectedBookings!.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Walang apektadong booking.',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  )
                                else
                                  ...affectedBookings!.map((b) {
                                    final isCancelled = b['willBeCancelled'] as bool;
                                    final newStart = b['newStart'] as DateTime?;
                                    final newEnd = b['newEnd'] as DateTime?;
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                isCancelled ? Icons.cancel_outlined : Icons.update,
                                                size: 14,
                                                color: isCancelled
                                                    ? Colors.red.shade600
                                                    : Colors.orange.shade700,
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  '${b['renterName']} · '
                                                  '${DateFormat('MMM d').format(b['start'] as DateTime)} – '
                                                  '${DateFormat('MMM d, yyyy').format(b['end'] as DateTime)}',
                                                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                isCancelled ? 'Ikakansela' : 'Ire-reschedule',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: isCancelled
                                                      ? Colors.red.shade600
                                                      : Colors.orange.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (!isCancelled && newStart != null && newEnd != null)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 20, top: 2),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.arrow_forward, size: 12, color: Colors.orange.shade700),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${DateFormat('MMM d').format(newStart)} – ${DateFormat('MMM d, yyyy').format(newEnd)}',
                                                    style: TextStyle(fontSize: 11, color: Colors.orange.shade800, fontWeight: FontWeight.w500),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }),
                              ],
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Kanselahin'),
              ),
              ElevatedButton(
                onPressed: equipmentGood == null
                    ? null
                    : () async {
                        Navigator.pop(dialogContext);

                        // Complete the rental
                        requestBloc.add(
                            RequestStatusUpdated(requestId, RentRequestStatus.completed));

                        // Log rental usage for maintenance hour tracking.
                        // Each rental day = 24 hours of assumed machine use.
                        final startDate = DateTime(rentalStart.year,
                            rentalStart.month, rentalStart.day);
                        final endDate = DateTime(rentalEnd.year,
                            rentalEnd.month, rentalEnd.day);
                        final rentalDays =
                            endDate.difference(startDate).inDays + 1;
                        MaintenanceService().logRentalUsage(
                          equipmentId  : equipment.id ?? requestId,
                          ownerId      : ownerId,
                          equipmentName: equipment.name,
                          rentalDays   : rentalDays,
                        );

                        // If No + maintenance end date selected → schedule it
                        if (equipmentGood == false && maintenanceEndDate != null) {
                          await _applyMaintenanceFromConditionReport(
                            context: context,
                            equipment: equipment,
                            maintenanceEnd: maintenanceEndDate!,
                            today: today,
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: lightColorScheme.primary),
                child: const Text(
                  'Isumite at Tapusin',
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

// ── Inline date row widget for the dialog ───────────────────────────────────
Widget _buildDateRow({
  required String label,
  required String value,
  required IconData icon,
  required Color color,
  required bool isFixed,
  required VoidCallback? onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isFixed ? Colors.grey.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFixed ? Colors.grey.shade300 : color.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isFixed ? Colors.grey.shade600 : Colors.black87,
                ),
              ),
            ],
          ),
          if (!isFixed) ...[
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 16),
          ],
        ],
      ),
    ),
  );
}

// ── Fetches bookings affected by maintenance from the condition report flow ──
Future<List<Map<String, dynamic>>> _fetchConditionReportAffectedBookings({
  required String equipmentId,
  required DateTime today,
  required DateTime maintenanceEnd,
  DateTime? availableUntil,
}) async {
  const activeStatuses = ['pending', 'approved', 'readyForPickup'];
  final snap = await FirebaseFirestore.instance
      .collection('rentRequests')
      .where('itemId', isEqualTo: equipmentId)
      .where('status', whereIn: activeStatuses)
      .get();

  final maintenanceEndDay =
      DateTime(maintenanceEnd.year, maintenanceEnd.month, maintenanceEnd.day);
  final durationDays = maintenanceEndDay.difference(today).inDays + 1;
  final isUnforeseen = durationDays > 7;

  // Sort ascending by start so cascade propagates in order
  final sortedDocs = snap.docs.toList()
    ..sort((a, b) {
      final aStart = (a.data()['start'] as Timestamp).toDate();
      final bStart = (b.data()['start'] as Timestamp).toDate();
      return aStart.compareTo(bStart);
    });

  final results = <Map<String, dynamic>>[];

  if (isUnforeseen) {
    // Unforeseen: only direct overlaps are cancelled.
    for (final doc in sortedDocs) {
      final request = RentRequest.fromDoc(doc);
      final bookingStart =
          DateTime(request.start.year, request.start.month, request.start.day);
      final bookingEnd =
          DateTime(request.end.year, request.end.month, request.end.day);
      final overlaps =
          bookingStart.isBefore(maintenanceEndDay.add(const Duration(days: 1))) &&
          bookingEnd.isAfter(today.subtract(const Duration(days: 1)));
      if (!overlaps) continue;
      results.add({
        'renterName': request.name,
        'start': request.start,
        'end': request.end,
        'willBeCancelled': true,
      });
    }
  } else {
    // Foreseen: simulate the same cascade used during actual scheduling so
    // bookings shifted by a prior booking are also included in the preview.
    DateTime blockedUntil = maintenanceEndDay;
    for (final doc in sortedDocs) {
      final request = RentRequest.fromDoc(doc);
      final bookingStart =
          DateTime(request.start.year, request.start.month, request.start.day);
      if (bookingStart.isAfter(blockedUntil)) continue; // Not affected

      final bookingDuration = request.end.difference(request.start);
      final newStart = DateTime(
        blockedUntil.year, blockedUntil.month, blockedUntil.day,
        request.start.hour, request.start.minute,
      ).add(const Duration(days: 1));
      final newEnd = newStart.add(bookingDuration);

      final exceedsAvailability =
          availableUntil != null && newEnd.isAfter(availableUntil);

      results.add({
        'renterName': request.name,
        'start': request.start,
        'end': request.end,
        'willBeCancelled': exceedsAvailability,
        if (!exceedsAvailability) 'newStart': newStart,
        if (!exceedsAvailability) 'newEnd': newEnd,
      });

      if (!exceedsAvailability) {
        // Advance cascade pointer; cancelled slots don't block the next booking.
        blockedUntil = DateTime(newEnd.year, newEnd.month, newEnd.day);
      }
    }
  }

  return results;
}

// ── Applies maintenance after condition report (same logic as _scheduleMaintenance) ─
Future<void> _applyMaintenanceFromConditionReport({
  required BuildContext context,
  required Equipment equipment,
  required DateTime maintenanceEnd,
  required DateTime today,
}) async {
  final durationDays = maintenanceEnd.difference(today).inDays + 1;
  final isUnforeseen = durationDays > 7;


  try {
    final db = FirebaseFirestore.instance;

    // Update equipment status
    await db.collection('equipment').doc(equipment.id).update({
      'status': EquipmentStatus.underMaintenance.toValue(),
      'isAvailable': false,
      'maintenanceStart': Timestamp.fromDate(today),
      'maintenanceEnd': Timestamp.fromDate(maintenanceEnd),
    });

    const activeStatuses = ['pending', 'approved', 'readyForPickup'];

    final bookingsSnap = await db
        .collection('rentRequests')
        .where('itemId', isEqualTo: equipment.id)
        .where('status', whereIn: activeStatuses)
        .get();

    final batch = db.batch();
    final List<Future<void>> notifFutures = [];

    // Sort by start date so cascade shifts propagate in order.
    final sortedDocs = bookingsSnap.docs.toList()
      ..sort((a, b) {
        final aStart = (a.data()['start'] as Timestamp).toDate();
        final bStart = (b.data()['start'] as Timestamp).toDate();
        return aStart.compareTo(bStart);
      });

    // For foreseen maintenance: tracks the last occupied day so that
    // each shifted booking cascades off the previous one's new end date.
    DateTime blockedUntil = DateTime(maintenanceEnd.year, maintenanceEnd.month, maintenanceEnd.day);
    final maintenanceEndDay = DateTime(maintenanceEnd.year, maintenanceEnd.month, maintenanceEnd.day);

    for (final doc in sortedDocs) {
      final request = RentRequest.fromDoc(doc);

      final bookingStart = DateTime(request.start.year, request.start.month, request.start.day);
      final bookingEnd   = DateTime(request.end.year,   request.end.month,   request.end.day);

      if (isUnforeseen) {
        final overlaps =
            bookingStart.isBefore(maintenanceEndDay.add(const Duration(days: 1))) &&
            bookingEnd.isAfter(today.subtract(const Duration(days: 1)));
        if (!overlaps) continue;

        batch.update(doc.reference, {
          'status': RentRequestStatus.canceled.name,
          'declineReason':
              'Ang kagamitan ay naka-schedule para sa hindi inaasahang maintenance mula '
              '${DateFormat('MMM d').format(today)} hanggang ${DateFormat('MMM d, yyyy').format(maintenanceEnd)}. '
              'Paumanhin sa abala.',
        });
        notifFutures.add(_sendNotification(
          userId: request.renterId,
          title: '🔧 Kinansela ang Booking — Maintenance',
          body: 'Ang iyong booking para sa "${equipment.name}" '
              '(${DateFormat('MMM d').format(request.start)} – ${DateFormat('MMM d').format(request.end)}) '
              'ay kinansela dahil sa hindi inaasahang maintenance ($durationDays na araw). '
              'Paumanhin sa abala.',
          type: 'maintenance_cancel',
          extra: {'requestId': request.requestId, 'equipmentId': equipment.id, 'ownerId': equipment.ownerId},
        ));
      } else {
        // Foreseen: cascade shift — conflict if booking starts on or before blockedUntil.
        if (bookingStart.isAfter(blockedUntil)) continue;

        final bookingDuration = request.end.difference(request.start);
        final newStart = DateTime(
          blockedUntil.year, blockedUntil.month, blockedUntil.day,
          request.start.hour, request.start.minute,
        ).add(const Duration(days: 1));
        final newEnd = newStart.add(bookingDuration);

        final exceedsAvailability = equipment.availableUntil != null &&
            newEnd.isAfter(equipment.availableUntil!);

        if (exceedsAvailability) {
          batch.update(doc.reference, {
            'status': RentRequestStatus.canceled.name,
            'declineReason':
                'Hindi ma-reschedule ang booking pagkatapos ng maintenance — ang bagong mga petsa ay wala na sa availability ng kagamitan.',
          });
          notifFutures.add(_sendNotification(
            userId: request.renterId,
            title: '🔧 Kinansela ang Booking — Labas ng Availability',
            body: 'Hindi ma-reschedule ang iyong booking para sa "${equipment.name}" '
                'pagkatapos ng maintenance dahil ang bagong mga petsa ay wala na sa '
                'availability ng kagamitan. Kinansela na ang iyong booking.',
            type: 'maintenance_cancel',
            extra: {'requestId': request.requestId, 'equipmentId': equipment.id, 'ownerId': equipment.ownerId},
          ));
          // Do NOT advance blockedUntil — cancelled slot is freed.
        } else {
          batch.update(doc.reference, {
            'start'         : Timestamp.fromDate(newStart),
            'end'           : Timestamp.fromDate(newEnd),
            'originalStart' : Timestamp.fromDate(request.start),
            'originalEnd'   : Timestamp.fromDate(request.end),
            'maintenanceRescheduled': true,
          });
          notifFutures.add(_sendNotification(
            userId: request.renterId,
            title: '📅 Na-reschedule ang Booking — Maintenance',
            body: 'Ang iyong booking para sa "${equipment.name}" ay inilipat mula '
                '${DateFormat('MMM d').format(request.start)} – ${DateFormat('MMM d').format(request.end)} '
                'patungong ${DateFormat('MMM d').format(newStart)} – ${DateFormat('MMM d, yyyy').format(newEnd)} '
                'dahil sa maintenance. '
                'Maaari mong kanselahin o tanggapin ang bagong schedule.',
            type: 'maintenance_reschedule',
            extra: {
              'requestId': request.requestId,
              'equipmentId': equipment.id,
              'ownerId': equipment.ownerId,
              'canCancel': true,
              'canAccept': true,
              'newStart': Timestamp.fromDate(newStart),
              'newEnd': Timestamp.fromDate(newEnd),
            },
          ));
          // Advance the cascade pointer so the next booking shifts off this one's new end.
          blockedUntil = DateTime(newEnd.year, newEnd.month, newEnd.day);
        }
      }
    }

    await batch.commit();
    await Future.wait(notifFutures);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUnforeseen
                ? '⚠️ Maintenance na-set. Ang mga apektadong booking ay kinansela.'
                : '✅ Maintenance na-schedule. Ang mga booking ay na-reschedule.',
          ),
          backgroundColor: isUnforeseen ? Colors.red : Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maintenance error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// --------------- HELPER: send in-app notification ---------------
Future<void> _sendNotification({
  required String userId,
  required String title,
  required String body,
  required String type,
  Map<String, dynamic> extra = const {},
}) async {
  await FirebaseFirestore.instance
      .collection('notifications')
      .doc(userId)
      .collection('items')
      .add({
    'title': title,
    'body': body,
    'type': type,
    'read': false,
    'createdAt': FieldValue.serverTimestamp(),
    ...extra,
  });
}

  void _showCancelDialog(BuildContext context, RentRequest request,
      {required bool isRenter}) {
    // Case 1: strike if renter cancels after approval.
    final isPostApproval = isRenter &&
        (request.status == RentRequestStatus.approved ||
            request.status == RentRequestStatus.readyForPickup);

    final requestBloc = context.read<RequestBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Request',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(isRenter
            ? isPostApproval
                ? 'Sigurado ka bang gusto mong kanselahin ang approved na rental na ito? '
                  'Ang pagkansela pagkatapos ng pag-apruba ay magdudulot ng isang paglabag sa iyong account.'
                : 'Are you sure you want to cancel this rental request? This cannot be undone.'
            : 'Are you sure you want to cancel this request? The renter will be notified.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Go Back'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              requestBloc.add(RequestStatusUpdated(
                  request.requestId, RentRequestStatus.canceled));

              // ── Case 1: issue strike for post-approval cancel ────────────
              if (isPostApproval) {
                try {
                  await StrikeService().submitReport(
                    requestId        : request.requestId,
                    renterId         : request.renterId,
                    ownerId          : request.ownerId,
                    reason           : 'cancel_after_approval',
                    details          : 'Renter cancelled after the request was approved.',
                    blockDurationDays: kBlockDurationCancelStrike,
                  );
                } catch (e) {
                  debugPrint('Case 1 strike failed (non-fatal): $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  bool _canRenterCancel(RentRequest request) {
    if (request.status == RentRequestStatus.pending) return true;
    if (request.status == RentRequestStatus.approved ||
        request.status == RentRequestStatus.readyForPickup) {
      final approvedAt = request.createdAt;
      if (approvedAt != null) {
        return DateTime.now().difference(approvedAt).inHours < 24;
      }
      return true;
    }
    return false;
  }

  bool _canOwnerCancel(RentRequest request) {
    return request.status == RentRequestStatus.pending ||
        request.status == RentRequestStatus.approved ||
        request.status == RentRequestStatus.readyForPickup;
  }

  // ── Replace your old _proofImage() helper with this ───────────────────────
Widget _proofImages(
  List<String> urls,
  String label,
  BuildContext context,
) {
  if (urls.isEmpty) return const SizedBox.shrink();
 
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label row
        Row(
          children: [
            const Icon(Icons.photo_library_outlined,
                size: 14, color: Color(0xFF3B82F6)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '(${urls.length})',
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
        const SizedBox(height: 8),
 
        // Horizontally scrollable image strip
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final url = urls[i];
              final isVideo = _isVideoUrl(url);
 
              return GestureDetector(
                onTap: () => _openProofViewer(context, urls, initialIndex: i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: isVideo
                      ? _videoThumbnailTile(url)
                      : Image.network(
                          url,
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                                  ? child
                                  : Container(
                                      width: 110,
                                      height: 110,
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    ),
                          errorBuilder: (_, __, ___) => Container(
                            width: 110,
                            height: 110,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image_outlined,
                                color: Colors.grey),
                          ),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}
 
/// Dark tile with play icon for video URLs
Widget _videoThumbnailTile(String url) {
  return Container(
    width: 110,
    height: 110,
    color: Colors.grey.shade800,
    child: const Center(
      child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 36),
    ),
  );
}
 
/// Detect video by URL extension
bool _isVideoUrl(String url) {
  final ext = url.split('?').first.split('.').last.toLowerCase();
  return ['mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v'].contains(ext);
}
 
/// Full-screen viewer — tap to open any proof
void _openProofViewer(
  BuildContext context,
  List<String> urls, {
  int initialIndex = 0,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ProofViewerPage(urls: urls, initialIndex: initialIndex),
    ),
  );
}

} // end of _RequestSentPageState


