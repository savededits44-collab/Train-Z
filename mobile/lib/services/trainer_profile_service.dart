import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/firestore_collections.dart';
import '../shared/models/trainer_profile_model.dart';
import '../shared/models/user_model.dart';
import 'auth_service.dart';

/// Singleton service managing Trainer profile credentials, draft progress,
/// profile completion scoring, and submission for admin review.
class TrainerProfileService extends ChangeNotifier {
  static final TrainerProfileService _instance = TrainerProfileService._internal();
  static TrainerProfileService get instance => _instance;
  TrainerProfileService._internal();

  // Personal Profile Fields
  String? _fullName;
  String? _mobileNumber;
  String? _dateOfBirth; // ISO string "YYYY-MM-DD"
  Gender? _gender;
  String? _photoUrl;
  String? _photoPath; // local file path if picked but not yet synced
  String? _bio;
  double _experienceYears = 0.0;
  TrainerCategory _category = TrainerCategory.trainer;

  // Professional Information Fields
  List<String> _specialties = ['Strength & Conditioning'];
  List<String> _clientTypes = [];
  List<String> _trainingGoals = [];
  List<String> _trainingMethods = [];
  List<String> _languages = [];
  String? _professionalExperience;
  String? _trainingApproach;

  // Training Services Fields
  bool _trainsAtHome = false;
  bool _trainsAtGym = false;
  List<String> _otherTrainingLocations = [];
  List<String> _serviceAreas = []; // Dynamic, NO hardcoded cities
  List<String> _workingDays = [];  // e.g. ["MON", "TUE", "WED"]
  String? _workingHours;           // e.g. "06:00 AM - 09:00 PM"

  // Legacy/Compatibility fields
  String? _gymName;
  String? _sinceWhen;
  String? _certificatePath;
  int _hourlyRate = 500;

  // Profile Completion & Lifecycle
  int _profileCompletionScore = 0;
  bool _isProfileCompleted = false;
  DateTime? _submittedAt;
  TrainerVerificationStatus _verificationStatus = TrainerVerificationStatus.pending;
  DateTime? _approvedAt;
  String? _adminNotes;

  // ───────────────────────────────────────────────────────────────────────────
  // Getters
  // ───────────────────────────────────────────────────────────────────────────

  String? get fullName => _fullName;
  String? get mobileNumber => _mobileNumber;
  String? get dateOfBirth => _dateOfBirth;
  Gender? get gender => _gender;
  String? get photoUrl => _photoUrl;
  String? get photoPath => _photoPath;
  String? get bio => _bio;
  double get experienceYears => _experienceYears;
  TrainerCategory get category => _category;

  List<String> get specialties => List.unmodifiable(_specialties);
  List<String> get clientTypes => List.unmodifiable(_clientTypes);
  List<String> get trainingGoals => List.unmodifiable(_trainingGoals);
  List<String> get trainingMethods => List.unmodifiable(_trainingMethods);
  List<String> get languages => List.unmodifiable(_languages);
  String? get professionalExperience => _professionalExperience;
  String? get trainingApproach => _trainingApproach;

  bool get trainsAtHome => _trainsAtHome;
  bool get trainsAtGym => _trainsAtGym;
  List<String> get otherTrainingLocations => List.unmodifiable(_otherTrainingLocations);
  List<String> get serviceAreas => List.unmodifiable(_serviceAreas);
  List<String> get workingDays => List.unmodifiable(_workingDays);
  String? get workingHours => _workingHours;

  String? get gymName => _gymName;
  String? get sinceWhen => _sinceWhen;
  String? get certificatePath => _certificatePath;
  int get hourlyRate => _hourlyRate;

  String get experience => '${_experienceYears.toStringAsFixed(_experienceYears % 1 == 0 ? 0 : 1)} Years';
  String get philosophy => _bio ?? _trainingApproach ?? '';
  String? get age {
    if (_dateOfBirth == null) return null;
    final dob = DateTime.tryParse(_dateOfBirth!);
    if (dob == null) return null;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age > 0 ? age.toString() : null;
  }

  int get profileCompletionScore => _profileCompletionScore;
  bool get isProfileCompleted => _isProfileCompleted;
  DateTime? get submittedAt => _submittedAt;
  TrainerVerificationStatus get verificationStatus => _verificationStatus;
  DateTime? get approvedAt => _approvedAt;
  String? get adminNotes => _adminNotes;

