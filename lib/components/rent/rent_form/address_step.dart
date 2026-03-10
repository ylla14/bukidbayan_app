import 'package:bukidbayan_app/screens/location_picker_screen.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class AddressStep extends StatefulWidget {
  /// Pre-filled from user profile
  final String? profileAddress;
  final double? profileLat;
  final double? profileLng;

  final TextEditingController addressController;
  final ValueChanged<double?> onLatChanged;
  final ValueChanged<double?> onLngChanged;

  const AddressStep({
    super.key,
    required this.profileAddress,
    required this.profileLat,
    required this.profileLng,
    required this.addressController,
    required this.onLatChanged,
    required this.onLngChanged,
  });

  @override
  State<AddressStep> createState() => _AddressStepState();
}

class _AddressStepState extends State<AddressStep> {
  String _mode = 'my'; // 'my' or 'other'

  double? _pickedLat;
  double? _pickedLng;
  String? _pickedAddress; // last value set by map picker

  bool get _profileHasAddress =>
      widget.profileAddress != null && widget.profileAddress!.isNotEmpty;

@override
void initState() {
  super.initState();
  if (!_profileHasAddress) {
    _mode = 'other';
  } else {
    widget.addressController.text = widget.profileAddress!;
    // ✅ Defer parent setState calls until after the current build is done
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
      // Clear to force explicit input
      widget.addressController.text = '';
      widget.onLatChanged(null);
      widget.onLngChanged(null);
    }
  }

  Future<void> _openMapPicker() async {
    final initial = (_pickedLat != null && _pickedLng != null)
        ? LatLng(_pickedLat!, _pickedLng!)
        : (widget.profileLat != null && widget.profileLng != null)
            ? LatLng(widget.profileLat!, widget.profileLng!)
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
                icon: Icons.edit_location_alt_rounded,
                label: 'Other Address',
                subtitle: (_mode == 'other' &&
                        widget.addressController.text.isNotEmpty)
                    ? widget.addressController.text
                    : 'Tap to set address',
                isSelected: _mode == 'other',
                isDisabled: false,
                onTap: () => _selectMode('other'),
              ),
            ),
          ],
        ),

        // ── 'Other' text input ──────────────────────────────────────
        if (_mode == 'other') ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: widget.addressController,
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
              hintText: 'Type address or pick on map',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: lightColorScheme.primary.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    BorderSide(color: lightColorScheme.primary, width: 2),
              ),
              suffixIcon: IconButton(
                icon: Icon(Icons.map_outlined,
                    color: lightColorScheme.primary),
                tooltip: 'Pick on map',
                onPressed: _openMapPicker,
              ),
            ),
          ),
          if (_pickedLat != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 14, color: Colors.green.shade600),
                const SizedBox(width: 4),
                Text(
                  'Location pinned on map',
                  style: TextStyle(
                      fontSize: 11, color: Colors.green.shade600),
                ),
              ],
            ),
          ],
        ],

        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Option card (same style as equipment listing) ─────────────────────────────

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