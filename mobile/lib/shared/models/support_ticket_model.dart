import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Complaint and support request categories for TRAIN Z
enum SupportTicketCategory {
  bookingIssue,
  trainerIssue,
  paymentIssue,
  refundCancellation,
  technicalIssue,
  accountIssue,
  other;

  String get label {
    switch (this) {
      case SupportTicketCategory.bookingIssue:
        return 'Booking issue';
      case SupportTicketCategory.trainerIssue:
        return 'Trainer-related issue';
      case SupportTicketCategory.paymentIssue:
        return 'Payment issue';
      case SupportTicketCategory.refundCancellation:
        return 'Refund or cancellation';
      case SupportTicketCategory.technicalIssue:
        return 'Technical issue';
      case SupportTicketCategory.accountIssue:
        return 'Account issue';
      case SupportTicketCategory.other:
        return 'Other';
    }
  }

  String get firestoreValue {
    switch (this) {
      case SupportTicketCategory.bookingIssue:
        return 'BOOKING_ISSUE';
      case SupportTicketCategory.trainerIssue:
        return 'TRAINER_ISSUE';
      case SupportTicketCategory.paymentIssue:
        return 'PAYMENT_ISSUE';
      case SupportTicketCategory.refundCancellation:
        return 'REFUND_CANCELLATION';
      case SupportTicketCategory.technicalIssue:
        return 'TECHNICAL_ISSUE';
      case SupportTicketCategory.accountIssue:
        return 'ACCOUNT_ISSUE';
      case SupportTicketCategory.other:
        return 'OTHER';
    }
  }

  static SupportTicketCategory fromString(String? value) {
    if (value == null) return SupportTicketCategory.other;
    final normalized = value.trim().toUpperCase().replaceAll(' ', '_').replaceAll('-', '_');
    switch (normalized) {
      case 'BOOKING_ISSUE':
      case 'BOOKING':
        return SupportTicketCategory.bookingIssue;
      case 'TRAINER_ISSUE':
      case 'TRAINER_RELATED_ISSUE':
      case 'TRAINER':
        return SupportTicketCategory.trainerIssue;
      case 'PAYMENT_ISSUE':
      case 'PAYMENT':
        return SupportTicketCategory.paymentIssue;
      case 'REFUND_CANCELLATION':
      case 'REFUND':
      case 'CANCELLATION':
        return SupportTicketCategory.refundCancellation;
      case 'TECHNICAL_ISSUE':
      case 'TECHNICAL':
        return SupportTicketCategory.technicalIssue;
      case 'ACCOUNT_ISSUE':
      case 'ACCOUNT':
        return SupportTicketCategory.accountIssue;
      default:
        return SupportTicketCategory.other;
    }
  }
}

/// Lifecycle status of a TRAIN Z support ticket
enum SupportTicketStatus {
  submitted,
  underReview,
  inProgress,
  resolved,
  closed;

  String get label {
    switch (this) {
      case SupportTicketStatus.submitted:
        return 'Submitted';
      case SupportTicketStatus.underReview:
        return 'Under Review';
      case SupportTicketStatus.inProgress:
        return 'In Progress';
      case SupportTicketStatus.resolved:
        return 'Resolved';
      case SupportTicketStatus.closed:
        return 'Closed';
    }
  }

  String get firestoreValue {
    switch (this) {
      case SupportTicketStatus.submitted:
        return 'SUBMITTED';
      case SupportTicketStatus.underReview:
        return 'UNDER_REVIEW';
      case SupportTicketStatus.inProgress:
        return 'IN_PROGRESS';
      case SupportTicketStatus.resolved:
        return 'RESOLVED';
      case SupportTicketStatus.closed:
        return 'CLOSED';
    }
  }

  Color get color {
    switch (this) {
      case SupportTicketStatus.submitted:
        return const Color(0xFF2563EB); // Blue
      case SupportTicketStatus.underReview:
        return const Color(0xFFD97706); // Amber
      case SupportTicketStatus.inProgress:
        return const Color(0xFF7C3AED); // Purple
      case SupportTicketStatus.resolved:
        return const Color(0xFF16A34A); // Green
      case SupportTicketStatus.closed:
        return const Color(0xFF6B7280); // Grey
    }
  }

