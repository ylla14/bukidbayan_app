import 'package:bukidbayan_app/services/commercial_rate_benchmark_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommercialRateBenchmarkService', () {
    test('seeds default benchmarks once and stays idempotent', () async {
      final firestore = FakeFirebaseFirestore();
      final service = CommercialRateBenchmarkService(firestore: firestore);

      await service.seedDefaultBenchmarks();
      await service.seedDefaultBenchmarks();

      final snapshot = await firestore
          .collection('commercial_rate_benchmarks')
          .get();

      expect(
        snapshot.docs.length,
        CommercialRateBenchmarkService.defaultBenchmarks.length,
      );
      expect(snapshot.docs.any((doc) => doc.id == 'tractor_per_day'), isTrue);
      expect(snapshot.docs.any((doc) => doc.id == 'rice_mill_per_kg'), isTrue);
    });
  });
}
