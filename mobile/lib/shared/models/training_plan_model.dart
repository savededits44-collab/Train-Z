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
  final String? trainerId; // null or empty for platform-controlled fixed packages
  final String? trainerName;
  final bool isApproved; // Platform plans are pre-approved; custom plans require Admin approval
  final bool isCustom;
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
    this.trainerId,
    this.trainerName,
    this.isApproved = true,
    this.isCustom = false,
    this.createdAt,
  });

  /// Single session base rate in INR
  static const int singleSessionRate = 500;

  /// Price per individual session
  double get pricePerSession => sessionsCount > 0 ? price / sessionsCount : 0.0;

  /// Formatted price with standard Indian thousands separator (e.g. ₹500, ₹1,399, ₹10,799, ₹52,999)
  String get formattedPrice => formatPrice(price);

  /// Helper to format currency in INR with commas
  static String formatPrice(int amount) {
    final str = amount.toString();
    if (str.length <= 3) return '₹$str';
    final lastThree = str.substring(str.length - 3);
    var remaining = str.substring(0, str.length - 3);
    final chunks = <String>[];
    while (remaining.length > 2) {
      chunks.insert(0, remaining.substring(remaining.length - 2));
      remaining = remaining.substring(0, remaining.length - 2);
    }
    if (remaining.isNotEmpty) {
      chunks.insert(0, remaining);
    }
    return '₹${chunks.join(',')},$lastThree';
  }

  /// Total standard cost if booked as single sessions
  int get standardTotalCost => sessionsCount * singleSessionRate;

  /// Total savings compared to booking single sessions
  int get totalSavings => (standardTotalCost - price).clamp(0, 100000);

  /// Percentage saved vs single session rate
  int get savingsPercent {
    if (sessionsCount <= 1 || standardTotalCost <= 0) return 0;
    return (((standardTotalCost - price) / standardTotalCost) * 100).round().clamp(0, 100);
  }

  /// Whether this is a platform-wide package (standard trainer) or custom trainer plan
  bool get isPlatformPackage => trainerId == null || trainerId!.trim().isEmpty;

  /// Human-readable package type badge
  String get packageTypeLabel =>
      isCustom ? 'Advanced Trainer Custom Plan' : 'TRAIN Z Platform Package';

  /// Whether this is the flagship 6-Month Transformation package
  bool get isTransformationPackage =>
      id == 'plan_6_months' ||
      title.toLowerCase().contains('6-month') ||
      sessionsCount >= 150;

  /// The six official predefined TRAIN Z packages with platform-controlled pricing, sessions and validity
  static const List<TrainingPlanModel> platformPackages = [
    TrainingPlanModel(
      id: 'plan_1_day',
      title: '1 Day',
      price: 500,
      sessionsCount: 1,
      validityDays: 1,
      sessionDurationMinutes: 60,
      description: 'Single 60-min personal training session to jumpstart your fitness journey.',
      popular: false,
      isActive: true,
      isApproved: true,
      isCustom: false,
    ),
    TrainingPlanModel(
      id: 'plan_3_days',
      title: '3 Days',
      price: 1399,
      sessionsCount: 3,
      validityDays: 3,
      sessionDurationMinutes: 60,
      description: '3 dedicated 1-on-1 sessions for form correction and target routines.',
      popular: false,
      isActive: true,
      isApproved: true,
      isCustom: false,
    ),
    TrainingPlanModel(
      id: 'plan_1_week',
      title: '1 Week',
      price: 2799,
      sessionsCount: 6,
      validityDays: 7,
      sessionDurationMinutes: 60,
      description: '6 intensive sessions across 7 days for rapid momentum and consistency.',
      popular: false,
      isActive: true,
      isApproved: true,
      isCustom: false,
    ),
    TrainingPlanModel(
      id: 'plan_1_month',
      title: '1 Month',
      price: 10799,
      sessionsCount: 26,
      validityDays: 30,
      sessionDurationMinutes: 60,
      description: '26 sessions designed for comprehensive monthly body recomp and habit mastery.',
      popular: true,
      isActive: true,
      isApproved: true,
      isCustom: false,
    ),
    TrainingPlanModel(
      id: 'plan_3_months',
      title: '3 Months',
      price: 29999,
      sessionsCount: 78,
      validityDays: 90,
      sessionDurationMinutes: 60,
      description: '78 sessions over a full quarter for substantial muscle gain and fat loss.',
      popular: false,
      isActive: true,
      isApproved: true,
      isCustom: false,
    ),
    TrainingPlanModel(
      id: 'plan_6_months',
      title: '6-Month Transformation',
      price: 52999,
      sessionsCount: 150,
      validityDays: 180,
      sessionDurationMinutes: 60,
      description: '150 sessions for complete physical and lifestyle transformation with elite trainers.',
      popular: false,
      isActive: true,
      isApproved: true,
      isCustom: false,
    ),
  ];

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
      'trainerId': trainerId,
      'trainerName': trainerName,
      'isApproved': isApproved,
      'isCustom': isCustom,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory TrainingPlanModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final tId = map['trainerId'] as String?;
    final hasTrainer = tId != null && tId.trim().isNotEmpty;
    final isCustomVal = (map['isCustom'] as bool?) ?? hasTrainer;

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
      trainerId: tId,
      trainerName: map['trainerName'] as String?,
      isApproved: (map['isApproved'] as bool?) ?? !hasTrainer, // Platform plans are approved by default
      isCustom: isCustomVal,
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
    String? trainerId,
    String? trainerName,
    bool? isApproved,
    bool? isCustom,
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
      trainerId: trainerId ?? this.trainerId,
      trainerName: trainerName ?? this.trainerName,
      isApproved: isApproved ?? this.isApproved,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory TrainingPlanModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TrainingPlanModel.fromMap(data, id: doc.id);
  }
}
