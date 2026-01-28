import 'package:bukidbayan_app/screens/dashboard/home_screen.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';

class RequestSentPage extends StatelessWidget {
  const RequestSentPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Simulated renting steps
    final steps = [
      'Request Received',
      'Being Processed',
      'In Progress',
      'Completed',
    ];

    final currentStep = 0; // The first step after sending request

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Sent'),
        centerTitle: true,
        backgroundColor: lightColorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline,
                color: lightColorScheme.primary, size: 80),
            const SizedBox(height: 16),
            const Text(
              'Your request has been sent!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),

            // Steps
            Expanded(
              child: ListView.builder(
                itemCount: steps.length,
                itemBuilder: (context, index) {
                  bool completed = index < currentStep;
                  bool inProgress = index == currentStep;

                  return ListTile(
                    leading: Icon(
                      completed
                          ? Icons.check_circle
                          : inProgress
                              ? Icons.autorenew
                              : Icons.radio_button_unchecked,
                      color: completed
                          ? Colors.green
                          : inProgress
                              ? Colors.orange
                              : Colors.grey,
                    ),
                    title: Text(
                      steps[index],
                      style: TextStyle(
                        color: completed
                            ? Colors.green
                            : inProgress
                                ? Colors.orange
                                : Colors.grey,
                        fontWeight: inProgress ? FontWeight.bold : null,
                      ),
                    ),
                  );
                },
              ),
            ),

            ElevatedButton(
              onPressed: () {
                // Navigate back to home or requests page
                Navigator.pop(context, () => const HomeScreen());
              },
              child: const Text('Back to Home'),
            )
          ],
        ),
      ),
    );
  }
}
