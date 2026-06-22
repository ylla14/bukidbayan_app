import 'package:bukidbayan_app/services/platform_telemetry_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlatformTelemetryService', () {
    test('logs app events and heartbeat snapshots', () async {
      final firestore = FakeFirebaseFirestore();
      final service = PlatformTelemetryService(firestore: firestore);

      await service.logAppOpen(source: 'test_boot');
      await service.recordHeartbeat(source: 'test_boot');
      await service.logBackgroundTaskResult(
        taskName: 'seed_defaults',
        success: false,
        message: 'boom',
      );

      final events = await firestore.collection('app_events').get();
      expect(events.docs.length, 2);
      expect(
        events.docs.any((doc) => doc.data()['eventType'] == 'app_open'),
        isTrue,
      );
      expect(
        events.docs.any(
          (doc) =>
              doc.data()['eventType'] == 'background_task' &&
              doc.data()['status'] == 'failure',
        ),
        isTrue,
      );

      final current = await firestore
          .collection('system_health')
          .doc('current')
          .get();
      expect(current.exists, isTrue);
      expect(current.data()!['lastAppOpenSource'], 'test_boot');
      expect(current.data()!['lastHeartbeatSource'], 'test_boot');

      final heartbeats = await firestore
          .collection('system_health')
          .doc('current')
          .collection('heartbeats')
          .get();
      expect(heartbeats.docs.length, 1);
    });
  });
}