  Color get backgroundColor {
    switch (this) {
      case SupportTicketStatus.submitted:
        return const Color(0xFFEFF6FF);
      case SupportTicketStatus.underReview:
        return const Color(0xFFFFFBEB);
      case SupportTicketStatus.inProgress:
        return const Color(0xFFF5F3FF);
      case SupportTicketStatus.resolved:
        return const Color(0xFFF0FDF4);
      case SupportTicketStatus.closed:
        return const Color(0xFFF3F4F6);
    }
  }

  static SupportTicketStatus fromString(String? value) {
    if (value == null) return SupportTicketStatus.submitted;
    final normalized = value.trim().toUpperCase().replaceAll(' ', '_').replaceAll('-', '_');
    switch (normalized) {
      case 'SUBMITTED':
        return SupportTicketStatus.submitted;
      case 'UNDER_REVIEW':
        return SupportTicketStatus.underReview;
      case 'IN_PROGRESS':
        return SupportTicketStatus.inProgress;
      case 'RESOLVED':
        return SupportTicketStatus.resolved;
      case 'CLOSED':
        return SupportTicketStatus.closed;
      default:
        return SupportTicketStatus.submitted;
    }
  }
}

/// Represents a support ticket submitted by a client in TRAIN Z
class SupportTicketModel {
  final String id;
  final String ticketNumber; // e.g. TKT-7B9F12
  final String clientId;
  final String clientName;
  final String? clientEmail;
  final SupportTicketCategory category;
  final String subject;
  final String description;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? bookingId;
  final String? bookingReference;
  final SupportTicketStatus status;
  final String? lastMessage;
  final String? lastMessageSender; // 'CLIENT' | 'SUPPORT'
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;

  const SupportTicketModel({
    required this.id,
    required this.ticketNumber,
    required this.clientId,
    required this.clientName,
    this.clientEmail,
    required this.category,
    required this.subject,
    required this.description,
    this.attachmentUrl,
    this.attachmentName,
    this.bookingId,
    this.bookingReference,
    this.status = SupportTicketStatus.submitted,
    this.lastMessage,
    this.lastMessageSender,
    this.createdAt,
    this.updatedAt,
    this.resolvedAt,
    this.closedAt,
  });

  bool get isActive =>
      status == SupportTicketStatus.submitted ||
      status == SupportTicketStatus.underReview ||
      status == SupportTicketStatus.inProgress;

  bool get isClosed => status == SupportTicketStatus.closed;

  bool get isResolved => status == SupportTicketStatus.resolved;

  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;

  bool get hasRelatedBooking => bookingReference != null && bookingReference!.isNotEmpty;

