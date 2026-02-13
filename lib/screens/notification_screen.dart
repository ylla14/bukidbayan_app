import 'package:bukidbayan_app/screens/migration_page.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';


class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  // Sample notifications data
  final List<Map<String, String>> notifications = const [
    {
      'title': 'New Message',
      'subtitle': 'You received a new message from John',
      'time': '2h ago',
    },
    {
      'title': 'Equipment Ready',
      'subtitle': 'Your rented equipment is ready',
      'time': '4h ago',
    },
    {
      'title': 'Payment Received',
      'subtitle': 'We received your payment successfully',
      'time': '1d ago',
    },
    {
      'title': 'Update Available',
      'subtitle': 'New app update is available',
      'time': '2d ago',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications',style: TextStyle(color: lightColorScheme.onPrimary),),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [lightColorScheme.primary, lightColorScheme.secondary],
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Text(
                'No notifications yet!',
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                return ListTile(
                  leading: const Icon(Icons.notifications, color: Colors.blue),
                  title: Text(
                    notif['title']!,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text(notif['subtitle']!),
                  trailing: Text(
                    notif['time']!,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onTap: () {
                    // Handle notification tap if needed
                  },
                );
              },
            ),

            floatingActionButton: FloatingActionButton(
              mini: true,
              backgroundColor: lightColorScheme.primary,
              child: const Icon(Icons.settings, size: 18),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MigrationScreen(), // change to your page
                  ),
                );
              },
            ),
    );
  }
}


