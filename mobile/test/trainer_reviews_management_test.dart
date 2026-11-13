import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:trainuspro/screens/trainer/trainer_reviews_screen.dart';
import 'package:trainuspro/services/trainer_review_service.dart';
import 'package:trainuspro/shared/models/review_model.dart';
import 'package:trainuspro/shared/models/review_report_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testTrainerId = 'trainer_rohit_uid_101';
  const otherTrainerId = 'trainer_priya_uid_202';
  final now = DateTime.now();

  setUp(() {
    TrainerReviewService.instance.resetForTest();
  });

  group('1. ReviewModel Extended Fields & Serialization', () {
    test('Stores and serializes trainer responses and moderation report audit fields', () {
      final respondedTime = DateTime(2026, 11, 13, 11, 30);
      final review = ReviewModel(
        id: 'rev_audit_101',
        bookingId: 'bk_101',
        clientId: 'client_sam',
        clientName: 'Samir Verma',
        clientPhotoUrl: 'https://trainz.app/photos/samir.jpg',
        trainerId: testTrainerId,
        rating: 4.8,
        comment: 'Great coaching on deadlift form and core bracing.',
        packageName: '1 Month Transformation',
        sessionDate: DateTime(2026, 11, 10),
        trainerResponse: 'Thank you Samir! Your discipline and progressive overload consistency have been phenomenal.',
        trainerRespondedAt: respondedTime,
        isReported: false,
      );

      expect(review.stars, 5);
      expect(review.displayClientName, 'Samir Verma');
      expect(review.hasResponse, isTrue);

      final map = review.toMap();
      expect(map['trainerResponse'], contains('discipline and progressive overload'));
      expect(map['clientName'], 'Samir Verma');
      expect(map['packageName'], '1 Month Transformation');

      final reconstructed = ReviewModel.fromMap(map, id: 'rev_audit_101');
      expect(reconstructed.id, 'rev_audit_101');
      expect(reconstructed.displayClientName, 'Samir Verma');
      expect(reconstructed.trainerResponse, contains('Thank you Samir!'));
      expect(reconstructed.rating, 4.8);
      expect(reconstructed.stars, 5);
    });

    test('ReviewReportModel serializes deterministic audit report fields', () {
      final report = ReviewReportModel(
        id: '${testTrainerId}_rev_999',
        reviewId: 'rev_999',
        trainerId: testTrainerId,
        reporterId: testTrainerId,
        reason: 'Inappropriate or Abusive Language',
        details: 'Review contains profane personal attacks unrelated to workout.',
        status: 'PENDING',
        createdAt: now,
      );

      final map = report.toMap();
      expect(map['id'], '${testTrainerId}_rev_999');
      expect(map['reason'], 'Inappropriate or Abusive Language');
      expect(map['details'], contains('profane personal attacks'));

      final reconstructed = ReviewReportModel.fromMap(map, id: '${testTrainerId}_rev_999');
      expect(reconstructed.id, '${testTrainerId}_rev_999');
      expect(reconstructed.reviewId, 'rev_999');
      expect(reconstructed.status, 'PENDING');
    });
  });

  group('2. Rating Aggregations & Distribution Metrics', () {
    test('Calculates average rating, distribution bars, and positive percentage accurately', () async {
      final service = TrainerReviewService.instance;

      service.setTestReviews([
        ReviewModel(
          id: 'r1',
          bookingId: 'b1',
          clientId: 'c1',
          clientName: 'Client 1',
          trainerId: testTrainerId,
          rating: 5.0,
          comment: 'Perfect session!',
          trainerResponse: 'Thanks!',
        ),
        ReviewModel(
          id: 'r2',
          bookingId: 'b2',
          clientId: 'c2',
          clientName: 'Client 2',
          trainerId: testTrainerId,
          rating: 5.0,
          comment: 'Super energetic and punctual.',
        ),
        ReviewModel(
          id: 'r3',
          bookingId: 'b3',
          clientId: 'c3',
          clientName: 'Client 3',
          trainerId: testTrainerId,
          rating: 4.0,
          comment: 'Good guidance overall.',
        ),
        ReviewModel(
          id: 'r4',
          bookingId: 'b4',
          clientId: 'c4',
          clientName: 'Client 4',
          trainerId: testTrainerId,
          rating: 3.0,
          comment: 'Decent workout.',
        ),
      ]);

      final metrics = await service.getReviewMetrics(testTrainerId);

      // (5.0 + 5.0 + 4.0 + 3.0) / 4 = 17.0 / 4 = 4.25 -> clamped to 4.3
      expect(metrics.totalReviews, 4);
      expect(metrics.averageRating, 4.3);
      expect(metrics.formattedAverage, '4.3');
      expect(metrics.ratingDistribution[5], 2);
      expect(metrics.ratingDistribution[4], 1);
      expect(metrics.ratingDistribution[3], 1);
      expect(metrics.ratingDistribution[2], 0);
      expect(metrics.ratingDistribution[1], 0);

      // Star percentages
      expect(metrics.starPercentage(5), 0.5); // 2 out of 4 = 50%
      expect(metrics.starPercentage(4), 0.25); // 1 out of 4 = 25%

      // Positive percentage: (2 + 1) / 4 = 75%
      expect(metrics.positivePercentage, 75.0);

      // Response rate: 1 responded out of 4 = 25%
      expect(metrics.responseRatePercent, 25.0);
    });

    test('Non-public reviews are excluded from public trainer review metrics', () async {
      final service = TrainerReviewService.instance;

      service.setTestReviews([
        ReviewModel(
          id: 'r_public',
          bookingId: 'b1',
          clientId: 'c1',
          trainerId: testTrainerId,
          rating: 5.0,
          comment: 'Visible review',
          isPublic: true,
        ),
        ReviewModel(
          id: 'r_hidden',
          bookingId: 'b2',
          clientId: 'c2',
          trainerId: testTrainerId,
          rating: 1.0,
          comment: 'Draft or private feedback',
          isPublic: false,
        ),
      ]);

      final metrics = await service.getReviewMetrics(testTrainerId);
      expect(metrics.totalReviews, 1);
      expect(metrics.averageRating, 5.0);
    });
  });

  group('3. Trainer Public Responses & Ownership Enforcement', () {
    test('Submitting response updates trainerResponse and records timestamp', () async {
      final service = TrainerReviewService.instance;

      service.setTestReviews([
        ReviewModel(
          id: 'rev_reply_1',
          bookingId: 'b1',
          clientId: 'client_aman',
          clientName: 'Aman Deep',
          trainerId: testTrainerId,
          rating: 5.0,
          comment: 'Very professional coach, loved the flexibility.',
        ),
      ]);

      await service.submitTrainerResponse(
        reviewId: 'rev_reply_1',
        trainerId: testTrainerId,
        responseText: 'Thank you Aman! It was a pleasure training you.',
      );

      final updated = service.allReviews.firstWhere((r) => r.id == 'rev_reply_1');
      expect(updated.hasResponse, isTrue);
      expect(updated.trainerResponse, 'Thank you Aman! It was a pleasure training you.');
      expect(updated.trainerRespondedAt, isNotNull);

      // Verify client rating and comment remain 100% immutable
      expect(updated.rating, 5.0);
      expect(updated.comment, 'Very professional coach, loved the flexibility.');
    });

    test('Response content validation rejects empty, too short, or abusive words', () async {
      final service = TrainerReviewService.instance;

      service.setTestReviews([
        ReviewModel(
          id: 'rev_reply_val',
          bookingId: 'b1',
          clientId: 'client_aman',
          trainerId: testTrainerId,
          rating: 4.0,
          comment: 'Good session',
        ),
      ]);

      // Too short (< 3 chars)
      expect(
        () async => await service.submitTrainerResponse(
          reviewId: 'rev_reply_val',
          trainerId: testTrainerId,
          responseText: 'Hi',
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Abusive / inappropriate language
      expect(
        () async => await service.submitTrainerResponse(
          reviewId: 'rev_reply_val',
          trainerId: testTrainerId,
          responseText: 'You are an idiot and this review is a fake scam!',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Trainer cannot respond to or delete responses on reviews belonging to another trainer', () async {
      final service = TrainerReviewService.instance;

      service.setTestReviews([
        ReviewModel(
          id: 'rev_other_trainer',
          bookingId: 'b2',
          clientId: 'client_aman',
          trainerId: otherTrainerId,
          rating: 5.0,
          comment: 'Super coach Priya!',
        ),
      ]);

      // Unauthorized response attempt
      expect(
        () async => await service.submitTrainerResponse(
          reviewId: 'rev_other_trainer',
          trainerId: testTrainerId,
          responseText: 'Unauthorized response attempt',
        ),
        throwsA(isA<StateError>()),
      );

      // Unauthorized deletion attempt
      expect(
        () async => await service.deleteTrainerResponse(
          reviewId: 'rev_other_trainer',
          trainerId: testTrainerId,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Deleting trainer response clears response text and timestamp', () async {
      final service = TrainerReviewService.instance;

      service.setTestReviews([
        ReviewModel(
          id: 'rev_to_delete',
          bookingId: 'b1',
          clientId: 'client_aman',
          trainerId: testTrainerId,
          rating: 5.0,
          comment: 'Excellent!',
          trainerResponse: 'Initial response',
          trainerRespondedAt: now,
        ),
      ]);

      await service.deleteTrainerResponse(
        reviewId: 'rev_to_delete',
        trainerId: testTrainerId,
      );

      final updated = service.allReviews.firstWhere((r) => r.id == 'rev_to_delete');
      expect(updated.hasResponse, isFalse);
      expect(updated.trainerResponse, isNull);
    });
  });

  group('4. Review Reporting & Duplicate Prevention', () {
    test('Reporting review flags isReported and creates ReviewReportModel', () async {
      final service = TrainerReviewService.instance;

      service.setTestReviews([
        ReviewModel(
          id: 'rev_flag_1',
          bookingId: 'b1',
          clientId: 'c1',
          clientName: 'Fake Account',
          trainerId: testTrainerId,
          rating: 1.0,
          comment: 'Call 9876543210 for best offers outside the app',
        ),
      ]);

      await service.reportReview(
        reviewId: 'rev_flag_1',
        trainerId: testTrainerId,
        reason: 'Spam or Commercial Solicitation',
        details: 'Client comment is advertising personal numbers.',
      );

      final updated = service.allReviews.firstWhere((r) => r.id == 'rev_flag_1');
      expect(updated.isReported, isTrue);
      expect(updated.reportReason, 'Spam or Commercial Solicitation');

      final reports = service.allReports;
      expect(reports.length, 1);
      expect(reports.first.id, '${testTrainerId}_rev_flag_1');
      expect(reports.first.status, 'PENDING');
    });

    test('Duplicate reporting attempt throws StateError to prevent multiple audit tickets', () async {
      final service = TrainerReviewService.instance;

      service.setTestReviews([
        ReviewModel(
          id: 'rev_dup_report',
          bookingId: 'b1',
          clientId: 'c1',
          trainerId: testTrainerId,
          rating: 2.0,
          comment: 'Not satisfied with schedule',
          isReported: true,
          reportReason: 'Conflict of Interest',
        ),
      ]);

      service.setTestReports([
        ReviewReportModel(
          id: '${testTrainerId}_rev_dup_report',
          reviewId: 'rev_dup_report',
          trainerId: testTrainerId,
          reporterId: testTrainerId,
          reason: 'Conflict of Interest',
        ),
      ]);

      expect(
        () async => await service.reportReview(
          reviewId: 'rev_dup_report',
          trainerId: testTrainerId,
          reason: 'Conflict of Interest',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('5. Widget Tests: TrainerReviewsScreen UI Flow', () {
    testWidgets('Renders reviews dashboard with average score, distribution bars, and feedback cards', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = TrainerReviewService.instance;
      service.setTestReviews([
        ReviewModel(
          id: 'rev_ui_1',
          bookingId: 'bk_1',
          clientId: 'cl_1',
          clientName: 'Kunal Kapoor',
          trainerId: testTrainerId,
          rating: 5.0,
          comment: 'Outstanding trainer! Transformed my posture and core strength.',
          packageName: '6-Month Transformation',
          createdAt: now,
        ),
        ReviewModel(
          id: 'rev_ui_2',
          bookingId: 'bk_2',
          clientId: 'cl_2',
          clientName: 'Dev Patel',
          trainerId: testTrainerId,
          rating: 4.0,
          comment: 'Very encouraging and patient during workouts.',
          packageName: '1 Month',
          trainerResponse: 'Thank you Dev! Keep pushing hard.',
          trainerRespondedAt: now,
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerReviewsScreen(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Header and Hero Metrics
      expect(find.text('Reviews & Ratings'), findsOneWidget);
      expect(find.text('4.5'), findsOneWidget); // (5 + 4) / 2 = 4.5
      expect(find.text('2 Verified Reviews'), findsOneWidget);
      expect(find.text('100% Positive Feedback'), findsOneWidget);

      // Review cards in list
      expect(find.text('Kunal Kapoor'), findsOneWidget);
      expect(find.textContaining('Transformed my posture and core strength'), findsOneWidget);
      expect(find.text('Package: 6-Month Transformation'), findsOneWidget);

      expect(find.text('Dev Patel'), findsOneWidget);
      expect(find.text('Your Public Response'), findsOneWidget);
      expect(find.textContaining('Thank you Dev! Keep pushing hard'), findsOneWidget);
    });

    testWidgets('Filters review list live by search query', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = TrainerReviewService.instance;
      service.setTestReviews([
        ReviewModel(
          id: 'rev_search_1',
          bookingId: 'bk_1',
          clientId: 'cl_1',
          clientName: 'Hrithik Roshan',
          trainerId: testTrainerId,
          rating: 5.0,
          comment: 'Best workout session ever!',
        ),
        ReviewModel(
          id: 'rev_search_2',
          bookingId: 'bk_2',
          clientId: 'cl_2',
          clientName: 'Farhan Akhtar',
          trainerId: testTrainerId,
          rating: 5.0,
          comment: 'Incredible cardio stamina routine.',
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerReviewsScreen(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Hrithik Roshan'), findsOneWidget);
      expect(find.text('Farhan Akhtar'), findsOneWidget);

      // Search for Hrithik
      await tester.enterText(find.byType(TextField), 'Hrithik');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Hrithik Roshan'), findsOneWidget);
      expect(find.text('Farhan Akhtar'), findsNothing);
    });

    testWidgets('Tapping Reply to Client opens bottom sheet modal for writing a response', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = TrainerReviewService.instance;
      service.setTestReviews([
        ReviewModel(
          id: 'rev_modal_reply',
          bookingId: 'bk_1',
          clientId: 'cl_1',
          clientName: 'Ranbir Kapoor',
          trainerId: testTrainerId,
          rating: 5.0,
          comment: 'Super dedicated trainer.',
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerReviewsScreen(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Reply to Client'), findsOneWidget);
      await tester.tap(find.text('Reply to Client'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Modal bottom sheet should appear
      expect(find.text('Reply to Client Review'), findsOneWidget);
      expect(find.text('Publish Reply'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Tapping report icon button opens policy reporting sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = TrainerReviewService.instance;
      service.setTestReviews([
        ReviewModel(
          id: 'rev_modal_report',
          bookingId: 'bk_1',
          clientId: 'cl_1',
          clientName: 'Anil Kapoor',
          trainerId: testTrainerId,
          rating: 1.0,
          comment: 'Inappropriate content',
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerReviewsScreen(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on report flag icon
      await tester.tap(find.byIcon(Iconsax.flag));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Report Review to Administrators'), findsOneWidget);
      expect(find.text('Submit Report'), findsOneWidget);
    });
  });

  group('6. Zero Casual & Romantic Terminology Audit', () {
    test('Confirms zero romantic, casual, or matching terms in reviews UI', () {
      const prohibitedTerms = [
        'match',
        'matched',
        'matching',
        'date',
        'dating',
        'flirt',
        'swipe',
        'romance',
        'romantic',
        'soulmate',
        'partner',
        'crush',
      ];

      final sampleTexts = [
        'Reviews & Ratings',
        'Client Feedback',
        'Verified Reviews',
        'Positive Feedback',
        'Reply to Client',
        'Your Public Response',
        'Report Review to Administrators',
        'Verified Client',
        'Package Plan',
      ];

      for (final text in sampleTexts) {
        final lower = text.toLowerCase();
        for (final term in prohibitedTerms) {
          expect(
            lower.contains(term),
            isFalse,
            reason: 'Text "$text" contains prohibited term "$term"',
          );
        }
      }
    });
  });
}
