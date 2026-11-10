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
  final String? clientPhotoUrl;
  final int? clientAge;
  final String? fitnessGoal;
  final String? packageName;
  final DateTime? packageStartDate;
  final DateTime? packageExpiryDate;
  final int? totalPackageDays;
  final int? sessionsCompleted;
  final int? totalSessions;
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
    this.clientPhotoUrl,
    this.clientAge,
    this.fitnessGoal,
    this.packageName,
    this.packageStartDate,
    this.packageExpiryDate,
    this.totalPackageDays,
    this.sessionsCompleted,
    this.totalSessions,
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

  /// ── Package & Schedule Resolved Metrics ──────────────────────────────────
  String get resolvedPackageName {
    if (packageName != null && packageName!.trim().isNotEmpty) return packageName!;
    final pid = (planId ?? '').toLowerCase();
    if (pid.contains('1_day')) return '1 Day Pass';
    if (pid.contains('3_day')) return '3 Days Starter';
    if (pid.contains('1_week')) return '1 Week Intensive';
    if (pid.contains('3_month')) return '3 Months Transformation';
    if (pid.contains('6_month')) return '6-Month Transformation';
    return 'Monthly Plan (30 Days)';
  }

  int get resolvedTotalDays {
    if (totalPackageDays != null && totalPackageDays! > 0) return totalPackageDays!;
    final pid = (planId ?? '').toLowerCase();
    if (pid.contains('1_day')) return 1;
    if (pid.contains('3_day')) return 3;
    if (pid.contains('1_week')) return 7;
    if (pid.contains('3_month')) return 90;
    if (pid.contains('6_month')) return 180;
    return 30;
  }

  DateTime get resolvedStartDate {
    if (packageStartDate != null) return packageStartDate!;
    if (createdAt != null) {
      return DateTime(createdAt!.year, createdAt!.month, createdAt!.day);
    }
    // Default reasonable start relative to session date
    final defaultOffset = (resolvedTotalDays * 0.4).round();
    return DateTime(sessionDate.year, sessionDate.month, sessionDate.day)
        .subtract(Duration(days: defaultOffset));
  }

  DateTime get resolvedExpiryDate {
    if (packageExpiryDate != null) return packageExpiryDate!;
    return resolvedStartDate.add(Duration(days: resolvedTotalDays));
  }

  int get resolvedDaysRemaining {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(resolvedExpiryDate.year, resolvedExpiryDate.month, resolvedExpiryDate.day);
    final diff = expiry.difference(today).inDays;
    return diff.clamp(0, resolvedTotalDays);
  }

  int get resolvedDaysCompleted {
    return (resolvedTotalDays - resolvedDaysRemaining).clamp(0, resolvedTotalDays);
  }

  /// Package remaining fraction: e.g. "15/30 Days Left", "7/90 Days Left", "3/30 Days Left"
  String get remainingDaysFraction => '$resolvedDaysRemaining/$resolvedTotalDays Days Left';

  /// Visual progress fraction (0.0 to 1.0) of remaining duration
  double get packageProgress {
    if (resolvedTotalDays <= 0) return 0.0;
    return (resolvedDaysRemaining / resolvedTotalDays).clamp(0.0, 1.0);
  }

  /// Package Health Category:
  /// - 'red': Expiring soon (<= 3 days)
  /// - 'orange': Nearing expiry (<= 10 days or <= 25% remaining)
  /// - 'green': Plenty of days remaining
  String get packageHealthStatus {
    if (resolvedDaysRemaining <= 3) {
      return 'red';
    } else if (resolvedDaysRemaining <= 10 || packageProgress <= 0.25) {
      return 'orange';
    } else {
      return 'green';
    }
  }

  int get resolvedAge => clientAge ?? 26;
  String get resolvedFitnessGoal => fitnessGoal ?? displayWorkoutType;

  int get resolvedTotalSessions {
    if (totalSessions != null && totalSessions! > 0) return totalSessions!;
    if (resolvedTotalDays == 30) return 26;
    if (resolvedTotalDays == 90) return 78;
    if (resolvedTotalDays == 180) return 150;
    if (resolvedTotalDays == 7) return 6;
    if (resolvedTotalDays == 3) return 3;
    return 1;
  }

  int get resolvedSessionsCompleted {
    if (sessionsCompleted != null && sessionsCompleted! >= 0) return sessionsCompleted!;
    final ratio = resolvedTotalDays > 0 ? (resolvedDaysCompleted / resolvedTotalDays) : 0.5;
    return (resolvedTotalSessions * ratio).round().clamp(0, resolvedTotalSessions);
  }

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
    String? clientPhotoUrl,
    int? clientAge,
    String? fitnessGoal,
    String? packageName,
    DateTime? packageStartDate,
    DateTime? packageExpiryDate,
    int? totalPackageDays,
    int? sessionsCompleted,
    int? totalSessions,
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
      clientPhotoUrl: clientPhotoUrl ?? this.clientPhotoUrl,
      clientAge: clientAge ?? this.clientAge,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      packageName: packageName ?? this.packageName,
      packageStartDate: packageStartDate ?? this.packageStartDate,
      packageExpiryDate: packageExpiryDate ?? this.packageExpiryDate,
      totalPackageDays: totalPackageDays ?? this.totalPackageDays,
      sessionsCompleted: sessionsCompleted ?? this.sessionsCompleted,
      totalSessions: totalSessions ?? this.totalSessions,
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
      'clientPhotoUrl': clientPhotoUrl,
      'clientAge': clientAge,
      'fitnessGoal': fitnessGoal,
      'packageName': packageName,
      'packageStartDate': packageStartDate != null ? Timestamp.fromDate(packageStartDate!) : null,
      'packageExpiryDate': packageExpiryDate != null ? Timestamp.fromDate(packageExpiryDate!) : null,
      'totalPackageDays': totalPackageDays,
      'sessionsCompleted': sessionsCompleted,
      'totalSessions': totalSessions,
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
      clientPhotoUrl: map['clientPhotoUrl'] as String?,
      clientAge: (map['clientAge'] as num?)?.toInt(),
      fitnessGoal: map['fitnessGoal'] as String?,
      packageName: map['packageName'] as String?,
      packageStartDate: parseTimestamp(map['packageStartDate']),
      packageExpiryDate: parseTimestamp(map['packageExpiryDate']),
      totalPackageDays: (map['totalPackageDays'] as num?)?.toInt(),
      sessionsCompleted: (map['sessionsCompleted'] as num?)?.toInt(),
      totalSessions: (map['totalSessions'] as num?)?.toInt(),
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

