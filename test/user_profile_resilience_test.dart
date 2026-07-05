import 'package:bukidbayan_app/services/auth_services.dart';
import 'package:bukidbayan_app/services/firestore_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('user profile resilience', () {
    test('saveCropPreferences creates a missing user document', () async {
      final firestore = FakeFirebaseFirestore();
      final service = FirestoreService(firestore: firestore);

      await service.saveCropPreferences('user-1', const ['Rice', 'Corn']);

      final doc = await firestore.collection('users').doc('user-1').get();

      expect(doc.exists, isTrue);
      expect(doc.data()?['cropPreferences'], const ['Rice', 'Corn']);
    });

    test(
      'ensureUserDocument creates a minimal profile for email users',
      () async {
        final firestore = FakeFirebaseFirestore();
        final auth = MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(
            uid: 'user-2',
            email: 'a@gmail.com',
            displayName: 'Alice Farmer',
          ),
        );
        final service = AuthService(auth: auth, firestore: firestore);

        final data = await service.ensureUserDocument(auth.currentUser!);
        final doc = await firestore.collection('users').doc('user-2').get();

        expect(doc.exists, isTrue);
        expect(data['email'], 'a@gmail.com');
        expect(data['firstName'], 'Alice');
        expect(data['lastName'], 'Farmer');
        expect(data['isPhoneUser'], isFalse);
      },
    );

    test('registerPhone merges into a missing user document', () async {
      final firestore = FakeFirebaseFirestore();
      final service = AuthService(
        auth: MockFirebaseAuth(),
        firestore: firestore,
      );

      await service.registerPhone('user-3', '09171234567');

      final doc = await firestore.collection('users').doc('user-3').get();

      expect(doc.exists, isTrue);
      expect(doc.data()?['phoneNumber'], '09171234567');
    });
  });
}
