import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of an account deletion request.
enum DeletionRequestStatus {
  pendingReview,
  approved,
  rejected;

  String toFirestore() {
    switch (this) {
      case DeletionRequestStatus.pendingReview:
        return 'PENDING_REVIEW';
      case DeletionRequestStatus.approved:
        return 'APPROVED';
      case DeletionRequestStatus.rejected:
        return 'REJECTED';
    }
  }

  static DeletionRequestStatus fromFirestore(dynamic val) {
    if (val == null) return DeletionRequestStatus.pendingReview;
    final str = val.toString().trim().toUpperCase();
    if (str == 'APPROVED') return DeletionRequestStatus.approved;
    if (str == 'REJECTED') return DeletionRequestStatus.rejected;
    return DeletionRequestStatus.pendingReview;
  }

  String get displayName {
    switch (this) {
      case DeletionRequestStatus.pendingReview:
        return 'Pending Review';
      case DeletionRequestStatus.approved:
        return 'Approved & Deleted';
      case DeletionRequestStatus.rejected:
        return 'Rejected';
    }
  }
}

/// Represents a formal request submitted by a Trainer to delete their platform account.
/// Legal, financial, and booking audit records are permanently preserved.
class AccountDeletionRequestModel {
  final String id;
  final String userId;
  final String role;
  final String reason;
  final DeletionRequestStatus status;
  final bool preserveFinancialRecords;
  final bool preserveBookingHistory;
  final DateTime? requestedAt;
  final DateTime? processedAt;
  final String? adminNotes;

  const AccountDeletionRequestModel({
    required this.id,
    required this.userId,
    this.role = 'TRAINER',
    required this.reason,
    this.status = DeletionRequestStatus.pendingReview,
    this.preserveFinancialRecords = true,
    this.preserveBookingHistory = true,
    this.requestedAt,
    this.processedAt,
    this.adminNotes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'role': role,
        'reason': reason,
        'status': status.toFirestore(),
        'preserveFinancialRecords': preserveFinancialRecords,
        'preserveBookingHistory': preserveBookingHistory,
        'requestedAt': requestedAt != null ? Timestamp.fromDate(requestedAt!) : FieldValue.serverTimestamp(),
        if (processedAt != null) 'processedAt': Timestamp.fromDate(processedAt!),
        if (adminNotes != null) 'adminNotes': adminNotes,
      };

  factory AccountDeletionRequestModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return AccountDeletionRequestModel(
      id: id,
      userId: map['userId'] as String? ?? '',
      role: map['role'] as String? ?? 'TRAINER',
      reason: map['reason'] as String? ?? '',
      status: DeletionRequestStatus.fromFirestore(map['status']),
      preserveFinancialRecords: map['preserveFinancialRecords'] as bool? ?? true,
      preserveBookingHistory: map['preserveBookingHistory'] as bool? ?? true,
      requestedAt: parseDate(map['requestedAt']),
      processedAt: parseDate(map['processedAt']),
      adminNotes: map['adminNotes'] as String?,
    );
  }
}

/// Result of evaluating whether a Trainer is eligible to delete their account.
class TrainerDeletionEligibilityResult {
  final bool canDelete;
  final String? blockerReason;
  final int activeBookingsCount;
  final int pendingPayoutsAmount;

  const TrainerDeletionEligibilityResult({
    required this.canDelete,
    this.blockerReason,
    this.activeBookingsCount = 0,
    this.pendingPayoutsAmount = 0,
  });

  bool get hasActiveBookings => activeBookingsCount > 0;
  bool get hasPendingPayouts => pendingPayoutsAmount > 0;
}

