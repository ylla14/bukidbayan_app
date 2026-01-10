
import 'package:bukidbayan_app/components/app_bar.dart';
import 'package:bukidbayan_app/components/customDrawer.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void doSomething() {
    print("Home function called!");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      drawer: CustomDrawer(),
      body: Center(
        child: Column(
          children: [
            Text('Welcome to HomeScreen'),
            ElevatedButton(
              onPressed: doSomething,
              child: Text('Do something'),
            ),
          ],
        )
      ),
    );
  }
}
