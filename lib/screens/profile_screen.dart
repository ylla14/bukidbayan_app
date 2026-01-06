// profile_screen.dart
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/theme/theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void doProfileStuff() {
    print("Profile function called!");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: lightColorScheme.primary,
        title: Text("Profile"),
      ),
      body: Column(
        children: [
          Text('Welcome to ProfileScreen'),
          ElevatedButton(
            onPressed: doProfileStuff,
            child: Text('Do profile stuff'),
          ),
        ],
      ),
    );
  }
}
