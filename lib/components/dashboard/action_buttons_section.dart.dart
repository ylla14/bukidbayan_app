import 'package:flutter/material.dart';
import 'package:bukidbayan_app/widgets/custom_icon_button.dart';
import 'package:bukidbayan_app/screens/dashboard/rentals_list.dart';

class ActionButtonsSection extends StatelessWidget {
  const ActionButtonsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomIconButton(
          icon: const Icon(Icons.add_box_rounded),
          label: const Text('My Rental Requests'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    RentalsList(mode: RentalsListMode.myRequests),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        CustomIconButton(
          icon: const Icon(Icons.inbox_rounded),
          label: const Text('Requests for My Equipment'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    RentalsList(mode: RentalsListMode.incomingRequests),
              ),
            );
          },
        ),
      ],
    );
  }
}
