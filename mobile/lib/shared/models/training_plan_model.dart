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

  /// Price per individual session
  double get pricePerSession => sessionsCount > 0 ? price / sessionsCount : 0.0;

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

  factory TrainingPlanModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TrainingPlanModel.fromMap(data, id: doc.id);
  }
}

