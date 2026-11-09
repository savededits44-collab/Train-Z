import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

enum BookingStatus {
  pending,
  confirmed,
  completed,
  cancelledClientEarly, // >= 12h, credit returned
  cancelledClientLate,  // < 12h, credit forfeited
  cancelledTrainer,     // credit returned
  cancelledAdmin;       // credit returned

  String toFirestore() {
    switch (this) {
      case BookingStatus.pending:
        return 'PENDING';
      case BookingStatus.confirmed:
        return 'CONFIRMED';
      case BookingStatus.completed:
        return 'COMPLETED';
      case BookingStatus.cancelledClientEarly:
        return 'CANCELLED_CLIENT_EARLY';
      case BookingStatus.cancelledClientLate:
        return 'CANCELLED_CLIENT_LATE';
      case BookingStatus.cancelledTrainer:
        return 'CANCELLED_TRAINER';
      case BookingStatus.cancelledAdmin:
        return 'CANCELLED_ADMIN';
    }
  }

  static BookingStatus fromFirestore(dynamic val) {
    if (val == null) return BookingStatus.pending;
    final str = val.toString().trim().toUpperCase();
    for (final s in BookingStatus.values) {
      if (s.toFirestore() == str) return s;
    }
    return BookingStatus.pending;
  }
}

class BookingModel {
  final String id;
  final String clientId;
  final String trainerId;
  final Gender clientGender;
  final Gender trainerGender;
  final String? planId;
  final DateTime sessionDate;
  final String startTime; // e.g. "07:00"
  final String endTime;   // e.g. "08:00"
  final BookingStatus status;
  final String? creditTransactionId;
  final String? meetingLocation;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BookingModel({
    required this.id,
    required this.clientId,
    required this.trainerId,
    required this.clientGender,
    required this.trainerGender,
    this.planId,
    required this.sessionDate,
    required this.startTime,
    required this.endTime,
    this.status = BookingStatus.confirmed,
    this.creditTransactionId,
    this.meetingLocation,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  /// Business Rule Section 5: Male -> Male only, Female -> Female only
  bool get hasValidGenderMatch => clientGender == trainerGender;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'trainerId': trainerId,
      'clientGender': clientGender.toFirestore(),
      'trainerGender': trainerGender.toFirestore(),
      'planId': planId,
      'sessionDate': Timestamp.fromDate(sessionDate),
      'startTime': startTime,
      'endTime': endTime,
      'status': status.toFirestore(),
      'creditTransactionId': creditTransactionId,
      'meetingLocation': meetingLocation,
      'notes': notes,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory BookingModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return BookingModel(
      id: id,
      clientId: map['clientId'] as String? ?? '',
      trainerId: map['trainerId'] as String? ?? '',
      clientGender: Gender.fromFirestore(map['clientGender']) ?? Gender.male,
      trainerGender: Gender.fromFirestore(map['trainerGender']) ?? Gender.male,
      planId: map['planId'] as String?,
      sessionDate: parseTimestamp(map['sessionDate']) ?? DateTime.now(),
      startTime: map['startTime'] as String? ?? '06:00',
      endTime: map['endTime'] as String? ?? '07:00',
      status: BookingStatus.fromFirestore(map['status']),
      creditTransactionId: map['creditTransactionId'] as String?,
      meetingLocation: map['meetingLocation'] as String?,
      notes: map['notes'] as String?,
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
    );
  }

  factory BookingModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BookingModel.fromMap(data, id: doc.id);
  }
}

