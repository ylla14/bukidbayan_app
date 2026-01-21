import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
             colors: [lightColorScheme.primary, lightColorScheme.secondary],
             stops: [0.0, 0.9]
          )
          
        ),
      ),
      backgroundColor: lightColorScheme.primary,
      centerTitle: true,
      title: Icon(Icons.person),
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
      ),
      actions: [
          // IconButton(
          //   onPressed: () {
          //     Navigator.push(context, MaterialPageRoute(builder: (e) => const EquipmentListingScreen(),));
          //   },
          //   icon: Icon(Icons.add_box_rounded),
          // ),

             IconButton(
              icon: const Icon(Icons.notifications_outlined),
              iconSize: 35,
              onPressed: () {
                // TODO: navigate to notifications screen
              },
            ),

        ],
    );
  }

  // Required so Scaffold knows how tall the AppBar is
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
