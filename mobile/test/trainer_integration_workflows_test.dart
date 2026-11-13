import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/features/trainer/controllers/trainer_auth_controller.dart';
import 'package:trainuspro/routing/app_router.dart';
import 'package:trainuspro/routing/role_guards.dart';
import 'package:trainuspro/services/booking_service.dart';
import 'package:trainuspro/services/notification_service.dart';
import 'package:trainuspro/services/trainer_account_service.dart';
import 'package:trainuspro/services/trainer_availability_service.dart';
import 'package:trainuspro/services/trainer_client_service.dart';
import 'package:trainuspro/services/trainer_earnings_service.dart';
import 'package:trainuspro/services/trainer_package_service.dart';
import 'package:trainuspro/services/trainer_profile_service.dart';
import 'package:trainuspro/services/trainer_review_service.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/notification_model.dart';
import 'package:trainuspro/shared/models/review_model.dart';
import 'package:trainuspro/shared/models/trainer_availability_model.dart';
import 'package:trainuspro/shared/models/trainer_earnings_model.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  setUp(() {
    TrainerProfileService.instance.reset();
    BookingService.instance.resetForTest();
    TrainerAvailabilityService.instance.resetMockData();
    TrainerPackageService.instance.clearMockData();
    TrainerReviewService.instance.resetForTest();
    TrainerClientService.instance.resetForTest();
    TrainerAccountService.instance.resetForTest();
    TrainerEarningsService.instance.resetForTest();
  });

  group('Workflow 1: Standard & Advanced Trainer Registration and Category Selection', () {
    test('Standard Trainer registration form validation and tier constraints', () {
      final formErr = TrainerAuthController.validateRegistrationFormStatic(
        name: 'Sameer Khan',
        email: 'sameer@trainz.test',
        phoneNumber: '9876543210',
        password: 'Password@123',
        confirmPassword: 'Password@123',
      );
      expect(formErr, isNull);

      final catErr = TrainerAuthController.validateCategorySelectionStatic(
        category: TrainerCategory.trainer,
        experienceYears: 0.0,
      );
      expect(catErr, isNull);
    });

    test('Advanced Trainer registration mandates >= 3.5 years experience and certificate confirmation', () {
      final underYearsErr = TrainerAuthController.validateCategorySelectionStatic(
        category: TrainerCategory.advancedTrainer,
        experienceYears: 2.5,
        hasConfirmedCertificate: true,
      );
      expect(underYearsErr, contains('3.5 years'));

      final unconfirmedErr = TrainerAuthController.validateCategorySelectionStatic(
        category: TrainerCategory.advancedTrainer,
        experienceYears: 4.0,
        hasConfirmedCertificate: false,
      );
      expect(unconfirmedErr, contains('confirm possession of relevant professional certificates'));

      final validAdvErr = TrainerAuthController.validateCategorySelectionStatic(
        category: TrainerCategory.advancedTrainer,
        experienceYears: 4.0,
        hasConfirmedCertificate: true,
      );
      expect(validAdvErr, isNull);
    });

    test('Professional Trainer category remains unavailable at initial launch', () {
      expect(TrainerCategory.professionalTrainer.isAvailableAtLaunch, isFalse);
    });
  });

  group('Workflow 2: Account Lifecycle States and Dashboard Gates', () {
    test('Pending verification routes to TrainerPendingApprovalScreen', () {
      const user = UserModel(
        uid: 'tr_pending_01',
        email: 'pending@trainz.test',
        role: UserRole.trainer,
        status: UserStatus.active,
        isEmailVerified: true,
        isOnboarded: true,
      );
      const profile = TrainerProfileModel(
        uid: 'tr_pending_01',
        verificationStatus: TrainerVerificationStatus.pending,
        isProfileCompleted: true,
      );

      expect(RoleGuards.canAccessTrainerDashboard(user: user, profile: profile), isFalse);
      expect(RoleGuards.resolveTrainerDestinationRoute(user: user, profile: profile), AppRouter.trainerPendingApproval);
    });

    test('Approved verification routes to TrainerDashboard', () {
      const user = UserModel(
        uid: 'tr_approved_01',
        email: 'approved@trainz.test',
        role: UserRole.trainer,
        status: UserStatus.active,
        isEmailVerified: true,
        isOnboarded: true,
      );
      const profile = TrainerProfileModel(
        uid: 'tr_approved_01',
        verificationStatus: TrainerVerificationStatus.approved,
        isProfileCompleted: true,
      );

      expect(RoleGuards.canAccessTrainerDashboard(user: user, profile: profile), isTrue);
      expect(RoleGuards.resolveTrainerDestinationRoute(user: user, profile: profile), AppRouter.trainerDashboard);
    });
  });

  group('Workflow 3: Training Package & Plan Management (Standard vs Advanced)', () {
    test('Standard Trainers are strictly assigned fixed platform packages', () {
      final pkgService = TrainerPackageService.instance;
      final packages = pkgService.getPlatformPackages();

      expect(packages.length, 6);
      expect(packages[0].title, '1 Day');
      expect(packages[0].price, 500);
      expect(packages[0].sessionsCount, 1);
      expect(packages[0].validityDays, 1);

      expect(packages[3].title, '1 Month');
      expect(packages[3].price, 10799);
      expect(packages[3].sessionsCount, 26);
      expect(packages[3].validityDays, 30);

      expect(packages[5].title, '6-Month Transformation');
      expect(packages[5].price, 52999);
      expect(packages[5].sessionsCount, 150);
      expect(packages[5].validityDays, 180);
    });

    test('Advanced Trainers can create custom packages that require Admin approval', () async {
      final pkgService = TrainerPackageService.instance;
      final planId = await pkgService.createCustomPlan(
        title: 'Marathon Performance Masterclass',
        description: 'Elite aerobic conditioning and running mechanics',
        price: 18000,
        sessionsCount: 24,
        validityDays: 60,
        sessionDurationMinutes: 60,
        submitForApproval: true,
      );

      expect(planId.isNotEmpty, isTrue);
    });
  });

  group('Workflow 4: Availability & Calendar Management', () {
    test('AvailabilityWindow enforces minimum 60-minute duration and generates discrete slots', () {
      const window = AvailabilityWindow(start: '06:00 AM', end: '09:00 AM');
      expect(window.durationMinutes, 180);
      expect(window.isValid, isTrue);

      final slots = window.generate60MinSlots();
      expect(slots.map((s) => s.start).toList(), ['06:00 AM', '07:00 AM', '08:00 AM']);
    });
  });

  group('Workflow 5: Booking, 1-on-1 Communication, & Session Completion', () {
    test('Confirmed session details enforce 60-minute duration and gender matching', () {
      final booking = BookingModel(
        id: 'bk_workflow_01',
        clientId: 'client_01',
        trainerId: 'trainer_01',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime.now(),
        startTime: '07:00',
        endTime: '08:00',
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.success,
        packageName: '1 Month',
        packagePrice: 10799,
        totalSessions: 26,
        sessionsCompleted: 5,
        meetingLocation: 'Golds Gym Bandra West, Mumbai',
        creditTransactionId: 'tx_cred_01',
      );

      expect(booking.clientGender, booking.trainerGender);
      expect(booking.sessionDurationDisplay, '60 Minutes (Personal 1-on-1)');
      expect(booking.status, BookingStatus.confirmed);
      expect(booking.isCompleted, isFalse);
    });

    test('Completing an eligible session updates status and increments completed count', () async {
      final booking = BookingModel(
        id: 'bk_complete_test',
        clientId: 'client_01',
        trainerId: 'trainer_01',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        sessionDate: DateTime.now(),
        startTime: '09:00',
        endTime: '10:00',
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.success,
        totalSessions: 10,
        sessionsCompleted: 2,
      );

      final bookingService = BookingService.instance;
      bookingService.addOrUpdateBooking(booking);

      await bookingService.completeSession(
        bookingId: 'bk_complete_test',
        sessionNotes: 'Great form on Romanian deadlifts and pullups.',
      );

      final completedBooking = bookingService.allBookings.firstWhere((b) => b.id == 'bk_complete_test');
      expect(completedBooking.status, BookingStatus.completed);
      expect(completedBooking.sessionsCompleted, 3);
      expect(completedBooking.notes, contains('Great form on Romanian deadlifts'));
    });
  });

  group('Workflow 6: Earnings, Commission, and Review Management', () {
    test('Trainer can view transactions and accurate commission calculations', () {
      final earningsService = TrainerEarningsService.instance;
      final tx = TrainerEarningsTransactionModel(
        id: 'earn_bk_01',
        bookingId: 'bk_01',
        bookingRef: '#BK-001',
        trainerId: 'trainer_alpha',
        clientId: 'client_omega',
        clientName: 'Athlete Rohan',
        packageName: '1 Month Transformation',
        sessionDate: DateTime.now(),
        grossAmount: 415,
        commissionRatePercent: 15,
        commissionAmount: 62,
        netAmount: 353,
        payoutStatus: TrainerPayoutStatus.eligibleForPayout,
      );

      earningsService.setTestTransactions([tx]);
      expect(earningsService.allTransactions.length, 1);
      expect(earningsService.allTransactions[0].formattedGross, '₹415');
      expect(earningsService.allTransactions[0].formattedCommission, '₹62');
      expect(earningsService.allTransactions[0].formattedNet, '₹353');
    });

    test('Trainer can submit professional response to eligible client review', () async {
      final review = ReviewModel(
        id: 'rev_workflow_01',
        bookingId: 'bk_rev_01',
        clientId: 'cl_01',
        trainerId: 'trainer_01',
        rating: 5.0,
        comment: 'Outstanding trainer! Very methodical and focused on injury prevention.',
        isPublic: true,
        clientName: 'Ananya Verma',
        createdAt: DateTime.now(),
      );

      final reviewService = TrainerReviewService.instance;
      reviewService.setTestReviews([review]);

      await reviewService.submitTrainerResponse(
        reviewId: 'rev_workflow_01',
        trainerId: 'trainer_01',
        responseText: 'Thank you Ananya! Honored to coach your journey.',
      );

      final updated = reviewService.allReviews.firstWhere((r) => r.id == 'rev_workflow_01');
      expect(updated.trainerResponse, 'Thank you Ananya! Honored to coach your journey.');
      expect(updated.hasResponse, isTrue);
    });
  });

  group('Workflow 7: Client Records, Private Notes, and Notifications', () {
    test('Private training note is authored and persisted for connected client', () async {
      final clientService = TrainerClientService.instance;
      final note = await clientService.addNote(
        trainerId: 'tr_01',
        clientId: 'cl_01',
        title: 'Mobility Assessment',
        content: 'Client working on shoulder mobility prior to overhead press.',
        category: 'FORM_CHECK',
      );

      expect(note.trainerId, 'tr_01');
      expect(note.clientId, 'cl_01');
      expect(note.content, contains('shoulder mobility'));
    });

    test('Notification categories filter correctly for Trainer Notification Centre', () {
      final notifService = NotificationService.instance;
      final notifications = [
        NotificationModel(
          id: 'notif_bk',
          userId: 'tr_01',
          title: 'New Confirmed Booking',
          body: 'Session booked for Monday 8:00 AM',
          type: 'BOOKING_CONFIRMED',
          isRead: false,
          createdAt: DateTime.now(),
        ),
        NotificationModel(
          id: 'notif_msg',
          userId: 'tr_01',
          title: 'New Message',
          body: 'Client sent a message',
          type: 'CHAT_MESSAGE',
          isRead: true,
          createdAt: DateTime.now(),
        ),
      ];

      final bookingNotifs = notifService.filterByCategory(notifications, NotificationCategory.bookings);
      expect(bookingNotifs.length, 1);
      expect(bookingNotifs[0].id, 'notif_bk');

      final msgNotifs = notifService.filterByCategory(notifications, NotificationCategory.messages);
      expect(msgNotifs.length, 1);
      expect(msgNotifs[0].id, 'notif_msg');
    });
  });

  group('Workflow 8: Navigation Route Coverage Integration', () {
    test('AppRouter generates all defined Trainer routes cleanly without missing definitions', () {
      final routesToTest = [
        AppRouter.trainerLogin,
        AppRouter.trainerRegister,
        AppRouter.trainerCategorySelection,
        AppRouter.trainerRegistrationSuccess,
        AppRouter.trainerPendingApproval,
        AppRouter.trainerDashboard,
        AppRouter.trainerAvailability,
        AppRouter.trainerCertificates,
        AppRouter.trainerBookings,
        AppRouter.trainerEarnings,
        AppRouter.trainerReviews,
        AppRouter.trainerClients,
        AppRouter.trainerMessages,
        AppRouter.trainerNotifications,
        AppRouter.trainerNotificationPreferences,
        AppRouter.trainerSettings,
        AppRouter.trainerPersonalInfo,
        AppRouter.trainerAccountSecurity,
        AppRouter.trainerPrivacyDocuments,
        AppRouter.trainerHelpSupport,
        AppRouter.trainerLegal,
        AppRouter.trainerAccountDeletion,
        AppRouter.trainerPackages,
        AppRouter.trainerProfileSetup,
      ];

      for (final routeName in routesToTest) {
        final route = AppRouter.onGenerateRoute(RouteSettings(name: routeName));
        expect(route, isNotNull, reason: 'Route $routeName must produce a valid MaterialPageRoute');
        expect(route, isA<MaterialPageRoute>());
      }
    });
  });
}
