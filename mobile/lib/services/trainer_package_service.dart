import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/firestore_collections.dart';
import '../shared/models/training_plan_model.dart';

/// Dedicated service for Trainer Package & Plan Management.
/// Supports both:
/// - Standard Trainers (read-only view of the 6 fixed TRAIN Z platform packages)
/// - Advanced Trainers (creation, updating, deletion, and approval tracking of custom plans)
class TrainerPackageService {
  static final TrainerPackageService instance = TrainerPackageService._internal();
  factory TrainerPackageService() => instance;
  TrainerPackageService._internal();

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore? get _firestore {
    try {
      _firestoreInstance ??= FirebaseFirestore.instance;
      return _firestoreInstance;
    } catch (_) {
      return null;
    }
  }

  // In-memory cache & mock fallback for unit tests and offline preview
  final Map<String, List<TrainingPlanModel>> _mockPlans = {};
  final StreamController<List<TrainingPlanModel>> _mockStreamController =
      StreamController<List<TrainingPlanModel>>.broadcast();

  @visibleForTesting
  void clearMockData() {
    _mockPlans.clear();
  }

  @visibleForTesting
  void addMockPlan(String trainerId, TrainingPlanModel plan) {
    _mockPlans.putIfAbsent(trainerId, () => []);
    _mockPlans[trainerId]!.add(plan);
    _mockStreamController.add(List.unmodifiable(_mockPlans[trainerId]!));
  }

  /// Returns the 6 fixed TRAIN Z packages standardized platform-wide.
  List<TrainingPlanModel> getPlatformPackages() {
    return TrainingPlanModel.platformPackages;
  }

  /// Streams custom training plans created by an Advanced Trainer.
  /// Filters out deleted packages so the trainer views only active, pending, draft, or rejected plans.
  Stream<List<TrainingPlanModel>> streamCustomPlans(String trainerId) {
    if (trainerId.trim().isEmpty) return Stream.value([]);

    final firestore = _firestore;
    if (firestore == null) {
      final list = (_mockPlans[trainerId] ?? []).where((p) => !p.isDeleted).toList();
      return Stream.value(list);
    }

    try {
      return firestore
          .collection(FirestoreCollections.trainingPlans)
          .where('trainerId', isEqualTo: trainerId)
          .snapshots()
          .map((snapshot) {
        final plans = snapshot.docs
            .map((doc) => TrainingPlanModel.fromDocument(doc))
            .where((p) => !p.isDeleted)
            .toList();

        // Sort: newest first
        plans.sort((a, b) {
          final aDate = a.updatedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.updatedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });

        return plans;
      }).handleError((err) {
        debugPrint('Notice: Error streaming custom plans: $err');
        return <TrainingPlanModel>[];
      });
    } catch (e) {
      debugPrint('Notice: Exception setting up custom plans stream: $e');
      return Stream.value([]);
    }
  }

  /// Creates a new custom training plan for an approved Advanced Trainer.
  /// Enforces validation and always sets `isApproved: false` and `approvalStatus: PENDING`
  /// or `DRAFT` depending on [submitForApproval].
  Future<String> createCustomPlan({
    required String title,
    required int price,
    required int sessionsCount,
    required int validityDays,
    required String description,
    int sessionDurationMinutes = 60,
    bool submitForApproval = true,
  }) async {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {}
    final uid = user?.uid ?? 'test_trainer_uid';

    final trimmedTitle = title.trim();
    final trimmedDesc = description.trim();

    if (trimmedTitle.isEmpty) {
      throw ArgumentError('Package title cannot be empty.');
    }
    if (price <= 0) {
      throw ArgumentError('Price must be greater than ₹0.');
    }
    if (sessionsCount <= 0) {
      throw ArgumentError('Sessions count must be at least 1.');
    }
    if (validityDays <= 0) {
      throw ArgumentError('Validity period must be at least 1 day.');
    }

    final approvalStatus = submitForApproval ? PackageApprovalStatus.pending : PackageApprovalStatus.draft;
    final firestore = _firestore;
    final now = DateTime.now();
    final planId = firestore != null
        ? firestore.collection(FirestoreCollections.trainingPlans).doc().id
        : 'plan_${DateTime.now().millisecondsSinceEpoch}';

    final plan = TrainingPlanModel(
      id: planId,
      title: trimmedTitle,
      price: price,
      sessionsCount: sessionsCount,
      validityDays: validityDays,
      sessionDurationMinutes: sessionDurationMinutes,
      description: trimmedDesc,
      popular: false,
      isActive: false, // Inactive until approved
      trainerId: uid,
      trainerName: user?.displayName ?? 'Coach',
      isApproved: false, // Mandatory: pending Admin review
      approvalStatus: approvalStatus,
      adminRejectionReason: null,
      isDeleted: false,
      isCustom: true,
      createdAt: now,
      updatedAt: now,
    );

    if (firestore != null) {
      await firestore.collection(FirestoreCollections.trainingPlans).doc(planId).set(plan.toMap());
    } else {
      addMockPlan(uid, plan);
    }

    return planId;
  }

