import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/constants/firestore_collections.dart';
import '../core/errors/app_exceptions.dart';
import '../shared/models/trainer_profile_model.dart';
import '../shared/models/user_model.dart';

/// Single, unified authentication service for TRAIN Z (both Clients and Trainers).
/// Roles and permissions are strictly decoupled from public authentication tokens.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Checks if current authenticated user has verified their email address
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

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
    final doc = await _firestore.collection(FirestoreCollections.users).doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromDocument(doc);
  }

  /// Fetch strongly-typed TrainerProfileModel
  Future<TrainerProfileModel?> getTrainerProfile(String uid) async {
    if (uid.trim().isEmpty) return null;
    final doc = await _firestore.collection(FirestoreCollections.trainerProfiles).doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;
    return TrainerProfileModel.fromDocument(doc);
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
      return TrainerProfileModel.fromDocument(snapshot);
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
