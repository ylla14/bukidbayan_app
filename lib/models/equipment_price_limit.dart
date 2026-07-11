import 'package:cloud_firestore/cloud_firestore.dart';

class EquipmentPriceLimit {
  final String categoryLabel;
  final double minPrice;
  final double maxPrice;
  final DateTime? updatedAt;

  const EquipmentPriceLimit({
    required this.categoryLabel,
    required this.minPrice,
    required this.maxPrice,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'categoryLabel': categoryLabel,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory EquipmentPriceLimit.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    return EquipmentPriceLimit(
      categoryLabel: data['categoryLabel'] as String? ?? doc.id,
      minPrice: (data['minPrice'] as num?)?.toDouble() ?? 0,
      maxPrice: (data['maxPrice'] as num?)?.toDouble() ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
