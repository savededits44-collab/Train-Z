import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Payout status for individual earnings transactions
enum TrainerPayoutStatus {
  processing,
  eligibleForPayout,
  payoutPending,
  paid,
  failed,
  refunded,
  reversed;

  String toFirestore() {
    switch (this) {
      case TrainerPayoutStatus.processing:
        return 'PROCESSING';
      case TrainerPayoutStatus.eligibleForPayout:
        return 'ELIGIBLE_FOR_PAYOUT';
      case TrainerPayoutStatus.payoutPending:
        return 'PAYOUT_PENDING';
      case TrainerPayoutStatus.paid:
        return 'PAID';
      case TrainerPayoutStatus.failed:
        return 'FAILED';
      case TrainerPayoutStatus.refunded:
        return 'REFUNDED';
      case TrainerPayoutStatus.reversed:
        return 'REVERSED';
    }
  }

  static TrainerPayoutStatus fromFirestore(dynamic val) {
    if (val == null) return TrainerPayoutStatus.eligibleForPayout;
    final str = val.toString().trim().toUpperCase();
    switch (str) {
      case 'PROCESSING':
        return TrainerPayoutStatus.processing;
      case 'ELIGIBLE_FOR_PAYOUT':
      case 'ELIGIBLE':
        return TrainerPayoutStatus.eligibleForPayout;
      case 'PAYOUT_PENDING':
      case 'PENDING':
        return TrainerPayoutStatus.payoutPending;
      case 'PAID':
        return TrainerPayoutStatus.paid;
      case 'FAILED':
        return TrainerPayoutStatus.failed;
      case 'REFUNDED':
        return TrainerPayoutStatus.refunded;
      case 'REVERSED':
        return TrainerPayoutStatus.reversed;
      default:
        return TrainerPayoutStatus.eligibleForPayout;
    }
  }

  String get displayTitle {
    switch (this) {
      case TrainerPayoutStatus.processing:
        return 'Processing';
      case TrainerPayoutStatus.eligibleForPayout:
        return 'Eligible for Payout';
      case TrainerPayoutStatus.payoutPending:
        return 'Payout Pending';
      case TrainerPayoutStatus.paid:
        return 'Paid';
      case TrainerPayoutStatus.failed:
        return 'Failed';
      case TrainerPayoutStatus.refunded:
        return 'Refunded';
      case TrainerPayoutStatus.reversed:
        return 'Reversed';
    }
  }

  Color get color {
    switch (this) {
      case TrainerPayoutStatus.processing:
        return const Color(0xFF3B82F6); // Blue
      case TrainerPayoutStatus.eligibleForPayout:
        return const Color(0xFF10B981); // Emerald Green
      case TrainerPayoutStatus.payoutPending:
        return const Color(0xFFF59E0B); // Amber
      case TrainerPayoutStatus.paid:
        return const Color(0xFFD4FF00); // Lime Accent
      case TrainerPayoutStatus.failed:
        return const Color(0xFFEF4444); // Red
      case TrainerPayoutStatus.refunded:
      case TrainerPayoutStatus.reversed:
        return const Color(0xFF9CA3AF); // Muted Grey
    }
  }
}

/// Represents an authoritative transaction record of completed session earnings.
class TrainerEarningsTransactionModel {
  final String id;
  final String bookingId;
  final String bookingRef;
  final String trainerId;
  final String? clientId;
  final String clientName;
  final String packageName;
  final DateTime sessionDate;
  final String startTime;
  final String endTime;
  final int durationMinutes;
  final int grossAmount; // in INR
  final int? commissionRatePercent; // e.g. 15
  final int commissionAmount; // in INR
  final int netAmount; // in INR (grossAmount - commissionAmount)
  final TrainerPayoutStatus payoutStatus;
  final String status; // 'COMPLETED', 'REFUNDED', 'REVERSED'
  final String? payoutId;
  final String? failureReason;
  final String? refundReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TrainerEarningsTransactionModel({
    required this.id,
    required this.bookingId,
    required this.bookingRef,
    required this.trainerId,
    this.clientId,
    required this.clientName,
    required this.packageName,
    required this.sessionDate,
    this.startTime = '08:00',
    this.endTime = '09:00',
    this.durationMinutes = 60,
    required this.grossAmount,
    this.commissionRatePercent,
    required this.commissionAmount,
    required this.netAmount,
    this.payoutStatus = TrainerPayoutStatus.eligibleForPayout,
    this.status = 'COMPLETED',
    this.payoutId,
    this.failureReason,
    this.refundReason,
    this.createdAt,
    this.updatedAt,
  });

