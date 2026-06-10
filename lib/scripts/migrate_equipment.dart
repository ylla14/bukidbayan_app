import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> migrateDamageReportCount() async {
  final snapshot =
      await FirebaseFirestore.instance.collection('equipment').get();

  for (var doc in snapshot.docs) {
    await doc.reference.update({
      'damageReportCount': doc.data()['damageReportCount'] ?? 0,
    });
  }
}