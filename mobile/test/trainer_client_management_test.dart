import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:trainuspro/screens/trainer/trainer_client_detail_screen.dart';
import 'package:trainuspro/screens/trainer/trainer_clients_screen.dart';
import 'package:trainuspro/services/chat_service.dart';
import 'package:trainuspro/services/trainer_client_service.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/trainer_client_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = TrainerClientService.instance;

  final sampleBooking1 = BookingModel(
    id: 'booking_1',
    clientId: 'client_101',
    trainerId: 'trainer_1',
    clientGender: Gender.male,
    trainerGender: Gender.male,
    clientName: 'Aarav Sharma',
    packageName: '1 Month Transformation',
    packagePrice: 10799,
    sessionsCount: 26,
    totalSessions: 26,
    sessionsCompleted: 14,
    validityDays: 30,
    sessionDate: DateTime.now().add(const Duration(days: 2)),
    startTime: '08:00',
    endTime: '09:00',
    fitnessGoal: 'Hypertrophy & Strength',
    status: BookingStatus.confirmed,
    paymentStatus: PaymentStatus.success,
  );

  final sampleBooking1Completed = BookingModel(
    id: 'booking_1_prev',
    clientId: 'client_101',
    trainerId: 'trainer_1',
    clientGender: Gender.male,
    trainerGender: Gender.male,
    clientName: 'Aarav Sharma',
    packageName: '1 Month Transformation',
    sessionDate: DateTime.now().subtract(const Duration(days: 3)),
    startTime: '08:00',
    endTime: '09:00',
    status: BookingStatus.completed,
    paymentStatus: PaymentStatus.success,
  );

  final sampleBooking2Past = BookingModel(
    id: 'booking_2',
    clientId: 'client_102',
    trainerId: 'trainer_1',
    clientGender: Gender.male,
    trainerGender: Gender.male,
    clientName: 'Rohan Verma',
    packageName: '3 Days Quick Start',
    packagePrice: 1399,
    sessionsCount: 3,
    totalSessions: 3,
    sessionsCompleted: 3,
    validityDays: 3,
    sessionDate: DateTime.now().subtract(const Duration(days: 45)),
    startTime: '10:00',
    endTime: '11:00',
    fitnessGoal: 'Conditioning',
    status: BookingStatus.completed,
    paymentStatus: PaymentStatus.success,
  );

  final sampleBookingOtherTrainer = BookingModel(
    id: 'booking_other',
    clientId: 'client_103',
    trainerId: 'trainer_999',
    clientGender: Gender.female,
    trainerGender: Gender.female,
    clientName: 'Pooja Reddy',
    packageName: '1 Week Platform Plan',
    sessionDate: DateTime.now().add(const Duration(days: 1)),
    startTime: '09:00',
    endTime: '10:00',
    status: BookingStatus.confirmed,
    paymentStatus: PaymentStatus.success,
  );

  setUp(() {
    service.resetForTest();
  });

  group('1. Client Aggregation & Booking History', () {
    test('Aggregates multiple bookings per client and computes metrics accurately', () {
      final clients = service.aggregateClientsFromBookings('trainer_1', [
        sampleBooking1,
        sampleBooking1Completed,
        sampleBooking2Past,
        sampleBookingOtherTrainer,
      ]);

      // Only trainer_1's clients should be included (client_101 and client_102)
      expect(clients.length, equals(2));

      final client1 = clients.firstWhere((c) => c.clientId == 'client_101');
      expect(client1.name, equals('Aarav Sharma'));
      expect(client1.activePackageName, equals('1 Month Transformation'));
      expect(client1.totalSessions, equals(26));
      expect(client1.completedSessions, equals(14));
      expect(client1.remainingSessions, equals(12));
      expect(client1.status, equals(TrainerClientStatus.active));
      expect(client1.nextSessionDate, isNotNull);
      expect(client1.lastCompletedSessionDate, isNotNull);

      final client2 = clients.firstWhere((c) => c.clientId == 'client_102');
      expect(client2.name, equals('Rohan Verma'));
      expect(client2.status, equals(TrainerClientStatus.past));
      expect(client2.remainingSessions, equals(0));
      expect(client2.nextSessionDate, isNull);
    });

    test('Separates active and past clients accurately', () {
      final clients = service.aggregateClientsFromBookings('trainer_1', [
        sampleBooking1,
        sampleBooking2Past,
      ]);

      final activeClients = service.filterClients(clients, statusFilter: TrainerClientStatus.active);
      final pastClients = service.filterClients(clients, statusFilter: TrainerClientStatus.past);

      expect(activeClients.length, equals(1));
      expect(activeClients.first.clientId, equals('client_101'));

      expect(pastClients.length, equals(1));
      expect(pastClients.first.clientId, equals('client_102'));
    });
  });

  group('2. Client Ownership & Unconnected Users Segregation', () {
    test('Excludes clients booked with other trainers', () {
      final clients = service.aggregateClientsFromBookings('trainer_1', [
        sampleBookingOtherTrainer,
      ]);

      expect(clients.isEmpty, isTrue);
    });

    test('Ignores bookings with missing or empty client IDs', () {
      final invalidBooking = BookingModel(
        id: 'booking_invalid',
        clientId: '',
        trainerId: 'trainer_1',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime.now(),
        startTime: '07:00',
        endTime: '08:00',
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.success,
      );

      final clients = service.aggregateClientsFromBookings('trainer_1', [invalidBooking]);
      expect(clients.isEmpty, isTrue);
    });
  });

  group('3. Filtering & Search', () {
    test('Filters clients by search query matching name, package, or fitness goal', () {
      final clients = service.aggregateClientsFromBookings('trainer_1', [
        sampleBooking1,
        sampleBooking2Past,
      ]);

      final searchByName = service.filterClients(clients, query: 'Aarav');
      expect(searchByName.length, equals(1));
      expect(searchByName.first.name, equals('Aarav Sharma'));

      final searchByPackage = service.filterClients(clients, query: 'Quick Start');
      expect(searchByPackage.length, equals(1));
      expect(searchByPackage.first.name, equals('Rohan Verma'));

      final searchByGoal = service.filterClients(clients, query: 'Hypertrophy');
      expect(searchByGoal.length, equals(1));
      expect(searchByGoal.first.name, equals('Aarav Sharma'));

      final searchNoMatch = service.filterClients(clients, query: 'Nonexistent');
      expect(searchNoMatch.isEmpty, isTrue);
    });
  });

  group('4. Private Training Notes & Ownership Enforcement', () {
    test('Trainer can add, update, and delete private training notes', () async {
      final note = await service.addNote(
        trainerId: 'trainer_1',
        clientId: 'client_101',
        title: 'Core Stability Assessment',
        content: 'Client demonstrated improved plank duration with neutral spine alignment.',
        category: 'Form & Technique',
      );

      expect(note.id, startsWith('note_'));
      expect(note.title, equals('Core Stability Assessment'));
      expect(note.category, equals('Form & Technique'));

      // Update note
      await service.updateNote(
        noteId: note.id,
        trainerId: 'trainer_1',
        title: 'Core Stability Update',
        content: 'Plank form held cleanly for 90 seconds without lower back dip.',
        category: 'Form & Technique',
      );

      // Verify update via stream
      final notes = await service.streamNotes(trainerId: 'trainer_1', clientId: 'client_101').first;
      expect(notes.first.title, equals('Core Stability Update'));
      expect(notes.first.content, contains('90 seconds'));

      // Delete note
      await service.deleteNote(noteId: note.id, trainerId: 'trainer_1');
      final notesAfterDelete = await service.streamNotes(trainerId: 'trainer_1', clientId: 'client_101').first;
      expect(notesAfterDelete.isEmpty, isTrue);
    });

    test('Enforces non-empty note content validation', () async {
      expect(
        () => service.addNote(
          trainerId: 'trainer_1',
          clientId: 'client_101',
          title: 'Empty Note',
          content: '   ',
        ),
        throwsArgumentError,
      );
    });

    test('Rejects medical diagnoses or medical advice in training notes', () async {
      expect(
        () => service.addNote(
          trainerId: 'trainer_1',
          clientId: 'client_101',
          title: 'Health Advice',
          content: 'I provide a clinical diagnosis of lumbar disc herniation and prescribe anti-inflammatories.',
        ),
        throwsArgumentError,
      );
    });

    test('Unauthorized trainer cannot edit or delete another trainer\'s notes', () async {
      final note = await service.addNote(
        trainerId: 'trainer_1',
        clientId: 'client_101',
        title: 'Owner Note',
        content: 'Private coach observation.',
      );

      expect(
        () => service.updateNote(
          noteId: note.id,
          trainerId: 'trainer_999', // Different trainer
          title: 'Hacked Title',
          content: 'Hacked Content',
        ),
        throwsA(isA<TrainerClientSecurityException>()),
      );

      expect(
        () => service.deleteNote(
          noteId: note.id,
          trainerId: 'trainer_999', // Different trainer
        ),
        throwsA(isA<TrainerClientSecurityException>()),
      );
    });
  });

  group('5. Training Progress & Milestones', () {
    test('Trainer can record, stream, and delete progress milestones', () async {
      final prog = await service.addProgress(
        trainerId: 'trainer_1',
        clientId: 'client_101',
        title: 'Completed 10 Consecutive Sessions',
        notes: 'Maintained 100% adherence over 4 weeks with zero cancellations.',
        category: 'Consistency',
        achievedDate: DateTime.now(),
      );

      expect(prog.id, startsWith('prog_'));
      expect(prog.title, equals('Completed 10 Consecutive Sessions'));
      expect(prog.category, equals('Consistency'));

      final list = await service.streamProgress(trainerId: 'trainer_1', clientId: 'client_101').first;
      expect(list.length, equals(1));
      expect(list.first.title, equals('Completed 10 Consecutive Sessions'));

      // Unauthorized deletion check
      expect(
        () => service.deleteProgress(progressId: prog.id, trainerId: 'trainer_999'),
        throwsA(isA<TrainerClientSecurityException>()),
      );

      // Authorized delete
      await service.deleteProgress(progressId: prog.id, trainerId: 'trainer_1');
      final listAfter = await service.streamProgress(trainerId: 'trainer_1', clientId: 'client_101').first;
      expect(listAfter.isEmpty, isTrue);
    });

    test('Progress title cannot be empty', () async {
      expect(
        () => service.addProgress(
          trainerId: 'trainer_1',
          clientId: 'client_101',
          title: '   ',
          notes: 'Some notes',
          achievedDate: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });
  });

  group('6. Communication Shortcuts & Messaging Permissions', () {
    test('Messaging requires valid booking connection and rejects unconnected users', () async {
      final chatService = ChatService.instance;

      expect(
        () => chatService.getOrCreateConversation(
          clientId: 'unconnected_client',
          trainerId: 'trainer_1',
          trainerName: 'Coach John',
          clientName: 'Unconnected User',
        ),
        throwsA(isA<MessagingPermissionException>()),
      );
    });
  });

  group('7. Widget Tests: TrainerClientsScreen UI Flow', () {
    testWidgets('Renders My Clients screen with stat cards, search bar, and client cards', (tester) async {
      final testClient = TrainerClientModel(
        clientId: 'client_101',
        name: 'Aarav Sharma',
        activePackageName: '1 Month Transformation',
        totalSessions: 26,
        completedSessions: 14,
        remainingSessions: 12,
        status: TrainerClientStatus.active,
        nextSessionDate: DateTime.now().add(const Duration(days: 1)),
        nextSessionTime: '08:00',
        lastCompletedSessionDate: DateTime.now().subtract(const Duration(days: 2)),
      );

      service.setTestClients([testClient]);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerClientsScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Clients'), findsOneWidget);
      expect(find.text('Total Athletes'), findsOneWidget);
      expect(find.text('Active Athletes'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('ACTIVE'), findsWidgets);
      expect(find.text('View Profile, Notes & Milestones'), findsOneWidget);
      expect(find.byIcon(Iconsax.message), findsOneWidget);
    });

    testWidgets('Switching filter tabs separates active and past athletes', (tester) async {
      final activeClient = TrainerClientModel(
        clientId: 'client_101',
        name: 'Aarav Active',
        status: TrainerClientStatus.active,
      );
      final pastClient = TrainerClientModel(
        clientId: 'client_102',
        name: 'Rohan Past',
        status: TrainerClientStatus.past,
      );

      service.setTestClients([activeClient, pastClient]);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerClientsScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      // All tab shows both
      expect(find.text('Aarav Active'), findsOneWidget);
      expect(find.text('Rohan Past'), findsOneWidget);

      // Tap Active tab
      await tester.tap(find.textContaining('Active (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Aarav Active'), findsOneWidget);
      expect(find.text('Rohan Past'), findsNothing);

      // Tap Past tab
      await tester.tap(find.textContaining('Past (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Aarav Active'), findsNothing);
      expect(find.text('Rohan Past'), findsOneWidget);
    });

    testWidgets('Live search filters client cards', (tester) async {
      final client1 = TrainerClientModel(
        clientId: 'c1',
        name: 'Aarav Sharma',
        status: TrainerClientStatus.active,
      );
      final client2 = TrainerClientModel(
        clientId: 'c2',
        name: 'Deepak Patel',
        status: TrainerClientStatus.active,
      );

      service.setTestClients([client1, client2]);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerClientsScreen(trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Deepak Patel'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Deepak');
      await tester.pumpAndSettle();

      expect(find.text('Aarav Sharma'), findsNothing);
      expect(find.text('Deepak Patel'), findsOneWidget);
    });
  });

  group('8. Widget Tests: TrainerClientDetailScreen UI Flow', () {
    testWidgets('Renders detail screen tabs (Sessions, Notes, Progress)', (tester) async {
      final client = TrainerClientModel(
        clientId: 'client_101',
        name: 'Aarav Sharma',
        activePackageName: '1 Month Transformation',
        totalSessions: 26,
        completedSessions: 14,
        remainingSessions: 12,
        status: TrainerClientStatus.active,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TrainerClientDetailScreen(client: client, trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Client Details'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('Sessions'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Progress'), findsOneWidget);

      // Switch to Notes tab
      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      expect(find.text('Add Private Note'), findsOneWidget);
      expect(find.textContaining('Private training notes are visible exclusively to you'), findsOneWidget);

      // Switch to Progress tab
      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();

      expect(find.text('Record Progress Milestone'), findsOneWidget);
      expect(find.text('Milestones'), findsOneWidget);
    });

    testWidgets('Tapping Add Private Note opens bottom sheet', (tester) async {
      final client = TrainerClientModel(
        clientId: 'client_101',
        name: 'Aarav Sharma',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TrainerClientDetailScreen(client: client, trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Notes'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Private Note'));
      await tester.pumpAndSettle();

      expect(find.text('Save Note'), findsOneWidget);
      expect(find.text('Observation Details *'), findsOneWidget);
    });

    testWidgets('Tapping Record Milestone opens bottom sheet', (tester) async {
      final client = TrainerClientModel(
        clientId: 'client_101',
        name: 'Aarav Sharma',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TrainerClientDetailScreen(client: client, trainerId: 'trainer_1'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Progress'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Record Progress Milestone'));
      await tester.pumpAndSettle();

      expect(find.text('Record Milestone'), findsWidgets);
      expect(find.text('Milestone Title *'), findsOneWidget);
      expect(find.text('Save Milestone'), findsOneWidget);
    });
  });

  group('9. Zero Casual & Romantic Terminology Audit', () {
    test('UI strings and models contain zero dating, casual, or romantic terms', () {
      const prohibitedCasualWords = [
        'dating', 'date night', 'soulmate', 'crush', 'hookup', 'meet singles', 'flirt'
      ];

      final client = TrainerClientModel(
        clientId: 'c1',
        name: 'Test Athlete',
        fitnessGoal: 'Muscle Hypertrophy',
        activePackageName: '1 Month Transformation',
      );

      final str = '${client.name} ${client.fitnessGoal} ${client.activePackageName} ${client.formattedNextSession}'.toLowerCase();
      for (final word in prohibitedCasualWords) {
        expect(str.contains(word), isFalse, reason: 'Contains prohibited word: $word');
      }
    });
  });
}
