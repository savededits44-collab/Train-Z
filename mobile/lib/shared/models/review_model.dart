import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String id;
  final String bookingId;
  final String clientId;
  final String trainerId;
  final double rating; // 1.0 - 5.0
  final String comment;
  final bool isPublic;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ReviewModel({
    required this.id,
    required this.bookingId,
    required this.clientId,
    required this.trainerId,
    required this.rating,
    required this.comment,
    this.isPublic = true,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookingId': bookingId,
      'clientId': clientId,
      'trainerId': trainerId,
      'rating': rating,
      'comment': comment,
      'isPublic': isPublic,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory ReviewModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return ReviewModel(
      id: id,
      bookingId: map['bookingId'] as String? ?? '',
      clientId: map['clientId'] as String? ?? '',
      trainerId: map['trainerId'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      comment: map['comment'] as String? ?? '',
      isPublic: map['isPublic'] as bool? ?? true,
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
    );
  }

  factory ReviewModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ReviewModel.fromMap(data, id: doc.id);
  }
}

