import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/widgets/custom_divider.dart';
import 'package:bukidbayan_app/widgets/step_header.dart';
import 'package:flutter/material.dart';

class DeliveryMethodStep extends StatelessWidget {
  final DeliveryMethod selected;
  final ValueChanged<DeliveryMethod> onChanged;

  /// Equipment location — shown as a hint under the Pickup option
  final String? equipmentLocation;

  const DeliveryMethodStep({
    super.key,
    required this.selected,
    required this.onChanged,
    this.equipmentLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CustomDivider(),
        const StepHeader(
          title: 'Step 3: Paraan ng Pagkuha',
          subtitle: 'Piliin kung kukuha ka mismo o ipapadala.',
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _MethodCard(
                icon: Icons.directions_walk_rounded,
                label: 'Pick Up',
                subtitle: equipmentLocation != null && equipmentLocation!.isNotEmpty
                    ? equipmentLocation!
                    : 'Collect from equipment location',
                isSelected: selected == DeliveryMethod.pickup,
                onTap: () => onChanged(DeliveryMethod.pickup),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MethodCard(
                icon: Icons.local_shipping_rounded,
                label: 'Delivery',
                subtitle: 'Owner delivers to your address',
                isSelected: selected == DeliveryMethod.delivery,
                onTap: () => onChanged(DeliveryMethod.delivery),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = lightColorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              size: 22,
              color: isSelected ? primary : Colors.black45,
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
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? primary : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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