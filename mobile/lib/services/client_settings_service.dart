import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../core/constants/firestore_collections.dart';
import '../core/errors/app_exceptions.dart';
import '../core/utils/validators.dart';
import '../shared/models/client_profile_model.dart';
import '../shared/models/notification_preferences_model.dart';
import '../shared/models/user_model.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';

/// Core service governing Client Settings, Personal Information, Security,
/// Privacy Controls, Notification Preferences, and Account Deletion for TRAIN Z.
class ClientSettingsService {
  ClientSettingsService._internal();
  static final ClientSettingsService instance = ClientSettingsService._internal();
  factory ClientSettingsService() => instance;

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore? get _firestore {
    try {
      if (_firestoreInstance != null) return _firestoreInstance;
      if (Firebase.apps.isEmpty) return null;
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  void setFirestoreForTesting(FirebaseFirestore? firestore) {
    _firestoreInstance = firestore;
  }

  FirebaseAuth? _authInstance;
  FirebaseAuth get _auth {
    try {
      return _authInstance ?? FirebaseAuth.instance;
    } catch (_) {
      return _authInstance ?? FirebaseAuth.instance;
    }
  }

  void setAuthForTesting(FirebaseAuth? auth) {
    _authInstance = auth;
  }

  // ── In-Memory Mock Store for Testing & Offline Fallback ──
  final Map<String, NotificationPreferencesModel> _mockPreferences = {};
  final Map<String, Map<String, dynamic>> _mockDeletionRequests = {};
  final Map<String, UserModel> _mockUsers = {};
  final Map<String, ClientProfileModel> _mockProfiles = {};

  void setMockUser(UserModel user) => _mockUsers[user.uid] = user;
  UserModel? getMockUser(String uid) => _mockUsers[uid];

  void setMockProfile(ClientProfileModel profile) => _mockProfiles[profile.uid] = profile;
  ClientProfileModel? getMockProfile(String uid) => _mockProfiles[uid];

  void setMockPreferences(String uid, NotificationPreferencesModel prefs) {
    _mockPreferences[uid] = prefs;
    NotificationService.instance.setUserPreferences(uid, prefs);
  }

  Map<String, dynamic>? getMockDeletionRequest(String uid) => _mockDeletionRequests[uid];

  void resetMockStore() {
    _mockPreferences.clear();
    _mockDeletionRequests.clear();
    _mockUsers.clear();
    _mockProfiles.clear();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 1. Personal Information Management
  // ───────────────────────────────────────────────────────────────────────────

  /// Updates personal profile information with strict validation
  Future<bool> updatePersonalInfo({
    required String uid,
    required String displayName,
    String? phoneNumber,
    DateTime? dateOfBirth,
    String? preferredVenue,
    String? emergencyContact,
    List<String>? fitnessGoals,
    String? fitnessLevel,
  }) async {
    if (uid.trim().isEmpty) {
      throw const SettingsException('User ID is required to update personal information.');
    }

    final nameError = Validators.validateName(displayName);
    if (nameError != null) {
      throw SettingsException(nameError);
    }

    if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
      final phoneError = Validators.validatePhone(phoneNumber);
      if (phoneError != null) {
        throw SettingsException(phoneError);
      }
    }

    final trimmedName = displayName.trim();
    final trimmedPhone = phoneNumber?.trim();

    // 1. Update in-memory mock store
    final existingUser = _mockUsers[uid];
    if (existingUser != null) {
      _mockUsers[uid] = existingUser.copyWith(
        displayName: trimmedName,
        phoneNumber: trimmedPhone,
        updatedAt: DateTime.now(),
      );
    }

    final existingProfile = _mockProfiles[uid] ?? ClientProfileModel(uid: uid);
    _mockProfiles[uid] = ClientProfileModel(
      uid: uid,
      fitnessGoals: fitnessGoals ?? existingProfile.fitnessGoals,
      fitnessLevel: fitnessLevel ?? existingProfile.fitnessLevel,
      preferredTrainingTypes: existingProfile.preferredTrainingTypes,
      fitnessInterests: existingProfile.fitnessInterests,
      dateOfBirth: dateOfBirth ?? existingProfile.dateOfBirth,
      preferredCityId: existingProfile.preferredCityId,
      preferredTrainingLocation: preferredVenue ?? existingProfile.preferredTrainingLocation,
      privateAddress: existingProfile.privateAddress,
      activePackageId: existingProfile.activePackageId,
      emergencyContact: emergencyContact?.trim() ?? existingProfile.emergencyContact,
      favoriteTrainerIds: existingProfile.favoriteTrainerIds,
      updatedAt: DateTime.now(),
    );

    // 2. Persist to Firestore if available
    final fs = _firestore;
    if (fs != null) {
      try {
        final batch = fs.batch();
        final userRef = fs.collection(FirestoreCollections.users).doc(uid);
        final userUpdates = <String, dynamic>{
          'displayName': trimmedName,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (trimmedPhone != null) userUpdates['phoneNumber'] = trimmedPhone;
        batch.set(userRef, userUpdates, SetOptions(merge: true));

        final profileRef = fs.collection(FirestoreCollections.clientProfiles).doc(uid);
        final profileUpdates = <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (preferredVenue != null) profileUpdates['preferredTrainingLocation'] = preferredVenue;
        if (dateOfBirth != null) profileUpdates['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);
        if (emergencyContact != null) profileUpdates['emergencyContact'] = emergencyContact.trim();
        if (fitnessGoals != null) profileUpdates['fitnessGoals'] = fitnessGoals;
        if (fitnessLevel != null) profileUpdates['fitnessLevel'] = fitnessLevel;
        batch.set(profileRef, profileUpdates, SetOptions(merge: true));

        await batch.commit();
      } catch (e) {
        // Fallback to local memory updates in offline mode
      }
    }

    // 3. Update Firebase Auth display name if session exists
    try {
      final user = _auth.currentUser;
      if (user != null && user.uid == uid) {
        await user.updateDisplayName(trimmedName);
      }
    } catch (_) {}

    return true;
  }

  /// Uploads and sets a new profile avatar securely in Firebase Storage
  Future<String> updateProfilePhoto({
    required String uid,
    required File imageFile,
    void Function(double progress)? onProgress,
  }) async {
    if (uid.trim().isEmpty) {
      throw const SettingsException('User ID is required to update profile picture.');
    }

    final downloadUrl = await StorageService.instance.uploadProfilePicture(
      userId: uid,
      file: imageFile,
      onProgress: onProgress,
    );

    // Update in mock store
    final existing = _mockUsers[uid];
    if (existing != null) {
      _mockUsers[uid] = existing.copyWith(photoUrl: downloadUrl);
    }

    // Update Auth user profile URL
    try {
      await _auth.currentUser?.updatePhotoURL(downloadUrl);
    } catch (_) {}

    return downloadUrl;
  }

  /// Sends email verification or update verification to new email
  Future<void> requestEmailUpdate(String newEmail) async {
    final emailError = Validators.validateEmail(newEmail);
    if (emailError != null) {
      throw SettingsException(emailError);
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('No authenticated session found.');
    }

    try {
      // Firebase Auth verifyBeforeUpdateEmail sends a verification link to new email
      await user.verifyBeforeUpdateEmail(newEmail.trim());
    } on FirebaseAuthException catch (e) {
      throw SettingsException(_resolveAuthErrorCode(e));
    } catch (e) {
      throw SettingsException('Could not initiate email update: $e');
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 2. Account & Security Management
  // ───────────────────────────────────────────────────────────────────────────

  /// Changes the user's password after validating current password reauthentication
  /// Passwords are NEVER stored in Firestore or local storage.
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (currentPassword.isEmpty) {
      throw const SettingsException('Please enter your current password.');
    }

    if (newPassword != confirmPassword) {
      throw const SettingsException('New passwords do not match.');
    }

    // Validate password complexity
    final strengthError = validateNewPassword(newPassword);
    if (strengthError != null) {
      throw SettingsException(strengthError);
    }

    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw const AuthException('No active authenticated user session found.');
    }

    try {
      // 1. Re-authenticate user before allowing password change
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);

      // 2. Apply new password
      await user.updatePassword(newPassword);

      // 3. Emit mandatory account security notification
      await NotificationService.instance.sendNotification(
        userId: user.uid,
        title: 'Security Alert: Password Changed',
        body: 'Your TRAIN Z account password was successfully updated.',
        type: 'SECURITY_ALERT',
        data: {'action': 'PASSWORD_CHANGED', 'timestamp': DateTime.now().toIso8601String()},
      );

      return true;
    } on FirebaseAuthException catch (e) {
      throw SettingsException(_resolveAuthErrorCode(e));
    } catch (e) {
      if (e is SettingsException) rethrow;
      throw SettingsException('Failed to update password: $e');
    }
  }

  /// Password complexity validator (minimum 8 chars, uppercase, lowercase, digit)
  static String? validateNewPassword(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter (A-Z).';
    }
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter (a-z).';
    }
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number (0-9).';
    }
    return null;
  }

