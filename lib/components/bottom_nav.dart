import 'package:bukidbayan_app/components/crop_preference_dialog.dart';
import 'package:bukidbayan_app/screens/admin/admin_screen.dart';
import 'package:bukidbayan_app/screens/crowdfunding_screen.dart';
import 'package:bukidbayan_app/screens/rent/rent_screen.dart';
import 'package:bukidbayan_app/services/app_language.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/screens/dashboard/home_screen.dart';
import 'package:bukidbayan_app/screens/profile/profile_screen.dart';
import 'package:bukidbayan_app/theme/theme.dart';

class BottomNav extends StatefulWidget {
  const BottomNav({super.key});

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> {
  int currentIndex = 0;

  final List<Widget> screens = [
    HomeScreen(),
    RentScreen(),
    CrowdfundingScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkCropPreferences(),
    );
  }

  Future<void> _checkCropPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;

    final prefs = await FirestoreService().getCropPreferences(user.uid);
    if (prefs == null && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => CropPreferenceDialog(userId: user.uid),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLanguageScope(
      builder: (context) => Scaffold(
        body: screens[currentIndex],
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
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home),
              label: AppLanguage.text(en: 'Home', tl: 'Tahanan'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.build),
              label: AppLanguage.text(en: 'Equipment', tl: 'Kagamitan'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.volunteer_activism),
              label: AppLanguage.text(en: 'Campaigns', tl: 'Kampanya'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person),
              label: AppLanguage.text(en: 'Profile', tl: 'Profile'),
            ),
          ],
        ),
      ),
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

/// Minimal shell for the co-op account — shows Admin Dashboard instead of regular navigation.
class CoopBottomNav extends StatefulWidget {
  const CoopBottomNav({super.key});

  @override
  State<CoopBottomNav> createState() => _CoopBottomNavState();
}

class _CoopBottomNavState extends State<CoopBottomNav> {
  int currentIndex = 0;

  final List<Widget> coopScreens = [
    CrowdfundingScreen(isCoop: true),
    AdminScreen(isCoop: true),
  ];

  @override
  Widget build(BuildContext context) {
    return AppLanguageScope(
      builder: (context) => Scaffold(
        body: coopScreens[currentIndex],
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
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.volunteer_activism),
              label: AppLanguage.text(en: 'Campaigns', tl: 'Kampanya'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.admin_panel_settings),
              label: AppLanguage.text(en: 'Admin', tl: 'Admin'),
            ),
          ],
        ),
      ),
    );
  }
}
