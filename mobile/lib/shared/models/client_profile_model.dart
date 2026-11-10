import 'package:cloud_firestore/cloud_firestore.dart';

class ClientProfileModel {
  final String uid;
  final List<String> fitnessGoals;
  final String? fitnessLevel; // Beginner, Intermediate, Advanced
  final List<String> preferredTrainingTypes; // Strength, HIIT, Calisthenics, Yoga, Boxing
  final List<String> fitnessInterests; // Core Strength, Posture, Nutrition, Recovery
  final DateTime? dateOfBirth;
  final String? preferredCityId;
  final String? preferredTrainingLocation; // Home Gym, Commercial Gym, Outdoor Park, Trainer Studio
  final String? privateAddress; // Kept private, never shown publicly
  final String? activePackageId;
  final String? emergencyContact;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ClientProfileModel({
    required this.uid,
    this.fitnessGoals = const [],
    this.fitnessLevel,
    this.preferredTrainingTypes = const [],
    this.fitnessInterests = const [],
    this.dateOfBirth,
    this.preferredCityId,
    this.preferredTrainingLocation,
    this.privateAddress,
    this.activePackageId,
    this.emergencyContact,
    this.createdAt,
    this.updatedAt,
  });

  /// Computes profile completion score (0 to 100%)
  int calculateCompletion({
    required bool hasName,
    required bool hasPhone,
    required bool hasPhoto,
    required bool hasGender,
  }) {
    int score = 0;
    if (hasName) score += 15;
    if (hasPhone) score += 15;
    if (hasGender) score += 10;
    if (hasPhoto) score += 15;
    if (dateOfBirth != null) score += 10;
    if (fitnessGoals.isNotEmpty && fitnessLevel != null) score += 15;
    if (preferredTrainingTypes.isNotEmpty) score += 10;
    if (preferredCityId != null && preferredCityId!.isNotEmpty) score += 10;
    return score.clamp(0, 100);
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fitnessGoals': fitnessGoals,
      'fitnessLevel': fitnessLevel,
      'preferredTrainingTypes': preferredTrainingTypes,
      'fitnessInterests': fitnessInterests,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'preferredCityId': preferredCityId,
      'preferredTrainingLocation': preferredTrainingLocation,
      'privateAddress': privateAddress,
      'activePackageId': activePackageId,
      'emergencyContact': emergencyContact,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory ClientProfileModel.fromMap(Map<String, dynamic> map, {required String uid}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return ClientProfileModel(
      uid: uid,
      fitnessGoals: (map['fitnessGoals'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      fitnessLevel: map['fitnessLevel'] as String?,
      preferredTrainingTypes: (map['preferredTrainingTypes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      fitnessInterests: (map['fitnessInterests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      dateOfBirth: parseTimestamp(map['dateOfBirth']),
      preferredCityId: map['preferredCityId'] as String?,
      preferredTrainingLocation: map['preferredTrainingLocation'] as String?,
      privateAddress: map['privateAddress'] as String?,
      activePackageId: map['activePackageId'] as String?,
      emergencyContact: map['emergencyContact'] as String?,
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
    );
  }

  factory ClientProfileModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ClientProfileModel.fromMap(data, uid: doc.id);
  }

  ClientProfileModel copyWith({
    List<String>? fitnessGoals,
    String? fitnessLevel,
    List<String>? preferredTrainingTypes,
    List<String>? fitnessInterests,
    DateTime? dateOfBirth,
    String? preferredCityId,
    String? preferredTrainingLocation,
    String? privateAddress,
    String? activePackageId,
    String? emergencyContact,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClientProfileModel(
      uid: uid,
      fitnessGoals: fitnessGoals ?? this.fitnessGoals,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      preferredTrainingTypes: preferredTrainingTypes ?? this.preferredTrainingTypes,
      fitnessInterests: fitnessInterests ?? this.fitnessInterests,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      preferredCityId: preferredCityId ?? this.preferredCityId,
      preferredTrainingLocation: preferredTrainingLocation ?? this.preferredTrainingLocation,
      privateAddress: privateAddress ?? this.privateAddress,
      activePackageId: activePackageId ?? this.activePackageId,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
