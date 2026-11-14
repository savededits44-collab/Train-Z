import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/features/client/presentation/screens/client_home_screen.dart';
import 'package:trainuspro/screens/onboarding/role_selection_screen.dart';
import 'package:trainuspro/screens/trainer/trainer_dashboard.dart';
import 'package:trainuspro/services/trainer_profile_service.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';
import 'package:trainuspro/splashscreen/splashscreen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TRAIN Z: Complete UI/UX Refinement & Duplicate Audit Tests', () {
    testWidgets('1. Splash Screen: Luxury minimal branding without playful mascot or cartoon clutter', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Brand typography & luxury tagline
      expect(find.textContaining('TRAIN'), findsWidgets);
      expect(find.text('PREMIUM PERSONAL TRAINING'), findsOneWidget);

      // Verify ZERO playful mascot / cartoon elements
      expect(find.text('Start Transformation'), findsNothing);
      expect(find.text('Kettlebell'), findsNothing);

      // Pump enough time to settle pending auth dwell timer
      await tester.pump(const Duration(milliseconds: 2000));
    });

    testWidgets('2. Role Selection Screen: Consistent TRAIN Z branding without legacy naming', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: RoleSelectionScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Choose how you want to use TRAIN Z to tailor your experience.'), findsOneWidget);
      expect(find.textContaining('Trainuspro'), findsNothing);
    });

    testWidgets('3. Client Home Screen: AppBar has zero logout button (logout restricted to Profile)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: ClientHomeScreen(initialTab: 0),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Top AppBar should contain location pill and notification icon, but NEVER a sign out icon
      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);

      final logoutInAppBar = find.descendant(
        of: appBarFinder,
        matching: find.byTooltip('Sign Out'),
      );
      expect(logoutInAppBar, findsNothing);

      // Verify redundant quick actions row is removed
      expect(find.text('My Packages'), findsNothing); // eliminated duplicate quick action card
    });

    testWidgets('4. Trainer Dashboard: Header has zero logout button (logout restricted to Profile)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = TrainerProfileService.instance;
      service.setTestProfile(
        fullName: 'Alex Vance',
        mobileNumber: '9988776655',
        dateOfBirth: '1993-04-12',
        gender: Gender.male,
        bio: 'Certified strength & conditioning coach.',
        experienceYears: 4.0,
        category: TrainerCategory.trainer,
        verificationStatus: TrainerVerificationStatus.approved,
        isProfileCompleted: true,
        profileCompletionScore: 100,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerDashboard(trainerId: 'alex_test_coach_99'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Header should display logo, notifications and avatar
      expect(find.text('Welcome back,'), findsOneWidget);
      expect(find.text('Alex Vance'), findsOneWidget);

      // Header row must NOT contain a logout button tooltip
      expect(find.byTooltip('Sign Out'), findsNothing);
    });
  });
}
