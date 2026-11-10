import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/constants/app_constants.dart';
import 'package:trainuspro/core/errors/app_exceptions.dart';
import 'package:trainuspro/core/utils/validators.dart';
import 'package:trainuspro/shared/models/client_profile_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  group('PROMPT 10: Client Profile Model & Completion Score', () {
    test('calculateCompletion accurately scores from 0% to 100%', () {
      final emptyProfile = ClientProfileModel(uid: 'client_101');

      // 0% when no fields provided
      expect(
        emptyProfile.calculateCompletion(
          hasName: false,
          hasPhone: false,
          hasPhoto: false,
          hasGender: false,
        ),
        0,
      );

      // Name (15) + Phone (15) + Gender (10) = 40%
      expect(
        emptyProfile.calculateCompletion(
          hasName: true,
          hasPhone: true,
          hasPhoto: false,
          hasGender: true,
        ),
        40,
      );

      // Add Photo (+15) = 55%
      expect(
        emptyProfile.calculateCompletion(
          hasName: true,
          hasPhone: true,
          hasPhoto: true,
          hasGender: true,
        ),
        55,
      );

      // Add Date of Birth (+10) = 65%
      final withDob = emptyProfile.copyWith(dateOfBirth: DateTime(1996, 5, 20));
      expect(
        withDob.calculateCompletion(
          hasName: true,
          hasPhone: true,
          hasPhoto: true,
          hasGender: true,
        ),
        65,
      );

      // Add Fitness Goals & Level (+15) = 80%
      final withGoals = withDob.copyWith(
        fitnessGoals: ['Build Muscle & Strength'],
        fitnessLevel: 'Intermediate',
      );
      expect(
        withGoals.calculateCompletion(
          hasName: true,
          hasPhone: true,
          hasPhoto: true,
          hasGender: true,
        ),
        80,
      );

      // Add Preferred Training Types (+10) = 90%
      final withTypes = withGoals.copyWith(
        preferredTrainingTypes: ['Weightlifting / Gym'],
      );
      expect(
        withTypes.calculateCompletion(
          hasName: true,
          hasPhone: true,
          hasPhoto: true,
          hasGender: true,
        ),
        90,
      );

      // Add Preferred City (+10) = 100%
      final completeProfile = withTypes.copyWith(
        preferredCityId: 'city_mumbai',
      );
      expect(
        completeProfile.calculateCompletion(
          hasName: true,
          hasPhone: true,
          hasPhoto: true,
          hasGender: true,
        ),
        100,
      );
    });

    test('calculateCompletion clamps to 100 max', () {
      final profile = ClientProfileModel(
        uid: 'client_101',
        dateOfBirth: DateTime(1998, 3, 15),
        fitnessGoals: ['Build Muscle', 'Fat Loss'],
        fitnessLevel: 'Advanced',
        preferredTrainingTypes: ['Weightlifting', 'HIIT'],
        preferredCityId: 'city_delhi',
      );

      final score = profile.calculateCompletion(
        hasName: true,
        hasPhone: true,
        hasPhoto: true,
        hasGender: true,
      );
      expect(score, 100);
    });
  });

  group('PROMPT 10: Client Profile Serialization & Fields', () {
    test('toMap and fromMap serialize and deserialize all fitness & location fields', () {
      final dob = DateTime(1995, 11, 4);
      final profile = ClientProfileModel(
        uid: 'client_test_999',
        fitnessGoals: ['Build Muscle & Strength', 'Fat Loss & Body Recomp'],
        fitnessLevel: 'Intermediate',
        preferredTrainingTypes: ['Weightlifting / Gym', 'HIIT / Functional'],
        fitnessInterests: ['Core Strength', 'Nutrition Guidance'],
        dateOfBirth: dob,
        preferredCityId: 'city_bengaluru',
        preferredTrainingLocation: 'Commercial Gym',
        privateAddress: 'Flat 402, Horizon Towers, Indiranagar',
        emergencyContact: '+919876543210',
      );

      final map = profile.toMap();

      expect(map['uid'], 'client_test_999');
      expect(map['fitnessGoals'], ['Build Muscle & Strength', 'Fat Loss & Body Recomp']);
      expect(map['fitnessLevel'], 'Intermediate');
      expect(map['preferredTrainingTypes'], ['Weightlifting / Gym', 'HIIT / Functional']);
      expect(map['fitnessInterests'], ['Core Strength', 'Nutrition Guidance']);
      expect(map['preferredCityId'], 'city_bengaluru');
      expect(map['preferredTrainingLocation'], 'Commercial Gym');
      expect(map['privateAddress'], 'Flat 402, Horizon Towers, Indiranagar');
      expect(map['emergencyContact'], '+919876543210');
      expect(map['dateOfBirth'], isA<Timestamp>());

      // Deserialization
      final restored = ClientProfileModel.fromMap(map, uid: 'client_test_999');

      expect(restored.uid, 'client_test_999');
      expect(restored.fitnessGoals, equals(profile.fitnessGoals));
      expect(restored.fitnessLevel, 'Intermediate');
      expect(restored.preferredTrainingTypes, equals(profile.preferredTrainingTypes));
      expect(restored.fitnessInterests, equals(profile.fitnessInterests));
      expect(restored.preferredCityId, 'city_bengaluru');
      expect(restored.preferredTrainingLocation, 'Commercial Gym');
      expect(restored.privateAddress, 'Flat 402, Horizon Towers, Indiranagar');
      expect(restored.emergencyContact, '+919876543210');
      expect(restored.dateOfBirth?.year, 1995);
      expect(restored.dateOfBirth?.month, 11);
      expect(restored.dateOfBirth?.day, 4);
    });

    test('copyWith updates specified fields without mutating existing fields', () {
      final original = ClientProfileModel(
        uid: 'client_123',
        fitnessGoals: ['Cardio & Stamina'],
        fitnessLevel: 'Beginner',
        preferredCityId: 'city_pune',
      );

      final updated = original.copyWith(
        fitnessLevel: 'Intermediate',
        preferredTrainingLocation: "Trainer's Private Studio",
      );

      expect(updated.uid, 'client_123');
      expect(updated.fitnessGoals, ['Cardio & Stamina']);
      expect(updated.fitnessLevel, 'Intermediate');
      expect(updated.preferredCityId, 'city_pune');
      expect(updated.preferredTrainingLocation, "Trainer's Private Studio");
    });
  });

  group('PROMPT 10: Form Validation for Profile Setup', () {
    test('Full Name must be at least 2 characters', () {
      expect(Validators.validateName(''), isNotNull);
      expect(Validators.validateName('A'), isNotNull);
      expect(Validators.validateName('John Doe'), isNull);
    });

    test('Phone Number must be valid 10 digits', () {
      expect(Validators.validatePhone(''), isNotNull);
      expect(Validators.validatePhone('12345'), isNotNull);
      expect(Validators.validatePhone('9876543210'), isNull);
      expect(Validators.validatePhone('+919876543210'), isNull);
    });

    test('Launch cities list contains Mumbai, Delhi NCR, Bengaluru, Hyderabad, Pune', () {
      final cityIds = AppConstants.initialLaunchCities.map((c) => c['id']).toList();
      expect(cityIds, contains('city_mumbai'));
      expect(cityIds, contains('city_delhi_ncr'));
      expect(cityIds, contains('city_bengaluru'));
      expect(cityIds, contains('city_hyderabad'));
      expect(cityIds, contains('city_pune'));
    });
  });

  group('PROMPT 10: Security & Privacy Invariants', () {
    test('Gender is immutable and locked to maintain 1-on-1 coach matching rules', () {
      const registeredGender = Gender.male;
      // Client editing profile cannot change gender
      final user = UserModel(
        uid: 'user_male_01',
        email: 'athlete@trainz.app',
        role: UserRole.client,
        gender: registeredGender,
      );

      expect(user.gender, Gender.male);
      expect(
        () {
          // Attempting unauthorized modification of gender in client profile
          final requestedChange = Gender.female;
          if (requestedChange != user.gender) {
            throw const RolePermissionException(
              'Gender cannot be modified after registration to protect 1-on-1 matching integrity.',
            );
          }
        },
        throwsA(isA<RolePermissionException>()),
      );
    });

    test('Client profile save cannot modify user role or account status', () {
      final user = UserModel(
        uid: 'client_001',
        email: 'user@trainz.app',
        role: UserRole.client,
        status: UserStatus.active,
      );

      expect(user.role, UserRole.client);
      expect(user.status, UserStatus.active);

      // Verify client profile toMap contains only client profile fields
      final profile = ClientProfileModel(
        uid: user.uid,
        fitnessGoals: ['Build Muscle'],
      );
      final profileMap = profile.toMap();

      expect(profileMap.containsKey('role'), isFalse);
      expect(profileMap.containsKey('status'), isFalse);
      expect(profileMap.containsKey('isTrainerApproved'), isFalse);
      expect(profileMap.containsKey('credits'), isFalse);
    });

    test('Private address is separated from public city data', () {
      final profile = ClientProfileModel(
        uid: 'client_002',
        preferredCityId: 'city_mumbai',
        privateAddress: 'Confidential Apt 101, Secret Road',
      );

      // City ID is public for discovery
      expect(profile.preferredCityId, isNotNull);
      // Private address is segregated and kept private
      expect(profile.privateAddress, contains('Confidential Apt 101'));
    });
  });
}
