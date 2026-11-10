import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/utils/validators.dart';
import '../../../services/auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';
import '../../../shared/models/client_profile_model.dart';
import '../../../shared/models/user_model.dart';

/// Controller managing Client Profile setup, edits, image uploads, and completion calculations.
class ClientProfileController extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();

  UserModel? _user;
  ClientProfileModel? _profile;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _errorMessage;
  File? _selectedPhotoFile;

  ClientProfileController() {
    loadProfile();
  }

  UserModel? get user => _user;
  ClientProfileModel? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isUploadingPhoto => _isUploadingPhoto;
  String? get errorMessage => _errorMessage;
  File? get selectedPhotoFile => _selectedPhotoFile;

  /// Real-time profile completion score (0 - 100%)
  int get completionPercentage {
    if (_user == null) return 0;
    final p = _profile ?? ClientProfileModel(uid: _user!.uid);
    return p.calculateCompletion(
      hasName: (_user!.displayName != null && _user!.displayName!.trim().length >= 2),
      hasPhone: (_user!.phoneNumber != null && _user!.phoneNumber!.trim().isNotEmpty),
      hasPhoto: (_user!.photoUrl != null && _user!.photoUrl!.isNotEmpty) || _selectedPhotoFile != null,
      hasGender: _user!.gender != null,
    );
  }

  /// Loads client user and profile from Firestore
  Future<void> loadProfile() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    _setLoading(true);
    try {
      _user = await _authService.getUserModel(uid);
      _profile = await _firestoreService.getClientProfile(uid);
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load profile details: $e');
      _setLoading(false);
    }
  }

  /// Pick profile image from Gallery or Camera
  Future<File?> pickProfileImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (picked != null) {
        _selectedPhotoFile = File(picked.path);
        notifyListeners();
        return _selectedPhotoFile;
      }
      return null;
    } catch (e) {
      _setError('Failed to pick image: $e');
      return null;
    }
  }

  /// Saves client personal and fitness profile
  Future<bool> saveProfile({
    required String fullName,
    required String phoneNumber,
    required DateTime? dateOfBirth,
    required List<String> fitnessGoals,
    required String? fitnessLevel,
    required List<String> preferredTrainingTypes,
    required List<String> fitnessInterests,
    required String preferredCityId,
    required String? preferredTrainingLocation,
    required String? privateAddress,
    required String? emergencyContact,
  }) async {
    _clearError();

    // 1. Validations
    final nameError = Validators.validateName(fullName);
    if (nameError != null) {
      _setError(nameError);
      return false;
    }

    final phoneError = Validators.validatePhone(phoneNumber);
    if (phoneError != null) {
      _setError(phoneError);
      return false;
    }

    if (fitnessGoals.isEmpty) {
      _setError('Please select at least one fitness goal.');
      return false;
    }

    if (fitnessLevel == null || fitnessLevel.isEmpty) {
      _setError('Please select your current fitness experience level.');
      return false;
    }

    if (preferredTrainingTypes.isEmpty) {
      _setError('Please select at least one preferred training type.');
      return false;
    }

    if (preferredCityId.isEmpty) {
      _setError('Please select your preferred launch city.');
      return false;
    }

    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      _setError('No active user session found.');
      return false;
    }

    _isSaving = true;
    notifyListeners();

    try {
      String? photoUrl = _user?.photoUrl;

      // 2. Upload photo if newly selected
      if (_selectedPhotoFile != null) {
        _isUploadingPhoto = true;
        notifyListeners();
        photoUrl = await _storageService.uploadProfilePicture(
          userId: uid,
          file: _selectedPhotoFile!,
        );
        _isUploadingPhoto = false;
      }

      // 3. Assemble ClientProfileModel
      final updatedProfile = ClientProfileModel(
        uid: uid,
        fitnessGoals: fitnessGoals,
        fitnessLevel: fitnessLevel,
        preferredTrainingTypes: preferredTrainingTypes,
        fitnessInterests: fitnessInterests,
        dateOfBirth: dateOfBirth,
        preferredCityId: preferredCityId,
        preferredTrainingLocation: preferredTrainingLocation,
        privateAddress: privateAddress,
        emergencyContact: emergencyContact,
        updatedAt: DateTime.now(),
      );

      // 4. Atomically persist to Firestore
      await _firestoreService.saveFullClientProfile(
        uid: uid,
        displayName: fullName,
        phoneNumber: phoneNumber,
        photoUrl: photoUrl,
        profile: updatedProfile,
      );

      // 5. Refresh local models
      _user = _user?.copyWith(
        displayName: fullName,
        phoneNumber: phoneNumber,
        photoUrl: photoUrl,
        isOnboarded: true,
      );
      _profile = updatedProfile;
      _selectedPhotoFile = null;

      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSaving = false;
      _isUploadingPhoto = false;
      _setError('Failed to save profile: $e');
      return false;
    }
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
}

