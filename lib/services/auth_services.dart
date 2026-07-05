import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  static const String _shadowEmailDomain = '@phone.bukidbayan.app';

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Identifier validation & helpers ──────────────────────────────────────

  /// Returns true if [input] is a valid login identifier:
  ///   • exactly 11 digits (phone, e.g. 09123456789), OR
  ///   • a valid email (alphanumeric @ letters-only-domain . 2+ char TLD)
  static bool isValidIdentifier(String input) {
    final trimmed = input.trim();
    if (RegExp(r'^\d{11}$').hasMatch(trimmed)) return true;
    if (RegExp(
      r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z]+\.[a-zA-Z]{2,}$',
    ).hasMatch(trimmed)) {
      return true;
    }
    return false;
  }

  bool _isPhoneNumber(String input) =>
      RegExp(r'^\d{11}$').hasMatch(input.trim());

  String _toShadowEmail(String phone) => '${phone.trim()}$_shadowEmailDomain';

  // Validate an address string via Nominatim (OpenStreetMap).
  // Returns {'latitude': ..., 'longitude': ...} on success.
  // Throws Exception if the address cannot be resolved.
  Future<Map<String, double>> validateAndGeocodeAddress(String address) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?format=json'
        '&q=${Uri.encodeQueryComponent(address)}'
        '&limit=1',
      );
      final response = await http.get(
        uri,
        headers: {'Accept-Language': 'en', 'User-Agent': 'BukidbayanApp/1.0'},
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Could not validate address. Check your connection and try again.',
        );
      }

      final List<dynamic> results = jsonDecode(response.body);
      if (results.isEmpty) {
        throw Exception(
          'Address not found. Please enter a more specific address.',
        );
      }

      final first = results.first as Map<String, dynamic>;
      return {
        'latitude': double.parse(first['lat'] as String),
        'longitude': double.parse(first['lon'] as String),
      };
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception(
        'Could not validate address. Check your connection and try again.',
      );
    }
  }

  // Sign up with a phone number (new users only).
  // The phone number is converted to a shadow email internally for Firebase Auth.
  // Optionally accepts farm location fields (address, lat, lng, polygon ID from Agromonitoring).
  Future<User?> signUp(
    String phoneNumber,
    String password,
    String firstName,
    String lastName,
    String address,
    double latitude,
    double longitude, {
    String? farmAddress,
    double? farmLatitude,
    double? farmLongitude,
    String? farmPolygonId,
  }) async {
    final shadowEmail = _toShadowEmail(phoneNumber);
    try {
      // Create user in Firebase Auth using the shadow email
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: shadowEmail,
            password: password,
          );

      User? user = userCredential.user;

      if (user != null) {
        // Store additional user data in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'email': shadowEmail,
          'phoneNumber': phoneNumber.trim(),
          'isPhoneUser': true,
          'firstName': firstName,
          'lastName': lastName,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
          'locationType': 'Home',
          if (farmAddress != null) 'farmAddress': farmAddress,
          if (farmLatitude != null) 'farmLatitude': farmLatitude,
          if (farmLongitude != null) 'farmLongitude': farmLongitude,
          if (farmPolygonId != null) 'farmPolygonId': farmPolygonId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Update display name
        await user.updateDisplayName('$firstName $lastName');
      }

      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw Exception('The password provided is too weak.');
      } else if (e.code == 'email-already-in-use') {
        throw Exception('That phone number is already registered.');
      } else {
        throw Exception(e.message ?? 'An error occurred during sign up.');
      }
    } catch (e) {
      throw Exception('An error occurred: $e');
    }
  }

  // Login with either an email address or an 11-digit phone number.
  // If a phone number is provided, Firestore is queried first to resolve
  // the associated email (real or shadow) before authenticating.
  Future<User?> login(String identifier, String password) async {
    String emailToUse = identifier.trim();

    if (_isPhoneNumber(identifier)) {
      final query = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: identifier.trim())
          .limit(1)
          .get();
      if (query.docs.isEmpty) {
        throw Exception('No account found for that phone number.');
      }
      emailToUse = query.docs.first['email'] as String;
    }

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: emailToUse,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('No user found for that email.');
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Wrong password provided.');
      } else {
        throw Exception(e.message ?? 'An error occurred during login.');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('An error occurred: $e');
    }
  }

  // Register a phone number for an existing email-based user.
  // Validates uniqueness before saving.
  Future<void> registerPhone(String uid, String phoneNumber) async {
    final phone = phoneNumber.trim();
    final existing = await _firestore
        .collection('users')
        .where('phoneNumber', isEqualTo: phone)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty && existing.docs.first.id != uid) {
      throw Exception(
        'That phone number is already registered to another account.',
      );
    }
    await _firestore.collection('users').doc(uid).set({
      'phoneNumber': phone,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Co-op account constants
  static const String coopPhone = '09876543210';
  static const String coopPassword = 'IAmACoop.';

  /// Seeds the singular co-op account into Firebase Auth + Firestore if it
  /// doesn't already exist. Safe to call on every app startup.
  Future<void> seedCoopAccount() async {
    final coopEmail = _toShadowEmail(coopPhone);

    // Check by phone number only (avoids needing a composite Firestore index)
    try {
      final query = await _firestore
          .collection('users')
          .where('phoneNumber', isEqualTo: coopPhone)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) return; // Already seeded
    } catch (e) {
      debugPrint('[seedCoopAccount] Firestore check failed: $e');
      return;
    }

    // Create or recover the Firebase Auth account
    UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: coopEmail,
        password: coopPassword,
      );
      debugPrint('[seedCoopAccount] Auth account created.');
    } on FirebaseAuthException catch (e) {
      if (e.code != 'email-already-in-use') {
        debugPrint('[seedCoopAccount] Auth creation failed: ${e.code}');
        return;
      }
      // Auth account exists but Firestore doc is missing — sign in to get UID
      try {
        cred = await _auth.signInWithEmailAndPassword(
          email: coopEmail,
          password: coopPassword,
        );
        debugPrint('[seedCoopAccount] Recovered existing Auth account.');
      } catch (e2) {
        debugPrint(
          '[seedCoopAccount] Could not sign in to recover account: $e2',
        );
        return;
      }
    }

    try {
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'phoneNumber': coopPhone,
        'email': coopEmail,
        'firstName': 'BukidBayan',
        'lastName': 'Co-op',
        'accountType': 'coop',
        'isPhoneUser': true,
      }, SetOptions(merge: true));
      debugPrint(
        '[seedCoopAccount] Firestore doc written for uid=${cred.user!.uid}',
      );
    } catch (e) {
      debugPrint('[seedCoopAccount] Firestore write failed: $e');
    } finally {
      await _auth.signOut();
    }
  }

  /// Returns true if the given uid belongs to the co-op account.
  Future<bool> isCoopAccount(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data()?['accountType'] == 'coop';
    } catch (_) {
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> ensureUserDocument(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final existing = await docRef.get();
    final existingData = existing.data();
    if (existingData != null) return existingData;

    final displayNameParts = (user.displayName ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    final firstName = displayNameParts.isNotEmpty ? displayNameParts.first : '';
    final lastName = displayNameParts.length > 1
        ? displayNameParts.sublist(1).join(' ')
        : '';
    final email = user.email?.trim();

    final profileData = <String, dynamic>{
      if (email != null && email.isNotEmpty) 'email': email,
      if (firstName.isNotEmpty) 'firstName': firstName,
      if (lastName.isNotEmpty) 'lastName': lastName,
      'isPhoneUser': email?.endsWith(_shadowEmailDomain) ?? false,
    };

    await docRef.set({
      ...profileData,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return profileData;
  }

  // Update user data in Firestore
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Error updating user data: $e');
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(
        e.message ?? 'An error occurred while resetting password.',
      );
    }
  }
}

// //import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// class AuthService {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   // Get current user
//   User? get currentUser => _auth.currentUser;

//   // Auth state changes stream
//   Stream<User?> get authStateChanges => _auth.authStateChanges();

//   //  PHONE AUTH

//   /// Step 1 — Send OTP to the given phone number.
//   /// [onCodeSent] receives the verificationId you must keep for step 2.
//   /// [onError] receives a human-readable error message.
//   Future<void> sendOtp({
//     required String phoneNumber,             // e.g. "+63 912 345 6789"
//     required void Function(String verificationId) onCodeSent,
//     required void Function(String error) onError,
//     void Function(PhoneAuthCredential)? onAutoVerified, // Android instant-verify
//   }) async {
//     await _auth.verifyPhoneNumber(
//       phoneNumber: phoneNumber,
//       timeout: const Duration(seconds: 60),

//       // Android: SMS auto-read succeeded — sign in immediately
//       verificationCompleted: (PhoneAuthCredential credential) async {
//         if (onAutoVerified != null) onAutoVerified(credential);
//       },

//       verificationFailed: (FirebaseAuthException e) {
//         final msg = switch (e.code) {
//           'invalid-phone-number' => 'Invalid phone number. Please include the country code (e.g. +63).',
//           'too-many-requests'    => 'Too many attempts. Please try again later.',
//           _                      => e.message ?? 'Failed to send OTP.',
//         };
//         onError(msg);
//       },

//       codeSent: (String verificationId, int? resendToken) {
//         onCodeSent(verificationId);
//       },

//       codeAutoRetrievalTimeout: (_) {}, // no-op — OTP entry handles this
//     );
//   }

//   /// Step 2 — Verify OTP and complete sign-up / login.
//   /// For sign-up pass the extra profile fields; for login leave them null.
//   Future<User?> verifyOtpAndSignUp({
//     required String verificationId,
//     required String smsCode,
//     // Sign-up extras — null for plain login
//     String? firstName,
//     String? lastName,
//     String? address,
//     String? locationType,   // 'Home' | 'Farm' | 'Business' | 'Current Location'
//     double? latitude,
//     double? longitude,
//   }) async {
//     try {
//       final credential = PhoneAuthProvider.credential(
//         verificationId: verificationId,
//         smsCode: smsCode,
//       );

//       final userCredential = await _auth.signInWithCredential(credential);
//       final user = userCredential.user;

//       if (user == null) throw Exception('Authentication failed.');

//       final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

//       if (isNewUser && firstName != null) {
//         // Persist profile to Firestore
//         await _firestore.collection('users').doc(user.uid).set({
//           'phoneNumber': user.phoneNumber,
//           'firstName':   firstName,
//           'lastName':    lastName ?? '',
//           'address':     address ?? '',
//           'locationType': locationType ?? 'Home',
//           if (latitude  != null) 'latitude':  latitude,
//           if (longitude != null) 'longitude': longitude,
//           'createdAt': FieldValue.serverTimestamp(),
//         });

//         await user.updateDisplayName('$firstName ${lastName ?? ''}');
//       }

//       return user;
//     } on FirebaseAuthException catch (e) {
//       final msg = switch (e.code) {
//         'invalid-verification-code' => 'Invalid OTP. Please try again.',
//         'session-expired'           => 'OTP expired. Please request a new one.',
//         _                           => e.message ?? 'Verification failed.',
//       };
//       throw Exception(msg);
//     } catch (e) {
//       throw Exception('An error occurred: $e');
//     }
//   }

//   //  PROFILE

//   // Get user data from Firestore
//   Future<Map<String, dynamic>?> getUserData(String uid) async {
//     try {
//       final doc = await _firestore.collection('users').doc(uid).get();
//       return doc.data();
//     } catch (e) {
//       print('Error getting user data: $e');
//       return null;
//     }
//   }

//   // Update user data in Firestore
//   Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
//     try {
//       await _firestore.collection('users').doc(uid).update(data);
//     } catch (e) {
//       throw Exception('Error updating user data: $e');
//     }
//   }

//   // Update location
//   Future<void> updateLocation({
//     required String uid,
//     required String address,
//     required String locationType,
//     double? latitude,
//     double? longitude,
//   }) async {
//     await updateUserData(uid, {
//       'address':      address,
//       'locationType': locationType,
//       if (latitude  != null) 'latitude':  latitude,
//       if (longitude != null) 'longitude': longitude,
//     });
//   }

//   // SESSION

//   Future<void> logout() async => _auth.signOut();
// }
