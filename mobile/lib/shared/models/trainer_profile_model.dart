import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

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

enum TrainerCategory {
  trainer,
  advancedTrainer,
  professionalTrainer;

  String toFirestore() {
    switch (this) {
      case TrainerCategory.trainer:
        return 'TRAINER';
      case TrainerCategory.advancedTrainer:
        return 'ADVANCED_TRAINER';
      case TrainerCategory.professionalTrainer:
        return 'PROFESSIONAL_TRAINER';
    }
  }

  static TrainerCategory fromFirestore(dynamic val) {
    if (val == null) return TrainerCategory.trainer;
    final str = val.toString().trim().toUpperCase();
    if (str == 'ADVANCED_TRAINER' || str == 'ADVANCED') {
      return TrainerCategory.advancedTrainer;
    }
    if (str == 'PROFESSIONAL_TRAINER' || str == 'PROFESSIONAL') {
      return TrainerCategory.professionalTrainer;
    }
    return TrainerCategory.trainer;
  }

  String get displayName {
    switch (this) {
      case TrainerCategory.trainer:
        return 'Trainer';
      case TrainerCategory.advancedTrainer:
        return 'Advanced Trainer';
      case TrainerCategory.professionalTrainer:
        return 'Professional Trainer';
    }
  }

  String get requirementText {
    switch (this) {
      case TrainerCategory.trainer:
        return 'Must have at least one beginner-level trainer certificate.';
      case TrainerCategory.advancedTrainer:
        return 'Must have relevant professional trainer qualifications & at least 3.5 years of experience.';
      case TrainerCategory.professionalTrainer:
        return 'Elite Master Coach credentials. Available in future platform release.';
    }
  }

  String get packageRuleText {
    switch (this) {
      case TrainerCategory.trainer:
        return 'Uses standard TRAIN Z platform packages.';
      case TrainerCategory.advancedTrainer:
        return 'Can create custom training plans and set independent session rates.';
      case TrainerCategory.professionalTrainer:
        return 'Custom enterprise training packages.';
    }
  }

  bool get isAvailableAtLaunch => this != TrainerCategory.professionalTrainer;
}

class TrainerProfileModel {
  final String uid;
  final String? bio;
  final List<String> specialties;
  final double experienceYears;
  final String? cityId;
  final int hourlyRate; // in INR
  final TrainerCategory category;
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

  // Profile fields
  final String? photoUrl;
  final String? dateOfBirth; // ISO string "YYYY-MM-DD", stored in users collection too
  final List<String> languages;
  final List<String> clientTypes;
  final List<String> trainingGoals;
  final List<String> trainingMethods;
  final String? trainingApproach;
  final String? professionalExperience;

  // Training service fields
  final bool trainsAtHome;
  final bool trainsAtGym;
  final List<String> otherTrainingLocations;
  final List<String> serviceAreas; // dynamic, NO hardcoded cities
  final List<String> workingDays; // e.g. ["MON","TUE","WED"]
  final String? workingHours; // e.g. "6:00 AM - 9:00 PM"

  // Profile completion
  final int profileCompletionScore; // 0-100

  const TrainerProfileModel({
    required this.uid,
    this.bio,
    this.specialties = const [],
    this.experienceYears = 0.0,
    this.cityId,
    this.hourlyRate = 500,
    this.category = TrainerCategory.trainer,
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
    // New fields
    this.photoUrl,
    this.dateOfBirth,
    this.languages = const [],
    this.clientTypes = const [],
    this.trainingGoals = const [],
    this.trainingMethods = const [],
    this.trainingApproach,
    this.professionalExperience,
    this.trainsAtHome = false,
    this.trainsAtGym = false,
    this.otherTrainingLocations = const [],
    this.serviceAreas = const [],
    this.workingDays = const [],
    this.workingHours,
    this.profileCompletionScore = 0,
  });

