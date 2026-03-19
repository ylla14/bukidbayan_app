import 'package:bukidbayan_app/models/equipment.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/widgets/availability_box.dart';

class ProductAvailability extends StatelessWidget {
  final Equipment item;

  const ProductAvailability({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final category = item.category?.toLowerCase();

    String? infoMessage;
    if (category == 'tractor' || category == 'harvester (halimaw)') {
      infoMessage = 'Ang kagamitang ito ay kayang magtrabaho ng hanggang 2 ektarya bawat araw.';
    } else if (category == 'floating tiller (pagong)' && category == 'hand tractor (kuliglig)') {
      infoMessage = 'Ang kagamitang ito ay kayang magtrabaho ng hanggang 1 ektarya bawat araw.';
    } 
    // else if (category == 'hand tractor (kuliglig)') {
    //   infoMessage = 'Ang kagamitang ito ay kayang magtrabaho ng hanggang 0.5 ektarya bawat araw.';
    // }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Availability',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AvailabilityBox(
                  label: 'From',
                  value: item.availableFrom != null
                      ? '${item.availableFrom!.month}/${item.availableFrom!.day}/${item.availableFrom!.year}'
                      : 'Not specified',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AvailabilityBox(
                  label: 'To',
                  value: item.availableUntil != null
                      ? '${item.availableUntil!.month}/${item.availableUntil!.day}/${item.availableUntil!.year}'
                      : 'Not specified',
                ),
              ),
            ],
          ),
          if (infoMessage != null) ...[
            const SizedBox(height: 10),
            _InfoBox(message: infoMessage),
          ],
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String message;

  const _InfoBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.green.shade800),
            ),
          ),
        ],
      ),
    );
  }
}