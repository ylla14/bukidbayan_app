import 'package:bukidbayan_app/screens/location_picker_screen.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class AddressStep extends StatefulWidget {
  /// Pre-filled from user profile
  final String? profileAddress;
  final double? profileLat;
  final double? profileLng;

  /// Pre-filled from user profile's farm field
  final String? profileFarmAddress;
  final double? profileFarmLat;
  final double? profileFarmLng;

  final TextEditingController addressController;
  final ValueChanged<double?> onLatChanged;
  final ValueChanged<double?> onLngChanged;

  const AddressStep({
    super.key,
    required this.profileAddress,
    required this.profileLat,
    required this.profileLng,
    required this.profileFarmAddress,
    required this.profileFarmLat,
    required this.profileFarmLng,
    required this.addressController,
    required this.onLatChanged,
    required this.onLngChanged,
  });

  @override
  State<AddressStep> createState() => _AddressStepState();
}

class _AddressStepState extends State<AddressStep> {
  String _mode = 'my'; // 'my' or 'farm'

  double? _pickedLat;
  double? _pickedLng;
  String? _pickedAddress; // last value set by map picker

  bool get _profileHasAddress =>
      widget.profileAddress != null && widget.profileAddress!.isNotEmpty;

  bool get _profileHasFarmAddress =>
      widget.profileFarmAddress != null && widget.profileFarmAddress!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (!_profileHasAddress) {
      _mode = 'farm';
    } else {
      widget.addressController.text = widget.profileAddress!;
      // Defer parent setState calls until after the current build is done
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onLatChanged(widget.profileLat);
        widget.onLngChanged(widget.profileLng);
      });
    }
  }

  void _selectMode(String mode) {
    setState(() => _mode = mode);
    if (mode == 'my') {
      widget.addressController.text = widget.profileAddress ?? '';
      widget.onLatChanged(widget.profileLat);
      widget.onLngChanged(widget.profileLng);
    } else {
      // Pre-fill with farm address from profile, if available
      widget.addressController.text = widget.profileFarmAddress ?? '';
      widget.onLatChanged(widget.profileFarmLat);
      widget.onLngChanged(widget.profileFarmLng);
      // Sync picker coords so the GPS badge shows immediately
      _pickedLat     = widget.profileFarmLat;
      _pickedLng     = widget.profileFarmLng;
      _pickedAddress = widget.profileFarmAddress;
    }
  }

  Future<void> _openMapPicker() async {
    final initial = (_pickedLat != null && _pickedLng != null)
        ? LatLng(_pickedLat!, _pickedLng!)
        : (widget.profileFarmLat != null && widget.profileFarmLng != null)
            ? LatLng(widget.profileFarmLat!, widget.profileFarmLng!)
            : null;

    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(initialPosition: initial),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        widget.addressController.text = result.address;
        _pickedLat     = result.latitude;
        _pickedLng     = result.longitude;
        _pickedAddress = result.address;
      });
      widget.onLatChanged(result.latitude);
      widget.onLngChanged(result.longitude);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Address',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: lightColorScheme.primary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Saan dadalhin o ipapadala ang kagamitan?',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 10),

        // ── Option cards ────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _AddressOptionCard(
                icon: Icons.home_rounded,
                label: 'My Address',
                subtitle: _profileHasAddress
                    ? widget.profileAddress!
                    : 'No address in profile',
                isSelected: _mode == 'my',
                isDisabled: !_profileHasAddress,
                onTap: () => _selectMode('my'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AddressOptionCard(
                icon: Icons.grass_rounded,
                label: 'Farm Field Address',
                subtitle: _profileHasFarmAddress
                    ? widget.profileFarmAddress!
                    : (_mode == 'farm' && widget.addressController.text.isNotEmpty)
                        ? widget.addressController.text
                        : 'Tap to set farm address',
                isSelected: _mode == 'farm',
                isDisabled: false,
                onTap: () => _selectMode('farm'),
              ),
            ),
          ],
        ),

        // ── Farm Field text input ───────────────────────────────────
        if (_mode == 'farm') ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: widget.addressController,
            maxLines: 2,
            keyboardType: TextInputType.streetAddress,
            onChanged: (v) {
              // User typed manually — clear picker coords
              if (_pickedAddress != null && v != _pickedAddress) {
                setState(() {
                  _pickedLat     = null;
                  _pickedLng     = null;
                  _pickedAddress = null;
                });
                widget.onLatChanged(null);
                widget.onLngChanged(null);
              }
            },
            decoration: InputDecoration(
              hintText: 'Lokasyon ng bukid / farm field',
              hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
              prefixIcon: Icon(Icons.location_on_outlined,
                  color: lightColorScheme.primary, size: 20),
              suffixIcon: IconButton(
                icon: Icon(Icons.map_outlined,
                    color: lightColorScheme.primary, size: 22),
                tooltip: 'Pumili sa mapa',
                onPressed: _openMapPicker,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.black12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: lightColorScheme.primary.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: lightColorScheme.primary, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          if (_pickedLat != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Row(
                children: [
                  Icon(Icons.my_location_rounded,
                      size: 12, color: lightColorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'GPS: ${_pickedLat!.toStringAsFixed(5)}, '
                    '${_pickedLng!.toStringAsFixed(5)}',
                    style: TextStyle(
                        fontSize: 11, color: lightColorScheme.primary),
                  ),
                ],
              ),
            ),
          ],
        ],

        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Option card ───────────────────────────────────────────────────────────────

class _AddressOptionCard extends StatelessWidget {
  final IconData    icon;
  final String      label;
  final String      subtitle;
  final bool        isSelected;
  final bool        isDisabled;
  final VoidCallback onTap;

  const _AddressOptionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = lightColorScheme.primary;
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primary.withOpacity(0.08) : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? primary : Colors.black12,
            width: isSelected ? 1.8 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: isDisabled
                  ? Colors.grey.shade400
                  : isSelected
                      ? primary
                      : Colors.black45,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isDisabled
                          ? Colors.grey.shade400
                          : isSelected
                              ? primary
                              : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDisabled
                          ? Colors.grey.shade300
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}