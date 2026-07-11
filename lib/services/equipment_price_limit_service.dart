import 'package:bukidbayan_app/models/equipment_price_limit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EquipmentPriceLimitService {
  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  EquipmentPriceLimitService({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('equipment_price_limits');

  /// All admin-configured price limits, keyed by category label.
  /// Categories without an admin override simply won't have an entry here.
  Future<Map<String, EquipmentPriceLimit>> getAll() async {
    final snapshot = await _collection.get();
    return {
      for (final doc in snapshot.docs)
        doc.id: EquipmentPriceLimit.fromDoc(doc),
    };
  }

  Future<void> setLimit({
    required String categoryLabel,
    required double minPrice,
    required double maxPrice,
  }) async {
    await _collection.doc(categoryLabel).set({
      'categoryLabel': categoryLabel,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
