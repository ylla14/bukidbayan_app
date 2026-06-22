import 'package:bukidbayan_app/models/rent_request.dart';
import 'package:bukidbayan_app/services/rent_request_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RentRequestService', () {
    test(
      'creates lifecycle history and geography fields on request save',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = RentRequestService(firestore: firestore);

        final request = RentRequest(
          requestId: '',
          itemId: 'eq-1',
          itemName: 'Four-wheel Tractor',
          name: 'Farmer One',
          address:
              'Purok 4, Barangay San Jose, Tanauan City, Batangas, CALABARZON',
          start: DateTime(2026, 6, 25),
          end: DateTime(2026, 6, 27),
          renterId: 'renter-1',
          ownerId: 'owner-1',
          farmAddress: 'Sitio Uno, Barangay Sampaga, Los Banos, Laguna',
          cropType: 'Rice',
          farmingPhase: 'Land preparation',
          intendedUse: 'Plowing',
        );

        final requestId = await service.saveRequest(request);
        final saved = await firestore
            .collection('rentRequests')
            .doc(requestId)
            .get();

        expect(saved.exists, isTrue);
        expect(saved.data()!['barangay'], 'Barangay San Jose');
        expect(saved.data()!['municipality'], 'Tanauan City');
        expect(saved.data()!['province'], 'Batangas');
        expect(saved.data()!['region'], 'CALABARZON');
        expect(saved.data()!['farmBarangay'], 'Barangay Sampaga');
        expect(saved.data()!['cropType'], 'Rice');

        final history = await saved.reference
            .collection('status_history')
            .get();
        expect(history.docs.length, 1);
        expect(history.docs.first.data()['toStatus'], 'pending');

        final timeline = await saved.reference
            .collection('timeline_events')
            .get();
        expect(timeline.docs.length, 1);
        expect(timeline.docs.first.data()['eventType'], 'request_created');
      },
    );

    test('records status changes in immutable history', () async {
      final firestore = FakeFirebaseFirestore();
      final service = RentRequestService(firestore: firestore);

      final requestId = await service.saveRequest(
        RentRequest(
          requestId: '',
          itemId: 'eq-2',
          itemName: 'Power Tiller',
          name: 'Farmer Two',
          address: 'Barangay Mabini, Sto Tomas, Batangas',
          start: DateTime(2026, 7, 1),
          end: DateTime(2026, 7, 2),
          renterId: 'renter-2',
          ownerId: 'owner-2',
        ),
      );

      await service.updateRequestStatus(
        requestId: requestId,
        status: RentRequestStatus.approved,
        actorId: 'owner-2',
        actorRole: 'owner',
      );

      final history = await firestore
          .collection('rentRequests')
          .doc(requestId)
          .collection('status_history')
          .get();
      final timeline = await firestore
          .collection('rentRequests')
          .doc(requestId)
          .collection('timeline_events')
          .get();

      expect(history.docs.length, 2);
      expect(
        history.docs.any(
          (doc) =>
              doc.data()['fromStatus'] == 'pending' &&
              doc.data()['toStatus'] == 'approved',
        ),
        isTrue,
      );
      expect(
        timeline.docs.any((doc) => doc.data()['eventType'] == 'status_changed'),
        isTrue,
      );
    });
  });
}
