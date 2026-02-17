import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String reviewId;
  final String requestId;
  final String itemId;
  final String reviewerId;
  final double rating;
  final String comment;
  final DateTime? createdAt;

  Review({
    required this.reviewId,
    required this.requestId,
    required this.itemId,
    required this.reviewerId,
    required this.rating,
    this.comment = '',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'itemId': itemId,
      'reviewerId': reviewerId,
      'rating': rating,
      'comment': comment,
    };
  }

  factory Review.fromDoc(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;

    return Review(
      reviewId: doc.id,
      requestId: map['requestId'] ?? '',
      itemId: map['itemId'] ?? '',
      reviewerId: map['reviewerId'] ?? '',
      rating: (map['rating'] ?? 0).toDouble(),
      comment: map['comment'] ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}
