import 'package:cloud_firestore/cloud_firestore.dart';

class RenterReport {
  final String reportId;
  final String requestId;
  final String renterId;
  final String ownerId;
  final String reason;
  final String details;
  final List<String> evidenceUrls;
  final DateTime createdAt;

  RenterReport({
    required this.reportId,
    required this.requestId,
    required this.renterId,
    required this.ownerId,
    required this.reason,
    required this.details,
    this.evidenceUrls = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'renterId': renterId,
      'ownerId': ownerId,
      'reason': reason,
      'details': details,
      'evidenceUrls': evidenceUrls,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory RenterReport.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return RenterReport(
      reportId: doc.id,
      requestId: map['requestId'] as String,
      renterId: map['renterId'] as String,
      ownerId: map['ownerId'] as String,
      reason: map['reason'] as String,
      details: map['details'] as String,
      evidenceUrls: List<String>.from(map['evidenceUrls'] as List? ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
