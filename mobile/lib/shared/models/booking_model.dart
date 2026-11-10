import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

enum BookingStatus {
  pending,
  confirmed,
  completed,
  cancelledClientEarly, // >= 12h, credit returned
  cancelledClientLate,  // < 12h, credit forfeited
  cancelledTrainer,     // credit returned
  cancelledAdmin,       // credit returned
  rejected;             // Trainer rejected request

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
      case BookingStatus.rejected:
        return 'REJECTED';
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
  final String? clientName;
  final String? clientPhone;
  final String? trainerName;
  final String? trainerPhotoUrl;
  final String? workoutType;
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
    this.clientName,
    this.clientPhone,
    this.trainerName,
    this.trainerPhotoUrl,
    this.workoutType,
    this.creditTransactionId,
    this.meetingLocation,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  /// Convenient display getters
  String get displayClientName =>
      (clientName != null && clientName!.trim().isNotEmpty) ? clientName! : 'Athlete #$id';
  String get displayTrainerName =>
      (trainerName != null && trainerName!.trim().isNotEmpty) ? trainerName! : 'Coach #$trainerId';
  String get displayWorkoutType =>
      (workoutType != null && workoutType!.trim().isNotEmpty) ? workoutType! : (planId ?? 'Personal Training');

  BookingModel copyWith({
    String? id,
    String? clientId,
    String? trainerId,
    Gender? clientGender,
    Gender? trainerGender,
    String? planId,
    DateTime? sessionDate,
    String? startTime,
    String? endTime,
    BookingStatus? status,
    String? clientName,
    String? clientPhone,
    String? trainerName,
    String? trainerPhotoUrl,
    String? workoutType,
    String? creditTransactionId,
    String? meetingLocation,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BookingModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      trainerId: trainerId ?? this.trainerId,
      clientGender: clientGender ?? this.clientGender,
      trainerGender: trainerGender ?? this.trainerGender,
      planId: planId ?? this.planId,
      sessionDate: sessionDate ?? this.sessionDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      trainerName: trainerName ?? this.trainerName,
      trainerPhotoUrl: trainerPhotoUrl ?? this.trainerPhotoUrl,
      workoutType: workoutType ?? this.workoutType,
      creditTransactionId: creditTransactionId ?? this.creditTransactionId,
      meetingLocation: meetingLocation ?? this.meetingLocation,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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
      'clientName': clientName,
      'clientPhone': clientPhone,
      'trainerName': trainerName,
      'trainerPhotoUrl': trainerPhotoUrl,
      'workoutType': workoutType,
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
      clientName: map['clientName'] as String?,
      clientPhone: map['clientPhone'] as String?,
      trainerName: map['trainerName'] as String?,
      trainerPhotoUrl: map['trainerPhotoUrl'] as String?,
      workoutType: map['workoutType'] as String?,
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

