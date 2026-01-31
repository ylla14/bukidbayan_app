import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';

class CustomDrawer extends StatelessWidget {
  final Future<void> Function() onLogout;

  const CustomDrawer({
    super.key,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: lightColorScheme.onPrimary,
      surfaceTintColor: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(30),
        children: [
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
          ),

          ListTile(
            leading: const Icon(Icons.circle),
            title: const Text('Menu 2'),
          ),

          const Divider(),

          //LOGOUT BUTTON
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              await onLogout();

              // Navigate back to login screen
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/login',
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
