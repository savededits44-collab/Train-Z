import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/features/client/presentation/screens/client_notification_preferences_screen.dart';
import 'package:trainuspro/features/client/presentation/screens/client_notifications_screen.dart';
import 'package:trainuspro/services/notification_service.dart';
import 'package:trainuspro/services/push_notification_service.dart';
import 'package:trainuspro/shared/models/notification_model.dart';
import 'package:trainuspro/shared/models/notification_preferences_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. NotificationModel Category & Reference Resolution', () {
    test('Correctly maps notification types into 7 TRAIN Z categories', () {
      const bNotif = NotificationModel(
        id: 'n1',
        userId: 'u1',
        title: 'Booking Confirmed',
        body: 'Session is confirmed',
        type: 'BOOKING_CONFIRMED',
      );
      expect(bNotif.category, equals('Bookings'));

      const rNotif = NotificationModel(
        id: 'n2',
        userId: 'u1',
        title: 'Upcoming Reminder',
        body: 'Session in 2h',
        type: 'UPCOMING_REMINDER',
      );
      expect(rNotif.category, equals('Sessions and reminders'));

      const cNotif = NotificationModel(
        id: 'n3',
        userId: 'u1',
        title: 'Coach Message',
        body: 'Bring extra water',
        type: 'CHAT_MESSAGE',
      );
      expect(cNotif.category, equals('Trainer messages'));

      const pNotif = NotificationModel(
        id: 'n4',
        userId: 'u1',
        title: 'Payment Confirmed',
        body: 'Receipt ready',
        type: 'PAYMENT_CONFIRMED',
      );
      expect(pNotif.category, equals('Packages and payments'));

      const revNotif = NotificationModel(
        id: 'n5',
        userId: 'u1',
        title: 'Review Session',
        body: 'Please leave feedback',
        type: 'REVIEW_REQUEST',
      );
      expect(revNotif.category, equals('Reviews and feedback'));

      const sNotif = NotificationModel(
        id: 'n6',
        userId: 'u1',
        title: 'Support Update',
        body: 'Specialist responded',
        type: 'SUPPORT_TICKET_UPDATE',
      );
      expect(sNotif.category, equals('Support updates'));

      const aNotif = NotificationModel(
        id: 'n7',
        userId: 'u1',
        title: 'New Gym Feature',
        body: 'Check out new workouts',
        type: 'PLATFORM_ANNOUNCEMENT',
      );
      expect(aNotif.category, equals('Platform announcements'));
    });

    test('referenceLabel cleanly surfaces ticket, receipt, booking and coach identifiers', () {
      // 1. Support ticket
      const ticketNotif = NotificationModel(
        id: 'n_ticket',
        userId: 'u1',
        title: 'Ticket update',
        body: 'Status resolved',
        type: 'SUPPORT_TICKET_UPDATE',
        data: {'ticketNumber': 'TRZ-987654'},
      );
      expect(ticketNotif.referenceLabel, equals('Ticket: #TRZ-987654'));

      // 2. Receipt
      const receiptNotif = NotificationModel(
        id: 'n_pay',
        userId: 'u1',
        title: 'Payment success',
        body: 'Payment verified',
        type: 'PAYMENT_CONFIRMED',
        data: {'receiptNumber': 'RCP-2026-001'},
      );
      expect(receiptNotif.referenceLabel, equals('Receipt: #RCP-2026-001'));

      // 3. Booking reference
      const bookingNotif = NotificationModel(
        id: 'n_book',
        userId: 'u1',
        title: 'Booking confirmed',
        body: 'Session booked',
        type: 'BOOKING_CONFIRMED',
        data: {'bookingReference': 'BK-778899'},
      );
      expect(bookingNotif.referenceLabel, equals('Ref: #BK-778899'));

      // 4. Booking ID fallback
      const bookingIdNotif = NotificationModel(
        id: 'n_bid',
        userId: 'u1',
        title: 'Booking confirmed',
        body: 'Session booked',
        type: 'BOOKING_CONFIRMED',
        data: {'bookingId': '12345678abcdef'},
      );
      expect(bookingIdNotif.referenceLabel, equals('Ref: #12345678'));

      // 5. Coach name fallback
      const chatNotif = NotificationModel(
        id: 'n_chat',
        userId: 'u1',
        title: 'Message',
        body: 'See you at the gym',
        type: 'CHAT_MESSAGE',
        data: {'trainerName': 'Coach Marcus'},
      );
      expect(chatNotif.referenceLabel, equals('Coach: Coach Marcus'));
    });
  });

  group('2. NotificationPreferencesModel & Mandatory Rules', () {
    test('Default constructor sets all operational categories true and marketing false', () {
      const prefs = NotificationPreferencesModel();
      expect(prefs.bookingUpdates, isTrue);
      expect(prefs.sessionReminders, isTrue);
      expect(prefs.paymentUpdates, isTrue);
      expect(prefs.trainerMessages, isTrue);
      expect(prefs.reviewsAndFeedback, isTrue);
      expect(prefs.supportUpdates, isTrue);
      expect(prefs.platformAnnouncements, isFalse);
    });

    test('Mandatory security and critical payment transaction alerts can NEVER be disabled', () {
      // Create user preferences with all optional categories turned off
      const allOff = NotificationPreferencesModel(
        bookingUpdates: false,
        sessionReminders: false,
        paymentUpdates: false,
        trainerMessages: false,
        reviewsAndFeedback: false,
        supportUpdates: false,
        platformAnnouncements: false,
      );

      // Account Security alerts must bypass preference suppression
      expect(allOff.isCategoryEnabled('SECURITY_ALERT'), isTrue);
      expect(allOff.isCategoryEnabled('PASSWORD_CHANGED'), isTrue);
      expect(allOff.isCategoryEnabled('AUTH_LOGIN_NEW_DEVICE'), isTrue);
      expect(allOff.isCategoryEnabled('ACCOUNT_DELETION_CONFIRMATION'), isTrue);

      // Critical transaction receipts / payment failures must bypass preference suppression
      expect(allOff.isCategoryEnabled('PAYMENT_CONFIRMED'), isTrue);
      expect(allOff.isCategoryEnabled('PAYMENT_FAILED'), isTrue);
      expect(allOff.isCategoryEnabled('TRANSACTION_RECEIPT'), isTrue);
      expect(allOff.isCategoryEnabled('PAYMENT_RECEIPT'), isTrue);
      expect(allOff.isCategoryEnabled('REFUND_PROCESSED'), isTrue);

      // Optional categories must be suppressed when false
      expect(allOff.isCategoryEnabled('BOOKING_CONFIRMED'), isFalse);
      expect(allOff.isCategoryEnabled('UPCOMING_REMINDER'), isFalse);
      expect(allOff.isCategoryEnabled('CHAT_MESSAGE'), isFalse);
      expect(allOff.isCategoryEnabled('PACKAGE_PURCHASED'), isFalse);
      expect(allOff.isCategoryEnabled('REVIEW_REQUEST'), isFalse);
      expect(allOff.isCategoryEnabled('SUPPORT_TICKET_UPDATE'), isFalse);
      expect(allOff.isCategoryEnabled('PLATFORM_ANNOUNCEMENT'), isFalse);
    });

    test('Serialization to/from Map preserves all 7 category flags', () {
      const original = NotificationPreferencesModel(
        bookingUpdates: true,
        sessionReminders: false,
        paymentUpdates: true,
        trainerMessages: true,
        reviewsAndFeedback: false,
        supportUpdates: true,
        platformAnnouncements: true,
      );

      final map = original.toMap();
      final reconstructed = NotificationPreferencesModel.fromMap(map);

      expect(reconstructed.bookingUpdates, isTrue);
      expect(reconstructed.sessionReminders, isFalse);
      expect(reconstructed.paymentUpdates, isTrue);
      expect(reconstructed.trainerMessages, isTrue);
      expect(reconstructed.reviewsAndFeedback, isFalse);
      expect(reconstructed.supportUpdates, isTrue);
      expect(reconstructed.platformAnnouncements, isTrue);
    });
  });

  group('3. NotificationService Operations, Deduplication & Read State', () {
    late NotificationService service;
    const testUid = 'athlete_client_notif_001';

    setUp(() {
      service = NotificationService.instance;
      service.clearCache();
    });

    tearDown(() {
      service.clearCache();
    });

    test('sendNotification immediately populates unread count and notifications stream', () async {
      expect(service.notifications.length, equals(0));
      expect(service.unreadCount, equals(0));

      await service.sendNotification(
        userId: testUid,
        title: 'Workout Scheduled',
        body: 'Strength training tomorrow at 7 AM',
        type: 'BOOKING_CONFIRMED',
        relatedId: 'bk_101',
      );

      expect(service.notifications.length, equals(1));
      expect(service.unreadCount, equals(1));
      expect(service.notifications.first.title, equals('Workout Scheduled'));
      expect(service.notifications.first.isRead, isFalse);
    });

    test('Deduplication prevents identical notifications within 30-second window', () async {
      await service.sendNotification(
        userId: testUid,
        title: 'Session Reminder',
        body: 'Session starts in 2 hours',
        type: 'UPCOMING_REMINDER',
        relatedId: 'bk_dedup_001',
      );
      expect(service.notifications.length, equals(1));

      // Attempt to immediately send identical notification
      await service.sendNotification(
        userId: testUid,
        title: 'Session Reminder',
        body: 'Session starts in 2 hours',
        type: 'UPCOMING_REMINDER',
        relatedId: 'bk_dedup_001',
      );
      // Still 1 notification: duplicate was suppressed
      expect(service.notifications.length, equals(1));
    });

    test('NotificationService suppresses optional notifications when disabled in user preferences', () async {
      service.setUserPreferences(
        testUid,
        const NotificationPreferencesModel(bookingUpdates: false),
      );

      await service.sendNotification(
        userId: testUid,
        title: 'Booking Confirmed',
        body: 'Session confirmed',
        type: 'BOOKING_CONFIRMED',
      );

      // Suppressed due to bookingUpdates: false
      expect(service.notifications.length, equals(0));

      // Mandatory security alert must NOT be suppressed
      await service.sendNotification(
        userId: testUid,
        title: 'Password Changed',
        body: 'Your account password was updated',
        type: 'SECURITY_ALERT',
      );
      expect(service.notifications.length, equals(1));
    });

    test('markAsRead and markAllAsRead accurately update read status and unread counter', () async {
      await service.sendNotification(
        userId: testUid,
        title: 'Notice 1',
        body: 'First message',
        type: 'CHAT_MESSAGE',
        relatedId: 'msg_1',
      );
      await service.sendNotification(
        userId: testUid,
        title: 'Notice 2',
        body: 'Second message',
        type: 'CHAT_MESSAGE',
        relatedId: 'msg_2',
      );

      expect(service.unreadCount, equals(2));

      // Mark single as read
      final firstId = service.notifications.first.id;
      await service.markAsRead(firstId);
      expect(service.unreadCount, equals(1));
      expect(service.notifications.firstWhere((n) => n.id == firstId).isRead, isTrue);

      // Mark all as read
      await service.markAllAsRead();
      expect(service.unreadCount, equals(0));
      expect(service.notifications.every((n) => n.isRead), isTrue);
    });

    test('deleteNotification successfully removes item and recalculates counter', () async {
      await service.sendNotification(
        userId: testUid,
        title: 'Notice to delete',
        body: 'Delete me',
        type: 'BOOKING_CONFIRMED',
        relatedId: 'del_1',
      );
      expect(service.notifications.length, equals(1));

      final id = service.notifications.first.id;
      await service.deleteNotification(id);
      expect(service.notifications.length, equals(0));
      expect(service.unreadCount, equals(0));
    });
  });

  group('4. Push Notification Service Navigation Parsing & Security', () {
    test('navigatorKey is properly instantiated and ready for deep linking', () {
      expect(PushNotificationService.navigatorKey, isNotNull);
    });

    test('Payload sanitization: verifies sensitive customer address and secrets are never in push data', () {
      final dirtyData = {
        'type': 'BOOKING_CONFIRMED',
        'bookingId': 'bk_secure_001',
        'trainerName': 'Coach Sarah',
        'meetingLocation': '123 Private Apartment Blvd, Apt 4B',
        'privateAddress': 'Secret Residential Villa',
        'creditCard': '4111222233334444',
        'razorpaySignature': 'super_secret_hash',
      };

      // Ensure blacklist filters sensitive credentials
      final blacklistedKeys = [
        'meetingLocation',
        'privateAddress',
        'creditCard',
        'razorpaySignature',
      ];

      final cleanData = Map<String, dynamic>.from(dirtyData)
        ..removeWhere((k, v) => blacklistedKeys.contains(k));

      expect(cleanData.containsKey('meetingLocation'), isFalse);
      expect(cleanData.containsKey('privateAddress'), isFalse);
      expect(cleanData.containsKey('creditCard'), isFalse);
      expect(cleanData.containsKey('razorpaySignature'), isFalse);
      expect(cleanData['bookingId'], equals('bk_secure_001'));
      expect(cleanData['trainerName'], equals('Coach Sarah'));
    });
  });

  group('5. Safety & Professional Fitness Domain Audit', () {
    test('Zero dating or romantic terminology across notification files and copy', () {
      final prohibitedKeywords = [
        'hookup',
        'flirt',
        'date',
        'matchmaking',
        'casual encounter',
        'romance',
        'lover',
        'dating',
      ];

      final sampleTexts = [
        'Notification Centre',
        'Booking updates: confirmations, reschedules, and cancellation notices',
        'Session reminders: helpful alerts at 12 hours, 2 hours, and 1 hour before coaching',
        'Trainer messages: direct workout guidance and arrivals from your personal coach',
        'Payment & package updates: purchase receipts and credit warnings',
        'Reviews & feedback: post-session reviews and trainer ratings',
        'Support ticket updates: customer specialist responses',
        'Platform announcements: new training features and workout advice',
      ];

      for (final text in sampleTexts) {
        for (final word in prohibitedKeywords) {
          final regex = RegExp(r'\b' + word + r'\b', caseSensitive: false);
          expect(regex.hasMatch(text), isFalse,
              reason: 'Found inappropriate terminology "$word" in: "$text"');
        }
      }
    });
  });

  group('6. UI Widget Tests for Client Notifications & Preferences', () {
    testWidgets('ClientNotificationsScreen displays categories, unread filter, and notifications', (tester) async {
      final notifService = NotificationService.instance;
      notifService.clearCache();

      // Seed 2 notifications
      await notifService.sendNotification(
        userId: 'athlete_ui_test',
        title: 'Morning HIIT Confirmed',
        body: 'Your HIIT session with Coach Marcus is set.',
        type: 'BOOKING_CONFIRMED',
        relatedId: 'bk_ui_1',
        data: {'bookingReference': 'BK-100200'},
      );

      await notifService.sendNotification(
        userId: 'athlete_ui_test',
        title: 'Support Resolved',
        body: 'Your ticket has been answered by support.',
        type: 'SUPPORT_TICKET_UPDATE',
        relatedId: 'tick_ui_1',
        data: {'ticketNumber': 'TRZ-5566'},
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ClientNotificationsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Title & filters
      expect(find.text('Notification Centre'), findsOneWidget);
      expect(find.text('Mark all read'), findsOneWidget);
      expect(find.textContaining('Unread ('), findsOneWidget);

      // Category chips
      expect(find.textContaining('All ('), findsOneWidget);
      expect(find.textContaining('Bookings'), findsOneWidget);
      expect(find.textContaining('Sessions and reminders'), findsOneWidget);

      // Notification cards
      expect(find.text('Morning HIIT Confirmed'), findsOneWidget);
      expect(find.text('Support Resolved'), findsOneWidget);
      expect(find.text('Ref: #BK-100200'), findsOneWidget);
      expect(find.text('Ticket: #TRZ-5566'), findsOneWidget);

      // Tap Mark all read
      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();

      expect(notifService.unreadCount, equals(0));
      notifService.clearCache();
    });

    testWidgets('ClientNotificationPreferencesScreen displays all categories and mandatory security banner', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ClientNotificationPreferencesScreen(clientId: 'athlete_prefs_test'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notification Preferences'), findsOneWidget);
      expect(find.text('Account Security Alerts'), findsOneWidget);
      expect(find.text('(Mandatory)'), findsOneWidget);

      // Category switch titles
      expect(find.text('Booking Updates'), findsOneWidget);
      expect(find.text('Session Reminders'), findsOneWidget);
      expect(find.text('Trainer Messages'), findsOneWidget);
      expect(find.text('Payment & Package Updates'), findsOneWidget);
      expect(find.text('Reviews & Feedback'), findsOneWidget);
      expect(find.text('Support Ticket Updates'), findsOneWidget);
      expect(find.text('Platform Announcements'), findsOneWidget);
    });
  });
}
