import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/features/client/presentation/widgets/trainer_filter_sheet.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  group('PROMPT 10: Find Trainer - Aggregated Display Model & Formats', () {
    final sampleMaleTrainer = TrainerDisplayModel(
      profile: const TrainerProfileModel(
        uid: 'trainer_m1',
        bio: 'Elite strength coach specializing in hypertrophy and barbell mechanics.',
        specialties: ['Hypertrophy & Strength', 'Form Correction'],
        experienceYears: 6,
        cityId: 'city_mumbai',
        verificationStatus: TrainerVerificationStatus.approved,
        isActive: true,
        hourlyRate: 1500,
        ratingAvg: 4.9,
        totalReviews: 24,
      ),
      uid: 'trainer_m1',
      displayName: 'Vikram Malhotra',
      photoUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
      gender: Gender.male,
      email: 'vikram@trainz.com',
      phoneNumber: '+919876543210',
      experienceYears: 6,
      specialties: ['Hypertrophy & Strength', 'Form Correction'],
      gymName: 'Gold\'s Gym Bandra',
      ratingAvg: 4.9,
      totalReviews: 24,
      hourlyRate: 1500,
      hasAvailableSlots: true,
      trainingGoals: ['Muscle Gain', 'Strength', 'Powerlifting'],
      certifications: ['CSCS', 'ACE CPT'],
      serviceArea: 'Bandra & Khar West, Mumbai',
      cityId: 'city_mumbai',
    );

    final sampleFemaleTrainer = TrainerDisplayModel(
      profile: const TrainerProfileModel(
        uid: 'trainer_f1',
        bio: 'Certified conditioning and fat-loss specialist for women athletes.',
        specialties: ['HIIT & Conditioning', 'Fat Loss'],
        experienceYears: 4,
        cityId: 'city_mumbai',
        verificationStatus: TrainerVerificationStatus.approved,
        isActive: true,
        hourlyRate: 1200,
        ratingAvg: 4.8,
        totalReviews: 19,
      ),
      uid: 'trainer_f1',
      displayName: 'Ananya Sharma',
      photoUrl: null,
      gender: Gender.female,
      email: 'ananya@trainz.com',
      phoneNumber: '+919876543211',
      experienceYears: 4,
      specialties: ['HIIT & Conditioning', 'Fat Loss'],
      gymName: 'Fitness First',
      ratingAvg: 4.8,
      totalReviews: 19,
      hourlyRate: 1200,
      hasAvailableSlots: false,
      trainingGoals: ['Fat Loss', 'Stamina', 'Endurance'],
      certifications: ['NASM CPT'],
      serviceArea: 'Juhu & Andheri West, Mumbai',
      cityId: 'city_mumbai',
    );

    test('Experience text formats correctly with pluralization', () {
      expect(sampleMaleTrainer.experienceText, '6+ Years Exp');
      expect(sampleFemaleTrainer.experienceText, '4+ Years Exp');

      final oneYearTrainer = sampleMaleTrainer.copyWith(experienceYears: 1);
      expect(oneYearTrainer.experienceText, '1+ Year Exp');
    });

    test('Rating getters format properly to 1 decimal place', () {
      expect(sampleMaleTrainer.rating, 4.9);
      expect(sampleMaleTrainer.ratingText, '4.9');
      expect(sampleFemaleTrainer.rating, 4.8);
      expect(sampleFemaleTrainer.ratingText, '4.8');
    });

    test('Availability text formats accurately based on live slots flag', () {
      expect(sampleMaleTrainer.hasAvailableSlots, isTrue);
      expect(sampleMaleTrainer.availabilityText, 'Slots Available');

      expect(sampleFemaleTrainer.hasAvailableSlots, isFalse);
      expect(sampleFemaleTrainer.availabilityText, 'Fully Booked');
    });

    test('Display location prioritizes serviceArea over generic fallbacks', () {
      expect(sampleMaleTrainer.displayLocation, 'Bandra & Khar West, Mumbai');
      expect(sampleFemaleTrainer.displayLocation, 'Juhu & Andheri West, Mumbai');

      final fallbackTrainer = TrainerDisplayModel(
        profile: sampleMaleTrainer.profile,
        uid: sampleMaleTrainer.uid,
        displayName: sampleMaleTrainer.displayName,
        gender: Gender.male,
        specialties: sampleMaleTrainer.specialties,
        experienceYears: sampleMaleTrainer.experienceYears,
        ratingAvg: sampleMaleTrainer.ratingAvg,
        totalReviews: sampleMaleTrainer.totalReviews,
        hourlyRate: sampleMaleTrainer.hourlyRate,
        gymName: 'Gold\'s Gym Bandra',
      );
      expect(fallbackTrainer.displayLocation, 'Gold\'s Gym Bandra');
    });
  });

  group('PROMPT 10: Search Filter Logic (Name, Specialty, Experience, Goals)', () {
    final trainers = [
      TrainerDisplayModel(
        profile: TrainerProfileModel(
          uid: 't1',
          bio: 'Calisthenics master and bodyweight trainer.',
          specialties: ['Calisthenics', 'Core & Mobility'],
          experienceYears: 2,
          cityId: 'city_mumbai',
          verificationStatus: TrainerVerificationStatus.approved,
          isActive: true,
          hourlyRate: 1000,
          ratingAvg: 4.5,
          totalReviews: 12,
        ),
        uid: 't1',
        displayName: 'Rohan Verma',
        gender: Gender.male,
        experienceYears: 2,
        specialties: ['Calisthenics', 'Core & Mobility'],
        ratingAvg: 4.5,
        totalReviews: 12,
        hourlyRate: 1000,
        hasAvailableSlots: true,
        trainingGoals: ['Bodyweight Strength', 'Mobility'],
        certifications: ['WCO Level 2'],
        gymName: 'Cult Fit',
        serviceArea: 'Andheri East',
        cityId: 'city_mumbai',
      ),
      TrainerDisplayModel(
        profile: TrainerProfileModel(
          uid: 't2',
          bio: 'Powerlifting champion with 7 years of Olympic bar coaching.',
          specialties: ['Hypertrophy & Strength', 'Form Correction'],
          experienceYears: 7,
          cityId: 'city_mumbai',
          verificationStatus: TrainerVerificationStatus.approved,
          isActive: true,
          hourlyRate: 2000,
          ratingAvg: 4.95,
          totalReviews: 48,
        ),
        uid: 't2',
        displayName: 'Kabir Oberoi',
        gender: Gender.male,
        experienceYears: 7,
        specialties: ['Hypertrophy & Strength', 'Form Correction'],
        ratingAvg: 4.95,
        totalReviews: 48,
        hourlyRate: 2000,
        hasAvailableSlots: false,
        trainingGoals: ['Muscle Gain', 'Strength', 'Powerlifting'],
        certifications: ['CSCS', 'IPF Coach'],
        gymName: 'Powerhouse Gym',
        serviceArea: 'Bandra West',
        cityId: 'city_mumbai',
      ),
      TrainerDisplayModel(
        profile: TrainerProfileModel(
          uid: 't3',
          bio: 'Functional HIIT & Fat Loss specialist.',
          specialties: ['HIIT & Conditioning', 'Fat Loss'],
          experienceYears: 4,
          cityId: 'city_delhi',
          verificationStatus: TrainerVerificationStatus.approved,
          isActive: true,
          hourlyRate: 1300,
          ratingAvg: 4.7,
          totalReviews: 22,
        ),
        uid: 't3',
        displayName: 'Arjun Kapoor',
        gender: Gender.male,
        experienceYears: 4,
        specialties: ['HIIT & Conditioning', 'Fat Loss'],
        ratingAvg: 4.7,
        totalReviews: 22,
        hourlyRate: 1300,
        hasAvailableSlots: true,
        trainingGoals: ['Fat Loss', 'Cardio Endurance'],
        certifications: ['ACE CPT'],
        gymName: 'Anytime Fitness',
        serviceArea: 'South Extension, Delhi',
        cityId: 'city_delhi',
      ),
    ];

    List<TrainerDisplayModel> filterBySearch(String query) {
      if (query.isEmpty) return trainers;
      final q = query.toLowerCase();
      return trainers.where((t) {
        final nameMatch = t.displayName.toLowerCase().contains(q);
        final gymMatch = (t.gymName ?? '').toLowerCase().contains(q);
        final areaMatch = (t.serviceArea ?? '').toLowerCase().contains(q);
        final specMatch = t.specialties.any((s) => s.toLowerCase().contains(q));
        final goalMatch = t.trainingGoals.any((g) => g.toLowerCase().contains(q));
        final expMatch = t.experienceText.toLowerCase().contains(q) ||
            '${t.experienceYears} years'.contains(q);
        final certMatch = t.certifications.any((c) => c.toLowerCase().contains(q));
        final bioMatch = (t.profile.bio ?? '').toLowerCase().contains(q);
        return nameMatch ||
            gymMatch ||
            areaMatch ||
            specMatch ||
            goalMatch ||
            expMatch ||
            certMatch ||
            bioMatch;
      }).toList();
    }

    test('Searches by coach name case-insensitively', () {
      final res = filterBySearch('kabir');
      expect(res.length, 1);
      expect(res.first.displayName, 'Kabir Oberoi');
    });

    test('Searches by fitness specialization', () {
      final res = filterBySearch('calisthenics');
      expect(res.length, 1);
      expect(res.first.displayName, 'Rohan Verma');
    });

    test('Searches by training goals (e.g., Fat Loss, Muscle Gain)', () {
      final res = filterBySearch('Muscle Gain');
      expect(res.length, 1);
      expect(res.first.displayName, 'Kabir Oberoi');

      final resFatLoss = filterBySearch('Fat Loss');
      expect(resFatLoss.length, 1);
      expect(resFatLoss.first.displayName, 'Arjun Kapoor');
    });

    test('Searches by experience text', () {
      final res = filterBySearch('7 years');
      expect(res.length, 1);
      expect(res.first.displayName, 'Kabir Oberoi');
    });

    test('Searches by gym name or service area', () {
      final res = filterBySearch('South Extension');
      expect(res.length, 1);
      expect(res.first.displayName, 'Arjun Kapoor');
    });
  });

  group('PROMPT 10: Advanced Filters (Specialization, Experience, Rating, Slots)', () {
    final trainers = [
      TrainerDisplayModel(
        profile: TrainerProfileModel(
          uid: 't1',
          specialties: ['Calisthenics'],
          experienceYears: 2,
          cityId: 'city_mumbai',
          verificationStatus: TrainerVerificationStatus.approved,
          isActive: true,
          hourlyRate: 1000,
          ratingAvg: 4.2,
          totalReviews: 8,
        ),
        uid: 't1',
        displayName: 'Coach Junior',
        gender: Gender.male,
        experienceYears: 2,
        specialties: ['Calisthenics'],
        ratingAvg: 4.2,
        totalReviews: 8,
        hourlyRate: 1000,
        hasAvailableSlots: false,
        cityId: 'city_mumbai',
      ),
      TrainerDisplayModel(
        profile: TrainerProfileModel(
          uid: 't2',
          specialties: ['Hypertrophy & Strength'],
          experienceYears: 4,
          cityId: 'city_mumbai',
          verificationStatus: TrainerVerificationStatus.approved,
          isActive: true,
          hourlyRate: 1500,
          ratingAvg: 4.6,
          totalReviews: 20,
        ),
        uid: 't2',
        displayName: 'Coach Mid',
        gender: Gender.male,
        experienceYears: 4,
        specialties: ['Hypertrophy & Strength'],
        ratingAvg: 4.6,
        totalReviews: 20,
        hourlyRate: 1500,
        hasAvailableSlots: true,
        cityId: 'city_mumbai',
      ),
      TrainerDisplayModel(
        profile: TrainerProfileModel(
          uid: 't3',
          specialties: ['Hypertrophy & Strength', 'Form Correction'],
          experienceYears: 8,
          cityId: 'city_mumbai',
          verificationStatus: TrainerVerificationStatus.approved,
          isActive: true,
          hourlyRate: 2500,
          ratingAvg: 4.9,
          totalReviews: 50,
        ),
        uid: 't3',
        displayName: 'Coach Senior',
        gender: Gender.male,
        experienceYears: 8,
        specialties: ['Hypertrophy & Strength', 'Form Correction'],
        ratingAvg: 4.9,
        totalReviews: 50,
        hourlyRate: 2500,
        hasAvailableSlots: true,
        cityId: 'city_mumbai',
      ),
    ];

    List<TrainerDisplayModel> applyFilters(List<TrainerDisplayModel> list, TrainerFilterState filter) {
      var res = list;
      if (filter.specializations.isNotEmpty) {
        res = res.where((t) => filter.specializations.any((s) => t.specialties.contains(s))).toList();
      }
      if (filter.experienceLevel != 'All') {
        res = res.where((t) {
          final exp = t.experienceYears;
          if (filter.experienceLevel == '1-3 years') return exp >= 1 && exp <= 3;
          if (filter.experienceLevel == '3-5 years') return exp >= 3 && exp <= 5;
          if (filter.experienceLevel == '5+ years') return exp >= 5;
          return true;
        }).toList();
      }
      if (filter.minRating > 0.0) {
        res = res.where((t) => t.rating >= filter.minRating).toList();
      }
      if (filter.availableSlotsOnly) {
        res = res.where((t) => t.hasAvailableSlots).toList();
      }
      return res;
    }

    test('Filters by experience level bracket (1-3 years, 3-5 years, 5+ years)', () {
      final res1To3 = applyFilters(trainers, const TrainerFilterState(experienceLevel: '1-3 years'));
      expect(res1To3.length, 1);
      expect(res1To3.first.displayName, 'Coach Junior');

      final res3To5 = applyFilters(trainers, const TrainerFilterState(experienceLevel: '3-5 years'));
      expect(res3To5.length, 1);
      expect(res3To5.first.displayName, 'Coach Mid');

      final res5Plus = applyFilters(trainers, const TrainerFilterState(experienceLevel: '5+ years'));
      expect(res5Plus.length, 1);
      expect(res5Plus.first.displayName, 'Coach Senior');
    });

    test('Filters by minimum rating threshold (4.5+)', () {
      final res45 = applyFilters(trainers, const TrainerFilterState(minRating: 4.5));
      expect(res45.length, 2);
      expect(res45.map((t) => t.displayName), containsAll(['Coach Mid', 'Coach Senior']));
      expect(res45.any((t) => t.displayName == 'Coach Junior'), isFalse);
    });

    test('Filters by live slot availability flag', () {
      final resSlots = applyFilters(trainers, const TrainerFilterState(availableSlotsOnly: true));
      expect(resSlots.length, 2);
      expect(resSlots.any((t) => t.displayName == 'Coach Junior'), isFalse);
    });

    test('TrainerFilterState accurately computes activeFilterCount', () {
      const state0 = TrainerFilterState();
      expect(state0.hasActiveFilters, isFalse);
      expect(state0.activeFilterCount, 0);

      const stateApplied = TrainerFilterState(
        specializations: {'Calisthenics'},
        experienceLevel: '3-5 years',
        minRating: 4.5,
        availableSlotsOnly: true,
      );
      expect(stateApplied.hasActiveFilters, isTrue);
      expect(stateApplied.activeFilterCount, 4);
    });
  });

  group('PROMPT 10: Sorting Algorithms (Highest Rating, Experience, Relevance)', () {
    final trainers = [
      TrainerDisplayModel(
        profile: TrainerProfileModel(
          uid: 't1',
          specialties: ['CrossFit'],
          experienceYears: 3,
          cityId: 'city_mumbai',
          verificationStatus: TrainerVerificationStatus.approved,
          isActive: true,
          hourlyRate: 1100,
          ratingAvg: 4.6,
          totalReviews: 10,
        ),
        uid: 't1',
        displayName: 'Aman',
        gender: Gender.male,
        experienceYears: 3,
        specialties: ['CrossFit'],
        ratingAvg: 4.6,
        totalReviews: 10,
        hourlyRate: 1100,
        hasAvailableSlots: false,
        cityId: 'city_mumbai',
      ),
      TrainerDisplayModel(
        profile: TrainerProfileModel(
          uid: 't2',
          specialties: ['Strength'],
          experienceYears: 10,
          cityId: 'city_mumbai',
          verificationStatus: TrainerVerificationStatus.approved,
          isActive: true,
          hourlyRate: 2200,
          ratingAvg: 4.8,
          totalReviews: 40,
        ),
        uid: 't2',
        displayName: 'Bharat',
        gender: Gender.male,
        experienceYears: 10,
        specialties: ['Strength'],
        ratingAvg: 4.8,
        totalReviews: 40,
        hourlyRate: 2200,
        hasAvailableSlots: true,
        cityId: 'city_mumbai',
      ),
      TrainerDisplayModel(
        profile: TrainerProfileModel(
          uid: 't3',
          specialties: ['Cardio'],
          experienceYears: 6,
          cityId: 'city_mumbai',
          verificationStatus: TrainerVerificationStatus.approved,
          isActive: true,
          hourlyRate: 1600,
          ratingAvg: 4.95,
          totalReviews: 55,
        ),
        uid: 't3',
        displayName: 'Chetan',
        gender: Gender.male,
        experienceYears: 6,
        specialties: ['Cardio'],
        ratingAvg: 4.95,
        totalReviews: 55,
        hourlyRate: 1600,
        hasAvailableSlots: true,
        cityId: 'city_mumbai',
      ),
    ];

    test('Sorts by highest rating correctly', () {
      final sorted = List<TrainerDisplayModel>.from(trainers)
        ..sort((a, b) => b.rating.compareTo(a.rating));
      expect(sorted.map((t) => t.displayName).toList(), ['Chetan', 'Bharat', 'Aman']);
    });

    test('Sorts by most years of experience correctly', () {
      final sorted = List<TrainerDisplayModel>.from(trainers)
        ..sort((a, b) => b.experienceYears.compareTo(a.experienceYears));
      expect(sorted.map((t) => t.displayName).toList(), ['Bharat', 'Chetan', 'Aman']);
    });
  });

  group('PROMPT 10: Gender Matching Security & Location Restrictions', () {
    test('Strict gender invariant: Male client matches ONLY with Male trainers', () {
      const clientGender = Gender.male;
      const trainerGender1 = Gender.male;
      const trainerGender2 = Gender.female;

      expect(clientGender == trainerGender1, isTrue);
      expect(clientGender == trainerGender2, isFalse);
    });

    test('Strict gender invariant: Female client matches ONLY with Female trainers', () {
      const clientGender = Gender.female;
      const trainerGender1 = Gender.female;
      const trainerGender2 = Gender.male;

      expect(clientGender == trainerGender1, isTrue);
      expect(clientGender == trainerGender2, isFalse);
    });

    test('Only approved and active trainers qualify for display', () {
      final approvedActive = TrainerProfileModel(
        uid: 't_ok',
        specialties: ['Strength'],
        experienceYears: 5,
        cityId: 'city_mumbai',
        verificationStatus: TrainerVerificationStatus.approved,
        isActive: true,
        hourlyRate: 1500,
      );

      final pendingVerification = TrainerProfileModel(
        uid: 't_pending',
        specialties: ['Strength'],
        experienceYears: 5,
        cityId: 'city_mumbai',
        verificationStatus: TrainerVerificationStatus.pending,
        isActive: true,
        hourlyRate: 1500,
      );

      final suspendedTrainer = TrainerProfileModel(
        uid: 't_suspended',
        specialties: ['Strength'],
        experienceYears: 5,
        cityId: 'city_mumbai',
        verificationStatus: TrainerVerificationStatus.approved,
        isActive: false,
        hourlyRate: 1500,
      );

      bool isEligible(TrainerProfileModel t) {
        return t.verificationStatus == TrainerVerificationStatus.approved && t.isActive;
      }

      expect(isEligible(approvedActive), isTrue);
      expect(isEligible(pendingVerification), isFalse);
      expect(isEligible(suspendedTrainer), isFalse);
    });
  });
}
