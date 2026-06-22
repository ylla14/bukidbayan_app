import 'package:cloud_firestore/cloud_firestore.dart';

class CommercialRateBenchmark {
  final String id;
  final String categoryLabel;
  final String equipmentLabel;
  final String rentalUnit;
  final double averageRate;
  final double minimumRate;
  final double maximumRate;
  final String scopeLabel;
  final String notes;
  final DateTime? updatedAt;

  const CommercialRateBenchmark({
    required this.id,
    required this.categoryLabel,
    required this.equipmentLabel,
    required this.rentalUnit,
    required this.averageRate,
    required this.minimumRate,
    required this.maximumRate,
    required this.scopeLabel,
    required this.notes,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'categoryLabel': categoryLabel,
      'equipmentLabel': equipmentLabel,
      'rentalUnit': rentalUnit,
      'averageRate': averageRate,
      'minimumRate': minimumRate,
      'maximumRate': maximumRate,
      'scopeLabel': scopeLabel,
      'notes': notes,
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  factory CommercialRateBenchmark.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
    return CommercialRateBenchmark(
      id: doc.id,
      categoryLabel: data['categoryLabel'] as String? ?? '',
      equipmentLabel: data['equipmentLabel'] as String? ?? '',
      rentalUnit: data['rentalUnit'] as String? ?? '',
      averageRate: (data['averageRate'] as num?)?.toDouble() ?? 0,
      minimumRate: (data['minimumRate'] as num?)?.toDouble() ?? 0,
      maximumRate: (data['maximumRate'] as num?)?.toDouble() ?? 0,
      scopeLabel: data['scopeLabel'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
