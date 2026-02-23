import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  //  PHONE AUTH 

  /// Step 1 — Send OTP to the given phone number.
  /// [onCodeSent] receives the verificationId you must keep for step 2.
  /// [onError] receives a human-readable error message.
  Future<void> sendOtp({
    required String phoneNumber,             // e.g. "+63 912 345 6789"
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onError,
    void Function(PhoneAuthCredential)? onAutoVerified, // Android instant-verify
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),

      // Android: SMS auto-read succeeded — sign in immediately
      verificationCompleted: (PhoneAuthCredential credential) async {
        if (onAutoVerified != null) onAutoVerified(credential);
      },

      verificationFailed: (FirebaseAuthException e) {
        final msg = switch (e.code) {
          'invalid-phone-number' => 'Invalid phone number. Please include the country code (e.g. +63).',
          'too-many-requests'    => 'Too many attempts. Please try again later.',
          _                      => e.message ?? 'Failed to send OTP.',
        };
        onError(msg);
      },

      codeSent: (String verificationId, int? resendToken) {
        onCodeSent(verificationId);
      },

      codeAutoRetrievalTimeout: (_) {}, // no-op — OTP entry handles this
    );
  }

  /// Step 2 — Verify OTP and complete sign-up / login.
  /// For sign-up pass the extra profile fields; for login leave them null.
  Future<User?> verifyOtpAndSignUp({
    required String verificationId,
    required String smsCode,
    // Sign-up extras — null for plain login
    String? firstName,
    String? lastName,
    String? address,
    String? locationType,   // 'Home' | 'Farm' | 'Business' | 'Current Location'
    double? latitude,
    double? longitude,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) throw Exception('Authentication failed.');

      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

      if (isNewUser && firstName != null) {
        // Persist profile to Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'phoneNumber': user.phoneNumber,
          'firstName':   firstName,
          'lastName':    lastName ?? '',
          'address':     address ?? '',
          'locationType': locationType ?? 'Home',
          if (latitude  != null) 'latitude':  latitude,
          if (longitude != null) 'longitude': longitude,
          'createdAt': FieldValue.serverTimestamp(),
        });

        await user.updateDisplayName('$firstName ${lastName ?? ''}');
      }

      return user;
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'invalid-verification-code' => 'Invalid OTP. Please try again.',
        'session-expired'           => 'OTP expired. Please request a new one.',
        _                           => e.message ?? 'Verification failed.',
      };
      throw Exception(msg);
    } catch (e) {
      throw Exception('An error occurred: $e');
    }
  }

  //  PROFILE 

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Update user data in Firestore
  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      throw Exception('Error updating user data: $e');
    }
  }

  // Update location
  Future<void> updateLocation({
    required String uid,
    required String address,
    required String locationType,
    double? latitude,
    double? longitude,
  }) async {
    await updateUserData(uid, {
      'address':      address,
      'locationType': locationType,
      if (latitude  != null) 'latitude':  latitude,
      if (longitude != null) 'longitude': longitude,
    });
  }

  // SESSION 

  Future<void> logout() async => _auth.signOut();
}