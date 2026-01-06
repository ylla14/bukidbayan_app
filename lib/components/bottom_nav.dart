import 'package:flutter/material.dart';
import 'package:bukidbayan_app/screens/home_screen.dart';
import 'package:bukidbayan_app/screens/profile_screen.dart';
import 'package:bukidbayan_app/theme/theme.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int currentIndex = 0;

  final List<Widget> screens = [
    HomeScreen(),     // Full home screen widget
    ProfileScreen(),  // Full profile screen widget
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[currentIndex],  // Each screen handles its own layout
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        backgroundColor: lightColorScheme.primary,
        unselectedItemColor: Colors.white54,
        selectedItemColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
