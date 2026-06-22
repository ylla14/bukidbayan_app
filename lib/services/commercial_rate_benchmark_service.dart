import 'package:bukidbayan_app/models/commercial_rate_benchmark.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CommercialRateBenchmarkService {
  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  CommercialRateBenchmarkService({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('commercial_rate_benchmarks');

  static const List<CommercialRateBenchmark> defaultBenchmarks = [
    CommercialRateBenchmark(
      id: 'tractor_per_day',
      categoryLabel: 'Tractor',
      equipmentLabel: 'Four-wheel Tractor',
      rentalUnit: 'Per Day',
      averageRate: 3500,
      minimumRate: 2800,
      maximumRate: 4500,
      scopeLabel: 'Provincial benchmark',
      notes: 'Seeded baseline for future savings comparison analytics.',
    ),
    CommercialRateBenchmark(
      id: 'hand_tractor_per_day',
      categoryLabel: 'Hand Tractor (Kuliglig)',
      equipmentLabel: 'Hand Tractor',
      rentalUnit: 'Per Day',
      averageRate: 1800,
      minimumRate: 1200,
      maximumRate: 2500,
      scopeLabel: 'Provincial benchmark',
      notes: 'Seeded baseline for future savings comparison analytics.',
    ),
    CommercialRateBenchmark(
      id: 'floating_tiller_per_day',
      categoryLabel: 'Floating Tiller (Pagong)',
      equipmentLabel: 'Floating Tiller',
      rentalUnit: 'Per Day',
      averageRate: 2200,
      minimumRate: 1600,
      maximumRate: 3000,
      scopeLabel: 'Provincial benchmark',
      notes: 'Seeded baseline for future savings comparison analytics.',
    ),
    CommercialRateBenchmark(
      id: 'harvester_per_day',
      categoryLabel: 'Harvester (Halimaw)',
      equipmentLabel: 'Combine Harvester',
      rentalUnit: 'Per Day',
      averageRate: 8500,
      minimumRate: 7000,
      maximumRate: 11000,
      scopeLabel: 'Provincial benchmark',
      notes: 'Seeded baseline for future savings comparison analytics.',
    ),
    CommercialRateBenchmark(
      id: 'rice_mill_per_kg',
      categoryLabel: 'Rice Mill',
      equipmentLabel: 'Rice Mill Service',
      rentalUnit: 'Per Kg',
      averageRate: 3.5,
      minimumRate: 2.5,
      maximumRate: 4.5,
      scopeLabel: 'Provincial benchmark',
      notes: 'Seeded baseline for future savings comparison analytics.',
    ),
  ];

  Future<void> seedDefaultBenchmarks() async {
    final existing = await _collection.get();
    final existingIds = existing.docs.map((doc) => doc.id).toSet();

    final batch = _firestore.batch();
    var wroteAny = false;

    for (final benchmark in defaultBenchmarks) {
      if (existingIds.contains(benchmark.id)) {
        continue;
      }

      batch.set(_collection.doc(benchmark.id), benchmark.toMap());
      wroteAny = true;
    }

    if (wroteAny) {
      await batch.commit();
    }
  }

  Future<List<CommercialRateBenchmark>> getBenchmarks() async {
    final snapshot = await _collection.get();
    final benchmarks = snapshot.docs
        .map(CommercialRateBenchmark.fromDoc)
        .toList();
    benchmarks.sort((a, b) => a.categoryLabel.compareTo(b.categoryLabel));
    return benchmarks;
  }
}
