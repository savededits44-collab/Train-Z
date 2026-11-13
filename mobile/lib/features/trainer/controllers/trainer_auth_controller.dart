import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/validators.dart';
import '../../../services/auth_service.dart';
import '../../../services/trainer_profile_service.dart';
import '../../../shared/models/trainer_profile_model.dart';
import '../../../shared/models/user_model.dart';

enum TrainerAuthNavigationTarget {
  verifyEmail,
  categorySelection,
  pendingApproval,
  approved,
  rejected,
  suspended,
}

/// Dedicated authentication controller for TRAIN Z Trainer flows.
/// Enforces trusted backend logic, role boundaries, and approval status lifecycle.
class TrainerAuthController extends ChangeNotifier {
  final AuthService _authService;

  TrainerAuthController({AuthService? authService})
      : _authService = authService ?? AuthService();

  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _currentTrainerUser;
  TrainerProfileModel? _currentTrainerProfile;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserModel? get currentTrainerUser => _currentTrainerUser;
  TrainerProfileModel? get currentTrainerProfile => _currentTrainerProfile;
  bool get isAuthenticated => _authService.currentUser != null;
  bool get isEmailVerified => _authService.isEmailVerified;

  // ───────────────────────────────────────────────────────────────────────────
  // Form Validations
  // ───────────────────────────────────────────────────────────────────────────

  static String? validateRegistrationFormStatic({
    required String name,
    required String email,
    required String phoneNumber,
    required String password,
    required String confirmPassword,
  }) {
    final nameError = Validators.validateName(name);
    if (nameError != null) return nameError;

    final emailError = Validators.validateEmail(email);
    if (emailError != null) return emailError;

    final phoneError = Validators.validatePhone(phoneNumber);
    if (phoneError != null) return phoneError;

    final passError = Validators.validatePassword(password);
    if (passError != null) return passError;

    if (password != confirmPassword) {
      return 'Passwords do not match. Please re-enter.';
    }

    return null;
  }

  static String? validateCategorySelectionStatic({
    required TrainerCategory category,
    required double experienceYears,
    bool hasConfirmedCertificate = false,
  }) {
    if (category == TrainerCategory.professionalTrainer) {
      return 'Professional Trainer category is Coming Soon and unavailable at launch.';
    }

    if (category == TrainerCategory.advancedTrainer) {
      if (experienceYears < 3.5) {
        return 'Advanced Trainers must have at least 3.5 years of relevant training experience.';
      }
      if (!hasConfirmedCertificate) {
        return 'You must confirm possession of relevant professional certificates and qualifications.';
      }
    }

    // Standard Trainer (TrainerCategory.trainer):
    // No certificate is required, no formal qualification is required, no minimum experience.
    // Trainers can register and complete their profiles without uploading certificates.

    return null;
  }

  String? validateRegistrationForm({
    required String name,
    required String email,
    required String phoneNumber,
    required String password,
    required String confirmPassword,
  }) {
    return validateRegistrationFormStatic(
      name: name,
      email: email,
      phoneNumber: phoneNumber,
      password: password,
      confirmPassword: confirmPassword,
    );
  }

