import 'package:flutter/material.dart';
import 'package:bukidbayan_app/widgets/dashboard_summary_card.dart';

class SummaryCardsSection extends StatelessWidget {
  const SummaryCardsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          DashboardSummaryCard(
            icon: Icons.thermostat,
            title: 'Temperature',
            value: '32°C',
            subtitle: 'Feels hot',
            backgroundColor: const Color(0xFFFFF3E0),
            iconColor: Colors.deepOrange,
          ),
          const SizedBox(width: 12),
          DashboardSummaryCard(
            icon: Icons.water_drop,
            title: 'Humidity',
            value: '78%',
            subtitle: 'High humidity',
            backgroundColor: const Color(0xFFE3F2FD),
            iconColor: Colors.blue,
          ),
          const SizedBox(width: 12),
          DashboardSummaryCard(
            icon: Icons.cloudy_snowing,
            title: 'Rain Chance',
            value: '60%',
            subtitle: 'Possible showers',
            backgroundColor: const Color(0xFFE8F5E9),
            iconColor: Colors.green,
          ),
        ],
      ),
    );
  }
}
