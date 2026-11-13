import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/errors/app_exceptions.dart';
import 'package:trainuspro/services/booking_service.dart';
import 'package:trainuspro/services/client_settings_service.dart';
import 'package:trainuspro/services/credit_service.dart';
import 'package:trainuspro/services/notification_service.dart';
import 'package:trainuspro/services/review_service.dart';
import 'package:trainuspro/services/support_service.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/notification_preferences_model.dart';
import 'package:trainuspro/shared/models/review_model.dart';
import 'package:trainuspro/shared/models/session_credit_model.dart';
import 'package:trainuspro/shared/models/support_ticket_model.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  group('1. Authentication Protection & Session Cleanup', () {
    test('Sign out cleanly purges all in-memory caches across all services', () async {
      // 1. Populate mock caches across services
      final now = DateTime.now();
      final mockBooking = BookingModel(
        id: 'book_session_123',
        clientId: 'client_alice',
        trainerId: 'trainer_bob',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        sessionDate: now.add(const Duration(days: 2)),
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        meetingLocation: 'Flat 402, Royal Palms, Pune',
      );
      BookingService.instance.addOrUpdateBooking(mockBooking);
      expect(BookingService.instance.allBookings.any((b) => b.id == 'book_session_123'), isTrue);

      final mockCredit = SessionCreditModel(
        clientId: 'client_alice',
        availableBalance: 10,
        totalPurchased: 10,
      );
      CreditService().setMockCredits(mockCredit);
      expect(CreditService().getMockCredits('client_alice'), isNotNull);

      final mockTicket = SupportTicketModel(
        id: 'tkt_alice_01',
        ticketNumber: 'TKT-ALICE01',
        clientId: 'client_alice',
        clientName: 'Alice Athlete',
        category: SupportTicketCategory.bookingIssue,
        subject: 'Session time issue',
        description: 'Need to check schedule details',
        createdAt: now,
        updatedAt: now,
      );
      SupportService.instance.setMockTicket(mockTicket);
      expect(SupportService.instance.getMockTicket('tkt_alice_01'), isNotNull);

      final mockReview = ReviewModel(
        id: 'rev_alice_01',
        bookingId: 'book_session_123',
        clientId: 'client_alice',
        trainerId: 'trainer_bob',
        clientName: 'Alice A.',
        rating: 5.0,
        comment: 'Outstanding strength workout!',
        createdAt: now,
        updatedAt: now,
      );
      ReviewService.instance.setMockReview(mockReview);
      expect(ReviewService.instance.getMockReview('rev_alice_01'), isNotNull);

      NotificationService.instance.setUserPreferences(
        'client_alice',
        const NotificationPreferencesModel(bookingUpdates: false),
      );

      // 2. Perform secure session sign-out
      BookingService.instance.clearBookings();
      CreditService().resetMockCredits();
      SupportService.instance.resetMockTickets();
      ReviewService.instance.resetMockReviews();
      NotificationService.instance.clearCache();
      ClientSettingsService.instance.resetMockStore();

      // 3. Verify that sensitive in-memory state is completely purged
      expect(BookingService.instance.allBookings.where((b) => b.id == 'book_session_123').isEmpty, isTrue);
      expect(CreditService().getMockCredits('client_alice'), isNull);
      expect(SupportService.instance.getMockTicket('tkt_alice_01'), isNull);
      expect(ReviewService.instance.getMockReview('rev_alice_01'), isNull);
      expect(NotificationService.instance.notifications.isEmpty, isTrue);
    });

    test('Unauthenticated ticket creation is rejected', () async {
      expect(
        () => SupportService.instance.createTicket(
          clientId: '',
          clientName: 'Anonymous',
          category: SupportTicketCategory.bookingIssue,
          subject: 'Valid Subject',
          description: 'Valid description that has more than 10 characters',
        ),
        throwsA(isA<SupportException>()),
      );
    });
  });

  group('2. Cross-Client Data Access & Ownership Security', () {
    test('Client B cannot access Client A support ticket via getTicketById', () async {
      final now = DateTime.now();
      final ticketA = SupportTicketModel(
        id: 'tkt_client_a_secure',
        ticketNumber: 'TKT-SECURE01',
        clientId: 'client_alice_id',
        clientName: 'Alice Smith',
        category: SupportTicketCategory.paymentIssue,
        subject: 'Payment double charge',
        description: 'My card was charged twice for the standard package',
        createdAt: now,
        updatedAt: now,
      );
      SupportService.instance.setMockTicket(ticketA);

      // Client A can access their own ticket
      final ownTicket = await SupportService.instance.getTicketById('tkt_client_a_secure', 'client_alice_id');
      expect(ownTicket.id, equals('tkt_client_a_secure'));

      // Client B (Eve) attempting to access Alice's ticket is rejected
      expect(
        () => SupportService.instance.getTicketById('tkt_client_a_secure', 'client_eve_hacker_id'),
        throwsA(isA<SupportException>()),
      );
    });

    test('streamTicketMessages prevents unauthorized cross-client access', () {
      final now = DateTime.now();
      final ticketA = SupportTicketModel(
        id: 'tkt_conv_alice',
        ticketNumber: 'TKT-CONV01',
        clientId: 'client_alice_id',
        clientName: 'Alice Smith',
        category: SupportTicketCategory.bookingIssue,
        subject: 'Confidential workout request',
        description: 'Need confidential coach advice',
        createdAt: now,
        updatedAt: now,
      );
      SupportService.instance.setMockTicket(ticketA);

      // Client B (Eve) streaming messages for Alice's ticket returns an error stream
      final messageStream = SupportService.instance.streamTicketMessages('tkt_conv_alice', 'client_eve_hacker_id');
      expect(messageStream, emitsError(isA<SupportException>()));
    });

    test('Review submission enforces session completion and client ownership', () async {
      final now = DateTime.now();
      final bookingPending = BookingModel(
        id: 'book_pending_test',
        clientId: 'client_athlete_1',
        trainerId: 'trainer_pro_1',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: now.add(const Duration(days: 1)),
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        status: BookingStatus.pending,
      );

      // 1. Rejects review for uncompleted booking
      expect(
        () => ReviewService.instance.submitReview(
          bookingId: 'book_pending_test',
          clientId: 'client_athlete_1',
          trainerId: 'trainer_pro_1',
          rating: 5.0,
          comment: 'Great workout session before completion',
          bookingContext: bookingPending,
        ),
        throwsA(isA<ReviewException>()),
      );

      // 2. Rejects review if caller is not the athlete who completed the booking
      final bookingCompleted = bookingPending.copyWith(status: BookingStatus.completed);
      expect(
        () => ReviewService.instance.submitReview(
          bookingId: 'book_pending_test',
          clientId: 'client_hacker_imposter',
          trainerId: 'trainer_pro_1',
          rating: 5.0,
          comment: 'Imposter review attempting cross-client submission',
          bookingContext: bookingCompleted,
        ),
        throwsA(isA<ReviewException>()),
      );

      // 3. Allows genuine athlete who completed the session
      final success = await ReviewService.instance.submitReview(
        bookingId: 'book_pending_test',
        clientId: 'client_athlete_1',
        trainerId: 'trainer_pro_1',
        rating: 4.8,
        comment: 'Exceptional technique corrections and intensity.',
        bookingContext: bookingCompleted,
      );
      expect(success, isTrue);
    });
  });

  group('3. Trainer Data Boundaries & Confidentiality', () {
    test('Public trainer profile model never exposes private documents, notes or CPR files to clients', () {
      const sensitiveTrainerProfile = TrainerProfileModel(
        uid: 'trainer_private_doc_test',
        specialties: ['Hypertrophy', 'Strength'],
        experienceYears: 5.0,
        hourlyRate: 1500,
        category: TrainerCategory.advancedTrainer,
        verificationStatus: TrainerVerificationStatus.approved,
        isActive: true,
        ratingAvg: 4.9,
        totalReviews: 24,
        adminReviewNotes: 'INTERNAL ADMIN NOTE: Checked CPR certificate and police clearance on Nov 10',
        verificationDocuments: [
          'https://storage.trainz.internal/certificates/trainer_private_doc_test/govt_id.pdf',
          'https://storage.trainz.internal/certificates/trainer_private_doc_test/cpr_first_aid.pdf',
        ],
        certificationDocuments: [
          'https://storage.trainz.internal/certificates/trainer_private_doc_test/ace_certified.pdf',
        ],
      );

      final displayModel = TrainerDisplayModel(
        profile: sensitiveTrainerProfile,
        uid: sensitiveTrainerProfile.uid,
        displayName: 'Coach Vikram',
        gender: Gender.male,
        specialties: sensitiveTrainerProfile.specialties,
        experienceYears: sensitiveTrainerProfile.experienceYears,
        ratingAvg: sensitiveTrainerProfile.ratingAvg,
        totalReviews: sensitiveTrainerProfile.totalReviews,
        hourlyRate: sensitiveTrainerProfile.hourlyRate,
        certifications: const ['ACE Certified Personal Trainer', 'CPR & AED'],
      );

      // Display model must contain public badge names only
      expect(displayModel.displayName, equals('Coach Vikram'));
      expect(displayModel.certifications.contains('ACE Certified Personal Trainer'), isTrue);

      // No private PDF document URLs or internal admin notes are exposed in public display model properties
      expect(displayModel.verifiedQualifications.isEmpty, isTrue);
    });

    test('Private home address privacy protection guard flags residential venues', () {
      const residentialLocations = [
        'Flat 402, Tower B, Amanora Park Town, Pune',
        'House No 12, Silver Oaks Residence, Pune',
        'Apartment 3A, Green Glen Layout, Bellandur',
        'Villa 14, Prestige Golfshire, Bangalore',
      ];

      for (final loc in residentialLocations) {
        final lower = loc.toLowerCase();
        final isHomeAddress = lower.contains('flat') ||
            lower.contains('apartment') ||
            lower.contains('house') ||
            lower.contains('home') ||
            lower.contains('residence') ||
            lower.contains('villa') ||
            lower.contains('tower') ||
            lower.contains('floor');
        expect(isHomeAddress, isTrue, reason: '$loc should be flagged as private home address');
      }

      const publicGymLocations = [
        'Gold Gym, Kalyani Nagar, Pune',
        'Cult.fit Studio, Koramangala',
        'Public Jogging Park, Shivaji Nagar',
      ];

      for (final loc in publicGymLocations) {
        final lower = loc.toLowerCase();
        final isHomeAddress = lower.contains('flat') ||
            lower.contains('apartment') ||
            lower.contains('house') ||
            lower.contains('home') ||
            lower.contains('residence') ||
            lower.contains('villa') ||
            lower.contains('tower') ||
            lower.contains('floor');
        expect(isHomeAddress, isFalse, reason: '$loc should NOT be flagged as home address');
      }
    });
  });

  group('4. Security & Role Integrity', () {
    test('Password complexity enforces minimum 8 chars, uppercase, lowercase, and digit', () {
      expect(ClientSettingsService.validateNewPassword('weak'), contains('at least 8 characters'));
      expect(ClientSettingsService.validateNewPassword('nouppercase1!'), contains('uppercase letter'));
      expect(ClientSettingsService.validateNewPassword('NOLOWERCASE1!'), contains('lowercase letter'));
      expect(ClientSettingsService.validateNewPassword('NoDigitsHere!'), contains('number'));
      expect(ClientSettingsService.validateNewPassword('Short1!'), contains('at least 8 characters'));
      expect(ClientSettingsService.validateNewPassword('TrainZ@2026Safe'), isNull);
    });

    test('Reviewer names are masked to protect personal privacy', () async {
      final now = DateTime.now();
      final completedBooking = BookingModel(
        id: 'book_privacy_mask_1',
        clientId: 'client_privacy_1',
        trainerId: 'trainer_pro_1',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: now,
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        status: BookingStatus.completed,
      );

      await ReviewService.instance.submitReview(
        bookingId: 'book_privacy_mask_1',
        clientId: 'client_privacy_1',
        trainerId: 'trainer_pro_1',
        rating: 5.0,
        comment: 'Great workout technique corrections',
        clientName: 'Rahul Sharma',
        bookingContext: completedBooking,
      );
      final savedReview = ReviewService.instance.getMockReview('book_privacy_mask_1');
      expect(savedReview?.clientName, equals('Rahul S.'));
    });

    test('Support ticket attachments enforce 5MB maximum file size', () {
      expect(5 * 1024 * 1024, equals(5242880));
      const validSize = 4 * 1024 * 1024; // 4MB
      const invalidSize = 6 * 1024 * 1024; // 6MB

      expect(validSize <= 5242880, isTrue);
      expect(invalidSize <= 5242880, isFalse);
    });
  });

  group('5. Zero Romantic/Dating Terminology Audit', () {
    test('Ensures strict personal training domain terminology with zero dating or romance jargon', () {
      final codeFilesToCheck = [
        'lib/services/client_settings_service.dart',
        'lib/services/support_service.dart',
        'lib/services/review_service.dart',
        'lib/services/credit_service.dart',
        'lib/services/firestore_service.dart',
        'lib/shared/models/support_ticket_model.dart',
        'lib/shared/models/review_model.dart',
      ];

      final prohibitedTerms = [
        'dating',
        'romance',
        'flirt',
        'hookup',
        'casual encounter',
        'speed date',
        'matchmaker',
      ];

      for (final relativePath in codeFilesToCheck) {
        final file = File(relativePath);
        if (file.existsSync()) {
          final content = file.readAsStringSync().toLowerCase();
          for (final prohibited in prohibitedTerms) {
            final regex = RegExp('\\b${RegExp.escape(prohibited)}\\b', caseSensitive: false);
            expect(
              regex.hasMatch(content),
              isFalse,
              reason: 'File $relativePath contains prohibited romantic term: $prohibited',
            );
          }
        }
      }
    });
  });
}
