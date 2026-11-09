import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus {
  initiated,
  success,
  failed,
  refunded;

  String toFirestore() => name.toUpperCase();

  static PaymentStatus fromFirestore(dynamic val) {
    if (val == null) return PaymentStatus.initiated;
    final str = val.toString().trim().toUpperCase();
    for (final s in PaymentStatus.values) {
      if (s.name.toUpperCase() == str) return s;
    }
    return PaymentStatus.initiated;
  }
}

class PaymentModel {
  final String id;
  final String? paymentIntentId;
  final String clientId;
  final String planId;
  final int amount; // in INR
  final String currency; // 'INR'
  final PaymentStatus status;
  final String? paymentMethod;
  final String? gatewayOrderId;
  final String? invoiceId;
  final DateTime? createdAt;

  const PaymentModel({
    required this.id,
    this.paymentIntentId,
    required this.clientId,
    required this.planId,
    required this.amount,
    this.currency = 'INR',
    this.status = PaymentStatus.initiated,
    this.paymentMethod,
    this.gatewayOrderId,
    this.invoiceId,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'paymentIntentId': paymentIntentId,
      'clientId': clientId,
      'planId': planId,
      'amount': amount,
      'currency': currency,
      'status': status.toFirestore(),
      'paymentMethod': paymentMethod,
      'gatewayOrderId': gatewayOrderId,
      'invoiceId': invoiceId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
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
      planId: map['planId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      currency: map['currency'] as String? ?? 'INR',
      status: PaymentStatus.fromFirestore(map['status']),
      paymentMethod: map['paymentMethod'] as String?,
      gatewayOrderId: map['gatewayOrderId'] as String?,
      invoiceId: map['invoiceId'] as String?,
      createdAt: parseTimestamp(map['createdAt']),
    );
  }

  factory PaymentModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PaymentModel.fromMap(data, id: doc.id);
  }
}

