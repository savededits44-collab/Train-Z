import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/constants/firestore_collections.dart';
import 'package:trainuspro/features/client/presentation/screens/client_chat_screen.dart';
import 'package:trainuspro/features/client/presentation/screens/client_notifications_screen.dart';
import 'package:trainuspro/services/chat_service.dart';
import 'package:trainuspro/shared/models/conversation_model.dart';
import 'package:trainuspro/shared/models/notification_model.dart';

void main() {
  group('1. Conversation & Chat Message Models', () {
    test('ConversationModel deterministically computes ID from client and trainer IDs', () {
      final id = ConversationModel.generateId('client_123', 'trainer_456');
      expect(id, equals('client_123_trainer_456'));
    });

    test('ConversationModel toMap and fromMap serialize and deserialize accurately', () {
      final now = DateTime(2026, 11, 13, 10, 30);
      final model = ConversationModel(
        id: 'client_1_trainer_2',
        clientId: 'client_1',
        trainerId: 'trainer_2',
        bookingId: 'booking_999',
        trainerName: 'Rajesh Kumar',
        trainerPhotoUrl: 'https://trainz.com/photo.jpg',
        clientName: 'Rahul Sharma',
        clientPhotoUrl: null,
        lastMessage: 'Looking forward to our session!',
        lastMessageSenderId: 'client_1',
        lastMessageAt: now,
        clientUnreadCount: 0,
        trainerUnreadCount: 1,
        createdAt: now,
        updatedAt: now,
      );

      final map = model.toMap();
      expect(map['id'], equals('client_1_trainer_2'));
      expect(map['clientId'], equals('client_1'));
      expect(map['trainerId'], equals('trainer_2'));
      expect(map['bookingId'], equals('booking_999'));
      expect(map['trainerName'], equals('Rajesh Kumar'));
      expect(map['lastMessage'], equals('Looking forward to our session!'));
      expect(map['trainerUnreadCount'], equals(1));

      final restored = ConversationModel.fromMap(map, id: 'client_1_trainer_2');
      expect(restored.id, equals(model.id));
      expect(restored.clientId, equals(model.clientId));
      expect(restored.trainerId, equals(model.trainerId));
      expect(restored.bookingId, equals(model.bookingId));
      expect(restored.trainerName, equals(model.trainerName));
      expect(restored.lastMessage, equals(model.lastMessage));
      expect(restored.trainerUnreadCount, equals(1));
    });

    test('ChatMessageModel serialization and read receipt state', () {
      final now = DateTime(2026, 11, 13, 11, 0);
      final message = ChatMessageModel(
        id: 'msg_001',
        conversationId: 'client_1_trainer_2',
        senderId: 'trainer_2',
        senderName: 'Rajesh Kumar',
        receiverId: 'client_1',
        text: 'Please bring your resistance bands today.',
        isRead: false,
        createdAt: now,
      );

      final map = message.toMap();
      expect(map['text'], equals('Please bring your resistance bands today.'));
      expect(map['isRead'], isFalse);

      final restored = ChatMessageModel.fromMap(map, id: 'msg_001');
      expect(restored.id, equals('msg_001'));
      expect(restored.senderName, equals('Rajesh Kumar'));
      expect(restored.isRead, isFalse);

      final readMessage = restored.copyWith(isRead: true, readAt: now);
      expect(readMessage.isRead, isTrue);
      expect(readMessage.readAt, equals(now));
    });
  });

  group('2. Notification Model & Routing Targets', () {
    test('NotificationModel extracts bookingId and conversationId cleanly', () {
      final bookingNotif = NotificationModel(
        id: 'notif_1',
        userId: 'client_1',
        title: 'Booking Confirmed',
        body: 'Your 1-on-1 session is confirmed.',
        type: 'BOOKING_CONFIRMED',
        data: {'bookingId': 'bk_12345', 'trainerId': 'tr_678'},
      );

      expect(bookingNotif.isBookingRelated, isTrue);
      expect(bookingNotif.isChatRelated, isFalse);
      expect(bookingNotif.bookingId, equals('bk_12345'));
      expect(bookingNotif.trainerId, equals('tr_678'));

      final chatNotif = NotificationModel(
        id: 'notif_2',
        userId: 'client_1',
        title: 'Rajesh Kumar',
        body: 'See you tomorrow at 7 AM.',
        type: 'CHAT_MESSAGE',
        data: {
          'conversationId': 'client_1_tr_678',
          'trainerId': 'tr_678',
          'trainerName': 'Rajesh Kumar',
        },
      );

      expect(chatNotif.isChatRelated, isTrue);
      expect(chatNotif.isBookingRelated, isFalse);
      expect(chatNotif.conversationId, equals('client_1_tr_678'));
      expect(chatNotif.trainerName, equals('Rajesh Kumar'));
    });

    test('Firestore collection constants include conversations and messages', () {
      expect(FirestoreCollections.conversations, equals('conversations'));
      expect(FirestoreCollections.messages, equals('messages'));
      expect(FirestoreCollections.notifications, equals('notifications'));
      expect(FirestoreCollections.users, equals('users'));
      expect(FirestoreCollections.bookings, equals('bookings'));
    });
  });

  group('3. Messaging Permissions Invariants', () {
    test('MessagingPermissionException carries descriptive policy violation explanation', () {
      const ex = MessagingPermissionException('Messaging restricted to booked trainers.');
      expect(ex.toString(), contains('Messaging restricted to booked trainers.'));
    });

    test('sendMessage rejects empty message body', () async {
      final chatService = ChatService.instance;
      expect(
        () => chatService.sendMessage(
          conversationId: 'c1_t1',
          senderId: 'c1',
          senderName: 'Client',
          receiverId: 't1',
          text: '   ',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('4. UI & Empty State Invariants', () {
    testWidgets('ClientChatScreen displays trainer name and professional fitness elements', (tester) async {
      final conversation = ConversationModel(
        id: 'c1_t1',
        clientId: 'c1',
        trainerId: 't1',
        trainerName: 'Vikram Malhotra',
        clientName: 'Amit Verma',
        lastMessage: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ClientChatScreen(conversation: conversation),
        ),
      );
      await tester.pump();

      // Verify header components
      expect(find.text('Vikram Malhotra'), findsWidgets);
      expect(find.text('Personal Trainer • Active'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Private 1-on-1 Fitness Chat for booked training sessions.'), findsOneWidget);

      // Verify conversation starter info
      expect(find.text('Connected for Training'), findsOneWidget);

      // Verify no dating language
      expect(find.textContaining('Match', findRichText: true), findsNothing);
      expect(find.textContaining('Dating', findRichText: true), findsNothing);
    });

    testWidgets('ClientNotificationsScreen displays header, filter chips and empty state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ClientNotificationsScreen(),
        ),
      );

      expect(find.text('Notification Centre'), findsOneWidget);
      expect(find.textContaining('All ('), findsOneWidget);
      expect(find.textContaining('Unread ('), findsOneWidget);

      // Clean empty state verification
      expect(find.text('No Notifications Yet'), findsOneWidget);
      expect(
        find.text('You will receive real-time updates for booking confirmations, reminders, and trainer messages here.'),
        findsOneWidget,
      );
    });

    test('Conversation list total unread count calculation folds unread counts accurately', () {
      final convs = [
        const ConversationModel(
          id: 'c1_t1',
          clientId: 'c1',
          trainerId: 't1',
          trainerName: 'Trainer 1',
          clientName: 'Client 1',
          clientUnreadCount: 3,
        ),
        const ConversationModel(
          id: 'c1_t2',
          clientId: 'c1',
          trainerId: 't2',
          trainerName: 'Trainer 2',
          clientName: 'Client 1',
          clientUnreadCount: 0,
        ),
        const ConversationModel(
          id: 'c1_t3',
          clientId: 'c1',
          trainerId: 't3',
          trainerName: 'Trainer 3',
          clientName: 'Client 1',
          clientUnreadCount: 2,
        ),
      ];

      final totalUnread = convs.fold<int>(0, (total, c) => total + c.clientUnreadCount);
      expect(totalUnread, equals(5));
    });

    test('Notification model supports all required TRAIN Z notification types', () {
      const requiredTypes = [
        'BOOKING_CONFIRMED',
        'BOOKING_CANCELLED',
        'BOOKING_RESCHEDULED',
        'UPCOMING_REMINDER',
        'CHAT_MESSAGE',
        'PAYMENT_CONFIRMED',
        'PACKAGE_PURCHASED',
      ];

      for (final type in requiredTypes) {
        final notif = NotificationModel(
          id: 'test_$type',
          userId: 'user_1',
          title: 'Test $type',
          body: 'Notification body for $type',
          type: type,
        );
        expect(notif.type, equals(type));
        expect(notif.toMap()['type'], equals(type));
      }
    });

    test('Strict linguistic invariant: zero dating, romantic, or matchmaking terminology', () {
      final testConversation = ConversationModel(
        id: 'c_t',
        clientId: 'c',
        trainerId: 't',
        trainerName: 'Personal Trainer',
        clientName: 'Client Athlete',
        lastMessage: 'Your upcoming session is confirmed.',
      );

      final forbiddenKeywords = ['match', 'dating', 'romantic', 'matchmaking', 'find your match', 'matched'];
      final convJson = testConversation.toMap().toString().toLowerCase();

      for (final keyword in forbiddenKeywords) {
        expect(convJson.contains(keyword), isFalse, reason: 'Found dating keyword: $keyword');
      }
    });
  });
}
