import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/firestore_collections.dart';
import '../shared/models/trainer_profile_model.dart';

/// Singleton service holding and synchronizing Trainer onboarding, profile credentials,
/// and admin verification status.
class TrainerProfileService extends ChangeNotifier {
  static final TrainerProfileService _instance = TrainerProfileService._internal();
  static TrainerProfileService get instance => _instance;
  TrainerProfileService._internal();

  // Onboarding credentials
  List<String> _specialties = ['Strength & Conditioning'];
  String _experience = '3 Years';
  String _philosophy = 'Focus on progressive overload, strict form, and sustainable lifestyle transformation.';

  // Profile setup credentials
  String? _fullName;
  String? _age;
  String? _sinceWhen; // e.g. "Since 2021"
  String? _gymName;
  String? _mobileNumber;
  String? _photoPath; // local file path to live selfie / captured photo
  String? _certificatePath; // local file path to coaching certificate (optional)
  bool _isProfileCompleted = false;

  // Admin verification state
  TrainerVerificationStatus _verificationStatus = TrainerVerificationStatus.pending;
  DateTime? _submittedAt;
  DateTime? _approvedAt;
  String? _adminNotes;

  // Getters
  List<String> get specialties => List.unmodifiable(_specialties);
  String get experience => _experience;
  String get philosophy => _philosophy;

  String? get fullName => _fullName;
  String? get age => _age;
  String? get sinceWhen => _sinceWhen;
  String? get gymName => _gymName;
  String? get mobileNumber => _mobileNumber;
  String? get photoPath => _photoPath;
  String? get certificatePath => _certificatePath;
  bool get isProfileCompleted => _isProfileCompleted;

  TrainerVerificationStatus get verificationStatus => _verificationStatus;
  bool get isPendingApproval => _isProfileCompleted && _verificationStatus == TrainerVerificationStatus.pending;
  bool get isApproved => _isProfileCompleted && _verificationStatus == TrainerVerificationStatus.approved;
  bool get isRejected => _isProfileCompleted && _verificationStatus == TrainerVerificationStatus.rejected;
  DateTime? get submittedAt => _submittedAt;
  DateTime? get approvedAt => _approvedAt;
  String? get adminNotes => _adminNotes;

  /// Update initial onboarding credentials
  void saveOnboarding({
    required List<String> specialties,
    required String experience,
    required String philosophy,
  }) {
    _specialties = List.from(specialties);
    _experience = experience.trim().isEmpty ? '1 Year' : experience.trim();
    _philosophy = philosophy.trim().isEmpty
        ? 'Empowering clients through discipline and consistency.'
        : philosophy.trim();
    notifyListeners();
  }

  /// Update complete trainer profile credentials and submit to Admin for review
  Future<void> saveProfileDetails({
    required String fullName,
    required String age,
    required String sinceWhen,
    required String gymName,
    required String mobileNumber,
    String? photoPath,
    String? certificatePath,
  }) async {
    _fullName = fullName.trim();
    _age = age.trim();
    _sinceWhen = sinceWhen.trim();
    _gymName = gymName.trim();
    _mobileNumber = mobileNumber.trim();
    if (photoPath != null && photoPath.isNotEmpty) {
      _photoPath = photoPath;
    }
    _certificatePath = certificatePath;
    _isProfileCompleted = true;
    _verificationStatus = TrainerVerificationStatus.pending;
    _submittedAt = DateTime.now();
    notifyListeners();

    // Optionally sync with Firestore if authenticated user exists
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        final userRef = FirebaseFirestore.instance
            .collection(FirestoreCollections.users)
            .doc(uid);

        batch.set(userRef, {
          'displayName': _fullName,
          'phoneNumber': _mobileNumber,
          'onboarded': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        final trainerRef = FirebaseFirestore.instance
            .collection(FirestoreCollections.trainerProfiles)
            .doc(uid);

        int years = int.tryParse(_experience.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;

        batch.set(trainerRef, {
          'uid': uid,
          'fullName': _fullName,
          'age': int.tryParse(_age ?? '') ?? 25,
          'sinceWhen': _sinceWhen,
          'gymName': _gymName,
          'mobileNumber': _mobileNumber,
          'specialties': _specialties,
          'experienceYears': years,
          'bio': _philosophy,
          if (_certificatePath != null && _certificatePath!.isNotEmpty)
            'certificationDocuments': [_certificatePath],
          'verificationStatus': _verificationStatus.toFirestore(),
          'isProfileCompleted': true,
          'submittedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await batch.commit();
      } catch (e) {
        debugPrint('Notice: TrainerProfileService Firestore sync: $e');
      }
    }
  }

  /// Admin approval action
  Future<void> approveByAdmin({String? notes}) async {
    _verificationStatus = TrainerVerificationStatus.approved;
    _approvedAt = DateTime.now();
    _adminNotes = notes;
    notifyListeners();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
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
    if (uid != null) {
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
    if (uid != null) {
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
