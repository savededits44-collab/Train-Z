import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/constants/firestore_collections.dart';
import 'package:trainuspro/services/booking_service.dart';
import 'package:trainuspro/services/support_service.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/support_ticket_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TRAIN Z Firebase Backend & App Integration Audit Tests', () {
    late BookingService bookingService;
    late SupportService supportService;

    setUp(() {
      bookingService = BookingService.instance;
      supportService = SupportService.instance;
      bookingService.resetForTest();
      supportService.resetMockTickets();
    });

    tearDown(() {
      bookingService.clearBookings();
      supportService.resetMockTickets();
    });

    test('BookingService correctly isolates client and trainer bookings and supports clearBookings', () {
      final clientBooking = BookingModel(
        id: 'book_client_001',
        clientId: 'client_alpha',
        trainerId: 'trainer_beta',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Rahul Verma',
        trainerName: 'Vikram Malhotra',
        sessionDate: DateTime.now().add(const Duration(days: 1)),
        startTime: '10:00',
        endTime: '11:00',
        workoutType: 'Personal Training',
        status: BookingStatus.confirmed,
        createdAt: DateTime.now(),
      );

      final otherBooking = BookingModel(
        id: 'book_trainer_002',
        clientId: 'client_gamma',
        trainerId: 'trainer_omega',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        clientName: 'Aditi Sharma',
        trainerName: 'Neha Kapoor',
        sessionDate: DateTime.now().add(const Duration(days: 2)),
        startTime: '14:00',
        endTime: '15:00',
        workoutType: 'HIIT',
        status: BookingStatus.pending,
        createdAt: DateTime.now(),
      );

      // Add bookings to service
      bookingService.addOrUpdateBooking(clientBooking);
      bookingService.addOrUpdateBooking(otherBooking);

      expect(bookingService.allBookings.length, equals(2));

      // Test client isolation
      final clientResults = bookingService.allBookings.where((b) => b.clientId == 'client_alpha').toList();
      expect(clientResults.length, equals(1));
      expect(clientResults.first.id, equals('book_client_001'));

      // Test trainer isolation helper
      final trainerBetaBookings = bookingService.bookingsForTrainer('trainer_beta');
      expect(trainerBetaBookings.length, equals(1));
      expect(trainerBetaBookings.first.id, equals('book_client_001'));

      final trainerOmegaBookings = bookingService.bookingsForTrainer('trainer_omega');
      expect(trainerOmegaBookings.length, equals(1));
      expect(trainerOmegaBookings.first.id, equals('book_trainer_002'));

      // Test clearBookings on sign out cleans state completely
      bookingService.clearBookings();
      expect(bookingService.allBookings.isEmpty, isTrue);
      expect(bookingService.bookingsForTrainer('trainer_beta').isEmpty, isTrue);
    });

    test('SupportService creates tickets and queries tickets strictly enforcing client ownership', () async {
      final ticket = await supportService.createTicket(
        clientId: 'client_user_123',
        clientName: 'Rohan Mehra',
        clientEmail: 'rohan@example.com',
        category: SupportTicketCategory.bookingIssue,
        subject: 'Session reschedule assistance',
        description: 'Need help rescheduling my session with trainer Vikram.',
      );

      expect(ticket.id.isNotEmpty, isTrue);
      expect(ticket.clientId, equals('client_user_123'));
      expect(ticket.ticketNumber.startsWith('TKT-'), isTrue);
      expect(ticket.status, equals(SupportTicketStatus.submitted));

      // Stream client tickets
      final clientTickets = await supportService.streamClientTickets('client_user_123').first;
      expect(clientTickets.length, equals(1));
      expect(clientTickets.first.id, equals(ticket.id));

      // Ticket by ID enforcement
      final fetched = await supportService.getTicketById(ticket.id, 'client_user_123');
      expect(fetched.clientId, equals('client_user_123'));
      expect(fetched.subject, equals('Session reschedule assistance'));

      // Other client cannot access this client's tickets
      expect(
        () async => await supportService.getTicketById(ticket.id, 'client_stranger_456'),
        throwsException,
      );
    });

    test('Firestore collections registry matches security rules definitions', () {
      expect(FirestoreCollections.users, equals('users'));
      expect(FirestoreCollections.clientProfiles, equals('client_profiles'));
      expect(FirestoreCollections.trainerProfiles, equals('trainer_profiles'));
      expect(FirestoreCollections.bookings, equals('bookings'));
      expect(FirestoreCollections.trainerAvailability, equals('trainer_availability'));
      expect(FirestoreCollections.sessionCredits, equals('session_credits'));
      expect(FirestoreCollections.reviews, equals('reviews'));
      expect(FirestoreCollections.notifications, equals('notifications'));
      expect(FirestoreCollections.supportTickets, equals('support_tickets'));
      expect(FirestoreCollections.conversations, equals('conversations'));
      expect(FirestoreCollections.trainerCertificates, equals('trainer_certificates'));
    });
  });
}
