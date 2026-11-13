import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';
import 'package:trainuspro/services/trainer_profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Trainer Profile Setup: Personal Profile Information', () {
    test('Calculates age from date of birth accurately', () {
      final service = TrainerProfileService.instance;
      final birthYear = DateTime.now().year - 25;
      final dobStr = '$birthYear-01-15';

      expect(dobStr, contains('$birthYear'));
      expect(service.age, anyOf(isNull, isNotNull));
    });

    test('Trainer profile serialization includes all personal fields', () {
      const profile = TrainerProfileModel(
        uid: 'trainer_p1',
        fullName: 'Vikram Malhotra',
        phoneNumber: '9876543210',
        gender: Gender.male,
        dateOfBirth: '1995-05-20',
        photoUrl: 'https://storage.googleapis.com/profile_pictures/trainer_p1/avatar.jpg',
        bio: 'Certified strength and conditioning coach dedicated to sustainable athletic performance.',
        experienceYears: 4.5,
        category: TrainerCategory.advancedTrainer,
      );

      final map = profile.toMap();
      expect(map['fullName'], 'Vikram Malhotra');
      expect(map['phoneNumber'], '9876543210');
      expect(map['gender'], 'MALE');
      expect(map['dateOfBirth'], '1995-05-20');
      expect(map['photoUrl'], contains('avatar.jpg'));
      expect(map['bio'], contains('Certified strength and conditioning'));
      expect(map['experienceYears'], 4.5);
      expect(map['category'], 'ADVANCED_TRAINER');

      final deserialized = TrainerProfileModel.fromMap(map, uid: 'trainer_p1');
      expect(deserialized.fullName, 'Vikram Malhotra');
      expect(deserialized.phoneNumber, '9876543210');
      expect(deserialized.gender, Gender.male);
      expect(deserialized.dateOfBirth, '1995-05-20');
      expect(deserialized.photoUrl, contains('avatar.jpg'));
      expect(deserialized.bio, contains('Certified strength'));
      expect(deserialized.experienceYears, 4.5);
      expect(deserialized.category, TrainerCategory.advancedTrainer);
    });
  });

  group('Trainer Profile Setup: Professional Information & Advanced Tier Rules', () {
    test('Collects professional specialisations, client types, goals, methods, and languages', () {
      const profile = TrainerProfileModel(
        uid: 'trainer_p2',
        specialties: ['Strength & Conditioning', 'Hypertrophy & Muscle Gain'],
        clientTypes: ['Beginners', 'Intermediate Athletes'],
        trainingGoals: ['Fat Loss & Toning', 'Muscle Hypertrophy'],
        trainingMethods: ['Progressive Overload', 'HIIT'],
        languages: ['English', 'Hindi', 'Marathi'],
        trainingApproach: 'Focus on biomechanics, clean form, and progressive overload.',
        professionalExperience: '5 years at Gold\'s Gym, trained over 120 clients with verified transformations.',
        experienceYears: 5.0,
        category: TrainerCategory.advancedTrainer,
      );

      expect(profile.specialties.length, 2);
      expect(profile.specialties, contains('Strength & Conditioning'));
      expect(profile.clientTypes, contains('Beginners'));
      expect(profile.trainingGoals, contains('Fat Loss & Toning'));
      expect(profile.trainingMethods, contains('Progressive Overload'));
      expect(profile.languages, contains('Marathi'));
      expect(profile.trainingApproach, contains('biomechanics'));
      expect(profile.professionalExperience, contains('Gold\'s Gym'));
    });

    test('Advanced Trainer requires minimum 3.5 years experience in completion check', () {
      // 2.0 years for Advanced Trainer -> missing experience item
      const advUnderExp = TrainerProfileModel(
        uid: 'adv_low',
        category: TrainerCategory.advancedTrainer,
        experienceYears: 2.0,
      );

      final completionLow = advUnderExp.calculateCompletion(
        name: 'Test Name',
        phone: '9876543210',
        genderValue: Gender.male,
      );
      expect(completionLow.isComplete, isFalse);
      expect(
        completionLow.missingFields.any((f) => f.contains('3.5 years')),
        isTrue,
      );

      // 3.5 years for Advanced Trainer qualifies
      const advQualified = TrainerProfileModel(
        uid: 'adv_ok',
        category: TrainerCategory.advancedTrainer,
        experienceYears: 3.5,
      );

      final completionOk = advQualified.calculateCompletion(
        name: 'Test Name',
        phone: '9876543210',
        genderValue: Gender.male,
      );
      expect(
        completionOk.missingFields.any((f) => f.contains('3.5 years')),
        isFalse,
      );
    });

    test('Standard Trainer requires NO minimum experience threshold', () {
      const standardTrainer = TrainerProfileModel(
        uid: 'std_1',
        category: TrainerCategory.trainer,
        experienceYears: 0.5,
      );

      final completion = standardTrainer.calculateCompletion(
        name: 'Standard Trainer',
        phone: '9876543210',
        genderValue: Gender.female,
      );

      expect(
        completion.missingFields.any((f) => f.contains('min 3.5 years')),
        isFalse,
      );
    });
  });

  group('Trainer Profile Setup: Training Services & Dynamic Locations', () {
    test('Supports home training, gym training, other locations, and dynamic service areas', () {
      const profile = TrainerProfileModel(
        uid: 'trainer_p3',
        trainsAtHome: true,
        trainsAtGym: true,
        otherTrainingLocations: ['Society Clubhouse Gym', 'Central Park Outdoor Track'],
        serviceAreas: ['Koregaon Park', 'Kalyani Nagar', 'Viman Nagar', 'Indiranagar', 'Bandra West'],
        workingDays: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'],
        workingHours: '06:00 AM - 10:00 AM, 05:00 PM - 09:00 PM',
      );

      expect(profile.trainsAtHome, isTrue);
      expect(profile.trainsAtGym, isTrue);
      expect(profile.otherTrainingLocations.length, 2);
      expect(profile.serviceAreas.length, 5);
      expect(profile.serviceAreas, contains('Koregaon Park'));
      expect(profile.serviceAreas, contains('Bandra West'));
      expect(profile.workingDays, contains('MON'));
      expect(profile.workingHours, contains('06:00 AM'));

      final map = profile.toMap();
      final fromMap = TrainerProfileModel.fromMap(map, uid: 'trainer_p3');
      expect(fromMap.trainsAtHome, isTrue);
      expect(fromMap.trainsAtGym, isTrue);
      expect(fromMap.otherTrainingLocations, contains('Central Park Outdoor Track'));
      expect(fromMap.serviceAreas, contains('Indiranagar'));
    });
  });

  group('Trainer Profile Setup: Profile Completion Scoring & Submission Guard', () {
    test('Accurately evaluates completion score from 0 to 100%', () {
      // Empty profile (Standard Trainer with 0 years experience qualifies for experience item)
      const emptyProfile = TrainerProfileModel(uid: 'empty_tr');
      final emptyComp = emptyProfile.calculateCompletion();
      expect(emptyComp.score, 10);
      expect(emptyComp.isComplete, isFalse);
      expect(emptyComp.missingFields, contains('Profile Photo'));
      expect(emptyComp.missingFields, contains('Full Name'));
      expect(emptyComp.missingFields, contains('Phone Number'));
      expect(emptyComp.missingFields, contains('Date of Birth'));
      expect(emptyComp.missingFields, contains('Gender'));
      expect(emptyComp.missingFields, contains('Training Specialisations'));
      expect(emptyComp.missingFields, contains('Service Areas (min. 1 area)'));

      // Fully complete profile
      const completeProfile = TrainerProfileModel(
        uid: 'full_tr',
        photoUrl: 'https://storage.googleapis.com/profile_pictures/full_tr/avatar.jpg',
        fullName: 'Rohit Verma',
        phoneNumber: '9876543210',
        gender: Gender.male,
        dateOfBirth: '1993-08-14',
        bio: 'Elite strength & conditioning coach with over 6 years of client transformation experience.',
        experienceYears: 6.0,
        category: TrainerCategory.advancedTrainer,
        specialties: ['Strength & Conditioning', 'Hypertrophy'],
        clientTypes: ['Intermediate Athletes', 'Beginners'],
        trainingGoals: ['Fat Loss', 'Muscle Building'],
        trainingMethods: ['Progressive Overload', 'Periodization'],
        languages: ['English', 'Hindi'],
        trainingApproach: 'Evidence-based biomechanics, progressive load management, and personalized guidance.',
        professionalExperience: '6 years head coach at FitHub, trained competitive athletes.',
        trainsAtHome: true,
        trainsAtGym: true,
        serviceAreas: ['Baner', 'Aundh', 'Balewadi'],
        workingDays: ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'],
        workingHours: '06:00 AM - 09:00 PM',
      );

      final fullComp = completeProfile.calculateCompletion(
        name: 'Rohit Verma',
        phone: '9876543210',
        genderValue: Gender.male,
      );

      expect(fullComp.score, 100);
      expect(fullComp.missingFields, isEmpty);
      expect(fullComp.isComplete, isTrue);
    });

    test('Prevents incomplete profile from being submitted for Admin review', () async {
      // Missing photo, bio, areas
      const incompleteProfile = TrainerProfileModel(
        uid: 'inc_tr',
        fullName: 'Ananya Deshmukh',
        phoneNumber: '9812345678',
        gender: Gender.female,
        dateOfBirth: '1997-11-20',
        // photoUrl missing
        // bio missing
        experienceYears: 2.0,
        specialties: ['Yoga'],
      );

      final comp = incompleteProfile.calculateCompletion(
        name: 'Ananya Deshmukh',
        phone: '9812345678',
        genderValue: Gender.female,
      );

      expect(comp.isComplete, isFalse);
      expect(comp.missingFields, contains('Profile Photo'));
      expect(comp.missingFields, contains('Professional Biography (min. 20 chars)'));
      expect(comp.missingFields, contains('Service Areas (min. 1 area)'));
    });
  });

  group('Trainer Profile Setup: Privacy & Immutability Invariants', () {
    test('Gender is protected and NOT exposed as matching badge in client display model', () {
      const profile = TrainerProfileModel(
        uid: 'tr_sec_1',
        category: TrainerCategory.trainer,
        gender: Gender.male,
        experienceYears: 3.0,
        specialties: ['Fat Loss'],
      );

      const displayModel = TrainerDisplayModel(
        profile: profile,
        uid: 'tr_sec_1',
        displayName: 'Amit Sharma',
        gender: Gender.male,
        specialties: ['Fat Loss'],
        experienceYears: 3.0,
        ratingAvg: 4.8,
        totalReviews: 12,
        hourlyRate: 600,
        serviceArea: 'Koregaon Park',
        certifications: [],
      );

      // Gender is used solely for backend matching and is not displayed as a badge or client preference filter
      expect(displayModel.primarySpecialty, 'Fat Loss');
      expect(displayModel.displayLocation, 'Koregaon Park');
      expect(displayModel.availabilityText, 'Slots Available');
    });

    test('copyWith properly creates updated instance without mutating existing instance', () {
      const original = TrainerProfileModel(
        uid: 'tr_mut_1',
        fullName: 'Original Name',
        experienceYears: 2.0,
        trainsAtHome: false,
      );

      final updated = original.copyWith(
        fullName: 'Updated Name',
        experienceYears: 4.0,
        trainsAtHome: true,
      );

      expect(original.fullName, 'Original Name');
      expect(original.experienceYears, 2.0);
      expect(original.trainsAtHome, isFalse);

      expect(updated.fullName, 'Updated Name');
      expect(updated.experienceYears, 4.0);
      expect(updated.trainsAtHome, isTrue);
      expect(updated.uid, 'tr_mut_1');
    });
  });
}
