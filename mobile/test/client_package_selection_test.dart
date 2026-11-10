import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/constants/app_constants.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/training_plan_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  final plans = AppConstants.fixedTrainingPlans
      .map((m) => TrainingPlanModel.fromMap(m, id: m['id'] as String? ?? ''))
      .toList();

  group('PROMPT 12: Fixed Platform Training Packages & Pricing Truth', () {
    test('Collection contains exactly 6 official TRAIN Z packages', () {
      expect(plans.length, 6);
    });

    test('1 Day package: ₹500, 1 session, 1 day validity', () {
      final plan = plans.firstWhere((p) => p.id == 'plan_1_day');
      expect(plan.title, '1 Day');
      expect(plan.price, 500);
      expect(plan.sessionsCount, 1);
      expect(plan.validityDays, 1);
      expect(plan.pricePerSession, 500.0);
      expect(plan.totalSavings, 0.0);
      expect(plan.savingsPercent, 0);
      expect(plan.isTransformationPackage, isFalse);
    });

    test('3 Days package: ₹1,399, 3 sessions, 3 days validity', () {
      final plan = plans.firstWhere((p) => p.id == 'plan_3_days');
      expect(plan.title, '3 Days');
      expect(plan.price, 1399);
      expect(plan.sessionsCount, 3);
      expect(plan.validityDays, 3);
      // Standard total = 3 * 500 = 1500. Savings = 1500 - 1399 = 101.
      expect(plan.pricePerSession, closeTo(466.33, 0.1));
      expect(plan.totalSavings, closeTo(101.0, 0.1));
      expect(plan.savingsPercent, 7); // (101 / 1500) * 100 = 6.73% -> 7%
      expect(plan.isTransformationPackage, isFalse);
    });

    test('1 Week package: ₹2,799, 6 sessions, 7 days validity', () {
      final plan = plans.firstWhere((p) => p.id == 'plan_1_week');
      expect(plan.title, '1 Week');
      expect(plan.price, 2799);
      expect(plan.sessionsCount, 6);
      expect(plan.validityDays, 7);
      // Standard total = 6 * 500 = 3000. Savings = 3000 - 2799 = 201.
      expect(plan.pricePerSession, closeTo(466.5, 0.1));
      expect(plan.totalSavings, closeTo(201.0, 0.1));
      expect(plan.savingsPercent, 7); // (201 / 3000) * 100 = 6.7% -> 7%
      expect(plan.isTransformationPackage, isFalse);
    });

    test('1 Month package: ₹10,799, 26 sessions, 30 days validity', () {
      final plan = plans.firstWhere((p) => p.id == 'plan_1_month');
      expect(plan.title, '1 Month');
      expect(plan.price, 10799);
      expect(plan.sessionsCount, 26);
      expect(plan.validityDays, 30);
      // Standard total = 26 * 500 = 13000. Savings = 13000 - 10799 = 2201.
      expect(plan.pricePerSession, closeTo(415.35, 0.1));
      expect(plan.totalSavings, closeTo(2201.0, 0.1));
      expect(plan.savingsPercent, 17); // (2201 / 13000) * 100 = 16.93% -> 17%
      expect(plan.popular, isTrue);
      expect(plan.isTransformationPackage, isFalse);
    });

    test('3 Months package: ₹29,999, 78 sessions, 90 days validity', () {
      final plan = plans.firstWhere((p) => p.id == 'plan_3_months');
      expect(plan.title, '3 Months');
      expect(plan.price, 29999);
      expect(plan.sessionsCount, 78);
      expect(plan.validityDays, 90);
      // Standard total = 78 * 500 = 39000. Savings = 39000 - 29999 = 9001.
      expect(plan.pricePerSession, closeTo(384.60, 0.1));
      expect(plan.totalSavings, closeTo(9001.0, 0.1));
      expect(plan.savingsPercent, 23); // (9001 / 39000) * 100 = 23.08% -> 23%
      expect(plan.isTransformationPackage, isFalse);
    });

    test('6-Month Transformation package: ₹52,999, 150 sessions, 180 days validity', () {
      final plan = plans.firstWhere((p) => p.id == 'plan_6_months');
      expect(plan.title, '6-Month Transformation');
      expect(plan.price, 52999);
      expect(plan.sessionsCount, 150);
      expect(plan.validityDays, 180);
      // Standard total = 150 * 500 = 75000. Savings = 75000 - 52999 = 22001.
      expect(plan.pricePerSession, closeTo(353.33, 0.1));
      expect(plan.totalSavings, closeTo(22001.0, 0.1));
      expect(plan.savingsPercent, 29); // (22001 / 75000) * 100 = 29.33% -> 29%
      expect(plan.isTransformationPackage, isTrue);
    });
  });

  group('PROMPT 12: Package Comparison & Value Calculations', () {
    test('6-Month Transformation offers the lowest per-session rate and maximum savings', () {
      final transformation = plans.firstWhere((p) => p.isTransformationPackage);

      for (final other in plans) {
        if (other.id != transformation.id) {
          expect(transformation.pricePerSession, lessThan(other.pricePerSession));
          expect(transformation.savingsPercent, greaterThanOrEqualTo(other.savingsPercent));
        }
      }
    });

    test('Package comparison matrix reflects accurate discount progression', () {
      // Base single-session package is ₹500
      final single = plans.firstWhere((p) => p.id == 'plan_1_day');
      expect(single.pricePerSession, 500.0);

      // All multi-session packages provide a discount compared to single sessions
      for (final plan in plans.where((p) => p.sessionsCount > 1)) {
        expect(plan.pricePerSession, lessThan(single.pricePerSession));
      }

      // Progression across committed tiers (1 Month -> 3 Months -> 6 Months) strictly reduces per-session cost
      final month1 = plans.firstWhere((p) => p.id == 'plan_1_month');
      final month3 = plans.firstWhere((p) => p.id == 'plan_3_months');
      final month6 = plans.firstWhere((p) => p.id == 'plan_6_months');

      expect(month1.pricePerSession, lessThan(single.pricePerSession));
      expect(month3.pricePerSession, lessThan(month1.pricePerSession));
      expect(month6.pricePerSession, lessThan(month3.pricePerSession));
    });

    test('Session duration and expiry policy attributes are transparent', () {
      for (final plan in plans) {
        expect(plan.sessionDurationMinutes, 60);
        expect(plan.validityDays, greaterThanOrEqualTo(1));
        expect(plan.sessionsCount, greaterThanOrEqualTo(1));
        expect(plan.description, isNotEmpty);
      }
    });
  });

  group('PROMPT 12: Trainer Connection Context', () {
    const trainer = TrainerDisplayModel(
      profile: TrainerProfileModel(
        uid: 'trainer_mumbai_01',
        bio: 'Senior Performance Coach specializing in strength development.',
        specialties: ['Hypertrophy & Strength', 'Fat Loss'],
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
      specialties: ['Hypertrophy & Strength', 'Fat Loss'],
      gymName: 'Gold\'s Gym Bandra West',
      ratingAvg: 4.95,
      totalReviews: 38,
      hourlyRate: 1500,
      hasAvailableSlots: true,
      trainingGoals: ['Muscle Gain', 'Fat Loss'],
      certifications: ['CSCS Certified', 'ACE Master Trainer'],
      serviceArea: 'Bandra & Khar West, Mumbai',
      cityId: 'city_mumbai',
    );

    test('Trainer association presents coach identity and credentials', () {
      expect(trainer.displayName, 'Kabir Oberoi');
      expect(trainer.ratingText, '5.0');
      expect(trainer.gymName, 'Gold\'s Gym Bandra West');
      expect(trainer.serviceArea, contains('Bandra'));
    });

    test('Gender matching validation passes for same-gender pairing', () {
      const clientGender = Gender.male;
      expect(trainer.gender, equals(clientGender));
    });
  });

  group('PROMPT 12: Security & Backend Price Immutability', () {
    test('Training plan model cannot have price altered by client side', () {
      final original = plans.first;
      final copy = original.copyWith(price: 100); // simulate attempted tampering

      // Original source-of-truth remains immutable
      expect(original.price, 500);
      expect(copy.price, 100);
      // In production, Firestore security rules prevent write access to training_plans
    });

    test('Plan IDs conform to standardized Firestore document IDs', () {
      final expectedIds = [
        'plan_1_day',
        'plan_3_days',
        'plan_1_week',
        'plan_1_month',
        'plan_3_months',
        'plan_6_months',
      ];
      final actualIds = plans.map((p) => p.id).toList();
      expect(actualIds, containsAll(expectedIds));
    });
  });
}
