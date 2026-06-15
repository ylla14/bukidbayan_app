import 'dart:async';

import 'package:bukidbayan_app/screens/crowdfunding_payment_return_screen.dart';
import 'package:bukidbayan_app/screens/auth/signin_screen.dart';
import 'package:bukidbayan_app/services/auth_services.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:bukidbayan_app/services/weather_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/screens/welcome_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirestoreService firestoreService = FirestoreService();
  await firestoreService.validateAllEquipmentAvailability();
  await firestoreService.seedEquipmentDropdownOptions();
  await AuthService().seedCoopAccount();
  unawaited(WeatherService().runWeatherCheck());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final name = settings.name;
    if (name == null || name.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(name);
    if (uri == null) {
      return null;
    }

    if (uri.path == CrowdfundingPaymentReturnScreen.routePath) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => CrowdfundingPaymentReturnScreen(
          campaignId: uri.queryParameters['campaignId'],
          attemptId: uri.queryParameters['attemptId'],
          paymentStatusHint: uri.queryParameters['paymentStatus'],
        ),
      );
    }

    return null;
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {
        '/login': (context) => SignInScreen(),
        // '/home': (context) =>  HomeScreen(),
        // add more screens here as needed
      },
      onGenerateRoute: _onGenerateRoute,
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
