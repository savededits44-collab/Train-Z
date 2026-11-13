import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/constants/firestore_collections.dart';
import '../core/errors/app_exceptions.dart';
import '../shared/models/trainer_certificate_model.dart';
import '../shared/models/trainer_profile_model.dart';
import '../shared/models/user_model.dart';

/// Single, unified authentication service for TRAIN Z (both Clients and Trainers).
/// Roles and permissions are strictly decoupled from public authentication tokens.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  FirebaseAuth? _authInstance;
  FirebaseAuth get _auth {
    _authInstance ??= FirebaseAuth.instance;
    return _authInstance!;
  }

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore get _firestore {
    _firestoreInstance ??= FirebaseFirestore.instance;
    return _firestoreInstance!;
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (_) {
      return Stream.value(null);
    }
  }

  /// Checks if current authenticated user has verified their email address
  bool get isEmailVerified {
    try {
      return _auth.currentUser?.emailVerified ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Stream of current typed UserModel from Firestore
  Stream<UserModel?> get currentUserProfileStream {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return Stream.value(null);
    return _firestore
        .collection(FirestoreCollections.users)
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return UserModel.fromDocument(snapshot);
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Authentication Actions
  // ───────────────────────────────────────────────────────────────────────────

  /// Sign up with Email and Password.
  /// Note: [requestedRole] can only be CLIENT or TRAINER. ADMIN is strictly blocked.
  Future<UserCredential> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    String? phoneNumber,
    UserRole? requestedRole,
    Gender? gender,
    TrainerCategory? trainerCategory,
    double? experienceYears,
  }) async {
    // Security Guard: Prevent public users from attempting to self-assign ADMIN role
    if (requestedRole == UserRole.admin) {
      throw const RolePermissionException(
        'Public registration for ADMIN role is strictly forbidden.',
      );
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      await user.updateDisplayName(name.trim());

      final batch = _firestore.batch();

      // 1. Create primary user document
      final userModel = UserModel(
        uid: user.uid,
        email: email.trim(),
        displayName: name.trim(),
        phoneNumber: phoneNumber?.trim(),
        role: requestedRole,
        gender: gender,
        status: UserStatus.active,
        isEmailVerified: user.emailVerified,
        isOnboarded: false,
        createdAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
      );

      batch.set(
        _firestore.collection(FirestoreCollections.users).doc(user.uid),
        userModel.toMap(),
        SetOptions(merge: true),
      );

      // 2. If registered as CLIENT, automatically initialize client_profiles & session_credits
      if (requestedRole == UserRole.client) {
        batch.set(
          _firestore.collection(FirestoreCollections.clientProfiles).doc(user.uid),
          {
            'uid': user.uid,
            'fitnessGoals': <String>[],
            'fitnessLevel': null,
            'preferredCityId': null,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        batch.set(
          _firestore.collection(FirestoreCollections.sessionCredits).doc(user.uid),
          {
            'clientId': user.uid,
            'totalPurchased': 0,
            'totalReserved': 0,
            'totalConsumed': 0,
            'totalReturned': 0,
            'totalForfeited': 0,
            'availableBalance': 0,
            'lastUpdated': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      // 3. If registered as TRAINER, initialize trainer_profiles with PENDING verification
      if (requestedRole == UserRole.trainer) {
        batch.set(
          _firestore.collection(FirestoreCollections.trainerProfiles).doc(user.uid),
          {
            'uid': user.uid,
            'category': (trainerCategory ?? TrainerCategory.trainer).toFirestore(),
            'verificationStatus': 'PENDING',
            'experienceYears': experienceYears ?? 0.0,
            'specialties': <String>[],
            'hourlyRate': 500,
            'verificationDocuments': <String>[],
            'certificationDocuments': <String>[],
            'adminReviewNotes': null,
            'approvedAt': null,
            'approvedBy': null,
            'isActive': true,
            'ratingAvg': 5.0,
            'totalReviews': 0,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      // Attempt to dispatch email verification automatically
      try {
        await user.sendEmailVerification();
      } catch (_) {
        // Non-blocking; user can re-trigger verification manually
      }
    }

    return credential;
  }

  /// Sign in with Email and Password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      // Record last login timestamp
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .set({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isEmailVerified': user.emailVerified,
      }, SetOptions(merge: true));
    }

    return credential;
  }

  /// Continue / Sign in with Google (OAuth)
  Future<UserCredential?> signInWithGoogle({
    UserRole? requestedRole,
  }) async {
    if (requestedRole == UserRole.admin) {
      throw const RolePermissionException(
        'Public registration for ADMIN role is strictly forbidden.',
      );
    }

    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // Cancelled

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;

    if (user != null) {
      final docRef = _firestore.collection(FirestoreCollections.users).doc(user.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        final newUser = UserModel(
          uid: user.uid,
          email: user.email ?? googleUser.email,
          displayName: user.displayName ?? googleUser.displayName ?? '',
          photoUrl: user.photoURL,
          role: requestedRole,
          status: UserStatus.active,
          isEmailVerified: true, // Google accounts are pre-verified
          isOnboarded: false,
          createdAt: DateTime.now(),
          lastLoginAt: DateTime.now(),
        );
        await docRef.set(newUser.toMap());
      } else {
        await docRef.set({
          'lastLoginAt': FieldValue.serverTimestamp(),
          'isEmailVerified': true,
        }, SetOptions(merge: true));
      }
    }

    return userCredential;
  }

  /// Sends email verification link to current authenticated user
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('No authenticated user session found.');
    }
    await user.sendEmailVerification();
  }

  /// Reloads user to check if email was verified
  Future<bool> reloadAndCheckEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final updated = _auth.currentUser;
    final verified = updated?.emailVerified ?? false;

    if (verified) {
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .update({'isEmailVerified': true});
    }

    return verified;
  }

  /// Password reset link to user's registered email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Sign out from both Firebase and Google session
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Profile & Role Handling
  // ───────────────────────────────────────────────────────────────────────────

  /// Fetch user document map (backward compatible)
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    if (uid.trim().isEmpty) return null;
    final doc = await _firestore.collection(FirestoreCollections.users).doc(uid).get();
    return doc.data();
  }

  /// Fetch strongly-typed UserModel
  Future<UserModel?> getUserModel(String uid) async {
    if (uid.trim().isEmpty) return null;
    try {
      final doc = await _firestore.collection(FirestoreCollections.users).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        final model = UserModel.fromDocument(doc);
        if (!kReleaseMode && isDemoTrainer(uid: uid, email: model.email)) {
          return model.copyWith(
            role: UserRole.trainer,
            status: UserStatus.active,
            isEmailVerified: true,
            isOnboarded: true,
          );
        }
        return model;
      }
    } catch (e) {
      debugPrint('Notice: Error fetching user model: $e');
    }

    if (!kReleaseMode && isDemoTrainer(uid: uid)) {
      return syntheticDemoUser(uid);
    }
    return null;
  }

  /// Dedicated development demo trainer account constants
  static const String demoStandardTrainerUid = 'nY3lebkFPBZwWNV6ycj4QtpttV92';
  static const String demoAdvancedTrainerUid = 'tBzc47n2bpbLVVIFSIEd34Mfbma2';
  static const String demoStandardTrainerEmail = 'trainer.demo@trainz.test';
  static const String demoAdvancedTrainerEmail = 'advanced.demo@trainz.test';

  /// Development/Test environment helper to identify seeded demo trainer accounts
  static bool isDemoTrainer({String? email, String? uid}) {
    if (kReleaseMode) return false;
    final cleanEmail = email?.toLowerCase().trim();
    return uid == demoStandardTrainerUid ||
        uid == demoAdvancedTrainerUid ||
        cleanEmail == demoStandardTrainerEmail ||
        cleanEmail == demoAdvancedTrainerEmail;
  }

  static bool isStandardDemoTrainer({String? email, String? uid}) {
    if (kReleaseMode) return false;
    final cleanEmail = email?.toLowerCase().trim();
    return uid == demoStandardTrainerUid || cleanEmail == demoStandardTrainerEmail;
  }

  static bool isAdvancedDemoTrainer({String? email, String? uid}) {
    if (kReleaseMode) return false;
    final cleanEmail = email?.toLowerCase().trim();
    return uid == demoAdvancedTrainerUid || cleanEmail == demoAdvancedTrainerEmail;
  }

  static UserModel syntheticDemoUser(String uid) {
    final isAdv = isAdvancedDemoTrainer(uid: uid);
    return UserModel(
      uid: uid,
      email: isAdv ? demoAdvancedTrainerEmail : demoStandardTrainerEmail,
      displayName: isAdv ? 'Demo Advanced Trainer' : 'Demo Standard Trainer',
      role: UserRole.trainer,
      status: UserStatus.active,
      isEmailVerified: true,
      isOnboarded: true,
      phoneNumber: isAdv ? '+919876543211' : '+919876543210',
      gender: Gender.male,
    );
  }

  static TrainerProfileModel syntheticDemoProfile(String uid) {
    final isAdv = isAdvancedDemoTrainer(uid: uid);
    if (isAdv) {
      return const TrainerProfileModel(
        uid: demoAdvancedTrainerUid,
        fullName: 'Demo Advanced Trainer',
        phoneNumber: '+919876543211',
        gender: Gender.male,
        dateOfBirth: '1992-08-20',
        bio: 'Professional strength and conditioning coach with 4 years of experience guiding athletes in hypertrophy, powerlifting, and body transformation protocols.',
        category: TrainerCategory.advancedTrainer,
        verificationStatus: TrainerVerificationStatus.approved,
        experienceYears: 4.0,
        hourlyRate: 1200,
        isProfileCompleted: true,
        profileCompletionScore: 100,
        isActive: true,
        specialties: ['Strength & Conditioning', 'Hypertrophy', 'Nutrition Coaching'],
        clientTypes: ['Athletes', 'Working Professionals', 'Intermediate Lifters'],
        trainingGoals: ['Build Muscle & Strength', 'Fat Loss & Conditioning', 'Athletic Performance'],
        trainingMethods: ['Periodized Strength', 'Progressive Overload', 'Functional Movement'],
        languages: ['English', 'Hindi'],
        trainingApproach: 'Evidence-based strength and conditioning with customized progression metrics and comprehensive nutritional guidance.',
        professionalExperience: 'Head Trainer at Cult Fitness (4 years), worked with 150+ personal training clients, developed periodized hypertrophy programs.',
        trainsAtHome: true,
        trainsAtGym: true,
        serviceAreas: ['Koramangala, Bengaluru', 'Indiranagar, Bengaluru', 'HSR Layout, Bengaluru'],
        workingDays: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'],
        workingHours: '06:00 AM - 08:00 PM',
        verifiedQualifications: [
          VerifiedQualification(
            id: 'cert_demo_advanced_01',
            certificateName: '[DEMO TEST] Certified Strength & Conditioning Specialist (CSCS)',
            courseName: 'Advanced Strength & Periodization Masterclass',
            issuingOrganization: 'National Strength & Conditioning Association (Test Synthetic)',
            yearOfCompletion: '2021',
            qualificationDetails: 'Advanced professional credential with 4.0 years of elite strength conditioning coaching experience.',
          ),
          VerifiedQualification(
            id: 'cert_demo_advanced_02',
            certificateName: '[DEMO TEST] Precision Nutrition Level 1 (Pn1)',
            courseName: 'Exercise Nutrition & Periodization',
            issuingOrganization: 'Precision Nutrition (Test Synthetic)',
            yearOfCompletion: '2022',
            qualificationDetails: 'Sports nutrition, metabolic profiling, and body recomposition.',
          ),
        ],
      );
    }
    return const TrainerProfileModel(
      uid: demoStandardTrainerUid,
      fullName: 'Demo Standard Trainer',
      phoneNumber: '+919876543210',
      gender: Gender.male,
      dateOfBirth: '1995-05-15',
      bio: 'Dedicated personal fitness coach specializing in strength fundamentals, fat loss, functional conditioning, and sustainable healthy lifestyle habits.',
      category: TrainerCategory.trainer,
      verificationStatus: TrainerVerificationStatus.approved,
      experienceYears: 1.5,
      hourlyRate: 500,
      isProfileCompleted: true,
      profileCompletionScore: 100,
      isActive: true,
      specialties: ['Strength Training', 'Fat Loss', 'Functional Fitness'],
      clientTypes: ['Beginners', 'General Population', 'Weight Loss Clients'],
      trainingGoals: ['Weight Loss', 'General Fitness', 'Core Strength'],
      trainingMethods: ['Bodyweight Training', 'Circuit Training', 'Mobility Drills'],
      languages: ['English', 'Hindi'],
      trainingApproach: 'Encouraging, structured, and goal-oriented workouts tailored to beginner and intermediate athletes.',
      professionalExperience: '1.5 years personal training at local fitness clubs.',
      trainsAtHome: true,
      trainsAtGym: true,
      serviceAreas: ['Pune Central', 'Kothrud, Pune', 'Aundh, Pune'],
      workingDays: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'],
      workingHours: '06:00 AM - 08:00 PM',
      verifiedQualifications: [
        VerifiedQualification(
          id: 'cert_demo_standard_01',
          certificateName: '[DEMO TEST] Certified Personal Trainer Level 1 (Beginner)',
          courseName: 'Foundation in Personal Training',
          issuingOrganization: 'TRAIN Z Fitness Academy (Test Synthetic)',
          yearOfCompletion: '2024',
          qualificationDetails: 'Synthetic demo qualification for Standard Trainer verification testing.',
        ),
      ],
    );
  }

  /// Helper to enrich trainer profile model for designated demo accounts in development/test environments
  TrainerProfileModel _enrichIfDemoAccount(TrainerProfileModel model, String uid) {
    if (kReleaseMode) return model;
    final currentEmail = currentUser?.email?.toLowerCase().trim();

    if (isStandardDemoTrainer(email: currentEmail, uid: uid)) {
      return model.copyWith(
        verificationStatus: TrainerVerificationStatus.approved,
        category: TrainerCategory.trainer,
        isProfileCompleted: true,
        profileCompletionScore: 100,
        isActive: true,
        verifiedQualifications: const [
          VerifiedQualification(
            id: 'cert_demo_standard_01',
            certificateName: '[DEMO TEST] Certified Personal Trainer Level 1 (Beginner)',
            courseName: 'Foundation in Personal Training',
            issuingOrganization: 'TRAIN Z Fitness Academy (Test Synthetic)',
            yearOfCompletion: '2024',
            qualificationDetails: 'Synthetic demo qualification for Standard Trainer verification testing.',
          ),
        ],
      );
    }

    if (isAdvancedDemoTrainer(email: currentEmail, uid: uid)) {
      return model.copyWith(
        verificationStatus: TrainerVerificationStatus.approved,
        category: TrainerCategory.advancedTrainer,
        experienceYears: model.experienceYears < 3.5 ? 4.0 : model.experienceYears,
        isProfileCompleted: true,
        profileCompletionScore: 100,
        isActive: true,
        verifiedQualifications: const [
          VerifiedQualification(
            id: 'cert_demo_advanced_01',
            certificateName: '[DEMO TEST] Certified Strength & Conditioning Specialist (CSCS)',
            courseName: 'Advanced Strength & Periodization Masterclass',
            issuingOrganization: 'National Strength & Conditioning Association (Test Synthetic)',
            yearOfCompletion: '2021',
            qualificationDetails: 'Advanced professional credential with 4.0 years of elite strength conditioning coaching experience.',
          ),
          VerifiedQualification(
            id: 'cert_demo_advanced_02',
            certificateName: '[DEMO TEST] Precision Nutrition Level 1 (Pn1)',
            courseName: 'Exercise Nutrition & Periodization',
            issuingOrganization: 'Precision Nutrition (Test Synthetic)',
            yearOfCompletion: '2022',
            qualificationDetails: 'Sports nutrition, metabolic profiling, and body recomposition.',
          ),
        ],
      );
    }

    return model;
  }

  /// Fetch strongly-typed TrainerProfileModel
  Future<TrainerProfileModel?> getTrainerProfile(String uid) async {
    if (uid.trim().isEmpty) return null;
    try {
      final doc = await _firestore.collection(FirestoreCollections.trainerProfiles).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return _enrichIfDemoAccount(TrainerProfileModel.fromDocument(doc), uid);
      }
    } catch (e) {
      debugPrint('Notice: Error fetching trainer profile: $e');
    }

    if (!kReleaseMode && isDemoTrainer(uid: uid)) {
      return syntheticDemoProfile(uid);
    }
    return null;
  }

  /// Stream of current typed TrainerProfileModel from Firestore
  Stream<TrainerProfileModel?> trainerProfileStream(String uid) {
    if (uid.trim().isEmpty) return Stream.value(null);
    return _firestore
        .collection(FirestoreCollections.trainerProfiles)
        .doc(uid)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return _enrichIfDemoAccount(TrainerProfileModel.fromDocument(snapshot), uid);
    });
  }

  /// Update client onboarding preferences (backward compatible)
  Future<void> saveClientOnboarding({
    required String goal,
    required String fitnessLevel,
    Gender? gender,
    String? preferredCityId,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return;

    final batch = _firestore.batch();

    // 1. Update users collection
    final userRef = _firestore.collection(FirestoreCollections.users).doc(uid);
    final userUpdates = <String, dynamic>{
      'role': 'CLIENT',
      'onboarded': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (gender != null) {
      userUpdates['gender'] = gender.toFirestore();
    }
    batch.set(userRef, userUpdates, SetOptions(merge: true));

    // 2. Populate client_profiles collection
    final clientProfileRef = _firestore.collection(FirestoreCollections.clientProfiles).doc(uid);
    batch.set(clientProfileRef, {
      'uid': uid,
      'fitnessGoals': [goal],
      'fitnessLevel': fitnessLevel,
      'preferredCityId': preferredCityId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3. Initialize session_credits collection balance if not present
    final creditRef = _firestore.collection(FirestoreCollections.sessionCredits).doc(uid);
    batch.set(creditRef, {
      'clientId': uid,
      'totalPurchased': 0,
      'totalReserved': 0,
      'totalConsumed': 0,
      'totalReturned': 0,
      'totalForfeited': 0,
      'availableBalance': 0,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// Update trainer onboarding credentials (backward compatible)
  Future<void> saveTrainerOnboarding({
    required List<String> specialties,
    required String experience,
    required String bio,
    Gender? gender,
    String? cityId,
    int? hourlyRate,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return;

    final batch = _firestore.batch();

    // 1. Update users collection
    final userRef = _firestore.collection(FirestoreCollections.users).doc(uid);
    final userUpdates = <String, dynamic>{
      'role': 'TRAINER',
      'onboarded': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (gender != null) {
      userUpdates['gender'] = gender.toFirestore();
    }
    batch.set(userRef, userUpdates, SetOptions(merge: true));

    // 2. Populate trainer_profiles collection
    int years = int.tryParse(experience.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    final trainerProfileRef = _firestore.collection(FirestoreCollections.trainerProfiles).doc(uid);
    batch.set(trainerProfileRef, {
      'uid': uid,
      'bio': bio,
      'specialties': specialties,
      'experienceYears': years,
      'cityId': cityId,
      'hourlyRate': hourlyRate ?? 500,
      // Section 6: Initial status is PENDING review
      'verificationStatus': 'PENDING',
      'verificationDocuments': [],
      'certificationDocuments': [],
      'adminReviewNotes': null,
      'approvedAt': null,
      'approvedBy': null,
      'isActive': true,
      'ratingAvg': 5.0,
      'totalReviews': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
