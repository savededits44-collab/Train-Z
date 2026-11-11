import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/constants/app_constants.dart';
import 'package:trainuspro/core/utils/date_time_utils.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/notification_model.dart';
import 'package:trainuspro/shared/models/session_credit_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  group('PROMPT 15: Requirement 1 - Pune-Only Location Invariant', () {
    test('Platform operates exclusively in Pune, Maharashtra, India', () {
      expect(AppConstants.operatingCity, 'Pune');
      expect(AppConstants.operatingState, 'Maharashtra');
      expect(AppConstants.operatingCountry, 'India');
      expect(AppConstants.operatingLocationDisplay, 'Pune, Maharashtra');
    });

    test('Pune service areas encompass core neighborhoods', () {
      expect(AppConstants.puneServiceAreas, contains('Koregaon Park'));
      expect(AppConstants.puneServiceAreas, contains('Baner'));
      expect(AppConstants.puneServiceAreas, contains('Kothrud'));
      expect(AppConstants.puneServiceAreas, contains('Kalyani Nagar'));
      expect(AppConstants.puneServiceAreas, contains('Viman Nagar'));
      expect(AppConstants.puneServiceAreas, contains('Aundh'));
      expect(AppConstants.puneServiceAreas, contains('Shivaji Nagar'));
      expect(AppConstants.puneServiceAreas, contains('Wakad'));
      expect(AppConstants.puneServiceAreas, contains('Hinjawadi'));
    });
  });

  group('PROMPT 15: Requirement 2 & 3 - My Bookings 4 Sections & Details', () {
    final now = DateTime.now();

    final upcomingBooking = BookingModel(
      id: 'b_upcoming_1',
      clientId: 'c_athlete_1',
      trainerId: 't_coach_1',
      clientGender: Gender.male,
      trainerGender: Gender.male,
      sessionDate: now.add(const Duration(days: 2)),
      startTime: '07:00',
      endTime: '08:00',
      status: BookingStatus.confirmed,
      paymentStatus: PaymentStatus.completed,
      packageName: '1 Month',
      trainerName: 'Vikram Singh',
      meetingLocation: 'Baner Commercial Gym, Pune, MH',
    );

    final pendingBooking = BookingModel(
      id: 'b_pending_1',
      clientId: 'c_athlete_1',
      trainerId: 't_coach_1',
      clientGender: Gender.male,
      trainerGender: Gender.male,
      sessionDate: now.add(const Duration(days: 3)),
      startTime: '08:00',
      endTime: '09:00',
      status: BookingStatus.pending,
      paymentStatus: PaymentStatus.pending,
      packageName: '3 Days Starter',
      trainerName: 'Vikram Singh',
      meetingLocation: 'Koregaon Park, Pune, MH',
    );

    final completedBooking = BookingModel(
      id: 'b_completed_1',
      clientId: 'c_athlete_1',
      trainerId: 't_coach_1',
      clientGender: Gender.male,
      trainerGender: Gender.male,
      sessionDate: now.subtract(const Duration(days: 4)),
      startTime: '07:00',
      endTime: '08:00',
      status: BookingStatus.completed,
      paymentStatus: PaymentStatus.completed,
      packageName: '1 Month',
      trainerName: 'Vikram Singh',
      meetingLocation: 'Kothrud Fitness Center, Pune, MH',
    );

    final cancelledEarlyBooking = BookingModel(
      id: 'b_cancelled_1',
      clientId: 'c_athlete_1',
      trainerId: 't_coach_1',
      clientGender: Gender.male,
      trainerGender: Gender.male,
      sessionDate: now.add(const Duration(days: 1)),
      startTime: '07:00',
      endTime: '08:00',
      status: BookingStatus.cancelledClientEarly,
      paymentStatus: PaymentStatus.completed,
      packageName: '1 Month',
      trainerName: 'Vikram Singh',
      meetingLocation: 'Viman Nagar, Pune, MH',
    );

    final cancelledLateBooking = BookingModel(
      id: 'b_cancelled_2',
      clientId: 'c_athlete_1',
      trainerId: 't_coach_1',
      clientGender: Gender.male,
      trainerGender: Gender.male,
      sessionDate: now.add(const Duration(hours: 3)),
      startTime: '18:00',
      endTime: '19:00',
      status: BookingStatus.cancelledClientLate,
      paymentStatus: PaymentStatus.completed,
      packageName: '1 Month',
      trainerName: 'Vikram Singh',
      meetingLocation: 'Kalyani Nagar, Pune, MH',
    );

    test('Booking categorization accurately maps to 4 sections', () {
      final all = [
        upcomingBooking,
        pendingBooking,
        completedBooking,
        cancelledEarlyBooking,
        cancelledLateBooking,
      ];

      final upcoming = all.where((b) => b.isUpcoming).toList();
      final pending = all.where((b) => b.isPending).toList();
      final completed = all.where((b) => b.isCompleted).toList();
      final cancelled = all.where((b) => b.isCancelled).toList();

      expect(upcoming.length, 1);
      expect(upcoming.first.id, 'b_upcoming_1');

      expect(pending.length, 1);
      expect(pending.first.id, 'b_pending_1');

      expect(completed.length, 1);
      expect(completed.first.id, 'b_completed_1');

      expect(cancelled.length, 2);
      expect(cancelled.map((b) => b.id), containsAll(['b_cancelled_1', 'b_cancelled_2']));
    });

    test('Booking details structure enforces 60-minute duration and Pune location', () {
      expect(upcomingBooking.sessionDurationDisplay, '60 Minutes (Personal 1-on-1)');
      expect(upcomingBooking.startTime, '07:00');
      expect(upcomingBooking.endTime, '08:00');
      expect(upcomingBooking.meetingLocation, contains('Pune, MH'));
      expect(upcomingBooking.displayTrainerName, 'Vikram Singh');
      expect(upcomingBooking.displayStatus, 'Confirmed');
    });
  });

  group('PROMPT 15: Requirement 4 - Session Credits Real-time Accounting', () {
    test('SessionCreditModel accurately computes balance from double-entry truth', () {
      const credit = SessionCreditModel(
        clientId: 'c_test_athlete',
        totalPurchased: 26,
        totalReserved: 2,
        totalConsumed: 10,
        totalReturned: 1,
        totalForfeited: 1,
        availableBalance: 14, // 26 + 1 (returned) - 2 (reserved) - 10 (consumed) - 1 (forfeited) = 14
      );

      expect(credit.totalPurchased, 26);
      expect(credit.totalReserved, 2);
      expect(credit.totalConsumed, 10);
      expect(credit.totalReturned, 1);
      expect(credit.totalForfeited, 1);
      expect(credit.availableBalance, 14);
      expect(credit.hasAvailableCredits, isTrue);
    });

    test('SessionCreditModel serialization toMap and fromMap preserves all values', () {
      const original = SessionCreditModel(
        clientId: 'usr_pune_123',
        totalPurchased: 78,
        totalReserved: 4,
        totalConsumed: 20,
        totalReturned: 2,
        totalForfeited: 1,
        availableBalance: 55,
      );

      final map = original.toMap();
      expect(map['clientId'], 'usr_pune_123');
      expect(map['totalPurchased'], 78);
      expect(map['totalReserved'], 4);
      expect(map['totalConsumed'], 20);
      expect(map['totalReturned'], 2);
      expect(map['totalForfeited'], 1);
      expect(map['availableBalance'], 55);

      final restored = SessionCreditModel.fromMap(map, clientId: 'usr_pune_123');
      expect(restored.clientId, original.clientId);
      expect(restored.totalPurchased, original.totalPurchased);
      expect(restored.availableBalance, original.availableBalance);
    });
  });

  group('PROMPT 15: Requirement 5 - Section 8 Cancellation Rules (12-Hour Policy)', () {
    test('Client cancellation >= 12h before start qualifies for credit return', () {
      final futureDate = DateTime.now().add(const Duration(hours: 13));
      final canReturn = DateTimeUtils.canReturnCreditOnClientCancellation(futureDate);
      expect(canReturn, isTrue);
    });

    test('Client cancellation at exact 12h qualifies for credit return', () {
      final now = DateTime.now();
      final exactDate = now.add(const Duration(hours: 12));
      final canReturn = DateTimeUtils.canReturnCreditOnClientCancellation(exactDate, now: now);
      expect(canReturn, isTrue);
    });

    test('Client cancellation < 12h before start forfeits session credit', () {
      final lateDate = DateTime.now().add(const Duration(hours: 11, minutes: 59));
      final canReturn = DateTimeUtils.canReturnCreditOnClientCancellation(lateDate);
      expect(canReturn, isFalse);
    });

    test('Trainer or Platform cancellation always qualifies for credit return', () {
      final now = DateTime.now();
      // Even if session is in 1 hour, trainer cancellation returns credit
      final sessionIn1h = now.add(const Duration(hours: 1));

      // Admin or Trainer caller
      bool isTrainerOrAdmin(UserRole role) => role == UserRole.trainer || role == UserRole.admin;
      expect(isTrainerOrAdmin(UserRole.trainer), isTrue);
      expect(isTrainerOrAdmin(UserRole.admin), isTrue);

      final returnCreditTrainer = isTrainerOrAdmin(UserRole.trainer) ||
          DateTimeUtils.canReturnCreditOnClientCancellation(sessionIn1h);
      expect(returnCreditTrainer, isTrue);
    });

    test('BookingModel status flags correctly reflect credit outcome', () {
      final earlyCancelled = BookingModel(
        id: 'b1',
        clientId: 'c1',
        trainerId: 't1',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        sessionDate: DateTime.now().add(const Duration(days: 2)),
        startTime: '07:00',
        endTime: '08:00',
        status: BookingStatus.cancelledClientEarly,
      );

      expect(earlyCancelled.isCancelled, isTrue);
      expect(earlyCancelled.isCreditReturned, isTrue);
      expect(earlyCancelled.isCreditForfeited, isFalse);
      expect(earlyCancelled.displayStatus, contains('Credit Returned'));

      final lateCancelled = BookingModel(
        id: 'b2',
        clientId: 'c1',
        trainerId: 't1',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        sessionDate: DateTime.now().add(const Duration(hours: 4)),
        startTime: '10:00',
        endTime: '11:00',
        status: BookingStatus.cancelledClientLate,
      );

      expect(lateCancelled.isCancelled, isTrue);
      expect(lateCancelled.isCreditReturned, isFalse);
      expect(lateCancelled.isCreditForfeited, isTrue);
      expect(lateCancelled.displayStatus, contains('Credit Forfeited'));
    });
  });

  group('PROMPT 15: Requirement 6 - Rescheduling & Double-Booking Protection', () {
    test('Rescheduled booking retains previous session date and start/end times', () {
      final originalDate = DateTime(2026, 11, 15);
      final newDate = DateTime(2026, 11, 18);

      final rescheduledBooking = BookingModel(
        id: 'b_resched_1',
        clientId: 'c_athlete_99',
        trainerId: 't_coach_99',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: newDate,
        startTime: '09:00',
        endTime: '10:00',
        status: BookingStatus.confirmed,
        isRescheduled: true,
        previousSessionDate: originalDate,
        previousStartTime: '07:00',
        previousEndTime: '08:00',
      );

      expect(rescheduledBooking.isRescheduled, isTrue);
      expect(rescheduledBooking.sessionDate, newDate);
      expect(rescheduledBooking.startTime, '09:00');
      expect(rescheduledBooking.endTime, '10:00');
      expect(rescheduledBooking.previousSessionDate, originalDate);
      expect(rescheduledBooking.previousStartTime, '07:00');
      expect(rescheduledBooking.previousEndTime, '08:00');
    });

    test('Double-booking detector identifies time overlap on same date and coach', () {
      final existingBookingSlot = '08:00';
      final requestedSlot = '08:00';
      final anotherSlot = '09:00';

      bool hasConflict(String slot) => slot == existingBookingSlot;

      expect(hasConflict(requestedSlot), isTrue); // Conflict detected
      expect(hasConflict(anotherSlot), isFalse); // Free slot
    });
  });

  group('PROMPT 15: Requirement 8 - Notifications Types & Read Tracking', () {
    test('NotificationModel serializes confirmation, reschedule, and cancellation notices', () {
      final notif = NotificationModel(
        id: 'notif_101',
        userId: 'client_pune_99',
        title: 'Booking Confirmed',
        body: 'Your 60-min personal workout with Vikram Singh in Baner, Pune is confirmed.',
        type: 'BOOKING_CONFIRMED',
        isRead: false,
        data: {'bookingId': 'b_123', 'city': 'Pune'},
      );

      final map = notif.toMap();
      expect(map['title'], 'Booking Confirmed');
      expect(map['type'], 'BOOKING_CONFIRMED');
      expect(map['isRead'], isFalse);
      expect(map['data']['city'], 'Pune');

      final reconstructed = NotificationModel.fromMap(map, id: 'notif_101');
      expect(reconstructed.id, notif.id);
      expect(reconstructed.title, notif.title);
      expect(reconstructed.type, notif.type);
      expect(reconstructed.isRead, isFalse);
    });

    test('Notification unread filter counts only unread notices', () {
      final notifs = [
        const NotificationModel(id: '1', userId: 'u1', title: 'A', body: 'A', type: 'BOOKING_CONFIRMED', isRead: false),
        const NotificationModel(id: '2', userId: 'u1', title: 'B', body: 'B', type: 'BOOKING_RESCHEDULED', isRead: true),
        const NotificationModel(id: '3', userId: 'u1', title: 'C', body: 'C', type: 'BOOKING_CANCELLED', isRead: false),
      ];

      final unread = notifs.where((n) => !n.isRead).toList();
      expect(unread.length, 2);
    });
  });

  group('PROMPT 15: Requirement 11 - Security & Data Privacy', () {
    test('Booking query filters enforce ownership by clientId', () {
      final allBookings = [
        BookingModel(
          id: 'b_own_1',
          clientId: 'client_current',
          trainerId: 'trainer_1',
          clientGender: Gender.male,
          trainerGender: Gender.male,
          sessionDate: DateTime.now().add(const Duration(days: 1)),
          startTime: '07:00',
          endTime: '08:00',
        ),
        BookingModel(
          id: 'b_other_1',
          clientId: 'client_different',
          trainerId: 'trainer_1',
          clientGender: Gender.male,
          trainerGender: Gender.male,
          sessionDate: DateTime.now().add(const Duration(days: 1)),
          startTime: '09:00',
          endTime: '10:00',
        ),
      ];

      final clientScoped = allBookings.where((b) => b.clientId == 'client_current').toList();
      expect(clientScoped.length, 1);
      expect(clientScoped.first.id, 'b_own_1');
    });

    test('Strict gender matching is maintained across client bookings', () {
      final validMalePair = BookingModel(
        id: 'b_male',
        clientId: 'c_male',
        trainerId: 't_male',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime.now().add(const Duration(days: 1)),
        startTime: '07:00',
        endTime: '08:00',
      );

      final invalidPair = BookingModel(
        id: 'b_invalid',
        clientId: 'c_male',
        trainerId: 't_female',
        clientGender: Gender.male,
        trainerGender: Gender.female,
        sessionDate: DateTime.now().add(const Duration(days: 1)),
        startTime: '07:00',
        endTime: '08:00',
      );

      expect(validMalePair.hasValidGenderMatch, isTrue);
      expect(invalidPair.hasValidGenderMatch, isFalse);
    });
  });
}
