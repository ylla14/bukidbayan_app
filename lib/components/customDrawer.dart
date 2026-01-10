import 'package:flutter/material.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
       surfaceTintColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.all(30),
          children: [
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              // onTap: () {
              //   Navigator.pushReplacement(
              //     context, MaterialPageRoute(
              //       builder: (e) => ProfileScreen(),
              //     )
              //   );
              // } ,
            ),
            ListTile(
              leading: Icon(Icons.circle),
              title: Text('Menu 2')
            )
          ],
        )
    );
  }
}