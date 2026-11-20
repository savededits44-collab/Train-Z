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

  // Training Services Fields (Commercial Gym Standard)
  bool _trainsAtHome = false;
  bool _trainsAtGym = true;
  List<String> _otherTrainingLocations = [];
  List<String> _serviceAreas = []; // Dynamic, NO hardcoded cities
  List<String> _workingDays = [];  // e.g. ["MON", "TUE", "WED"]
  String? _workingHours;           // e.g. "06:00 AM - 09:00 PM"

  // Primary Working Location (Default commercial gym)
  String? _primaryGymName;
  String? _primaryGymAddress;
  double? _primaryGymLat;
  double? _primaryGymLng;

  // Active Location (Updateable area when coaching elsewhere - separate from primary)
  String? _activeLocationName;
  String? _activeLocationAddress;
  double? _activeLat;
  double? _activeLng;
  DateTime? _activeLocationUpdatedAt;

  // Trainer-defined Travel Radius (in km)
  double _travelRadiusKm = 15.0;

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
  bool get isSuspended => _verificationStatus == TrainerVerificationStatus.suspended;
  bool get isAdvancedTrainer => _category == TrainerCategory.advancedTrainer;

  String? get primaryGymName => _primaryGymName;
  String? get primaryGymAddress => _primaryGymAddress;
  double? get primaryGymLat => _primaryGymLat;
  double? get primaryGymLng => _primaryGymLng;

  String? get activeLocationName => _activeLocationName;
  String? get activeLocationAddress => _activeLocationAddress;
  double? get activeLat => _activeLat;
  double? get activeLng => _activeLng;
  DateTime? get activeLocationUpdatedAt => _activeLocationUpdatedAt;

  double get travelRadiusKm => _travelRadiusKm;

  double? get effectiveLat => _activeLat ?? _primaryGymLat;
  double? get effectiveLng => _activeLng ?? _primaryGymLng;
  String get effectiveLocationName =>
      _activeLocationName ?? _primaryGymName ?? (_serviceAreas.isNotEmpty ? _serviceAreas.first : 'Commercial Partner Gym');
  String get effectiveLocationAddress =>
      _activeLocationAddress ?? _primaryGymAddress ?? '';

  /// Updates Primary Working Location
  Future<void> updatePrimaryLocation({
    required String gymName,
    required String gymAddress,
    double? lat,
    double? lng,
  }) async {
    _primaryGymName = gymName.trim();
    _primaryGymAddress = gymAddress.trim();
    _primaryGymLat = lat;
    _primaryGymLng = lng;
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.trainerProfiles)
            .doc(uid)
            .set({
          'primaryGymName': _primaryGymName,
          'primaryGymAddress': _primaryGymAddress,
          'primaryGymLat': _primaryGymLat,
          'primaryGymLng': _primaryGymLng,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Notice: Error saving primary location: $e');
      }
    }
  }

  /// Updates Active Location (separate from primary)
  Future<void> updateActiveLocation({
    required String locationName,
    required String locationAddress,
    double? lat,
    double? lng,
  }) async {
    _activeLocationName = locationName.trim();
    _activeLocationAddress = locationAddress.trim();
    _activeLat = lat;
    _activeLng = lng;
    _activeLocationUpdatedAt = DateTime.now();
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.trainerProfiles)
            .doc(uid)
            .set({
          'activeLocationName': _activeLocationName,
          'activeLocationAddress': _activeLocationAddress,
          'activeLat': _activeLat,
          'activeLng': _activeLng,
          'activeLocationUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Notice: Error saving active location: $e');
      }
    }
  }

  /// Resets Active Location to match Primary Location
  Future<void> resetActiveLocationToPrimary() async {
    _activeLocationName = _primaryGymName;
    _activeLocationAddress = _primaryGymAddress;
    _activeLat = _primaryGymLat;
    _activeLng = _primaryGymLng;
    _activeLocationUpdatedAt = DateTime.now();
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.trainerProfiles)
            .doc(uid)
            .set({
          'activeLocationName': _activeLocationName,
          'activeLocationAddress': _activeLocationAddress,
          'activeLat': _activeLat,
          'activeLng': _activeLng,
          'activeLocationUpdatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Notice: Error resetting active location: $e');
      }
    }
  }

  /// Updates Trainer-defined Travel Radius (in km)
  Future<void> updateTravelRadius(double radiusKm) async {
    _travelRadiusKm = radiusKm.clamp(1.0, 100.0);
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection(FirestoreCollections.trainerProfiles)
            .doc(uid)
            .set({
          'travelRadiusKm': _travelRadiusKm,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Notice: Error updating travel radius: $e');
      }
    }
  }

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
    _primaryGymName = null;
    _primaryGymAddress = null;
    _primaryGymLat = null;
    _primaryGymLng = null;
    _activeLocationName = null;
    _activeLocationAddress = null;
    _activeLat = null;
    _activeLng = null;
    _activeLocationUpdatedAt = null;
    _travelRadiusKm = 15.0;
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
    _primaryGymName = model.primaryGymName ?? _primaryGymName;
    _primaryGymAddress = model.primaryGymAddress ?? _primaryGymAddress;
    _primaryGymLat = model.primaryGymLat ?? _primaryGymLat;
    _primaryGymLng = model.primaryGymLng ?? _primaryGymLng;
    _activeLocationName = model.activeLocationName ?? _activeLocationName;
    _activeLocationAddress = model.activeLocationAddress ?? _activeLocationAddress;
    _activeLat = model.activeLat ?? _activeLat;
    _activeLng = model.activeLng ?? _activeLng;
    _activeLocationUpdatedAt = model.activeLocationUpdatedAt ?? _activeLocationUpdatedAt;
    _travelRadiusKm = model.travelRadiusKm;
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
        _primaryGymName = tData['primaryGymName'] as String? ?? _primaryGymName;
        _primaryGymAddress = tData['primaryGymAddress'] as String? ?? _primaryGymAddress;
        _primaryGymLat = (tData['primaryGymLat'] as num?)?.toDouble() ?? _primaryGymLat;
        _primaryGymLng = (tData['primaryGymLng'] as num?)?.toDouble() ?? _primaryGymLng;
        _activeLocationName = tData['activeLocationName'] as String? ?? _activeLocationName;
        _activeLocationAddress = tData['activeLocationAddress'] as String? ?? _activeLocationAddress;
        _activeLat = (tData['activeLat'] as num?)?.toDouble() ?? _activeLat;
        _activeLng = (tData['activeLng'] as num?)?.toDouble() ?? _activeLng;
        if (tData['activeLocationUpdatedAt'] is Timestamp) {
          _activeLocationUpdatedAt = (tData['activeLocationUpdatedAt'] as Timestamp).toDate();
        }
        _travelRadiusKm = (tData['travelRadiusKm'] as num?)?.toDouble() ?? _travelRadiusKm;
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

      final comp = calculateCompletion();
      _profileCompletionScore = comp.score;

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
    String? primaryGymName,
    String? primaryGymAddress,
    double? primaryGymLat,
    double? primaryGymLng,
    double? travelRadiusKm,
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
    _trainsAtHome = false;
    _trainsAtGym = true;
    _otherTrainingLocations = List.from(otherTrainingLocations);
    _serviceAreas = List.from(serviceAreas);
    _workingDays = List.from(workingDays);
    _workingHours = workingHours.trim();

    if (primaryGymName != null && primaryGymName.trim().isNotEmpty) {
      _primaryGymName = primaryGymName.trim();
    }
    if (primaryGymAddress != null && primaryGymAddress.trim().isNotEmpty) {
      _primaryGymAddress = primaryGymAddress.trim();
    }
    if (primaryGymLat != null) _primaryGymLat = primaryGymLat;
    if (primaryGymLng != null) _primaryGymLng = primaryGymLng;
    if (travelRadiusKm != null && travelRadiusKm > 0) {
      _travelRadiusKm = travelRadiusKm;
    }

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
        'trainsAtHome': false,
        'trainsAtGym': true,
        'otherTrainingLocations': _otherTrainingLocations,
        'serviceAreas': _serviceAreas,
        'workingDays': _workingDays,
        'workingHours': _workingHours,
        'primaryGymName': _primaryGymName,
        'primaryGymAddress': _primaryGymAddress,
        'primaryGymLat': _primaryGymLat,
        'primaryGymLng': _primaryGymLng,
        'activeLocationName': _activeLocationName,
        'activeLocationAddress': _activeLocationAddress,
        'activeLat': _activeLat,
        'activeLng': _activeLng,
        'activeLocationUpdatedAt': _activeLocationUpdatedAt != null ? Timestamp.fromDate(_activeLocationUpdatedAt!) : null,
        'travelRadiusKm': _travelRadiusKm,
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
      trainsAtHome: false,
      trainsAtGym: true,
      otherTrainingLocations: _otherTrainingLocations,
      serviceAreas: _serviceAreas,
      workingDays: _workingDays,
      workingHours: _workingHours,
      primaryGymName: _primaryGymName,
      primaryGymAddress: _primaryGymAddress,
      primaryGymLat: _primaryGymLat,
      primaryGymLng: _primaryGymLng,
      activeLocationName: _activeLocationName,
      activeLocationAddress: _activeLocationAddress,
      activeLat: _activeLat,
      activeLng: _activeLng,
      activeLocationUpdatedAt: _activeLocationUpdatedAt,
      travelRadiusKm: _travelRadiusKm,
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
}