  String get formattedGross => '₹$grossAmount';
  String get formattedCommission => '₹$commissionAmount';
  String get formattedNet => '₹$netAmount';

  String get formattedTimeSlot => '$startTime - $endTime ($durationMinutes min)';

  String get formattedSessionDate {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${sessionDate.day} ${months[sessionDate.month - 1]} ${sessionDate.year}';
  }

  bool get isRefunded => payoutStatus == TrainerPayoutStatus.refunded || payoutStatus == TrainerPayoutStatus.reversed;
  bool get isEligible => payoutStatus == TrainerPayoutStatus.eligibleForPayout;
  bool get isPaid => payoutStatus == TrainerPayoutStatus.paid;

  TrainerEarningsTransactionModel copyWith({
    String? id,
    String? bookingId,
    String? bookingRef,
    String? trainerId,
    String? clientId,
    String? clientName,
    String? packageName,
    DateTime? sessionDate,
    String? startTime,
    String? endTime,
    int? durationMinutes,
    int? grossAmount,
    int? commissionRatePercent,
    int? commissionAmount,
    int? netAmount,
    TrainerPayoutStatus? payoutStatus,
    String? status,
    String? payoutId,
    String? failureReason,
    String? refundReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TrainerEarningsTransactionModel(
      id: id ?? this.id,
      bookingId: bookingId ?? this.bookingId,
      bookingRef: bookingRef ?? this.bookingRef,
      trainerId: trainerId ?? this.trainerId,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      packageName: packageName ?? this.packageName,
      sessionDate: sessionDate ?? this.sessionDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      grossAmount: grossAmount ?? this.grossAmount,
      commissionRatePercent: commissionRatePercent ?? this.commissionRatePercent,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      netAmount: netAmount ?? this.netAmount,
      payoutStatus: payoutStatus ?? this.payoutStatus,
      status: status ?? this.status,
      payoutId: payoutId ?? this.payoutId,
      failureReason: failureReason ?? this.failureReason,
      refundReason: refundReason ?? this.refundReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookingId': bookingId,
      'bookingRef': bookingRef,
      'trainerId': trainerId,
      'clientId': clientId,
      'clientName': clientName,
      'packageName': packageName,
      'sessionDate': Timestamp.fromDate(sessionDate),
      'startTime': startTime,
      'endTime': endTime,
      'durationMinutes': durationMinutes,
      'grossAmount': grossAmount,
      'commissionRatePercent': commissionRatePercent,
      'commissionAmount': commissionAmount,
      'netAmount': netAmount,
      'payoutStatus': payoutStatus.toFirestore(),
      'status': status,
      'payoutId': payoutId,
      'failureReason': failureReason,
      'refundReason': refundReason,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory TrainerEarningsTransactionModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return TrainerEarningsTransactionModel(
      id: id,
      bookingId: map['bookingId'] as String? ?? id.replaceFirst('earn_', ''),
      bookingRef: map['bookingRef'] as String? ?? '#${id.length >= 8 ? id.substring(0, 8).toUpperCase() : id}',
      trainerId: map['trainerId'] as String? ?? '',
      clientId: map['clientId'] as String?,
      clientName: map['clientName'] as String? ?? 'Client',
      packageName: map['packageName'] as String? ?? 'Personal Training',
      sessionDate: parseDate(map['sessionDate']),
      startTime: map['startTime'] as String? ?? '08:00',
      endTime: map['endTime'] as String? ?? '09:00',
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 60,
      grossAmount: (map['grossAmount'] as num?)?.toInt() ?? 0,
      commissionRatePercent: (map['commissionRatePercent'] as num?)?.toInt(),
      commissionAmount: (map['commissionAmount'] as num?)?.toInt() ?? 0,
      netAmount: (map['netAmount'] as num?)?.toInt() ?? 0,
      payoutStatus: TrainerPayoutStatus.fromFirestore(map['payoutStatus']),
      status: map['status'] as String? ?? 'COMPLETED',
      payoutId: map['payoutId'] as String?,
      failureReason: map['failureReason'] as String?,
      refundReason: map['refundReason'] as String?,
      createdAt: map['createdAt'] != null ? parseDate(map['createdAt']) : null,
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
    );
  }
}

/// Status of aggregated payout batches
enum PayoutBatchStatus {
  processing,
  pending,
  paid,
  failed;

  String toFirestore() {
    switch (this) {
      case PayoutBatchStatus.processing:
        return 'PROCESSING';
      case PayoutBatchStatus.pending:
        return 'PENDING';
      case PayoutBatchStatus.paid:
        return 'PAID';
      case PayoutBatchStatus.failed:
        return 'FAILED';
    }
  }

  static PayoutBatchStatus fromFirestore(dynamic val) {
    if (val == null) return PayoutBatchStatus.pending;
    final str = val.toString().trim().toUpperCase();
    switch (str) {
      case 'PROCESSING':
        return PayoutBatchStatus.processing;
      case 'PAID':
        return PayoutBatchStatus.paid;
      case 'FAILED':
        return PayoutBatchStatus.failed;
      case 'PENDING':
      default:
        return PayoutBatchStatus.pending;
    }
  }

  String get displayTitle {
    switch (this) {
      case PayoutBatchStatus.processing:
        return 'Processing';
      case PayoutBatchStatus.pending:
        return 'Payout Pending';
      case PayoutBatchStatus.paid:
        return 'Paid';
      case PayoutBatchStatus.failed:
        return 'Failed';
    }
  }

  Color get color {
    switch (this) {
      case PayoutBatchStatus.processing:
        return const Color(0xFF3B82F6);
      case PayoutBatchStatus.pending:
        return const Color(0xFFF59E0B);
      case PayoutBatchStatus.paid:
        return const Color(0xFFD4FF00);
      case PayoutBatchStatus.failed:
        return const Color(0xFFEF4444);
    }
  }
}

/// Represents an aggregated payout batch disbursed to the trainer
class TrainerPayoutModel {
  final String id;
  final String trainerId;
  final int amount; // in INR
  final DateTime payoutDate;
  final PayoutBatchStatus status;
  final int transactionCount;
  final String? bankAccountLast4;
  final String? bankName;
  final String? utrNumber;
  final String? failureReason;
  final DateTime? createdAt;

  const TrainerPayoutModel({
    required this.id,
    required this.trainerId,
    required this.amount,
    required this.payoutDate,
    this.status = PayoutBatchStatus.paid,
    this.transactionCount = 1,
    this.bankAccountLast4,
    this.bankName,
    this.utrNumber,
    this.failureReason,
    this.createdAt,
  });

  String get formattedAmount => '₹$amount';

  String get formattedDate {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${payoutDate.day} ${months[payoutDate.month - 1]} ${payoutDate.year}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trainerId': trainerId,
      'amount': amount,
      'payoutDate': Timestamp.fromDate(payoutDate),
      'status': status.toFirestore(),
      'transactionCount': transactionCount,
      'bankAccountLast4': bankAccountLast4,
      'bankName': bankName,
      'utrNumber': utrNumber,
      'failureReason': failureReason,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory TrainerPayoutModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return TrainerPayoutModel(
      id: id,
      trainerId: map['trainerId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      payoutDate: parseDate(map['payoutDate']),
      status: PayoutBatchStatus.fromFirestore(map['status']),
      transactionCount: (map['transactionCount'] as num?)?.toInt() ?? 1,
      bankAccountLast4: map['bankAccountLast4'] as String?,
      bankName: map['bankName'] as String?,
      utrNumber: map['utrNumber'] as String?,
      failureReason: map['failureReason'] as String?,
      createdAt: map['createdAt'] != null ? parseDate(map['createdAt']) : null,
    );
  }
}

/// Aggregated financial metrics overview
class TrainerEarningsSummaryModel {
  final int totalGrossRevenue;
  final int totalCommission;
  final int netEarnings;
  final int pendingPayout;
  final int totalPaidOut;
  final int completedSessionsCount;
  final int? commissionRatePercent;
  final bool isCommissionConfigured;

  const TrainerEarningsSummaryModel({
    this.totalGrossRevenue = 0,
    this.totalCommission = 0,
    this.netEarnings = 0,
    this.pendingPayout = 0,
    this.totalPaidOut = 0,
    this.completedSessionsCount = 0,
    this.commissionRatePercent,
    this.isCommissionConfigured = true,
  });

  String get formattedGrossRevenue => '₹$totalGrossRevenue';
  String get formattedCommission => '₹$totalCommission';
  String get formattedNetEarnings => '₹$netEarnings';
  String get formattedPendingPayout => '₹$pendingPayout';
  String get formattedPaidOut => '₹$totalPaidOut';

  String get formattedCommissionRate =>
      isCommissionConfigured && commissionRatePercent != null ? '$commissionRatePercent%' : 'Pending';

  double get averageNetPerSession =>
      completedSessionsCount > 0 ? netEarnings / completedSessionsCount : 0.0;
}

