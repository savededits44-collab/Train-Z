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

  /// Seeds initial verified trainers (both Male & Female across launch cities)
  Future<void> seedApprovedTrainers() async {
    final batch = _firestore.batch();
    final usersCol = _firestore.collection(FirestoreCollections.users);
    final trainersCol = _firestore.collection(FirestoreCollections.trainerProfiles);

    final trainers = [
      {
        'uid': 'trainer_vikram_mumbai',
        'email': 'vikram.trainer@trainz.app',
        'displayName': 'Vikram Malhotra',
        'phoneNumber': '+91 98201 12345',
        'role': 'TRAINER',
        'gender': 'MALE',
        'status': 'ACTIVE',
        'isEmailVerified': true,
        'onboarded': true,
        'bio': 'Certified Strength & Conditioning Specialist. Expert in progressive overload, barbell mechanics, and contest prep.',
        'specialties': ['Hypertrophy & Strength', 'Powerlifting', 'Form Correction'],
        'experienceYears': 6,
        'cityId': 'city_mumbai',
        'hourlyRate': 650,
        'ratingAvg': 4.92,
        'totalReviews': 48,
        'gymName': "Gold's Gym Bandra West",
      },
      {
        'uid': 'trainer_arjun_bengaluru',
        'email': 'arjun.trainer@trainz.app',
        'displayName': 'Arjun Rao',
        'phoneNumber': '+91 98450 67890',
        'role': 'TRAINER',
        'gender': 'MALE',
        'status': 'ACTIVE',
        'isEmailVerified': true,
        'onboarded': true,
        'bio': 'Functional athlete & calisthenics coach. Focused on mobility, high VO2 max endurance, and athletic recomposition.',
        'specialties': ['Calisthenics', 'HIIT & Conditioning', 'Fat Loss'],
        'experienceYears': 4,
        'cityId': 'city_bengaluru',
        'hourlyRate': 600,
        'ratingAvg': 4.88,
        'totalReviews': 32,
        'gymName': 'Cult.fit Indiranagar',
      },
      {
        'uid': 'trainer_priya_mumbai',
        'email': 'priya.trainer@trainz.app',
        'displayName': 'Priya Sharma',
        'phoneNumber': '+91 98199 54321',
        'role': 'TRAINER',
        'gender': 'FEMALE',
        'status': 'ACTIVE',
        'isEmailVerified': true,
        'onboarded': true,
        'bio': 'Elite female coach specializing in female body transformation, postpartum recovery, and hypertrophy conditioning.',
        'specialties': ['Body Recomposition', 'Strength Training', 'Core & Mobility'],
        'experienceYears': 5,
        'cityId': 'city_mumbai',
        'hourlyRate': 700,
        'ratingAvg': 4.96,
        'totalReviews': 56,
        'gymName': 'Equinox Khar West',
      },
      {
        'uid': 'trainer_neha_delhi',
        'email': 'neha.trainer@trainz.app',
        'displayName': 'Neha Kapoor',
        'phoneNumber': '+91 98110 98765',
        'role': 'TRAINER',
        'gender': 'FEMALE',
        'status': 'ACTIVE',
        'isEmailVerified': true,
        'onboarded': true,
        'bio': 'Holistic trainer focusing on athletic strength, endurance circuits, and injury prevention for female athletes.',
        'specialties': ['Athletic Performance', 'HIIT Circuit', 'Nutrition Guidance'],
        'experienceYears': 4,
        'cityId': 'city_delhi_ncr',
        'hourlyRate': 650,
        'ratingAvg': 4.89,
        'totalReviews': 29,
        'gymName': 'Fitness First Gurgaon',
      },
    ];

    for (final t in trainers) {
      final userDocRef = usersCol.doc(t['uid'] as String);
      batch.set(userDocRef, {
        'uid': t['uid'],
        'email': t['email'],
        'displayName': t['displayName'],
        'phoneNumber': t['phoneNumber'],
        'role': t['role'],
        'gender': t['gender'],
        'status': t['status'],
        'isEmailVerified': t['isEmailVerified'],
        'onboarded': t['onboarded'],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final trainerDocRef = trainersCol.doc(t['uid'] as String);
      batch.set(trainerDocRef, {
        'uid': t['uid'],
        'bio': t['bio'],
        'specialties': t['specialties'],
        'experienceYears': t['experienceYears'],
        'cityId': t['cityId'],
        'hourlyRate': t['hourlyRate'],
        'verificationStatus': 'APPROVED',
        'isActive': true,
        'ratingAvg': t['ratingAvg'],
        'totalReviews': t['totalReviews'],
        'gymName': t['gymName'],
        'approvedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
    debugPrint('✅ Seeded approved trainers for male and female clients.');
  }

  /// Runs full foundation seed
  Future<void> seedAll() async {
    await Future.wait([
      seedTrainingPlans(),
      seedLaunchCities(),
      seedPlatformSettings(),
      seedApprovedTrainers(),
    ]);
  }
}

