import 'package:flutter/material.dart';
import 'package:bukidbayan_app/widgets/availability_box.dart';
// import 'package:bukidbayan_app/models/rentModel.dart';
import 'package:bukidbayan_app/mock_data/rent_items.dart';


class ProductAvailability extends StatelessWidget {
  final RentItem item;

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
                  value: item.availableFrom ?? 'Not specified',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AvailabilityBox(
                  label: 'To',
                  value: item.availableTo ?? 'Not specified',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
