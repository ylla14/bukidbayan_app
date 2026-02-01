import 'package:bukidbayan_app/models/equipment.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/widgets/availability_box.dart';
// import 'package:bukidbayan_app/models/rentModel.dart';


class ProductAvailability extends StatelessWidget {
  final Equipment item;

  const ProductAvailability({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
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
        ],
      ),
    );
  }
}
