import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/firestore_collections.dart';
import '../shared/models/account_deletion_model.dart';
import '../shared/models/user_model.dart';
import 'auth_service.dart';
import 'booking_service.dart';
import 'trainer_earnings_service.dart';

/// Centralized service handling Trainer account security, personal details,
/// and verified account deletion requests.
class TrainerAccountService extends ChangeNotifier {
  static final TrainerAccountService instance = TrainerAccountService._internal();
  factory TrainerAccountService() => instance;
  TrainerAccountService._internal();

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore? get _firestore {
    try {
      _firestoreInstance ??= FirebaseFirestore.instance;
      return _firestoreInstance;
    } catch (_) {
      return null;
    }
  }

  // Testing support
  bool _isTestMode = false;
  TrainerDeletionEligibilityResult? _testEligibility;
  final List<AccountDeletionRequestModel> _testDeletionRequests = [];

  List<AccountDeletionRequestModel> get testDeletionRequests =>
      List.unmodifiable(_testDeletionRequests);

  @visibleForTesting
  void resetForTest() {
    _isTestMode = true;
    _testEligibility = null;
    _testDeletionRequests.clear();
  }

  @visibleForTesting
  void setTestEligibility(TrainerDeletionEligibilityResult result) {
    _isTestMode = true;
    _testEligibility = result;
    notifyListeners();
  }

  /// Checks whether a trainer is eligible to request account deletion.
  /// Blocked if there are active confirmed bookings or unsettled payouts.
  Future<TrainerDeletionEligibilityResult> checkDeletionEligibility(String trainerId) async {
    if (_isTestMode && _testEligibility != null) {
      return _testEligibility!;
    }

    int activeBookingsCount = 0;
    int pendingPayoutsAmount = 0;

    // 1. Check for active/upcoming bookings
    try {
      final bookings = BookingService.instance.bookingsForTrainer(trainerId);
      final active = bookings.where((b) {
        return b.isConfirmed && !b.isCompleted && !b.isCancelled;
      }).toList();
      activeBookingsCount = active.length;
    } catch (e) {
      debugPrint('Notice: Error inspecting trainer bookings: $e');
    }

    // 2. Check for pending / unsettled payouts
    try {
      final summary = await TrainerEarningsService.instance.getEarningsSummary(trainerId);
      pendingPayoutsAmount = summary.pendingPayout;
    } catch (e) {
      debugPrint('Notice: Error inspecting trainer earnings: $e');
    }

    if (activeBookingsCount > 0) {
      return TrainerDeletionEligibilityResult(
        canDelete: false,
        activeBookingsCount: activeBookingsCount,
        pendingPayoutsAmount: pendingPayoutsAmount,
        blockerReason:
            'You have $activeBookingsCount active upcoming training session(s). Please complete or resolve all scheduled bookings before requesting account deletion.',
      );
    }

    if (pendingPayoutsAmount > 0) {
      return TrainerDeletionEligibilityResult(
        canDelete: false,
        activeBookingsCount: 0,
        pendingPayoutsAmount: pendingPayoutsAmount,
        blockerReason:
            'You have ₹$pendingPayoutsAmount in pending payouts. Please wait until your funds are transferred to your bank before requesting account deletion.',
      );
    }

    return const TrainerDeletionEligibilityResult(canDelete: true);
  }

  /// Requests account deletion.
  /// If [password] is provided for email/password trainers, reauthenticates first.
  /// Preserves required financial, booking, and payment records for legal compliance.
  Future<AccountDeletionRequestModel> requestAccountDeletion({
    required String trainerId,
    required String reason,
    String? password,
  }) async {
    final cleanReason = reason.trim().isEmpty ? 'Trainer requested deletion' : reason.trim();

    // 1. Check eligibility
    final eligibility = await checkDeletionEligibility(trainerId);
    if (!eligibility.canDelete) {
      throw StateError(eligibility.blockerReason ?? 'Account cannot be deleted at this time.');
    }

    // 2. Reauthenticate if password is provided
    if (password != null && password.trim().isNotEmpty) {
      try {
        await AuthService().reauthenticate(password.trim());
      } catch (e) {
        if (!_isTestMode) rethrow;
      }
    }

    final requestId = 'del_${trainerId}_${DateTime.now().millisecondsSinceEpoch}';
    final request = AccountDeletionRequestModel(
      id: requestId,
      userId: trainerId,
      role: 'TRAINER',
      reason: cleanReason,
      status: DeletionRequestStatus.pendingReview,
      preserveFinancialRecords: true,
      preserveBookingHistory: true,
      requestedAt: DateTime.now(),
    );

    if (_isTestMode) {
      _testDeletionRequests.add(request);
      notifyListeners();
      return request;
    }

    // 3. Write to Firestore
    if (_firestore != null) {
      final batch = _firestore!.batch();

      // Record deletion request
      final requestRef = _firestore!
          .collection(FirestoreCollections.accountDeletionRequests)
          .doc(requestId);
      batch.set(requestRef, request.toMap());

      // Deactivate trainer profile
      final profileRef = _firestore!
          .collection(FirestoreCollections.trainerProfiles)
          .doc(trainerId);
      batch.set(profileRef, {
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Flag user account status
      final userRef = _firestore!
          .collection(FirestoreCollections.users)
          .doc(trainerId);
      batch.set(userRef, {
        'status': 'DELETION_REQUESTED',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
    }

    notifyListeners();
    return request;
  }

  /// Updates personal details (Name, Phone, Gender, Date of Birth).
  /// Strictly prevents modification of Trainer role or category.
  Future<void> updatePersonalDetails({
    required String trainerId,
    required String displayName,
    required String phoneNumber,
    Gender? gender,
    String? dateOfBirth,
  }) async {
    final cleanName = displayName.trim();
    final cleanPhone = phoneNumber.trim();

    if (cleanName.length < 2) {
      throw ArgumentError('Display name must be at least 2 characters.');
    }
    if (cleanPhone.length < 10) {
      throw ArgumentError('Phone number must have at least 10 digits.');
    }

    if (_isTestMode) {
      notifyListeners();
      return;
    }

    if (_firestore != null) {
      final batch = _firestore!.batch();

      final userRef = _firestore!.collection(FirestoreCollections.users).doc(trainerId);
      final userUpdates = <String, dynamic>{
        'displayName': cleanName,
        'phoneNumber': cleanPhone,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (gender != null) userUpdates['gender'] = gender.toFirestore();
      if (dateOfBirth != null) userUpdates['dateOfBirth'] = dateOfBirth;
      batch.set(userRef, userUpdates, SetOptions(merge: true));

      final profileRef = _firestore!.collection(FirestoreCollections.trainerProfiles).doc(trainerId);
      final profileUpdates = <String, dynamic>{
        'fullName': cleanName,
        'mobileNumber': cleanPhone,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (gender != null) profileUpdates['gender'] = gender.toFirestore();
      if (dateOfBirth != null) profileUpdates['dateOfBirth'] = dateOfBirth;
      batch.set(profileRef, profileUpdates, SetOptions(merge: true));

      await batch.commit();
    }

    // Also update current FirebaseAuth user displayName
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.uid == trainerId) {
        await user.updateDisplayName(cleanName);
      }
    } catch (_) {}

    notifyListeners();
  }
}

