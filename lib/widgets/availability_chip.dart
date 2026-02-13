import 'package:flutter/material.dart';

class AvailabilityChip extends StatelessWidget {
  final bool isAvailable;
  final bool isPending; // 👈 ADD THIS

  const AvailabilityChip({
    super.key,
    required this.isAvailable,
    this.isPending = false, // 👈 ADD THIS with default
  });

  @override
  Widget build(BuildContext context) {
    // Priority: pending > unavailable > available
    Color chipColor;
    String chipText;
    
    if (isPending) {
      chipColor = Colors.orange[600]!;
      chipText = 'Pending Request';
    } else if (isAvailable) {
      chipColor = Colors.green[600]!;
      chipText = 'Available';
    } else {
      chipColor = Colors.red[600]!;
      chipText = 'Unavailable';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        chipText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}