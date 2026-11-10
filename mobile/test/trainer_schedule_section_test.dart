import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  group('Trainer Schedule Redesign & Package Progress Tests', () {
    test('Remaining days fraction format displays correctly for various packages', () {
      final now = DateTime.now();

      // Case 1: 15/30 Days Left (Monthly)
      final booking1 = BookingModel(
        id: 'test_b1',
        clientId: 'c1',
        trainerId: 't1',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: now,
        startTime: '07:00 AM',
        endTime: '08:00 AM',
        totalPackageDays: 30,
        packageStartDate: now.subtract(const Duration(days: 15)),
        packageExpiryDate: now.add(const Duration(days: 15)),
      );
      expect(booking1.remainingDaysFraction, '15/30 Sessions Left');
      expect(booking1.remainingSessionsFraction, '15/30 Sessions Left');
      expect(booking1.remainingFractionNumbers, '15/30');
      expect(booking1.resolvedDaysRemaining, 15);
      expect(booking1.resolvedDaysCompleted, 15);
      expect(booking1.packageProgress, closeTo(0.5, 0.05));
      expect(booking1.packageHealthStatus, 'green');

      // Case 2: 7/90 Sessions Left (3 Months - Nearing Expiry / Orange)
      final booking2 = BookingModel(
        id: 'test_b2',
        clientId: 'c2',
        trainerId: 't1',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        sessionDate: now,
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        totalPackageDays: 90,
        packageStartDate: now.subtract(const Duration(days: 83)),
        packageExpiryDate: now.add(const Duration(days: 7)),
      );
      expect(booking2.remainingDaysFraction, '7/90 Sessions Left');
      expect(booking2.remainingSessionsFraction, '7/90 Sessions Left');
      expect(booking2.remainingFractionNumbers, '7/90');
      expect(booking2.resolvedDaysRemaining, 7);
      expect(booking2.resolvedDaysCompleted, 83);
      expect(booking2.packageHealthStatus, 'orange');

      // Case 3: 3/30 Sessions Left (Monthly - Expiring Soon / Red)
      final booking3 = BookingModel(
        id: 'test_b3',
        clientId: 'c3',
        trainerId: 't1',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: now,
        startTime: '05:00 PM',
        endTime: '06:00 PM',
        totalPackageDays: 30,
        packageStartDate: now.subtract(const Duration(days: 27)),
        packageExpiryDate: now.add(const Duration(days: 3)),
      );
      expect(booking3.remainingDaysFraction, '3/30 Sessions Left');
      expect(booking3.remainingSessionsFraction, '3/30 Sessions Left');
      expect(booking3.remainingFractionNumbers, '3/30');
      expect(booking3.resolvedDaysRemaining, 3);
      expect(booking3.resolvedDaysCompleted, 27);
      expect(booking3.packageHealthStatus, 'red');
    });

    test('Default package derivation infers total days and start/expiry when unassigned', () {
      final now = DateTime.now();

      final bookingMonth = BookingModel(
        id: 'test_b4',
        clientId: 'c4',
        trainerId: 't1',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        planId: 'plan_1_month',
        sessionDate: now,
        startTime: '08:00 AM',
        endTime: '09:00 AM',
      );

      expect(bookingMonth.resolvedTotalDays, 30);
      expect(bookingMonth.resolvedPackageName, 'Monthly Plan (30 Sessions)');
      expect(bookingMonth.resolvedTotalSessions, 26);
      expect(bookingMonth.remainingDaysFraction.contains('/30 Sessions Left'), isTrue);

      final booking3Months = BookingModel(
        id: 'test_b5',
        clientId: 'c5',
        trainerId: 't1',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        planId: 'plan_3_months',
        sessionDate: now,
        startTime: '06:00 PM',
        endTime: '07:00 PM',
      );

      expect(booking3Months.resolvedTotalDays, 90);
      expect(booking3Months.resolvedPackageName, '3 Months Transformation');
      expect(booking3Months.resolvedTotalSessions, 78);
      expect(booking3Months.remainingDaysFraction.contains('/90 Sessions Left'), isTrue);
    });

    test('BookingModel completion mutation increments attended count and sets status', () {
      final now = DateTime.now();
      final initial = BookingModel(
        id: 'test_b_complete',
        clientId: 'c1',
        trainerId: 't1',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: now,
        startTime: '07:00 AM',
        endTime: '08:00 AM',
        status: BookingStatus.confirmed,
        sessionsCompleted: 13,
        totalSessions: 26,
      );

      expect(initial.status, BookingStatus.confirmed);
      expect(initial.sessionsCompleted, 13);

      final updated = initial.copyWith(
        status: BookingStatus.completed,
        sessionsCompleted: (initial.sessionsCompleted ?? 0) + 1,
      );

      expect(updated.status, BookingStatus.completed);
      expect(updated.sessionsCompleted, 14);
    });

    test('Client details metadata (age, phone, fitnessGoal, dates) are resolved cleanly', () {
      final now = DateTime.now();
      final booking = BookingModel(
        id: 'test_b6',
        clientId: 'c6',
        trainerId: 't1',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Vikram Malhotra',
        clientPhone: '+91 99887 66554',
        clientAge: 29,
        fitnessGoal: 'Hypertrophy & Powerlifting',
        packageName: '6-Month Transformation',
        totalPackageDays: 180,
        totalSessions: 150,
        sessionsCompleted: 35,
        sessionDate: now,
        startTime: '09:00 AM',
        endTime: '10:00 AM',
      );

      expect(booking.displayClientName, 'Vikram Malhotra');
      expect(booking.clientPhone, '+91 99887 66554');
      expect(booking.resolvedAge, 29);
      expect(booking.resolvedFitnessGoal, 'Hypertrophy & Powerlifting');
      expect(booking.resolvedTotalDays, 180);
      expect(booking.resolvedTotalSessions, 150);
      expect(booking.resolvedSessionsCompleted, 35);
    });
  });
}
