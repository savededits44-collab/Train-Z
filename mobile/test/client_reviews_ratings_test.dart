import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/errors/app_exceptions.dart';
import 'package:trainuspro/features/client/presentation/widgets/client_review_modal.dart';
import 'package:trainuspro/services/review_service.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/review_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  final reviewService = ReviewService.instance;

  setUp(() {
    reviewService.resetMockReviews();
  });

  group('Requirement 1: Review Submission Eligibility & Constraints', () {
    final completedBooking = BookingModel(
      id: 'bk_comp_001',
      clientId: 'client_rahul',
      trainerId: 'trainer_vikram',
      clientGender: Gender.male,
      trainerGender: Gender.male,
      sessionDate: DateTime.now().subtract(const Duration(days: 1)),
      startTime: '07:00 AM',
      endTime: '08:00 AM',
      status: BookingStatus.completed,
      paymentStatus: PaymentStatus.completed,
      packageName: '1 Month',
      clientName: 'Rahul Sharma',
    );

    test('Completed session allows successful review submission', () async {
      final success = await reviewService.submitReview(
        bookingId: completedBooking.id,
        clientId: completedBooking.clientId,
        trainerId: completedBooking.trainerId,
        rating: 5.0,
        comment: 'Outstanding coaching session! Great form cues on deadlifts.',
        categories: ['Technique & Form', 'Punctual & Prepared'],
        clientName: 'Rahul Sharma',
        bookingContext: completedBooking,
      );

      expect(success, isTrue);
      final saved = reviewService.getMockReview(completedBooking.id);
      expect(saved, isNotNull);
      expect(saved!.rating, 5.0);
      expect(saved.comment, 'Outstanding coaching session! Great form cues on deadlifts.');
      expect(saved.categories, contains('Technique & Form'));
      expect(saved.isPublic, isTrue);
      expect(saved.isReported, isFalse);
    });

    test('Rejects reviews for unconfirmed / pending bookings', () async {
      final pendingBooking = completedBooking.copyWith(
        id: 'bk_pend_002',
        status: BookingStatus.pending,
      );

      expect(
        () => reviewService.submitReview(
          bookingId: pendingBooking.id,
          clientId: pendingBooking.clientId,
          trainerId: pendingBooking.trainerId,
          rating: 4.0,
          comment: 'Good session workout.',
          bookingContext: pendingBooking,
        ),
        throwsA(isA<ReviewException>().having(
          (e) => e.message,
          'message',
          contains('Reviews can only be submitted for completed training sessions'),
        )),
      );
    });

    test('Rejects reviews for confirmed but not yet completed bookings', () async {
      final confirmedBooking = completedBooking.copyWith(
        id: 'bk_conf_003',
        status: BookingStatus.confirmed,
      );

      expect(
        () => reviewService.submitReview(
          bookingId: confirmedBooking.id,
          clientId: confirmedBooking.clientId,
          trainerId: confirmedBooking.trainerId,
          rating: 5.0,
          comment: 'Looking forward to this workout.',
          bookingContext: confirmedBooking,
        ),
        throwsA(isA<ReviewException>().having(
          (e) => e.message,
          'message',
          contains('Reviews can only be submitted for completed training sessions'),
        )),
      );
    });

    test('Rejects reviews for cancelled sessions', () async {
      final cancelledBooking = completedBooking.copyWith(
        id: 'bk_canc_004',
        status: BookingStatus.cancelledClientEarly,
      );

      expect(
        () => reviewService.submitReview(
          bookingId: cancelledBooking.id,
          clientId: cancelledBooking.clientId,
          trainerId: cancelledBooking.trainerId,
          rating: 1.0,
          comment: 'Session was cancelled before workout.',
          bookingContext: cancelledBooking,
        ),
        throwsA(isA<ReviewException>().having(
          (e) => e.message,
          'message',
          contains('Reviews can only be submitted for completed training sessions'),
        )),
      );
    });

    test('Rejects review if client is not the athlete who booked the session', () async {
      expect(
        () => reviewService.submitReview(
          bookingId: completedBooking.id,
          clientId: 'stranger_client_999',
          trainerId: completedBooking.trainerId,
          rating: 5.0,
          comment: 'Impersonating another athlete.',
          bookingContext: completedBooking,
        ),
        throwsA(isA<ReviewException>().having(
          (e) => e.message,
          'message',
          contains('Only the athlete who completed this booking can submit a review'),
        )),
      );
    });

    test('Validates rating range (must be between 1.0 and 5.0 stars)', () async {
      expect(
        () => reviewService.submitReview(
          bookingId: completedBooking.id,
          clientId: completedBooking.clientId,
          trainerId: completedBooking.trainerId,
          rating: 0.5,
          comment: 'Too low rating score.',
          bookingContext: completedBooking,
        ),
        throwsA(isA<ReviewException>().having(
          (e) => e.message,
          'message',
          contains('Rating must be between 1.0 and 5.0 stars'),
        )),
      );

      expect(
        () => reviewService.submitReview(
          bookingId: completedBooking.id,
          clientId: completedBooking.clientId,
          trainerId: completedBooking.trainerId,
          rating: 6.0,
          comment: 'Too high rating score.',
          bookingContext: completedBooking,
        ),
        throwsA(isA<ReviewException>().having(
          (e) => e.message,
          'message',
          contains('Rating must be between 1.0 and 5.0 stars'),
        )),
      );
    });

    test('Enforces written feedback minimum character length (>= 5 chars)', () async {
      expect(
        () => reviewService.submitReview(
          bookingId: completedBooking.id,
          clientId: completedBooking.clientId,
          trainerId: completedBooking.trainerId,
          rating: 4.0,
          comment: 'Ok', // only 2 chars
          bookingContext: completedBooking,
        ),
        throwsA(isA<ReviewException>().having(
          (e) => e.message,
          'message',
          contains('must be at least 5 characters long'),
        )),
      );
    });
  });

  group('Requirement 1 & 3: Single Review Guarantee & In-Place Editing', () {
    final booking = BookingModel(
      id: 'bk_comp_edit_001',
      clientId: 'client_priya',
      trainerId: 'trainer_ananya',
      clientGender: Gender.female,
      trainerGender: Gender.female,
      sessionDate: DateTime.now().subtract(const Duration(days: 2)),
      startTime: '08:00 AM',
      endTime: '09:00 AM',
      status: BookingStatus.completed,
      paymentStatus: PaymentStatus.completed,
      packageName: '1 Month',
      clientName: 'Priya Patel',
    );

    test('Editing an existing review updates the same record without duplicating', () async {
      // 1. Initial submission
      await reviewService.submitReview(
        bookingId: booking.id,
        clientId: booking.clientId,
        trainerId: booking.trainerId,
        rating: 4.0,
        comment: 'Very solid workout session, pushed my limits.',
        categories: ['Challenging Workout'],
        clientName: 'Priya Patel',
        bookingContext: booking,
      );

      // Verify single record
      final reviewsBefore = await reviewService.streamTrainerReviews(booking.trainerId).first;
      expect(reviewsBefore.length, 1);
      expect(reviewsBefore.first.rating, 4.0);
      expect(reviewsBefore.first.comment, 'Very solid workout session, pushed my limits.');

      // 2. Client edits review to 5.0 stars with added categories
      await reviewService.submitReview(
        bookingId: booking.id,
        clientId: booking.clientId,
        trainerId: booking.trainerId,
        rating: 5.0,
        comment: 'Updated review: Absolute masterclass in form and hypertrophy!',
        categories: ['Challenging Workout', 'Technique & Form', 'Highly Motivating'],
        clientName: 'Priya Patel',
        bookingContext: booking,
      );

      // Verify still exactly 1 review exists for this booking/trainer
      final reviewsAfter = await reviewService.streamTrainerReviews(booking.trainerId).first;
      expect(reviewsAfter.length, 1);
      expect(reviewsAfter.first.id, booking.id);
      expect(reviewsAfter.first.rating, 5.0);
      expect(reviewsAfter.first.comment, 'Updated review: Absolute masterclass in form and hypertrophy!');
      expect(reviewsAfter.first.categories.length, 3);
    });
  });

  group('Requirement 2 & 3: Client Privacy & Name Masking', () {
    final booking = BookingModel(
      id: 'bk_priv_001',
      clientId: 'client_rahul',
      trainerId: 'trainer_1',
      clientGender: Gender.male,
      trainerGender: Gender.male,
      sessionDate: DateTime.now(),
      startTime: '06:00 AM',
      endTime: '07:00 AM',
      status: BookingStatus.completed,
      paymentStatus: PaymentStatus.completed,
      packageName: '1 Month',
    );

    test('Masks multi-word client full names (e.g. Rahul Sharma -> Rahul S.)', () async {
      await reviewService.submitReview(
        bookingId: booking.id,
        clientId: booking.clientId,
        trainerId: booking.trainerId,
        rating: 5.0,
        comment: 'Great workout guidance and pacing.',
        clientName: 'Rahul Sharma',
        bookingContext: booking,
      );

      final saved = reviewService.getMockReview(booking.id);
      expect(saved!.clientName, 'Rahul S.');
    });

    test('Preserves single first names (e.g. Vikram -> Vikram)', () async {
      await reviewService.submitReview(
        bookingId: 'bk_priv_002',
        clientId: 'client_vikram',
        trainerId: booking.trainerId,
        rating: 5.0,
        comment: 'High intensity and great motivational support.',
        clientName: 'Vikram',
        bookingContext: booking.copyWith(id: 'bk_priv_002', clientId: 'client_vikram'),
      );

      final saved = reviewService.getMockReview('bk_priv_002');
      expect(saved!.clientName, 'Vikram');
    });

    test('Falls back to "Verified Athlete" when client name is omitted or empty', () async {
      await reviewService.submitReview(
        bookingId: 'bk_priv_003',
        clientId: 'client_anon',
        trainerId: booking.trainerId,
        rating: 4.0,
        comment: 'Prompt trainer arrival and excellent exercise variety.',
        clientName: '   ',
        bookingContext: booking.copyWith(id: 'bk_priv_003', clientId: 'client_anon'),
      );

      final saved = reviewService.getMockReview('bk_priv_003');
      expect(saved!.clientName, 'Verified Athlete');
    });
  });

  group('Requirement 2 & 4: Trainer Aggregate Ratings Calculation', () {
    const trainerId = 'trainer_aggregate_test';

    test('Calculates accurate average rating and count from genuine eligible reviews', () async {
      // 1. Initial state: 0 reviews
      final initialAgg = await reviewService.calculateTrainerAggregateRating(trainerId);
      expect(initialAgg['totalReviews'], 0);
      expect(initialAgg['ratingAvg'], 5.0); // default baseline

      // 2. Add Review 1: 5.0
      await reviewService.submitReview(
        bookingId: 'bk_agg_01',
        clientId: 'client_1',
        trainerId: trainerId,
        rating: 5.0,
        comment: 'Exceptional training experience.',
        bookingContext: BookingModel(
          id: 'bk_agg_01',
          clientId: 'client_1',
          trainerId: trainerId,
          clientGender: Gender.male,
          trainerGender: Gender.male,
          sessionDate: DateTime.now(),
          startTime: '07:00 AM',
          endTime: '08:00 AM',
          status: BookingStatus.completed,
          paymentStatus: PaymentStatus.completed,
          packageName: '1 Month',
        ),
      );

      // 3. Add Review 2: 4.0
      await reviewService.submitReview(
        bookingId: 'bk_agg_02',
        clientId: 'client_2',
        trainerId: trainerId,
        rating: 4.0,
        comment: 'Great training form correction.',
        bookingContext: BookingModel(
          id: 'bk_agg_02',
          clientId: 'client_2',
          trainerId: trainerId,
          clientGender: Gender.male,
          trainerGender: Gender.male,
          sessionDate: DateTime.now(),
          startTime: '08:00 AM',
          endTime: '09:00 AM',
          status: BookingStatus.completed,
          paymentStatus: PaymentStatus.completed,
          packageName: '1 Month',
        ),
      );

      // 4. Add Review 3: 4.5
      await reviewService.submitReview(
        bookingId: 'bk_agg_03',
        clientId: 'client_3',
        trainerId: trainerId,
        rating: 4.5,
        comment: 'Very consistent, punctual and demanding session.',
        bookingContext: BookingModel(
          id: 'bk_agg_03',
          clientId: 'client_3',
          trainerId: trainerId,
          clientGender: Gender.female,
          trainerGender: Gender.male,
          sessionDate: DateTime.now(),
          startTime: '09:00 AM',
          endTime: '10:00 AM',
          status: BookingStatus.completed,
          paymentStatus: PaymentStatus.completed,
          packageName: '1 Month',
        ),
      );

      // Average: (5.0 + 4.0 + 4.5) / 3 = 13.5 / 3 = 4.5
      final agg = await reviewService.calculateTrainerAggregateRating(trainerId);
      expect(agg['totalReviews'], 3);
      expect(agg['ratingAvg'], 4.5);
    });
  });

  group('Requirement 3: Review Reporting & Content Moderation', () {
    const trainerId = 'trainer_report_test';

    test('Reporting an inappropriate review flags it and logs report', () async {
      await reviewService.submitReview(
        bookingId: 'bk_rep_01',
        clientId: 'client_bad',
        trainerId: trainerId,
        rating: 1.0,
        comment: 'Violative abusive comment containing inappropriate language.',
        bookingContext: BookingModel(
          id: 'bk_rep_01',
          clientId: 'client_bad',
          trainerId: trainerId,
          clientGender: Gender.male,
          trainerGender: Gender.male,
          sessionDate: DateTime.now(),
          startTime: '07:00 AM',
          endTime: '08:00 AM',
          status: BookingStatus.completed,
          paymentStatus: PaymentStatus.completed,
          packageName: '1 Month',
        ),
      );

      // Also add a legitimate 5.0 review
      await reviewService.submitReview(
        bookingId: 'bk_rep_02',
        clientId: 'client_good',
        trainerId: trainerId,
        rating: 5.0,
        comment: 'Wonderful coach, professional and punctual.',
        bookingContext: BookingModel(
          id: 'bk_rep_02',
          clientId: 'client_good',
          trainerId: trainerId,
          clientGender: Gender.female,
          trainerGender: Gender.male,
          sessionDate: DateTime.now(),
          startTime: '08:00 AM',
          endTime: '09:00 AM',
          status: BookingStatus.completed,
          paymentStatus: PaymentStatus.completed,
          packageName: '1 Month',
        ),
      );

      // Total reviews initially = 2 (avg = 3.0)
      final aggBefore = await reviewService.calculateTrainerAggregateRating(trainerId);
      expect(aggBefore['totalReviews'], 2);
      expect(aggBefore['ratingAvg'], 3.0);

      // Report the abusive review
      final reportSuccess = await reviewService.reportReview(
        reviewId: 'bk_rep_01',
        reporterId: 'client_moderator',
        reason: 'Inappropriate or Offensive Language',
        details: 'Review violates platform respectful conduct rules.',
      );
      expect(reportSuccess, isTrue);

      // Verify report was saved in mock store
      expect(reviewService.mockReports.length, 1);
      expect(reviewService.mockReports.first['reviewId'], 'bk_rep_01');
      expect(reviewService.mockReports.first['status'], 'PENDING_MODERATION');

      // Verify reported review is excluded from public streams
      final publicReviews = await reviewService.streamTrainerReviews(trainerId).first;
      expect(publicReviews.length, 1);
      expect(publicReviews.first.id, 'bk_rep_02');

      // Verify reported review is excluded from trainer aggregate calculation
      final aggAfter = await reviewService.calculateTrainerAggregateRating(trainerId);
      expect(aggAfter['totalReviews'], 1);
      expect(aggAfter['ratingAvg'], 5.0);
    });
  });

  group('Safety & Professional Standards Audit', () {
    test('Zero dating or romantic terminology across review models', () {
      final review = ReviewModel(
        id: 'rev_audit_01',
        bookingId: 'bk_audit_01',
        clientId: 'client_audit',
        trainerId: 'trainer_audit',
        clientName: 'Rohit K.',
        rating: 5.0,
        comment: 'Challenging hypertrophy training and strict squat biomechanics.',
        categories: ['Technique & Form', 'Punctual & Prepared'],
        isPublic: true,
        createdAt: DateTime.now(),
      );

      final mapString = review.toMap().toString().toLowerCase();
      expect(mapString.contains('dating'), isFalse);
      expect(mapString.contains('match'), isFalse);
      expect(mapString.contains('single'), isFalse);
      expect(mapString.contains('hookup'), isFalse);
      expect(mapString.contains('flirt'), isFalse);
      expect(mapString.contains('romance'), isFalse);
    });
  });

  group('ClientReviewModal UI Widget Tests', () {
    final testBooking = BookingModel(
      id: 'bk_ui_001',
      clientId: 'client_ui',
      trainerId: 'trainer_ui',
      clientGender: Gender.male,
      trainerGender: Gender.male,
      sessionDate: DateTime.now().subtract(const Duration(days: 1)),
      startTime: '07:00 AM',
      endTime: '08:00 AM',
      status: BookingStatus.completed,
      paymentStatus: PaymentStatus.completed,
      packageName: '1 Month',
      trainerName: 'Arjun Verma',
      clientName: 'Rahul Sharma',
    );

    testWidgets('Renders all modal sections and elements correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientReviewModal(booking: testBooking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rate Your Training Session'), findsOneWidget);
      expect(find.text('Arjun Verma • 60-Min Training'), findsOneWidget);
      expect(find.text('HOW WAS YOUR WORKOUT?'), findsOneWidget);
      expect(find.text('5.0 ★ Excellent Workout'), findsOneWidget);
      expect(find.text('WORKOUT HIGHLIGHTS (OPTIONAL)'), findsOneWidget);
      expect(find.text('Punctual & Prepared'), findsOneWidget);
      expect(find.text('Technique & Form'), findsOneWidget);
      expect(find.text('WRITTEN FEEDBACK'), findsOneWidget);
      expect(find.text('Submit Review'), findsOneWidget);
    });

    testWidgets('Selecting rating stars updates rating label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientReviewModal(booking: testBooking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5.0 ★ Excellent Workout'), findsOneWidget);

      // Find star icons and tap the 4th star
      final starIcons = find.byIcon(Icons.star_rounded);
      expect(starIcons, findsNWidgets(5));
      await tester.tap(starIcons.at(3)); // 4th star (0-indexed 3)
      await tester.pumpAndSettle();

      expect(find.text('4.0 ★ Very Good Session'), findsOneWidget);
    });

    testWidgets('Tapping category chips toggles selection and updates state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientReviewModal(booking: testBooking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chipFinder = find.widgetWithText(FilterChip, 'Technique & Form');
      expect(chipFinder, findsOneWidget);

      final FilterChip chipBefore = tester.widget(chipFinder);
      expect(chipBefore.selected, isFalse);

      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      final FilterChip chipAfter = tester.widget(chipFinder);
      expect(chipAfter.selected, isTrue);
    });

    testWidgets('Submitting with < 5 characters shows validation error', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientReviewModal(booking: testBooking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter short comment
      await tester.enterText(find.byType(TextFormField), 'Bad');
      await tester.pumpAndSettle();

      // Tap submit
      await tester.tap(find.text('Submit Review'));
      await tester.pumpAndSettle();

      expect(find.text('Please provide at least 5 characters of feedback.'), findsOneWidget);
    });

    testWidgets('Submitting valid feedback stores review successfully', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool onSubmittedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientReviewModal(
              booking: testBooking,
              onReviewSubmitted: () => onSubmittedCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter valid feedback
      await tester.enterText(
        find.byType(TextFormField),
        'Fantastic session with great intensity and proper form guidance!',
      );
      await tester.pumpAndSettle();

      // Tap submit
      await tester.tap(find.text('Submit Review'));
      await tester.pumpAndSettle();

      expect(onSubmittedCalled, isTrue);
      final saved = reviewService.getMockReview(testBooking.id);
      expect(saved, isNotNull);
      expect(saved!.comment, 'Fantastic session with great intensity and proper form guidance!');
      expect(saved.clientName, 'Rahul S.');
    });
  });
}
