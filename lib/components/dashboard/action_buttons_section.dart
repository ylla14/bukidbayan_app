import 'package:bukidbayan_app/screens/dashboard/earnings_report_page.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/screens/dashboard/rentals_list.dart';

class ActionButtonsSection extends StatelessWidget {
  const ActionButtonsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        Text(
          "Mabilis na Aksyon",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),

        // Side-by-side action cards
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.add_box_rounded,
                label: "Aking Rental\nRequests",
                color: lightColorScheme.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RentalsList(mode: RentalsListMode.myRequests),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionCard(
                icon: Icons.inbox_rounded,
                label: "Paparating na\nRequests",
                color: lightColorScheme.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RentalsList(mode: RentalsListMode.incomingRequests),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Full-width earnings button
        _ActionCard(
          icon: Icons.payments_rounded,
          label: "Kabuuang Kita mula sa Natapos na Renta",
          color: lightColorScheme.primary,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EarningsReportPage()),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: color.withOpacity(0.9),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}