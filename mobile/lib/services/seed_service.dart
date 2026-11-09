import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/firestore_collections.dart';

/// Database seeder for platform fixed plans, initial launch cities, and platform settings.
/// Can be invoked by admin or during platform initialization.
class SeedService {
  static final SeedService _instance = SeedService._internal();
  factory SeedService() => _instance;
  SeedService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Seeds all 6 platform training plans matching Section 7.
  /// Uses upsert (`SetOptions(merge: true)`) so existing configurations aren't corrupted.
  Future<void> seedTrainingPlans() async {
    final batch = _firestore.batch();
    final plansCol = _firestore.collection(FirestoreCollections.trainingPlans);

    for (final plan in AppConstants.fixedTrainingPlans) {
      final docRef = plansCol.doc(plan['id'] as String);
      batch.set(docRef, {
        ...plan,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      }, SetOptions(merge: true));
    }

    await batch.commit();
    debugPrint('✅ Seeded ${AppConstants.fixedTrainingPlans.length} fixed training plans into Firestore.');
  }

  /// Seeds initial launch cities
  Future<void> seedLaunchCities() async {
    final batch = _firestore.batch();
    final citiesCol = _firestore.collection(FirestoreCollections.cities);

    for (final city in AppConstants.initialLaunchCities) {
      final docRef = citiesCol.doc(city['id'] as String);
      batch.set(docRef, {
        ...city,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
    debugPrint('✅ Seeded ${AppConstants.initialLaunchCities.length} launch cities into Firestore.');
  }

  /// Seeds default platform settings
  Future<void> seedPlatformSettings() async {
    final docRef = _firestore.collection(FirestoreCollections.platformSettings).doc('general');
    await docRef.set({
      'id': 'general',
      'minCancellationHours': AppConstants.cancellationWindowHours,
      'sessionDurationMinutes': AppConstants.sessionDurationMinutes,
      'platformFeePercent': 15,
      'supportEmail': AppConstants.supportEmail,
      'appVersionMin': '1.0.0',
      'isMaintenanceMode': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint('✅ Seeded default platform settings into Firestore.');
  }

  /// Runs full foundation seed
  Future<void> seedAll() async {
    await Future.wait([
      seedTrainingPlans(),
      seedLaunchCities(),
      seedPlatformSettings(),
    ]);
  }
}

