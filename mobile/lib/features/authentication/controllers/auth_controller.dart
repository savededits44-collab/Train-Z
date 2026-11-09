import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../services/auth_service.dart';
import '../../../shared/models/user_model.dart';

/// Presentation-layer state manager for authentication and user session.
class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  StreamSubscription<UserModel?>? _userSub;

  AuthController() {
    _initSessionListener();
  }

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _authService.currentUser != null;

  void _initSessionListener() {
    _authService.authStateChanges.listen((firebaseUser) {
      if (firebaseUser == null) {
        _currentUser = null;
        _userSub?.cancel();
        notifyListeners();
      } else {
        _userSub?.cancel();
        _userSub = _authService.currentUserProfileStream.listen((profile) {
          _currentUser = profile;
          notifyListeners();
        });
      }
    });
  }

  /// Sign In with Email
  Future<bool> signInWithEmail(String email, String password) async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.signInWithEmail(email: email, password: password);
      _setLoading(false);
      return true;
    } on TrainZException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Sign Up with Email
  Future<bool> signUpWithEmail({
    required String name,
    required String email,
    required String password,
    UserRole? requestedRole,
    Gender? gender,
  }) async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.signUpWithEmail(
        name: name,
        email: email,
        password: password,
        requestedRole: requestedRole,
        gender: gender,
      );
      _setLoading(false);
      return true;
    } on TrainZException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Sign In with Google
  Future<bool> signInWithGoogle({UserRole? requestedRole}) async {
    _setLoading(true);
    _clearError();
    try {
      final credential = await _authService.signInWithGoogle(requestedRole: requestedRole);
      _setLoading(false);
      return credential != null;
    } on TrainZException catch (e) {
      _setError(e.message);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Password Reset
  Future<bool> sendPasswordReset(String email) async {
    _setLoading(true);
    _clearError();
    try {
      await _authService.sendPasswordResetEmail(email);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  /// Dispatches email verification
  Future<void> sendEmailVerification() async {
    await _authService.sendEmailVerification();
  }

  /// Sign Out
  Future<void> signOut() async {
    _setLoading(true);
    await _authService.signOut();
    _currentUser = null;
    _setLoading(false);
  }

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

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }
}

