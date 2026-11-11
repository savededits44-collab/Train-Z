import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an active or completed training package purchased by a client and assigned to a trainer.
class PurchasedPackageModel {
  final String id;
  final String clientId;
  final String clientName;
  final String? clientPhotoUrl;
  final String? clientPhone;
  final String trainerId;
  final String trainerName;
  final String? trainerPhotoUrl;
  final String packageId; // e.g. 'plan_30_days', 'plan_3_months'
  final String packageName; // e.g. 'Monthly Transformation (30 Days)'
  final int price; // in INR
  final DateTime purchaseDate;
  final DateTime startDate;
  final DateTime expiryDate;
  final int totalDays;
  final int totalSessions;
  final int completedSessions;
  final String paymentStatus; // 'COMPLETED', 'PENDING', 'FAILED'
  final String? paymentTransactionId;
  final String status; // 'ACTIVE', 'EXPIRING_SOON', 'EXPIRED', 'COMPLETED'
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PurchasedPackageModel({
    required this.id,
    required this.clientId,
    required this.clientName,
    this.clientPhotoUrl,
    this.clientPhone,
    required this.trainerId,
    required this.trainerName,
    this.trainerPhotoUrl,
    required this.packageId,
    required this.packageName,
    required this.price,
    required this.purchaseDate,
    required this.startDate,
    required this.expiryDate,
    required this.totalDays,
    required this.totalSessions,
    this.completedSessions = 0,
    this.paymentStatus = 'COMPLETED',
    this.paymentTransactionId,
    this.status = 'ACTIVE',
    this.createdAt,
    this.updatedAt,
  });

  /// ── Date-Derived Progress & Remaining Calculations ──────────────────────────

  /// Days elapsed since package start date, calculated using actual calendar days
  int get completedDays {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    if (today.isBefore(start)) return 0;
    final diff = today.difference(start).inDays;
    return diff.clamp(0, totalDays);
  }

  /// Remaining days until package expiry date, calculated using actual calendar dates
  int get remainingDays {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final diff = expiry.difference(today).inDays;
    return diff.clamp(0, totalDays);
  }

  /// Remaining workout sessions
  int get remainingSessions {
    final left = totalSessions - completedSessions;
    return left > 0 ? left : 0;
  }

  /// Days fraction string: e.g. "3/30 Days", "27/30 Days Left"
  String get daysCompletedFraction => '$completedDays/$totalDays Days';
  String get daysRemainingFraction => '$remainingDays/$totalDays Days Left';

  /// Sessions fraction string: e.g. "4/12 Sessions", "8/12 Sessions Left"
  String get sessionsCompletedFraction => '$completedSessions/$totalSessions Sessions';
  String get sessionsRemainingFraction => '$remainingSessions/$totalSessions Sessions Left';

  /// Visual progress fraction (0.0 to 1.0)
  double get daysProgress {
    if (totalDays <= 0) return 0.0;
    return (completedDays / totalDays).clamp(0.0, 1.0);
  }

  double get sessionsProgress {
    if (totalSessions <= 0) return 0.0;
    return (completedSessions / totalSessions).clamp(0.0, 1.0);
  }

  /// Status indicators:
  /// - Green: Plenty of days remaining (> 10 days)
  /// - Orange: Package nearing expiry (<= 10 days)
  /// - Red: Package expiring soon (<= 3 days) or expired
  String get healthStatus {
    if (remainingDays <= 3 || remainingSessions <= 1) return 'red';
    if (remainingDays <= 10 || (totalDays > 0 && remainingDays / totalDays <= 0.25)) return 'orange';
    return 'green';
  }

  bool get isExpired => remainingDays <= 0 || status == 'EXPIRED';

  PurchasedPackageModel copyWith({
    String? id,
    String? clientId,
    String? clientName,
    String? clientPhotoUrl,
    String? clientPhone,
    String? trainerId,
    String? trainerName,
    String? trainerPhotoUrl,
    String? packageId,
    String? packageName,
    int? price,
    DateTime? purchaseDate,
    DateTime? startDate,
    DateTime? expiryDate,
    int? totalDays,
    int? totalSessions,
    int? completedSessions,
    String? paymentStatus,
    String? paymentTransactionId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PurchasedPackageModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      clientName: clientName ?? this.clientName,
      clientPhotoUrl: clientPhotoUrl ?? this.clientPhotoUrl,
      clientPhone: clientPhone ?? this.clientPhone,
      trainerId: trainerId ?? this.trainerId,
      trainerName: trainerName ?? this.trainerName,
      trainerPhotoUrl: trainerPhotoUrl ?? this.trainerPhotoUrl,
      packageId: packageId ?? this.packageId,
      packageName: packageName ?? this.packageName,
      price: price ?? this.price,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      startDate: startDate ?? this.startDate,
      expiryDate: expiryDate ?? this.expiryDate,
      totalDays: totalDays ?? this.totalDays,
      totalSessions: totalSessions ?? this.totalSessions,
      completedSessions: completedSessions ?? this.completedSessions,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentTransactionId: paymentTransactionId ?? this.paymentTransactionId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'clientName': clientName,
      'clientPhotoUrl': clientPhotoUrl,
      'clientPhone': clientPhone,
      'trainerId': trainerId,
      'trainerName': trainerName,
      'trainerPhotoUrl': trainerPhotoUrl,
      'packageId': packageId,
      'packageName': packageName,
      'price': price,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'startDate': Timestamp.fromDate(startDate),
      'expiryDate': Timestamp.fromDate(expiryDate),
      'totalDays': totalDays,
      'totalSessions': totalSessions,
      'completedSessions': completedSessions,
      'paymentStatus': paymentStatus,
      'paymentTransactionId': paymentTransactionId,
      'status': status,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory PurchasedPackageModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    final now = DateTime.now();
    return PurchasedPackageModel(
      id: id,
      clientId: map['clientId'] as String? ?? '',
      clientName: map['clientName'] as String? ?? 'Athlete',
      clientPhotoUrl: map['clientPhotoUrl'] as String?,
      clientPhone: map['clientPhone'] as String?,
      trainerId: map['trainerId'] as String? ?? '',
      trainerName: map['trainerName'] as String? ?? 'Coach',
      trainerPhotoUrl: map['trainerPhotoUrl'] as String?,
      packageId: map['packageId'] as String? ?? 'plan_30_days',
      packageName: map['packageName'] as String? ?? 'Training Package',
      price: (map['price'] as num?)?.toInt() ?? 0,
      purchaseDate: parseDate(map['purchaseDate'], now),
      startDate: parseDate(map['startDate'], now),
      expiryDate: parseDate(map['expiryDate'], now.add(const Duration(days: 30))),
      totalDays: (map['totalDays'] as num?)?.toInt() ?? 30,
      totalSessions: (map['totalSessions'] as num?)?.toInt() ?? 26,
      completedSessions: (map['completedSessions'] as num?)?.toInt() ?? 0,
      paymentStatus: map['paymentStatus'] as String? ?? 'COMPLETED',
      paymentTransactionId: map['paymentTransactionId'] as String?,
      status: map['status'] as String? ?? 'ACTIVE',
      createdAt: map['createdAt'] is Timestamp ? (map['createdAt'] as Timestamp).toDate() : null,
      updatedAt: map['updatedAt'] is Timestamp ? (map['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  factory PurchasedPackageModel.fromDocument(DocumentSnapshot doc) {
    return PurchasedPackageModel.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      id: doc.id,
    );
  }
}
