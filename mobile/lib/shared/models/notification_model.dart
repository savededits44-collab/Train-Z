import 'package:cloud_firestore/cloud_firestore.dart';

/// Categories for organizing Trainer notifications.
enum NotificationCategory {
  all,
  bookings,
  messages,
  sessions,
  packages,
  earnings,
  reviews,
  support,
  announcements;

  String get displayName {
    switch (this) {
      case NotificationCategory.all:
        return 'All';
      case NotificationCategory.bookings:
        return 'Bookings';
      case NotificationCategory.messages:
        return 'Messages';
      case NotificationCategory.sessions:
        return 'Sessions';
      case NotificationCategory.packages:
        return 'Packages';
      case NotificationCategory.earnings:
        return 'Earnings & Payouts';
      case NotificationCategory.reviews:
        return 'Reviews';
      case NotificationCategory.support:
        return 'Support';
      case NotificationCategory.announcements:
        return 'Announcements';
    }
  }
}

class NotificationModel {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type; // e.g. 'BOOKING_CONFIRMED', 'BOOKING_CANCELLED', 'BOOKING_RESCHEDULED', 'UPCOMING_REMINDER', 'CHAT_MESSAGE', 'PAYMENT_CONFIRMED'
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

  String? get bookingId => data['bookingId'] as String? ?? data['relatedId'] as String?;
  String? get conversationId => data['conversationId'] as String?;
  String? get trainerId => data['trainerId'] as String?;
  String? get trainerName => data['trainerName'] as String?;
  String? get ticketId => data['ticketId'] as String? ?? data['supportTicketId'] as String?;
  String? get paymentId => data['paymentId'] as String?;
  String? get receiptNumber => data['receiptNumber'] as String?;
  String? get packageId => data['packageId'] as String?;
  String? get payoutId => data['payoutId'] as String?;
  String? get reviewId => data['reviewId'] as String?;

  bool get isBookingRelated =>
      type.startsWith('BOOKING_') || type == 'UPCOMING_REMINDER';
  bool get isChatRelated => type == 'CHAT_MESSAGE';
  bool get isSupportRelated => type.startsWith('SUPPORT_');
  bool get isPaymentRelated =>
      type.startsWith('PAYMENT_') || type.startsWith('PACKAGE_') || type.contains('CREDIT_');

  /// Maps the notification type into one of the 7 designated TRAIN Z categories.
  String get category {
    final cleanType = type.trim().toUpperCase();
    if (cleanType.contains('REMINDER') || cleanType == 'SESSION_REMINDER') {
      return 'Sessions and reminders';
    }
    if (cleanType.startsWith('BOOKING_') || cleanType == 'BOOKING_UPDATE') {
      return 'Bookings';
    }
    if (cleanType.contains('CHAT') || cleanType.contains('MESSAGE')) {
      return 'Trainer messages';
    }
    if (cleanType.startsWith('PAYMENT_') ||
        cleanType.startsWith('PACKAGE_') ||
        cleanType.contains('CREDIT_') ||
        cleanType == 'PAYMENT_UPDATE') {
      return 'Packages and payments';
    }
    if (cleanType.contains('REVIEW') ||
        cleanType.contains('RATING') ||
        cleanType.contains('FEEDBACK')) {
      return 'Reviews and feedback';
    }
    if (cleanType.startsWith('SUPPORT_') || cleanType == 'SUPPORT_TICKET_UPDATE') {
      return 'Support updates';
    }
    if (cleanType.contains('ANNOUNCEMENT') ||
        cleanType.contains('MARKETING') ||
        cleanType.contains('PROMO')) {
      return 'Platform announcements';
    }
    return 'Other';
  }

  /// Extracts a formatted reference badge string (Booking #, Ticket #, Receipt #, or Coach).
  String? get referenceLabel {
    // 1. Support ticket
    final ticketNum = data['ticketNumber'] as String? ?? data['ticketId'] as String? ?? data['supportTicketId'] as String?;
    if (ticketNum != null && ticketNum.isNotEmpty) {
      final clean = ticketNum.length > 10 ? ticketNum.substring(0, 8).toUpperCase() : ticketNum.toUpperCase();
      return 'Ticket: #$clean';
    }

    // 2. Receipt / Payment
    final rNum = data['receiptNumber'] as String?;
    if (rNum != null && rNum.isNotEmpty) {
      return 'Receipt: #$rNum';
    }
    final payId = data['paymentId'] as String?;
    if (payId != null && payId.isNotEmpty) {
      final clean = payId.length > 8 ? payId.substring(0, 8).toUpperCase() : payId.toUpperCase();
      return 'Payment: #$clean';
    }

    // 3. Booking reference
    final bRef = data['bookingReference'] as String?;
    if (bRef != null && bRef.isNotEmpty) {
      return 'Ref: #$bRef';
    }
    final bId = bookingId;
    if (bId != null && bId.isNotEmpty) {
      final clean = bId.length > 8 ? bId.substring(0, 8).toUpperCase() : bId.toUpperCase();
      return 'Ref: #$clean';
    }

    // 4. Trainer reference
    if (trainerName != null && trainerName!.isNotEmpty) {
      return 'Coach: $trainerName';
    }

    return null;
  }

  /// Maps the string [type] into a [NotificationCategory].
  NotificationCategory get categoryEnum {
    final t = type.toUpperCase();
    if (t.startsWith('BOOKING_')) {
      return NotificationCategory.bookings;
    }
    if (t == 'CHAT_MESSAGE' || t == 'MESSAGE') {
      return NotificationCategory.messages;
    }
    if (t.contains('REMINDER') || t.startsWith('SESSION_')) {
      return NotificationCategory.sessions;
    }
    if (t.startsWith('PACKAGE_')) {
      return NotificationCategory.packages;
    }
    if (t.startsWith('PAYOUT_') || t.startsWith('EARNINGS_') || t == 'PAYMENT_CONFIRMED' || t == 'PAYOUT') {
      return NotificationCategory.earnings;
    }
    if (t.startsWith('REVIEW_') || t == 'REVIEW') {
      return NotificationCategory.reviews;
    }
    if (t.startsWith('SUPPORT_') || t == 'SUPPORT') {
      return NotificationCategory.support;
    }
    if (t == 'ANNOUNCEMENT' || t == 'PLATFORM_ANNOUNCEMENT' || t == 'GENERAL') {
      return NotificationCategory.announcements;
    }
    return NotificationCategory.announcements;
  }

  NotificationCategory get trainerCategory => categoryEnum;

  /// Formatted date and time string.
  String get formattedDate {
    if (createdAt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(createdAt!);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24 && createdAt!.day == now.day) {
      final hour = createdAt!.hour.toString().padLeft(2, '0');
      final min = createdAt!.minute.toString().padLeft(2, '0');
      return 'Today, $hour:$min';
    }
    if (diff.inDays == 1 || (diff.inHours < 48 && createdAt!.day == now.subtract(const Duration(days: 1)).day)) {
      final hour = createdAt!.hour.toString().padLeft(2, '0');
      final min = createdAt!.minute.toString().padLeft(2, '0');
      return 'Yesterday, $hour:$min';
    }

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = createdAt!.hour.toString().padLeft(2, '0');
    final min = createdAt!.minute.toString().padLeft(2, '0');
    return '${createdAt!.day} ${months[createdAt!.month - 1]} ${createdAt!.year}, $hour:$min';
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? type,
    bool? isRead,
    Map<String, dynamic>? data,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
    );
  }

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
