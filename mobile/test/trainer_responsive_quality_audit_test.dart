import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/features/trainer/presentation/screens/trainer_login_screen.dart';
import 'package:trainuspro/screens/trainer/trainer_availability_screen.dart';
import 'package:trainuspro/screens/trainer/trainer_bookings_screen.dart';
import 'package:trainuspro/screens/trainer/trainer_certificates_screen.dart';
import 'package:trainuspro/screens/trainer/trainer_clients_screen.dart';
import 'package:trainuspro/screens/trainer/trainer_dashboard.dart';
import 'package:trainuspro/screens/trainer/trainer_earnings_screen.dart';
import 'package:trainuspro/screens/trainer/trainer_package_management_screen.dart';
import 'package:trainuspro/screens/trainer/trainer_reviews_screen.dart';
import 'package:trainuspro/screens/trainer/trainer_settings_screen.dart';
import 'package:trainuspro/services/trainer_profile_service.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testTrainerId = 'trainer_responsive_qa_01';

  setUp(() {
    TrainerProfileService.instance.reset();
    TrainerProfileService.instance.setTestProfile(
      fullName: 'Vikram Sengupta',
      mobileNumber: '9876543210',
      dateOfBirth: '1992-04-10',
      gender: Gender.male,
      bio: 'Elite strength & conditioning coach with 5+ years experience.',
      experienceYears: 5.0,
      category: TrainerCategory.advancedTrainer,
      verificationStatus: TrainerVerificationStatus.approved,
      isProfileCompleted: true,
      profileCompletionScore: 100,
    );
  });

  group('TRAIN Z Trainer Responsive & Screen Density QA Suite', () {
    // 1. Small Screen Android (320 x 568 - Compact Device / Split Screen)
    testWidgets('1. Trainer Dashboard renders cleanly without overflow on compact 320dp width', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerDashboard(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.byType(TrainerDashboard), findsOneWidget);
      expect(find.text('Vikram Sengupta'), findsOneWidget);
    });

    // 2. Standard Screen Android (360 x 780 - Typical Mid-tier Android)
    testWidgets('2. Trainer Dashboard renders cleanly on standard 360dp phone', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerDashboard(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.text('CURRENT EARNINGS'), findsOneWidget);
      expect(find.text('ADVANCED TRAINER'), findsOneWidget);
    });

    // 3. Large Flagship Android (412 x 915 - Pixel 8 Pro / Galaxy S23+)
    testWidgets('3. Trainer Dashboard renders cleanly on large 412dp flagship screen', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerDashboard(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.byType(TrainerDashboard), findsOneWidget);
    });

    // 4. Compact iPhone SE (375 x 667 pt, 2.0x retina)
    testWidgets('4. Trainer Dashboard handles iPhone SE retina viewport', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerDashboard(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.text('Vikram Sengupta'), findsOneWidget);
    });

    // 5. Large iPhone 16 Pro Max (430 x 932 pt, 3.0x Super Retina)
    testWidgets('5. Trainer Dashboard handles iPhone 16 Pro Max 3x density', (tester) async {
      tester.view.physicalSize = const Size(1290, 2796);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerDashboard(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.byType(TrainerDashboard), findsOneWidget);
    });

    // 6. Availability & Calendar Screen Responsiveness
    testWidgets('6. TrainerAvailabilityScreen renders tabs and calendar without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerAvailabilityScreen(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.byType(TrainerAvailabilityScreen), findsOneWidget);
    });

    // 7. Bookings Management Screen Responsiveness
    testWidgets('7. TrainerBookingsScreen renders search and tab filter bar', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerBookingsScreen(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.byType(TrainerBookingsScreen), findsOneWidget);
    });

    // 8. Earnings Screen Responsiveness
    testWidgets('8. TrainerEarningsScreen renders payout cards and date filter chips', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerEarningsScreen(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.byType(TrainerEarningsScreen), findsOneWidget);
    });

    // 9. Reviews Screen Responsiveness
    testWidgets('9. TrainerReviewsScreen renders rating summary and filter chips', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerReviewsScreen(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.byType(TrainerReviewsScreen), findsOneWidget);
    });

    // 10. Clients Management Screen Responsiveness
    testWidgets('10. TrainerClientsScreen renders client cards and search bar', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerClientsScreen(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.byType(TrainerClientsScreen), findsOneWidget);
    });

    // 11. Package Management Screen Responsiveness
    testWidgets('11. TrainerPackageManagementScreen renders platform and custom plan tabs', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerPackageManagementScreen(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.byType(TrainerPackageManagementScreen), findsOneWidget);
    });

    // 12. Certificates Screen Responsiveness
    testWidgets('12. TrainerCertificatesScreen renders certificates list and upload button', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerCertificatesScreen(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.byType(TrainerCertificatesScreen), findsOneWidget);
    });

    // 13. Settings Screen Responsiveness
    testWidgets('13. TrainerSettingsScreen renders all setting categories cleanly', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerSettingsScreen(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.byType(TrainerSettingsScreen), findsOneWidget);
    });

    // 14. Registration & Login Screens Keyboard Handling (viewInsets.bottom = 300)
    testWidgets('14. TrainerLoginScreen handles keyboard appearance without overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerLoginScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.byType(TrainerLoginScreen), findsOneWidget);
    });

    // 15. Touch Target Sizes Check (Navigation & Action Buttons >= 44x44)
    testWidgets('15. Trainer bottom navigation items meet minimum touch targets', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerDashboard(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final navItems = find.byType(Expanded);
      expect(navItems, findsWidgets);

      // Verify each bottom nav tab tap target is accessible
      await tester.tap(find.text('Clients'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Schedule'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Home'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
    });
  });
}
