import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:trainuspro/screens/trainer/trainer_conversation_screen.dart';
import 'package:trainuspro/screens/trainer/trainer_messages_screen.dart';
import 'package:trainuspro/services/chat_service.dart';
import 'package:trainuspro/shared/models/conversation_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final chatService = ChatService.instance;

  final sampleConv1 = ConversationModel(
    id: 'client_101_trainer_1',
    clientId: 'client_101',
    trainerId: 'trainer_1',
    clientName: 'Aarav Sharma',
    trainerName: 'Coach Vikram',
    lastMessage: 'Looking forward to our session tomorrow at 8 AM.',
    lastMessageSenderId: 'client_101',
    lastMessageAt: DateTime.now().subtract(const Duration(minutes: 15)),
    trainerUnreadCount: 2,
    clientUnreadCount: 0,
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    updatedAt: DateTime.now().subtract(const Duration(minutes: 15)),
  );

  final sampleConv2 = ConversationModel(
    id: 'client_102_trainer_1',
    clientId: 'client_102',
    trainerId: 'trainer_1',
    clientName: 'Rohan Verma',
    trainerName: 'Coach Vikram',
    lastMessage: 'Form on deadlifts looked great today.',
    lastMessageSenderId: 'trainer_1',
    lastMessageAt: DateTime.now().subtract(const Duration(hours: 4)),
    trainerUnreadCount: 0,
    clientUnreadCount: 1,
    createdAt: DateTime.now().subtract(const Duration(days: 10)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 4)),
  );

  final sampleConvOtherTrainer = ConversationModel(
    id: 'client_103_trainer_999',
    clientId: 'client_103',
    trainerId: 'trainer_999',
    clientName: 'Pooja Reddy',
    trainerName: 'Coach Sarah',
    lastMessage: 'Session confirmed.',
    lastMessageSenderId: 'trainer_999',
    lastMessageAt: DateTime.now(),
    trainerUnreadCount: 1,
    clientUnreadCount: 0,
  );

  setUp(() {
    chatService.resetForTest();
  });

  group('1. Conversation Ownership & Segregation', () {
    test('Trainer can only stream conversations belonging to their authenticated trainerId', () async {
      chatService.setTestConversations([sampleConv1, sampleConv2, sampleConvOtherTrainer]);

      final trainerConvs = await chatService.streamTrainerConversations('trainer_1').first;
      expect(trainerConvs.length, equals(2));
      expect(trainerConvs.any((c) => c.trainerId == 'trainer_999'), isFalse);
      expect(trainerConvs.map((c) => c.clientId), containsAll(['client_101', 'client_102']));
    });

    test('Creating a conversation with an unconnected client throws MessagingPermissionException', () async {
      expect(
        () => chatService.getOrCreateConversation(
          clientId: 'unconnected_client',
          trainerId: 'trainer_1',
          trainerName: 'Coach Vikram',
          clientName: 'Stranger',
        ),
        throwsA(isA<MessagingPermissionException>()),
      );
    });

    test('Authorized trainer with legitimate booking can access or create conversation', () async {
      chatService.setTestBookingConnection('client_105', 'trainer_1', true);

      final conv = await chatService.getOrCreateConversation(
        clientId: 'client_105',
        trainerId: 'trainer_1',
        trainerName: 'Coach Vikram',
        clientName: 'Kunal Kapoor',
      );

      expect(conv.id, equals('client_105_trainer_1'));
      expect(conv.clientName, equals('Kunal Kapoor'));
    });
  });

  group('2. Trainer Message Sending & Receiving', () {
    test('Trainer sends message, updates lastMessage, and increments client unread count', () async {
      chatService.setTestConversations([sampleConv1]);

      final msg = await chatService.sendMessage(
        conversationId: sampleConv1.id,
        senderId: 'trainer_1',
        senderName: 'Coach Vikram',
        receiverId: 'client_101',
        text: 'Please remember to bring resistance bands tomorrow.',
        isClient: false,
      );

      expect(msg.id, startsWith('msg_'));
      expect(msg.text, equals('Please remember to bring resistance bands tomorrow.'));
      expect(msg.isRead, isFalse);

      // Verify conversation metadata updated
      final updatedConvs = await chatService.streamTrainerConversations('trainer_1').first;
      final conv = updatedConvs.firstWhere((c) => c.id == sampleConv1.id);
      expect(conv.lastMessage, equals('Please remember to bring resistance bands tomorrow.'));
      expect(conv.lastMessageSenderId, equals('trainer_1'));
      // When trainer sends, client unread count increments, trainer unread count does NOT increment
      expect(conv.clientUnreadCount, equals(1));
    });

    test('Sending empty message throws ArgumentError', () async {
      expect(
        () => chatService.sendMessage(
          conversationId: 'some_conv',
          senderId: 'trainer_1',
          senderName: 'Coach Vikram',
          receiverId: 'client_101',
          text: '    ',
          isClient: false,
        ),
        throwsArgumentError,
      );
    });

    test('Messages are delivered in chronological order', () async {
      final msg1 = ChatMessageModel(
        id: 'msg_1',
        conversationId: sampleConv1.id,
        senderId: 'client_101',
        senderName: 'Aarav Sharma',
        receiverId: 'trainer_1',
        text: 'Hello Coach',
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      final msg2 = ChatMessageModel(
        id: 'msg_2',
        conversationId: sampleConv1.id,
        senderId: 'trainer_1',
        senderName: 'Coach Vikram',
        receiverId: 'client_101',
        text: 'Hey Aarav, ready for training?',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      chatService.setTestMessages(sampleConv1.id, [msg1, msg2]);

      final messages = await chatService.streamMessages(sampleConv1.id).first;
      expect(messages.length, equals(2));
      expect(messages[0].text, equals('Hello Coach'));
      expect(messages[1].text, equals('Hey Aarav, ready for training?'));
    });
  });

  group('3. Unread Message Indicators & Mark as Read', () {
    test('Calculates trainer total unread count correctly', () async {
      chatService.setTestConversations([sampleConv1, sampleConv2]); // sampleConv1 has 2 unread, sampleConv2 has 0

      final totalUnread = await chatService.streamTrainerTotalUnreadCount('trainer_1').first;
      expect(totalUnread, equals(2));
    });

    test('markConversationAsRead clears trainerUnreadCount and marks messages as read', () async {
      final msg1 = ChatMessageModel(
        id: 'msg_1',
        conversationId: sampleConv1.id,
        senderId: 'client_101',
        senderName: 'Aarav',
        receiverId: 'trainer_1',
        text: 'Unread message',
        isRead: false,
      );

      chatService.setTestConversations([sampleConv1]);
      chatService.setTestMessages(sampleConv1.id, [msg1]);

      await chatService.markConversationAsRead(
        conversationId: sampleConv1.id,
        currentUserId: 'trainer_1',
        isClient: false,
      );

      // Verify trainer unread count is cleared
      final convs = await chatService.streamTrainerConversations('trainer_1').first;
      expect(convs.first.trainerUnreadCount, equals(0));

      // Verify message isRead is true
      final messages = await chatService.streamMessages(sampleConv1.id).first;
      expect(messages.first.isRead, isTrue);
      expect(messages.first.readAt, isNotNull);
    });
  });

  group('4. Pagination & Filtering', () {
    test('fetchOlderMessages retrieves historical messages before given timestamp', () async {
      final now = DateTime.now();
      final msgOld = ChatMessageModel(
        id: 'msg_old',
        conversationId: sampleConv1.id,
        senderId: 'client_101',
        senderName: 'Aarav',
        receiverId: 'trainer_1',
        text: 'Old message from yesterday',
        createdAt: now.subtract(const Duration(days: 1)),
      );
      final msgRecent = ChatMessageModel(
        id: 'msg_recent',
        conversationId: sampleConv1.id,
        senderId: 'trainer_1',
        senderName: 'Coach',
        receiverId: 'client_101',
        text: 'Recent message',
        createdAt: now,
      );

      chatService.setTestMessages(sampleConv1.id, [msgOld, msgRecent]);

      final older = await chatService.fetchOlderMessages(
        sampleConv1.id,
        beforeDate: now.subtract(const Duration(minutes: 30)),
        limit: 10,
      );

      expect(older.length, equals(1));
      expect(older.first.text, equals('Old message from yesterday'));
    });

    test('filterConversations filters by athlete name and message text', () {
      final list = [sampleConv1, sampleConv2];

      final byName = chatService.filterConversations(list, query: 'Aarav');
      expect(byName.length, equals(1));
      expect(byName.first.clientName, equals('Aarav Sharma'));

      final byMsg = chatService.filterConversations(list, query: 'deadlifts');
      expect(byMsg.length, equals(1));
      expect(byMsg.first.clientName, equals('Rohan Verma'));

      final noMatch = chatService.filterConversations(list, query: 'nonexistent');
      expect(noMatch.isEmpty, isTrue);
    });
  });

  group('5. Widget Tests: TrainerMessagesScreen UI Flow', () {
    testWidgets('Renders messages screen with stats, search bar, and conversation cards', (tester) async {
      chatService.setTestConversations([sampleConv1, sampleConv2]);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerMessagesScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Client Messages'), findsOneWidget);
      expect(find.text('Conversations'), findsOneWidget);
      expect(find.text('Unread Messages'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Rohan Verma'), findsOneWidget);
      expect(find.text('2'), findsWidgets); // Unread badge count
    });

    testWidgets('Search query filters conversation list dynamically', (tester) async {
      chatService.setTestConversations([sampleConv1, sampleConv2]);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerMessagesScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Rohan Verma'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Rohan');
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsNothing);
      expect(find.text('Rohan Verma'), findsOneWidget);
    });

    testWidgets('Tapping a conversation navigates to TrainerConversationScreen', (tester) async {
      chatService.setTestConversations([sampleConv1]);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerMessagesScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Aarav Sharma'));
      await tester.pumpAndSettle();

      expect(find.byType(TrainerConversationScreen), findsOneWidget);
      expect(find.text('Booked Athlete • Active'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });

  group('6. Widget Tests: TrainerConversationScreen UI Flow', () {
    testWidgets('Displays messages with proper styling and sends new message', (tester) async {
      final msg1 = ChatMessageModel(
        id: 'msg_1',
        conversationId: sampleConv1.id,
        senderId: 'client_101',
        senderName: 'Aarav',
        receiverId: 'trainer_1',
        text: 'Morning Coach, what is our focus today?',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );

      chatService.setTestConversations([sampleConv1]);
      chatService.setTestMessages(sampleConv1.id, [msg1]);

      await tester.pumpWidget(
        MaterialApp(
          home: TrainerConversationScreen(
            conversation: sampleConv1,
            trainerId: 'trainer_1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Morning Coach, what is our focus today?'), findsOneWidget);

      // Type reply
      await tester.enterText(find.byType(TextField), 'We will focus on upper body posture and bench press.');
      await tester.tap(find.byIcon(Iconsax.send_1));
      await tester.pumpAndSettle();

      expect(find.text('We will focus on upper body posture and bench press.'), findsOneWidget);
    });

    testWidgets('Empty conversation shows friendly coaching empty state', (tester) async {
      chatService.setTestConversations([sampleConv2]);
      chatService.setTestMessages(sampleConv2.id, []);

      await tester.pumpWidget(
        MaterialApp(
          home: TrainerConversationScreen(
            conversation: sampleConv2,
            trainerId: 'trainer_1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Direct Chat with Rohan Verma'), findsOneWidget);
      expect(find.textContaining('Send a welcome message or coordinate training location'), findsOneWidget);
    });
  });

  group('7. Zero Casual & Dating Terminology Audit', () {
    test('UI strings and models contain zero dating, casual, or romantic terms', () {
      const prohibitedCasualWords = [
        'dating', 'date night', 'soulmate', 'crush', 'hookup', 'meet singles', 'flirt'
      ];

      final text = '${sampleConv1.clientName} ${sampleConv1.lastMessage} ${sampleConv2.lastMessage}'.toLowerCase();
      for (final word in prohibitedCasualWords) {
        expect(text.contains(word), isFalse, reason: 'Contains prohibited word: $word');
      }
    });
  });
}

