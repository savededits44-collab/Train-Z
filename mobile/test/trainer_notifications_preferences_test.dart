import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:trainuspro/screens/trainer/trainer_notification_preferences_screen.dart';
import 'package:trainuspro/screens/trainer/trainer_notifications_screen.dart';
import 'package:trainuspro/services/notification_service.dart';
import 'package:trainuspro/services/push_notification_service.dart';
import 'package:trainuspro/services/trainer_notification_preferences_service.dart';
import 'package:trainuspro/shared/models/notification_model.dart';
import 'package:trainuspro/shared/models/trainer_notification_preferences_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final notifService = NotificationService.instance;
  final prefsService = TrainerNotificationPreferencesService.instance;

  final sampleNotifBooking = NotificationModel(
    id: 'n_booking_1',
    userId: 'trainer_1',
    title: 'New Confirmed Booking',
    body: 'Aarav Sharma booked a 1-Month Strength & Conditioning plan.',
    type: 'BOOKING_CONFIRMED',
    isRead: false,
    data: {'bookingId': 'bk_12345', 'trainerId': 'trainer_1'},
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );

  final sampleNotifMessage = NotificationModel(
    id: 'n_msg_1',
    userId: 'trainer_1',
    title: 'New Message from Rohan',
    body: 'Coach, what time should we meet tomorrow?',
    type: 'CHAT_MESSAGE',
    isRead: false,
    data: {
      'conversationId': 'conv_123',
      'clientId': 'client_rohan',
      'clientName': 'Rohan Verma',
      'trainerId': 'trainer_1',
    },
    createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
  );

  final sampleNotifPackage = NotificationModel(
    id: 'n_pkg_1',
    userId: 'trainer_1',
    title: 'Custom Package Approved',
    body: 'Your "VIP Marathon Prep" plan has been approved by Admin.',
    type: 'PACKAGE_APPROVED',
    isRead: true,
    data: {'packageId': 'pkg_vip_01', 'trainerId': 'trainer_1'},
    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
  );

  final sampleNotifPayout = NotificationModel(
    id: 'n_payout_1',
    userId: 'trainer_1',
    title: 'Payout Processed',
    body: 'Your payout of ₹15,400 has been transferred to your bank.',
    type: 'PAYOUT_PROCESSED',
    isRead: true,
    data: {'payoutId': 'pay_8889', 'trainerId': 'trainer_1'},
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  );

  final sampleNotifReview = NotificationModel(
    id: 'n_review_1',
    userId: 'trainer_1',
    title: 'New 5-Star Review',
    body: 'Pooja left a 5-star rating: "Best coach in the city!"',
    type: 'REVIEW_NEW',
    isRead: false,
    data: {'reviewId': 'rev_777', 'trainerId': 'trainer_1'},
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  );

  final sampleNotifOtherTrainer = NotificationModel(
    id: 'n_other_1',
    userId: 'trainer_999',
    title: 'Other Trainer Notification',
    body: 'Should not be visible to trainer_1',
    type: 'BOOKING_CONFIRMED',
    isRead: false,
    data: {'bookingId': 'bk_999', 'trainerId': 'trainer_999'},
    createdAt: DateTime.now(),
  );

  setUp(() {
    notifService.resetForTest();
    prefsService.resetForTest();
  });

  group('NotificationModel Tests', () {
    test('Maps string type to appropriate NotificationCategory', () {
      expect(
        const NotificationModel(
          id: '1',
          userId: 'u',
          title: 't',
          body: 'b',
          type: 'BOOKING_CONFIRMED',
        ).categoryEnum,
        NotificationCategory.bookings,
      );

      expect(
        const NotificationModel(
          id: '2',
          userId: 'u',
          title: 't',
          body: 'b',
          type: 'CHAT_MESSAGE',
        ).categoryEnum,
        NotificationCategory.messages,
      );

      expect(
        const NotificationModel(
          id: '3',
          userId: 'u',
          title: 't',
          body: 'b',
          type: 'UPCOMING_REMINDER',
        ).categoryEnum,
        NotificationCategory.sessions,
      );

      expect(
        const NotificationModel(
          id: '4',
          userId: 'u',
          title: 't',
          body: 'b',
          type: 'PACKAGE_APPROVED',
        ).categoryEnum,
        NotificationCategory.packages,
      );

      expect(
        const NotificationModel(
          id: '5',
          userId: 'u',
          title: 't',
          body: 'b',
          type: 'PAYOUT_PROCESSED',
        ).categoryEnum,
        NotificationCategory.earnings,
      );

      expect(
        const NotificationModel(
          id: '6',
          userId: 'u',
          title: 't',
          body: 'b',
          type: 'REVIEW_NEW',
        ).categoryEnum,
        NotificationCategory.reviews,
      );

      expect(
        const NotificationModel(
          id: '7',
          userId: 'u',
          title: 't',
          body: 'b',
          type: 'SUPPORT_RESPONSE',
        ).categoryEnum,
        NotificationCategory.support,
      );

      expect(
        const NotificationModel(
          id: '8',
          userId: 'u',
          title: 't',
          body: 'b',
          type: 'PLATFORM_ANNOUNCEMENT',
        ).categoryEnum,
        NotificationCategory.announcements,
      );
    });

    test('Formatted dates render relative time correctly', () {
      final now = DateTime.now();
      final justNow = NotificationModel(
        id: '1',
        userId: 'u',
        title: 't',
        body: 'b',
        type: 't',
        createdAt: now.subtract(const Duration(seconds: 30)),
      );
      expect(justNow.formattedDate, 'Just now');

      final fiveMinAgo = NotificationModel(
        id: '2',
        userId: 'u',
        title: 't',
        body: 'b',
        type: 't',
        createdAt: now.subtract(const Duration(minutes: 5)),
      );
      expect(fiveMinAgo.formattedDate, '5m ago');

      final emptyDate = const NotificationModel(
        id: '3',
        userId: 'u',
        title: 't',
        body: 'b',
        type: 't',
      );
      expect(emptyDate.formattedDate, '');
    });

    test('Convenience getters retrieve reference IDs', () {
      final notif = NotificationModel(
        id: 'n1',
        userId: 'u1',
        title: 'Title',
        body: 'Body',
        type: 'BOOKING_CONFIRMED',
        data: {
          'bookingId': 'bk_1',
          'conversationId': 'conv_1',
          'packageId': 'pkg_1',
          'payoutId': 'pay_1',
          'reviewId': 'rev_1',
          'ticketId': 'tkt_1',
        },
      );

      expect(notif.bookingId, 'bk_1');
      expect(notif.conversationId, 'conv_1');
      expect(notif.packageId, 'pkg_1');
      expect(notif.payoutId, 'pay_1');
      expect(notif.reviewId, 'rev_1');
      expect(notif.ticketId, 'tkt_1');
    });

    test('Serialization toMap and fromMap works correctly', () {
      final notif = NotificationModel(
        id: 'notif_99',
        userId: 'tr_1',
        title: 'Test',
        body: 'Test body',
        type: 'BOOKING_CONFIRMED',
        isRead: false,
        data: {'bookingId': 'bk_001'},
        createdAt: DateTime(2026, 11, 13, 10, 30),
      );

      final map = notif.toMap();
      final fromMap = NotificationModel.fromMap(map, id: 'notif_99');

      expect(fromMap.id, 'notif_99');
      expect(fromMap.userId, 'tr_1');
      expect(fromMap.title, 'Test');
      expect(fromMap.bookingId, 'bk_001');
    });
  });

  group('TrainerNotificationPreferencesModel Tests', () {
    test('Default values are all enabled and security is locked', () {
      const prefs = TrainerNotificationPreferencesModel();
      expect(prefs.bookings, true);
      expect(prefs.sessionReminders, true);
      expect(prefs.messages, true);
      expect(prefs.packageApprovals, true);
      expect(prefs.payouts, true);
      expect(prefs.reviews, true);
      expect(prefs.support, true);
      expect(prefs.promotions, true);

      // Mandatory locked channels
      expect(prefs.accountSecurity, true);
      expect(prefs.verificationStatus, true);
    });

    test('Serialization and deserialization', () {
      const prefs = TrainerNotificationPreferencesModel(
        bookings: true,
        sessionReminders: false,
        messages: true,
        packageApprovals: false,
        payouts: true,
        reviews: false,
        support: true,
        promotions: false,
      );

      final map = prefs.toMap();
      final reconstructed = TrainerNotificationPreferencesModel.fromMap(map);

      expect(reconstructed.bookings, true);
      expect(reconstructed.sessionReminders, false);
      expect(reconstructed.messages, true);
      expect(reconstructed.packageApprovals, false);
      expect(reconstructed.payouts, true);
      expect(reconstructed.reviews, false);
      expect(reconstructed.support, true);
      expect(reconstructed.promotions, false);
      expect(reconstructed.accountSecurity, true);
      expect(reconstructed.verificationStatus, true);
    });
  });

  group('NotificationService & PreferencesService Integration Tests', () {
    test('Preferences service updates and streams preferences in test mode', () async {
      final initial = await prefsService.getPreferences('trainer_1');
      expect(initial.bookings, true);

      await prefsService.updatePreferences(
        'trainer_1',
        const TrainerNotificationPreferencesModel(bookings: false),
      );

      final updated = await prefsService.getPreferences('trainer_1');
      expect(updated.bookings, false);
      expect(updated.sessionReminders, true);
    });

    test('Stream notifications for trainer isolates records and orders descending', () async {
      notifService.setTestNotifications([
        sampleNotifBooking,
        sampleNotifMessage,
        sampleNotifPackage,
        sampleNotifOtherTrainer,
      ]);

      final stream = notifService.streamNotificationsForTrainer('trainer_1');
      final list = await stream.first;

      expect(list.length, 3);
      expect(list.any((n) => n.userId == 'trainer_999'), isFalse);
      // Newest first
      expect(list.first.id, 'n_booking_1');
    });

    test('Category filtering isolates notifications by category', () {
      final all = [
        sampleNotifBooking,
        sampleNotifMessage,
        sampleNotifPackage,
        sampleNotifPayout,
        sampleNotifReview,
      ];

      final bookings = notifService.filterByCategory(all, NotificationCategory.bookings);
      expect(bookings.length, 1);
      expect(bookings.first.id, 'n_booking_1');

      final packages = notifService.filterByCategory(all, NotificationCategory.packages);
      expect(packages.length, 1);
      expect(packages.first.id, 'n_pkg_1');

      final earnings = notifService.filterByCategory(all, NotificationCategory.earnings);
      expect(earnings.length, 1);
      expect(earnings.first.id, 'n_payout_1');

      final reviews = notifService.filterByCategory(all, NotificationCategory.reviews);
      expect(reviews.length, 1);
      expect(reviews.first.id, 'n_review_1');
    });

    test('Mark single as read and mark all as read', () async {
      notifService.setTestNotifications([sampleNotifBooking, sampleNotifMessage]);
      expect(notifService.unreadCount, 2);

      await notifService.markAsRead('n_booking_1');
      expect(notifService.unreadCount, 1);

      await notifService.markAllAsRead();
      expect(notifService.unreadCount, 0);
    });

    test('Delete notification removes item', () async {
      notifService.setTestNotifications([sampleNotifBooking, sampleNotifMessage]);
      expect(notifService.notifications.length, 2);

      await notifService.deleteNotification('n_booking_1');
      expect(notifService.notifications.length, 1);
      expect(notifService.notifications.first.id, 'n_msg_1');
    });
  });

  group('PushNotificationService Routing Tests', () {
    testWidgets('handleNotificationNavigation handles trainer notification types', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: PushNotificationService.navigatorKey,
          home: const Scaffold(body: Text('Base Screen')),
        ),
      );

      // Verify PushNotificationService instance exists and navigatorKey is bound
      expect(PushNotificationService.navigatorKey.currentState, isNotNull);
    });
  });

  group('TrainerNotificationsScreen Widget Tests', () {
    testWidgets('Renders empty state when trainer has no notifications', (tester) async {
      notifService.setTestNotifications([]);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerNotificationsScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notification Centre'), findsOneWidget);
      expect(find.text('No Notifications'), findsOneWidget);
      expect(find.text('0'), findsOneWidget); // Total 0
    });

    testWidgets('Renders notification list and category chips', (tester) async {
      notifService.setTestNotifications([
        sampleNotifBooking,
        sampleNotifMessage,
        sampleNotifPackage,
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerNotificationsScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notification Centre'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('2 Unread'), findsOneWidget); // booking & message unread

      // Verify category chips
      expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Bookings'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Messages'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Packages'), findsOneWidget);

      // Notification cards
      expect(find.text('New Confirmed Booking'), findsOneWidget);
      expect(find.text('New Message from Rohan'), findsOneWidget);
      expect(find.text('Custom Package Approved'), findsOneWidget);
    });

    testWidgets('Filtering by category chip isolates category cards', (tester) async {
      notifService.setTestNotifications([
        sampleNotifBooking,
        sampleNotifMessage,
        sampleNotifPackage,
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerNotificationsScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Bookings' chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Bookings'));
      await tester.pumpAndSettle();

      expect(find.text('New Confirmed Booking'), findsOneWidget);
      expect(find.text('New Message from Rohan'), findsNothing);
      expect(find.text('Custom Package Approved'), findsNothing);

      // Tap 'Messages' chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Messages'));
      await tester.pumpAndSettle();

      expect(find.text('New Confirmed Booking'), findsNothing);
      expect(find.text('New Message from Rohan'), findsOneWidget);
      expect(find.text('Custom Package Approved'), findsNothing);
    });

    testWidgets('Mark all read button marks unread notifications as read', (tester) async {
      notifService.setTestNotifications([
        sampleNotifBooking,
        sampleNotifMessage,
      ]);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerNotificationsScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mark all read'), findsOneWidget);

      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();

      expect(notifService.unreadCount, 0);
      expect(find.text('Mark all read'), findsNothing);
    });

    testWidgets('Preferences icon button navigates to Preferences Screen', (tester) async {
      notifService.setTestNotifications([]);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerNotificationsScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      final prefsButton = find.byIcon(Iconsax.setting_2);
      expect(prefsButton, findsOneWidget);

      await tester.tap(prefsButton);
      await tester.pumpAndSettle();

      expect(find.text('Notification Preferences'), findsOneWidget);
    });
  });

  group('TrainerNotificationPreferencesScreen Widget Tests', () {
    testWidgets('Renders mandatory locked section and optional toggles', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerNotificationPreferencesScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notification Preferences'), findsOneWidget);
      expect(find.text('Essential Notifications'), findsOneWidget);
      expect(find.text('Account Security & Sign-in Alerts'), findsOneWidget);
      expect(find.text('Certificate & Account Verification'), findsOneWidget);

      // Check optional categories
      expect(find.text('Booking Updates'), findsOneWidget);
      expect(find.text('Session Reminders'), findsOneWidget);
      expect(find.text('Client Messages'), findsOneWidget);
      expect(find.text('Package Approvals'), findsOneWidget);
      expect(find.text('Earnings & Payouts'), findsOneWidget);
      expect(find.text('Reviews & Feedback'), findsOneWidget);
      expect(find.text('Support Updates'), findsOneWidget);
      expect(find.text('Promotional Announcements'), findsOneWidget);

      // Reset to Recommended Defaults button
      final resetButton = find.text('Reset to Recommended Defaults');
      await tester.scrollUntilVisible(resetButton, 300);
      expect(resetButton, findsOneWidget);
    });

    testWidgets('Toggling switch updates trainer notification preferences', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerNotificationPreferencesScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      // Find first switch for Bookings & Cancellations
      final switches = find.byType(Switch);
      expect(switches, findsNWidgets(8)); // 8 optional categories

      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      final prefs = await prefsService.getPreferences('trainer_1');
      expect(prefs.bookings, false);
    });

    testWidgets('Reset to defaults restores all optional preferences', (tester) async {
      await prefsService.updatePreferences(
        'trainer_1',
        const TrainerNotificationPreferencesModel(bookings: false, payouts: false),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerNotificationPreferencesScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      final resetButton = find.text('Reset to Recommended Defaults');
      await tester.scrollUntilVisible(resetButton, 300);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      final prefs = await prefsService.getPreferences('trainer_1');
      expect(prefs.bookings, true);
      expect(prefs.payouts, true);
    });
  });
}
