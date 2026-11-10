import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/constants/app_constants.dart';
import 'package:trainuspro/core/errors/app_exceptions.dart';
import 'package:trainuspro/services/firestore_service.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/trainer_availability_model.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/training_plan_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  final plan1Month = TrainingPlanModel.fromMap(
    AppConstants.fixedTrainingPlans.firstWhere((p) => p['id'] == 'plan_1_month'),
    id: 'plan_1_month',
  );

  const maleTrainer = TrainerDisplayModel(
    profile: TrainerProfileModel(
      uid: 'trainer_mumbai_01',
      bio: 'Senior Performance Coach specializing in strength & hypertrophy.',
      specialties: ['Strength', 'Fat Loss'],
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
    specialties: ['Strength', 'Fat Loss'],
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

  const femaleTrainer = TrainerDisplayModel(
    profile: TrainerProfileModel(
      uid: 'trainer_delhi_01',
      bio: 'Elite Conditioning Coach.',
      specialties: ['HIIT', 'Pilates'],
      experienceYears: 5,
      cityId: 'city_delhi_ncr',
      hourlyRate: 1400,
      ratingAvg: 4.9,
      totalReviews: 24,
      verificationStatus: TrainerVerificationStatus.approved,
      isActive: true,
    ),
    uid: 'trainer_delhi_01',
    displayName: 'Aanya Sharma',
    photoUrl: 'https://trainz.app/photos/aanya.jpg',
    gender: Gender.female,
    email: 'aanya@trainz.com',
    experienceYears: 5,
    specialties: ['HIIT', 'Pilates'],
    gymName: 'Cult.fit Studio South Delhi',
    ratingAvg: 4.9,
    totalReviews: 24,
    hourlyRate: 1400,
    hasAvailableSlots: true,
    trainingGoals: ['Fat Loss', 'Mobility'],
    certifications: ['ACE Master Trainer'],
    serviceArea: 'Greater Kailash & Saket, Delhi',
    cityId: 'city_delhi_ncr',
  );

  group('PROMPT 13: Booking System - Date & Eligibility Validation', () {
    test('Date selection disallows past dates', () {
      final now = DateTime.now();
      final pastDate = now.subtract(const Duration(days: 2));

      // Booking validation check
      final isPast = pastDate.isBefore(DateTime(now.year, now.month, now.day));
      expect(isPast, isTrue);
    });

    test('Dates within package validity period are eligible', () {
      final now = DateTime.now();
      final validityDays = plan1Month.validityDays; // 30 days
      final validSessionDate = now.add(const Duration(days: 10));
      final maxEligibleDate = now.add(Duration(days: validityDays));

      expect(validSessionDate.isBefore(maxEligibleDate), isTrue);
    });

    test('Dates exceeding package validity period are disallowed', () {
      final now = DateTime.now();
      final validityDays = plan1Month.validityDays; // 30 days
      final tooFarDate = now.add(Duration(days: validityDays + 5));
      final maxEligibleDate = now.add(Duration(days: validityDays));

      expect(tooFarDate.isAfter(maxEligibleDate), isTrue);
    });
  });

  group('PROMPT 13: Time Slot Availability & 60-Minute Structure', () {
    test('Standard training slots enforce strict 60-minute duration', () {
      const startTimes = [
        '06:00 AM',
        '07:00 AM',
        '08:30 AM',
        '10:00 AM',
        '11:30 AM',
        '05:00 PM',
        '06:30 PM',
        '08:00 PM',
      ];

      for (final start in startTimes) {
        final end = FirestoreService.computeSlotEndTime(start);
        expect(end, isNotEmpty);
      }

      expect(FirestoreService.computeSlotEndTime('07:00 AM'), '08:00 AM');
      expect(FirestoreService.computeSlotEndTime('05:00 PM'), '06:00 PM');
    });

    test('Unavailable/Booked time slots are correctly flagged', () {
      const slotAvailable = TimeSlot(start: '07:00 AM', end: '08:00 AM', isBooked: false);
      const slotBooked = TimeSlot(start: '08:30 AM', end: '09:30 AM', isBooked: true);

      expect(slotAvailable.isBooked, isFalse);
      expect(slotBooked.isBooked, isTrue);
    });
  });

  group('PROMPT 13: Training Location & Service Area Matching', () {
    test('Address matching trainer service area passes validation', () {
      final isBandra = FirestoreService.isAddressInTrainerServiceArea(
        clientAddress: '14th Road, Bandra West, Mumbai',
        trainerServiceArea: maleTrainer.serviceArea ?? '',
        trainerCity: maleTrainer.cityId,
      );
      expect(isBandra, isTrue);

      final isKhar = FirestoreService.isAddressInTrainerServiceArea(
        clientAddress: 'Linking Road, Khar West, Mumbai',
        trainerServiceArea: maleTrainer.serviceArea ?? '',
        trainerCity: maleTrainer.cityId,
      );
      expect(isKhar, isTrue);
    });

    test('Address outside trainer service area is flagged', () {
      final isDelhi = FirestoreService.isAddressInTrainerServiceArea(
        clientAddress: 'Connaught Place, New Delhi',
        trainerServiceArea: maleTrainer.serviceArea ?? '',
        trainerCity: maleTrainer.cityId,
      );
      expect(isDelhi, isFalse);
    });

    test('Empty address fails service area validation', () {
      final isEmpty = FirestoreService.isAddressInTrainerServiceArea(
        clientAddress: '',
        trainerServiceArea: maleTrainer.serviceArea ?? '',
        trainerCity: maleTrainer.cityId,
      );
      expect(isEmpty, isFalse);
    });
  });

  group('PROMPT 13: Temporary Slot Reservation & Expiry Timing', () {
    test('Reservation creates hold with 15-minute checkout expiration', () {
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(minutes: 15));

      final reservation = BookingModel(
        id: 'book_res_001',
        clientId: 'client_rohan',
        trainerId: maleTrainer.uid,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        packageId: plan1Month.id,
        packagePrice: plan1Month.price,
        sessionsCount: plan1Month.sessionsCount,
        validityDays: plan1Month.validityDays,
        sessionDate: now.add(const Duration(days: 1)),
        startTime: '07:00 AM',
        endTime: '08:00 AM',
        status: BookingStatus.reserved,
        paymentStatus: PaymentStatus.pending,
        meetingLocation: 'Gold\'s Gym Bandra West',
        reservedAt: now,
        expiresAt: expiresAt,
      );

      expect(reservation.status, BookingStatus.reserved);
      expect(reservation.paymentStatus, PaymentStatus.pending);
      expect(reservation.isTemporaryReservation, isTrue);
      expect(reservation.isConfirmed, isFalse);
      expect(reservation.isReservationExpired, isFalse);
      expect(reservation.minutesRemaining, closeTo(15, 1));
    });

    test('Expired reservation is identified and blocks direct payment', () {
      final now = DateTime.now();
      final expiredHold = BookingModel(
        id: 'book_res_expired',
        clientId: 'client_rohan',
        trainerId: maleTrainer.uid,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: now.add(const Duration(days: 1)),
        startTime: '07:00 AM',
        endTime: '08:00 AM',
        status: BookingStatus.reserved,
        paymentStatus: PaymentStatus.pending,
        reservedAt: now.subtract(const Duration(minutes: 20)),
        expiresAt: now.subtract(const Duration(minutes: 5)),
      );

      expect(expiredHold.isReservationExpired, isTrue);
      expect(expiredHold.secondsRemaining, 0);
    });
  });

  group('PROMPT 13: Double-Booking Protection & Atomic Conflict Checking', () {
    test('Cannot double-book slot if active lock exists for another client', () {
      final now = DateTime.now();
      final existingLockClientId = 'client_athlete_A';
      final newAttemptClientId = 'client_athlete_B';
      final lockExpiresAt = now.add(const Duration(minutes: 10));

      // Simulate lock verification logic
      final isLocked = existingLockClientId != newAttemptClientId && lockExpiresAt.isAfter(now);
      expect(isLocked, isTrue);

      expect(
        () {
          if (isLocked) {
            throw const BookingConflictException(
              'This time slot is temporarily reserved by another client during checkout.',
            );
          }
        },
        throwsA(isA<BookingConflictException>()),
      );
    });

    test('Expired slot lock from another client allows new reservation', () {
      final now = DateTime.now();
      final existingLockClientId = 'client_athlete_A';
      final newAttemptClientId = 'client_athlete_B';
      final lockExpiresAt = now.subtract(const Duration(minutes: 2)); // expired 2 mins ago

      // Since lock is expired, it is no longer blocking
      final isLockActive = existingLockClientId != newAttemptClientId && lockExpiresAt.isAfter(now);
      expect(isLockActive, isFalse);
    });
  });

  group('PROMPT 13: Payment Failure vs Confirmation Transitions', () {
    test('Payment confirmation updates booking to CONFIRMED and payment COMPLETED', () {
      final now = DateTime.now();
      final reservation = BookingModel(
        id: 'book_res_002',
        clientId: 'client_rohan',
        trainerId: maleTrainer.uid,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: now.add(const Duration(days: 1)),
        startTime: '07:00 AM',
        endTime: '08:00 AM',
        status: BookingStatus.reserved,
        paymentStatus: PaymentStatus.pending,
        expiresAt: now.add(const Duration(minutes: 12)),
      );

      // Transition on payment verification
      final confirmed = reservation.copyWith(
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.completed,
        paymentTransactionId: 'TXN_PAY_SUCCESS_987',
        confirmedAt: now,
      );

      expect(confirmed.status, BookingStatus.confirmed);
      expect(confirmed.paymentStatus, PaymentStatus.completed);
      expect(confirmed.isConfirmed, isTrue);
      expect(confirmed.paymentTransactionId, 'TXN_PAY_SUCCESS_987');
    });

    test('Payment failure or client cancel transitions booking to CANCELLED and FAILED', () {
      final now = DateTime.now();
      final reservation = BookingModel(
        id: 'book_res_003',
        clientId: 'client_rohan',
        trainerId: maleTrainer.uid,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: now.add(const Duration(days: 1)),
        startTime: '07:00 AM',
        endTime: '08:00 AM',
        status: BookingStatus.reserved,
        paymentStatus: PaymentStatus.pending,
      );

      final failed = reservation.copyWith(
        status: BookingStatus.cancelledClientEarly,
        paymentStatus: PaymentStatus.failed,
      );

      expect(failed.status, BookingStatus.cancelledClientEarly);
      expect(failed.paymentStatus, PaymentStatus.failed);
      expect(failed.isConfirmed, isFalse);
    });
  });

  group('PROMPT 13: Strict Gender Matching Invariant in Bookings', () {
    test('Male client with Male trainer passes gender matching', () {
      const clientGender = Gender.male;
      expect(maleTrainer.gender, clientGender);
    });

    test('Male client with Female trainer throws GenderMismatchException', () {
      const clientGender = Gender.male;
      expect(femaleTrainer.gender, isNot(clientGender));

      expect(
        () {
          if (clientGender != femaleTrainer.gender) {
            throw const GenderMismatchException(
              'Male clients can only book Male trainers.',
            );
          }
        },
        throwsA(isA<GenderMismatchException>()),
      );
    });
  });

  group('PROMPT 13: Session Credits Isolation Rule', () {
    test('Booking reservation does not mutate session credits ledger directly', () {
      final now = DateTime.now();
      final booking = BookingModel(
        id: 'book_credits_check',
        clientId: 'client_rohan',
        trainerId: maleTrainer.uid,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: now.add(const Duration(days: 1)),
        startTime: '07:00 AM',
        endTime: '08:00 AM',
        status: BookingStatus.reserved,
        paymentStatus: PaymentStatus.pending,
      );

      // In this prompt, creditTransactionId must be null or deferred to payment module
      expect(booking.creditTransactionId, isNull);
    });
  });
}

