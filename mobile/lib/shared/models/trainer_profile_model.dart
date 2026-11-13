import 'package:cloud_firestore/cloud_firestore.dart';
import 'trainer_certificate_model.dart';
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
        return 'No certificate or minimum experience required. Standard platform packages apply.';
      case TrainerCategory.advancedTrainer:
        return 'Must have relevant professional trainer qualifications & at least 3.5 years of experience.';
      case TrainerCategory.professionalTrainer:
        return 'Coming Soon.';
    }
  }

  String get packageRuleText {
    switch (this) {
      case TrainerCategory.trainer:
        return 'Uses standard TRAIN Z platform packages.';
      case TrainerCategory.advancedTrainer:
        return 'Can create custom training plans and set independent session rates. Each custom plan requires Admin approval.';
      case TrainerCategory.professionalTrainer:
        return 'Coming Soon.';
    }
  }

  bool get isAvailableAtLaunch => this != TrainerCategory.professionalTrainer;
}

class TrainerProfileCompletion {
  final int score;
  final List<String> missingFields;
  final bool isComplete;

  const TrainerProfileCompletion({
    required this.score,
    required this.missingFields,
    required this.isComplete,
  });
}

class TrainerProfileModel {
  final String uid;
  final String? fullName;
  final String? phoneNumber;
  final Gender? gender;
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
  final bool isProfileCompleted;
  final DateTime? submittedAt;

  // Client-facing verified qualifications (sanitized metadata, zero file URLs)
  final List<VerifiedQualification> verifiedQualifications;

  const TrainerProfileModel({
    required this.uid,
    this.fullName,
    this.phoneNumber,
    this.gender,
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
    // Profile fields
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
    this.isProfileCompleted = false,
    this.submittedAt,
    this.verifiedQualifications = const [],
  });

  bool get isApproved => verificationStatus == TrainerVerificationStatus.approved;
  bool get isPending => verificationStatus == TrainerVerificationStatus.pending;
  bool get isRejected => verificationStatus == TrainerVerificationStatus.rejected;
  bool get isSuspended => verificationStatus == TrainerVerificationStatus.suspended;
  bool get isAdvancedTrainer => category == TrainerCategory.advancedTrainer;
  bool get isStandardTrainer => category == TrainerCategory.trainer;
  bool get canBeBooked => isApproved && isActive;
  int get experienceYearsInt => experienceYears.floor();

