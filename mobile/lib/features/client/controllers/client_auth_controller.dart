import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/validators.dart';
import '../../../services/auth_service.dart';
import '../../../shared/models/user_model.dart';

enum ClientAuthNavigationTarget {
  verifyEmail,
  profileCompletion,
  clientHome,
}

/// Dedicated authentication controller for TRAIN Z Client user flows.
class ClientAuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _currentClient;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserModel? get currentClient => _currentClient;
  bool get isAuthenticated => _authService.currentUser != null;
  bool get isEmailVerified => _authService.isEmailVerified;

  // ───────────────────────────────────────────────────────────────────────────
  // Client Registration
  // ───────────────────────────────────────────────────────────────────────────

  /// Registers a new Client account with full validation and Firestore synchronization.
  /// Enforces that role is strictly [UserRole.client].
  Future<bool> registerClient({
    required String name,
    required String email,
    required String phoneNumber,
    required String password,
    required String confirmPassword,
    required Gender? gender,
  }) async {
    _clearError();

    // 1. Validate Form Fields
    final nameError = Validators.validateName(name);
    if (nameError != null) {
      _setError(nameError);
      return false;
    }

    final emailError = Validators.validateEmail(email);
    if (emailError != null) {
      _setError(emailError);
      return false;
    }

    final phoneError = Validators.validatePhone(phoneNumber);
    if (phoneError != null) {
      _setError(phoneError);
      return false;
    }

    final passError = Validators.validatePassword(password);
    if (passError != null) {
      _setError(passError);
      return false;
    }

    if (password != confirmPassword) {
      _setError('Passwords do not match. Please re-enter.');
      return false;
    }

    if (gender == null) {
      _setError('Please select your gender for personal trainer matching.');
      return false;
    }

    // 2. Perform Firebase Registration
    _setLoading(true);
    try {
      final credential = await _authService.signUpWithEmail(
        name: name,
        email: email,
        password: password,
        phoneNumber: phoneNumber,
        requestedRole: UserRole.client, // Strict CLIENT role assignment
        gender: gender,
      );

      final uid = credential.user?.uid;
      if (uid != null) {
        _currentClient = await _authService.getUserModel(uid);
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

  // ───────────────────────────────────────────────────────────────────────────
  // Client Login
  // ───────────────────────────────────────────────────────────────────────────

  /// Authenticates client and evaluates routing destination
  Future<ClientAuthNavigationTarget?> loginClient({
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

      // Role check: Only CLIENT accounts may log in here
      if (userModel.role != UserRole.client) {
        await _authService.signOut();
        _setLoading(false);
        _setError(
          'This portal is for Clients. Trainer accounts should log in via the Trainer portal.',
        );
        return null;
      }

      if (userModel.status == UserStatus.suspended) {
        await _authService.signOut();
        _setLoading(false);
        _setError('Your account is currently suspended. Please contact support@trainz.app.');
        return null;
      }

      _currentClient = userModel;
      _setLoading(false);

      // Routing evaluation
      if (!user.emailVerified && !userModel.isEmailVerified) {
        return ClientAuthNavigationTarget.verifyEmail;
      }

      if (!userModel.isOnboarded) {
        return ClientAuthNavigationTarget.profileCompletion;
      }

      return ClientAuthNavigationTarget.clientHome;
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
  // Email Verification
  // ───────────────────────────────────────────────────────────────────────────

  /// Reloads user and checks if email is verified
  Future<bool> checkEmailVerification() async {
    _setLoading(true);
    try {
      final verified = await _authService.reloadAndCheckEmailVerification();
      if (verified && _currentClient != null) {
        _currentClient = _currentClient!.copyWith(isEmailVerified: true);
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
      _setError('Could not send verification email. Please try again in a few moments.');
      return false;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Password Reset
  // ───────────────────────────────────────────────────────────────────────────

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
      _setError('Unable to send password recovery email. Please try again.');
      return false;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Sign Out
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _authService.signOut();
    _currentClient = null;
    notifyListeners();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Internal Helpers
  // ───────────────────────────────────────────────────────────────────────────

  void _setLoading(bool val) {
    _isLoading = val;
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
        return 'The email address is improperly formatted.';
      case 'operation-not-allowed':
        return 'Email/password authentication is not enabled.';
      case 'weak-password':
        return 'The password chosen is too weak. Please choose a stronger password.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No registered account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password or credentials. Please try again.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a moment and try again.';
      default:
        return e.message ?? 'Authentication failed (${e.code}).';
    }
  }
}