  bool get isPendingApproval => _isProfileCompleted && _verificationStatus == TrainerVerificationStatus.pending;
  bool get isApproved => _isProfileCompleted && _verificationStatus == TrainerVerificationStatus.approved;
  bool get isRejected => _isProfileCompleted && _verificationStatus == TrainerVerificationStatus.rejected;
  bool get isAdvancedTrainer => _category == TrainerCategory.advancedTrainer;

  /// Sets test profile in memory for unit and widget testing
  void setTestProfile({
    String? fullName,
    String? mobileNumber,
    String? dateOfBirth,
    Gender? gender,
    String? photoUrl,
    String? bio,
    double? experienceYears,
    TrainerCategory? category,
    TrainerVerificationStatus? verificationStatus,
    int? hourlyRate,
    bool? isProfileCompleted,
    int? profileCompletionScore,
    String? adminNotes,
  }) {
    if (fullName != null) _fullName = fullName;
    if (mobileNumber != null) _mobileNumber = mobileNumber;
    if (dateOfBirth != null) _dateOfBirth = dateOfBirth;
    if (gender != null) _gender = gender;
    if (photoUrl != null) _photoUrl = photoUrl;
    if (bio != null) _bio = bio;
    if (experienceYears != null) _experienceYears = experienceYears;
    if (category != null) _category = category;
    if (verificationStatus != null) _verificationStatus = verificationStatus;
    if (hourlyRate != null) _hourlyRate = hourlyRate;
    if (isProfileCompleted != null) _isProfileCompleted = isProfileCompleted;
    if (profileCompletionScore != null) _profileCompletionScore = profileCompletionScore;
    if (adminNotes != null) _adminNotes = adminNotes;
    notifyListeners();
  }

  /// Reset in-memory state
  void reset() {
    _fullName = null;
    _mobileNumber = null;
    _dateOfBirth = null;
    _gender = null;
    _photoUrl = null;
    _photoPath = null;
    _bio = null;
    _experienceYears = 1.0;
    _category = TrainerCategory.trainer;
    _specialties.clear();
    _clientTypes.clear();
    _trainingGoals.clear();
    _trainingMethods.clear();
    _languages.clear();
    _professionalExperience = null;
    _trainingApproach = null;
    _trainsAtHome = false;
    _trainsAtGym = true;
    _otherTrainingLocations.clear();
    _serviceAreas.clear();
    _workingDays.clear();
    _workingHours = null;
    _gymName = null;
    _sinceWhen = null;
    _certificatePath = null;
    _hourlyRate = 500;
    _profileCompletionScore = 0;
    _isProfileCompleted = false;
    _verificationStatus = TrainerVerificationStatus.pending;
    _adminNotes = null;
    notifyListeners();
  }

