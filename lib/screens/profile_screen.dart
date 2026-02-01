// profile_screen.dart
import 'package:bukidbayan_app/components/app_bar.dart';
import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  ProfileScreen({super.key});

  final FirebaseAuth _auth = FirebaseAuth.instance;

  void doProfileStuff() {
    print("Profile function called!");
  }

  Future<void> logout() async {
  await _auth.signOut();
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      drawer: CustomDrawer(onLogout: logout,),
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
