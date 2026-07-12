import 'package:bukidbayan_app/services/app_language.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class GreetingSection extends StatelessWidget {
  const GreetingSection({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return AppLanguage.text(en: 'Good Morning', tl: 'Magandang Umaga');
    }
    if (hour < 17) {
      return AppLanguage.text(en: 'Good Afternoon', tl: 'Magandang Hapon');
    }
    return AppLanguage.text(en: 'Good Evening', tl: 'Magandang Gabi');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name =
        user?.displayName?.split(' ').first ??
        AppLanguage.text(en: 'Farmer', tl: 'Magsasaka');
    final today = DateFormat('EEEE, MMMM d').format(DateTime.now());
    final primary = Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "${_getGreeting()}, $name",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 19, // adjust as needed
              ),
            ),
            const SizedBox(height: 4),
            Text(
              today,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),

        // Avatar / initial badge
        CircleAvatar(
          radius: 22,
          backgroundColor: primary.withOpacity(0.15),
          child: Text(
            name[0].toUpperCase(),
            style: TextStyle(
              color: primary,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
      ],
    );
  }
}
