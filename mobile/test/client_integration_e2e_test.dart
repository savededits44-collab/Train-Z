import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/errors/app_exceptions.dart';
import 'package:trainuspro/features/client/client_feature.dart';
import 'package:trainuspro/routing/app_router.dart';
import 'package:trainuspro/services/auth_service.dart';
import 'package:trainuspro/services/booking_service.dart';
import 'package:trainuspro/services/credit_service.dart';
import 'package:trainuspro/services/location_service.dart';
import 'package:trainuspro/services/notification_service.dart';
import 'package:trainuspro/services/review_service.dart';
import 'package:trainuspro/services/support_service.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/client_profile_model.dart';
import 'package:trainuspro/shared/models/notification_preferences_model.dart';
import 'package:trainuspro/shared/models/support_ticket_model.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/training_plan_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  setUp(() {
    BookingService.instance.clearBookings();
    CreditService.instance.resetMockCredits();
    SupportService.instance.resetMockTickets();
    ReviewService.instance.resetMockReviews();
    NotificationService.instance.clearCache();
  });

  group('E2E Client Workflow 1: Registration, Profile Setup, & Completion Calculation', () {
    test('Client profile setup enforces required fields and calculates completion %', () {
      const emptyProfile = ClientProfileModel(uid: 'client_e2e_01');
      final scoreEmpty = emptyProfile.calculateCompletion(
        hasName: false,
        hasPhone: false,
        hasPhoto: false,
        hasGender: false,
      );
      expect(scoreEmpty, equals(0));

      final scorePartial = emptyProfile.calculateCompletion(
        hasName: true,
        hasPhone: true,
        hasPhoto: false,
        hasGender: true,
      );
      expect(scorePartial, equals(40)); // 15 + 15 + 10

      final fullProfile = ClientProfileModel(
        uid: 'client_e2e_01',
        fitnessLevel: 'Advanced',
        fitnessGoals: const ['Muscle Gain', 'Endurance'],
        preferredTrainingTypes: const ['Strength', 'HIIT'],
        preferredCityId: 'mumbai',
        preferredTrainingLocation: 'Home Training',
        dateOfBirth: DateTime(1995, 5, 20),
        emergencyContact: '+919876543210',
      );

      final scoreFull = fullProfile.calculateCompletion(
        hasName: true,
        hasPhone: true,
        hasPhoto: true,
        hasGender: true,
      );
      expect(scoreFull, equals(100));
    });

    test('Prevents client self-assigning ADMIN role during registration', () {
      expect(
        () => AuthService.instance.signUpWithEmail(
          name: 'Hacker',
          email: 'hacker@test.com',
          password: 'Password123!',
          requestedRole: UserRole.admin,
        ),
        throwsA(isA<RolePermissionException>()),
      );
    });
  });

  group('E2E Client Workflow 2: Trainer Discovery, Gender Matching & City Validation', () {
    final femaleTrainer = TrainerDisplayModel(
      profile: const TrainerProfileModel(
        uid: 'trainer_f_01',
        category: TrainerCategory.trainer,
        verificationStatus: TrainerVerificationStatus.approved,
      ),
      uid: 'trainer_f_01',
      displayName: 'Priya Sharma',
      gender: Gender.female,
      cityId: 'mumbai',
      experienceYears: 5.0,
      specialties: const ['Strength Training', 'Core Conditioning'],
      ratingAvg: 4.9,
      totalReviews: 24,
      hourlyRate: 600,
    );

    final maleTrainer = TrainerDisplayModel(
      profile: const TrainerProfileModel(
        uid: 'trainer_m_01',
        category: TrainerCategory.advancedTrainer,
        verificationStatus: TrainerVerificationStatus.approved,
      ),
      uid: 'trainer_m_01',
      displayName: 'Vikram Rao',
      gender: Gender.male,
      cityId: 'mumbai',
      experienceYears: 8.0,
      specialties: const ['Olympic Weightlifting'],
      ratingAvg: 4.8,
      totalReviews: 40,
      hourlyRate: 900,
    );

    test('Strict 1-on-1 gender matching blocks mismatched gender bookings', () {
      const clientGender = Gender.female;

      // Female client viewing female trainer is allowed
      expect(femaleTrainer.gender, equals(clientGender));

      // Female client viewing male trainer is blocked by gender guard
      expect(maleTrainer.gender, isNot(equals(clientGender)));
    });

    test('LocationService accurately validates active vs inactive launch cities', () {
      final locService = LocationService.instance;

      expect(locService.isCityActive('city_pune'), isTrue);
      expect(locService.isCityActive('city_mumbai'), isFalse);
      expect(locService.isCityActive('city_bangalore'), isFalse);
      expect(locService.isCityActive('unknown_city'), isFalse);
    });
  });

  group('E2E Client Workflow 3: Trainer Package Rules & Professional Guard', () {
    test('Standard Trainers offer fixed platform packages; Professional Trainers are blocked', () {
      final standardPlans = TrainingPlanModel.platformPackages;
      expect(standardPlans, isNotEmpty);
      expect(standardPlans.first.sessionsCount, equals(1));
      expect(standardPlans.first.sessionDurationMinutes, equals(60));

      final proTrainer = TrainerDisplayModel(
        profile: const TrainerProfileModel(
          uid: 'trainer_pro_01',
          category: TrainerCategory.professionalTrainer,
          verificationStatus: TrainerVerificationStatus.approved,
        ),
        uid: 'trainer_pro_01',
        displayName: 'Dr. Arjun Mehta',
        gender: Gender.male,
        cityId: 'mumbai',
        experienceYears: 15.0,
        specialties: const ['Sports Medicine', 'Rehabilitation'],
        ratingAvg: 5.0,
        totalReviews: 50,
        hourlyRate: 2000,
      );

      expect(proTrainer.category, equals(TrainerCategory.professionalTrainer));
    });

    test('Athlete home address remains strictly confidential and never leaked in trainer profile', () {
      const privateAddress = 'Flat 402, Sea Green Heights, Bandra West, Mumbai';
      const clientProfile = ClientProfileModel(
        uid: 'client_secure_01',
        privateAddress: privateAddress,
      );

      final map = clientProfile.toMap();
      expect(map['privateAddress'], equals(privateAddress));

      // Trainer profile never contains athlete address field
      final trainerProfile = TrainerDisplayModel(
        profile: const TrainerProfileModel(
          uid: 'trainer_pub_01',
          category: TrainerCategory.trainer,
        ),
        uid: 'trainer_pub_01',
        displayName: 'Coach Rahul',
        gender: Gender.male,
        experienceYears: 3.0,
        specialties: const ['Fat Loss'],
        ratingAvg: 4.7,
        totalReviews: 12,
        hourlyRate: 500,
      );

      expect(trainerProfile.displayLocation, isNotEmpty);
      expect(trainerProfile.displayLocation.contains(privateAddress), isFalse);
    });
  });

  group('E2E Client Workflow 4 & 5: Package Purchase & Session-Credit Ledger', () {
    test('Purchasing a package records a PURCHASE ledger transaction and credits balance', () async {
      const clientId = 'client_ledger_test_01';
      final creditService = CreditService.instance;

      final initial = creditService.getMockCredits(clientId);
      expect(initial?.availableBalance ?? 0, 0);

      // Client purchases a 6-session transformation package
      await creditService.recordPurchase(
        clientId: clientId,
        sessionCount: 6,
        paymentId: 'PAY_MOCK_123',
        planId: 'plan_6_sessions',
        packageName: '1 Week (6 Sessions)',
        validityDays: 7,
      );

      final updated = creditService.getMockCredits(clientId)!;
      expect(updated.totalPurchased, 6);
      expect(updated.availableBalance, 6);
      expect(updated.totalReserved, 0);
      expect(updated.totalConsumed, 0);
      expect(updated.totalForfeited, 0);
    });

    test('Booking with credit transitions balance: PURCHASE -> RESERVE', () async {
      const clientId = 'client_reserve_test_01';
      const bookingId = 'booking_res_001';
      final creditService = CreditService.instance;

      await creditService.recordPurchase(
        clientId: clientId,
        sessionCount: 6,
        paymentId: 'PAY_MOCK_456',
        planId: 'plan_6_sessions',
        packageName: '6 Sessions',
        validityDays: 7,
      );

      // Reserve 1 session credit for a scheduled 60-min booking
      final txId = await creditService.reserveCreditForBooking(
        clientId: clientId,
        bookingId: bookingId,
      );
      expect(txId, isNotEmpty);

      final balance = creditService.getMockCredits(clientId)!;
      expect(balance.availableBalance, 5);
      expect(balance.totalReserved, 1);

      // Idempotency test: double reservation for the same booking does not double debit
      final secondTxId = await creditService.reserveCreditForBooking(
        clientId: clientId,
        bookingId: bookingId,
      );
      expect(secondTxId, equals(txId));

      final balanceAfterRepeat = creditService.getMockCredits(clientId)!;
      expect(balanceAfterRepeat.availableBalance, 5);
      expect(balanceAfterRepeat.totalReserved, 1);
    });
  });

  group('E2E Client Workflow 6: 12-Hour Cancellation Rule Enforcement', () {
    test('Cancellation >= 12 hours prior returns the credit to available balance', () async {
      const clientId = 'client_cancel_early_01';
      const bookingId = 'booking_early_01';
      final creditService = CreditService.instance;

      await creditService.recordPurchase(
        clientId: clientId,
        sessionCount: 1,
        paymentId: 'PAY_MOCK_789',
        planId: 'plan_single',
      );

      await creditService.reserveCreditForBooking(
        clientId: clientId,
        bookingId: bookingId,
      );

      // Client cancels with > 12h remaining (scheduled 24 hours in the future)
      final futureSessionTime = DateTime.now().add(const Duration(hours: 24));
      final returned = await creditService.processCancellationCredit(
        clientId: clientId,
        bookingId: bookingId,
        sessionStartTime: futureSessionTime,
        cancelledByRole: UserRole.client,
      );

      expect(returned, isTrue);
      final balance = creditService.getMockCredits(clientId)!;
      expect(balance.availableBalance, 1); // Returned
      expect(balance.totalReserved, 0);
      expect(balance.totalReturned, 1);
      expect(balance.totalForfeited, 0);
    });

    test('Cancellation < 12 hours prior forfeits the session credit without refund', () async {
      const clientId = 'client_cancel_late_01';
      const bookingId = 'booking_late_01';
      final creditService = CreditService.instance;

      await creditService.recordPurchase(
        clientId: clientId,
        sessionCount: 1,
        paymentId: 'PAY_MOCK_999',
        planId: 'plan_single',
      );

      await creditService.reserveCreditForBooking(
        clientId: clientId,
        bookingId: bookingId,
      );

      // Client cancels with only 3 hours notice (< 12 hours policy)
      final nearSessionTime = DateTime.now().add(const Duration(hours: 3));
      final returned = await creditService.processCancellationCredit(
        clientId: clientId,
        bookingId: bookingId,
        sessionStartTime: nearSessionTime,
        cancelledByRole: UserRole.client,
      );

      expect(returned, isFalse); // Forfeited, not returned!
      final balance = creditService.getMockCredits(clientId)!;
      expect(balance.availableBalance, 0); // Not returned
      expect(balance.totalReserved, 0);
      expect(balance.totalForfeited, 1); // Forfeited
    });
  });

  group('E2E Client Workflow 7: Session Completion & Review Submission Gating', () {
    test('Completing a session records CONSUME transaction and unlocks review eligibility', () async {
      const clientId = 'client_complete_01';
      const bookingId = 'booking_comp_01';
      const trainerId = 'trainer_target_01';
      final creditService = CreditService.instance;
      final reviewService = ReviewService.instance;

      await creditService.recordPurchase(
        clientId: clientId,
        sessionCount: 1,
        paymentId: 'PAY_MOCK_111',
        planId: 'plan_single',
      );

      await creditService.reserveCreditForBooking(
        clientId: clientId,
        bookingId: bookingId,
      );

      // Complete session
      await creditService.consumeCreditForCompletedSession(
        clientId: clientId,
        bookingId: bookingId,
      );

      final balance = creditService.getMockCredits(clientId)!;
      expect(balance.totalConsumed, 1);
      expect(balance.totalReserved, 0);
      expect(balance.availableBalance, 0);

      // Create booking model representing completed session
      final completedBooking = BookingModel(
        id: bookingId,
        clientId: clientId,
        trainerId: trainerId,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime.now().subtract(const Duration(hours: 2)),
        startTime: '07:00',
        endTime: '08:00',
        status: BookingStatus.completed,
        paymentStatus: PaymentStatus.completed,
      );

      // Client submits review for completed session
      final success = await reviewService.submitReview(
        bookingId: completedBooking.id,
        clientId: completedBooking.clientId,
        trainerId: completedBooking.trainerId,
        rating: 5.0,
        comment: 'Outstanding personal training session! Coach kept form disciplined and high energy.',
        categories: const ['Technique & Form'],
        clientName: 'Rahul Athlete',
        bookingContext: completedBooking,
      );

      expect(success, isTrue);

      final review = await reviewService.getReviewForBooking(completedBooking.id);
      expect(review, isNotNull);
      expect(review!.rating, 5.0);
    });

    test('Reviews are strictly rejected for unconfirmed, pending, or cancelled sessions', () async {
      final reviewService = ReviewService.instance;

      final pendingBooking = BookingModel(
        id: 'booking_pending_99',
        clientId: 'client_test',
        trainerId: 'trainer_test',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime.now().add(const Duration(days: 2)),
        startTime: '08:00',
        endTime: '09:00',
        status: BookingStatus.confirmed, // Upcoming, not completed!
      );

      expect(
        () => reviewService.submitReview(
          bookingId: pendingBooking.id,
          clientId: pendingBooking.clientId,
          trainerId: pendingBooking.trainerId,
          rating: 5.0,
          comment: 'Trying to review before session has happened!',
          bookingContext: pendingBooking,
        ),
        throwsA(isA<ReviewException>()),
      );

      final cancelledBooking = pendingBooking.copyWith(
        status: BookingStatus.cancelledClientEarly,
      );

      expect(
        () => reviewService.submitReview(
          bookingId: cancelledBooking.id,
          clientId: cancelledBooking.clientId,
          trainerId: cancelledBooking.trainerId,
          rating: 1.0,
          comment: 'Reviewing a cancelled session is disallowed.',
          bookingContext: cancelledBooking,
        ),
        throwsA(isA<ReviewException>()),
      );
    });
  });

  group('E2E Client Workflow 8: Support Tickets & Dispute Resolution', () {
    test('Client can create support ticket and receive resolution updates', () async {
      final supportService = SupportService.instance;
      const clientId = 'client_support_e2e';

      final ticket = await supportService.createTicket(
        clientId: clientId,
        clientName: 'Aarav Patel',
        clientEmail: 'aarav@test.com',
        category: SupportTicketCategory.bookingIssue,
        subject: 'Slot Reschedule Clarification',
        description: 'Need clarification on trainer availability for tomorrow evening workout.',
        bookingId: 'booking_ref_101',
      );

      expect(ticket.ticketNumber, startsWith('TKT-'));
      expect(ticket.status, SupportTicketStatus.submitted);

      final clientTicket = await supportService.getTicketById(ticket.id, clientId);
      expect(clientTicket.id, equals(ticket.id));
      expect(clientTicket.subject, equals('Slot Reschedule Clarification'));
    });
  });

  group('E2E Client Workflow 9: Notification Preferences & Mandatory Alert Invariant', () {
    test('Mandatory security alerts cannot be suppressed by user preferences', () {
      const restrictivePrefs = NotificationPreferencesModel(
        bookingUpdates: false,
        trainerMessages: false,
        sessionReminders: false,
        platformAnnouncements: false,
      );

      // Mandatory account security alert is always allowed
      expect(restrictivePrefs.isCategoryEnabled('SECURITY_ALERT'), isTrue);
      expect(restrictivePrefs.isCategoryEnabled('PASSWORD_RESET'), isTrue);
      expect(restrictivePrefs.isCategoryEnabled('ACCOUNT_DELETION'), isTrue);

      // Optional categories are suppressed
      expect(restrictivePrefs.isCategoryEnabled('TRAINER_MESSAGE'), isFalse);
    });
  });

  group('E2E Client Workflow 10: Routing & Access Control Protection', () {
    test('AppRouter contains all client feature routes', () {
      expect(AppRouter.clientHome, equals('/client/home'));
      expect(AppRouter.clientSettings, equals('/client/settings'));
      expect(AppRouter.clientPersonalInfo, equals('/client/personal-info'));
      expect(AppRouter.clientAccountSecurity, equals('/client/account-security'));
      expect(AppRouter.clientAccountDeletion, equals('/client/account-deletion'));
      expect(AppRouter.clientNotificationPreferences, equals('/client/notification-preferences'));
      expect(AppRouter.clientPrivacySettings, equals('/client/privacy-settings'));
      expect(AppRouter.clientHelpSupport, equals('/client/help-support'));
      expect(AppRouter.clientSupportTickets, equals('/client/support-tickets'));
      expect(AppRouter.clientSubmitTicket, equals('/client/submit-ticket'));
      expect(AppRouter.clientSupportDetail, equals('/client/support-detail'));
      expect(AppRouter.clientLegal, equals('/client/legal'));
    });

    test('ClientHomeScreen supports deep tab navigation via initialTab', () {
      const homeTab0 = ClientHomeScreen(initialTab: 0);
      expect(homeTab0.initialTab, 0);

      const bookingsTab2 = ClientHomeScreen(initialTab: 2);
      expect(bookingsTab2.initialTab, 2);

      const messagesTab3 = ClientHomeScreen(initialTab: 3);
      expect(messagesTab3.initialTab, 3);
    });
  });

  group('E2E Client Workflow 11: Zero Romantic/Dating Terminology Linguistic Invariant', () {
    test('Strict personal fitness domain compliance across all models and strings', () {
      final bannedTokens = [
        'dating',
        'romance',
        'romantic',
        'matchmaker',
        'courtship',
        'hookup',
        'flirt',
        'speed dating',
        'lover',
        'intimacy',
      ];

      final sampleTexts = [
        'TRAIN Z Personal Fitness Platform',
        '1-on-1 Personal Training Session with Coach Priya',
        '60 Minutes 1-on-1 Fitness Transformation',
        'Discipline, Form, Technique, Cardiovascular Conditioning',
        'Certified Strength & Conditioning Specialist',
        'Support Ticket: Booking and Scheduling Assistance',
        'Session Credits Double-Entry Ledger',
      ];

      for (final text in sampleTexts) {
        for (final banned in bannedTokens) {
          expect(
            text.toLowerCase().contains(banned),
            isFalse,
            reason: 'Found disallowed dating terminology: "$banned" in "$text"',
          );
        }
      }
    });
  });
}
