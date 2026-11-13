/// Model representing a Trainer's notification channel preferences.
/// Essential account-security and verification notifications are permanently active.
class TrainerNotificationPreferencesModel {
  final bool bookings;
  final bool sessionReminders;
  final bool messages;
  final bool packageApprovals;
  final bool payouts;
  final bool reviews;
  final bool support;
  final bool promotions;

  const TrainerNotificationPreferencesModel({
    this.bookings = true,
    this.sessionReminders = true,
    this.messages = true,
    this.packageApprovals = true,
    this.payouts = true,
    this.reviews = true,
    this.support = true,
    this.promotions = true,
  });

  /// Essential account security notifications cannot be disabled.
  bool get accountSecurity => true;

  /// Critical trainer identity and certification compliance status cannot be disabled.
  bool get verificationStatus => true;

  TrainerNotificationPreferencesModel copyWith({
    bool? bookings,
    bool? sessionReminders,
    bool? messages,
    bool? packageApprovals,
    bool? payouts,
    bool? reviews,
    bool? support,
    bool? promotions,
  }) {
    return TrainerNotificationPreferencesModel(
      bookings: bookings ?? this.bookings,
      sessionReminders: sessionReminders ?? this.sessionReminders,
      messages: messages ?? this.messages,
      packageApprovals: packageApprovals ?? this.packageApprovals,
      payouts: payouts ?? this.payouts,
      reviews: reviews ?? this.reviews,
      support: support ?? this.support,
      promotions: promotions ?? this.promotions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bookings': bookings,
      'sessionReminders': sessionReminders,
      'messages': messages,
      'packageApprovals': packageApprovals,
      'payouts': payouts,
      'reviews': reviews,
      'support': support,
      'promotions': promotions,
      'accountSecurity': true,
      'verificationStatus': true,
    };
  }

  factory TrainerNotificationPreferencesModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const TrainerNotificationPreferencesModel();
    return TrainerNotificationPreferencesModel(
      bookings: map['bookings'] as bool? ?? true,
      sessionReminders: map['sessionReminders'] as bool? ?? true,
      messages: map['messages'] as bool? ?? true,
      packageApprovals: map['packageApprovals'] as bool? ?? true,
      payouts: map['payouts'] as bool? ?? true,
      reviews: map['reviews'] as bool? ?? true,
      support: map['support'] as bool? ?? true,
      promotions: map['promotions'] as bool? ?? true,
    );
  }
}

