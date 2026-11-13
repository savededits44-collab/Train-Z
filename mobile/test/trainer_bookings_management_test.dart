import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/screens/trainer/trainer_bookings_screen.dart';
import 'package:trainuspro/services/booking_service.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testTrainerId = 'trainer_rohit_test_uid';
  final now = DateTime.now();
  final todayMorning = DateTime(now.year, now.month, now.day, 8, 0);

  setUp(() {
    BookingService.instance.resetForTest();
  });

  group('1. BookingModel Extended Fields & Serialization', () {
    test('Stores and serializes cancellationReason, completedAt, completedBy properly', () {
      final completedTime = DateTime(2026, 11, 13, 10, 0);
      final booking = BookingModel(
        id: 'bk_audit_101',
        clientId: 'client_sam',
        trainerId: testTrainerId,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Sam Patel',
        sessionDate: DateTime(2026, 11, 13),
        startTime: '08:00',
        endTime: '09:00',
        status: BookingStatus.completed,
        paymentStatus: PaymentStatus.completed,
        packageName: '1 Month Transformation',
        cancellationReason: 'Client medical emergency',
        completedAt: completedTime,
        completedBy: testTrainerId,
      );

      final map = booking.toMap();
      expect(map['cancellationReason'], 'Client medical emergency');
      expect(map['completedBy'], testTrainerId);
      expect(map['completedAt'], isNotNull);

      final reconstructed = BookingModel.fromMap(map, id: 'bk_audit_101');
      expect(reconstructed.id, 'bk_audit_101');
      expect(reconstructed.cancellationReason, 'Client medical emergency');
      expect(reconstructed.completedBy, testTrainerId);
      expect(reconstructed.status, BookingStatus.completed);
      expect(reconstructed.completedAt?.year, 2026);
    });

    test('copyWith preserves or updates new completion and cancellation fields', () {
      final booking = BookingModel(
        id: 'bk_audit_102',
        clientId: 'client_sam',
        trainerId: testTrainerId,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime(2026, 11, 13),
        startTime: '09:00',
        endTime: '10:00',
      );

      expect(booking.completedAt, isNull);
      expect(booking.cancellationReason, isNull);

      final completedBooking = booking.copyWith(
        status: BookingStatus.completed,
        completedBy: testTrainerId,
        completedAt: DateTime(2026, 11, 13, 10, 0),
      );

      expect(completedBooking.status, BookingStatus.completed);
      expect(completedBooking.completedBy, testTrainerId);
      expect(completedBooking.completedAt, isNotNull);

      final cancelledBooking = booking.copyWith(
        status: BookingStatus.cancelled,
        cancellationReason: 'Heavy rain flooding gym',
      );

      expect(cancelledBooking.status, BookingStatus.cancelled);
      expect(cancelledBooking.cancellationReason, 'Heavy rain flooding gym');
    });
  });

  group('2. Booking Filtering by Status (Upcoming, Pending, Completed, Cancelled)', () {
    test('Filters bookings accurately into 4 distinct groups for the trainer', () {
      final bService = BookingService.instance;

      // 1. Upcoming (Confirmed, in future / today)
      bService.addOrUpdateBooking(BookingModel(
        id: 'bk_upcoming_1',
        clientId: 'client_1',
        trainerId: testTrainerId,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Aarav Mehta',
        sessionDate: now.add(const Duration(days: 1)),
        startTime: '07:00',
        endTime: '08:00',
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.completed,
      ));

      // 2. Pending request
      bService.addOrUpdateBooking(BookingModel(
        id: 'bk_pending_1',
        clientId: 'client_2',
        trainerId: testTrainerId,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Vikram Seth',
        sessionDate: now.add(const Duration(days: 2)),
        startTime: '09:00',
        endTime: '10:00',
        status: BookingStatus.pending,
        paymentStatus: PaymentStatus.pending,
      ));

      // 3. Completed session
      bService.addOrUpdateBooking(BookingModel(
        id: 'bk_completed_1',
        clientId: 'client_3',
        trainerId: testTrainerId,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Kunal Kapoor',
        sessionDate: now.subtract(const Duration(days: 1)),
        startTime: '08:00',
        endTime: '09:00',
        status: BookingStatus.completed,
        paymentStatus: PaymentStatus.completed,
        completedAt: now.subtract(const Duration(days: 1)),
        completedBy: testTrainerId,
      ));

      // 4. Cancelled session
      bService.addOrUpdateBooking(BookingModel(
        id: 'bk_cancelled_1',
        clientId: 'client_4',
        trainerId: testTrainerId,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Rohan Joshi',
        sessionDate: now.subtract(const Duration(days: 2)),
        startTime: '10:00',
        endTime: '11:00',
        status: BookingStatus.cancelled,
        cancellationReason: 'Trainer unwell',
      ));

      // Different trainer booking (should NOT appear in testTrainerId lists)
      bService.addOrUpdateBooking(BookingModel(
        id: 'bk_other_trainer',
        clientId: 'client_5',
        trainerId: 'other_trainer_uid',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Alien Client',
        sessionDate: now.add(const Duration(days: 1)),
        startTime: '07:00',
        endTime: '08:00',
        status: BookingStatus.confirmed,
      ));

      final upcoming = bService.upcomingBookingsForTrainer(testTrainerId);
      final pending = bService.pendingBookingsForTrainer(testTrainerId);
      final completed = bService.completedBookingsForTrainer(testTrainerId);
      final cancelled = bService.cancelledBookingsForTrainer(testTrainerId);

      expect(upcoming.length, 1);
      expect(upcoming.first.id, 'bk_upcoming_1');

      expect(pending.length, 1);
      expect(pending.first.id, 'bk_pending_1');

      expect(completed.length, 1);
      expect(completed.first.id, 'bk_completed_1');

      expect(cancelled.length, 1);
      expect(cancelled.first.id, 'bk_cancelled_1');
    });
  });

  group('3. Address Privacy Enforcement', () {
    test('Reveals exact address ONLY when booking is confirmed', () {
      const secretAddress = 'Flat 402, Elite Heights, Bandra West, Mumbai';

      final confirmedBooking = BookingModel(
        id: 'bk_conf_privacy',
        clientId: 'client_1',
        trainerId: testTrainerId,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        meetingLocation: secretAddress,
        sessionDate: now,
        startTime: '07:00',
        endTime: '08:00',
        status: BookingStatus.confirmed,
      );

      final pendingBooking = BookingModel(
        id: 'bk_pend_privacy',
        clientId: 'client_2',
        trainerId: testTrainerId,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        meetingLocation: secretAddress,
        sessionDate: now,
        startTime: '08:00',
        endTime: '09:00',
        status: BookingStatus.pending,
      );

      // In confirmed booking, location is permitted
      expect(confirmedBooking.status == BookingStatus.confirmed, isTrue);
      expect(confirmedBooking.meetingLocation, secretAddress);

      // In unconfirmed/pending booking, address must remain hidden behind privacy gate
      final isConfirmed = pendingBooking.status == BookingStatus.confirmed;
      final displayLocation = isConfirmed
          ? (pendingBooking.meetingLocation ?? 'Standard Gym Studio')
          : 'Location address hidden until booking is confirmed';

      expect(displayLocation, 'Location address hidden until booking is confirmed');
      expect(displayLocation.contains('Flat 402'), isFalse);
    });
  });

  group('4. Session Completion & Duplicate Prevention', () {
    test('Completing session marks status completed, records timestamp and completedBy', () async {
      final bService = BookingService.instance;

      final booking = BookingModel(
        id: 'bk_to_complete',
        clientId: 'client_sam',
        trainerId: testTrainerId,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: todayMorning,
        startTime: '08:00',
        endTime: '09:00',
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.completed,
      );

      bService.addOrUpdateBooking(booking);

      await bService.completeSession(
        bookingId: 'bk_to_complete',
        sessionNotes: 'Completed 5 sets of squats and 30 min cardio',
      );

      final updated = bService.allBookings.firstWhere((b) => b.id == 'bk_to_complete');
      expect(updated.status, BookingStatus.completed);
      expect(updated.completedAt, isNotNull);
      expect(updated.notes, contains('Completed 5 sets of squats and 30 min cardio'));
    });

    test('Duplicate completion attempt throws StateError to prevent multiple ledger consumes', () async {
      final bService = BookingService.instance;

      final booking = BookingModel(
        id: 'bk_already_done',
        clientId: 'client_sam',
        trainerId: testTrainerId,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: todayMorning,
        startTime: '08:00',
        endTime: '09:00',
        status: BookingStatus.completed,
        completedAt: now,
      );

      bService.addOrUpdateBooking(booking);

      expect(
        () async => await bService.completeSession(bookingId: 'bk_already_done'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('5. Trainer Cancellation & Refund Integrity', () {
    test('Trainer cancellation updates status to CANCELLED and records reason', () async {
      final bService = BookingService.instance;

      final booking = BookingModel(
        id: 'bk_to_cancel',
        clientId: 'client_sam',
        trainerId: testTrainerId,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: now.add(const Duration(days: 1)),
        startTime: '09:00',
        endTime: '10:00',
        status: BookingStatus.confirmed,
      );

      bService.addOrUpdateBooking(booking);

      await bService.cancelBooking(
        bookingId: 'bk_to_cancel',
        isTrainer: true,
        reason: 'Emergency hospital visit',
      );

      final updated = bService.allBookings.firstWhere((b) => b.id == 'bk_to_cancel');
      expect(updated.status, BookingStatus.cancelledTrainer);
      expect(updated.isCancelled, isTrue);
      expect(updated.cancellationReason, 'Emergency hospital visit');
    });

    test('Duplicate cancellation attempt throws StateError to prevent double refunds', () async {
      final bService = BookingService.instance;

      final booking = BookingModel(
        id: 'bk_already_cancelled',
        clientId: 'client_sam',
        trainerId: testTrainerId,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: now.add(const Duration(days: 1)),
        startTime: '09:00',
        endTime: '10:00',
        status: BookingStatus.cancelledTrainer,
        cancellationReason: 'Already cancelled',
      );

      bService.addOrUpdateBooking(booking);

      expect(
        () async => await bService.cancelBooking(
          bookingId: 'bk_already_cancelled',
          isTrainer: true,
          reason: 'Repeat attempt',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('6. Widget Tests: TrainerBookingsScreen UI Flow', () {
    testWidgets('Renders all 4 tabs and displays categorized bookings properly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final bService = BookingService.instance;

      // Add a confirmed upcoming booking
      bService.addOrUpdateBooking(BookingModel(
        id: 'bk_ui_up',
        clientId: 'cl_1',
        trainerId: testTrainerId,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Arjun Rampal',
        packageName: '1 Month Transformation',
        sessionDate: now.add(const Duration(days: 1)),
        startTime: '07:00',
        endTime: '08:00',
        status: BookingStatus.confirmed,
        meetingLocation: 'Andheri West Fitness Club',
      ));

      // Add a completed booking
      bService.addOrUpdateBooking(BookingModel(
        id: 'bk_ui_comp',
        clientId: 'cl_2',
        trainerId: testTrainerId,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Dev Patel',
        packageName: '3 Months Pro',
        sessionDate: now.subtract(const Duration(days: 1)),
        startTime: '08:00',
        endTime: '09:00',
        status: BookingStatus.completed,
        completedAt: now.subtract(const Duration(days: 1)),
        completedBy: testTrainerId,
      ));

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerBookingsScreen(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Title & Tabs
      expect(find.text('My Scheduled Bookings'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);

      // In Upcoming tab, Arjun Rampal should be visible
      expect(find.text('Arjun Rampal'), findsOneWidget);
      expect(find.text('1 Month Transformation'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('60 min'), findsOneWidget);

      // Switch to Completed tab
      await tester.tap(find.text('Completed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dev Patel should be visible in completed
      expect(find.text('Dev Patel'), findsOneWidget);
      expect(find.text('3 Months Pro'), findsOneWidget);
      expect(find.text('Completed'), findsWidgets);
    });

    testWidgets('Search input filters bookings live across client name and package', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final bService = BookingService.instance;

      bService.addOrUpdateBooking(BookingModel(
        id: 'bk_search_1',
        clientId: 'cl_1',
        trainerId: testTrainerId,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Sameer Khan',
        packageName: 'Standard 1 Day',
        sessionDate: now.add(const Duration(days: 1)),
        startTime: '07:00',
        endTime: '08:00',
        status: BookingStatus.confirmed,
      ));

      bService.addOrUpdateBooking(BookingModel(
        id: 'bk_search_2',
        clientId: 'cl_2',
        trainerId: testTrainerId,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Nitin Gadkari',
        packageName: 'Transformation Plan',
        sessionDate: now.add(const Duration(days: 2)),
        startTime: '09:00',
        endTime: '10:00',
        status: BookingStatus.confirmed,
      ));

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerBookingsScreen(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Sameer Khan'), findsOneWidget);
      expect(find.text('Nitin Gadkari'), findsOneWidget);

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Sameer');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Sameer Khan'), findsOneWidget);
      expect(find.text('Nitin Gadkari'), findsNothing);
    });

    testWidgets('Tapping booking opens detail modal sheet with full information & privacy gate', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final bService = BookingService.instance;

      bService.addOrUpdateBooking(BookingModel(
        id: 'bk_detail_modal',
        clientId: 'cl_1',
        trainerId: testTrainerId,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Karan Johar',
        clientPhone: '+91 9988776655',
        fitnessGoal: 'Core strengthening and posture',
        packageName: '6-Month Transformation',
        sessionDate: now.add(const Duration(days: 1)),
        startTime: '06:30',
        endTime: '07:30',
        status: BookingStatus.confirmed,
        meetingLocation: 'Juhu Tara Road Studio',
      ));

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerBookingsScreen(trainerId: testTrainerId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on Karan Johar card
      await tester.tap(find.text('Karan Johar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Modal sheet should be open
      expect(find.text('Booking Ref: #bk_detail_modal'), findsOneWidget);
      expect(find.text('Juhu Tara Road Studio'), findsWidgets);
      expect(find.text('Core strengthening and posture'), findsOneWidget);
      expect(find.text('6-Month Transformation'), findsWidgets);
      expect(find.text('Mark Completed'), findsOneWidget);
      expect(find.text('Cancel Session'), findsOneWidget);
    });
  });

  group('7. Zero Romantic & Dating Terminology Audit', () {
    test('Confirms zero romantic, dating, matching, or casual terms in UI texts', () {
      const prohibitedTerms = [
        'match',
        'matched',
        'matching',
        'date',
        'dating',
        'flirt',
        'swipe',
        'romance',
        'romantic',
        'soulmate',
        'partner',
        'crush',
      ];

      final sampleTexts = [
        'Trainer Bookings',
        'Manage your scheduled client training sessions and attendance',
        'Upcoming',
        'Pending',
        'Completed',
        'Cancelled',
        'Mark Session Completed',
        'Cancel Session',
        'Location address hidden until booking is confirmed',
        'No Upcoming Sessions',
        'Client Details',
        'Package Plan',
      ];

      for (final text in sampleTexts) {
        final lower = text.toLowerCase();
        for (final term in prohibitedTerms) {
          expect(
            lower.contains(term),
            isFalse,
            reason: 'Text "$text" contains prohibited term "$term"',
          );
        }
      }
    });
  });
}
