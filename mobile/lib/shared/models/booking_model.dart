import 'package:cloud_firestore/cloud_firestore.dart';
import 'payment_model.dart';
import 'user_model.dart';

export 'payment_model.dart' show PaymentStatus;

enum BookingStatus {
  pending,
  reserved,             // Temporary slot reservation (hold) during checkout
  confirmed,
  completed,
  cancelled,            // Generic / client or trainer cancelled
  cancelledClientEarly, // >= 12h, credit returned
  cancelledClientLate,  // < 12h, credit forfeited
  cancelledTrainer,     // credit returned
  cancelledAdmin,       // credit returned
  rejected,             // Trainer rejected request
  rescheduled,          // Trainer or client rescheduled session
  expired;              // Temporary slot reservation expired

  String toFirestore() {
    switch (this) {
      case BookingStatus.pending:
        return 'PENDING';
      case BookingStatus.reserved:
        return 'RESERVED';
      case BookingStatus.confirmed:
        return 'CONFIRMED';
      case BookingStatus.completed:
        return 'COMPLETED';
      case BookingStatus.cancelled:
        return 'CANCELLED';
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
      case BookingStatus.rescheduled:
        return 'RESCHEDULED';
      case BookingStatus.expired:
        return 'EXPIRED';
    }
  }

  static BookingStatus fromFirestore(dynamic val) {
    if (val == null) return BookingStatus.pending;
    final str = val.toString().trim().toUpperCase();
    if (str == 'RESCHEDULED') return BookingStatus.rescheduled;
    if (str == 'CANCELLED') return BookingStatus.cancelled;
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
  final String? packageId;
  final int? packagePrice;
  final int? sessionsCount;
  final int? validityDays;
  final DateTime sessionDate;
  final String startTime; // e.g. "07:00"
  final String endTime;   // e.g. "08:00"
  final BookingStatus status;
  final PaymentStatus paymentStatus;
  final String? creditTransactionId;
  final String? paymentTransactionId;
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
  final String? locationReference;
  final String? notes;
  final bool _isRescheduled;
  final DateTime? rescheduledAt;
  final DateTime? previousSessionDate;
  final String? previousStartTime;
  final String? previousEndTime;
  final DateTime? reservedAt;
  final DateTime? expiresAt;
  final DateTime? confirmedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BookingModel({
    required this.id,
    required this.clientId,
    required this.trainerId,
    required this.clientGender,
    required this.trainerGender,
    this.planId,
    this.packageId,
    this.packagePrice,
    this.sessionsCount,
    this.validityDays,
    required this.sessionDate,
    required this.startTime,
    required this.endTime,
    this.status = BookingStatus.confirmed,
    this.paymentStatus = PaymentStatus.pending,
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
    this.paymentTransactionId,
    this.meetingLocation,
    this.locationReference,
    this.notes,
    this._isRescheduled = false,
    this.rescheduledAt,
    this.previousSessionDate,
    this.previousStartTime,
    this.previousEndTime,
    this.reservedAt,
    this.expiresAt,
    this.confirmedAt,
    this.createdAt,
    this.updatedAt,
  });

  /// Convenient display getters
  String get displayClientName =>
      (clientName != null && clientName!.trim().isNotEmpty) ? clientName! : 'Athlete #$id';
  String get displayTrainerName =>
      (trainerName != null && trainerName!.trim().isNotEmpty) ? trainerName! : 'Coach #$trainerId';
  String get displayWorkoutType =>
      (workoutType != null && workoutType!.trim().isNotEmpty)
          ? workoutType!
          : (planId ?? packageId ?? 'Personal Training');

  /// Safe package ID getter
  String get resolvedPackageId => packageId ?? planId ?? 'plan_1_month';

  /// Temporary reservation check
  bool get isTemporaryReservation =>
      status == BookingStatus.reserved && paymentStatus == PaymentStatus.pending;

  /// Reservation expiry check
  bool get isReservationExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now()) && status == BookingStatus.reserved;

  /// Verified confirmed check
  bool get isConfirmed =>
      status == BookingStatus.confirmed && paymentStatus == PaymentStatus.completed;

  /// Rescheduled check
  bool get isRescheduled => _isRescheduled || status == BookingStatus.rescheduled;

  /// Status classification getters for client bookings section
  bool get isUpcoming =>
      status == BookingStatus.confirmed &&
      sessionDate.isAfter(DateTime.now().subtract(const Duration(hours: 1)));

  bool get isPending =>
      status == BookingStatus.pending || status == BookingStatus.reserved;

  bool get isCompleted => status == BookingStatus.completed;

