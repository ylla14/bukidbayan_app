import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

const bool kUseFirebaseEmulators = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
  defaultValue: false,
);

const bool kUseFirebaseAuthEmulator = bool.fromEnvironment(
  'USE_FIREBASE_AUTH_EMULATOR',
  defaultValue: false,
);

const int kFirestoreEmulatorPort = 8080;
const int kFunctionsEmulatorPort = 5001;
const int kAuthEmulatorPort = 9099;

const String _configuredEmulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: '127.0.0.1',
);

bool get includeSeedCrowdfundingCampaigns =>
    kUseFirebaseEmulators ||
    const bool.fromEnvironment(
      'INCLUDE_SEED_CROWDFUNDING_CAMPAIGNS',
      defaultValue: false,
    );

String get firebaseEmulatorHost {
  final normalized = _configuredEmulatorHost.trim();
  if (kIsWeb) return normalized;

  final usesLoopback = normalized == '127.0.0.1' || normalized == 'localhost';
  if (defaultTargetPlatform == TargetPlatform.android && usesLoopback) {
    // Android emulators must use 10.0.2.2 to reach the host machine.
    return '10.0.2.2';
  }
  return normalized;
}

Future<void> configureFirebaseLocalEmulators() async {
  if (!kUseFirebaseEmulators) return;

  final host = firebaseEmulatorHost;

  FirebaseFirestore.instance.useFirestoreEmulator(host, kFirestoreEmulatorPort);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
    sslEnabled: false,
  );

  if (kUseFirebaseAuthEmulator) {
    await FirebaseAuth.instance.useAuthEmulator(host, kAuthEmulatorPort);
  }
}
