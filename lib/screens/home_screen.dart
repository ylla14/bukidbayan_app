
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/theme/theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void doSomething() {
    print("Home function called!");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: lightColorScheme.primary,
        title: Text("Home"),
      ),
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
