import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/screens/welcome_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BukidBayan',
      theme: ThemeData(
        scaffoldBackgroundColor: lightColorScheme.surface,
      ),
      home: WelcomeScreen(),
    );
  }
}

