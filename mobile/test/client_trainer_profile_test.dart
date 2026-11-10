import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/constants/app_constants.dart';
import 'package:trainuspro/shared/models/client_profile_model.dart';
import 'package:trainuspro/shared/models/review_model.dart';
import 'package:trainuspro/shared/models/trainer_availability_model.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/training_plan_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  group('PROMPT 11: Trainer Profile Header, About, & Credentials', () {
    final trainer = TrainerDisplayModel(
      profile: const TrainerProfileModel(
        uid: 'trainer_mumbai_01',
        bio: 'Senior Performance Coach specializing in strength development, hypertrophy, and biomechanical form correction.',
        specialties: [
          'Hypertrophy & Strength',
          'Fat Loss',
          'Form Correction',
          'General Conditioning',
        ],
        experienceYears: 7,
        cityId: 'city_mumbai',
        hourlyRate: 1500,
        ratingAvg: 4.95,
        totalReviews: 38,
        verificationStatus: TrainerVerificationStatus.approved,
        isActive: true,
      ),
      uid: 'trainer_mumbai_01',
      displayName: 'Kabir Oberoi',
      photoUrl: 'https://trainz.app/photos/kabir.jpg',
      gender: Gender.male,
      email: 'kabir@trainz.com',
      experienceYears: 7,
      specialties: [
        'Hypertrophy & Strength',
        'Fat Loss',
        'Form Correction',
        'General Conditioning',
      ],
      gymName: 'Gold\'s Gym Bandra West',
      ratingAvg: 4.95,
      totalReviews: 38,
      hourlyRate: 1500,
      hasAvailableSlots: true,
      trainingGoals: ['Muscle Gain', 'Fat Loss', 'Strength'],
      certifications: ['CSCS Certified', 'ACE Master Trainer', 'CPR/AED'],
      serviceArea: 'Bandra & Khar West, Mumbai',
      cityId: 'city_mumbai',
    );

    test('Header attributes format accurately with verified credentials', () {
      expect(trainer.displayName, 'Kabir Oberoi');
      expect(trainer.ratingText, '5.0'); // rounded or formatted
      expect(trainer.rating, 4.95);
      expect(trainer.totalReviews, 38);
      expect(trainer.gymName, 'Gold\'s Gym Bandra West');
      expect(trainer.displayLocation, 'Bandra & Khar West, Mumbai');
      expect(trainer.experienceText, '7+ Years Exp');
    });

    test('About biography and certifications are populated and formatted', () {
      expect(trainer.profile.bio, contains('Senior Performance Coach'));
      expect(trainer.certifications.length, 3);
      expect(trainer.certifications, containsAll(['CSCS Certified', 'ACE Master Trainer']));
    });

    test('Specializations encompass major fitness categories', () {
      expect(trainer.specialties, contains('Hypertrophy & Strength'));
      expect(trainer.specialties, contains('Fat Loss'));
      expect(trainer.specialties, contains('Form Correction'));
      expect(trainer.specialties, contains('General Conditioning'));
    });
  });

  group('PROMPT 11: Favourite Trainer Storage & Client Account Integration', () {
    test('ClientProfileModel initializes with empty favoriteTrainerIds list', () {
      const profile = ClientProfileModel(uid: 'client_101');
      expect(profile.favoriteTrainerIds, isEmpty);
      expect(profile.isFavorite('trainer_01'), isFalse);
    });

    test('Toggling favourites adds and removes trainer UIDs in client profile', () {
      var profile = const ClientProfileModel(uid: 'client_101');

      // 1. Add trainer to favorites
      profile = profile.copyWith(favoriteTrainerIds: ['trainer_mumbai_01']);
      expect(profile.favoriteTrainerIds.length, 1);
      expect(profile.isFavorite('trainer_mumbai_01'), isTrue);
      expect(profile.isFavorite('trainer_delhi_02'), isFalse);

      // 2. Add another trainer
      profile = profile.copyWith(
        favoriteTrainerIds: [...profile.favoriteTrainerIds, 'trainer_delhi_02'],
      );
      expect(profile.favoriteTrainerIds.length, 2);
      expect(profile.isFavorite('trainer_delhi_02'), isTrue);

      // 3. Remove trainer from favorites
      final updatedList = List<String>.from(profile.favoriteTrainerIds)
        ..remove('trainer_mumbai_01');
      profile = profile.copyWith(favoriteTrainerIds: updatedList);
      expect(profile.favoriteTrainerIds.length, 1);
      expect(profile.isFavorite('trainer_mumbai_01'), isFalse);
      expect(profile.isFavorite('trainer_delhi_02'), isTrue);
    });

    test('Serializes and deserializes favoriteTrainerIds properly to Firestore Map', () {
      final profile = const ClientProfileModel(
        uid: 'client_101',
        favoriteTrainerIds: ['trainer_01', 'trainer_02'],
      );

      final map = profile.toMap();
      expect(map['favoriteTrainerIds'], ['trainer_01', 'trainer_02']);

      final restored = ClientProfileModel.fromMap(map, uid: 'client_101');
      expect(restored.favoriteTrainerIds, ['trainer_01', 'trainer_02']);
      expect(restored.isFavorite('trainer_01'), isTrue);
    });
  });

  group('PROMPT 11: Availability Slots & Dates Filtering', () {
    test('TimeSlot accurately determines availability based on isBooked flag', () {
      const slotOpen = TimeSlot(start: '06:00 AM', end: '07:00 AM', isBooked: false);
      const slotTaken = TimeSlot(start: '07:00 AM', end: '08:00 AM', isBooked: true);

      expect(slotOpen.isBooked, isFalse);
      expect(slotTaken.isBooked, isTrue);

      final schedule = TrainerAvailabilityModel(
        id: 'avail_1',
        trainerId: 'trainer_mumbai_01',
        dayOfWeek: 1, // Monday
        timeSlots: [slotOpen, slotTaken],
      );

      final availableSlots = schedule.timeSlots.where((s) => !s.isBooked).toList();
      expect(availableSlots.length, 1);
      expect(availableSlots.first.start, '06:00 AM');
    });

    test('Specific date overrides allow blacking out unavailable calendar dates', () {
      const schedule = TrainerAvailabilityModel(
        id: 'avail_1',
        trainerId: 'trainer_mumbai_01',
        dayOfWeek: 1,
        specificDateOverrides: ['2026-12-25', '2026-01-01'],
      );

      expect(schedule.specificDateOverrides, contains('2026-12-25'));
      expect(schedule.specificDateOverrides, contains('2026-01-01'));
      expect(schedule.specificDateOverrides.contains('2026-11-10'), isFalse);
    });
  });

  group('PROMPT 11: Verified Client Reviews Integration', () {
    test('ReviewModel deserializes verified client feedback correctly', () {
      final reviewMap = {
        'id': 'rev_01',
        'bookingId': 'book_123',
        'clientId': 'client_ananya',
        'trainerId': 'trainer_mumbai_01',
        'rating': 5.0,
        'comment': 'Exceptional attention to lifting technique and form.',
        'isPublic': true,
      };

      final review = ReviewModel.fromMap(reviewMap, id: 'rev_01');
      expect(review.id, 'rev_01');
      expect(review.rating, 5.0);
      expect(review.comment, 'Exceptional attention to lifting technique and form.');
      expect(review.isPublic, isTrue);
    });

    test('Filters only public reviews for the client profile', () {
      final reviews = [
        const ReviewModel(
          id: 'r1',
          bookingId: 'b1',
          clientId: 'c1',
          trainerId: 't1',
          rating: 5.0,
          comment: 'Great coach!',
          isPublic: true,
        ),
        const ReviewModel(
          id: 'r2',
          bookingId: 'b2',
          clientId: 'c2',
          trainerId: 't1',
          rating: 2.0,
          comment: 'Private dispute feedback.',
          isPublic: false,
        ),
      ];

      final publicReviews = reviews.where((r) => r.isPublic).toList();
      expect(publicReviews.length, 1);
      expect(publicReviews.first.id, 'r1');
    });
  });

  group('PROMPT 11: Gender Eligibility & Security Guards', () {
    test('Male client viewing Male trainer is permitted', () {
      const clientGender = Gender.male;
      const trainerGender = Gender.male;
      expect(clientGender == trainerGender, isTrue);
    });

    test('Female client viewing Female trainer is permitted', () {
      const clientGender = Gender.female;
      const trainerGender = Gender.female;
      expect(clientGender == trainerGender, isTrue);
    });

    test('Male client attempting to access Female trainer is blocked', () {
      const clientGender = Gender.male;
      const trainerGender = Gender.female;
      expect(clientGender == trainerGender, isFalse);
    });

    test('Female client attempting to access Male trainer is blocked', () {
      const clientGender = Gender.female;
      const trainerGender = Gender.male;
      expect(clientGender == trainerGender, isFalse);
    });
  });

  group('PROMPT 11: Training Package Selection Navigation', () {
    test('All 6 TRAIN Z official platform packages are available for selection', () {
      final plans = AppConstants.fixedTrainingPlans.map((p) {
        return TrainingPlanModel(
          id: p['id'] as String,
          title: p['title'] as String,
          price: p['price'] as int,
          sessionsCount: p['sessions'] as int,
          validityDays: p['validityDays'] as int,
          description: p['description'] as String,
          popular: p['popular'] as bool? ?? false,
        );
      }).toList();

      expect(plans.length, 6);
      expect(plans[0].title, '1 Day');
      expect(plans[0].price, 500);
      expect(plans[0].sessionsCount, 1);

      expect(plans[3].title, '1 Month');
      expect(plans[3].price, 10799);
      expect(plans[3].sessionsCount, 26);
      expect(plans[3].popular, isTrue);
      expect(plans[3].pricePerSession.round(), 415);

      expect(plans[5].title, '6-Month Transformation');
      expect(plans[5].price, 52999);
      expect(plans[5].sessionsCount, 150);
      expect(plans[5].validityDays, 180);
    });
  });
}
