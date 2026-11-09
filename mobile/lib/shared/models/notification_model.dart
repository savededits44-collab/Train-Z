import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type; // e.g. 'BOOKING_CONFIRMED', 'CREDIT_ADDED', 'TRAINER_APPROVED'
  final bool isRead;
  final Map<String, dynamic> data;
  final DateTime? createdAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    this.data = const {},
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'isRead': isRead,
      'data': data,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return NotificationModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      type: map['type'] as String? ?? 'GENERAL',
      isRead: map['isRead'] as bool? ?? false,
      data: map['data'] as Map<String, dynamic>? ?? {},
      createdAt: parseTimestamp(map['createdAt']),
    );
  }

  factory NotificationModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return NotificationModel.fromMap(data, id: doc.id);
  }
}