  /// Calculates profile completion (0 to 100%) and returns missing required fields.
  TrainerProfileCompletion calculateCompletion({
    String? name,
    String? phone,
    Gender? genderValue,
  }) {
    int score = 0;
    final missing = <String>[];

    // 1. Personal Profile Information (40%)
    final hasPhoto = photoUrl != null && photoUrl!.trim().isNotEmpty;
    if (hasPhoto) {
      score += 10;
    } else {
      missing.add('Profile Photo');
    }

    final effectiveName = name ?? fullName;
    final hasName = effectiveName != null && effectiveName.trim().isNotEmpty;
    if (hasName) {
      score += 10;
    } else {
      missing.add('Full Name');
    }

    final effectivePhone = phone ?? phoneNumber;
    final hasPhone = effectivePhone != null && effectivePhone.trim().isNotEmpty;
    if (hasPhone) {
      score += 5;
    } else {
      missing.add('Phone Number');
    }

    final hasDob = dateOfBirth != null && dateOfBirth!.trim().isNotEmpty;
    if (hasDob) {
      score += 5;
    } else {
      missing.add('Date of Birth');
    }

    final effectiveGender = genderValue ?? gender;
    final hasGender = effectiveGender != null;
    if (hasGender) {
      score += 5;
    } else {
      missing.add('Gender');
    }

    final hasBio = bio != null && bio!.trim().length >= 20;
    if (hasBio) {
      score += 5;
    } else {
      missing.add('Professional Biography (min. 20 chars)');
    }

    // 2. Professional Information (35%)
    final minExp = isAdvancedTrainer ? 3.5 : 0.0;
    final hasExp = experienceYears >= minExp && (experienceYears > 0 || isStandardTrainer);
    if (hasExp) {
      score += 10;
    } else {
      missing.add(isAdvancedTrainer ? 'Experience (min. 3.5 years for Advanced)' : 'Total Years of Experience');
    }

    final hasSpecs = specialties.isNotEmpty;
    if (hasSpecs) {
      score += 5;
    } else {
      missing.add('Training Specialisations');
    }

    final hasClients = clientTypes.isNotEmpty;
    if (hasClients) {
      score += 4;
    } else {
      missing.add('Types of Clients');
    }

    final hasGoals = trainingGoals.isNotEmpty;
    if (hasGoals) {
      score += 4;
    } else {
      missing.add('Fitness Goals');
    }

    final hasMethods = trainingMethods.isNotEmpty;
    if (hasMethods) {
      score += 4;
    } else {
      missing.add('Training Methods');
    }

    final hasLangs = languages.isNotEmpty;
    if (hasLangs) {
      score += 4;
    } else {
      missing.add('Languages Spoken');
    }

    final hasApproach = trainingApproach != null && trainingApproach!.trim().length >= 10;
    if (hasApproach) {
      score += 4;
    } else {
      missing.add('Training Approach Description');
    }

    // 3. Training Services (25%)
    final hasLocationType = trainsAtHome || trainsAtGym || otherTrainingLocations.isNotEmpty;
    if (hasLocationType) {
      score += 8;
    } else {
      missing.add('Training Locations (Home, Gym, or Other)');
    }

    final hasAreas = serviceAreas.isNotEmpty;
    if (hasAreas) {
      score += 9;
    } else {
      missing.add('Service Areas (min. 1 area)');
    }

    final hasSchedule = workingDays.isNotEmpty && (workingHours != null && workingHours!.trim().isNotEmpty);
    if (hasSchedule) {
      score += 8;
    } else {
      missing.add('Working Schedule (Days & Hours)');
    }

    final finalScore = score.clamp(0, 100);
    return TrainerProfileCompletion(
      score: finalScore,
      missingFields: missing,
      isComplete: missing.isEmpty && finalScore == 100,
    );
  }

