import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Returned by [LocationPickerScreen] via Navigator.pop.
class LocationPickerResult {
  final double latitude;
  final double longitude;
  final String address;

  const LocationPickerResult({
    required this.latitude,
    required this.longitude,
    required this.address,
  });
}

/// Full-screen Google Maps picker. The user taps (or drags the marker) to
/// choose a location. A bottom sheet shows the reverse-geocoded address and
/// a Confirm button.
///
/// Usage:
/// ```dart
/// final result = await Navigator.push<LocationPickerResult>(
///   context,
///   MaterialPageRoute(builder: (_) => LocationPickerScreen(
///     initialPosition: LatLng(lat, lng), // optional
///   )),
/// );
/// if (result != null) { /* use result.latitude, .longitude, .address */ }
/// ```
class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialPosition;

  const LocationPickerScreen({super.key, this.initialPosition});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  // Default centre: Cabuyao, Laguna
  static const LatLng _defaultCenter = LatLng(14.2470, 121.1367);

  LatLng? _picked;
  String? _address;
  bool _isResolving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _picked = widget.initialPosition;
      _reverseGeocode(widget.initialPosition!);
    }
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() {
      _isResolving = true;
      _address = null;
    });
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json'
        '&lat=${pos.latitude}'
        '&lon=${pos.longitude}'
        '&zoom=16'
        '&addressdetails=1',
      );
      final response = await http.get(uri, headers: {
        'Accept-Language': 'en',
        'User-Agent': 'BukidbayanApp/1.0',
      });

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() => _address = data['display_name'] as String?);
      } else {
        // Fallback to raw coordinates
        setState(() => _address = _coordLabel(pos));
      }
    } catch (_) {
      if (mounted) setState(() => _address = _coordLabel(pos));
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  String _coordLabel(LatLng pos) =>
      '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';

  void _onMapTap(LatLng pos) {
    setState(() {
      _picked = pos;
      _address = null;
    });
    _reverseGeocode(pos);
  }

  void _onMarkerDragEnd(LatLng pos) {
    setState(() {
      _picked = pos;
      _address = null;
    });
    _reverseGeocode(pos);
  }

  void _confirm() {
    if (_picked == null) return;
    Navigator.pop(
      context,
      LocationPickerResult(
        latitude: _picked!.latitude,
        longitude: _picked!.longitude,
        address: _address ?? _coordLabel(_picked!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.initialPosition ?? _defaultCenter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: center, zoom: 14),

            onTap: _onMapTap,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: _picked == null
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId('selected'),
                      position: _picked!,
                      draggable: true,
                      onDragEnd: _onMarkerDragEnd,
                    ),
                  },
          ),

          // Hint banner before a pin is placed
          if (_picked == null)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    'Tap on the map to drop a pin on your location',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
              ),
            ),

          // Bottom sheet shown once a pin is placed
          if (_picked != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selected Location',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    if (_isResolving)
                      const Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Resolving address…',
                            style: TextStyle(color: Colors.black54, fontSize: 14),
                          ),
                        ],
                      )
                    else
                      Text(
                        _address ?? 'Address unavailable',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      _coordLabel(_picked!),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isResolving ? null : _confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Confirm Location',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