  void updateHourlyRate(int rate) {
    _hourlyRate = rate;
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Profile Completion Evaluation
  // ───────────────────────────────────────────────────────────────────────────

  /// Evaluates completion based on required fields and returns a detailed report.
  TrainerProfileCompletion calculateCompletion() {
    final model = toModel(uid: FirebaseAuth.instance.currentUser?.uid ?? 'temp_uid');
    return model.calculateCompletion(
      name: _fullName,
      phone: _mobileNumber,
      genderValue: _gender,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Firestore Synchronization & State Loading
  // ───────────────────────────────────────────────────────────────────────────

  /// Populates all in-memory fields from a strongly-typed [TrainerProfileModel]
  void populateFromModel(TrainerProfileModel model) {
    _fullName = model.fullName ?? _fullName;
    _mobileNumber = model.phoneNumber ?? _mobileNumber;
    _gender = model.gender ?? _gender;
    _dateOfBirth = model.dateOfBirth ?? _dateOfBirth;
    _photoUrl = model.photoUrl ?? _photoUrl;
    _bio = model.bio ?? _bio;
    _category = model.category;
    _verificationStatus = model.verificationStatus;
    _experienceYears = model.experienceYears;
    _hourlyRate = model.hourlyRate;
    _specialties = List.from(model.specialties);
    _clientTypes = List.from(model.clientTypes);
    _trainingGoals = List.from(model.trainingGoals);
    _trainingMethods = List.from(model.trainingMethods);
    _languages = List.from(model.languages);
    _professionalExperience = model.professionalExperience;
    _trainingApproach = model.trainingApproach;
    _trainsAtHome = model.trainsAtHome;
    _trainsAtGym = model.trainsAtGym;
    _otherTrainingLocations = List.from(model.otherTrainingLocations);
    _serviceAreas = List.from(model.serviceAreas);
    _workingDays = List.from(model.workingDays);
    _workingHours = model.workingHours;
    _isProfileCompleted = model.isProfileCompleted;
    _profileCompletionScore = model.profileCompletionScore;
    _submittedAt = model.submittedAt;
    _approvedAt = model.approvedAt;
    _adminNotes = model.adminReviewNotes;
    notifyListeners();
  }

  /// Loads trainer profile and user metadata from Firestore into memory
  Future<void> loadProfile(String uid) async {
    if (uid.trim().isEmpty) return;

    try {
      final model = await AuthService().getTrainerProfile(uid);
      if (model != null) {
        populateFromModel(model);
        return;
      }
    } catch (e) {
      debugPrint('Notice: Error loading trainer profile via AuthService: $e');
    }

    try {
      final userSnap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.users)
          .doc(uid)
          .get();

      final trainerSnap = await FirebaseFirestore.instance
          .collection(FirestoreCollections.trainerProfiles)
          .doc(uid)
          .get();

      if (userSnap.exists) {
        final uData = userSnap.data()!;
        _fullName = uData['displayName'] as String? ?? _fullName;
        _mobileNumber = uData['phoneNumber'] as String? ?? _mobileNumber;
        _photoUrl = uData['photoUrl'] as String? ?? _photoUrl;
        _dateOfBirth = uData['dateOfBirth'] as String? ?? _dateOfBirth;
        _gender = Gender.fromFirestore(uData['gender']) ?? _gender;
      }

      if (trainerSnap.exists) {
        final tData = trainerSnap.data()!;
        _bio = tData['bio'] as String? ?? _bio;
        _category = TrainerCategory.fromFirestore(tData['category']);
        _verificationStatus = TrainerVerificationStatus.fromFirestore(tData['verificationStatus']);
        _experienceYears = (tData['experienceYears'] as num?)?.toDouble() ?? _experienceYears;
        _hourlyRate = (tData['hourlyRate'] as num?)?.toInt() ?? _hourlyRate;
        _photoUrl = tData['photoUrl'] as String? ?? _photoUrl;
        _dateOfBirth = tData['dateOfBirth'] as String? ?? _dateOfBirth;
        _adminNotes = tData['adminReviewNotes'] as String?;

        if (tData['specialties'] is List) {
          _specialties = (tData['specialties'] as List).map((e) => e.toString()).toList();
        }
        if (tData['clientTypes'] is List) {
          _clientTypes = (tData['clientTypes'] as List).map((e) => e.toString()).toList();
        }
        if (tData['trainingGoals'] is List) {
          _trainingGoals = (tData['trainingGoals'] as List).map((e) => e.toString()).toList();
        }
        if (tData['trainingMethods'] is List) {
          _trainingMethods = (tData['trainingMethods'] as List).map((e) => e.toString()).toList();
        }
        if (tData['languages'] is List) {
          _languages = (tData['languages'] as List).map((e) => e.toString()).toList();
        }

        _professionalExperience = tData['professionalExperience'] as String? ?? _professionalExperience;
        _trainingApproach = tData['trainingApproach'] as String? ?? _trainingApproach;
        _trainsAtHome = tData['trainsAtHome'] as bool? ?? _trainsAtHome;
        _trainsAtGym = tData['trainsAtGym'] as bool? ?? _trainsAtGym;

        if (tData['otherTrainingLocations'] is List) {
          _otherTrainingLocations = (tData['otherTrainingLocations'] as List).map((e) => e.toString()).toList();
        }
        if (tData['serviceAreas'] is List) {
          _serviceAreas = (tData['serviceAreas'] as List).map((e) => e.toString()).toList();
        }
        if (tData['workingDays'] is List) {
          _workingDays = (tData['workingDays'] as List).map((e) => e.toString()).toList();
        }

        _workingHours = tData['workingHours'] as String? ?? _workingHours;
        _gymName = tData['gymName'] as String? ?? _gymName;
        _sinceWhen = tData['sinceWhen'] as String? ?? _sinceWhen;
        _isProfileCompleted = tData['isProfileCompleted'] as bool? ?? _isProfileCompleted;
        _profileCompletionScore = (tData['profileCompletionScore'] as num?)?.toInt() ?? 0;

        if (tData['submittedAt'] is Timestamp) {
          _submittedAt = (tData['submittedAt'] as Timestamp).toDate();
        }
        if (tData['approvedAt'] is Timestamp) {
          _approvedAt = (tData['approvedAt'] as Timestamp).toDate();
        }
      }

      if (!kReleaseMode) {
        final currentEmail = AuthService().currentUser?.email?.toLowerCase().trim();
        if (AuthService.isStandardDemoTrainer(email: currentEmail, uid: uid)) {
          _verificationStatus = TrainerVerificationStatus.approved;
          _category = TrainerCategory.trainer;
          _experienceYears = 1.5;
          _isProfileCompleted = true;
          _profileCompletionScore = 100;
          _approvedAt ??= DateTime.now();
        } else if (AuthService.isAdvancedDemoTrainer(email: currentEmail, uid: uid)) {
          _verificationStatus = TrainerVerificationStatus.approved;
          _category = TrainerCategory.advancedTrainer;
          _experienceYears = 4.0;
          _isProfileCompleted = true;
          _profileCompletionScore = 100;
          _approvedAt ??= DateTime.now();
        }
      }

      if (kReleaseMode || !AuthService.isDemoTrainer(uid: uid)) {
        final comp = calculateCompletion();
        _profileCompletionScore = comp.score;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Notice: Error loading trainer profile: $e');
    }
  }

  /// Sets initial onboarding fields (legacy compatibility)
  void saveOnboarding({
    required List<String> specialties,
    required String experience,
    required String philosophy,
  }) {
    _specialties = List.from(specialties);
    final parsedExp = double.tryParse(experience.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 1.0;
    _experienceYears = parsedExp;
    _bio = philosophy.trim();
    _trainingApproach = philosophy.trim();
    notifyListeners();
  }

  /// Saves complete trainer profile details.
  /// If [submitForReview] is true, validates 100% completion before marking status as PENDING review.
  /// If [submitForReview] is false, saves as draft progress without blocking.
  Future<TrainerProfileCompletion> saveProfileDetails({
    required String fullName,
    required String mobileNumber,
    required String dateOfBirth,
    required Gender gender,
    required String bio,
    required double experienceYears,
    required List<String> specialties,
    required List<String> clientTypes,
    required List<String> trainingGoals,
    required List<String> trainingMethods,
    required List<String> languages,
    String? professionalExperience,
    String? trainingApproach,
    required bool trainsAtHome,
    required bool trainsAtGym,
    List<String> otherTrainingLocations = const [],
    required List<String> serviceAreas,
    required List<String> workingDays,
    required String workingHours,
    String? photoUrl,
    String? photoPath,
    String? gymName,
    String? sinceWhen,
    String? certificatePath,
    bool submitForReview = false,
  }) async {
    _fullName = fullName.trim();
    _mobileNumber = mobileNumber.trim();
    _dateOfBirth = dateOfBirth.trim();
    _gender = gender;
    _bio = bio.trim();
    _experienceYears = experienceYears;
    _specialties = List.from(specialties);
    _clientTypes = List.from(clientTypes);
    _trainingGoals = List.from(trainingGoals);
    _trainingMethods = List.from(trainingMethods);
    _languages = List.from(languages);
    _professionalExperience = professionalExperience?.trim();
    _trainingApproach = trainingApproach?.trim();
    _trainsAtHome = trainsAtHome;
    _trainsAtGym = trainsAtGym;
    _otherTrainingLocations = List.from(otherTrainingLocations);
    _serviceAreas = List.from(serviceAreas);
    _workingDays = List.from(workingDays);
    _workingHours = workingHours.trim();

    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      _photoUrl = photoUrl;
    }
    if (photoPath != null && photoPath.trim().isNotEmpty) {
      _photoPath = photoPath;
    }
    if (gymName != null && gymName.trim().isNotEmpty) {
      _gymName = gymName.trim();
    }
    if (sinceWhen != null && sinceWhen.trim().isNotEmpty) {
      _sinceWhen = sinceWhen.trim();
    }
    if (certificatePath != null && certificatePath.trim().isNotEmpty) {
      _certificatePath = certificatePath;
    }

    final completion = calculateCompletion();
    _profileCompletionScore = completion.score;

    if (submitForReview) {
      if (!completion.isComplete) {
        throw StateError(
          'Cannot submit incomplete profile. Missing: ${completion.missingFields.join(', ')}',
        );
      }
      _isProfileCompleted = true;
      _verificationStatus = TrainerVerificationStatus.pending;
      _submittedAt = DateTime.now();
    }

    notifyListeners();

    // Persist to Cloud Firestore against the authenticated Trainer UID
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.trim().isNotEmpty) {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Update users collection (name, phone, photo, gender, dob, onboarded)
      final userRef = FirebaseFirestore.instance.collection(FirestoreCollections.users).doc(uid);
      batch.set(userRef, {
        'displayName': _fullName,
        'phoneNumber': _mobileNumber,
        'gender': _gender?.toFirestore(),
        'dateOfBirth': _dateOfBirth,
        if (_photoUrl != null) 'photoUrl': _photoUrl,
        if (submitForReview) 'onboarded': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. Update trainer_profiles collection
      final trainerRef = FirebaseFirestore.instance.collection(FirestoreCollections.trainerProfiles).doc(uid);
      final trainerData = <String, dynamic>{
        'uid': uid,
        'fullName': _fullName,
        'mobileNumber': _mobileNumber,
        'gender': _gender?.toFirestore(),
        'dateOfBirth': _dateOfBirth,
        if (_photoUrl != null) 'photoUrl': _photoUrl,
        'bio': _bio,
        'experienceYears': _experienceYears,
        'specialties': _specialties,
        'clientTypes': _clientTypes,
        'trainingGoals': _trainingGoals,
        'trainingMethods': _trainingMethods,
        'languages': _languages,
        'professionalExperience': _professionalExperience,
        'trainingApproach': _trainingApproach,
        'trainsAtHome': _trainsAtHome,
        'trainsAtGym': _trainsAtGym,
        'otherTrainingLocations': _otherTrainingLocations,
        'serviceAreas': _serviceAreas,
        'workingDays': _workingDays,
        'workingHours': _workingHours,
        'gymName': _gymName,
        'sinceWhen': _sinceWhen,
        'profileCompletionScore': _profileCompletionScore,
        'isProfileCompleted': _isProfileCompleted,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (submitForReview) {
        trainerData['verificationStatus'] = _verificationStatus.toFirestore();
        trainerData['submittedAt'] = FieldValue.serverTimestamp();
      }

      batch.set(trainerRef, trainerData, SetOptions(merge: true));
      await batch.commit();
    }

    return completion;
  }

  /// Converts in-memory fields to [TrainerProfileModel]
  TrainerProfileModel toModel({required String uid}) {
    return TrainerProfileModel(
      uid: uid,
      fullName: _fullName,
      phoneNumber: _mobileNumber,
      gender: _gender,
      bio: _bio,
      specialties: _specialties,
      experienceYears: _experienceYears,
      category: _category,
      verificationStatus: _verificationStatus,
      hourlyRate: _hourlyRate,
      photoUrl: _photoUrl,
      dateOfBirth: _dateOfBirth,
      languages: _languages,
      clientTypes: _clientTypes,
      trainingGoals: _trainingGoals,
      trainingMethods: _trainingMethods,
      trainingApproach: _trainingApproach,
      professionalExperience: _professionalExperience,
      trainsAtHome: _trainsAtHome,
      trainsAtGym: _trainsAtGym,
      otherTrainingLocations: _otherTrainingLocations,
      serviceAreas: _serviceAreas,
      workingDays: _workingDays,
      workingHours: _workingHours,
      profileCompletionScore: _profileCompletionScore,
      isProfileCompleted: _isProfileCompleted,
      submittedAt: _submittedAt,
      approvedAt: _approvedAt,
      adminReviewNotes: _adminNotes,
    );
  }

  /// Admin approval action
  Future<void> approveByAdmin({String? notes}) async {
    _verificationStatus = TrainerVerificationStatus.approved;
    _approvedAt = DateTime.now();
    _adminNotes = notes;
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.trim().isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.trainerProfiles)
            .doc(uid)
            .set({
          'verificationStatus': 'APPROVED',
          'approvedAt': FieldValue.serverTimestamp(),
          'adminReviewNotes': notes,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Notice: TrainerProfileService approve Firestore: $e');
      }
    }
  }

  /// Admin rejection action
  Future<void> rejectByAdmin({required String reason}) async {
    _verificationStatus = TrainerVerificationStatus.rejected;
    _adminNotes = reason;
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.trim().isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.trainerProfiles)
            .doc(uid)
            .set({
          'verificationStatus': 'REJECTED',
          'adminReviewNotes': reason,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Notice: TrainerProfileService reject Firestore: $e');
      }
    }
  }

  /// Reset to pending review (for testing / demo)
  Future<void> resetToPending() async {
    _verificationStatus = TrainerVerificationStatus.pending;
    _adminNotes = null;
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.trim().isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.trainerProfiles)
            .doc(uid)
            .set({
          'verificationStatus': 'PENDING',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Notice: TrainerProfileService reset Firestore: $e');
      }
    }
  }
}
