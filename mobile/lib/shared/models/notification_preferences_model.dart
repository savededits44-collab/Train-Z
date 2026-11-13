import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a Client's notification preferences across TRAIN Z categories.
/// Essential account security notifications are mandatory and cannot be disabled.
class NotificationPreferencesModel {
  final bool bookingUpdates;
  final bool sessionReminders;
  final bool paymentUpdates;
  final bool trainerMessages;
  final bool reviewsAndFeedback;
  final bool supportUpdates;
  final bool platformAnnouncements;

  const NotificationPreferencesModel({
    this.bookingUpdates = true,
    this.sessionReminders = true,
    this.paymentUpdates = true,
    this.trainerMessages = true,
    this.reviewsAndFeedback = true,
    this.supportUpdates = true,
    this.platformAnnouncements = false,
  });

  /// Evaluates whether a given notification type is enabled by the client's preferences.
  /// Mandatory account security and critical payment transaction alerts always return true.
  bool isCategoryEnabled(String type) {
    final cleanType = type.trim().toUpperCase();

    // 1. Mandatory Account Security (Never suppressed)
    if (cleanType.contains('SECURITY') ||
        cleanType.contains('PASSWORD') ||
        cleanType.contains('AUTH') ||
        cleanType.contains('LOGIN') ||
        cleanType.contains('DELETION')) {
      return true;
    }

    // 2. Mandatory Critical Payment Transactions (Never suppressed)
    if (cleanType == 'PAYMENT_CONFIRMED' ||
        cleanType == 'PAYMENT_FAILED' ||
        cleanType == 'TRANSACTION_RECEIPT' ||
        cleanType == 'PAYMENT_RECEIPT' ||
        cleanType.contains('REFUND')) {
      return true;
    }

    // 3. Booking updates
    if (cleanType.startsWith('BOOKING_') || cleanType == 'BOOKING_UPDATE') {
      return bookingUpdates;
    }

    // 4. Session reminders
    if (cleanType.contains('REMINDER') || cleanType == 'SESSION_REMINDER') {
      return sessionReminders;
    }

    // 5. General payment and package updates
    if (cleanType.startsWith('PAYMENT_') ||
        cleanType.startsWith('PACKAGE_') ||
        cleanType.contains('CREDIT_') ||
        cleanType == 'PAYMENT_UPDATE') {
      return paymentUpdates;
    }

    // 6. Trainer messages
    if (cleanType.contains('CHAT') || cleanType.contains('MESSAGE')) {
      return trainerMessages;
    }

    // 7. Reviews and feedback
    if (cleanType.contains('REVIEW') ||
        cleanType.contains('RATING') ||
        cleanType.contains('FEEDBACK')) {
      return reviewsAndFeedback;
    }

    // 8. Support ticket updates
    if (cleanType.startsWith('SUPPORT_') || cleanType == 'SUPPORT_TICKET_UPDATE') {
      return supportUpdates;
    }

    // 9. General platform announcements & promotional updates
    if (cleanType.contains('ANNOUNCEMENT') ||
        cleanType.contains('MARKETING') ||
        cleanType.contains('PROMO')) {
      return platformAnnouncements;
    }

    // Default permissive for unspecified system notices
    return true;
  }

  Map<String, dynamic> toMap() {
    return {
      'bookingUpdates': bookingUpdates,
      'sessionReminders': sessionReminders,
      'paymentUpdates': paymentUpdates,
      'trainerMessages': trainerMessages,
      'reviewsAndFeedback': reviewsAndFeedback,
      'supportUpdates': supportUpdates,
      'platformAnnouncements': platformAnnouncements,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory NotificationPreferencesModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const NotificationPreferencesModel();
    return NotificationPreferencesModel(
      bookingUpdates: map['bookingUpdates'] as bool? ?? true,
      sessionReminders: map['sessionReminders'] as bool? ?? true,
      paymentUpdates: map['paymentUpdates'] as bool? ?? true,
      trainerMessages: map['trainerMessages'] as bool? ?? true,
      reviewsAndFeedback: map['reviewsAndFeedback'] as bool? ?? true,
      supportUpdates: map['supportUpdates'] as bool? ?? true,
      platformAnnouncements: map['platformAnnouncements'] as bool? ?? false,
    );
  }

  factory NotificationPreferencesModel.fromDocument(DocumentSnapshot doc) {
    if (!doc.exists) return const NotificationPreferencesModel();
    final data = doc.data() as Map<String, dynamic>?;
    return NotificationPreferencesModel.fromMap(data);
  }

  NotificationPreferencesModel copyWith({
    bool? bookingUpdates,
    bool? sessionReminders,
    bool? paymentUpdates,
    bool? trainerMessages,
    bool? reviewsAndFeedback,
    bool? supportUpdates,
    bool? platformAnnouncements,
  }) {
    return NotificationPreferencesModel(
      bookingUpdates: bookingUpdates ?? this.bookingUpdates,
      sessionReminders: sessionReminders ?? this.sessionReminders,
      paymentUpdates: paymentUpdates ?? this.paymentUpdates,
      trainerMessages: trainerMessages ?? this.trainerMessages,
      reviewsAndFeedback: reviewsAndFeedback ?? this.reviewsAndFeedback,
      supportUpdates: supportUpdates ?? this.supportUpdates,
      platformAnnouncements: platformAnnouncements ?? this.platformAnnouncements,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationPreferencesModel &&
          runtimeType == other.runtimeType &&
          bookingUpdates == other.bookingUpdates &&
          sessionReminders == other.sessionReminders &&
          paymentUpdates == other.paymentUpdates &&
          trainerMessages == other.trainerMessages &&
          reviewsAndFeedback == other.reviewsAndFeedback &&
          supportUpdates == other.supportUpdates &&
          platformAnnouncements == other.platformAnnouncements;

  @override
  int get hashCode =>
      bookingUpdates.hashCode ^
      sessionReminders.hashCode ^
      paymentUpdates.hashCode ^
      trainerMessages.hashCode ^
      reviewsAndFeedback.hashCode ^
      supportUpdates.hashCode ^
      platformAnnouncements.hashCode;
}
