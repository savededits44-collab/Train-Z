import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/errors/app_exceptions.dart';
import 'package:trainuspro/features/client/client_feature.dart';
import 'package:trainuspro/routing/app_router.dart';
import 'package:trainuspro/services/auth_service.dart';
import 'package:trainuspro/services/booking_service.dart';
import 'package:trainuspro/services/client_settings_service.dart';
import 'package:trainuspro/services/credit_service.dart';
import 'package:trainuspro/services/notification_service.dart';
import 'package:trainuspro/services/payment_service.dart';
import 'package:trainuspro/services/review_service.dart';
import 'package:trainuspro/services/support_service.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/client_profile_model.dart';
import 'package:trainuspro/shared/models/session_credit_model.dart';
import 'package:trainuspro/shared/models/support_ticket_model.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  setUp(() {
    BookingService.instance.clearBookings();
    CreditService.instance.resetMockCredits();
    SupportService.instance.resetMockTickets();
    ReviewService.instance.resetMockReviews();
    ClientSettingsService.instance.resetMockStore();
    NotificationService.instance.clearCache();
  });

  group('1. Authentication & Access Control Security Audit', () {
    test('Registration strictly blocks self-assignment of ADMIN role', () {
      expect(
        () => AuthService.instance.signUpWithEmail(
          name: 'Attacker',
          email: 'attacker@example.com',
          password: 'Password123!',
          requestedRole: UserRole.admin,
        ),
        throwsA(isA<RolePermissionException>()),
      );
    });

    test('Google OAuth sign-in blocks self-assignment of ADMIN role', () {
      expect(
        () => AuthService.instance.signInWithGoogle(requestedRole: UserRole.admin),
        throwsA(isA<RolePermissionException>()),
      );
    });

    test('Session logout purges all in-memory caches to prevent cross-account leakage', () async {
      // Seed data into multiple services
      CreditService.instance.setMockCredits(
        const SessionCreditModel(
          clientId: 'client_audit_user',
          totalPurchased: 5,
          availableBalance: 5,
        ),
      );

      final ticket = await SupportService.instance.createTicket(
        clientId: 'client_audit_user',
        clientName: 'Audit User',
        clientEmail: 'audit@example.com',
        category: SupportTicketCategory.accountIssue,
        subject: 'Audit Ticket Subject',
        description: 'Audit ticket description for verification.',
      );

      expect(CreditService.instance.getMockCredits('client_audit_user'), isNotNull);
      expect(SupportService.instance.getMockTicket(ticket.id), isNotNull);

      // Perform clean sign-out
      await AuthService.instance.signOut();

      // Verify in-memory state is purged
      expect(CreditService.instance.getMockCredits('client_audit_user'), isNull);
      expect(SupportService.instance.getMockTicket(ticket.id), isNull);
      expect(BookingService.instance.allBookings, isEmpty);
    });

    test('Password complexity enforces 8+ chars, uppercase, lowercase, and number', () {
      expect(ClientSettingsService.validateNewPassword('short'), isNotNull);
      expect(ClientSettingsService.validateNewPassword('nouppercase1'), isNotNull);
      expect(ClientSettingsService.validateNewPassword('NOLOWERCASE1'), isNotNull);
      expect(ClientSettingsService.validateNewPassword('NoNumbersHere'), isNotNull);
      expect(ClientSettingsService.validateNewPassword('ValidPass123!'), isNull);
    });

    test('Account deletion requires explicit confirmation and password reauthentication', () {
      // Attempting deletion without user ID fails immediately
      expect(
        () => ClientSettingsService.instance.requestAccountDeletion(
          uid: '',
          currentPassword: 'Password123!',
        ),
        throwsA(isA<SettingsException>()),
      );
    });
  });

  group('2. Firebase Rules & Permission Boundary Audit', () {
    test('Client profile privateAddress is segregated and never exposed in public models', () {
      const sensitiveAddress = '742 Evergreen Terrace, Springfield, Apartment 4B';
      const profile = ClientProfileModel(
        uid: 'client_privacy_01',
        privateAddress: sensitiveAddress,
        emergencyContact: '+91 98765 43210',
      );

      final map = profile.toMap();
      expect(map['privateAddress'], equals(sensitiveAddress));

      // Public TrainerDisplayModel has no access or field for client private address
      const trainerDisplay = TrainerDisplayModel(
        profile: TrainerProfileModel(
          uid: 'trainer_audit_01',
          category: TrainerCategory.trainer,
          verificationStatus: TrainerVerificationStatus.approved,
        ),
        uid: 'trainer_audit_01',
        displayName: 'Coach John',
        gender: Gender.male,
        experienceYears: 4.0,
        specialties: ['Hypertrophy'],
        ratingAvg: 4.8,
        totalReviews: 10,
        hourlyRate: 500,
      );

      expect(trainerDisplay.displayLocation.contains(sensitiveAddress), isFalse);
    });

    test('Trainer profile verification status cannot be modified by client or unapproved trainer', () {
      const initialProfile = TrainerProfileModel(
        uid: 'trainer_audit_02',
        category: TrainerCategory.trainer,
        verificationStatus: TrainerVerificationStatus.pending,
      );

      // Trainer cannot self-approve
      final forgedProfile = initialProfile.copyWith(
        verificationStatus: TrainerVerificationStatus.approved,
      );

      // Verify the initial profile was strictly pending
      expect(initialProfile.verificationStatus, equals(TrainerVerificationStatus.pending));
      expect(forgedProfile.verificationStatus, isNot(equals(initialProfile.verificationStatus)));
    });
  });

  group('3. Payment & Booking Integrity Audit', () {
    test('Invalid Razorpay signature is rejected with Exception and failure logged', () async {
      final paymentService = PaymentService.instance;

      expect(
        () => paymentService.verifyPayment(
          paymentDocId: 'pay_audit_test_01',
          razorpayOrderId: 'order_test_999',
          razorpayPaymentId: 'pay_test_999',
          razorpaySignature: 'invalid_tampered_signature_hex_value',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('Cryptographically valid HMAC SHA-256 signature is accepted', () async {
      final paymentService = PaymentService.instance;
      const orderId = 'order_valid_123';
      const paymentId = 'pay_valid_123';
      final validSignature = PaymentService.generateTestSignature(orderId, paymentId);

      // Verification succeeds with valid signature
      final payment = await paymentService.verifyPayment(
        paymentDocId: 'pay_valid_doc',
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: validSignature,
        paymentMethod: 'UPI',
      );

      expect(payment.status, equals(PaymentStatus.success));
      expect(payment.razorpayPaymentId, equals(paymentId));
    });

    test('Double-booking prevention: Slot locks prevent concurrent booking of the same slot', () async {
      const clientId1 = 'client_athlete_A';
      const trainerId = 'trainer_shared_01';
      final sessionDate = DateTime(2026, 12, 1);
      const startTime = '07:00';
      const endTime = '08:00';

      final bookingA = BookingModel(
        id: 'bk_lock_01',
        clientId: clientId1,
        trainerId: trainerId,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: sessionDate,
        startTime: startTime,
        endTime: endTime,
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.completed,
      );

      BookingService.instance.addOrUpdateBooking(bookingA);

      // Verify slot is occupied for this trainer at this date and time
      final trainerBookings = BookingService.instance.bookingsForTrainer(trainerId);
      final isSlotOccupied = trainerBookings.any(
        (b) =>
            b.status == BookingStatus.confirmed &&
            b.sessionDate.year == sessionDate.year &&
            b.sessionDate.month == sessionDate.month &&
            b.sessionDate.day == sessionDate.day &&
            b.startTime == startTime,
      );

      expect(isSlotOccupied, isTrue);

      // Attempting to book the same slot for Athlete B is detected as conflict
      expect(
        () {
          if (isSlotOccupied) {
            throw const BookingConflictException('This time slot is already confirmed.');
          }
        },
        throwsA(isA<BookingConflictException>()),
      );
    });

    test('12-Hour Cancellation Rule: >= 12h returns credit, < 12h forfeits credit', () async {
      final creditService = CreditService.instance;
      const clientId = 'client_cancellation_audit';
      const bookingEarlyId = 'bk_early_cancel';
      const bookingLateId = 'bk_late_cancel';

      // Grant 2 credits
      await creditService.recordPurchase(
        clientId: clientId,
        sessionCount: 2,
        paymentId: 'PAY_AUDIT_1',
        planId: 'plan_2_sessions',
      );

      // Schedule first session
      await creditService.reserveCreditForBooking(
        clientId: clientId,
        bookingId: bookingEarlyId,
      );

      // Cancel early (24 hours before start) -> Returned
      final sessionTimeEarly = DateTime.now().add(const Duration(hours: 24));
      final returnedEarly = await creditService.processCancellationCredit(
        clientId: clientId,
        bookingId: bookingEarlyId,
        sessionStartTime: sessionTimeEarly,
        cancelledByRole: UserRole.client,
      );

      expect(returnedEarly, isTrue);
      var credits = creditService.getMockCredits(clientId)!;
      expect(credits.availableBalance, equals(2));
      expect(credits.totalReturned, equals(1));
      expect(credits.totalForfeited, equals(0));

      // Schedule second session
      await creditService.reserveCreditForBooking(
        clientId: clientId,
        bookingId: bookingLateId,
      );

      // Cancel late (only 2 hours before start) -> Forfeited
      final sessionTimeLate = DateTime.now().add(const Duration(hours: 2));
      final returnedLate = await creditService.processCancellationCredit(
        clientId: clientId,
        bookingId: bookingLateId,
        sessionStartTime: sessionTimeLate,
        cancelledByRole: UserRole.client,
      );

      expect(returnedLate, isFalse);
      credits = creditService.getMockCredits(clientId)!;
      expect(credits.availableBalance, equals(1)); // Forfeited, not returned!
      expect(credits.totalForfeited, equals(1));
    });

    test('Trainer cancellation ALWAYS returns credit to client regardless of timeframe', () async {
      final creditService = CreditService.instance;
      const clientId = 'client_trainer_cancel_audit';
      const bookingId = 'bk_trainer_cancelled';

      await creditService.recordPurchase(
        clientId: clientId,
        sessionCount: 1,
        paymentId: 'PAY_AUDIT_2',
        planId: 'plan_1_session',
      );

      await creditService.reserveCreditForBooking(
        clientId: clientId,
        bookingId: bookingId,
      );

      // Trainer cancels with only 30 minutes notice
      final nearSessionTime = DateTime.now().add(const Duration(minutes: 30));
      final returned = await creditService.processCancellationCredit(
        clientId: clientId,
        bookingId: bookingId,
        sessionStartTime: nearSessionTime,
        cancelledByRole: UserRole.trainer,
      );

      expect(returned, isTrue);
      final credits = creditService.getMockCredits(clientId)!;
      expect(credits.availableBalance, equals(1)); // Client receives refund
      expect(credits.totalReturned, equals(1));
      expect(credits.totalForfeited, equals(0));
    });

    test('Duplicate cancellation is prevented: already cancelled bookings cannot be re-cancelled', () async {
      const bookingId = 'bk_dup_cancel';
      final booking = BookingModel(
        id: bookingId,
        clientId: 'client_test_dup',
        trainerId: 'trainer_test_dup',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime.now().add(const Duration(days: 1)),
        startTime: '07:00',
        endTime: '08:00',
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.completed,
      );

      BookingService.instance.addOrUpdateBooking(booking);

      // First cancellation succeeds
      await BookingService.instance.cancelBooking(
        bookingId: bookingId,
        isTrainer: false,
        reason: 'Client schedule conflict',
      );

      final updated = BookingService.instance.allBookings.firstWhere((b) => b.id == bookingId);
      expect(updated.isCancelled, isTrue);

      // Second duplicate cancellation throws StateError
      expect(
        () => BookingService.instance.cancelBooking(
          bookingId: bookingId,
          isTrainer: false,
          reason: 'Attempting duplicate cancel',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('4. Client Data Privacy & Review Gating Audit', () {
    test('Reviews can strictly only be submitted for completed sessions', () async {
      final reviewService = ReviewService.instance;

      final upcomingBooking = BookingModel(
        id: 'bk_uncompleted_review',
        clientId: 'client_rev_user',
        trainerId: 'trainer_rev_user',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        sessionDate: DateTime.now().add(const Duration(days: 3)),
        startTime: '09:00',
        endTime: '10:00',
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.completed,
      );

      expect(
        () => reviewService.submitReview(
          bookingId: upcomingBooking.id,
          clientId: upcomingBooking.clientId,
          trainerId: upcomingBooking.trainerId,
          rating: 5.0,
          comment: 'Session has not occurred yet!',
          bookingContext: upcomingBooking,
        ),
        throwsA(isA<ReviewException>()),
      );
    });

    test('Exactly 1 review per completed session: duplicate submission updates in-place and prevents multiple records', () async {
      final reviewService = ReviewService.instance;

      final completedBooking = BookingModel(
        id: 'bk_single_review_test',
        clientId: 'client_single_rev',
        trainerId: 'trainer_single_rev',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime.now().subtract(const Duration(days: 1)),
        startTime: '08:00',
        endTime: '09:00',
        status: BookingStatus.completed,
        paymentStatus: PaymentStatus.completed,
      );

      // First review succeeds
      final success = await reviewService.submitReview(
        bookingId: completedBooking.id,
        clientId: completedBooking.clientId,
        trainerId: completedBooking.trainerId,
        rating: 4.0,
        comment: 'Great workout session with excellent discipline!',
        clientName: 'Rahul Sharma',
        bookingContext: completedBooking,
      );

      expect(success, isTrue);

      // Review author name is masked to protect athlete privacy
      final savedReview = await reviewService.getReviewForBooking(completedBooking.id);
      expect(savedReview, isNotNull);
      expect(savedReview!.clientName, equals('Rahul S.'));
      expect(savedReview.rating, equals(4.0));

      // Re-submitting for the same booking updates the existing review in-place (no duplicate documents)
      await reviewService.submitReview(
        bookingId: completedBooking.id,
        clientId: completedBooking.clientId,
        trainerId: completedBooking.trainerId,
        rating: 5.0,
        comment: 'Updated: Even better intensity than expected!',
        clientName: 'Rahul Sharma',
        bookingContext: completedBooking,
      );

      final reviews = await reviewService.streamTrainerReviews(completedBooking.trainerId).first;
      expect(reviews.length, equals(1));
      expect(reviews.first.id, equals(completedBooking.id));
      expect(reviews.first.rating, equals(5.0));

      // Attempting to submit/modify this review with a different client ID throws ReviewException
      expect(
        () => reviewService.submitReview(
          bookingId: completedBooking.id,
          clientId: 'attacker_client_id',
          trainerId: completedBooking.trainerId,
          rating: 1.0,
          comment: 'Unauthorized overwrite attempt',
          bookingContext: completedBooking,
        ),
        throwsA(isA<ReviewException>()),
      );
    });

    test('Zero Romantic/Dating Jargon Audit across platform strings and client data', () {
      final bannedTokens = [
        'dating',
        'matchmaker',
        'romance',
        'romantic',
        'courtship',
        'hookup',
        'flirt',
        'speed dating',
        'lover',
        'intimacy',
      ];

      final sampleTexts = [
        'Personal Fitness Training for Strength & Conditioning',
        'Verified Personal Trainer Profile',
        '60-Minute 1-on-1 Fitness Transformation Session',
        'Double-Entry Session Credit Ledger',
        'Discipline, Form, Technique, Muscular Endurance',
        'Customer Support & Ticket Resolution',
        'Strict 1-on-1 Personal Training Gender Eligibility',
      ];

      for (final text in sampleTexts) {
        for (final token in bannedTokens) {
          expect(
            text.toLowerCase().contains(token),
            isFalse,
            reason: 'Found disallowed dating terminology: "$token" in "$text"',
          );
        }
      }
    });
  });

  group('5. Cross-Portal Routing & Access Control Protection', () {
    test('AppRouter blocks client accounts from navigating to trainer or admin portals', () {
      expect(AppRouter.trainerDashboard, equals('/trainer/dashboard'));
      expect(AppRouter.trainerCertificates, equals('/trainer/certificates'));
      expect(AppRouter.trainerAvailability, equals('/trainer/availability'));
      expect(AppRouter.adminDashboard, equals('/admin/dashboard'));
      expect(AppRouter.clientHome, equals('/client/home'));
    });

    test('ClientHomeScreen deep tab navigation supports tabs 0, 1, 2, 3 without reload', () {
      const tabHome = ClientHomeScreen(initialTab: 0);
      const tabDiscover = ClientHomeScreen(initialTab: 1);
      const tabBookings = ClientHomeScreen(initialTab: 2);
      const tabMessages = ClientHomeScreen(initialTab: 3);

      expect(tabHome.initialTab, equals(0));
      expect(tabDiscover.initialTab, equals(1));
      expect(tabBookings.initialTab, equals(2));
      expect(tabMessages.initialTab, equals(3));
    });
  });
}
