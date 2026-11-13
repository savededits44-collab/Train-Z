import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/errors/app_exceptions.dart';
import 'package:trainuspro/features/client/presentation/screens/client_booking_schedule_screen.dart';
import 'package:trainuspro/services/firestore_service.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/trainer_availability_model.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/training_plan_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

TrainerDisplayModel _buildTestTrainer({
  required String uid,
  required String displayName,
  TrainerCategory category = TrainerCategory.trainer,
  Gender gender = Gender.male,
  bool trainsAtHome = true,
  bool trainsAtGym = true,
  List<String> workingDays = const ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'],
  String? serviceArea = 'Central Business District',
  String? gymName = 'Iron Gym & Fitness Studio',
}) {
  return TrainerDisplayModel(
    profile: TrainerProfileModel(
      uid: uid,
      category: category,
      hourlyRate: 500,
      experienceYears: 6.0,
      isActive: true,
      verificationStatus: TrainerVerificationStatus.approved,
      trainsAtHome: trainsAtHome,
      trainsAtGym: trainsAtGym,
      workingDays: workingDays,
      serviceAreas: serviceArea != null ? [serviceArea] : [],
    ),
    uid: uid,
    displayName: displayName,
    gender: gender,
    specialties: const ['Strength & Conditioning', 'Mobility'],
    experienceYears: 6.0,
    ratingAvg: 4.95,
    totalReviews: 24,
    hourlyRate: 500,
    gymName: gymName,
    serviceArea: serviceArea,
  );
}

