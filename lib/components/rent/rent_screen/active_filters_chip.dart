import 'package:flutter/material.dart';
import 'package:bukidbayan_app/theme/theme.dart';

class ActiveFiltersChip extends StatelessWidget {
  final String label;
  final VoidCallback onClear;

  const ActiveFiltersChip({
    super.key,
    required this.label,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: lightColorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: lightColorScheme.primary,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: lightColorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClear,
            child: Icon(
              Icons.clear,
              size: 16,
              color: lightColorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