  /// Cancelled check (any client, trainer, or admin cancellation)
  bool get isCancelled =>
      status == BookingStatus.cancelled ||
      status == BookingStatus.cancelledClientEarly ||
      status == BookingStatus.cancelledClientLate ||
      status == BookingStatus.cancelledTrainer ||
      status == BookingStatus.cancelledAdmin ||
      status == BookingStatus.expired ||
      status == BookingStatus.rejected;

  /// Whether credit was returned upon cancellation
  bool get isCreditReturned =>
      status == BookingStatus.cancelledClientEarly ||
      status == BookingStatus.cancelledTrainer ||
      status == BookingStatus.cancelledAdmin;

  /// Whether credit was forfeited upon cancellation (<12h)
  bool get isCreditForfeited => status == BookingStatus.cancelledClientLate;

  /// Display string for status chip
  String get displayStatus {
    switch (status) {
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.pending:
        return 'Pending Approval';
      case BookingStatus.reserved:
        return 'Hold (Checkout)';
      case BookingStatus.rescheduled:
        return 'Rescheduled';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.cancelledClientEarly:
        return 'Cancelled (Credit Returned)';
      case BookingStatus.cancelledClientLate:
        return 'Cancelled (Credit Forfeited)';
      case BookingStatus.cancelledTrainer:
        return 'Cancelled by Trainer (Credit Returned)';
      case BookingStatus.cancelledAdmin:
        return 'Cancelled by Platform (Credit Returned)';
      case BookingStatus.rejected:
        return 'Declined by Trainer';
      case BookingStatus.expired:
        return 'Hold Expired';
    }
  }

  /// Explicit 60-minute duration string
  String get sessionDurationDisplay => '60 Minutes (Personal 1-on-1)';

  /// Exact DateTime of the session start by combining sessionDate with startTime
  DateTime get fullSessionStartDateTime {
    int hour = 6;
    int minute = 0;
    try {
      final cleanTime = startTime.trim();
      final isPm = cleanTime.toUpperCase().contains('PM');
      final isAm = cleanTime.toUpperCase().contains('AM');
      final digitsOnly = cleanTime.replaceAll(RegExp(r'[^\d:]'), '');
      final parts = digitsOnly.split(':');
      if (parts.isNotEmpty) {
        hour = int.tryParse(parts[0]) ?? 6;
        if (parts.length > 1) {
          minute = int.tryParse(parts[1]) ?? 0;
        }
        if (isPm && hour < 12) hour += 12;
        if (isAm && hour == 12) hour = 0;
      }
    } catch (_) {}
    return DateTime(
      sessionDate.year,
      sessionDate.month,
      sessionDate.day,
      hour,
      minute,
    );
  }

  /// Exact hours until session start from now
  double get hoursUntilSession {
    final now = DateTime.now();
    return fullSessionStartDateTime.difference(now).inMinutes / 60.0;
  }

  /// Whether cancellation qualifies for full credit refund (>= 12h rule)
  bool get isCancellationCreditRefundable => hoursUntilSession >= 12.0;

  /// Formatted booking reference string
  String get bookingReference => 'REF-${id.replaceAll('-', '').toUpperCase().padRight(8, '0').substring(0, 8)}';

  /// Minutes remaining until reservation expires
  int get minutesRemaining {
    if (expiresAt == null) return 0;
    final diff = expiresAt!.difference(DateTime.now()).inMinutes;
    return diff > 0 ? diff : 0;
  }