  String get formattedDate {
    if (createdAt == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${createdAt!.day} ${months[createdAt!.month - 1]} ${createdAt!.year}';
  }

  String get formattedTime {
    if (createdAt == null) return '';
    final h = createdAt!.hour > 12 ? createdAt!.hour - 12 : (createdAt!.hour == 0 ? 12 : createdAt!.hour);
    final m = createdAt!.minute.toString().padLeft(2, '0');
    final period = createdAt!.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  SupportTicketModel copyWith({
    String? id,
    String? ticketNumber,
    String? clientId,
    String? clientName,
    String? clientEmail,
    SupportTicketCategory? category,
    String? subject,
    String? description,
    String? attachmentUrl,
    String? attachmentName,
    String? bookingId,
    String? bookingReference,
    SupportTicketStatus? status,
    String? lastMessage,
    String? lastMessageSender,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    DateTime? closedAt,
  }) {
    return SupportTicketModel(
      id: id ?? this.id,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientEmail: clientEmail ?? this.clientEmail,
      category: category ?? this.category,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentName: attachmentName ?? this.attachmentName,
      bookingId: bookingId ?? this.bookingId,
      bookingReference: bookingReference ?? this.bookingReference,
      status: status ?? this.status,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSender: lastMessageSender ?? this.lastMessageSender,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ticketNumber': ticketNumber,
      'clientId': clientId,
      'clientName': clientName,
      'clientEmail': clientEmail,
      'category': category.firestoreValue,
      'subject': subject,
      'description': description,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'bookingId': bookingId,
      'bookingReference': bookingReference,
      'status': status.firestoreValue,
      'lastMessage': lastMessage ?? description,
      'lastMessageSender': lastMessageSender ?? 'CLIENT',
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'closedAt': closedAt != null ? Timestamp.fromDate(closedAt!) : null,
    };
  }

  factory SupportTicketModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    return SupportTicketModel(
      id: id,
      ticketNumber: map['ticketNumber'] as String? ?? 'TKT-${id.substring(0, id.length > 6 ? 6 : id.length).toUpperCase()}',
      clientId: map['clientId'] as String? ?? '',
      clientName: map['clientName'] as String? ?? 'Athlete',
      clientEmail: map['clientEmail'] as String?,
      category: SupportTicketCategory.fromString(map['category'] as String?),
      subject: map['subject'] as String? ?? '',
      description: map['description'] as String? ?? '',
      attachmentUrl: map['attachmentUrl'] as String?,
      attachmentName: map['attachmentName'] as String?,
      bookingId: map['bookingId'] as String?,
      bookingReference: map['bookingReference'] as String?,
      status: SupportTicketStatus.fromString(map['status'] as String?),
      lastMessage: map['lastMessage'] as String? ?? map['description'] as String?,
      lastMessageSender: map['lastMessageSender'] as String?,
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
      resolvedAt: parseTimestamp(map['resolvedAt']),
      closedAt: parseTimestamp(map['closedAt']),
    );
  }

  factory SupportTicketModel.fromDocument(DocumentSnapshot doc) {
    return SupportTicketModel.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      id: doc.id,
    );
  }
}

/// A structured message or follow-up within a support ticket conversation
class SupportMessageModel {
  final String id;
  final String ticketId;
  final String senderId;
  final String senderType; // 'CLIENT' | 'SUPPORT'
  final String senderName;
  final String message;
  final String? attachmentUrl;
  final String? attachmentName;
  final DateTime? createdAt;
  final bool isRead;

  const SupportMessageModel({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.senderType,
    required this.senderName,
    required this.message,
    this.attachmentUrl,
    this.attachmentName,
    this.createdAt,
    this.isRead = false,
  });

  bool get isClient => senderType == 'CLIENT';
  bool get isSupport => senderType == 'SUPPORT';

  String get formattedTime {
    if (createdAt == null) return '';
    final h = createdAt!.hour > 12 ? createdAt!.hour - 12 : (createdAt!.hour == 0 ? 12 : createdAt!.hour);
    final m = createdAt!.minute.toString().padLeft(2, '0');
    final period = createdAt!.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }

  String get formattedDate {
    if (createdAt == null) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${createdAt!.day} ${months[createdAt!.month - 1]}';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ticketId': ticketId,
      'senderId': senderId,
      'senderType': senderType,
      'senderName': senderName,
      'message': message,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'isRead': isRead,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory SupportMessageModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    return SupportMessageModel(
      id: id,
      ticketId: map['ticketId'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      senderType: map['senderType'] as String? ?? 'CLIENT',
      senderName: map['senderName'] as String? ?? (map['senderType'] == 'SUPPORT' ? 'TRAIN Z Support' : 'Athlete'),
      message: map['message'] as String? ?? '',
      attachmentUrl: map['attachmentUrl'] as String?,
      attachmentName: map['attachmentName'] as String?,
      isRead: map['isRead'] as bool? ?? false,
      createdAt: parseTimestamp(map['createdAt']),
    );
  }

  factory SupportMessageModel.fromDocument(DocumentSnapshot doc) {
    return SupportMessageModel.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      id: doc.id,
    );
  }
}
