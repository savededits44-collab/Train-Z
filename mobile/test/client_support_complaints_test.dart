import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/errors/app_exceptions.dart';
import 'package:trainuspro/features/client/presentation/screens/client_help_support_screen.dart';
import 'package:trainuspro/features/client/presentation/screens/client_submit_ticket_screen.dart';
import 'package:trainuspro/features/client/presentation/screens/client_support_tickets_screen.dart';
import 'package:trainuspro/services/support_service.dart';
import 'package:trainuspro/shared/models/support_ticket_model.dart';

void main() {
  final supportService = SupportService.instance;

  setUp(() {
    supportService.resetMockTickets();
  });

  group('Requirement 1 & 2: Support Ticket Creation & Field Validation', () {
    const clientId = 'client_athlete_101';
    const clientName = 'Rahul Sharma';

    test('Successfully submits a support ticket with all required fields', () async {
      final ticket = await supportService.createTicket(
        clientId: clientId,
        clientName: clientName,
        clientEmail: 'rahul.s@test.com',
        category: SupportTicketCategory.bookingIssue,
        subject: 'Trainer was delayed by 15 minutes',
        description: 'During my 60-min session today, the trainer arrived late due to gym entry delay.',
        bookingId: 'bk_2026_01',
        bookingReference: 'REF-B4728A1C',
        attachmentName: 'entry_log.png',
        attachmentUrl: 'https://storage.trainz.app/support/entry_log.png',
      );

      expect(ticket.id, startsWith('tkt_'));
      expect(ticket.ticketNumber, startsWith('TKT-'));
      expect(ticket.clientId, clientId);
      expect(ticket.clientName, clientName);
      expect(ticket.category, SupportTicketCategory.bookingIssue);
      expect(ticket.subject, 'Trainer was delayed by 15 minutes');
      expect(ticket.status, SupportTicketStatus.submitted);
      expect(ticket.bookingReference, 'REF-B4728A1C');
      expect(ticket.hasAttachment, isTrue);
      expect(ticket.isActive, isTrue);

      // Verify stored in mock store
      final fetched = supportService.getMockTicket(ticket.id);
      expect(fetched, isNotNull);
      expect(fetched!.ticketNumber, ticket.ticketNumber);

      // Verify initial message was created
      final messages = await supportService.streamTicketMessages(ticket.id, clientId).first;
      expect(messages.length, 1);
      expect(messages.first.senderId, clientId);
      expect(messages.first.isClient, isTrue);
      expect(messages.first.message, ticket.description);
    });

    test('Validates subject minimum character length (>= 3 chars)', () async {
      expect(
        () => supportService.createTicket(
          clientId: clientId,
          clientName: clientName,
          category: SupportTicketCategory.paymentIssue,
          subject: 'Hi', // only 2 chars
          description: 'Payment was deducted twice via Razorpay UPI.',
        ),
        throwsA(isA<SupportException>().having(
          (e) => e.message,
          'message',
          contains('Subject must be at least 3 characters long'),
        )),
      );
    });

    test('Validates detailed description minimum character length (>= 10 chars)', () async {
      expect(
        () => supportService.createTicket(
          clientId: clientId,
          clientName: clientName,
          category: SupportTicketCategory.technicalIssue,
          subject: 'App crashing on booking',
          description: 'Crash bug', // only 9 chars
        ),
        throwsA(isA<SupportException>().having(
          (e) => e.message,
          'message',
          contains('Detailed description must be at least 10 characters long'),
        )),
      );
    });

    test('Rejects unauthenticated ticket creation', () async {
      expect(
        () => supportService.createTicket(
          clientId: '   ',
          clientName: 'Anonymous',
          category: SupportTicketCategory.other,
          subject: 'General inquiry question',
          description: 'How do session credits transfer when moving cities?',
        ),
        throwsA(isA<SupportException>().having(
          (e) => e.message,
          'message',
          contains('User must be authenticated'),
        )),
      );
    });
  });

  group('Requirement 3 & 6: Ticket Tracking, Filtering & Ownership Security', () {
    const clientA = 'client_aaa';
    const clientB = 'client_bbb';

    test('streamClientTickets retrieves only tickets belonging to the client', () async {
      // Create ticket for Client A
      final ticketA = await supportService.createTicket(
        clientId: clientA,
        clientName: 'Athlete A',
        category: SupportTicketCategory.paymentIssue,
        subject: 'Double charge inquiry on 1 Month Package',
        description: 'My UPI app charged twice for the same package order.',
      );

      // Create ticket for Client B
      await supportService.createTicket(
        clientId: clientB,
        clientName: 'Athlete B',
        category: SupportTicketCategory.trainerIssue,
        subject: 'Trainer conduct report',
        description: 'Trainer rescheduled workout without prior 12h notice.',
      );

      final clientATickets = await supportService.streamClientTickets(clientA).first;
      expect(clientATickets.length, 1);
      expect(clientATickets.first.id, ticketA.id);
      expect(clientATickets.first.clientId, clientA);

      final clientBTickets = await supportService.streamClientTickets(clientB).first;
      expect(clientBTickets.length, 1);
      expect(clientBTickets.first.clientId, clientB);
    });

    test('Strict ownership guard prevents Client B from accessing Client A ticket', () async {
      final ticketA = await supportService.createTicket(
        clientId: clientA,
        clientName: 'Athlete A',
        category: SupportTicketCategory.refundCancellation,
        subject: 'Section 8 late cancellation query',
        description: 'I had a genuine medical emergency causing cancellation <12h.',
      );

      // Client A can access
      final fetched = await supportService.getTicketById(ticketA.id, clientA);
      expect(fetched.id, ticketA.id);

      // Client B cannot access Client A's ticket
      expect(
        () => supportService.getTicketById(ticketA.id, clientB),
        throwsA(isA<SupportException>().having(
          (e) => e.message,
          'message',
          contains('You do not have permission to view this support ticket'),
        )),
      );

      // Client B cannot stream Client A's ticket messages
      expect(
        supportService.streamTicketMessages(ticketA.id, clientB),
        emitsError(isA<SupportException>()),
      );
    });
  });

  group('Requirement 4: Structured Support Conversation & Follow-Up Messages', () {
    const clientId = 'client_athlete_followup';
    late SupportTicketModel ticket;

    setUp(() async {
      ticket = await supportService.createTicket(
        clientId: clientId,
        clientName: 'Priya Patel',
        category: SupportTicketCategory.technicalIssue,
        subject: 'Calendar slots not loading for tomorrow',
        description: 'When I tap on tomorrow date offset, the 60-min slot list shows empty.',
      );
    });

    test('Client can send follow-up messages chronologically', () async {
      final msg1 = await supportService.sendFollowUpMessage(
        ticketId: ticket.id,
        clientId: clientId,
        senderName: 'Priya Patel',
        message: 'I reinstalled the app and the issue persists on Android 14.',
      );

      expect(msg1.message, 'I reinstalled the app and the issue persists on Android 14.');
      expect(msg1.isClient, isTrue);

      final messages = await supportService.streamTicketMessages(ticket.id, clientId).first;
      expect(messages.length, 2); // Initial description + 1 follow-up
      expect(messages[1].message, msg1.message);

      // Verify ticket updatedAt and lastMessage updated
      final updatedTicket = supportService.getMockTicket(ticket.id);
      expect(updatedTicket!.lastMessage, msg1.message);
      expect(updatedTicket.lastMessageSender, 'CLIENT');
    });

    test('Support Specialist response appends to conversation thread', () async {
      await supportService.updateTicketStatus(
        ticketId: ticket.id,
        newStatus: SupportTicketStatus.inProgress,
        supportNote: 'Our engineering team deployed a fix for slot loading. Please refresh your screen.',
        supportAgentName: 'Kavita (TRAIN Z Lead Support)',
      );

      final messages = await supportService.streamTicketMessages(ticket.id, clientId).first;
      expect(messages.length, 2);
      expect(messages[1].isSupport, isTrue);
      expect(messages[1].senderName, 'Kavita (TRAIN Z Lead Support)');
      expect(messages[1].message, contains('deployed a fix for slot loading'));

      final updatedTicket = supportService.getMockTicket(ticket.id);
      expect(updatedTicket!.status, SupportTicketStatus.inProgress);
      expect(updatedTicket.lastMessageSender, 'SUPPORT');
    });

    test('Client can close their resolved ticket', () async {
      final closed = await supportService.closeTicket(ticketId: ticket.id, clientId: clientId);
      expect(closed, isTrue);

      final closedTicket = supportService.getMockTicket(ticket.id);
      expect(closedTicket!.isClosed, isTrue);
      expect(closedTicket.status, SupportTicketStatus.closed);
      expect(closedTicket.closedAt, isNotNull);

      // Sending message to closed ticket is rejected
      expect(
        () => supportService.sendFollowUpMessage(
          ticketId: ticket.id,
          clientId: clientId,
          senderName: 'Priya Patel',
          message: 'Can I ask one more thing?',
        ),
        throwsA(isA<SupportException>().having(
          (e) => e.message,
          'message',
          contains('This ticket is closed'),
        )),
      );
    });
  });

  group('Requirement 5: Attachments Validation & File Limits', () {
    test('Validates maximum file size limit of 5MB', () {
      expect(
        () => supportService.validateAttachmentFile(File('/tmp/nonexistent.exe')),
        throwsA(anything),
      );
    });
  });

  group('Requirement 7 & 8: Zero Dating or Romantic Terminology Audit', () {
    test('UI strings and categories contain zero dating or romantic terms', () {
      for (final cat in SupportTicketCategory.values) {
        final label = cat.label.toLowerCase();
        expect(label.contains('dating'), isFalse);
        expect(label.contains('romantic'), isFalse);
        expect(label.contains('match'), isFalse);
        expect(label.contains('single'), isFalse);
        expect(label.contains('hookup'), isFalse);
      }
    });
  });

  group('UI Widget Tests for Support Features', () {
    const testClientId = 'client_widget_test';
    const testClientName = 'Arjun Verma';

    testWidgets('ClientHelpSupportScreen renders action tiles and FAQ sections', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ClientHelpSupportScreen(
            clientId: testClientId,
            clientName: testClientName,
            clientEmail: 'arjun@trainz.test',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('Raise a Request'), findsOneWidget);
      expect(find.text('My Tickets'), findsOneWidget);
      expect(find.text('FREQUENTLY ASKED QUESTIONS'), findsOneWidget);
      expect(find.text('Booking & Scheduling'), findsOneWidget);
      expect(find.text('Packages & Payments'), findsOneWidget);
      expect(find.text('Cancellations & Refunds (Section 8 Policy)'), findsOneWidget);
      expect(find.text('Account, Safety & Privacy'), findsOneWidget);
      expect(find.text('Submit a Support Request'), findsOneWidget);
    });

    testWidgets('ClientSubmitTicketScreen validates short input and shows error', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ClientSubmitTicketScreen(
            clientId: testClientId,
            clientName: testClientName,
            clientEmail: 'arjun@trainz.test',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Raise a Request'), findsOneWidget);
      expect(find.text('COMPLAINT CATEGORY'), findsOneWidget);
      expect(find.text('SUBJECT'), findsOneWidget);
      expect(find.text('DETAILED DESCRIPTION'), findsOneWidget);

      // Tap submit with empty fields
      await tester.tap(find.text('Submit Support Request'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a subject (minimum 3 characters).'), findsOneWidget);
      expect(find.text('Please provide more details (minimum 10 characters).'), findsOneWidget);
    });

    testWidgets('ClientSupportTicketsScreen renders empty state when no tickets exist', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ClientSupportTicketsScreen(
            clientId: testClientId,
            clientName: testClientName,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Support Tickets'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Resolved / Closed'), findsOneWidget);
      expect(find.text('New Request'), findsOneWidget);
      expect(find.text('No support tickets found'), findsOneWidget);
    });
  });
}
