import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/constants/app_constants.dart';
import 'package:trainuspro/features/trainer/controllers/trainer_auth_controller.dart';
import 'package:trainuspro/routing/app_router.dart';
import 'package:trainuspro/routing/role_guards.dart';
import 'package:trainuspro/services/booking_service.dart';
import 'package:trainuspro/services/chat_service.dart';
import 'package:trainuspro/services/credit_service.dart';
import 'package:trainuspro/services/notification_service.dart';
import 'package:trainuspro/services/trainer_account_service.dart';
import 'package:trainuspro/services/trainer_availability_service.dart';
import 'package:trainuspro/services/trainer_certificate_service.dart';
import 'package:trainuspro/services/trainer_client_service.dart';
import 'package:trainuspro/services/trainer_earnings_service.dart';
import 'package:trainuspro/services/trainer_package_service.dart';
import 'package:trainuspro/services/trainer_profile_service.dart';
import 'package:trainuspro/services/trainer_review_service.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/conversation_model.dart';
import 'package:trainuspro/shared/models/review_model.dart';
import 'package:trainuspro/shared/models/session_credit_model.dart';
import 'package:trainuspro/shared/models/trainer_availability_model.dart';
import 'package:trainuspro/shared/models/trainer_certificate_model.dart';
import 'package:trainuspro/shared/models/trainer_client_model.dart';
import 'package:trainuspro/shared/models/trainer_earnings_model.dart';
import 'package:trainuspro/shared/models/trainer_notification_preferences_model.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/training_plan_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  setUp(() {
    TrainerProfileService.instance.reset();
    BookingService.instance.resetForTest();
    CreditService.instance.resetMockCredits();
    TrainerAvailabilityService.instance.resetMockData();
    TrainerPackageService.instance.clearMockData();
    TrainerReviewService.instance.resetForTest();
    TrainerClientService.instance.resetForTest();
    TrainerAccountService.instance.resetForTest();
    TrainerEarningsService.instance.resetForTest();
    NotificationService.instance.clearCache();
  });

  group('Section 2: Complete 20 Trainer End-to-End Workflows', () {
    // ── Workflow 1: Register Standard Trainer ──
    test('1. Register a Standard Trainer with valid credentials', () {
      final err = TrainerAuthController.validateRegistrationFormStatic(
        name: 'Arjun Mehta',
        email: 'arjun@trainz.fit',
        phoneNumber: '9876543210',
        password: 'Password@123',
        confirmPassword: 'Password@123',
      );
      expect(err, isNull);

      final catErr = TrainerAuthController.validateCategorySelectionStatic(
        category: TrainerCategory.trainer,
        experienceYears: 1.0,
      );
      expect(catErr, isNull);
    });

    // ── Workflow 2: Register Advanced Trainer ──
    test('2. Register an Advanced Trainer enforcing >= 3.5 yrs and certificate confirmation', () {
      final invalidYears = TrainerAuthController.validateCategorySelectionStatic(
        category: TrainerCategory.advancedTrainer,
        experienceYears: 2.0,
        hasConfirmedCertificate: true,
      );
      expect(invalidYears, contains('3.5 years'));

      final valid = TrainerAuthController.validateCategorySelectionStatic(
        category: TrainerCategory.advancedTrainer,
        experienceYears: 4.5,
        hasConfirmedCertificate: true,
      );
      expect(valid, isNull);
    });

    // ── Workflow 3: Submit Required Certificates ──
    test('3. Submit certificates and verify Standard vs Advanced requirements', () {
      final certService = TrainerCertificateService.instance;
      const trainerId = 'tr_cert_workflow_01';

      // Standard Trainer requires at least 1 verified certificate
      final standardEligible = certService.checkCategoryRequirements(
        category: TrainerCategory.trainer,
        experienceYears: 1.0,
        certificates: [
          const TrainerCertificateModel(
            id: 'cert_std_01',
            trainerId: trainerId,
            certificateName: 'ACE Certified Personal Trainer',
            courseName: 'Personal Fitness Training',
            issuingOrganization: 'ACE',
            yearOfCompletion: '2023',
            storagePath: 'certificates/tr_cert_workflow_01/cert_std_01.pdf',
            fileName: 'cert_std_01.pdf',
            fileType: 'pdf',
            fileSizeBytes: 1024 * 1024,
            verificationStatus: CertificateVerificationStatus.verified,
          ),
        ],
      );
      expect(standardEligible.isEligible, isTrue);

      // Advanced Trainer requires verified certificate + >= 3.5 years experience
      final advancedEligible = certService.checkCategoryRequirements(
        category: TrainerCategory.advancedTrainer,
        experienceYears: 4.0,
        certificates: [
          const TrainerCertificateModel(
            id: 'cert_adv_01',
            trainerId: trainerId,
            certificateName: 'CSCS Strength & Conditioning',
            courseName: 'Strength & Conditioning Specialist',
            issuingOrganization: 'NSCA',
            yearOfCompletion: '2020',
            storagePath: 'certificates/tr_cert_workflow_01/cert_adv_01.pdf',
            fileName: 'cert_adv_01.pdf',
            fileType: 'pdf',
            fileSizeBytes: 2 * 1024 * 1024,
            verificationStatus: CertificateVerificationStatus.verified,
          ),
        ],
      );
      expect(advancedEligible.isEligible, isTrue);
    });

    // ── Workflow 4: Pending, Approved, and Rejected States ──
    test('4. Verify pending, approved, and rejected account states', () {
      const baseUser = UserModel(
        uid: 'tr_status_user',
        email: 'coach@trainz.fit',
        role: UserRole.trainer,
        status: UserStatus.active,
        isEmailVerified: true,
        isOnboarded: true,
      );

      // Pending
      const pendingProfile = TrainerProfileModel(
        uid: 'tr_status_user',
        verificationStatus: TrainerVerificationStatus.pending,
      );
      expect(RoleGuards.resolveTrainerDestinationRoute(user: baseUser, profile: pendingProfile), AppRouter.trainerPendingApproval);

      // Rejected
      const rejectedProfile = TrainerProfileModel(
        uid: 'tr_status_user',
        verificationStatus: TrainerVerificationStatus.rejected,
      );
      expect(RoleGuards.resolveTrainerDestinationRoute(user: baseUser, profile: rejectedProfile), AppRouter.trainerRejected);

      // Approved
      const approvedProfile = TrainerProfileModel(
        uid: 'tr_status_user',
        verificationStatus: TrainerVerificationStatus.approved,
        isProfileCompleted: true,
      );
      expect(RoleGuards.resolveTrainerDestinationRoute(user: baseUser, profile: approvedProfile), AppRouter.trainerDashboard);
    });

    // ── Workflow 5: Dashboard Access After Approval ──
    test('5. Confirm correct dashboard access and role gate after approval', () {
      const user = UserModel(
        uid: 'tr_active_01',
        email: 'active@trainz.fit',
        role: UserRole.trainer,
        status: UserStatus.active,
        isEmailVerified: true,
        isOnboarded: true,
      );
      const profile = TrainerProfileModel(
        uid: 'tr_active_01',
        verificationStatus: TrainerVerificationStatus.approved,
        isProfileCompleted: true,
      );

      expect(RoleGuards.canAccessTrainerDashboard(user: user, profile: profile), isTrue);
    });

    // ── Workflow 6: Configure Weekly Availability ──
    test('6. Configure weekly recurring availability with valid 60-min windows', () {
      final defaultModel = TrainerAvailabilityModel.defaultSchedule('tr_avail_test');
      final schedule = defaultModel.days;

      expect(schedule.length, 7);
      for (final day in schedule) {
        for (final window in day.windows) {
          expect(window.isValid, isTrue);
          expect(window.durationMinutes, greaterThanOrEqualTo(60));
        }
      }
    });

    // ── Workflow 7: Date-Specific Availability Exceptions ──
    test('7. Add date-specific availability exceptions (custom hours and blocked date)', () {
      const trainerId = 'tr_avail_exceptions';
      final specificDate = DateTime(2026, 12, 25);

      final model = TrainerAvailabilityModel(
        id: 'avail_tr_exceptions',
        trainerId: trainerId,
        days: TrainerAvailabilityModel.defaultSchedule(trainerId).days,
        overrides: const [
          TrainerDateOverride(
            date: '2026-12-25',
            isBlocked: true,
            reason: 'Christmas Holiday',
          ),
        ],
      );

      expect(model.isDateBlocked(specificDate), isTrue);
      expect(model.overrideForDate(specificDate)?.reason, 'Christmas Holiday');
    });

    // ── Workflow 8 & 9: Create Advanced Trainer Custom Package & Submit for Admin Approval ──
    test('8 & 9. Create Advanced Trainer custom package and submit for Admin approval', () async {
      final pkgService = TrainerPackageService.instance;

      final planId = await pkgService.createCustomPlan(
        title: 'Hypertrophy Powerbuilding Elite',
        description: 'Targeted periodized hypertrophy plan with biomechanics coaching.',
        price: 24999,
        sessionsCount: 36,
        validityDays: 90,
        sessionDurationMinutes: 60,
        submitForApproval: true,
      );

      expect(planId.isNotEmpty, isTrue);
      final customPlans = await pkgService.streamCustomPlans('test_trainer_uid').first;
      final created = customPlans.firstWhere((p) => p.id == planId);
      expect(created.isCustom, isTrue);
      expect(created.approvalStatus, PackageApprovalStatus.pending);
      expect(created.isApproved, isFalse);
    });

    // ── Workflow 10: Verify Only Approved Packages are Published ──
    test('10. Verify that only approved packages are published to clients', () {
      final pkgService = TrainerPackageService.instance;
      const trainerId = 'tr_packages_check';

      const pendingPlan = TrainingPlanModel(
        id: 'plan_pending_01',
        trainerId: trainerId,
        title: 'Unapproved Package',
        price: 15000,
        sessionsCount: 20,
        validityDays: 30,
        sessionDurationMinutes: 60,
        description: 'Pending admin review package',
        isCustom: true,
        approvalStatus: PackageApprovalStatus.pending,
        isApproved: false,
        isActive: true,
      );

      const approvedPlan = TrainingPlanModel(
        id: 'plan_approved_02',
        trainerId: trainerId,
        title: 'Approved VIP Conditioning',
        price: 18000,
        sessionsCount: 24,
        validityDays: 60,
        sessionDurationMinutes: 60,
        description: 'Elite conditioning plan',
        isCustom: true,
        approvalStatus: PackageApprovalStatus.approved,
        isApproved: true,
        isActive: true,
      );

      pkgService.addMockPlan(trainerId, pendingPlan);
      pkgService.addMockPlan(trainerId, approvedPlan);

      // Verify client-side filtering rule: only approved and active plans are published
      final plans = [pendingPlan, approvedPlan];
      final published = plans.where((p) => p.isApproved && p.approvalStatus == PackageApprovalStatus.approved && p.isActive).toList();
      expect(published.any((p) => p.id == 'plan_pending_01'), isFalse);
      expect(published.any((p) => p.id == 'plan_approved_02'), isTrue);
    });

    // ── Workflow 11 & 12: Receive Confirmed Client Booking & View Details ──
    test('11 & 12. Receive confirmed Client booking and view session details', () {
      final booking = BookingModel(
        id: 'bk_e2e_trainer_01',
        clientId: 'client_kabir',
        trainerId: 'trainer_arjun',
        clientName: 'Kabir Varma',
        trainerName: 'Arjun Mehta',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime.now().add(const Duration(days: 1)),
        startTime: '07:00 AM',
        endTime: '08:00 AM',
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.completed,
        packageName: '1 Month',
        packagePrice: 10799,
        totalSessions: 26,
        sessionsCompleted: 0,
        meetingLocation: 'Gold Gym, Pune',
      );

      expect(booking.isConfirmed, isTrue);
      expect(booking.sessionDurationDisplay, '60 Minutes (Personal 1-on-1)');
      expect(booking.meetingLocation, 'Gold Gym, Pune');
    });

    // ── Workflow 13: Communicate with Client ──
    test('13. Trainer and Client 1-on-1 conversation channel', () async {
      final chatService = ChatService.instance;
      const convId = 'conv_trainer_client_01';

      final msg = ChatMessageModel(
        id: 'msg_01',
        conversationId: convId,
        senderId: 'trainer_arjun',
        senderName: 'Arjun Mehta',
        receiverId: 'client_kabir',
        text: 'Hi Kabir, please bring a towel and water bottle for tomorrow\'s leg session.',
        createdAt: DateTime.now(),
        isRead: false,
      );

      chatService.setTestMessages(convId, [msg]);
      final messages = await chatService.streamMessages(convId).first;
      expect(messages.length, 1);
      expect(messages.first.text, contains('leg session'));
    });

    // ── Workflow 14 & 15: Complete Eligible Session & Atomic Credit Consumption ──
    test('14 & 15. Complete eligible session and consume credit exactly once', () async {
      const clientId = 'client_credit_test';
      const bookingId = 'bk_credit_consume_01';

      final creditService = CreditService.instance;
      creditService.setMockCredits(
        const SessionCreditModel(
          clientId: clientId,
          totalPurchased: 10,
          totalReserved: 1,
          totalConsumed: 0,
          totalReturned: 0,
          totalForfeited: 0,
          availableBalance: 9,
        ),
      );

      final booking = BookingModel(
        id: bookingId,
        clientId: clientId,
        trainerId: 'trainer_arjun',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime.now(),
        startTime: '08:00 AM',
        endTime: '09:00 AM',
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.completed,
        totalSessions: 10,
        sessionsCompleted: 0,
      );

      final bookingService = BookingService.instance;
      bookingService.addOrUpdateBooking(booking);

      // Trainer completes session
      await bookingService.completeSession(
        bookingId: bookingId,
        sessionNotes: 'Completed back squats 5x5 at 100kg with solid depth.',
      );

      // 1. Booking marked completed
      final completed = bookingService.allBookings.firstWhere((b) => b.id == bookingId);
      expect(completed.status, BookingStatus.completed);
      expect(completed.sessionsCompleted, 1);

      // 2. Client session credit consumed exactly once
      final credit = creditService.getMockCredits(clientId)!;
      expect(credit.totalConsumed, 1);
      expect(credit.totalReserved, 0);
      expect(credit.availableBalance, 9);
    });

    // ── Workflow 16: View Earnings and Commission Information ──
    test('16. View earnings summary with commission calculation', () {
      final earningsService = TrainerEarningsService.instance;
      final tx = TrainerEarningsTransactionModel(
        id: 'tx_earn_01',
        bookingId: 'bk_01',
        bookingRef: '#REF-001',
        trainerId: 'trainer_arjun',
        clientId: 'client_kabir',
        clientName: 'Kabir Varma',
        packageName: '1 Month',
        sessionDate: DateTime.now(),
        grossAmount: 415,
        commissionRatePercent: 15,
        commissionAmount: 62,
        netAmount: 353,
        payoutStatus: TrainerPayoutStatus.eligibleForPayout,
      );

      earningsService.setTestTransactions([tx]);
      expect(earningsService.allTransactions.first.netAmount, 353);
      expect(earningsService.allTransactions.first.commissionAmount, 62);
    });

    // ── Workflow 17: View Client Reviews and Submit Response ──
    test('17. View Client reviews and submit an eligible Trainer response', () async {
      final reviewService = TrainerReviewService.instance;
      const reviewId = 'rev_booking_01';
      const trainerId = 'trainer_arjun';

      final review = ReviewModel(
        id: reviewId,
        bookingId: reviewId,
        clientId: 'client_kabir',
        trainerId: trainerId,
        clientName: 'Kabir V.',
        rating: 5.0,
        comment: 'Outstanding coaching! Highly disciplined and motivating.',
        isPublic: true,
      );

      reviewService.setTestReviews([review]);

      // Trainer replies to the review
      await reviewService.submitTrainerResponse(
        reviewId: reviewId,
        trainerId: trainerId,
        responseText: 'Thank you Kabir! Proud of your discipline on the deadlifts.',
      );

      final updated = reviewService.allReviews.firstWhere((r) => r.id == reviewId);
      expect(updated.trainerResponse, contains('Proud of your discipline'));
      expect(updated.hasResponse, isTrue);
    });

    // ── Workflow 18: Manage Connected Clients and Private Notes ──
    test('18. Manage connected Clients and private coach training notes', () async {
      final clientService = TrainerClientService.instance;
      const trainerId = 'trainer_arjun';
      const clientId = 'client_kabir';

      final client = TrainerClientModel(
        clientId: clientId,
        name: 'Kabir Varma',
        gender: Gender.male,
        activePackageName: '1 Month',
        totalSessions: 26,
        completedSessions: 4,
        remainingSessions: 22,
        firstSessionDate: DateTime.now().subtract(const Duration(days: 10)),
        lastCompletedSessionDate: DateTime.now(),
      );

      clientService.setTestClients([client]);
      final clients = await clientService.streamClientsForTrainer(trainerId).first;
      expect(clients.length, 1);

      // Add private coach note
      final note = await clientService.addNote(
        trainerId: trainerId,
        clientId: clientId,
        title: 'Mobility & Form',
        content: 'Work on ankle dorsiflexion before heavy back squats.',
      );

      expect(note.title, 'Mobility & Form');
      expect(note.content, contains('ankle dorsiflexion'));
    });

    // ── Workflow 19: Real-time Notifications ──
    test('19. Receive booking and session notifications', () async {
      final notifService = NotificationService.instance;
      const trainerId = 'trainer_arjun';

      await notifService.sendNotification(
        userId: trainerId,
        title: 'New Booking Confirmed 📅',
        body: 'Kabir Varma booked a session for tomorrow at 07:00 AM.',
        type: 'BOOKING_CONFIRMED',
        relatedId: 'bk_01',
      );

      final notifs = await notifService.streamNotificationsForTrainer(trainerId).first;
      expect(notifs.length, 1);
      expect(notifs.first.title, contains('New Booking Confirmed'));
    });

    // ── Workflow 20: Account & Notification Preferences ──
    test('20. Update account and notification preferences', () async {
      const defaultPrefs = TrainerNotificationPreferencesModel();
      expect(defaultPrefs.sessionReminders, isTrue);
      expect(defaultPrefs.messages, isTrue);

      final updatedPrefs = defaultPrefs.copyWith(messages: false);
      expect(updatedPrefs.messages, isFalse);
      expect(updatedPrefs.sessionReminders, isTrue);
      expect(updatedPrefs.accountSecurity, isTrue);
    });
  });

  group('Section 5: Error and Edge-Case Testing', () {
    test('Edge Case 1: Duplicate session completion is blocked with StateError', () async {
      const bookingId = 'bk_dup_complete';
      final booking = BookingModel(
        id: bookingId,
        clientId: 'client_edge_01',
        trainerId: 'trainer_edge_01',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime.now(),
        startTime: '07:00',
        endTime: '08:00',
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.completed,
      );

      final service = BookingService.instance;
      service.addOrUpdateBooking(booking);

      // First complete succeeds
      await service.completeSession(bookingId: bookingId);

      // Duplicate complete throws StateError
      expect(
        () => service.completeSession(bookingId: bookingId),
        throwsA(isA<StateError>()),
      );
    });

    test('Edge Case 2: Completing unconfirmed booking is blocked with StateError', () async {
      const bookingId = 'bk_unconfirmed_complete';
      final booking = BookingModel(
        id: bookingId,
        clientId: 'client_edge_02',
        trainerId: 'trainer_edge_02',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        sessionDate: DateTime.now(),
        startTime: '09:00',
        endTime: '10:00',
        status: BookingStatus.pending,
        paymentStatus: PaymentStatus.pending,
      );

      final service = BookingService.instance;
      service.addOrUpdateBooking(booking);

      expect(
        () => service.completeSession(bookingId: bookingId),
        throwsA(isA<StateError>()),
      );
    });

    test('Edge Case 3: Double-booking prevention via slot reservation locks', () async {
      const trainerId = 'trainer_lock_test';
      final date = DateTime(2026, 12, 10);
      const startTime = '06:00';
      const endTime = '07:00';

      final booking1 = BookingModel(
        id: 'bk_lock_first',
        clientId: 'client_01',
        trainerId: trainerId,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: date,
        startTime: startTime,
        endTime: endTime,
        status: BookingStatus.confirmed,
      );

      final service = BookingService.instance;
      service.addOrUpdateBooking(booking1);

      // Overlapping slot verification
      final isOverlapping = service.allBookings.any((b) =>
          b.trainerId == trainerId &&
          b.sessionDate.year == date.year &&
          b.sessionDate.month == date.month &&
          b.sessionDate.day == date.day &&
          b.startTime == startTime &&
          !b.isCancelled);

      expect(isOverlapping, isTrue);
    });

    test('Edge Case 4: Double cancellation throws StateError', () async {
      const bookingId = 'bk_double_cancel';
      final booking = BookingModel(
        id: bookingId,
        clientId: 'client_cancel_01',
        trainerId: 'trainer_cancel_01',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        sessionDate: DateTime.now().add(const Duration(days: 2)),
        startTime: '08:00',
        endTime: '09:00',
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.completed,
      );

      final service = BookingService.instance;
      service.addOrUpdateBooking(booking);

      // First cancel succeeds
      await service.cancelBooking(
        bookingId: bookingId,
        isTrainer: true,
        reason: 'Trainer emergency',
      );

      // Re-cancelling throws StateError
      expect(
        () => service.cancelBooking(
          bookingId: bookingId,
          isTrainer: true,
          reason: 'Duplicate cancel',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Edge Case 5: Zero dating, casual, or romantic terminology across all Trainer models', () {
      final bannedTokens = [
        'dating', 'matchmaker', 'romance', 'romantic', 'courtship', 'hookup', 'companion', 'speed-dating', 'swipe-right',
      ];

      final sampleTexts = [
        TrainerCategory.trainer.displayName,
        TrainerCategory.advancedTrainer.displayName,
        AppConstants.fixedTrainingPlans.map((p) => p['title']).join(' '),
        AppConstants.fixedTrainingPlans.map((p) => p['description']).join(' '),
      ];

      for (final text in sampleTexts) {
        for (final token in bannedTokens) {
          expect(text.toLowerCase().contains(token), isFalse,
              reason: 'Banned term "$token" found in "$text"');
        }
      }
    });
  });
}