  String? validateCategorySelection({
    required TrainerCategory category,
    required double experienceYears,
    bool hasConfirmedCertificate = false,
  }) {
    return validateCategorySelectionStatic(
      category: category,
      experienceYears: experienceYears,
      hasConfirmedCertificate: hasConfirmedCertificate,
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Trainer Registration
  // ───────────────────────────────────────────────────────────────────────────

  /// Registers a new Trainer account.
  /// Strict security: strictly assigns [UserRole.trainer], sets verification status to PENDING.
  Future<bool> registerTrainer({
    required String name,
    required String email,
    required String phoneNumber,
    required String password,
    required String confirmPassword,
    required TrainerCategory category,
    double experienceYears = 0.0,
    bool hasConfirmedCertificate = false,
  }) async {
    _clearError();

    final formError = validateRegistrationForm(
      name: name,
      email: email,
      phoneNumber: phoneNumber,
      password: password,
      confirmPassword: confirmPassword,
    );
    if (formError != null) {
      _setError(formError);
      return false;
    }

    final categoryError = validateCategorySelection(
      category: category,
      experienceYears: experienceYears,
      hasConfirmedCertificate: hasConfirmedCertificate,
    );
    if (categoryError != null) {
      _setError(categoryError);
      return false;
    }

    _setLoading(true);
    try {
      final credential = await _authService.signUpWithEmail(
        name: name,
        email: email,
        password: password,
        phoneNumber: phoneNumber,
        requestedRole: UserRole.trainer, // Strict TRAINER role assignment
        trainerCategory: category,
        experienceYears: experienceYears,
      );

      final uid = credential.user?.uid;
      if (uid != null) {
        _currentTrainerUser = await _authService.getUserModel(uid);
        _currentTrainerProfile = await _authService.getTrainerProfile(uid);
      }

      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      _setError(_resolveFirebaseAuthError(e));
      return false;
    } on TrainZException catch (e) {
      _setLoading(false);
      _setError(e.message);
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('An unexpected error occurred during registration. Please try again.');
      return false;
    }
  }

  /// Assigns category and experience for an already-authenticated trainer user.
  Future<bool> assignCategoryForCurrentTrainer({
    required TrainerCategory category,
    double experienceYears = 0.0,
    bool hasConfirmedCertificate = false,
  }) async {
    _clearError();
    final categoryError = validateCategorySelection(
      category: category,
      experienceYears: experienceYears,
      hasConfirmedCertificate: hasConfirmedCertificate,
    );
    if (categoryError != null) {
      _setError(categoryError);
      return false;
    }

    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      _setError('User session expired. Please log in again.');
      return false;
    }

    _setLoading(true);
    try {
      await _authService.initializeTrainerProfile(
        uid: uid,
        category: category,
        experienceYears: experienceYears,
      );
      _currentTrainerUser = await _authService.getUserModel(uid);
      _currentTrainerProfile = await _authService.getTrainerProfile(uid);
      if (_currentTrainerProfile != null) {
        TrainerProfileService.instance.populateFromModel(_currentTrainerProfile!);
      }
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to save category. Please try again.');
      return false;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Trainer Login
  // ───────────────────────────────────────────────────────────────────────────

  /// Authenticates trainer and evaluates routing destination based on verification status.
  Future<TrainerAuthNavigationTarget?> loginTrainer({
    required String email,
    required String password,
  }) async {
    _clearError();

    final emailError = Validators.validateEmail(email);
    if (emailError != null) {
      _setError(emailError);
      return null;
    }

    if (password.isEmpty) {
      _setError('Password is required.');
      return null;
    }

    _setLoading(true);
    try {
      final credential = await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        _setLoading(false);
        _setError('No session returned. Please try logging in again.');
        return null;
      }

      // Fetch user profile from Firestore
      final userModel = await _authService.getUserModel(user.uid);
      if (userModel == null) {
        _setLoading(false);
        _setError('User profile not found. Please contact support@trainz.app.');
        return null;
      }

      // Role Protection: Only TRAINER accounts may log in via the Trainer portal
      if (userModel.role != UserRole.trainer) {
        await _authService.signOut();
        _setLoading(false);
        _setError(
          'This portal is for TRAIN Z Trainers. Client accounts must log in via the Athlete portal.',
        );
        return null;
      }

      if (userModel.status == UserStatus.suspended) {
        await _authService.signOut();
        _setLoading(false);
        _setError('Your account is currently suspended. Please contact support@trainz.app.');
        return TrainerAuthNavigationTarget.suspended;
      }

      _currentTrainerUser = userModel;

      // Email verification check
      final isDemo = !kReleaseMode && AuthService.isDemoTrainer(email: email, uid: user.uid);
      if (!isDemo && !user.emailVerified && !userModel.isEmailVerified) {
        _setLoading(false);
        return TrainerAuthNavigationTarget.verifyEmail;
      }

      // Fetch trainer profile
      final trainerProfile = await _authService.getTrainerProfile(user.uid);
      _currentTrainerProfile = trainerProfile;
      if (trainerProfile != null) {
        TrainerProfileService.instance.populateFromModel(trainerProfile);
      }
      _setLoading(false);

      if (trainerProfile == null) {
        return TrainerAuthNavigationTarget.categorySelection;
      }

      // Evaluate Admin Verification Lifecycle
      switch (trainerProfile.verificationStatus) {
        case TrainerVerificationStatus.pending:
          return TrainerAuthNavigationTarget.pendingApproval;
        case TrainerVerificationStatus.rejected:
          return TrainerAuthNavigationTarget.rejected;
        case TrainerVerificationStatus.suspended:
          return TrainerAuthNavigationTarget.suspended;
        case TrainerVerificationStatus.approved:
          return TrainerAuthNavigationTarget.approved;
      }
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      _setError(_resolveFirebaseAuthError(e));
      return null;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to log in. Please check your network connection.');
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Status Refresher & Email Verification
  // ───────────────────────────────────────────────────────────────────────────

  /// Refreshes current trainer user and profile from Firestore to catch live Admin approvals
  Future<TrainerProfileModel?> refreshTrainerStatus() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return null;

    _setLoading(true);
    try {
      final updatedUser = await _authService.getUserModel(uid);
      final updatedProfile = await _authService.getTrainerProfile(uid);

      if (updatedUser != null) _currentTrainerUser = updatedUser;
      if (updatedProfile != null) {
        _currentTrainerProfile = updatedProfile;
        TrainerProfileService.instance.populateFromModel(updatedProfile);
      }

      _setLoading(false);
      return updatedProfile;
    } catch (e) {
      _setLoading(false);
      return null;
    }
  }

  /// Reloads user and checks if email is verified
  Future<bool> checkEmailVerification() async {
    _setLoading(true);
    try {
      final verified = await _authService.reloadAndCheckEmailVerification();
      if (verified && _currentTrainerUser != null) {
        _currentTrainerUser = _currentTrainerUser!.copyWith(isEmailVerified: true);
      }
      _setLoading(false);
      return verified;
    } catch (e) {
      _setLoading(false);
      return false;
    }
  }

  /// Dispatches email verification link
  Future<bool> resendVerificationEmail() async {
    try {
      await _authService.sendEmailVerification();
      return true;
    } catch (e) {
      _setError('Failed to resend verification email. Please try again later.');
      return false;
    }
  }

  /// Sends password reset email
  Future<bool> sendPasswordReset(String email) async {
    _clearError();
    final emailError = Validators.validateEmail(email);
    if (emailError != null) {
      _setError(emailError);
      return false;
    }

    _setLoading(true);
    try {
      await _authService.sendPasswordResetEmail(email);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setLoading(false);
      _setError(_resolveFirebaseAuthError(e));
      return false;
    } catch (e) {
      _setLoading(false);
      _setError('Failed to send password reset email. Please try again.');
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    _currentTrainerUser = null;
    _currentTrainerProfile = null;
    _clearError();
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Internal Helpers
  // ───────────────────────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  String _resolveFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account already exists with this email address. Please log in.';
      case 'invalid-email':
        return 'The email address format is invalid.';
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password. Please verify and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support@trainz.app.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again in a few minutes.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
    }
  }
}
