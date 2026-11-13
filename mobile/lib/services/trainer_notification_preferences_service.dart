import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/firestore_collections.dart';
import '../shared/models/trainer_notification_preferences_model.dart';

/// Service managing Trainer notification channel preferences.
/// Persists preferences securely under users/{uid}.notificationPreferences.
class TrainerNotificationPreferencesService {
  static final TrainerNotificationPreferencesService instance =
      TrainerNotificationPreferencesService._internal();
  factory TrainerNotificationPreferencesService() => instance;
  TrainerNotificationPreferencesService._internal();

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore? get _firestore {
    try {
      _firestoreInstance ??= FirebaseFirestore.instance;
      return _firestoreInstance;
    } catch (_) {
      return null;
    }
  }

  // In-memory testing support
  bool _isTestMode = false;
  final Map<String, TrainerNotificationPreferencesModel> _testPreferences = {};
  final Map<String, StreamController<TrainerNotificationPreferencesModel>> _controllers = {};

  @visibleForTesting
  void resetForTest() {
    _isTestMode = true;
    _testPreferences.clear();
  }

  @visibleForTesting
  void setTestPreferences(String uid, TrainerNotificationPreferencesModel prefs) {
    _isTestMode = true;
    _testPreferences[uid] = prefs;
    _getOrCreateController(uid).add(prefs);
  }

  StreamController<TrainerNotificationPreferencesModel> _getOrCreateController(String uid) {
    return _controllers.putIfAbsent(
      uid,
      () => StreamController<TrainerNotificationPreferencesModel>.broadcast(),
    );
  }

  /// Streams notification preferences for a user.
  Stream<TrainerNotificationPreferencesModel> streamPreferences(String uid) {
    if (uid.trim().isEmpty) {
      return Stream.value(const TrainerNotificationPreferencesModel());
    }

    if (_isTestMode) {
      final current = _testPreferences[uid] ?? const TrainerNotificationPreferencesModel();
      return Stream.value(current);
    }

    if (_firestore == null) {
      return Stream.value(const TrainerNotificationPreferencesModel());
    }

    return _firestore!
        .collection(FirestoreCollections.users)
        .doc(uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return const TrainerNotificationPreferencesModel();
      final data = doc.data()?['notificationPreferences'] as Map<String, dynamic>?;
      return TrainerNotificationPreferencesModel.fromMap(data);
    });
  }

  /// Fetches notification preferences once.
  Future<TrainerNotificationPreferencesModel> getPreferences(String uid) async {
    if (uid.trim().isEmpty) return const TrainerNotificationPreferencesModel();

    if (_isTestMode) {
      return _testPreferences[uid] ?? const TrainerNotificationPreferencesModel();
    }

    if (_firestore == null) {
      return const TrainerNotificationPreferencesModel();
    }

    try {
      final doc = await _firestore!.collection(FirestoreCollections.users).doc(uid).get();
      if (!doc.exists) return const TrainerNotificationPreferencesModel();
      final data = doc.data()?['notificationPreferences'] as Map<String, dynamic>?;
      return TrainerNotificationPreferencesModel.fromMap(data);
    } catch (e) {
      debugPrint('Notice: Error fetching notification preferences: $e');
      return const TrainerNotificationPreferencesModel();
    }
  }

  /// Updates notification preferences for the authenticated trainer.
  Future<void> updatePreferences(
    String uid,
    TrainerNotificationPreferencesModel prefs,
  ) async {
    if (uid.trim().isEmpty) return;

    if (_isTestMode) {
      _testPreferences[uid] = prefs;
      _getOrCreateController(uid).add(prefs);
      return;
    }

    if (_firestore != null) {
      try {
        await _firestore!.collection(FirestoreCollections.users).doc(uid).set({
          'notificationPreferences': prefs.toMap(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Notice: Error updating notification preferences: $e');
      }
    }
  }
}

