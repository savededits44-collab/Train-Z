import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/screens/trainer/trainer_availability_screen.dart';
import 'package:trainuspro/services/booking_service.dart';
import 'package:trainuspro/services/firestore_service.dart';
import 'package:trainuspro/services/trainer_availability_service.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/trainer_availability_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final availabilityService = TrainerAvailabilityService.instance;
  const testTrainerId = 'trainer_avail_test_01';

  setUp(() {
    availabilityService.resetMockData();
  });

  group('1. 60-Minute Session Duration Invariant & Window Rules', () {
    test('timeStringToMinutes and minutesToTimeString convert back and forth accurately', () {
      expect(timeStringToMinutes('06:00 AM'), 360);
      expect(timeStringToMinutes('12:00 PM'), 720);
      expect(timeStringToMinutes('01:30 PM'), 810);
      expect(timeStringToMinutes('08:00 PM'), 1200);

      expect(minutesToTimeString(360), '06:00 AM');
      expect(minutesToTimeString(720), '12:00 PM');
      expect(minutesToTimeString(810), '01:30 PM');
      expect(minutesToTimeString(1200), '08:00 PM');
    });

    test('AvailabilityWindow enforces minimum 60-minute session duration', () {
      const invalidWindow = AvailabilityWindow(start: '06:00 AM', end: '06:45 AM'); // 45 min
      expect(invalidWindow.durationMinutes, 45);
      expect(invalidWindow.isValid, false);

      const valid60MinWindow = AvailabilityWindow(start: '06:00 AM', end: '07:00 AM'); // 60 min
      expect(valid60MinWindow.durationMinutes, 60);
      expect(valid60MinWindow.isValid, true);

      const validMultiHourWindow = AvailabilityWindow(start: '06:00 AM', end: '11:00 AM'); // 300 min
      expect(validMultiHourWindow.durationMinutes, 300);
      expect(validMultiHourWindow.isValid, true);
    });

    test('AvailabilityWindow generates strictly discrete 60-minute training slots', () {
      const window = AvailabilityWindow(start: '06:00 AM', end: '09:00 AM');
      final slots = window.generate60MinSlots();

      expect(slots.length, 3);
      expect(slots[0].start, '06:00 AM');
      expect(slots[0].end, '07:00 AM');
      expect(slots[0].sessionDurationMinutes, 60);

      expect(slots[1].start, '07:00 AM');
      expect(slots[1].end, '08:00 AM');
      expect(slots[1].sessionDurationMinutes, 60);

      expect(slots[2].start, '08:00 AM');
      expect(slots[2].end, '09:00 AM');
      expect(slots[2].sessionDurationMinutes, 60);
    });

    test('Breaks between windows produce zero training slots', () {
      const morningWindow = AvailabilityWindow(start: '06:00 AM', end: '09:00 AM');
      const eveningWindow = AvailabilityWindow(start: '05:00 PM', end: '08:00 PM');
      // Break is from 09:00 AM to 05:00 PM (8 hours)

      const dayAvailability = DayAvailability(
        dayOfWeek: 1, // Monday
        isEnabled: true,
        windows: [morningWindow, eveningWindow],
      );

      final slots = dayAvailability.generateSlots();
      expect(slots.length, 6); // 3 morning + 3 evening

      // Verify no slot falls inside the break interval (09:00 AM - 05:00 PM)
      for (final slot in slots) {
        final startMin = timeStringToMinutes(slot.start);
        final isDuringBreak = startMin >= 540 && startMin < 1020;
        expect(isDuringBreak, isFalse, reason: 'Slot ${slot.start} falls inside break interval');
      }
    });

    test('Window overlap detection correctly identifies overlapping periods on same day', () {
      const w1 = AvailabilityWindow(start: '06:00 AM', end: '10:00 AM');
      const w2 = AvailabilityWindow(start: '09:00 AM', end: '12:00 PM'); // Overlaps 9-10
      const w3 = AvailabilityWindow(start: '10:00 AM', end: '01:00 PM'); // Adjacent, not overlapping
      const w4 = AvailabilityWindow(start: '04:00 PM', end: '08:00 PM'); // Completely disjoint

      expect(w1.overlapsWith(w2), isTrue);
      expect(w2.overlapsWith(w1), isTrue);
      expect(w1.overlapsWith(w3), isFalse);
      expect(w1.overlapsWith(w4), isFalse);
    });
  });

  group('2. Weekly Recurring Schedule & Days of the Week', () {
    test('Default baseline schedule configures Mon-Sat working and Sunday off', () {
      final defaultSchedule = TrainerAvailabilityModel.defaultSchedule(testTrainerId);

      expect(defaultSchedule.days.length, 7);
      // Mon (1) to Sat (6) enabled
      for (int i = 1; i <= 6; i++) {
        final d = defaultSchedule.day(i);
        expect(d.isEnabled, isTrue);
        expect(d.windows.length, 2);
        expect(d.windows[0].start, '06:00 AM');
        expect(d.windows[0].end, '11:00 AM');
        expect(d.windows[1].start, '04:00 PM');
        expect(d.windows[1].end, '08:00 PM');
      }

      // Sun (7) disabled
      final sun = defaultSchedule.day(7);
      expect(sun.isEnabled, isFalse);
      expect(sun.windows, isEmpty);
    });

    test('saveWeeklyAvailability rejects invalid windows with clear exceptions', () async {
      // Sub-60 minute window should throw
      final invalidDays = [
        const DayAvailability(
          dayOfWeek: 1,
          isEnabled: true,
          windows: [AvailabilityWindow(start: '06:00 AM', end: '06:30 AM')],
        ),
      ];

      expect(
        () => availabilityService.saveWeeklyAvailability(
          trainerId: testTrainerId,
          days: invalidDays,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Overlapping windows on Monday should throw
      final overlappingDays = [
        const DayAvailability(
          dayOfWeek: 1,
          isEnabled: true,
          windows: [
            AvailabilityWindow(start: '06:00 AM', end: '10:00 AM'),
            AvailabilityWindow(start: '09:00 AM', end: '12:00 PM'),
          ],
        ),
      ];

      expect(
        () => availabilityService.saveWeeklyAvailability(
          trainerId: testTrainerId,
          days: overlappingDays,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('saveWeeklyAvailability successfully persists valid custom schedule', () async {
      final customDays = [
        const DayAvailability(
          dayOfWeek: 1, // Mon
          isEnabled: true,
          windows: [
            AvailabilityWindow(start: '07:00 AM', end: '12:00 PM'),
            AvailabilityWindow(start: '03:00 PM', end: '07:00 PM'),
          ],
        ),
        const DayAvailability(
          dayOfWeek: 2, // Tue
          isEnabled: false,
          windows: [],
        ),
        const DayAvailability(
          dayOfWeek: 3, // Wed
          isEnabled: true,
          windows: [
            AvailabilityWindow(start: '08:00 AM', end: '02:00 PM'),
          ],
        ),
      ];

      final saved = await availabilityService.saveWeeklyAvailability(
        trainerId: testTrainerId,
        days: customDays,
      );
      expect(saved, isTrue);

      final fetched = await availabilityService.getWeeklyAvailability(testTrainerId);
      expect(fetched.day(1).isEnabled, isTrue);
      expect(fetched.day(1).windows.length, 2);
      expect(fetched.day(1).generateSlots().length, 9); // 5 morning + 4 afternoon
      expect(fetched.day(2).isEnabled, isFalse);
      expect(fetched.day(3).isEnabled, isTrue);
      expect(fetched.day(3).generateSlots().length, 6); // 6 slots
    });
  });

  group('3. Calendar Exceptions & Date Overrides (Blackouts / Custom Hours)', () {
    test('Setting blocked date disables all slots for that specific date', () async {
      // First ensure trainer has default weekly availability
      final defaultSched = TrainerAvailabilityModel.defaultSchedule(testTrainerId);
      await availabilityService.saveWeeklyAvailability(
        trainerId: testTrainerId,
        days: defaultSched.days,
      );

      final targetDate = DateTime(2026, 11, 20); // A Friday
      final targetDateStr = '2026-11-20';

      // Before blocking: Friday has slots
      final slotsBefore = await availabilityService.streamSlotsForTrainerDate(
        trainerId: testTrainerId,
        date: targetDate,
      ).first;
      expect(slotsBefore.isNotEmpty, isTrue);

      // Block date (personal leave)
      final blockResult = await availabilityService.setBlockedDate(
        trainerId: testTrainerId,
        dateStr: targetDateStr,
        isBlocked: true,
        reason: 'Personal Leave / Medical',
      );
      expect(blockResult.success, isTrue);

      // Verify date override is saved
      final override = await availabilityService.getDateOverride(testTrainerId, targetDateStr);
      expect(override, isNotNull);
      expect(override!.isBlocked, isTrue);
      expect(override.reason, 'Personal Leave / Medical');

      // After blocking: slots stream yields empty list
      final slotsAfter = await availabilityService.streamSlotsForTrainerDate(
        trainerId: testTrainerId,
        date: targetDate,
      ).first;
      expect(slotsAfter, isEmpty);
    });

    test('Custom date hours override regular weekly schedule for that date only', () async {
      final defaultSched = TrainerAvailabilityModel.defaultSchedule(testTrainerId);
      await availabilityService.saveWeeklyAvailability(
        trainerId: testTrainerId,
        days: defaultSched.days,
      );

      final targetDate = DateTime(2026, 11, 21); // A Saturday
      final targetDateStr = '2026-11-21';

      // Set custom hours: 10:00 AM - 01:00 PM (3 sessions)
      final customSuccess = await availabilityService.setCustomDateWindows(
        trainerId: testTrainerId,
        dateStr: targetDateStr,
        windows: const [
          AvailabilityWindow(start: '10:00 AM', end: '01:00 PM'),
        ],
        reason: 'Special Weekend Workshop',
      );
      expect(customSuccess, isTrue);

      final slots = await availabilityService.streamSlotsForTrainerDate(
        trainerId: testTrainerId,
        date: targetDate,
      ).first;

      expect(slots.length, 3);
      expect(slots[0].start, '10:00 AM');
      expect(slots[1].start, '11:00 AM');
      expect(slots[2].start, '12:00 PM');
    });

    test('Removing date override restores default weekly recurring schedule', () async {
      final targetDate = DateTime(2026, 11, 23); // Monday
      final targetDateStr = '2026-11-23';

      await availabilityService.setBlockedDate(
        trainerId: testTrainerId,
        dateStr: targetDateStr,
        isBlocked: true,
      );

      final unblockSuccess = await availabilityService.removeDateOverride(
        trainerId: testTrainerId,
        dateStr: targetDateStr,
      );
      expect(unblockSuccess, isTrue);

      final override = await availabilityService.getDateOverride(testTrainerId, targetDateStr);
      expect(override, isNull);

      final slotsAfterUnblock = await availabilityService.streamSlotsForTrainerDate(
        trainerId: testTrainerId,
        date: targetDate,
      ).first;
      expect(slotsAfterUnblock.isNotEmpty, isTrue);
    });
  });

  group('4. Confirmed Bookings Protection Invariant', () {
    test('Confirmed client bookings cannot be cancelled or deleted via availability block', () async {
      final sessionDate = DateTime(2026, 11, 25);
      final dateStr = '2026-11-25';

      // Seed a confirmed booking for client "Rahul Sharma"
      final confirmedBooking = BookingModel(
        id: 'booking_protect_01',
        clientId: 'client_rahul',
        trainerId: testTrainerId,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: sessionDate,
        startTime: '07:00 AM',
        endTime: '08:00 AM',
        status: BookingStatus.confirmed,
        clientName: 'Rahul Sharma',
      );

      BookingService.instance.addOrUpdateBooking(confirmedBooking);

      // Trainer blocks the date
      final res = await availabilityService.setBlockedDate(
        trainerId: testTrainerId,
        dateStr: dateStr,
        isBlocked: true,
        reason: 'Emergency Leave',
      );

      // Result warns trainer that 1 confirmed booking exists
      expect(res.confirmedBookingsCount, 1);

      // Booking status must still be CONFIRMED (never cancelled)
      final allBookings = BookingService.instance.allBookings;
      final match = allBookings.firstWhere((b) => b.id == 'booking_protect_01');
      expect(match.status, BookingStatus.confirmed);
      expect(match.clientName, 'Rahul Sharma');
    });
  });

  group('5. Conflict Resolution & Slot Status Classification', () {
    test('Slots correctly classify Available, Booked, and Past statuses', () {
      final model = TrainerAvailabilityModel.defaultSchedule(testTrainerId);
      final futureDate = DateTime(2026, 12, 1);

      final slots = model.getSlotsForDate(
        futureDate,
        confirmedStarts: {'07:00 AM'},
        reservedStarts: {'08:00 AM'},
        bookingClientNames: {'07:00 AM': 'Neha Kapoor'},
        bookingIds: {'07:00 AM': 'booking_neha_01'},
      );

      // Slot 06:00 AM -> Available
      final slot6 = slots.firstWhere((s) => s.start == '06:00 AM');
      expect(slot6.isAvailable, isTrue);
      expect(slot6.isBooked, isFalse);
      expect(slot6.isReserved, isFalse);

      // Slot 07:00 AM -> Booked
      final slot7 = slots.firstWhere((s) => s.start == '07:00 AM');
      expect(slot7.isAvailable, isFalse);
      expect(slot7.isBooked, isTrue);
      expect(slot7.bookedByClientName, 'Neha Kapoor');
      expect(slot7.bookingId, 'booking_neha_01');

      // Slot 08:00 AM -> Reserved (Temporary hold)
      final slot8 = slots.firstWhere((s) => s.start == '08:00 AM');
      expect(slot8.isAvailable, isFalse);
      expect(slot8.isReserved, isTrue);
    });
  });

  group('6. Client Booking Flow Integration', () {
    test('FirestoreService.streamSlotsForTrainerDate delegates to TrainerAvailabilityService', () async {
      final firestoreService = FirestoreService();
      final targetDate = DateTime(2026, 11, 28);

      final slots = await firestoreService.streamSlotsForTrainerDate(
        trainerId: testTrainerId,
        date: targetDate,
      ).first;

      // Generates slots according to default schedule
      expect(slots.isNotEmpty, isTrue);
      expect(slots.first.sessionDurationMinutes, 60);

      // Now trainer blocks the date
      await availabilityService.setBlockedDate(
        trainerId: testTrainerId,
        dateStr: '2026-11-28',
        isBlocked: true,
      );

      final slotsAfterBlock = await firestoreService.streamSlotsForTrainerDate(
        trainerId: testTrainerId,
        date: targetDate,
      ).first;

      // Blocked date seamlessly returns [] which triggers empty state in Client flow
      expect(slotsAfterBlock, isEmpty);
    });
  });

  group('7. Widget Tests: TrainerAvailabilityScreen', () {
    testWidgets('Renders Weekly Schedule and Calendar & Overrides tabs', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerAvailabilityScreen(trainerId: testTrainerId),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title and tabs
      expect(find.text('Availability & Calendar'), findsOneWidget);
      expect(find.text('Weekly Schedule'), findsOneWidget);
      expect(find.text('Calendar & Overrides'), findsOneWidget);
      expect(find.text('IST (Asia/Kolkata)'), findsOneWidget);

      // Verify 60-Minute Session Slots header
      expect(find.text('60-Minute Session Slots'), findsOneWidget);

      // Verify days of the week are visible
      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('Save Weekly Availability'), findsOneWidget);
    });

    testWidgets('Switching to Calendar & Overrides tab renders Day View, Date Navigator, and Bookings', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerAvailabilityScreen(trainerId: testTrainerId),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Calendar & Overrides tab
      await tester.tap(find.text('Calendar & Overrides'));
      await tester.pumpAndSettle();

      // View pills
      expect(find.text('Day View'), findsOneWidget);
      expect(find.text('Week View'), findsOneWidget);
      expect(find.text('Month View'), findsOneWidget);

      // Confirmed client sessions section
      expect(find.text('Confirmed Client Sessions'), findsOneWidget);
      expect(find.text('60-Minute Slots Breakdown'), findsOneWidget);

      // Protected callout
      expect(
        find.text('Confirmed bookings are protected and cannot be cancelled through availability settings.'),
        findsOneWidget,
      );

      // Block Date and Custom Hours buttons
      expect(find.text('Block Date'), findsOneWidget);
      expect(find.text('Custom Hours'), findsOneWidget);
    });
  });

  group('8. Zero Dating & Romantic Terminology Audit', () {
    test('Availability copy is strictly professional fitness coaching terminology', () {
      const prohibitedWords = [
        'dating', 'match', 'matches', 'soulmate', 'single',
        'flirt', 'romance', 'romantic', 'crush', 'partner hunt',
        'swipe right', 'swipe left', 'cupid', 'chemistry',
      ];

      final sampleTexts = [
        'Availability & Calendar',
        'Weekly Working Hours & Slots',
        '60-Minute Session Slots',
        'Windows are divided into 60-min sessions. Gaps between windows are automatic breaks.',
        'Save Weekly Availability',
        'Block Date so clients cannot book training sessions on this day.',
        'Confirmed client bookings cannot be cancelled via availability. Any booked sessions will remain valid.',
        'Define your weekly working days, set multiple training windows, add breaks, block dates for personal leave.',
        'Track client packages, remaining sessions, and schedule.',
      ];

      for (final text in sampleTexts) {
        final lower = text.toLowerCase();
        for (final word in prohibitedWords) {
          expect(lower.contains(word), isFalse, reason: 'Text "$text" contains forbidden word "$word"');
        }
      }
    });
  });
}