  TrainerProfileModel copyWith({
    String? uid,
    String? fullName,
    String? phoneNumber,
    Gender? gender,
    String? bio,
    List<String>? specialties,
    double? experienceYears,
    String? cityId,
    int? hourlyRate,
    TrainerCategory? category,
    TrainerVerificationStatus? verificationStatus,
    List<String>? verificationDocuments,
    List<String>? certificationDocuments,
    String? adminReviewNotes,
    DateTime? approvedAt,
    String? approvedBy,
    bool? isActive,
    double? ratingAvg,
    int? totalReviews,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? photoUrl,
    String? dateOfBirth,
    List<String>? languages,
    List<String>? clientTypes,
    List<String>? trainingGoals,
    List<String>? trainingMethods,
    String? trainingApproach,
    String? professionalExperience,
    bool? trainsAtHome,
    bool? trainsAtGym,
    List<String>? otherTrainingLocations,
    List<String>? serviceAreas,
    List<String>? workingDays,
    String? workingHours,
    int? profileCompletionScore,
    bool? isProfileCompleted,
    DateTime? submittedAt,
    List<VerifiedQualification>? verifiedQualifications,
  }) {
    return TrainerProfileModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      gender: gender ?? this.gender,
      bio: bio ?? this.bio,
      specialties: specialties ?? this.specialties,
      experienceYears: experienceYears ?? this.experienceYears,
      cityId: cityId ?? this.cityId,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      category: category ?? this.category,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationDocuments: verificationDocuments ?? this.verificationDocuments,
      certificationDocuments: certificationDocuments ?? this.certificationDocuments,
      adminReviewNotes: adminReviewNotes ?? this.adminReviewNotes,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      isActive: isActive ?? this.isActive,
      ratingAvg: ratingAvg ?? this.ratingAvg,
      totalReviews: totalReviews ?? this.totalReviews,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      photoUrl: photoUrl ?? this.photoUrl,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      languages: languages ?? this.languages,
      clientTypes: clientTypes ?? this.clientTypes,
      trainingGoals: trainingGoals ?? this.trainingGoals,
      trainingMethods: trainingMethods ?? this.trainingMethods,
      trainingApproach: trainingApproach ?? this.trainingApproach,
      professionalExperience: professionalExperience ?? this.professionalExperience,
      trainsAtHome: trainsAtHome ?? this.trainsAtHome,
      trainsAtGym: trainsAtGym ?? this.trainsAtGym,
      otherTrainingLocations: otherTrainingLocations ?? this.otherTrainingLocations,
      serviceAreas: serviceAreas ?? this.serviceAreas,
      workingDays: workingDays ?? this.workingDays,
      workingHours: workingHours ?? this.workingHours,
      profileCompletionScore: profileCompletionScore ?? this.profileCompletionScore,
      isProfileCompleted: isProfileCompleted ?? this.isProfileCompleted,
      submittedAt: submittedAt ?? this.submittedAt,
      verifiedQualifications: verifiedQualifications ?? this.verifiedQualifications,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      if (fullName != null) 'fullName': fullName,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (gender != null) 'gender': gender!.toFirestore(),
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
      'photoUrl': photoUrl,
      'dateOfBirth': dateOfBirth,
      'languages': languages,
      'clientTypes': clientTypes,
      'trainingGoals': trainingGoals,
      'trainingMethods': trainingMethods,
      'trainingApproach': trainingApproach,
      'professionalExperience': professionalExperience,
      'trainsAtHome': trainsAtHome,
      'trainsAtGym': trainsAtGym,
      'otherTrainingLocations': otherTrainingLocations,
      'serviceAreas': serviceAreas,
      'workingDays': workingDays,
      'workingHours': workingHours,
      'profileCompletionScore': profileCompletionScore,
      'isProfileCompleted': isProfileCompleted,
      'submittedAt': submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      if (verifiedQualifications.isNotEmpty)
        'verifiedQualifications': verifiedQualifications.map((q) => q.toMap()).toList(),
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
      fullName: map['fullName'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      gender: Gender.fromFirestore(map['gender']),
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
      photoUrl: map['photoUrl'] as String?,
      dateOfBirth: map['dateOfBirth'] as String?,
      languages: (map['languages'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      clientTypes: (map['clientTypes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      trainingGoals: (map['trainingGoals'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      trainingMethods: (map['trainingMethods'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      trainingApproach: map['trainingApproach'] as String?,
      professionalExperience: map['professionalExperience'] as String?,
      trainsAtHome: map['trainsAtHome'] as bool? ?? false,
      trainsAtGym: map['trainsAtGym'] as bool? ?? false,
      otherTrainingLocations: (map['otherTrainingLocations'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      serviceAreas: (map['serviceAreas'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      workingDays: (map['workingDays'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      workingHours: map['workingHours'] as String?,
      profileCompletionScore: (map['profileCompletionScore'] as num?)?.toInt() ?? 0,
      isProfileCompleted: map['isProfileCompleted'] as bool? ?? false,
      submittedAt: parseTimestamp(map['submittedAt']),
      verifiedQualifications: (map['verifiedQualifications'] as List<dynamic>?)
              ?.map((item) => VerifiedQualification.fromMap(Map<String, dynamic>.from(item as Map)))
              .toList() ??
          const [],
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
  TrainerCategory get category => profile.category;
  List<VerifiedQualification> get verifiedQualifications => profile.verifiedQualifications;

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

