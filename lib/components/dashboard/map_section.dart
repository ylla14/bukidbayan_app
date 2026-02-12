import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapSection extends StatelessWidget {
  final LatLng cabuyao;
  final GoogleMapController? mapController;

  const MapSection({super.key, required this.cabuyao, required this.mapController});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Nearby Equipment",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: cabuyao,
              zoom: 13,
            ),
            onMapCreated: (controller) => mapController,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),
        ),
      ],
    );
  }
}
