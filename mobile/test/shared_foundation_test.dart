import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/constants/app_constants.dart';
import 'package:trainuspro/core/constants/firestore_collections.dart';
import 'package:trainuspro/core/utils/date_time_utils.dart';
import 'package:trainuspro/core/utils/validators.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/session_credit_model.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/training_plan_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  group('Section 7: Fixed Platform Training Packages', () {
    test('contains all 6 required platform packages with exact pricing & sessions', () {
      final plans = AppConstants.fixedTrainingPlans;
      expect(plans.length, 6);

      final expected = [
        {'title': '1 Day', 'price': 500, 'sessions': 1, 'validityDays': 1},
        {'title': '3 Days', 'price': 1399, 'sessions': 3, 'validityDays': 3},
        {'title': '1 Week', 'price': 2799, 'sessions': 6, 'validityDays': 7},
        {'title': '1 Month', 'price': 10799, 'sessions': 26, 'validityDays': 30},
        {'title': '3 Months', 'price': 29999, 'sessions': 78, 'validityDays': 90},
        {'title': '6-Month Transformation', 'price': 52999, 'sessions': 150, 'validityDays': 180},
      ];

      for (int i = 0; i < expected.length; i++) {
        expect(plans[i]['title'], expected[i]['title']);
        expect(plans[i]['price'], expected[i]['price']);
        expect(plans[i]['sessions'], expected[i]['sessions']);
        expect(plans[i]['validityDays'], expected[i]['validityDays']);
        expect(plans[i]['sessionDurationMinutes'], 60);
      }
    });

    test('TrainingPlanModel price per session calculation', () {
      final plan = TrainingPlanModel(
        id: 'plan_1_month',
        title: '1 Month',
        price: 10799,
        sessionsCount: 26,
        validityDays: 30,
        description: 'Test monthly plan',
      );
      expect(plan.pricePerSession, closeTo(415.34, 0.05));
    });
  });

  group('Section 5: Gender Matching Business Rules', () {
    test('Male client with Male trainer is valid match', () {
      final booking = BookingModel(
        id: 'b1',
        clientId: 'c1',
        trainerId: 't1',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime.now().add(const Duration(days: 2)),
        startTime: '07:00',
        endTime: '08:00',
      );
      expect(booking.hasValidGenderMatch, isTrue);
    });

    test('Female client with Female trainer is valid match', () {
      final booking = BookingModel(
        id: 'b2',
        clientId: 'c2',
        trainerId: 't2',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        sessionDate: DateTime.now().add(const Duration(days: 2)),
        startTime: '08:00',
        endTime: '09:00',
      );
      expect(booking.hasValidGenderMatch, isTrue);
    });

    test('Male client with Female trainer violates matching rule', () {
      final booking = BookingModel(
        id: 'b3',
        clientId: 'c1',
        trainerId: 't2',
        clientGender: Gender.male,
        trainerGender: Gender.female,
        sessionDate: DateTime.now().add(const Duration(days: 2)),
        startTime: '07:00',
        endTime: '08:00',
      );
      expect(booking.hasValidGenderMatch, isFalse);
    });

    test('Female client with Male trainer violates matching rule', () {
      final booking = BookingModel(
        id: 'b4',
        clientId: 'c2',
        trainerId: 't1',
        clientGender: Gender.female,
        trainerGender: Gender.male,
        sessionDate: DateTime.now().add(const Duration(days: 2)),
        startTime: '07:00',
        endTime: '08:00',
      );
      expect(booking.hasValidGenderMatch, isFalse);
    });
  });

  group('Section 8: 12-Hour Cancellation Policy', () {
    test('Cancellation >= 12h qualifies for full credit return', () {
      final now = DateTime(2026, 11, 10, 10, 0);
      final sessionTime = DateTime(2026, 11, 10, 23, 0); // 13 hours away
      final canReturn = DateTimeUtils.canReturnCreditOnClientCancellation(sessionTime, now: now);
      expect(canReturn, isTrue);
    });

    test('Cancellation exact 12h qualifies for credit return', () {
      final now = DateTime(2026, 11, 10, 10, 0);
      final sessionTime = DateTime(2026, 11, 10, 22, 0); // 12 hours away
      final canReturn = DateTimeUtils.canReturnCreditOnClientCancellation(sessionTime, now: now);
      expect(canReturn, isTrue);
    });

    test('Cancellation < 12h results in credit forfeiture', () {
      final now = DateTime(2026, 11, 10, 10, 0);
      final sessionTime = DateTime(2026, 11, 10, 20, 0); // 10 hours away
      final canReturn = DateTimeUtils.canReturnCreditOnClientCancellation(sessionTime, now: now);
      expect(canReturn, isFalse);
    });
  });

  group('Section 8: Credit Ledger Balance Calculations', () {
    test('computes available credits correctly accounting for reserved, consumed, returned and forfeited', () {
      const credit = SessionCreditModel(
        clientId: 'client_123',
        totalPurchased: 26,
        totalReserved: 2,
        totalConsumed: 10,
        totalReturned: 1,
        totalForfeited: 1,
        availableBalance: 14,
      );
      // (26 purchased + 1 returned) - (2 reserved + 10 consumed + 1 forfeited) = 27 - 13 = 14
      expect(credit.computedAvailable, 14);
      expect(credit.availableBalance, credit.computedAvailable);
    });
  });

  group('Section 4 & 6: User Roles & Trainer Verification', () {
    test('UserRole parsing and serialization', () {
      expect(UserRole.fromFirestore('CLIENT'), UserRole.client);
      expect(UserRole.fromFirestore('TRAINER'), UserRole.trainer);
      expect(UserRole.fromFirestore('ADMIN'), UserRole.admin);
      expect(UserRole.client.toFirestore(), 'CLIENT');
      expect(UserRole.trainer.toFirestore(), 'TRAINER');
      expect(UserRole.admin.toFirestore(), 'ADMIN');
    });

    test('TrainerVerificationStatus checks', () {
      expect(TrainerVerificationStatus.fromFirestore('APPROVED'), TrainerVerificationStatus.approved);
      expect(TrainerVerificationStatus.fromFirestore('PENDING'), TrainerVerificationStatus.pending);
      expect(TrainerVerificationStatus.fromFirestore('REJECTED'), TrainerVerificationStatus.rejected);
      expect(TrainerVerificationStatus.fromFirestore('SUSPENDED'), TrainerVerificationStatus.suspended);

      const trainerApproved = TrainerProfileModel(
        uid: 't1',
        verificationStatus: TrainerVerificationStatus.approved,
        isActive: true,
      );
      expect(trainerApproved.canBeBooked, isTrue);

      const trainerPending = TrainerProfileModel(
        uid: 't2',
        verificationStatus: TrainerVerificationStatus.pending,
        isActive: true,
      );
      expect(trainerPending.canBeBooked, isFalse);

      const trainerInactive = TrainerProfileModel(
        uid: 't3',
        verificationStatus: TrainerVerificationStatus.approved,
        isActive: false,
      );
      expect(trainerInactive.canBeBooked, isFalse);
    });
  });

  group('Validation Utilities', () {
    test('validates email addresses', () {
      expect(Validators.validateEmail('user@trainz.app'), isNull);
      expect(Validators.validateEmail('invalid-email'), isNotNull);
      expect(Validators.validateEmail(''), isNotNull);
    });

    test('validates passwords (min 6 characters)', () {
      expect(Validators.validatePassword('secret123'), isNull);
      expect(Validators.validatePassword('12345'), isNotNull);
    });

    test('validates phone numbers', () {
      expect(Validators.validatePhone('9876543210'), isNull);
      expect(Validators.validatePhone('+919876543210'), isNull);
      expect(Validators.validatePhone('123'), isNotNull);
    });
  });

  group('Firestore Collection Constants', () {
    test('all 12 required collections are defined', () {
      expect(FirestoreCollections.users, 'users');
      expect(FirestoreCollections.clientProfiles, 'client_profiles');
      expect(FirestoreCollections.trainerProfiles, 'trainer_profiles');
      expect(FirestoreCollections.cities, 'cities');
      expect(FirestoreCollections.trainingPlans, 'training_plans');
      expect(FirestoreCollections.bookings, 'bookings');
      expect(FirestoreCollections.payments, 'payments');
      expect(FirestoreCollections.sessionCredits, 'session_credits');
      expect(FirestoreCollections.trainerAvailability, 'trainer_availability');
      expect(FirestoreCollections.reviews, 'reviews');
      expect(FirestoreCollections.notifications, 'notifications');
      expect(FirestoreCollections.platformSettings, 'platform_settings');
    });
  });
}

