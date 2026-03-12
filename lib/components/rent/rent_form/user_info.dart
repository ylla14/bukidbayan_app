import 'package:bukidbayan_app/screens/location_picker_screen.dart';
import 'package:bukidbayan_app/services/auth_services.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/custom_divider.dart';
import 'package:bukidbayan_app/widgets/custom_text_form_field.dart';
import 'package:bukidbayan_app/widgets/step_header.dart';
import 'package:flutter/material.dart';

class UserInfoStep extends StatefulWidget {
  final TextEditingController nameController;

  /// Controller for the farm address field. The parent owns it so it can
  /// pass the value to SubmitButton.
  final TextEditingController farmAddressController;

  /// Called whenever the user picks or geocodes a new farm location.
  /// Provides lat/lng so the parent can forward them to SubmitButton.
  final void Function(double lat, double lng)? onFarmLocationPicked;

  const UserInfoStep({
    super.key,
    required this.nameController,
    required this.farmAddressController,
    this.onFarmLocationPicked,
  });

  @override
  State<UserInfoStep> createState() => _UserInfoStepState();
}

class _UserInfoStepState extends State<UserInfoStep> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;

  // Coordinates from map picker (null if the user typed manually)
  double? _farmPickedLat;
  double? _farmPickedLng;
  String? _farmPickedAddress;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user != null) {
      final userData = await _authService.getUserData(user.uid);
      if (userData != null) {
        // Auto-fill name
        final name =
            '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'
                .trim();
        widget.nameController.text = name;

        // Auto-fill farm address if the field is still empty
        if (widget.farmAddressController.text.isEmpty) {
          final savedFarmAddress = userData['farmAddress'] as String?;
          if (savedFarmAddress != null && savedFarmAddress.isNotEmpty) {
            widget.farmAddressController.text = savedFarmAddress;

            // Pre-fill coordinates so we skip geocoding on submit
            final lat = (userData['farmLatitude'] as num?)?.toDouble();
            final lng = (userData['farmLongitude'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              _farmPickedLat = lat;
              _farmPickedLng = lng;
              _farmPickedAddress = savedFarmAddress;
              widget.onFarmLocationPicked?.call(lat, lng);
            }
          }
        }
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _openFarmPicker() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        widget.farmAddressController.text = result.address;
        _farmPickedLat = result.latitude;
        _farmPickedLng = result.longitude;
        _farmPickedAddress = result.address;
      });
      widget.onFarmLocationPicked?.call(result.latitude, result.longitude);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CustomDivider(),
        const StepHeader(
          title: 'Step 2: Impormasyon ng Umuupa',
          subtitle: 'Ilagay ang iyong buong pangalan.',
        ),
        CustomTextFormField(
            controller: widget.nameController, hint: 'Buong Pangalan'),

        const SizedBox(height: 20),

        // ── Farm Address ────────────────────────────────────────────────
        // Row(
        //   children: [
        //     Icon(Icons.grass_rounded,
        //         size: 18, color: lightColorScheme.primary),
        //     const SizedBox(width: 6),
        //     const Text(
        //       'Farm Field Address',
        //       style: TextStyle(
        //         fontSize: 14,
        //         fontWeight: FontWeight.w600,
        //         color: Colors.black87,
        //       ),
        //     ),
        //   ],
        // ),
        // const SizedBox(height: 6),
        // TextFormField(
        //   controller: widget.farmAddressController,
        //   maxLines: 2,
        //   onChanged: (val) {
        //     // Clear picked coords when the user manually edits
        //     if (_farmPickedAddress != null && val != _farmPickedAddress) {
        //       _farmPickedLat = null;
        //       _farmPickedLng = null;
        //       _farmPickedAddress = null;
        //     }
        //   },
        //   decoration: InputDecoration(
        //     hintText: 'Lokasyon ng bukid / farm field',
        //     hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        //     prefixIcon: Icon(Icons.location_on_outlined,
        //         color: lightColorScheme.primary, size: 20),
        //     suffixIcon: IconButton(
        //       icon: Icon(Icons.map_outlined,
        //           color: lightColorScheme.primary, size: 22),
        //       tooltip: 'Pumili sa mapa',
        //       onPressed: _openFarmPicker,
        //     ),
        //     border: OutlineInputBorder(
        //       borderRadius: BorderRadius.circular(10),
        //       borderSide: const BorderSide(color: Colors.black12),
        //     ),
        //     enabledBorder: OutlineInputBorder(
        //       borderRadius: BorderRadius.circular(10),
        //       borderSide: const BorderSide(color: Colors.black12),
        //     ),
        //     focusedBorder: OutlineInputBorder(
        //       borderRadius: BorderRadius.circular(10),
        //       borderSide:
        //           BorderSide(color: lightColorScheme.primary, width: 1.5),
        //     ),
        //     contentPadding:
        //         const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        //     filled: true,
        //     fillColor: Colors.grey.shade50,
        //   ),
        // ),

        // if (_farmPickedLat != null)
        //   Padding(
        //     padding: const EdgeInsets.only(top: 4, left: 4),
        //     child: Row(
        //       children: [
        //         Icon(Icons.my_location_rounded,
        //             size: 12, color: lightColorScheme.primary),
        //         const SizedBox(width: 4),
        //         Text(
        //           'GPS: ${_farmPickedLat!.toStringAsFixed(5)}, '
        //           '${_farmPickedLng!.toStringAsFixed(5)}',
        //           style: TextStyle(
        //               fontSize: 11, color: lightColorScheme.primary),
        //         ),
        //       ],
        //     ),
        //   ),
      ],
    );
  }
}