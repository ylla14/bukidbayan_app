import 'dart:async';

import 'package:bukidbayan_app/screens/crowdfunding_payment_return_screen.dart';
import 'package:bukidbayan_app/screens/auth/signin_screen.dart';
import 'package:bukidbayan_app/services/auth_services.dart';
import 'package:bukidbayan_app/services/commercial_rate_benchmark_service.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:bukidbayan_app/services/platform_telemetry_service.dart';
import 'package:bukidbayan_app/services/weather_service.dart';
import 'package:bukidbayan_app/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:bukidbayan_app/screens/welcome_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final telemetry = PlatformTelemetryService();
  final firestoreService = FirestoreService();
  final benchmarkService = CommercialRateBenchmarkService();

  await telemetry.logAppOpen(source: 'app_main');
  await telemetry.recordHeartbeat(source: 'app_startup');

  Future<void> runStartupTask(
    String taskName,
    Future<void> Function() task,
  ) async {
    try {
      await task();
      await telemetry.logBackgroundTaskResult(
        taskName: taskName,
        success: true,
      );
    } catch (error, stackTrace) {
      await telemetry.logBackgroundTaskResult(
        taskName: taskName,
        success: false,
        message: error.toString(),
        metadata: {'stackTrace': stackTrace.toString()},
      );
    }
  }

  await runStartupTask(
    'validate_equipment_availability',
    firestoreService.validateAllEquipmentAvailability,
  );
  await runStartupTask(
    'seed_equipment_dropdown_options',
    firestoreService.seedEquipmentDropdownOptions,
  );
  await runStartupTask('seed_coop_account', AuthService().seedCoopAccount);
  await runStartupTask(
    'seed_commercial_rate_benchmarks',
    benchmarkService.seedDefaultBenchmarks,
  );
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
