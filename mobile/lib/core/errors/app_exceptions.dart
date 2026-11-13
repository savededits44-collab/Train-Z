library;

/// Custom exception hierarchy for TRAIN Z platform operations.

sealed class TrainZException implements Exception {
  final String message;
  final String? code;
  final dynamic details;

  const TrainZException(this.message, {this.code, this.details});

  @override
  String toString() => 'TrainZException[$code]: $message';
}

/// Authentication and session errors
class AuthException extends TrainZException {
  const AuthException(super.message, {super.code, super.details});
}

/// Role violation or unauthorized privilege escalation attempt
class RolePermissionException extends TrainZException {
  const RolePermissionException(super.message, {super.code = 'PERMISSION_DENIED', super.details});
}

/// Gender matching rule violation (Male -> Male, Female -> Female)
class GenderMismatchException extends TrainZException {
  const GenderMismatchException(
    super.message, {
    super.code = 'GENDER_MISMATCH',
    super.details,
  });
}

/// Trainer verification status prevents booking or discovery
class TrainerNotApprovedException extends TrainZException {
  const TrainerNotApprovedException(
    super.message, {
    super.code = 'TRAINER_NOT_APPROVED',
    super.details,
  });
}

/// Client attempts to reserve a session without adequate available credits
class InsufficientCreditsException extends TrainZException {
  const InsufficientCreditsException(
    super.message, {
    super.code = 'INSUFFICIENT_CREDITS',
    super.details,
  });
}

/// Session cancellation policy violation
class CancellationPolicyException extends TrainZException {
  final bool isForfeited;
  const CancellationPolicyException(
    super.message, {
    this.isForfeited = false,
    super.code = 'CANCELLATION_POLICY',
    super.details,
  });
}

/// Double-booking collision or slot already reserved
class BookingConflictException extends TrainZException {
  const BookingConflictException(
    super.message, {
    super.code = 'SLOT_ALREADY_RESERVED',
    super.details,
  });
}

/// Temporary slot reservation expired
class ReservationExpiredException extends TrainZException {
  const ReservationExpiredException(
    super.message, {
    super.code = 'RESERVATION_EXPIRED',
    super.details,
  });
}

/// Firebase storage and document upload errors
class StorageException extends TrainZException {
  const StorageException(super.message, {super.code, super.details});
}

/// Review submission, validation, or moderation errors
class ReviewException extends TrainZException {
  const ReviewException(super.message, {super.code = 'REVIEW_ERROR', super.details});
}

/// Client support, complaint submission, and ticket management errors
class SupportException extends TrainZException {
  const SupportException(super.message, {super.code = 'SUPPORT_ERROR', super.details});
}

/// Client account settings, security, and profile preference errors
class SettingsException extends TrainZException {
  const SettingsException(super.message, {super.code = 'SETTINGS_ERROR', super.details});
}
