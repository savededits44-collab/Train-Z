import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/constants/app_constants.dart';
import 'package:trainuspro/core/utils/support_email_helper.dart';
import 'package:trainuspro/features/client/presentation/screens/client_help_support_screen.dart';
import 'package:trainuspro/screens/trainer/trainer_help_support_screen.dart';

void main() {
  group('Support Email & Team Identity Unit Tests', () {
    test('Official support email constant is trainzsupport@gmail.com', () {
      expect(SupportEmailHelper.officialSupportEmail, equals('trainzsupport@gmail.com'));
      expect(AppConstants.supportEmail, equals('trainzsupport@gmail.com'));
    });

    test('Official support identity is TRAIN Z Support Team', () {
      expect(SupportEmailHelper.officialSupportIdentity, equals('TRAIN Z Support Team'));
      expect(AppConstants.supportTeamIdentity, equals('TRAIN Z Support Team'));
    });

    test('buildSupportEmailUri constructs valid mailto URI with prefilled recipient and subject', () {
      final uri = SupportEmailHelper.buildSupportEmailUri(
        subject: 'TRAIN Z Client Support Request',
      );

      expect(uri.scheme, equals('mailto'));
      expect(uri.path, equals('trainzsupport@gmail.com'));
      expect(uri.queryParameters['subject'], equals('TRAIN Z Client Support Request'));
    });

    test('buildSupportEmailUri includes optional body when provided', () {
      final uri = SupportEmailHelper.buildSupportEmailUri(
        subject: 'General Question',
        body: 'Hello Support Team',
      );

      expect(uri.scheme, equals('mailto'));
      expect(uri.path, equals('trainzsupport@gmail.com'));
      expect(uri.queryParameters['subject'], equals('General Question'));
      expect(uri.queryParameters['body'], equals('Hello Support Team'));
    });
  });

  group('Client Help & Support Email UI Tests', () {
    testWidgets('ClientHelpSupportScreen displays Support Team identity and clickable email', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ClientHelpSupportScreen(
            clientId: 'client_test_123',
            clientName: 'Test Client',
            clientEmail: 'client@test.com',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Section label
      expect(find.text('CONTACT SUPPORT'), findsOneWidget);

      // Support Team identity
      expect(find.text('TRAIN Z Support Team'), findsOneWidget);

      // Email Support label & address
      expect(find.text('Email Support'), findsOneWidget);
      expect(find.text('trainzsupport@gmail.com'), findsOneWidget);

      // Existing options preserved
      expect(find.text('Submit a Support Request'), findsOneWidget);
      expect(find.text('Raise a Request'), findsOneWidget);
      expect(find.text('My Tickets'), findsOneWidget);

      // Tap email support
      final emailFinder = find.text('trainzsupport@gmail.com');
      await tester.scrollUntilVisible(emailFinder, 100, scrollable: find.byType(Scrollable).first);
      await tester.tap(emailFinder);
      await tester.pump();
    });
  });

  group('Trainer Help & Support Email UI Tests', () {
    testWidgets('TrainerHelpSupportScreen displays Support Team identity and clickable email', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerHelpSupportScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Section label
      expect(find.text('Contact Support'), findsOneWidget);

      // Support Team identity & coach badge
      expect(find.text('TRAIN Z Support Team'), findsOneWidget);
      expect(find.text('TRAIN Z Coach Support'), findsOneWidget);

      // Email Support label & address
      expect(find.text('Email Support'), findsOneWidget);
      expect(find.text('trainzsupport@gmail.com'), findsOneWidget);

      // FAQ section preserved
      expect(find.text('Frequently Asked Questions'), findsOneWidget);

      // Tap email support
      final emailFinder = find.text('trainzsupport@gmail.com');
      await tester.tap(emailFinder);
      await tester.pump();
    });
  });
}