  /// Updates an existing custom training plan.
  /// If the plan was previously approved, editing it resets `isApproved = false`
  /// and `approvalStatus = PENDING`, requiring re-approval from Admin.
  /// Existing client purchases in `purchased_packages` remain completely protected and valid.
  Future<void> updateCustomPlan({
    required String planId,
    required String title,
    required int price,
    required int sessionsCount,
    required int validityDays,
    required String description,
    int sessionDurationMinutes = 60,
    bool submitForApproval = true,
  }) async {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {}
    final uid = user?.uid ?? 'test_trainer_uid';

    final trimmedTitle = title.trim();
    final trimmedDesc = description.trim();

    if (trimmedTitle.isEmpty) {
      throw ArgumentError('Package title cannot be empty.');
    }
    if (price <= 0) {
      throw ArgumentError('Price must be greater than ₹0.');
    }
    if (sessionsCount <= 0) {
      throw ArgumentError('Sessions count must be at least 1.');
    }
    if (validityDays <= 0) {
      throw ArgumentError('Validity period must be at least 1 day.');
    }

    final status = submitForApproval ? 'PENDING' : 'DRAFT';
    final firestore = _firestore;

    if (firestore != null) {
      final docRef = firestore.collection(FirestoreCollections.trainingPlans).doc(planId);
      await docRef.update({
        'title': trimmedTitle,
        'price': price,
        'sessions': sessionsCount,
        'sessionsCount': sessionsCount,
        'validityDays': validityDays,
        'sessionDurationMinutes': sessionDurationMinutes,
        'description': trimmedDesc,
        'isApproved': false, // Mandatory: re-approval triggered on edit
        'isActive': false,   // Inactive until re-approved
        'approvalStatus': status,
        'adminRejectionReason': null, // Clear past rejection reason on re-edit
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final list = _mockPlans[uid];
      if (list != null) {
        final idx = list.indexWhere((p) => p.id == planId);
        if (idx != -1) {
          list[idx] = list[idx].copyWith(
            title: trimmedTitle,
            price: price,
            sessionsCount: sessionsCount,
            validityDays: validityDays,
            sessionDurationMinutes: sessionDurationMinutes,
            description: trimmedDesc,
            isApproved: false,
            isActive: false,
            approvalStatus: submitForApproval ? PackageApprovalStatus.pending : PackageApprovalStatus.draft,
            adminRejectionReason: null,
            updatedAt: DateTime.now(),
          );
          _mockStreamController.add(List.unmodifiable(list));
        }
      }
    }
  }

  /// Deletes or soft-archives a custom training plan.
  /// Existing client purchases in `purchased_packages` remain 100% intact and valid.
  Future<void> deleteCustomPlan(String planId) async {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {}
    final uid = user?.uid ?? 'test_trainer_uid';
    final firestore = _firestore;

    if (firestore != null) {
      final docRef = firestore.collection(FirestoreCollections.trainingPlans).doc(planId);
      await docRef.update({
        'isDeleted': true,
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final list = _mockPlans[uid];
      if (list != null) {
        final idx = list.indexWhere((p) => p.id == planId);
        if (idx != -1) {
          list[idx] = list[idx].copyWith(
            isDeleted: true,
            isActive: false,
            updatedAt: DateTime.now(),
          );
          _mockStreamController.add(List.unmodifiable(list));
        }
      }
    }
  }
}
