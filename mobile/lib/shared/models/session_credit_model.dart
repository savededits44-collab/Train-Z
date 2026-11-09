import 'package:cloud_firestore/cloud_firestore.dart';

enum CreditTransactionType {
  purchase,
  reserve,
  consume,
  returnCredit,
  forfeit;

  String toFirestore() {
    switch (this) {
      case CreditTransactionType.purchase:
        return 'PURCHASE';
      case CreditTransactionType.reserve:
        return 'RESERVE';
      case CreditTransactionType.consume:
        return 'CONSUME';
      case CreditTransactionType.returnCredit:
        return 'RETURN';
      case CreditTransactionType.forfeit:
        return 'FORFEIT';
    }
  }

  static CreditTransactionType fromFirestore(dynamic val) {
    if (val == null) return CreditTransactionType.purchase;
    final str = val.toString().trim().toUpperCase();
    if (str == 'RESERVE') return CreditTransactionType.reserve;
    if (str == 'CONSUME') return CreditTransactionType.consume;
    if (str == 'RETURN') return CreditTransactionType.returnCredit;
    if (str == 'FORFEIT') return CreditTransactionType.forfeit;
    return CreditTransactionType.purchase;
  }
}

class SessionCreditModel {
  final String clientId;
  final int totalPurchased;
  final int totalReserved;
  final int totalConsumed;
  final int totalReturned;
  final int totalForfeited;
  final int availableBalance;
  final DateTime? lastUpdated;

  const SessionCreditModel({
    required this.clientId,
    this.totalPurchased = 0,
    this.totalReserved = 0,
    this.totalConsumed = 0,
    this.totalReturned = 0,
    this.totalForfeited = 0,
    this.availableBalance = 0,
    this.lastUpdated,
  });

  /// Calculates real-time net available credit balance
  int get computedAvailable =>
      (totalPurchased + totalReturned) - (totalReserved + totalConsumed + totalForfeited);

  Map<String, dynamic> toMap() {
    return {
      'clientId': clientId,
      'totalPurchased': totalPurchased,
      'totalReserved': totalReserved,
      'totalConsumed': totalConsumed,
      'totalReturned': totalReturned,
      'totalForfeited': totalForfeited,
      'availableBalance': availableBalance,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  factory SessionCreditModel.fromMap(Map<String, dynamic> map, {required String clientId}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return SessionCreditModel(
      clientId: clientId,
      totalPurchased: (map['totalPurchased'] as num?)?.toInt() ?? 0,
      totalReserved: (map['totalReserved'] as num?)?.toInt() ?? 0,
      totalConsumed: (map['totalConsumed'] as num?)?.toInt() ?? 0,
      totalReturned: (map['totalReturned'] as num?)?.toInt() ?? 0,
      totalForfeited: (map['totalForfeited'] as num?)?.toInt() ?? 0,
      availableBalance: (map['availableBalance'] as num?)?.toInt() ?? 0,
      lastUpdated: parseTimestamp(map['lastUpdated']),
    );
  }

  factory SessionCreditModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SessionCreditModel.fromMap(data, clientId: doc.id);
  }
}

class CreditTransactionModel {
  final String id;
  final String clientId;
  final CreditTransactionType type;
  final int count;
  final String? bookingId;
  final String? paymentId;
  final String reason;
  final int balanceAfter;
  final DateTime? timestamp;

  const CreditTransactionModel({
    required this.id,
    required this.clientId,
    required this.type,
    required this.count,
    this.bookingId,
    this.paymentId,
    required this.reason,
    required this.balanceAfter,
    this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'type': type.toFirestore(),
      'count': count,
      'bookingId': bookingId,
      'paymentId': paymentId,
      'reason': reason,
      'balanceAfter': balanceAfter,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp(),
    };
  }

  factory CreditTransactionModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return CreditTransactionModel(
      id: id,
      clientId: map['clientId'] as String? ?? '',
      type: CreditTransactionType.fromFirestore(map['type']),
      count: (map['count'] as num?)?.toInt() ?? 1,
      bookingId: map['bookingId'] as String?,
      paymentId: map['paymentId'] as String?,
      reason: map['reason'] as String? ?? '',
      balanceAfter: (map['balanceAfter'] as num?)?.toInt() ?? 0,
      timestamp: parseTimestamp(map['timestamp']),
    );
  }

  factory CreditTransactionModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CreditTransactionModel.fromMap(data, id: doc.id);
  }
}

