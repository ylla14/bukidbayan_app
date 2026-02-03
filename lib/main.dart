import 'package:bukidbayan_app/screens/auth/signin_screen.dart';
import 'package:bukidbayan_app/screens/dashboard/home_screen.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/screens/welcome_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  FirestoreService firestoreService = FirestoreService(); // create instance
  await firestoreService.validateAllEquipmentAvailability(); // call method
  await firestoreService.seedEquipmentDropdownOptions(); // seed dropdown options if not yet in Firestore
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {
        '/login': (context) =>  SignInScreen(),
        // '/home': (context) =>  HomeScreen(),
        // add more screens here as needed
      },
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      scaffoldBackgroundColor: Colors.white,
      colorScheme: lightColorScheme,
      useMaterial3: true,
    ),
    home: const WelcomeScreen(),
  );

  }
}