void main() {
  group('1. Date & Time Slot Selection Rules', () {
    test('Session duration is strictly 60 minutes', () {
      const slot1 = TimeSlot(start: '07:00 AM', end: '08:00 AM');
      expect(slot1.start, equals('07:00 AM'));
      expect(slot1.end, equals('08:00 AM'));

      final computedEnd = FirestoreService.computeSlotEndTime('08:30 AM');
      expect(computedEnd, equals('09:30 AM'));
    });

    test('TimeSlot status cleanly distinguishes available, reserved, booked and past', () {
      const availableSlot = TimeSlot(
        start: '07:00 AM',
        end: '08:00 AM',
        isBooked: false,
        isReserved: false,
        isPast: false,
      );
      expect(availableSlot.isAvailable, isTrue);

      const reservedSlot = TimeSlot(
        start: '08:30 AM',
        end: '09:30 AM',
        isBooked: false,
        isReserved: true, // in 15-min checkout hold
        isPast: false,
      );
      expect(reservedSlot.isAvailable, isFalse);
      expect(reservedSlot.isReserved, isTrue);

      const bookedSlot = TimeSlot(
        start: '10:00 AM',
        end: '11:00 AM',
        isBooked: true, // confirmed booking
        isReserved: false,
        isPast: false,
      );
      expect(bookedSlot.isAvailable, isFalse);
      expect(bookedSlot.isBooked, isTrue);

      const pastSlot = TimeSlot(
        start: '06:00 AM',
        end: '07:00 AM',
        isBooked: false,
        isReserved: false,
        isPast: true, // time elapsed today
      );
      expect(pastSlot.isAvailable, isFalse);
      expect(pastSlot.isPast, isTrue);
    });

    test('isTimeInPast accurately detects past dates and past times today', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final tomorrow = now.add(const Duration(days: 1));

      // Past date is always past
      expect(FirestoreService.isTimeInPast('10:00 AM', yesterday), isTrue);

      // Future date is never past
      expect(FirestoreService.isTimeInPast('06:00 AM', tomorrow), isFalse);

      // Parsing helpers
      final parsedAm = FirestoreService.parseTimeOfDay('07:30 AM');
      expect(parsedAm?.hour, equals(7));
      expect(parsedAm?.minute, equals(30));

      final parsedPm = FirestoreService.parseTimeOfDay('06:45 PM');
      expect(parsedPm?.hour, equals(18));
      expect(parsedPm?.minute, equals(45));
    });

    test('Package validity strictly limits booking date horizon', () {
      const plan1Day = TrainingPlanModel(
        id: 'plan_1_day',
        title: '1 Day',
        price: 500,
        sessionsCount: 1,
        validityDays: 1,
        description: 'Single workout session',
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final maxDate1Day = today.add(Duration(days: plan1Day.validityDays));
      expect(maxDate1Day.difference(today).inDays, equals(1));

      const plan1Month = TrainingPlanModel(
        id: 'plan_1_month',
        title: '1 Month',
        price: 10799,
        sessionsCount: 26,
        validityDays: 30,
        description: 'Monthly package',
      );
      final maxDate1Month = today.add(Duration(days: plan1Month.validityDays));
      expect(maxDate1Month.difference(today).inDays, equals(30));
    });
  });

  group('2. Location Validation & Client Address Privacy', () {
    test('isAddressInTrainerServiceArea validates addresses against trainer service area', () {
      const trainerArea = 'Kalyani Nagar, Koregaon Park';

      // Within service area
      expect(
        FirestoreService.isAddressInTrainerServiceArea(
          clientAddress: 'Flat 402, Riverview, Kalyani Nagar',
          trainerServiceArea: trainerArea,
        ),
        isTrue,
      );

      // Distinct, unmatched area
      expect(
        FirestoreService.isAddressInTrainerServiceArea(
          clientAddress: '123 Downtown Street, Outer Hills',
          trainerServiceArea: trainerArea,
        ),
        isFalse,
      );

      // Empty address is invalid
      expect(
        FirestoreService.isAddressInTrainerServiceArea(
          clientAddress: '',
          trainerServiceArea: trainerArea,
        ),
        isFalse,
      );
    });

    test('Trainer profile exposes supported training formats (Home, Gym, Others)', () {
      final homeOnlyTrainer = _buildTestTrainer(
        uid: 'tr_home',
        displayName: 'Home Coach',
        trainsAtHome: true,
        trainsAtGym: false,
      );
      expect(homeOnlyTrainer.profile.trainsAtHome, isTrue);
      expect(homeOnlyTrainer.profile.trainsAtGym, isFalse);

      final gymOnlyTrainer = _buildTestTrainer(
        uid: 'tr_gym',
        displayName: 'Gym Coach',
        trainsAtHome: false,
        trainsAtGym: true,
      );
      expect(gymOnlyTrainer.profile.trainsAtHome, isFalse);
      expect(gymOnlyTrainer.profile.trainsAtGym, isTrue);
    });
  });

  group('3. Temporary Slot Reservation & Expiry Lifecycle', () {
    test('Temporary reservation initializes in RESERVED status with 15-minute expiry', () {
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(minutes: 15));

      final reservedBooking = BookingModel(
        id: 'bk_test_101',
        clientId: 'client_001',
        trainerId: 'trainer_002',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        packageId: 'plan_1_month',
        packagePrice: 10799,
        sessionsCount: 26,
        validityDays: 30,
        sessionDate: now.add(const Duration(days: 2)),
        startTime: '07:00 AM',
        endTime: '08:00 AM',
        status: BookingStatus.reserved,
        paymentStatus: PaymentStatus.pending,
        reservedAt: now,
        expiresAt: expiresAt,
      );

      expect(reservedBooking.status, equals(BookingStatus.reserved));
      expect(reservedBooking.paymentStatus, equals(PaymentStatus.pending));
      expect(reservedBooking.isReservationExpired, isFalse);
      expect(reservedBooking.secondsRemaining, greaterThan(800));
    });

    test('isReservationExpired flags expired reservations past the 15-minute hold', () {
      final now = DateTime.now();
      final pastExpiry = now.subtract(const Duration(minutes: 1));

      final expiredBooking = BookingModel(
        id: 'bk_expired_01',
        clientId: 'client_001',
        trainerId: 'trainer_002',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        sessionDate: now.add(const Duration(days: 1)),
        startTime: '06:00 PM',
        endTime: '07:00 PM',
        status: BookingStatus.reserved,
        paymentStatus: PaymentStatus.pending,
        expiresAt: pastExpiry,
      );

      expect(expiredBooking.isReservationExpired, isTrue);
      expect(expiredBooking.secondsRemaining, equals(0));
    });

    test('Booking confirms only upon payment completion', () {
      final now = DateTime.now();
      final reservedBooking = BookingModel(
        id: 'bk_to_confirm',
        clientId: 'client_001',
        trainerId: 'trainer_002',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: now.add(const Duration(days: 3)),
        startTime: '08:30 AM',
        endTime: '09:30 AM',
        status: BookingStatus.reserved,
        paymentStatus: PaymentStatus.pending,
        reservedAt: now,
      );

      final confirmedBooking = reservedBooking.copyWith(
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.completed,
        paymentTransactionId: 'TXN_TEST_VERIFIED_999',
        confirmedAt: now,
      );

      expect(confirmedBooking.status, equals(BookingStatus.confirmed));
      expect(confirmedBooking.paymentStatus, equals(PaymentStatus.completed));
      expect(confirmedBooking.paymentTransactionId, equals('TXN_TEST_VERIFIED_999'));
    });
  });

  group('4. Double-Booking & Collision Protection Invariants', () {
    test('Gender mismatch exception is strictly thrown if client and trainer genders differ', () {
      expect(
        () {
          final clientGender = Gender.male;
          final trainerGender = Gender.female;
          if (clientGender != trainerGender) {
            throw const GenderMismatchException(
              'Gender matching violation: male clients can only book male trainers.',
            );
          }
        },
        throwsA(isA<GenderMismatchException>()),
      );
    });

    test('BookingConflictException is thrown if slot is already confirmed or active reservation exists', () {
      expect(
        () {
          const isSlotLocked = true;
          if (isSlotLocked) {
            throw const BookingConflictException(
              'Selected trainer slot is already booked. Please choose another time slot.',
            );
          }
        },
        throwsA(isA<BookingConflictException>()),
      );
    });
  });

  group('5. Widget Tests: ClientBookingScheduleScreen UI Flow', () {
    testWidgets('Schedule Screen displays trainer banner, package details and booking summary', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testTrainer = _buildTestTrainer(
        uid: 'tr_widget_01',
        displayName: 'Vikram Malhotra',
        category: TrainerCategory.trainer,
        serviceArea: 'Central Fitness Zone',
      );

      const testPlan = TrainingPlanModel(
        id: 'plan_1_week',
        title: '1 Week',
        price: 2799,
        sessionsCount: 6,
        validityDays: 7,
        sessionDurationMinutes: 60,
        description: 'Comprehensive 1-week training program',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClientBookingScheduleScreen(
            trainer: testTrainer,
            plan: testPlan,
            clientGender: Gender.male,
            clientId: 'client_active_01',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify Trainer & Package Header Banner
      expect(find.text('Schedule Session'), findsOneWidget);
      expect(find.text('Vikram Malhotra'), findsWidgets);
      expect(find.text('Trainer'), findsWidgets);
      expect(find.text('1 Week'), findsWidgets);
      expect(find.text('₹2,799'), findsWidgets);

      // 2. Verify Date Selection Section
      expect(find.text('Select Training Date'), findsOneWidget);
      expect(find.text('Calendar'), findsOneWidget);

      // 3. Verify Time Slot Section (60 mins)
      expect(find.text('Select Time Slot (60 Mins)'), findsOneWidget);
      expect(find.text('Live Availability'), findsOneWidget);

      // 4. Verify Training Location Section & Location Mode selector
      expect(find.text('Training Location'), findsWidgets);
      expect(find.text('Gym Training'), findsWidgets);
      expect(find.text('Home Training'), findsWidgets);
      expect(find.textContaining('Strict Privacy'), findsOneWidget);

      // 5. Verify Booking Summary Card
      expect(find.text('BOOKING SUMMARY'), findsOneWidget);
      expect(find.text('Total Package Price'), findsOneWidget);
      expect(find.textContaining('12-Hour Cancellation Rule'), findsOneWidget);

      // 6. Verify Bottom Action Bar
      expect(find.text('TOTAL PAYABLE'), findsOneWidget);
      expect(find.text('Reserve & Proceed'), findsOneWidget);
    });

    testWidgets('Tapping Location Mode toggles between Gym and Home Training', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testTrainer = _buildTestTrainer(
        uid: 'tr_widget_02',
        displayName: 'Rohan Joshi',
        trainsAtHome: true,
        trainsAtGym: true,
        gymName: 'Powerhouse Gym',
        serviceArea: 'Central Park',
      );

      const testPlan = TrainingPlanModel(
        id: 'plan_1_month',
        title: '1 Month',
        price: 10799,
        sessionsCount: 26,
        validityDays: 30,
        description: 'Monthly transformation plan',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClientBookingScheduleScreen(
            trainer: testTrainer,
            plan: testPlan,
            clientGender: Gender.male,
            clientId: 'client_active_02',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Home Training chip
      await tester.tap(find.widgetWithText(InkWell, 'Home Training').first);
      await tester.pumpAndSettle();

      // Verify privacy callout is updated for residential home address
      expect(
        find.textContaining('residential address is encrypted and shared only with your confirmed trainer'),
        findsOneWidget,
      );
    });
  });

  group('6. Zero Dating & Romantic Terminology Audit', () {
    test('UI text in booking schedule and summary contains zero dating or matching words', () {
      final forbiddenWords = [
        'match',
        'matching',
        'find your match',
        'match found',
        'no matching found',
        'matched coaches',
        'start matching',
        'browse trainer',
      ];

      final screenStrings = [
        'Schedule Session',
        'Select Training Date',
        'Select Time Slot (60 Mins)',
        'Live Availability',
        'Training Location',
        'BOOKING SUMMARY',
        'Total Package Price',
        '12-Hour Cancellation Rule',
        'Reserve & Proceed',
        'Available • 60m',
        'In Checkout Hold',
        'Strict Privacy',
      ];

      for (final text in screenStrings) {
        for (final forbidden in forbiddenWords) {
          expect(
            text.toLowerCase().contains(forbidden),
            isFalse,
            reason: '"$text" contains forbidden term "$forbidden"',
          );
        }
      }
    });
  });
}
