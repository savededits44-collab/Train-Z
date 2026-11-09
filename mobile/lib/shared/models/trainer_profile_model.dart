import 'package:cloud_firestore/cloud_firestore.dart';

enum TrainerVerificationStatus {
  pending,
  approved,
  rejected,
  suspended;

  String toFirestore() => name.toUpperCase();

  static TrainerVerificationStatus fromFirestore(dynamic val) {
    if (val == null) return TrainerVerificationStatus.pending;
    final str = val.toString().trim().toUpperCase();
    for (final s in TrainerVerificationStatus.values) {
      if (s.name.toUpperCase() == str) return s;
    }
    return TrainerVerificationStatus.pending;
  }
}

class TrainerProfileModel {
  final String uid;
  final String? bio;
  final List<String> specialties;
  final int experienceYears;
  final String? cityId;
  final int hourlyRate; // in INR
  final TrainerVerificationStatus verificationStatus;
  final List<String> verificationDocuments;
  final List<String> certificationDocuments;
  final String? adminReviewNotes;
  final DateTime? approvedAt;
  final String? approvedBy; // Admin UID
  final bool isActive;
  final double ratingAvg;
  final int totalReviews;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TrainerProfileModel({
    required this.uid,
    this.bio,
    this.specialties = const [],
    this.experienceYears = 0,
    this.cityId,
    this.hourlyRate = 500,
    this.verificationStatus = TrainerVerificationStatus.pending,
    this.verificationDocuments = const [],
    this.certificationDocuments = const [],
    this.adminReviewNotes,
    this.approvedAt,
    this.approvedBy,
    this.isActive = true,
    this.ratingAvg = 5.0,
    this.totalReviews = 0,
    this.createdAt,
    this.updatedAt,
  });

  bool get isApproved => verificationStatus == TrainerVerificationStatus.approved;
  bool get canBeBooked => isApproved && isActive;

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'bio': bio,
      'specialties': specialties,
      'experienceYears': experienceYears,
      'cityId': cityId,
      'hourlyRate': hourlyRate,
      'verificationStatus': verificationStatus.toFirestore(),
      'verificationDocuments': verificationDocuments,
      'certificationDocuments': certificationDocuments,
      'adminReviewNotes': adminReviewNotes,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'isActive': isActive,
      'ratingAvg': ratingAvg,
      'totalReviews': totalReviews,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory TrainerProfileModel.fromMap(Map<String, dynamic> map, {required String uid}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return TrainerProfileModel(
      uid: uid,
      bio: map['bio'] as String?,
      specialties: (map['specialties'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      experienceYears: (map['experienceYears'] as num?)?.toInt() ?? 0,
      cityId: map['cityId'] as String?,
      hourlyRate: (map['hourlyRate'] as num?)?.toInt() ?? 500,
      verificationStatus: TrainerVerificationStatus.fromFirestore(map['verificationStatus']),
      verificationDocuments: (map['verificationDocuments'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      certificationDocuments: (map['certificationDocuments'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      adminReviewNotes: map['adminReviewNotes'] as String?,
      approvedAt: parseTimestamp(map['approvedAt']),
      approvedBy: map['approvedBy'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      ratingAvg: (map['ratingAvg'] as num?)?.toDouble() ?? 5.0,
      totalReviews: (map['totalReviews'] as num?)?.toInt() ?? 0,
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
    );
  }

  factory TrainerProfileModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TrainerProfileModel.fromMap(data, uid: doc.id);
  }
}

