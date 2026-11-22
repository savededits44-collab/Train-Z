import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/constants/firestore_collections.dart';
import '../core/errors/app_exceptions.dart';
import '../shared/models/trainer_profile_model.dart';
import '../shared/models/user_model.dart';
import 'booking_service.dart';
import 'client_settings_service.dart';
import 'credit_service.dart';
import 'notification_service.dart';
import 'review_service.dart';
import 'support_service.dart';

/// Single, unified authentication service for TRAIN Z (both Clients and Trainers).
/// Roles and permissions are strictly decoupled from public authentication tokens.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  static AuthService get instance => _instance;
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

  UserRole? _cachedRole;
  UserRole? get currentRole => _cachedRole;

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
      final user = _auth.currentUser;
      if (user == null) return false;
      final isGoogle = user.providerData.any((p) => p.providerId == 'google.com');
      return user.emailVerified || isGoogle;
    } catch (_) {
      return false;
    }
  }

  /// Stream of current typed UserModel from Firestore
  Stream<UserModel?> get currentUserProfileStream {
    try {
      final uid = currentUser?.uid;
      if (uid == null || uid.trim().isEmpty) return Stream.value(null);
      return _firestore
          .collection(FirestoreCollections.users)
          .doc(uid)
          .snapshots()
          .map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) return null;
        return UserModel.fromDocument(snapshot);
      });
    } catch (_) {
      return Stream.value(null);
    }
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
      await getUserModel(user.uid);
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
      final isGoogle = user.providerData.any((p) => p.providerId == 'google.com');
      final isVerified = user.emailVerified || isGoogle;
      // Record last login timestamp without overwriting existing backend verification
      final loginUpdates = <String, dynamic>{
        'lastLoginAt': FieldValue.serverTimestamp(),
      };
      if (isVerified) {
        loginUpdates['isEmailVerified'] = true;
      }
      await _firestore
          .collection(FirestoreCollections.users)
          .doc(user.uid)
          .set(loginUpdates, SetOptions(merge: true));
      await getUserModel(user.uid);
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

  DateTime? _lastVerificationEmailSentAt;
  static const int resendCooldownSeconds = 60;

  int get resendCooldownRemaining {
    if (_lastVerificationEmailSentAt == null) return 0;
    final diff = DateTime.now().difference(_lastVerificationEmailSentAt!).inSeconds;
    return diff < resendCooldownSeconds ? resendCooldownSeconds - diff : 0;
  }

  /// Sends email verification link to current authenticated user with cooldown protection
  Future<void> sendEmailVerification({bool enforceCooldown = true}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('No authenticated user session found.');
    }

    if (enforceCooldown && resendCooldownRemaining > 0) {
      throw AuthException(
        'Please wait ${resendCooldownRemaining}s before requesting another verification email.',
      );
    }

    try {
      await user.sendEmailVerification();
      _lastVerificationEmailSentAt = DateTime.now();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'too-many-requests') {
        throw const AuthException(
          'Too many verification requests sent. Please wait a few minutes before trying again.',
        );
      } else if (e.code == 'user-token-expired') {
        throw const AuthException(
          'Your session has expired. Please sign in again to receive a verification email.',
        );
      } else if (e.code == 'network-request-failed') {
        throw const AuthException(
          'Network connection unavailable. Please check your internet connection.',
        );
      }
      throw AuthException(e.message ?? 'Failed to send verification email. Please try again.');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to dispatch verification email: $e');
    }
  }

  /// Reloads user from Firebase Authentication and checks if email is verified.
  /// Strictly verifies against Firebase Auth and updates Firestore upon confirmation.
  Future<bool> reloadAndCheckEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      await user.reload();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-disabled') {
        throw const AuthException('This account has been disabled. Please contact support.');
      } else if (e.code == 'user-not-found') {
        throw const AuthException('User account no longer exists. Please sign up again.');
      } else if (e.code == 'network-request-failed') {
        throw const AuthException('Network connection error. Please check your internet connection.');
      }
      return false;
    } catch (_) {
      return false;
    }

    final updated = _auth.currentUser;
    if (updated == null) return false;

    final isGoogle = updated.providerData.any((p) => p.providerId == 'google.com');
    final verified = updated.emailVerified || isGoogle;

    if (verified) {
      try {
        await _firestore
            .collection(FirestoreCollections.users)
            .doc(user.uid)
            .set({
          'isEmailVerified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Notice: Error syncing verified email to Firestore: $e');
      }
    }

    return verified;
  }

  /// Password reset link to user's registered email
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Change password for email/password authenticated user.
  /// Requires re-authenticating with [currentPassword] before updating to [newPassword].
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (newPassword.trim().length < 6) {
      throw const AuthException('New password must be at least 6 characters.');
    }

    final user = currentUser;
    if (user == null) {
      throw const AuthException('No authenticated user session found.');
    }

    final email = user.email;
    if (email != null && email.isNotEmpty) {
      try {
        final cred = EmailAuthProvider.credential(
          email: email,
          password: currentPassword.trim(),
        );
        await user.reauthenticateWithCredential(cred);
      } catch (e) {
        throw AuthException('Current password incorrect or reauthentication failed: $e');
      }
    }

    await user.updatePassword(newPassword.trim());
  }

  /// Reauthenticates current user session with password
  Future<void> reauthenticate(String password) async {
    final user = currentUser;
    if (user == null) {
      throw const AuthException('No authenticated user session found.');
    }
    final email = user.email;
    if (email == null || email.isEmpty) return;

    final cred = EmailAuthProvider.credential(
      email: email,
      password: password.trim(),
    );
    await user.reauthenticateWithCredential(cred);
  }

  /// Updates email address with Firebase Authentication verification
  Future<void> updateEmailAddress(String newEmail) async {
    final cleanEmail = newEmail.trim().toLowerCase();
    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw const AuthException('Please provide a valid email address.');
    }

    final user = currentUser;
    if (user == null) {
      throw const AuthException('No authenticated user session found.');
    }

    try {
      await user.verifyBeforeUpdateEmail(cleanEmail);
    } catch (e) {
      debugPrint('Notice: Email verification trigger: $e');
    }

    await _firestore.collection(FirestoreCollections.users).doc(user.uid).set({
      'email': cleanEmail,
      'isEmailVerified': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Updates phone number in users and trainer_profiles
  Future<void> updatePhoneNumber(String newPhone) async {
    final clean = newPhone.trim();
    if (clean.length < 10) {
      throw const AuthException('Phone number must have at least 10 digits.');
    }

    final user = currentUser;
    if (user == null) {
      throw const AuthException('No authenticated user session found.');
    }

    final batch = _firestore.batch();
    final userRef = _firestore.collection(FirestoreCollections.users).doc(user.uid);
    batch.set(userRef, {
      'phoneNumber': clean,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final trainerRef = _firestore.collection(FirestoreCollections.trainerProfiles).doc(user.uid);
    batch.set(trainerRef, {
      'mobileNumber': clean,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// Sign out from both Firebase and Google session and securely clear in-memory caches
  Future<void> signOut() async {
    _cachedRole = null;
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (_) {}

    // Securely clear sensitive in-memory session caches to prevent cross-account leaks
    try {
      BookingService.instance.clearBookings();
      ClientSettingsService.instance.resetMockStore();
      CreditService().resetMockCredits();
      SupportService.instance.resetMockTickets();
      ReviewService.instance.resetMockReviews();
      NotificationService.instance.clearCache();
    } catch (_) {}
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
        _cachedRole = model.role;
        return model;
      }
    } catch (e) {
      debugPrint('Notice: Error fetching user model: $e');
    }
    return null;
  }

  /// Fetch strongly-typed TrainerProfileModel
  Future<TrainerProfileModel?> getTrainerProfile(String uid) async {
    if (uid.trim().isEmpty) return null;
    try {
      final doc = await _firestore.collection(FirestoreCollections.trainerProfiles).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return TrainerProfileModel.fromDocument(doc);
      }
    } catch (e) {
      debugPrint('Notice: Error fetching trainer profile: $e');
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

  /// Initialize or update category and experience for an existing authenticated trainer
  Future<void> initializeTrainerProfile({
    required String uid,
    required TrainerCategory category,
    double experienceYears = 0.0,
  }) async {
    final batch = _firestore.batch();
    final userRef = _firestore.collection(FirestoreCollections.users).doc(uid);
    batch.set(userRef, {
      'role': 'TRAINER',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final trainerProfileRef = _firestore.collection(FirestoreCollections.trainerProfiles).doc(uid);
    batch.set(trainerProfileRef, {
      'uid': uid,
      'category': category.toFirestore(),
      'experienceYears': experienceYears,
      'verificationStatus': 'PENDING',
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}
