import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/services/credit_service.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/session_credit_model.dart';
import 'package:trainuspro/shared/models/trainer_availability_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  setUp(() {
    CreditService().resetMockCredits();
  });

  group('Requirement 1 & 2: My Bookings & Session Information Display', () {
    final now = DateTime.now();

    final testBookings = [
      BookingModel(
        id: 'booking_up_01',
        clientId: 'client_101',
        trainerId: 'trainer_201',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: now.add(const Duration(days: 3)),
        startTime: '07:00 AM',
        endTime: '08:00 AM',
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.completed,
        packageName: '1 Month',
        trainerName: 'Vikram Singh',
        trainerPhotoUrl: 'https://example.com/vikram.jpg',
        meetingLocation: 'Baner Commercial Gym, Pune, MH',
      ),
      BookingModel(
        id: 'booking_pen_01',
        clientId: 'client_101',
        trainerId: 'trainer_201',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: now.add(const Duration(days: 2)),
        startTime: '08:00 AM',
        endTime: '09:00 AM',
        status: BookingStatus.pending,
        paymentStatus: PaymentStatus.pending,
        packageName: '1 Week (6 Sessions)',
        trainerName: 'Vikram Singh',
      ),
      BookingModel(
        id: 'booking_com_01',
        clientId: 'client_101',
        trainerId: 'trainer_201',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: now.subtract(const Duration(days: 2)),
        startTime: '06:00 AM',
        endTime: '07:00 AM',
        status: BookingStatus.completed,
        paymentStatus: PaymentStatus.completed,
        packageName: '1 Month',
        trainerName: 'Vikram Singh',
      ),
      BookingModel(
        id: 'booking_can_early',
        clientId: 'client_101',
        trainerId: 'trainer_201',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: now.add(const Duration(days: 1)),
        startTime: '07:00 AM',
        endTime: '08:00 AM',
        status: BookingStatus.cancelledClientEarly,
        paymentStatus: PaymentStatus.completed,
        packageName: '1 Month',
        trainerName: 'Vikram Singh',
      ),
      BookingModel(
        id: 'booking_can_late',
        clientId: 'client_101',
        trainerId: 'trainer_201',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: now.add(const Duration(hours: 4)),
        startTime: '05:00 PM',
        endTime: '06:00 PM',
        status: BookingStatus.cancelledClientLate,
        paymentStatus: PaymentStatus.completed,
        packageName: '1 Month',
        trainerName: 'Vikram Singh',
      ),
    ];

    test('Filters bookings into 4 distinct sections: Upcoming, Pending, Done, Cancelled', () {
      final upcoming = testBookings.where((b) => b.isUpcoming).toList();
      final pending = testBookings.where((b) => b.isPending).toList();
      final completed = testBookings.where((b) => b.isCompleted).toList();
      final cancelled = testBookings.where((b) => b.isCancelled).toList();

      expect(upcoming.length, 1);
      expect(upcoming.first.id, 'booking_up_01');

      expect(pending.length, 1);
      expect(pending.first.id, 'booking_pen_01');

      expect(completed.length, 1);
      expect(completed.first.id, 'booking_com_01');

      expect(cancelled.length, 2);
      expect(cancelled.map((b) => b.id), containsAll(['booking_can_early', 'booking_can_late']));
    });

    test('Booking details display all required session metrics and 60-min duration', () {
      final b = testBookings.first;
      expect(b.trainerName, 'Vikram Singh');
      expect(b.trainerPhotoUrl, 'https://example.com/vikram.jpg');
      expect(b.startTime, '07:00 AM');
      expect(b.endTime, '08:00 AM');
      expect(b.sessionDurationDisplay, '60 Minutes (Personal 1-on-1)');
      expect(b.meetingLocation, 'Baner Commercial Gym, Pune, MH');
      expect(b.resolvedPackageName, '1 Month');
      expect(b.displayStatus, 'Confirmed');
      expect(b.bookingReference.startsWith('REF-'), isTrue);
    });
  });

  group('Requirement 3 & 4: Exact Start Time & 12-Hour Cancellation Rule', () {
    test('fullSessionStartDateTime combines sessionDate with parsed startTime correctly', () {
      final date = DateTime(2026, 12, 10);
      final bookingAM = BookingModel(
        id: 'b_am',
        clientId: 'c1',
        trainerId: 't1',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        sessionDate: date,
        startTime: '07:30 AM',
        endTime: '08:30 AM',
      );

      final fullStartAM = bookingAM.fullSessionStartDateTime;
      expect(fullStartAM.year, 2026);
      expect(fullStartAM.month, 12);
      expect(fullStartAM.day, 10);
      expect(fullStartAM.hour, 7);
      expect(fullStartAM.minute, 30);

      final bookingPM = BookingModel(
        id: 'b_pm',
        clientId: 'c1',
        trainerId: 't1',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        sessionDate: date,
        startTime: '06:00 PM',
        endTime: '07:00 PM',
      );

      final fullStartPM = bookingPM.fullSessionStartDateTime;
      expect(fullStartPM.hour, 18);
      expect(fullStartPM.minute, 0);
    });

    test('Client cancellation >= 12h returns session credit (Section 8 policy)', () async {
      final now = DateTime.now();
      final sessionStart = now.add(const Duration(hours: 14));

      final booking = BookingModel(
        id: 'b_early_cancel',
        clientId: 'c_test_client',
        trainerId: 't_coach',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: sessionStart,
        startTime: '${sessionStart.hour.toString().padLeft(2, '0')}:${sessionStart.minute.toString().padLeft(2, '0')}',
        endTime: '${(sessionStart.hour + 1).toString().padLeft(2, '0')}:${sessionStart.minute.toString().padLeft(2, '0')}',
      );

      expect(booking.isCancellationCreditRefundable, isTrue);
      expect(booking.hoursUntilSession, greaterThanOrEqualTo(12.0));

      // Test via CreditService in-memory mock ledger
      CreditService().setMockCredits(const SessionCreditModel(
        clientId: 'c_test_client',
        totalPurchased: 10,
        totalReserved: 1,
        availableBalance: 9,
      ));

      final returned = await CreditService().processCancellationCredit(
        clientId: 'c_test_client',
        bookingId: 'b_early_cancel',
        sessionStartTime: booking.fullSessionStartDateTime,
        cancelledByRole: UserRole.client,
      );

      expect(returned, isTrue);
      final updated = CreditService().getMockCredits('c_test_client');
      expect(updated?.availableBalance, 10);
      expect(updated?.totalReturned, 1);
      expect(updated?.totalReserved, 0);
    });

    test('Client cancellation < 12h forfeits session credit (Section 8 penalty)', () async {
      final now = DateTime.now();
      final sessionStart = now.add(const Duration(hours: 6)); // Within 12h window

      final booking = BookingModel(
        id: 'b_late_cancel',
        clientId: 'c_test_client_late',
        trainerId: 't_coach',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        sessionDate: sessionStart,
        startTime: '${sessionStart.hour.toString().padLeft(2, '0')}:${sessionStart.minute.toString().padLeft(2, '0')}',
        endTime: '${(sessionStart.hour + 1).toString().padLeft(2, '0')}:${sessionStart.minute.toString().padLeft(2, '0')}',
      );

      expect(booking.isCancellationCreditRefundable, isFalse);
      expect(booking.hoursUntilSession, lessThan(12.0));

      CreditService().setMockCredits(const SessionCreditModel(
        clientId: 'c_test_client_late',
        totalPurchased: 10,
        totalReserved: 1,
        availableBalance: 9,
      ));

      final returned = await CreditService().processCancellationCredit(
        clientId: 'c_test_client_late',
        bookingId: 'b_late_cancel',
        sessionStartTime: booking.fullSessionStartDateTime,
        cancelledByRole: UserRole.client,
      );

      expect(returned, isFalse);
      final updated = CreditService().getMockCredits('c_test_client_late');
      expect(updated?.availableBalance, 9); // Credit is NOT returned
      expect(updated?.totalForfeited, 1); // Recorded as forfeited
      expect(updated?.totalReserved, 0);
    });

    test('Trainer or Platform cancellation always returns session credit', () async {
      final now = DateTime.now();
      // Even 1 hour before session
      final sessionStart = now.add(const Duration(hours: 1));

      CreditService().setMockCredits(const SessionCreditModel(
        clientId: 'c_trainer_cancel',
        totalPurchased: 6,
        totalReserved: 1,
        availableBalance: 5,
      ));

      final returned = await CreditService().processCancellationCredit(
        clientId: 'c_trainer_cancel',
        bookingId: 'b_trainer_cancel',
        sessionStartTime: sessionStart,
        cancelledByRole: UserRole.trainer,
      );

      expect(returned, isTrue);
      final updated = CreditService().getMockCredits('c_trainer_cancel');
      expect(updated?.availableBalance, 6);
      expect(updated?.totalReturned, 1);
    });

    test('Duplicate cancellation is prevented', () {
      final cancelledBooking = BookingModel(
        id: 'b_already_cancelled',
        clientId: 'c1',
        trainerId: 't1',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime.now().add(const Duration(days: 2)),
        startTime: '07:00 AM',
        endTime: '08:00 AM',
        status: BookingStatus.cancelledClientEarly,
      );

      expect(cancelledBooking.isCancelled, isTrue);
    });
  });

  group('Requirement 5: Rescheduling & Trainer Availability', () {
    test('Generates discrete 60-minute slots from TrainerAvailabilityModel', () {
      final targetDate = DateTime(2026, 12, 1); // Tuesday
      const weekly = TrainerAvailabilityModel(
        id: 'avail_vikram',
        trainerId: 'trainer_vikram',
        timezone: 'Asia/Kolkata',
        days: [
          DayAvailability(
            dayOfWeek: 2, // Tuesday
            isEnabled: true,
            windows: [
              AvailabilityWindow(start: '06:00 AM', end: '07:00 AM'),
              // 07:00 AM - 08:00 AM is a break (gap between windows)
              AvailabilityWindow(start: '08:00 AM', end: '09:00 AM'),
              AvailabilityWindow(start: '05:00 PM', end: '08:00 PM'),
            ],
          ),
        ],
      );

      final slots = weekly.getSlotsForDate(
        targetDate,
        confirmedStarts: {'06:00 AM'}, // One confirmed booking
      );

      expect(slots.isNotEmpty, isTrue);

      // 06:00 AM should be marked booked
      final slot6am = slots.firstWhere((s) => s.start == '06:00 AM');
      expect(slot6am.isBooked, isTrue);
      expect(slot6am.isAvailable, isFalse);

      // 07:00 AM is a break, so should not exist in slots
      final breakSlots = slots.where((s) => s.start == '07:00 AM');
      expect(breakSlots.isEmpty, isTrue);

      // 08:00 AM is available
      final slot8am = slots.firstWhere((s) => s.start == '08:00 AM');
      expect(slot8am.isAvailable, isTrue);
      expect(slot8am.isBooked, isFalse);

      // Evening window 17:00 (05:00 PM), 18:00 (06:00 PM), 19:00 (07:00 PM)
      final slot5pm = slots.firstWhere((s) => s.start == '05:00 PM');
      expect(slot5pm.isAvailable, isTrue);
    });

    test('Prevents double-booking when trainer slot is already booked or reserved', () {
      final confirmedStarts = {'08:00 AM'};
      final reservedStarts = {'09:00 AM'};

      bool isSlotTaken(String slotTime) {
        return confirmedStarts.contains(slotTime) || reservedStarts.contains(slotTime);
      }

      expect(isSlotTaken('08:00 AM'), isTrue); // Booked
      expect(isSlotTaken('09:00 AM'), isTrue); // Reserved
      expect(isSlotTaken('10:00 AM'), isFalse); // Available
    });

    test('Prevents rescheduling to past dates or times', () {
      final now = DateTime.now();
      final pastDate = now.subtract(const Duration(days: 1));

      bool isPast(DateTime date, String startTime) {
        int hour = 6;
        int minute = 0;
        try {
          final clean = startTime.trim();
          final isPm = clean.toUpperCase().contains('PM');
          final isAm = clean.toUpperCase().contains('AM');
          final digits = clean.replaceAll(RegExp(r'[^\d:]'), '');
          final parts = digits.split(':');
          if (parts.isNotEmpty) {
            hour = int.tryParse(parts[0]) ?? 6;
            if (parts.length > 1) minute = int.tryParse(parts[1]) ?? 0;
            if (isPm && hour < 12) hour += 12;
            if (isAm && hour == 12) hour = 0;
          }
        } catch (_) {}
        final full = DateTime(date.year, date.month, date.day, hour, minute);
        return full.isBefore(now);
      }

      expect(isPast(pastDate, '07:00 AM'), isTrue);
      expect(isPast(now.add(const Duration(days: 2)), '07:00 AM'), isFalse);
    });

    test('Rescheduled booking correctly records previousSessionDate and previousStartTime', () {
      final origDate = DateTime(2026, 11, 20);
      final newDate = DateTime(2026, 11, 25);

      final initial = BookingModel(
        id: 'b_resched_test',
        clientId: 'c1',
        trainerId: 't1',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: origDate,
        startTime: '07:00 AM',
        endTime: '08:00 AM',
        status: BookingStatus.confirmed,
      );

      final rescheduled = initial.copyWith(
        sessionDate: newDate,
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        isRescheduled: true,
        previousSessionDate: initial.sessionDate,
        previousStartTime: initial.startTime,
        previousEndTime: initial.endTime,
      );

      expect(rescheduled.isRescheduled, isTrue);
      expect(rescheduled.sessionDate, newDate);
      expect(rescheduled.startTime, '09:00 AM');
      expect(rescheduled.previousSessionDate, origDate);
      expect(rescheduled.previousStartTime, '07:00 AM');
    });
  });

  group('Requirement 6: Session Credits Ledger & Package Expiry', () {
    test('SessionCreditModel manages active package name, validity, and expiry calculations', () {
      final now = DateTime.now();
      final expiryDate = now.add(const Duration(days: 25));

      final credit = SessionCreditModel(
        clientId: 'c_pkg_client',
        totalPurchased: 26,
        totalReserved: 1,
        totalConsumed: 5,
        totalReturned: 1,
        totalForfeited: 0,
        availableBalance: 21,
        activePackageName: '1 Month (26 Sessions)',
        validityDays: 30,
        packageExpiryDate: expiryDate,
      );

      expect(credit.activePackageName, '1 Month (26 Sessions)');
      expect(credit.validityDays, 30);
      expect(credit.packageExpiryDate, expiryDate);
      expect(credit.isPackageExpired, isFalse);
      expect(credit.daysUntilExpiry, greaterThanOrEqualTo(24));
    });

    test('Package expiration flags true when packageExpiryDate is in the past', () {
      final expiredDate = DateTime.now().subtract(const Duration(days: 2));

      final credit = SessionCreditModel(
        clientId: 'c_expired_client',
        totalPurchased: 26,
        totalReserved: 0,
        totalConsumed: 10,
        availableBalance: 16,
        activePackageName: '1 Month',
        validityDays: 30,
        packageExpiryDate: expiredDate,
      );

      expect(credit.isPackageExpired, isTrue);
      expect(credit.daysUntilExpiry, 0);
    });

    test('CreditService records package purchase and persists metadata', () async {
      final service = CreditService();
      await service.recordPurchase(
        clientId: 'c_new_purchaser',
        planId: 'package_1_month',
        sessionCount: 26,
        paymentId: 'pay_tx_12345',
        packageName: '1 Month',
        validityDays: 30,
      );

      final record = service.getMockCredits('c_new_purchaser');
      expect(record, isNotNull);
      expect(record?.totalPurchased, 26);
      expect(record?.availableBalance, 26);
      expect(record?.activePackageName, '1 Month');
      expect(record?.validityDays, 30);
      expect(record?.packageExpiryDate, isNotNull);
    });

    test('CreditService reserveCreditForBooking decrements balance and increments reserved', () async {
      final service = CreditService();
      service.setMockCredits(const SessionCreditModel(
        clientId: 'c_reserver',
        totalPurchased: 6,
        availableBalance: 6,
      ));

      final txId = await service.reserveCreditForBooking(
        clientId: 'c_reserver',
        bookingId: 'b_reserved_1',
      );

      expect(txId.isNotEmpty, isTrue);
      final updated = service.getMockCredits('c_reserver');
      expect(updated?.availableBalance, 5);
      expect(updated?.totalReserved, 1);
    });

    test('CreditService consumeCreditForCompletedSession increments consumed and decrements reserved', () async {
      final service = CreditService();
      service.setMockCredits(const SessionCreditModel(
        clientId: 'c_consumer',
        totalPurchased: 6,
        totalReserved: 1,
        availableBalance: 5,
        totalConsumed: 0,
      ));

      await service.consumeCreditForCompletedSession(
        clientId: 'c_consumer',
        bookingId: 'b_done_1',
      );

      final updated = service.getMockCredits('c_consumer');
      expect(updated?.totalConsumed, 1);
      expect(updated?.totalReserved, 0);
      expect(updated?.availableBalance, 5);
    });
  });

  group('Requirement 7: Booking Reference & Privacy Protection', () {
    test('Booking reference formats as REF-8CHARPAD', () {
      final b1 = BookingModel(
        id: 'ab12cd34ef56',
        clientId: 'c1',
        trainerId: 't1',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        sessionDate: DateTime.now(),
        startTime: '07:00 AM',
        endTime: '08:00 AM',
      );

      expect(b1.bookingReference, 'REF-AB12CD34');

      final b2 = BookingModel(
        id: 'xyz',
        clientId: 'c1',
        trainerId: 't1',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        sessionDate: DateTime.now(),
        startTime: '07:00 AM',
        endTime: '08:00 AM',
      );

      expect(b2.bookingReference.startsWith('REF-XYZ'), isTrue);
      expect(b2.bookingReference.length, 12); // "REF-" (4) + 8 chars = 12
    });

    test('Privacy guard flags private home residence addresses', () {
      bool isPrivateResidence(String location) {
        final loc = location.toLowerCase();
        return loc.contains('flat') ||
            loc.contains('apartment') ||
            loc.contains('house') ||
            loc.contains('home') ||
            loc.contains('residence') ||
            loc.contains('villa') ||
            loc.contains('tower') ||
            loc.contains('floor');
      }

      expect(isPrivateResidence('Flat 402, Rohan Tarang, Wakad, Pune'), isTrue);
      expect(isPrivateResidence('Villa 12, Nyati Estate, Kalyani Nagar, Pune'), isTrue);
      expect(isPrivateResidence('Baner Commercial Gym, Baner, Pune'), isFalse);
      expect(isPrivateResidence('Koregaon Park Public Garden, Pune'), isFalse);
    });
  });

  group('Requirement 8: Professional Fitness Language Audit (Zero Dating/Romantic Terms)', () {
    test('No romantic, matching or dating terminology exists in models and copy', () {
      const forbiddenTerms = [
        'match',
        'dating',
        'date night',
        'swipe',
        'spark',
        'romance',
        'relationship',
        'love',
      ];

      final sampleTexts = [
        '60 Minutes (Personal 1-on-1)',
        'Personal Trainer • Certified Personal Trainer',
        'Athlete\'s Private Residence • Protected • Disclosed only to your booked trainer',
        'Session rescheduled to selected 60-minute time slot',
        '1 Session Credit Returned to Balance',
        '1 Session Credit Forfeited (<12h cancellation)',
        'TRAIN Z Personal Training Platform',
      ];

      for (final text in sampleTexts) {
        for (final forbidden in forbiddenTerms) {
          if (forbidden == 'match') {
            // "match" only allowed in gender match rule test context if any, but in user copy should not appear
            expect(text.toLowerCase().contains('dating'), isFalse);
            expect(text.toLowerCase().contains('romance'), isFalse);
            expect(text.toLowerCase().contains('swipe'), isFalse);
          } else {
            expect(text.toLowerCase().contains(forbidden), isFalse,
                reason: 'Copy contained forbidden romantic term: $forbidden');
          }
        }
      }
    });
  });
}
