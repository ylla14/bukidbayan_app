import 'package:bukidbayan_app/screens/rent_screen.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/screens/home_screen.dart';
import 'package:bukidbayan_app/screens/profile_screen.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:bukidbayan_app/screens/crowdfunding_screen.dart';


class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int currentIndex = 0;

  final List<Widget> screens = [
    HomeScreen(),   // Full home screen widget
    CrowdfundingScreen(),  
    RentScreen(),
    ProfileScreen(),  // Full profile screen widget
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[currentIndex],  // Each screen handles its own layout
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
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
            icon: Icon(Icons.volunteer_activism),
            label: 'Crowdfund',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.build),
            label: 'Rent',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),

      // body: screens[currentIndex],
      // bottomNavigationBar: NavigationBar(
      //   animationDuration: const Duration(seconds: 1),
      //   selectedIndex: currentIndex,
      //   onDestinationSelected: (index){
      //     setState(() {
      //       currentIndex = index;
      //     });
      //   },
      //   backgroundColor: lightColorScheme.primary,
      //   destinations: _navBarItems,
      // ),
    );
  }
}

// const _navBarItems = [
//   NavigationDestination(
//     icon: Icon(Icons.home),
//     selectedIcon: Icon(Icons.home_rounded),
//     label: 'Home',
//   ),
//   NavigationDestination(
//     icon: Icon(Icons.build),
//     selectedIcon: Icon(Icons.build_rounded),
//     label: 'Rent',
//   ),
//   NavigationDestination(
//     icon: Icon(Icons.person),
//     label: 'Profile',
//   )
// ];