  /// Sends password reset email
  Future<void> sendPasswordReset(String email) async {
    final emailError = Validators.validateEmail(email);
    if (emailError != null) {
      throw SettingsException(emailError);
    }
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw SettingsException(_resolveAuthErrorCode(e));
    }
  }

  /// Sends email verification link
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('No authenticated session found.');
    }
    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw SettingsException(_resolveAuthErrorCode(e));
    }
  }

  /// Reloads user and checks verification status
  Future<bool> reloadAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
      final verified = _auth.currentUser?.emailVerified ?? false;
      if (verified) {
        final fs = _firestore;
        if (fs != null) {
          await fs.collection(FirestoreCollections.users).doc(user.uid).set({
            'isEmailVerified': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
      return verified;
    } catch (_) {
      return false;
    }
  }

  /// Signs out securely
  Future<void> signOut() async {
    await AuthService().signOut();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 3. Notification Preferences Management
  // ───────────────────────────────────────────────────────────────────────────

  /// Streams real-time notification preferences for a client
  Stream<NotificationPreferencesModel> streamNotificationPreferences(String uid) {
    if (uid.trim().isEmpty) {
      return Stream.value(const NotificationPreferencesModel());
    }

    final fs = _firestore;
    if (fs == null) {
      final mock = _mockPreferences[uid] ?? const NotificationPreferencesModel();
      return Stream.value(mock);
    }

    try {
      return fs
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection(FirestoreCollections.userSettings)
          .doc('notifications')
          .snapshots()
          .map((snap) {
            if (!snap.exists) {
              return _mockPreferences[uid] ?? const NotificationPreferencesModel();
            }
            final prefs = NotificationPreferencesModel.fromDocument(snap);
            NotificationService.instance.setUserPreferences(uid, prefs);
            return prefs;
          })
          .handleError((_) {
            return _mockPreferences[uid] ?? const NotificationPreferencesModel();
          });
    } catch (_) {
      final mock = _mockPreferences[uid] ?? const NotificationPreferencesModel();
      return Stream.value(mock);
    }
  }

  /// Updates and persists notification preferences
  Future<bool> updateNotificationPreferences(
    String uid,
    NotificationPreferencesModel preferences,
  ) async {
    if (uid.trim().isEmpty) return false;

    // 1. Update mock store and NotificationService cache
    _mockPreferences[uid] = preferences;
    NotificationService.instance.setUserPreferences(uid, preferences);

    // 2. Persist to Firestore: save to users/{userId}/settings/notifications
    final fs = _firestore;
    if (fs != null) {
      try {
        final settingsCol = fs
            .collection(FirestoreCollections.users)
            .doc(uid)
            .collection(FirestoreCollections.userSettings);

        final map = preferences.toMap();
        await Future.wait([
          settingsCol.doc('notifications').set(map, SetOptions(merge: true)),
          settingsCol.doc('notification_preferences').set(map, SetOptions(merge: true)),
        ]);
      } catch (_) {}
    }

    return true;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // 4. Account Deletion Workflow (Trusted Backend & Secure Anonymization)
  // ───────────────────────────────────────────────────────────────────────────

  /// Requests secure account deletion:
  /// 1. Re-authenticates client with current password to prevent accidental / unauthorized deletion.
  /// 2. Records deletion request in Firestore.
  /// 3. Performs client data anonymization (anonymizes name, phone, residential address).
  /// 4. Preserves statutory transaction & invoice audit records per tax/financial compliance.
  /// 5. Revokes authentication and signs out cleanly.
  Future<bool> requestAccountDeletion({
    required String uid,
    required String currentPassword,
    String? reason,
  }) async {
    if (uid.trim().isEmpty) {
      throw const SettingsException('User ID is required for account deletion.');
    }

    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw const AuthException('No active authenticated session found.');
    }

    // 1. Mandatory Re-authentication
    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw SettingsException(_resolveAuthErrorCode(e));
    } catch (e) {
      throw SettingsException('Identity verification failed: $e');
    }

    final now = DateTime.now();

    // 2. Record deletion request in mock store
    _mockDeletionRequests[uid] = {
      'userId': uid,
      'email': user.email,
      'status': 'PROCESSED',
      'reason': reason ?? 'Client voluntary account closure',
      'requestedAt': now,
      'retentionNotice': 'Financial transaction records retained per statutory compliance.',
    };

    // 3. Persist deletion request and anonymize records in Firestore
    final fs = _firestore;
    if (fs != null) {
      try {
        final batch = fs.batch();

        final delReqRef = fs.collection(FirestoreCollections.deletionRequests).doc(uid);
        batch.set(delReqRef, {
          'userId': uid,
          'status': 'PROCESSED',
          'reason': reason ?? 'Client voluntary account closure',
          'requestedAt': FieldValue.serverTimestamp(),
        });

        // Anonymize user profile document
        final userRef = fs.collection(FirestoreCollections.users).doc(uid);
        batch.update(userRef, {
          'displayName': 'Deleted Athlete',
          'phoneNumber': null,
          'photoUrl': null,
          'status': 'DELETED',
          'updatedAt': FieldValue.serverTimestamp(),
          'deletedAt': FieldValue.serverTimestamp(),
        });

        // Clear sensitive private fields from client_profiles
        final clientProfileRef = fs.collection(FirestoreCollections.clientProfiles).doc(uid);
        batch.update(clientProfileRef, {
          'privateAddress': null,
          'emergencyContact': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Record statutory compliance audit record
        final auditRef = fs.collection(FirestoreCollections.deletionAudits).doc(uid);
        batch.set(auditRef, {
          'userId': uid,
          'role': 'CLIENT',
          'deletedAt': FieldValue.serverTimestamp(),
          'reason': reason ?? 'Client voluntary account closure',
          'statutoryRetentionNotice': 'Payment, booking reference, and invoice transactions retained per statutory financial auditing requirements.',
        });

        await batch.commit();
      } catch (_) {}
    }

    // 4. Delete Firebase Auth user if available
    try {
      await user.delete();
    } catch (_) {
      // If user.delete() requires immediate signout fallback
      await signOut();
    }

    return true;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Helper: Resolve Firebase Auth Error Codes
  // ───────────────────────────────────────────────────────────────────────────

  String _resolveAuthErrorCode(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect current password. Please try again.';
      case 'requires-recent-login':
        return 'This sensitive operation requires a recent sign-in. Please log out and sign back in to continue.';
      case 'user-mismatch':
        return 'The supplied credentials do not correspond to the currently signed-in user.';
      case 'user-not-found':
        return 'No user found for these credentials.';
      case 'weak-password':
        return 'The new password is too weak. Please include at least 8 characters with letters and numbers.';
      case 'email-already-in-use':
        return 'The specified email address is already in use by another account.';
      case 'invalid-email':
        return 'The email address format is invalid.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a few moments before trying again.';
      default:
        return e.message ?? 'Authentication error (${e.code}).';
    }
  }
}
