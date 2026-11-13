import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus {
  initiated,
  pending,
  completed,
  success,
  failed,
  cancelled,
  refunded;

  String toFirestore() {
    switch (this) {
      case PaymentStatus.initiated:
        return 'INITIATED';
      case PaymentStatus.pending:
        return 'PENDING';
      case PaymentStatus.completed:
        return 'COMPLETED';
      case PaymentStatus.success:
        return 'SUCCESS';
      case PaymentStatus.failed:
        return 'FAILED';
      case PaymentStatus.cancelled:
        return 'CANCELLED';
      case PaymentStatus.refunded:
        return 'REFUNDED';
    }
  }

  static PaymentStatus fromFirestore(dynamic val) {
    if (val == null) return PaymentStatus.initiated;
    final str = val.toString().trim().toUpperCase();
    for (final s in PaymentStatus.values) {
      if (s.toFirestore() == str || s.name.toUpperCase() == str) return s;
    }
    return PaymentStatus.initiated;
  }
}

class PaymentModel {
  final String id;
  final String? paymentIntentId;
  final String clientId;
  final String planId;
  final String? packageId;
  final String? packageName;
  final int? sessionsCount;
  final int? validityDays;
  final int amount; // in INR
  final String currency; // 'INR'
  final PaymentStatus status;
  final String? paymentMethod;
  final String? gatewayOrderId;
  final String? razorpayPaymentId;
  final String? razorpaySignature;
  final String? receiptNumber;
  final String? bookingId;
  final String? trainerId;
  final String? trainerName;
  final bool creditsGranted;
  final String? errorMessage;
  final String? invoiceId;
  final String? purchasedPackageId;
  final DateTime? verifiedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PaymentModel({
    required this.id,
    this.paymentIntentId,
    required this.clientId,
    required this.planId,
    this.packageId,
    this.packageName,
    this.sessionsCount,
    this.validityDays,
    required this.amount,
    this.currency = 'INR',
    this.status = PaymentStatus.initiated,
    this.paymentMethod,
    this.gatewayOrderId,
    this.razorpayPaymentId,
    this.razorpaySignature,
    this.receiptNumber,
    this.bookingId,
    this.trainerId,
    this.trainerName,
    this.creditsGranted = false,
    this.errorMessage,
    this.invoiceId,
    this.purchasedPackageId,
    this.verifiedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isSuccess => status == PaymentStatus.success;
  bool get isFailed => status == PaymentStatus.failed || status == PaymentStatus.cancelled;
  bool get isInitiated => status == PaymentStatus.initiated;

  String get displayAmount => '₹$amount';
  String get displayPackageName =>
      (packageName != null && packageName!.isNotEmpty) ? packageName! : planId;
  String get displayReceiptNumber =>
      (receiptNumber != null && receiptNumber!.isNotEmpty)
          ? receiptNumber!
          : 'REC-${id.length >= 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase()}';

  PaymentModel copyWith({
    String? id,
    String? paymentIntentId,
    String? clientId,
    String? planId,
    String? packageId,
    String? packageName,
    int? sessionsCount,
    int? validityDays,
    int? amount,
    String? currency,
    PaymentStatus? status,
    String? paymentMethod,
    String? gatewayOrderId,
    String? razorpayPaymentId,
    String? razorpaySignature,
    String? receiptNumber,
    String? bookingId,
    String? trainerId,
    String? trainerName,
    bool? creditsGranted,
    String? errorMessage,
    String? invoiceId,
    String? purchasedPackageId,
    DateTime? verifiedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PaymentModel(
      id: id ?? this.id,
      paymentIntentId: paymentIntentId ?? this.paymentIntentId,
      clientId: clientId ?? this.clientId,
      planId: planId ?? this.planId,
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      sessionsCount: sessionsCount ?? this.sessionsCount,
      validityDays: validityDays ?? this.validityDays,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      gatewayOrderId: gatewayOrderId ?? this.gatewayOrderId,
      razorpayPaymentId: razorpayPaymentId ?? this.razorpayPaymentId,
      razorpaySignature: razorpaySignature ?? this.razorpaySignature,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      bookingId: bookingId ?? this.bookingId,
      trainerId: trainerId ?? this.trainerId,
      trainerName: trainerName ?? this.trainerName,
      creditsGranted: creditsGranted ?? this.creditsGranted,
      errorMessage: errorMessage ?? this.errorMessage,
      invoiceId: invoiceId ?? this.invoiceId,
      purchasedPackageId: purchasedPackageId ?? this.purchasedPackageId,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'paymentIntentId': paymentIntentId,
      'clientId': clientId,
      'planId': planId,
      'packageId': packageId ?? planId,
      'packageName': packageName,
      'sessionsCount': sessionsCount,
      'validityDays': validityDays,
      'amount': amount,
      'currency': currency,
      'status': status.toFirestore(),
      'paymentMethod': paymentMethod,
      'gatewayOrderId': gatewayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpaySignature': razorpaySignature,
      'receiptNumber': receiptNumber,
      'bookingId': bookingId,
      'trainerId': trainerId,
      'trainerName': trainerName,
      'creditsGranted': creditsGranted,
      'errorMessage': errorMessage,
      'invoiceId': invoiceId,
      'purchasedPackageId': purchasedPackageId,
      'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory PaymentModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return PaymentModel(
      id: id,
      paymentIntentId: map['paymentIntentId'] as String?,
      clientId: map['clientId'] as String? ?? '',
      planId: map['planId'] as String? ?? map['packageId'] as String? ?? '',
      packageId: map['packageId'] as String? ?? map['planId'] as String?,
      packageName: map['packageName'] as String?,
      sessionsCount: (map['sessionsCount'] as num?)?.toInt(),
      validityDays: (map['validityDays'] as num?)?.toInt(),
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      currency: map['currency'] as String? ?? 'INR',
      status: PaymentStatus.fromFirestore(map['status']),
      paymentMethod: map['paymentMethod'] as String?,
      gatewayOrderId: map['gatewayOrderId'] as String?,
      razorpayPaymentId: map['razorpayPaymentId'] as String?,
      razorpaySignature: map['razorpaySignature'] as String?,
      receiptNumber: map['receiptNumber'] as String?,
      bookingId: map['bookingId'] as String?,
      trainerId: map['trainerId'] as String?,
      trainerName: map['trainerName'] as String?,
      creditsGranted: map['creditsGranted'] as bool? ?? false,
      errorMessage: map['errorMessage'] as String?,
      invoiceId: map['invoiceId'] as String?,
      purchasedPackageId: map['purchasedPackageId'] as String?,
      verifiedAt: parseTimestamp(map['verifiedAt']),
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
    );
  }

  factory PaymentModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PaymentModel.fromMap(data, id: doc.id);
  }
}
