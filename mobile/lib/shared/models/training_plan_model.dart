import 'package:cloud_firestore/cloud_firestore.dart';

class TrainingPlanModel {
  final String id;
  final String title;
  final int price; // in INR (e.g. 500, 1399, 2799, 10799, 29999, 52999)
  final int sessionsCount; // 1, 3, 6, 26, 78, 150
  final int validityDays; // 1, 3, 7, 30, 90, 180
  final int sessionDurationMinutes; // 60
  final String description;
  final bool popular;
  final bool isActive;
  final DateTime? createdAt;

  const TrainingPlanModel({
    required this.id,
    required this.title,
    required this.price,
    required this.sessionsCount,
    required this.validityDays,
    this.sessionDurationMinutes = 60,
    required this.description,
    this.popular = false,
    this.isActive = true,
    this.createdAt,
  });

  /// Single session base rate in INR
  static const int singleSessionRate = 500;

  /// Price per individual session
  double get pricePerSession => sessionsCount > 0 ? price / sessionsCount : 0.0;

  /// Total standard cost if booked as single sessions
  int get standardTotalCost => sessionsCount * singleSessionRate;

  /// Total savings compared to booking single sessions
  int get totalSavings => (standardTotalCost - price).clamp(0, 100000);

  /// Percentage saved vs single session rate
  int get savingsPercent {
    if (sessionsCount <= 1 || standardTotalCost <= 0) return 0;
    return (((standardTotalCost - price) / standardTotalCost) * 100).round().clamp(0, 100);
  }

  /// Whether this is the flagship 6-Month Transformation package
  bool get isTransformationPackage =>
      id == 'plan_6_months' ||
      title.toLowerCase().contains('6-month') ||
      sessionsCount >= 150;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'price': price,
      'sessions': sessionsCount,
      'sessionsCount': sessionsCount,
      'validityDays': validityDays,
      'sessionDurationMinutes': sessionDurationMinutes,
      'description': description,
      'popular': popular,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory TrainingPlanModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return TrainingPlanModel(
      id: id,
      title: map['title'] as String? ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      sessionsCount: (map['sessionsCount'] as num?)?.toInt() ?? (map['sessions'] as num?)?.toInt() ?? 1,
      validityDays: (map['validityDays'] as num?)?.toInt() ?? 1,
      sessionDurationMinutes: (map['sessionDurationMinutes'] as num?)?.toInt() ?? 60,
      description: map['description'] as String? ?? '',
      popular: map['popular'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: parseTimestamp(map['createdAt']),
    );
  }

  TrainingPlanModel copyWith({
    String? id,
    String? title,
    int? price,
    int? sessionsCount,
    int? validityDays,
    int? sessionDurationMinutes,
    String? description,
    bool? popular,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return TrainingPlanModel(
      id: id ?? this.id,
      title: title ?? this.title,
      price: price ?? this.price,
      sessionsCount: sessionsCount ?? this.sessionsCount,
      validityDays: validityDays ?? this.validityDays,
      sessionDurationMinutes: sessionDurationMinutes ?? this.sessionDurationMinutes,
      description: description ?? this.description,
      popular: popular ?? this.popular,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory TrainingPlanModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TrainingPlanModel.fromMap(data, id: doc.id);
  }
}

