import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/errors/app_exceptions.dart';
import 'package:trainuspro/screens/trainer/trainer_account_deletion_screen.dart';
import 'package:trainuspro/screens/trainer/trainer_account_security_screen.dart';
import 'package:trainuspro/screens/trainer/trainer_help_support_screen.dart';
import 'package:trainuspro/screens/trainer/trainer_legal_screen.dart';
import 'package:trainuspro/screens/trainer/trainer_personal_info_screen.dart';
import 'package:trainuspro/screens/trainer/trainer_privacy_documents_screen.dart';
import 'package:trainuspro/screens/trainer/trainer_settings_screen.dart';
import 'package:trainuspro/services/auth_service.dart';
import 'package:trainuspro/services/trainer_account_service.dart';
import 'package:trainuspro/services/trainer_certificate_service.dart';
import 'package:trainuspro/services/trainer_profile_service.dart';
import 'package:trainuspro/shared/models/account_deletion_model.dart';
import 'package:trainuspro/shared/models/trainer_certificate_model.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final accountService = TrainerAccountService.instance;
  final profileService = TrainerProfileService.instance;
  final certService = TrainerCertificateService.instance;
  final authService = AuthService();

  setUp(() {
    accountService.resetForTest();
    certService.clearMockData();
    profileService.setTestProfile(
      fullName: 'Vikram Malhotra',
      mobileNumber: '+919876543210',
      category: TrainerCategory.advancedTrainer,
      verificationStatus: TrainerVerificationStatus.approved,
      bio: 'Elite strength coach with 5 years experience.',
      experienceYears: 5.0,
      gender: Gender.male,
    );
  });

  group('1. Account Deletion Model & Eligibility Tests', () {
    test('AccountDeletionRequestModel serialization and status parsing', () {
      final model = AccountDeletionRequestModel(
        id: 'del_101',
        userId: 'trainer_1',
        reason: 'Relocating overseas',
        status: DeletionRequestStatus.pendingReview,
        preserveFinancialRecords: true,
        preserveBookingHistory: true,
        requestedAt: DateTime(2026, 11, 13, 15, 30),
      );

      final map = model.toMap();
      expect(map['id'], 'del_101');
      expect(map['userId'], 'trainer_1');
      expect(map['status'], 'PENDING_REVIEW');
      expect(map['preserveFinancialRecords'], true);
      expect(map['preserveBookingHistory'], true);

      final reconstructed = AccountDeletionRequestModel.fromMap(map, id: 'del_101');
      expect(reconstructed.id, 'del_101');
      expect(reconstructed.status, DeletionRequestStatus.pendingReview);
      expect(reconstructed.status.displayName, 'Pending Review');
    });

    test('TrainerDeletionEligibilityResult getters reflect blocker states', () {
      const blockedByBookings = TrainerDeletionEligibilityResult(
        canDelete: false,
        activeBookingsCount: 3,
        pendingPayoutsAmount: 0,
        blockerReason: 'Active upcoming sessions',
      );
      expect(blockedByBookings.canDelete, isFalse);
      expect(blockedByBookings.hasActiveBookings, isTrue);
      expect(blockedByBookings.hasPendingPayouts, isFalse);

      const blockedByPayouts = TrainerDeletionEligibilityResult(
        canDelete: false,
        activeBookingsCount: 0,
        pendingPayoutsAmount: 4500,
        blockerReason: 'Pending payouts in processing',
      );
      expect(blockedByPayouts.canDelete, isFalse);
      expect(blockedByPayouts.hasActiveBookings, isFalse);
      expect(blockedByPayouts.hasPendingPayouts, isTrue);

      const eligible = TrainerDeletionEligibilityResult(canDelete: true);
      expect(eligible.canDelete, isTrue);
      expect(eligible.hasActiveBookings, isFalse);
      expect(eligible.hasPendingPayouts, isFalse);
    });
  });

  group('2. TrainerAccountService Business Rules & Security Checks', () {
    test('checkDeletionEligibility reflects configured test eligibility', () async {
      accountService.setTestEligibility(
        const TrainerDeletionEligibilityResult(
          canDelete: false,
          activeBookingsCount: 2,
          blockerReason: 'You have 2 active upcoming training sessions.',
        ),
      );

      final res = await accountService.checkDeletionEligibility('trainer_1');
      expect(res.canDelete, isFalse);
      expect(res.activeBookingsCount, 2);
      expect(res.blockerReason, contains('2 active upcoming'));
    });

    test('requestAccountDeletion throws StateError if trainer is ineligible', () async {
      accountService.setTestEligibility(
        const TrainerDeletionEligibilityResult(
          canDelete: false,
          activeBookingsCount: 1,
          blockerReason: 'Active sessions present.',
        ),
      );

      expect(
        () => accountService.requestAccountDeletion(
          trainerId: 'trainer_1',
          reason: 'Leaving platform',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('requestAccountDeletion records request and preserves audit history when eligible', () async {
      accountService.setTestEligibility(
        const TrainerDeletionEligibilityResult(canDelete: true),
      );

      final req = await accountService.requestAccountDeletion(
        trainerId: 'trainer_1',
        reason: 'Relocating to another city',
      );

      expect(req.userId, 'trainer_1');
      expect(req.preserveFinancialRecords, isTrue);
      expect(req.preserveBookingHistory, isTrue);
      expect(accountService.testDeletionRequests.length, 1);
    });

    test('updatePersonalDetails enforces minimum field length constraints', () async {
      expect(
        () => accountService.updatePersonalDetails(
          trainerId: 'trainer_1',
          displayName: 'A', // too short
          phoneNumber: '+919876543210',
        ),
        throwsArgumentError,
      );

      expect(
        () => accountService.updatePersonalDetails(
          trainerId: 'trainer_1',
          displayName: 'Vikram',
          phoneNumber: '123', // too short
        ),
        throwsArgumentError,
      );

      // Valid update
      await accountService.updatePersonalDetails(
        trainerId: 'trainer_1',
        displayName: 'Vikram Malhotra',
        phoneNumber: '+919876543210',
        gender: Gender.male,
      );
    });
  });

  group('3. AuthService Security & Password Handling', () {
    test('changePassword validates new password length', () async {
      expect(
        () => authService.changePassword(
          currentPassword: 'oldPassword123',
          newPassword: 'short',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('updateEmailAddress validates valid email format', () async {
      expect(
        () => authService.updateEmailAddress('invalid-email'),
        throwsA(isA<AuthException>()),
      );
    });

    test('updatePhoneNumber validates phone length', () async {
      expect(
        () => authService.updatePhoneNumber('1234'),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('4. TrainerSettingsScreen Widget UI Flow', () {
    testWidgets('Renders all organized settings sections and header', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerSettingsScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings & Account'), findsOneWidget);
      expect(find.text('Vikram Malhotra'), findsOneWidget);
      expect(find.text('ADVANCED TRAINER'), findsOneWidget);

      // Section Headers & Tiles
      expect(find.text('Profile & Coaching Details'), findsOneWidget);
      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Professional Profile'), findsOneWidget);
      expect(find.text('Account & Security'), findsNWidgets(2));
      expect(find.text('Notification Preferences'), findsOneWidget);
      expect(find.text('Privacy & Documents'), findsOneWidget);
    });

    testWidgets('Tapping Personal Information pushes TrainerPersonalInfoScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerSettingsScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Personal Information'));
      await tester.pumpAndSettle();

      expect(find.text('Personal Information'), findsWidgets);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
    });

    testWidgets('Tapping Account & Security pushes TrainerAccountSecurityScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerSettingsScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Account & Security tile
      await tester.tap(find.text('Change password, email verification, session security'));
      await tester.pumpAndSettle();

      expect(find.text('Account & Security'), findsWidgets);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);
    });

    testWidgets('Tapping Privacy & Documents pushes TrainerPrivacyDocumentsScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerSettingsScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Privacy & Documents'));
      await tester.pumpAndSettle();

      expect(find.text('Privacy & Certificate Documents'), findsOneWidget);
      expect(find.text('Document Privacy Guarantee'), findsOneWidget);
    });

    testWidgets('Tapping Help & Support pushes TrainerHelpSupportScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerSettingsScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      final target = find.text('Help & Support');
      await tester.scrollUntilVisible(target, 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(target);
      await tester.pumpAndSettle();

      expect(find.byType(TrainerHelpSupportScreen), findsOneWidget);
      expect(find.text('TRAIN Z Coach Support'), findsOneWidget);
      expect(find.text('Frequently Asked Questions'), findsOneWidget);
    });

    testWidgets('Tapping Legal Information pushes TrainerLegalScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerSettingsScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      final target = find.text('Legal Information');
      await tester.scrollUntilVisible(target, 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(target);
      await tester.pumpAndSettle();

      expect(find.byType(TrainerLegalScreen), findsOneWidget);
      expect(find.text('Trainer Service Agreement'), findsOneWidget);
      expect(find.text('Coach Code of Conduct & Safety'), findsOneWidget);
    });

    testWidgets('Tapping Delete pushes TrainerAccountDeletionScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerSettingsScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      final target = find.text('Delete');
      await tester.scrollUntilVisible(target, 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(target);
      await tester.pumpAndSettle();

      expect(find.text('Permanent Account Action'), findsOneWidget);
      expect(find.text('Financial & Audit Record Retention'), findsOneWidget);
    });
  });

  group('5. TrainerPersonalInfoScreen UI Tests', () {
    testWidgets('Renders locked role & category notice and personal fields', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerPersonalInfoScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LOCKED'), findsOneWidget);
      expect(find.text('Advanced Trainer'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Gender'), findsOneWidget);

      final dobFinder = find.text('Date of Birth');
      await tester.scrollUntilVisible(dobFinder, 200, scrollable: find.byType(Scrollable).first);
      expect(dobFinder, findsWidgets);

      final saveBtn = find.text('Save Personal Details');
      await tester.scrollUntilVisible(saveBtn, 300, scrollable: find.byType(Scrollable).first);
      expect(saveBtn, findsOneWidget);
    });
  });

  group('6. TrainerAccountSecurityScreen UI Tests', () {
    testWidgets('Renders password change form and session security info', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerAccountSecurityScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Account & Security'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Current Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);
      expect(find.text('Forgot current password?'), findsOneWidget);
    });
  });

  group('7. TrainerPrivacyDocumentsScreen UI Tests', () {
    testWidgets('Renders privacy guarantee and submitted certificates', (tester) async {
      certService.seedMockCertificates('trainer_1', [
        const TrainerCertificateModel(
          id: 'cert_1',
          trainerId: 'trainer_1',
          certificateName: 'CSCS Elite Strength',
          courseName: 'Strength and Conditioning Specialist',
          issuingOrganization: 'NSCA',
          yearOfCompletion: '2023',
          storagePath: 'certificates/trainer_1/cert_1.pdf',
          fileName: 'cscs_cert.pdf',
          fileSizeBytes: 500 * 1024,
          fileType: 'pdf',
          verificationStatus: CertificateVerificationStatus.verified,
        ),
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerPrivacyDocumentsScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Privacy & Certificate Documents'), findsOneWidget);
      expect(find.text('Document Privacy Guarantee'), findsOneWidget);
      expect(find.text('CSCS Elite Strength'), findsOneWidget);
      expect(find.text('VERIFIED'), findsOneWidget);
      expect(find.text('Upload / Manage'), findsOneWidget);
    });
  });

  group('8. TrainerAccountDeletionScreen UI & Restriction Flow', () {
    testWidgets('Displays restriction alert and disables delete button when ineligible', (tester) async {
      accountService.setTestEligibility(
        const TrainerDeletionEligibilityResult(
          canDelete: false,
          activeBookingsCount: 3,
          pendingPayoutsAmount: 5000,
          blockerReason: 'You have 3 active upcoming training session(s).',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerAccountDeletionScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Account Deletion Restricted'), findsOneWidget);
      expect(find.text('You have 3 active upcoming training session(s).'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      final deleteButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Request Account Deletion'));
      expect(deleteButton.onPressed, isNull); // Disabled!
    });

    testWidgets('Allows deletion request submission when eligible and confirmed', (tester) async {
      accountService.setTestEligibility(
        const TrainerDeletionEligibilityResult(canDelete: true),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerAccountDeletionScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Account Deletion Restricted'), findsNothing);

      // Drag to reveal password field, confirmation checkbox and delete button
      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pumpAndSettle();

      // Enter reauthentication password
      final passwordField = find.byType(TextFormField).last;
      await tester.enterText(passwordField, 'secretPass123');
      await tester.pumpAndSettle();

      // Toggle risk confirmation
      final checkbox = find.byType(CheckboxListTile);
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.widgetWithText(ElevatedButton, 'Request Account Deletion'));
      await tester.pumpAndSettle();

      expect(find.text('Request Submitted'), findsOneWidget);
      expect(find.text('Log Out & Exit'), findsOneWidget);
    });
  });

  group('9. Zero Casual & Dating Terminology Audit', () {
    test('UI strings and settings models contain zero dating, casual, or romantic terms', () {
      final bannedKeywords = [
        'dating',
        'matchmaking',
        'romantic',
        'casual',
        'swipe right',
        'swipe left',
        'flirt',
        'hookup',
        'meet singles',
      ];

      final sampleTexts = [
        'Settings & Account',
        'Personal Information',
        'Professional Profile',
        'Account & Security',
        'Notification Preferences',
        'Privacy & Certificate Documents',
        'Help & Support',
        'Legal Information',
        'Trainer Service Agreement',
        'Coach Code of Conduct & Safety',
        'Request Account Deletion',
      ];

      for (final text in sampleTexts) {
        for (final banned in bannedKeywords) {
          expect(
            text.toLowerCase().contains(banned),
            isFalse,
            reason: 'Banned term "$banned" detected in text: "$text"',
          );
        }
      }
    });
  });
}
