import 'package:cloud_firestore/cloud_firestore.dart';

class ClientProfileModel {
  final String uid;
  final List<String> fitnessGoals;
  final String? fitnessLevel; // Beginner, Intermediate, Advanced
  final DateTime? dateOfBirth;
  final String? preferredCityId;
  final String? activePackageId;
  final String? emergencyContact;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ClientProfileModel({
    required this.uid,
    this.fitnessGoals = const [],
    this.fitnessLevel,
    this.dateOfBirth,
    this.preferredCityId,
    this.activePackageId,
    this.emergencyContact,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fitnessGoals': fitnessGoals,
      'fitnessLevel': fitnessLevel,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'preferredCityId': preferredCityId,
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
      dateOfBirth: parseTimestamp(map['dateOfBirth']),
      preferredCityId: map['preferredCityId'] as String?,
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
}

