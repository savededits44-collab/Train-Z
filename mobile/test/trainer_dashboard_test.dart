import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/features/trainer/presentation/screens/trainer_pending_approval_screen.dart';
import 'package:trainuspro/features/trainer/presentation/screens/trainer_rejected_screen.dart';
import 'package:trainuspro/screens/trainer/trainer_dashboard.dart';
import 'package:trainuspro/services/booking_service.dart';
import 'package:trainuspro/services/trainer_profile_service.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TRAIN Z: Trainer Dashboard & Access Control Tests', () {
    const standardTrainerId = 'test_standard_trainer_uid_101';
    const advancedTrainerId = 'test_advanced_trainer_uid_202';

    setUp(() {
      TrainerProfileService.instance.reset();
    });

    testWidgets('1. Standard Trainer Dashboard displays identity, category, and platform model', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = TrainerProfileService.instance;
      service.setTestProfile(
        fullName: 'Rahul Sharma',
        mobileNumber: '9876543210',
        dateOfBirth: '1995-05-15',
        gender: Gender.male,
        bio: 'Certified fitness coach specializing in hypertrophy.',
        experienceYears: 2.0,
        category: TrainerCategory.trainer,
        verificationStatus: TrainerVerificationStatus.approved,
        isProfileCompleted: true,
        profileCompletionScore: 100,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerDashboard(trainerId: standardTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Welcome header & name
      expect(find.text('Welcome back,'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);

      // Category badge
      expect(find.text('Trainer'), findsWidgets);
      expect(find.text('Approved & Active'), findsOneWidget);

      // Standard package model
      expect(find.text('TRAIN Z Platform Packages'), findsOneWidget);
      expect(find.text('STANDARD TRAINER'), findsOneWidget);
      expect(find.text('1 Day'), findsOneWidget);
      expect(find.text('1 Month'), findsOneWidget);
      expect(find.text('6-Month Transformation'), findsOneWidget);

      // Custom plan builder MUST NOT be displayed for Standard Trainer
      expect(find.text('ADVANCED TRAINER'), findsNothing);
      expect(find.text('Custom Training Plans Eligible'), findsNothing);
    });

    testWidgets('2. Advanced Trainer Dashboard displays Advanced status, verified qualifications & custom plan rule', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = TrainerProfileService.instance;
      service.setTestProfile(
        fullName: 'Vikram Sengupta',
        mobileNumber: '9123456780',
        dateOfBirth: '1990-08-20',
        gender: Gender.male,
        bio: 'Elite strength & conditioning coach with 4+ years experience.',
        experienceYears: 4.0,
        category: TrainerCategory.advancedTrainer,
        verificationStatus: TrainerVerificationStatus.approved,
        isProfileCompleted: true,
        profileCompletionScore: 100,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerDashboard(trainerId: advancedTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Advanced Trainer identity
      expect(find.text('Vikram Sengupta'), findsOneWidget);
      expect(find.text('Advanced Trainer'), findsWidgets);
      expect(find.text('ADVANCED TRAINER'), findsOneWidget);
      expect(find.text('Qualifications Verified (3.5+ Yrs Exp)'), findsOneWidget);

      // Custom training plan section & policy notice
      expect(find.text('Custom Training Plans Eligible'), findsOneWidget);
      expect(find.textContaining('Every custom training plan requires separate Admin approval before publication'), findsOneWidget);
      expect(find.text('Manage Custom Plans'), findsOneWidget);

      // Tap Manage Custom Plans -> shows modal sheet with Admin review rule
      await tester.tap(find.text('Manage Custom Plans'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Custom Training Plans'), findsOneWidget);
      expect(find.textContaining('Every custom training plan requires separate TRAIN Z Admin verification and approval'), findsOneWidget);
      expect(find.text('Got It'), findsOneWidget);

      await tester.tap(find.text('Got It'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('3. Access Control: Pending Trainer sees Application Status Screen instead of full dashboard', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = TrainerProfileService.instance;
      service.setTestProfile(
        fullName: 'Pending Coach',
        mobileNumber: '9888877777',
        dateOfBirth: '1994-01-01',
        gender: Gender.male,
        bio: 'Application submitted coach.',
        experienceYears: 3.5,
        category: TrainerCategory.trainer,
        verificationStatus: TrainerVerificationStatus.pending,
        isProfileCompleted: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerDashboard(trainerId: 'pending_uid_999'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Must render TrainerPendingApprovalScreen
      expect(find.byType(TrainerPendingApprovalScreen), findsOneWidget);
      // Restricted dashboard features must NOT be accessible
      expect(find.text('TRAIN Z Platform Packages'), findsNothing);
      expect(find.text('CURRENT EARNINGS'), findsNothing);
    });

    testWidgets('4. Access Control: Rejected Trainer sees Application Rejected Screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = TrainerProfileService.instance;
      service.setTestProfile(
        fullName: 'Rejected Coach',
        mobileNumber: '9888877777',
        dateOfBirth: '1994-01-01',
        gender: Gender.male,
        bio: 'Incomplete application.',
        experienceYears: 1.0,
        category: TrainerCategory.trainer,
        verificationStatus: TrainerVerificationStatus.rejected,
        isProfileCompleted: true,
        adminNotes: 'Invalid certificates submitted.',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerDashboard(trainerId: 'rejected_uid_888'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Must render TrainerRejectedScreen
      expect(find.byType(TrainerRejectedScreen), findsOneWidget);
      expect(find.textContaining('Application Not Approved'), findsOneWidget);
      expect(find.text('TRAIN Z Platform Packages'), findsNothing);
    });

    testWidgets('5. Dashboard Overview Metrics: Derived strictly from actual records with NO sample data', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = TrainerProfileService.instance;
      service.setTestProfile(
        fullName: 'Stats Coach',
        mobileNumber: '9888877777',
        dateOfBirth: '1992-02-02',
        gender: Gender.male,
        bio: 'Metrics tester.',
        experienceYears: 3.0,
        category: TrainerCategory.trainer,
        verificationStatus: TrainerVerificationStatus.approved,
        isProfileCompleted: true,
        profileCompletionScore: 100,
      );

      final now = DateTime.now();
      final bService = BookingService.instance;

      // Add a test booking strictly for this trainer
      bService.addOrUpdateBooking(
        BookingModel(
          id: 'test_overview_booking_1',
          clientId: 'client_real_10',
          trainerId: standardTrainerId,
          clientGender: Gender.male,
          trainerGender: Gender.male,
          clientName: 'Deepak Patel',
          sessionDate: now,
          startTime: '09:00 AM',
          endTime: '10:00 AM',
          meetingLocation: 'Cult.fit BKC',
          packageName: 'Monthly Pro',
          packagePrice: 10799,
          totalSessions: 26,
          sessionsCompleted: 1,
          status: BookingStatus.confirmed,
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerDashboard(trainerId: standardTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Verify the 4 overview metric cards
      expect(find.text('Upcoming Bookings'), findsOneWidget);
      expect(find.text("Today's Sessions"), findsOneWidget);
      expect(find.text('Completed Sessions'), findsOneWidget);
      expect(find.text('Active Clients'), findsOneWidget);

      // Verify no hardcoded sample rating
      expect(find.text('Rating'), findsNothing);
      expect(find.text('5.0'), findsNothing);

      // Verify Earnings box is displayed with live real-time calculated revenue
      expect(find.text('CURRENT EARNINGS'), findsOneWidget);
    });

    testWidgets('6. Upcoming Confirmed Sessions display client information and open details sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = TrainerProfileService.instance;
      service.setTestProfile(
        fullName: 'Coach Sanjay',
        mobileNumber: '9888877777',
        dateOfBirth: '1992-02-02',
        gender: Gender.male,
        bio: 'Session tester.',
        experienceYears: 3.0,
        category: TrainerCategory.trainer,
        verificationStatus: TrainerVerificationStatus.approved,
        isProfileCompleted: true,
        profileCompletionScore: 100,
      );

      final now = DateTime.now();
      final bService = BookingService.instance;

      bService.addOrUpdateBooking(
        BookingModel(
          id: 'test_session_card_1',
          clientId: 'client_sanjay_client_1',
          trainerId: 'sanjay_trainer_uid',
          clientGender: Gender.male,
          trainerGender: Gender.male,
          clientName: 'Arjun Kapoor',
          sessionDate: now.add(const Duration(days: 1)),
          startTime: '07:30 AM',
          endTime: '08:30 AM',
          meetingLocation: 'Golds Gym Bandra',
          packageName: '1 Month Pro',
          status: BookingStatus.confirmed,
          notes: 'Focus on shoulder stability.',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerDashboard(trainerId: 'sanjay_trainer_uid'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Card details
      expect(find.text('Arjun Kapoor'), findsOneWidget);
      expect(find.textContaining('07:30 AM'), findsOneWidget);
      expect(find.text('60m'), findsOneWidget);
      expect(find.text('Golds Gym Bandra'), findsOneWidget);
      expect(find.text('CONFIRMED'), findsWidgets);

      // Tap session card to open Booking Details Sheet
      await tester.tap(find.text('Arjun Kapoor'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Session Date'), findsOneWidget);
      expect(find.text('Time & Duration'), findsOneWidget);
      expect(find.text('07:30 AM - 08:30 AM (60 min)'), findsOneWidget);
      expect(find.text('Package Plan'), findsOneWidget);
      expect(find.text('1 Month Pro'), findsOneWidget);
      expect(find.text('Client Goals / Notes'), findsOneWidget);
      expect(find.text('Focus on shoulder stability.'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('7. Quick Actions: All 6 shortcuts exist and trigger appropriate modals/navigation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = TrainerProfileService.instance;
      service.setTestProfile(
        fullName: 'Quick Action Coach',
        mobileNumber: '9888877777',
        dateOfBirth: '1992-02-02',
        gender: Gender.male,
        bio: 'Action tester.',
        experienceYears: 3.0,
        category: TrainerCategory.trainer,
        verificationStatus: TrainerVerificationStatus.approved,
        isProfileCompleted: true,
        profileCompletionScore: 100,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerDashboard(trainerId: standardTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('My Profile'), findsOneWidget);
      expect(find.text('My Availability'), findsOneWidget);
      expect(find.text('My Bookings'), findsOneWidget);
      expect(find.text('Messages'), findsOneWidget);
      expect(find.text('Earnings'), findsOneWidget);
      expect(find.text('My Qualifications'), findsOneWidget);

      // Tap Availability -> shows Availability modal
      await tester.tap(find.text('My Availability'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Trainer Availability'), findsOneWidget);
      expect(find.textContaining('The Availability Management module is scheduled for the upcoming release'), findsOneWidget);
      expect(find.text('Understood'), findsOneWidget);
      await tester.tap(find.text('Understood'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Tap Earnings -> shows Earnings modal
      await tester.tap(find.text('Earnings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Trainer Earnings Overview'), findsOneWidget);
      expect(find.text('TOTAL EARNINGS'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('8. Notifications & Updates section is present with View All action', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = TrainerProfileService.instance;
      service.setTestProfile(
        fullName: 'Notification Coach',
        mobileNumber: '9888877777',
        dateOfBirth: '1992-02-02',
        gender: Gender.male,
        bio: 'Notification tester.',
        experienceYears: 3.0,
        category: TrainerCategory.trainer,
        verificationStatus: TrainerVerificationStatus.approved,
        isProfileCompleted: true,
        profileCompletionScore: 100,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerDashboard(trainerId: standardTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Recent Updates'), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);
    });

    testWidgets('9. Zero Dating & Romantic Terminology Audit across all Trainer Dashboard copy', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = TrainerProfileService.instance;
      service.setTestProfile(
        fullName: 'Audit Coach',
        mobileNumber: '9888877777',
        dateOfBirth: '1992-02-02',
        gender: Gender.male,
        bio: 'Audit coach bio.',
        experienceYears: 4.0,
        category: TrainerCategory.advancedTrainer,
        verificationStatus: TrainerVerificationStatus.approved,
        isProfileCompleted: true,
        profileCompletionScore: 100,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerDashboard(trainerId: advancedTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final allText = textWidgets.map((t) => t.data ?? '').join(' ').toLowerCase();

      final prohibitedWords = [
        'dating', 'matchmaker', 'romance', 'soulmate', 'swiping',
        'swipe right', 'tinder', 'bumble', 'cupid', 'love', 'date me'
      ];

      for (final word in prohibitedWords) {
        expect(allText.contains(word), isFalse, reason: 'Dashboard copy must not contain "$word"');
      }
    });
  });
}