  bool get isApproved => verificationStatus == TrainerVerificationStatus.approved;
  bool get isPending => verificationStatus == TrainerVerificationStatus.pending;
  bool get isRejected => verificationStatus == TrainerVerificationStatus.rejected;
  bool get isSuspended => verificationStatus == TrainerVerificationStatus.suspended;
  bool get isAdvancedTrainer => category == TrainerCategory.advancedTrainer;
  bool get isStandardTrainer => category == TrainerCategory.trainer;
  bool get canBeBooked => isApproved && isActive;
  int get experienceYearsInt => experienceYears.floor();

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'bio': bio,
      'specialties': specialties,
      'experienceYears': experienceYears,
      'cityId': cityId,
      'hourlyRate': hourlyRate,
      'category': category.toFirestore(),
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
      experienceYears: (map['experienceYears'] as num?)?.toDouble() ?? 0.0,
      cityId: map['cityId'] as String?,
      hourlyRate: (map['hourlyRate'] as num?)?.toInt() ?? 500,
      category: TrainerCategory.fromFirestore(map['category']),
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

/// Aggregated display model for verified trainers rendered on Client Dashboard and Discovery screens
class TrainerDisplayModel {
  final TrainerProfileModel profile;
  final String uid;
  final String displayName;
  final String? photoUrl;
  final Gender gender;
  final String? email;
  final String? phoneNumber;
  final String? gymName;
  final List<String> specialties;
  final double experienceYears;
  final String? cityId;
  final String? serviceArea;
  final double ratingAvg;
  final int totalReviews;
  final int hourlyRate;
  final bool hasAvailableSlots;
  final List<String> trainingGoals;
  final List<String> certifications;

  const TrainerDisplayModel({
    required this.profile,
    required this.uid,
    required this.displayName,
    this.photoUrl,
    required this.gender,
    this.email,
    this.phoneNumber,
    this.gymName,
    required this.specialties,
    required this.experienceYears,
    this.cityId,
    this.serviceArea,
    required this.ratingAvg,
    required this.totalReviews,
    required this.hourlyRate,
    this.hasAvailableSlots = true,
    this.trainingGoals = const [],
    this.certifications = const [],
  });

  String get experienceText =>
      '${experienceYears % 1 == 0 ? experienceYears.toInt() : experienceYears}+ ${experienceYears == 1 ? 'Year' : 'Years'} Exp';
  double get rating => ratingAvg;
  String get ratingText => ratingAvg.toStringAsFixed(1);
  String get primarySpecialty => specialties.isNotEmpty ? specialties.first : 'Personal Trainer';
  String get displayLocation => serviceArea ?? (gymName != null && gymName!.isNotEmpty ? gymName! : (cityId ?? 'All Cities'));
  String get availabilityText => hasAvailableSlots ? 'Slots Available' : 'Fully Booked';

  TrainerDisplayModel copyWith({
    TrainerProfileModel? profile,
    String? uid,
    String? displayName,
    String? photoUrl,
    Gender? gender,
    String? email,
    String? phoneNumber,
    String? gymName,
    List<String>? specialties,
    double? experienceYears,
    String? cityId,
    String? serviceArea,
    double? ratingAvg,
    int? totalReviews,
    int? hourlyRate,
    bool? hasAvailableSlots,
    List<String>? trainingGoals,
    List<String>? certifications,
  }) {
    return TrainerDisplayModel(
      profile: profile ?? this.profile,
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      gender: gender ?? this.gender,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      gymName: gymName ?? this.gymName,
      specialties: specialties ?? this.specialties,
      experienceYears: experienceYears ?? this.experienceYears,
      cityId: cityId ?? this.cityId,
      serviceArea: serviceArea ?? this.serviceArea,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      totalReviews: totalReviews ?? this.totalReviews,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      hasAvailableSlots: hasAvailableSlots ?? this.hasAvailableSlots,
      trainingGoals: trainingGoals ?? this.trainingGoals,
      certifications: certifications ?? this.certifications,
    );
  }
}

