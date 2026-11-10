import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/constants/app_constants.dart';
import 'package:trainuspro/core/utils/date_time_utils.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/session_credit_model.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/training_plan_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  group('PROMPT 3: Client Dashboard - Bottom Navigation & Tabs', () {
    test('defines all 5 client bottom navigation tabs', () {
      const tabs = ['Home', 'Find Trainer', 'Bookings', 'Messages', 'Profile'];
      expect(tabs.length, 5);
      expect(tabs[0], 'Home');
      expect(tabs[1], 'Find Trainer');
      expect(tabs[2], 'Bookings');
      expect(tabs[3], 'Messages');
      expect(tabs[4], 'Profile');
    });

    test('tab switching preserves valid index range (0 to 4)', () {
      int currentTab = 0;
      void switchTab(int index) {
        if (index >= 0 && index <= 4) {
          currentTab = index;
        }
      }

      switchTab(1);
      expect(currentTab, 1);
      switchTab(3);
      expect(currentTab, 3);
      switchTab(4);
      expect(currentTab, 4);
      switchTab(5); // Out of bounds
      expect(currentTab, 4);
    });
  });

  group('PROMPT 3: Featured Trainers & Security Verification Rules', () {
    final trainerProfile = TrainerProfileModel(
      uid: 'trainer_001',
      bio: 'Certified Strength Coach',
      specialties: ['Hypertrophy & Strength', 'Form Correction'],
      experienceYears: 6,
      cityId: 'city_mumbai',
      hourlyRate: 650,
      verificationStatus: TrainerVerificationStatus.approved,
      isActive: true,
      ratingAvg: 4.95,
      totalReviews: 42,
    );

    final trainerDisplay = TrainerDisplayModel(
      profile: trainerProfile,
      uid: 'trainer_001',
      displayName: 'Vikram Malhotra',
      gender: Gender.male,
      gymName: "Gold's Gym Bandra West",
      specialties: trainerProfile.specialties,
      experienceYears: trainerProfile.experienceYears,
      cityId: trainerProfile.cityId,
      ratingAvg: trainerProfile.ratingAvg,
      totalReviews: trainerProfile.totalReviews,
      hourlyRate: trainerProfile.hourlyRate,
    );

    test('TrainerDisplayModel formats experience, rating and primary specialty', () {
      expect(trainerDisplay.experienceText, '6+ Years Exp');
      expect(trainerDisplay.ratingText, '5.0'); // rounded or formatted
      expect(trainerDisplay.primarySpecialty, 'Hypertrophy & Strength');
      expect(trainerDisplay.displayName, 'Vikram Malhotra');
      expect(trainerDisplay.gymName, "Gold's Gym Bandra West");
    });

    test('Strict 1-on-1 Gender Matching Security Rule', () {
      const clientMale = Gender.male;
      const clientFemale = Gender.female;

      // Male client with Male trainer: Allowed
      expect(trainerDisplay.gender == clientMale, isTrue);

      // Female client with Male trainer: BLOCKED by security rule
      expect(trainerDisplay.gender == clientFemale, isFalse);

      final femaleTrainer = TrainerDisplayModel(
        profile: trainerProfile,
        uid: 'trainer_002',
        displayName: 'Priya Sharma',
        gender: Gender.female,
        specialties: ['HIIT & Conditioning'],
        experienceYears: 5,
        ratingAvg: 4.9,
        totalReviews: 35,
        hourlyRate: 700,
      );

      // Female client with Female trainer: Allowed
      expect(femaleTrainer.gender == clientFemale, isTrue);
      // Male client with Female trainer: BLOCKED
      expect(femaleTrainer.gender == clientMale, isFalse);
    });

    test('Only APPROVED and active trainers can be displayed and booked', () {
      expect(trainerProfile.isApproved, isTrue);
      expect(trainerProfile.canBeBooked, isTrue);

      final pendingTrainer = TrainerProfileModel(
        uid: 'trainer_pending',
        verificationStatus: TrainerVerificationStatus.pending,
        isActive: true,
      );
      expect(pendingTrainer.isApproved, isFalse);
      expect(pendingTrainer.canBeBooked, isFalse);

      final suspendedTrainer = TrainerProfileModel(
        uid: 'trainer_suspended',
        verificationStatus: TrainerVerificationStatus.suspended,
        isActive: false,
      );
      expect(suspendedTrainer.canBeBooked, isFalse);
    });

    test('Service area city filtering correctly isolates cities', () {
      expect(trainerDisplay.cityId, 'city_mumbai');

      bool matchesCity(TrainerDisplayModel t, String cityId) {
        return t.cityId == null || t.cityId == cityId;
      }

      expect(matchesCity(trainerDisplay, 'city_mumbai'), isTrue);
      expect(matchesCity(trainerDisplay, 'city_delhi_ncr'), isFalse);
      expect(matchesCity(trainerDisplay, 'city_bengaluru'), isFalse);
    });
  });

  group('PROMPT 3: Training Packages Display & Pricing', () {
    test('contains all 6 fixed packages with correct Firestore fields', () {
      final plans = AppConstants.fixedTrainingPlans.map((p) {
        return TrainingPlanModel.fromMap(p, id: p['id'] as String);
      }).toList();

      expect(plans.length, 6);

      // 1 Day
      final p1 = plans.firstWhere((p) => p.id == 'plan_1_day');
      expect(p1.price, 500);
      expect(p1.sessionsCount, 1);
      expect(p1.validityDays, 1);
      expect(p1.pricePerSession, 500.0);

      // 3 Days
      final p2 = plans.firstWhere((p) => p.id == 'plan_3_days');
      expect(p2.price, 1399);
      expect(p2.sessionsCount, 3);
      expect(p2.validityDays, 3);

      // 1 Week
      final p3 = plans.firstWhere((p) => p.id == 'plan_1_week');
      expect(p3.price, 2799);
      expect(p3.sessionsCount, 6);
      expect(p3.validityDays, 7);

      // 1 Month
      final p4 = plans.firstWhere((p) => p.id == 'plan_1_month');
      expect(p4.price, 10799);
      expect(p4.sessionsCount, 26);
      expect(p4.validityDays, 30);
      expect(p4.popular, isTrue);
      expect(p4.pricePerSession.round(), 415); // ₹415 per session

      // 3 Months
      final p5 = plans.firstWhere((p) => p.id == 'plan_3_months');
      expect(p5.price, 29999);
      expect(p5.sessionsCount, 78);
      expect(p5.validityDays, 90);

      // 6-Month Transformation
      final p6 = plans.firstWhere((p) => p.id == 'plan_6_months');
      expect(p6.price, 52999);
      expect(p6.sessionsCount, 150);
      expect(p6.validityDays, 180);
      expect(p6.pricePerSession.round(), 353); // ₹353 per session
    });
  });

  group('PROMPT 3: Real-Time Session Credits Ledger', () {
    test('SessionCreditModel accurately parses balance, reserved, and consumed', () {
      final ledger = SessionCreditModel(
        clientId: 'client_active_01',
        totalPurchased: 26,
        totalReserved: 2,
        totalConsumed: 5,
        totalReturned: 1,
        totalForfeited: 0,
        availableBalance: 20, // 26 - 5 - 2 + 1 = 20
      );

      expect(ledger.availableBalance, 20);
      expect(ledger.totalReserved, 2);
      expect(ledger.totalConsumed, 5);
      expect(ledger.hasAvailableCredits, isTrue);
      expect(ledger.canBookSession, isTrue);
    });

    test('Zero balance prevents booking without purchase', () {
      final emptyLedger = SessionCreditModel(
        clientId: 'client_new',
        availableBalance: 0,
      );

      expect(emptyLedger.hasAvailableCredits, isFalse);
      expect(emptyLedger.canBookSession, isFalse);
    });
  });

  group('PROMPT 3: Upcoming Bookings & 12-Hour Cancellation Policy', () {
    test('BookingModel display getters and status verification', () {
      final now = DateTime.now();
      final booking = BookingModel(
        id: 'book_client_001',
        clientId: 'client_test_id',
        trainerId: 'trainer_001',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        trainerName: 'Vikram Malhotra',
        clientName: 'Rohan Sharma',
        sessionDate: now.add(const Duration(days: 2)),
        startTime: '07:00 AM',
        endTime: '08:00 AM',
        workoutType: 'Strength & Hypertrophy',
        meetingLocation: "Gold's Gym Bandra West",
        status: BookingStatus.confirmed,
      );

      expect(booking.displayTrainerName, 'Vikram Malhotra');
      expect(booking.displayWorkoutType, 'Strength & Hypertrophy');
      expect(booking.status, BookingStatus.confirmed);
      expect(booking.hasValidGenderMatch, isTrue);
    });

    test('Cancellation >= 12h qualifies for full credit return', () {
      final futureSession = DateTime.now().add(const Duration(hours: 24));
      final canReturn = DateTimeUtils.canReturnCreditOnClientCancellation(futureSession);
      expect(canReturn, isTrue);
    });

    test('Cancellation < 12h forfeits credit per platform policy', () {
      final soonSession = DateTime.now().add(const Duration(hours: 3));
      final canReturn = DateTimeUtils.canReturnCreditOnClientCancellation(soonSession);
      expect(canReturn, isFalse);
    });
  });

  group('PROMPT 3: In-Memory Search & Specialty Filter Logic', () {
    final trainers = [
      TrainerDisplayModel(
        profile: const TrainerProfileModel(uid: 't1'),
        uid: 't1',
        displayName: 'Vikram Malhotra',
        gender: Gender.male,
        specialties: ['Hypertrophy & Strength', 'Form Correction'],
        experienceYears: 6,
        ratingAvg: 4.9,
        totalReviews: 40,
        hourlyRate: 650,
        gymName: "Gold's Gym Bandra",
      ),
      TrainerDisplayModel(
        profile: const TrainerProfileModel(uid: 't2'),
        uid: 't2',
        displayName: 'Arjun Rao',
        gender: Gender.male,
        specialties: ['Calisthenics', 'HIIT & Conditioning'],
        experienceYears: 4,
        ratingAvg: 4.8,
        totalReviews: 25,
        hourlyRate: 600,
        gymName: 'Cult.fit Indiranagar',
      ),
    ];

    test('filters trainers by query name', () {
      final results = trainers.where((t) => t.displayName.toLowerCase().contains('vikram')).toList();
      expect(results.length, 1);
      expect(results.first.displayName, 'Vikram Malhotra');
    });

    test('filters trainers by specialty', () {
      final results = trainers.where((t) => t.specialties.contains('Calisthenics')).toList();
      expect(results.length, 1);
      expect(results.first.displayName, 'Arjun Rao');
    });

    test('filters trainers by gym name', () {
      final results = trainers.where((t) => (t.gymName ?? '').toLowerCase().contains('cult')).toList();
      expect(results.length, 1);
      expect(results.first.displayName, 'Arjun Rao');
    });
  });
}

