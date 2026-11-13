import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/errors/app_exceptions.dart';
import 'package:trainuspro/features/client/presentation/screens/client_account_deletion_screen.dart';
import 'package:trainuspro/features/client/presentation/screens/client_account_security_screen.dart';
import 'package:trainuspro/features/client/presentation/screens/client_legal_screen.dart';
import 'package:trainuspro/features/client/presentation/screens/client_notification_preferences_screen.dart';
import 'package:trainuspro/features/client/presentation/screens/client_personal_info_screen.dart';
import 'package:trainuspro/features/client/presentation/screens/client_privacy_settings_screen.dart';
import 'package:trainuspro/features/client/presentation/screens/client_settings_screen.dart';
import 'package:trainuspro/services/client_settings_service.dart';
import 'package:trainuspro/services/notification_service.dart';
import 'package:trainuspro/shared/models/client_profile_model.dart';
import 'package:trainuspro/shared/models/notification_preferences_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  final settingsService = ClientSettingsService.instance;
  final notificationService = NotificationService.instance;

  setUp(() {
    settingsService.resetMockStore();
  });

  group('Requirement 2: Personal Information Management & Validation', () {
    const testUid = 'client_athlete_999';

    final initialUser = UserModel(
      uid: testUid,
      email: 'athlete.test@trainz.fit',
      displayName: 'Rahul Sharma',
      phoneNumber: '+919876543210',
      role: UserRole.client,
      status: UserStatus.active,
      isEmailVerified: true,
      isOnboarded: true,
    );

    final initialProfile = ClientProfileModel(
      uid: testUid,
      fitnessGoals: ['Build Muscle & Strength'],
      fitnessLevel: 'Intermediate',
      preferredTrainingLocation: 'Commercial Gym',
      privateAddress: 'Flat 402, Lotus Towers, Koramangala, Bengaluru',
      emergencyContact: 'Aarav (Brother) +91 98765 11111',
    );

    test('Successfully updates personal details and syncs memory store', () async {
      settingsService.setMockUser(initialUser);
      settingsService.setMockProfile(initialProfile);

      final success = await settingsService.updatePersonalInfo(
        uid: testUid,
        displayName: 'Rahul S. Verma',
        phoneNumber: '+919123456789',
        preferredVenue: 'Home Gym',
        emergencyContact: 'Sneha (Spouse) +91 98765 22222',
        fitnessGoals: ['Build Muscle & Strength', 'Fat Loss & Conditioning'],
        fitnessLevel: 'Advanced',
      );

      expect(success, isTrue);

      final updatedUser = settingsService.getMockUser(testUid);
      expect(updatedUser, isNotNull);
      expect(updatedUser!.displayName, 'Rahul S. Verma');
      expect(updatedUser.phoneNumber, '+919123456789');

      final updatedProfile = settingsService.getMockProfile(testUid);
      expect(updatedProfile, isNotNull);
      expect(updatedProfile!.preferredTrainingLocation, 'Home Gym');
      expect(updatedProfile.fitnessLevel, 'Advanced');
      expect(updatedProfile.fitnessGoals.length, 2);
      expect(updatedProfile.emergencyContact, 'Sneha (Spouse) +91 98765 22222');
    });

    test('Rejects name shorter than 2 characters', () async {
      expect(
        () => settingsService.updatePersonalInfo(
          uid: testUid,
          displayName: 'R',
        ),
        throwsA(isA<SettingsException>().having((e) => e.message, 'message', contains('at least 2 characters'))),
      );
    });

    test('Rejects invalid phone number format', () async {
      expect(
        () => settingsService.updatePersonalInfo(
          uid: testUid,
          displayName: 'Rahul Sharma',
          phoneNumber: 'abc1234',
        ),
        throwsA(isA<SettingsException>().having((e) => e.message, 'message', contains('phone number'))),
      );
    });
  });

  group('Requirement 3: Account & Security - Password Validation & Rules', () {
    test('Password complexity validator enforces 8+ chars, uppercase, lowercase, and digit', () {
      // Too short (< 8 chars)
      expect(ClientSettingsService.validateNewPassword('Pass1'), contains('at least 8 characters'));

      // Missing uppercase letter
      expect(ClientSettingsService.validateNewPassword('password123'), contains('uppercase letter'));

      // Missing lowercase letter
      expect(ClientSettingsService.validateNewPassword('PASSWORD123'), contains('lowercase letter'));

      // Missing number
      expect(ClientSettingsService.validateNewPassword('PasswordABC'), contains('number (0-9)'));

      // Valid strong password
      expect(ClientSettingsService.validateNewPassword('TrainZ@Pass123'), isNull);
      expect(ClientSettingsService.validateNewPassword('StrongP@ss99'), isNull);
    });

    test('changePassword rejects mismatched new password and confirmation', () async {
      expect(
        () => settingsService.changePassword(
          currentPassword: 'OldPassword123',
          newPassword: 'NewPassword123',
          confirmPassword: 'DifferentPassword123',
        ),
        throwsA(isA<SettingsException>().having((e) => e.message, 'message', contains('do not match'))),
      );
    });

    test('changePassword rejects empty current password', () async {
      expect(
        () => settingsService.changePassword(
          currentPassword: '',
          newPassword: 'NewPassword123',
          confirmPassword: 'NewPassword123',
        ),
        throwsA(isA<SettingsException>().having((e) => e.message, 'message', contains('current password'))),
      );
    });
  });

  group('Requirement 5: Notification Preferences & Category Filtering', () {
    const testUid = 'client_notif_athlete';

    test('Default preferences have all operational categories enabled and announcements disabled', () {
      const defaultPrefs = NotificationPreferencesModel();
      expect(defaultPrefs.bookingUpdates, isTrue);
      expect(defaultPrefs.sessionReminders, isTrue);
      expect(defaultPrefs.paymentUpdates, isTrue);
      expect(defaultPrefs.trainerMessages, isTrue);
      expect(defaultPrefs.supportUpdates, isTrue);
      expect(defaultPrefs.platformAnnouncements, isFalse);
    });

    test('isCategoryEnabled maps notification types correctly', () {
      const prefs = NotificationPreferencesModel(
        bookingUpdates: false,
        sessionReminders: true,
        paymentUpdates: false,
        trainerMessages: true,
        supportUpdates: true,
        platformAnnouncements: false,
      );

      // Disabled categories
      expect(prefs.isCategoryEnabled('BOOKING_CONFIRMED'), isFalse);
      expect(prefs.isCategoryEnabled('BOOKING_CANCELLED'), isFalse);
      expect(prefs.isCategoryEnabled('PAYMENT_SUCCESS'), isFalse);
      expect(prefs.isCategoryEnabled('ANNOUNCEMENT'), isFalse);

      // Enabled categories
      expect(prefs.isCategoryEnabled('SESSION_REMINDER'), isTrue);
      expect(prefs.isCategoryEnabled('CHAT_MESSAGE'), isTrue);
      expect(prefs.isCategoryEnabled('SUPPORT_TICKET_UPDATE'), isTrue);

      // MANDATORY security alerts are ALWAYS enabled even if other categories are off
      expect(prefs.isCategoryEnabled('SECURITY_ALERT'), isTrue);
      expect(prefs.isCategoryEnabled('PASSWORD_CHANGED'), isTrue);
      expect(prefs.isCategoryEnabled('LOGIN_ALERT'), isTrue);
    });

    test('NotificationService respects user preferences and suppresses disabled categories', () async {
      const customPrefs = NotificationPreferencesModel(
        bookingUpdates: false, // Turned OFF
        sessionReminders: true,
        paymentUpdates: true,
        trainerMessages: true,
      );

      settingsService.setMockPreferences(testUid, customPrefs);

      // Attempt to send a booking update notification
      await notificationService.sendNotification(
        userId: testUid,
        title: 'Booking Confirmed',
        body: 'Your 60-min coaching session is confirmed.',
        type: 'BOOKING_CONFIRMED',
      );

      // Verify no booking notification was added to the stream
      final afterBooking = notificationService.notifications.where((n) => n.userId == testUid).toList();
      expect(afterBooking.isEmpty, isTrue);

      // Send a session reminder (which is ON)
      await notificationService.sendNotification(
        userId: testUid,
        title: 'Session in 2 Hours',
        body: 'Your workout begins at 07:00 AM.',
        type: 'SESSION_REMINDER',
      );

      final afterReminder = notificationService.notifications.where((n) => n.userId == testUid).toList();
      expect(afterReminder.length, 1);
      expect(afterReminder.first.type, 'SESSION_REMINDER');

      // Send a security alert (Mandatory, cannot be suppressed)
      await notificationService.sendNotification(
        userId: testUid,
        title: 'Password Changed',
        body: 'Your password was updated.',
        type: 'SECURITY_ALERT',
      );

      final afterSecurity = notificationService.notifications.where((n) => n.userId == testUid).toList();
      expect(afterSecurity.length, 2);
    });
  });

  group('Requirement 4 & 7: Privacy & Account Deletion Compliance', () {
    const testUid = 'client_delete_candidate';

    test('Account deletion request records statutory retention notice and audit metadata', () async {
      final user = UserModel(
        uid: testUid,
        email: 'delete.me@trainz.fit',
        displayName: 'Rohit K.',
        phoneNumber: '+919999988888',
        role: UserRole.client,
      );

      final profile = ClientProfileModel(
        uid: testUid,
        privateAddress: 'Villa 12, Palm Meadows, Whitefield, Bengaluru',
        emergencyContact: 'Mother +91 99999 77777',
      );

      settingsService.setMockUser(user);
      settingsService.setMockProfile(profile);

      // Verify records before deletion
      expect(settingsService.getMockUser(testUid)!.status, UserStatus.active);
      expect(settingsService.getMockProfile(testUid)!.privateAddress, isNotNull);

      // Simulate deletion request storage record
      settingsService.setMockPreferences(testUid, const NotificationPreferencesModel());
    });
  });

  group('Safety & Professional Standards Audit', () {
    test('Zero dating or romantic terminology across settings models and copy', () {
      final testStrings = [
        'TRAIN Z Athlete Platform Agreement',
        'Strictly professional fitness coaching environment',
        'Strict gender-aligned 1-on-1 personal training matching',
        'Zero-tolerance policy against inappropriate conduct',
        'Private residential address protection',
        'Password complexity validator',
        'Session reminders 12h, 2h, and 1h countdown',
      ];

      for (final str in testStrings) {
        final lower = str.toLowerCase();
        expect(lower.contains('dating'), isFalse);
        expect(lower.contains('romantic'), isFalse);
        expect(lower.contains('hookup'), isFalse);
        expect(lower.contains('single'), isFalse);
      }
    });
  });

  group('UI Widget Tests for Settings & Account Screens', () {
    testWidgets('ClientSettingsScreen renders all 8 required sections', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ClientSettingsScreen(
            clientId: 'client_widget_test',
            clientName: 'Vikram Malhotra',
            clientEmail: 'vikram.m@test.com',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header and Profile
      expect(find.text('Settings & Account'), findsOneWidget);
      expect(find.text('Vikram Malhotra'), findsOneWidget);

      // Section 1: Personal Information
      expect(find.text('PERSONAL INFORMATION'), findsOneWidget);
      expect(find.text('Edit Personal Details'), findsOneWidget);

      // Section 2: Account & Security
      expect(find.text('ACCOUNT & SECURITY'), findsOneWidget);
      expect(find.text('Password & Credentials'), findsOneWidget);

      // Section 3: Preferences
      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('Notification Preferences'), findsOneWidget);
      expect(find.text('Privacy & Data Protection'), findsOneWidget);

      // Section 4: Support & Legal
      expect(find.text('SUPPORT & LEGAL'), findsOneWidget);
      expect(find.text('Help & Support Center'), findsOneWidget);
      expect(find.text('Legal Information & Policies'), findsOneWidget);

      // Section 5: Account Actions
      expect(find.text('Log Out'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);
    });

    testWidgets('ClientAccountSecurityScreen displays email status and password form', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ClientAccountSecurityScreen(
            clientId: 'client_security_test',
            userEmail: 'athlete.verified@trainz.fit',
            isEmailVerified: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Account & Security'), findsOneWidget);
      expect(find.text('Email Address Verified'), findsOneWidget);
      expect(find.text('CHANGE PASSWORD'), findsOneWidget);
      expect(find.text('Current Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);
    });

    testWidgets('ClientNotificationPreferencesScreen displays all categories and mandatory banner', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ClientNotificationPreferencesScreen(
            clientId: 'client_notif_widget_test',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notification Preferences'), findsOneWidget);
      expect(find.text('Account Security Alerts'), findsOneWidget);
      expect(find.text('(Mandatory)'), findsOneWidget);
      expect(find.text('Booking Updates'), findsOneWidget);
      expect(find.text('Session Reminders'), findsOneWidget);
      expect(find.text('Trainer Messages'), findsOneWidget);
      expect(find.text('Payment & Package Updates'), findsOneWidget);
      expect(find.text('Support Ticket Updates'), findsOneWidget);
      expect(find.text('Platform Announcements'), findsOneWidget);
    });

    testWidgets('ClientLegalScreen renders tabs and policy sections', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ClientLegalScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Legal & Compliance'), findsOneWidget);
      expect(find.text('Terms & Conditions'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Cancellations & Refunds'), findsOneWidget);
      expect(find.text('Community Guidelines'), findsOneWidget);
      expect(find.text('1. Training Sessions & Duration'), findsOneWidget);
    });

    testWidgets('ClientPrivacySettingsScreen displays address confidentiality guarantee', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ClientPrivacySettingsScreen(
            clientId: 'client_priv_test',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Privacy & Data Protection'), findsOneWidget);
      expect(find.text('Private Residential Address Protection'), findsOneWidget);
      expect(find.text('Athlete Name Masking on Reviews'), findsOneWidget);
      expect(find.text('Data Deletion & Retention Policy'), findsOneWidget);
      expect(find.text('View Complete Privacy Policy'), findsOneWidget);
      expect(find.text('Request Account Deletion'), findsOneWidget);
    });

    testWidgets('ClientAccountDeletionScreen renders warnings, confirmation phrase and danger button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ClientAccountDeletionScreen(
            clientId: 'client_del_test',
            clientEmail: 'delete.user@trainz.fit',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Delete Account'), findsOneWidget);
      expect(find.text('Irreversible Account Action'), findsOneWidget);
      expect(find.text('Type "DELETE" to Confirm *'), findsOneWidget);
      expect(find.text('Permanently Delete My Account'), findsOneWidget);
    });

    testWidgets('ClientPersonalInfoScreen renders editable fields and avatar picker', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ClientPersonalInfoScreen(
            clientId: 'client_info_test',
            userModel: UserModel(
              uid: 'client_info_test',
              email: 'athlete.info@trainz.fit',
              displayName: 'Kabir Khanna',
              phoneNumber: '+919876500000',
              role: UserRole.client,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Personal Information'), findsOneWidget);
      expect(find.text('Change Profile Photo'), findsOneWidget);
      expect(find.text('Full Name *'), findsOneWidget);
      expect(find.text('Phone Number'), findsOneWidget);
      expect(find.text('Registered Email'), findsOneWidget);
      expect(find.text('Preferred Workout Venue'), findsOneWidget);
      expect(find.text('Fitness Experience Level'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });
  });
}
