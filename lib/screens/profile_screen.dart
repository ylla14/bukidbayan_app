// profile_screen.dart
import 'package:bukidbayan_app/components/app_bar.dart';
import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void doProfileStuff() {
    print("Profile function called!");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      drawer: CustomDrawer(),
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
