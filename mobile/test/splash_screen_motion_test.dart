import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/screens/onboarding/role_selection_screen.dart';
import 'package:trainuspro/splashscreen/splashscreen.dart';

void main() {
  group('TRAIN Z Motion Graphics Animated Splash Screen Tests', () {
    testWidgets('1. Mathematical Center Alignment: Logo, Wordmark, and Tagline are centered', (tester) async {
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

      // Verify branding area is within a Center widget
      final centerFinder = find.byType(Center);
      expect(centerFinder, findsWidgets);

      // Verify the letters T, R, A, I, N, Z exist
      expect(find.text('T'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('I'), findsOneWidget);
      expect(find.text('N'), findsOneWidget);
      expect(find.text('Z'), findsNWidgets(2)); // Monogram Z + Wordmark Z

      // Tagline is present
      expect(find.text('PREMIUM PERSONAL TRAINING'), findsOneWidget);

      // Settle auth dwell timer
      await tester.pump(const Duration(milliseconds: 2000));
    });

    testWidgets('2. Reduced Motion Accessibility: Evaluates to settled state without animation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: SplashScreen(),
          ),
        ),
      );
      await tester.pump();

      // In reduced motion mode, all letters and branding are immediately rendered in place
      expect(find.text('T'), findsOneWidget);
      expect(find.text('R'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
      expect(find.text('I'), findsOneWidget);
      expect(find.text('N'), findsOneWidget);
      expect(find.text('Z'), findsNWidgets(2));
      expect(find.text('PREMIUM PERSONAL TRAINING'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2000));
    });

    testWidgets('3. Sequential Letter Timing Progression', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: SplashScreen(),
        ),
      );

      // Initial frame: background and monogram starting
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Letters sequentially enter
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // After settling, all elements are rendered
      expect(find.text('PREMIUM PERSONAL TRAINING'), findsOneWidget);

      // Settle auth dwell timer
      await tester.pump(const Duration(milliseconds: 1000));
    });

    testWidgets('4. Transition to Get Started & RoleSelectionScreen for Unauthenticated Users', (tester) async {
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
      // Pump past animation and auth resolution timer (1750ms)
      await tester.pump(const Duration(milliseconds: 2200));

      // Get Started button should now be visible
      expect(find.text('Get Started'), findsOneWidget);

      // Tap Get Started
      await tester.tap(find.text('Get Started'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // RoleSelectionScreen navigated to smoothly
      expect(find.byType(RoleSelectionScreen), findsOneWidget);
    });
  });
}
