import 'package:flutter/material.dart';

class RentItemCard extends StatelessWidget {
  final String title;
  final String price;
  final String rentRate; // 👈 add this
  final String imageUrl;

  const RentItemCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.price,
    required this.rentRate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.asset(imageUrl, fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₱$price ${_getRateSuffix(rentRate)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "est.",
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getRateSuffix(String rentRate) {
    switch (rentRate.toLowerCase()) {
      case 'per hour':
        return '/hour';
      case 'per day':
        return '/day';
      case 'per week':
        return '/week';
      case 'per month':
        return '/month';
      default:
        return '';
    }
  }
}


