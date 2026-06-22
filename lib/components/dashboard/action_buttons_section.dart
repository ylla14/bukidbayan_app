import 'package:bukidbayan_app/screens/dashboard/earnings_report_page.dart';
import 'package:bukidbayan_app/screens/dashboard/renter_analytics_screen.dart';
import 'package:bukidbayan_app/services/analytics/renter_analytics_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/screens/dashboard/rentals_list.dart';

class ActionButtonsSection extends StatelessWidget {
  final RenterAnalyticsService? renterAnalyticsServiceOverride;
  final String? renterAnalyticsRenterIdOverride;

  const ActionButtonsSection({
    super.key,
    this.renterAnalyticsServiceOverride,
    this.renterAnalyticsRenterIdOverride,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        Text(
          "Mabilis na Aksyon",
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                    builder: (_) =>
                        RentalsList(mode: RentalsListMode.myRequests),
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
                    builder: (_) =>
                        RentalsList(mode: RentalsListMode.incomingRequests),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        _ActionCard(
          cardKey: const Key('my_rental_analytics_button'),
          icon: Icons.insights_rounded,
          label: "Aking Rental Analytics",
          color: lightColorScheme.primary,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RenterAnalyticsScreen(
                serviceOverride: renterAnalyticsServiceOverride,
                renterIdOverride: renterAnalyticsRenterIdOverride,
              ),
            ),
          ),
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
  final Key? cardKey;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    this.cardKey,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: cardKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
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
                  color: color.withValues(alpha: 0.9),
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
