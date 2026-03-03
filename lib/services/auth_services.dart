import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<User?> signUp(
    String email,
    String password,
    String firstName,
    String lastName,
  ) async {
    try {
      // Create user in Firebase Auth
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        // Store additional user data in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
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
        throw Exception('An account already exists for that email.');
      } else {
        throw Exception(e.message ?? 'An error occurred during sign up.');
      }
    } catch (e) {
      throw Exception('An error occurred: $e');
    }
  }

  // Login with email and password
  Future<User?> login(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('No user found for that email.');
      } else if (e.code == 'wrong-password') {
        throw Exception('Wrong password provided.');
      } else {
        throw Exception(e.message ?? 'An error occurred during login.');
      }
    } catch (e) {
      throw Exception('An error occurred: $e');
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      return doc.data() as Map<String, dynamic>?;
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

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'An error occurred while resetting password.');
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