  /// Seconds remaining until reservation expires
  int get secondsRemaining {
    if (expiresAt == null) return 0;
    final diff = expiresAt!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  /// ── Package & Schedule Resolved Metrics ──────────────────────────────────
  String get resolvedPackageName {
    if (packageName != null && packageName!.trim().isNotEmpty) return packageName!;
    final pid = (planId ?? '').toLowerCase();
    if (pid.contains('1_day')) return '1 Session Pass';
    if (pid.contains('3_day')) return '3 Sessions Starter';
    if (pid.contains('1_week')) return '1 Week (6 Sessions)';
    if (pid.contains('3_month')) return '3 Months Transformation';
    if (pid.contains('6_month')) return '6-Month Transformation';
    return 'Monthly Plan (30 Sessions)';
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

  /// Package remaining fraction: e.g. "15/30 Sessions Left", "7/90 Sessions Left", "3/30 Sessions Left"
  String get remainingDaysFraction => '$resolvedDaysRemaining/$resolvedTotalDays Sessions Left';
  String get remainingSessionsFraction => '$resolvedDaysRemaining/$resolvedTotalDays Sessions Left';

  /// Number-only fraction: e.g. "15/30", "7/90", "3/30"
  String get remainingFractionNumbers => '$resolvedDaysRemaining/$resolvedTotalDays';

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
    String? packageId,
    int? packagePrice,
    int? sessionsCount,
    int? validityDays,
    DateTime? sessionDate,
    String? startTime,
    String? endTime,
    BookingStatus? status,
    PaymentStatus? paymentStatus,
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
    String? paymentTransactionId,
    String? meetingLocation,
    String? locationReference,
    String? notes,
    bool? isRescheduled,
    DateTime? rescheduledAt,
    DateTime? previousSessionDate,
    String? previousStartTime,
    String? previousEndTime,
    DateTime? reservedAt,
    DateTime? expiresAt,
    DateTime? confirmedAt,
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
      packageId: packageId ?? this.packageId,
      packagePrice: packagePrice ?? this.packagePrice,
      sessionsCount: sessionsCount ?? this.sessionsCount,
      validityDays: validityDays ?? this.validityDays,
      sessionDate: sessionDate ?? this.sessionDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
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
      paymentTransactionId: paymentTransactionId ?? this.paymentTransactionId,
      meetingLocation: meetingLocation ?? this.meetingLocation,
      locationReference: locationReference ?? this.locationReference,
      notes: notes ?? this.notes,
      isRescheduled: isRescheduled ?? this.isRescheduled,
      rescheduledAt: rescheduledAt ?? this.rescheduledAt,
      previousSessionDate: previousSessionDate ?? this.previousSessionDate,
      previousStartTime: previousStartTime ?? this.previousStartTime,
      previousEndTime: previousEndTime ?? this.previousEndTime,
      reservedAt: reservedAt ?? this.reservedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
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
      'planId': planId ?? packageId,
      'packageId': packageId ?? planId,
      'packagePrice': packagePrice,
      'sessionsCount': sessionsCount,
      'validityDays': validityDays,
      'sessionDate': Timestamp.fromDate(sessionDate),
      'startTime': startTime,
      'endTime': endTime,
      'status': status.toFirestore(),
      'paymentStatus': paymentStatus.toFirestore(),
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
      'paymentTransactionId': paymentTransactionId,
      'meetingLocation': meetingLocation,
      'locationReference': locationReference ?? meetingLocation,
      'notes': notes,
      'isRescheduled': isRescheduled,
      'rescheduledAt': rescheduledAt != null ? Timestamp.fromDate(rescheduledAt!) : null,
      'previousSessionDate': previousSessionDate != null ? Timestamp.fromDate(previousSessionDate!) : null,
      'previousStartTime': previousStartTime,
      'previousEndTime': previousEndTime,
      'reservedAt': reservedAt != null ? Timestamp.fromDate(reservedAt!) : null,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'confirmedAt': confirmedAt != null ? Timestamp.fromDate(confirmedAt!) : null,
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
      planId: map['planId'] as String? ?? map['packageId'] as String?,
      packageId: map['packageId'] as String? ?? map['planId'] as String?,
      packagePrice: (map['packagePrice'] as num?)?.toInt(),
      sessionsCount: (map['sessionsCount'] as num?)?.toInt() ?? (map['sessions'] as num?)?.toInt(),
      validityDays: (map['validityDays'] as num?)?.toInt(),
      sessionDate: parseTimestamp(map['sessionDate']) ?? DateTime.now(),
      startTime: map['startTime'] as String? ?? '06:00',
      endTime: map['endTime'] as String? ?? '07:00',
      status: BookingStatus.fromFirestore(map['status']),
      paymentStatus: PaymentStatus.fromFirestore(map['paymentStatus']),
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
      paymentTransactionId: map['paymentTransactionId'] as String?,
      meetingLocation: map['meetingLocation'] as String?,
      locationReference: map['locationReference'] as String? ?? map['meetingLocation'] as String?,
      notes: map['notes'] as String?,
      isRescheduled: map['isRescheduled'] as bool? ?? false,
      rescheduledAt: parseTimestamp(map['rescheduledAt']),
      previousSessionDate: parseTimestamp(map['previousSessionDate']),
      previousStartTime: map['previousStartTime'] as String?,
      previousEndTime: map['previousEndTime'] as String?,
      reservedAt: parseTimestamp(map['reservedAt']),
      expiresAt: parseTimestamp(map['expiresAt']),
      confirmedAt: parseTimestamp(map['confirmedAt']),
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
    );
  }

  factory BookingModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BookingModel.fromMap(data, id: doc.id);
  }
}
