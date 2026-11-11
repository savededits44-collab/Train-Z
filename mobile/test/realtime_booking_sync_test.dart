import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/services/booking_service.dart';
import 'package:trainuspro/services/trainer_schedule_service.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/purchased_package_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  group('Real-Time Booking & Client-Trainer Synchronization Tests', () {
    test('TEST 1: Client booking is received and registered in real-time booking stream', () {
      final bService = BookingService.instance;
      final now = DateTime.now();

      final booking = BookingModel(
        id: 'test_book_realtime_1',
        clientId: 'client_alpha',
        trainerId: 'trainer_omega',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Rahul Verma',
        clientPhone: '+91 9876543210',
        workoutType: 'Personal Training',
        sessionDate: now.add(const Duration(days: 2)),
        startTime: '08:00',
        endTime: '09:00',
        status: BookingStatus.pending,
        paymentStatus: PaymentStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      bService.addOrUpdateBooking(booking);

      expect(bService.pendingBookings.any((b) => b.id == 'test_book_realtime_1'), isTrue);
      final retrieved = bService.allBookings.firstWhere((b) => b.id == 'test_book_realtime_1');
      expect(retrieved.status, BookingStatus.pending);
      expect(retrieved.clientName, 'Rahul Verma');
    });

    test('TEST 2: Trainer accepts booking -> status updates to CONFIRMED instantly', () async {
      final bService = BookingService.instance;
      final now = DateTime.now();

      final booking = BookingModel(
        id: 'test_book_accept_2',
        clientId: 'client_beta',
        trainerId: 'trainer_omega',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        clientName: 'Priya Sharma',
        workoutType: 'Fat Loss',
        sessionDate: now.add(const Duration(days: 1)),
        startTime: '07:00',
        endTime: '08:00',
        status: BookingStatus.pending,
        paymentStatus: PaymentStatus.completed,
      );

      bService.addOrUpdateBooking(booking);
      await bService.acceptBooking('test_book_accept_2');

      final updated = bService.allBookings.firstWhere((b) => b.id == 'test_book_accept_2');
      expect(updated.status, BookingStatus.confirmed);
      expect(updated.isConfirmed, isTrue);
    });

    test('TEST 3: Trainer reschedules session -> date, time, and RESCHEDULED status sync instantly', () async {
      final bService = BookingService.instance;
      final now = DateTime.now();

      final booking = BookingModel(
        id: 'test_book_reschedule_3',
        clientId: 'client_gamma',
        trainerId: 'trainer_omega',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Vikram Singh',
        sessionDate: now.add(const Duration(days: 1)),
        startTime: '07:00',
        endTime: '08:00',
        status: BookingStatus.confirmed,
      );

      bService.addOrUpdateBooking(booking);

      final newDate = now.add(const Duration(days: 3));
      await bService.rescheduleBooking(
        bookingId: 'test_book_reschedule_3',
        newDate: newDate,
        newStartTime: '18:00',
        newEndTime: '19:00',
        reason: 'Client requested evening session',
      );

      final updated = bService.allBookings.firstWhere((b) => b.id == 'test_book_reschedule_3');
      expect(updated.status, BookingStatus.rescheduled);
      expect(updated.isRescheduled, isTrue);
      expect(updated.startTime, '18:00');
      expect(updated.endTime, '19:00');
      expect(updated.sessionDate.day, newDate.day);
    });

    test('TEST 4: Client package calculation derives actual calendar days without manual decrement', () {
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 5));
      final expiryDate = now.add(const Duration(days: 25)); // 30 total days

      final pkg = PurchasedPackageModel(
        id: 'pkg_test_4',
        clientId: 'client_delta',
        clientName: 'Ananya Roy',
        trainerId: 'trainer_omega',
        trainerName: 'Coach Dev',
        packageId: 'plan_1_month',
        packageName: 'Monthly Transformation (30 Sessions)',
        price: 10799,
        purchaseDate: startDate,
        startDate: startDate,
        expiryDate: expiryDate,
        totalDays: 30,
        totalSessions: 26,
        completedSessions: 4,
      );

      // Remaining days derived directly from calendar difference
      expect(pkg.completedDays, 5);
      expect(pkg.remainingDays, 25);
      expect(pkg.daysCompletedFraction, '5/30 Days');
      expect(pkg.daysRemainingFraction, '25/30 Days Left');
      expect(pkg.remainingSessions, 22);
      expect(pkg.sessionsCompletedFraction, '4/26 Sessions');
      expect(pkg.healthStatus, 'green'); // 25 days > 10 days
    });

    test('TEST 5: Expiring package triggers orange and red status indicators accurately', () {
      final now = DateTime.now();

      // Orange: 7 days remaining
      final orangePkg = PurchasedPackageModel(
        id: 'pkg_orange',
        clientId: 'client_1',
        clientName: 'Client 1',
        trainerId: 'trainer_1',
        trainerName: 'Coach 1',
        packageId: 'plan_30',
        packageName: '30-Day Plan',
        price: 10000,
        purchaseDate: now.subtract(const Duration(days: 23)),
        startDate: now.subtract(const Duration(days: 23)),
        expiryDate: now.add(const Duration(days: 7)),
        totalDays: 30,
        totalSessions: 26,
        completedSessions: 20,
      );
      expect(orangePkg.healthStatus, 'orange');

      // Red: 2 days remaining
      final redPkg = PurchasedPackageModel(
        id: 'pkg_red',
        clientId: 'client_2',
        clientName: 'Client 2',
        trainerId: 'trainer_1',
        trainerName: 'Coach 1',
        packageId: 'plan_30',
        packageName: '30-Day Plan',
        price: 10000,
        purchaseDate: now.subtract(const Duration(days: 28)),
        startDate: now.subtract(const Duration(days: 28)),
        expiryDate: now.add(const Duration(days: 2)),
        totalDays: 30,
        totalSessions: 26,
        completedSessions: 25,
      );
      expect(redPkg.healthStatus, 'red');
    });

    test('TEST 6: Trainer completes workout -> sessions completed increments and status is COMPLETED', () async {
      final bService = BookingService.instance;
      final now = DateTime.now();

      final booking = BookingModel(
        id: 'test_book_complete_6',
        clientId: 'client_theta',
        trainerId: 'trainer_omega',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Suresh Patel',
        sessionDate: now,
        startTime: '10:00',
        endTime: '11:00',
        status: BookingStatus.confirmed,
        sessionsCompleted: 3,
        totalSessions: 12,
      );

      bService.addOrUpdateBooking(booking);
      await bService.markSessionCompleted('test_book_complete_6');

      final updated = bService.allBookings.firstWhere((b) => b.id == 'test_book_complete_6');
      expect(updated.status, BookingStatus.completed);
      expect(updated.isCompleted, isTrue);
      expect(updated.sessionsCompleted, 4);
    });

    test('TEST 7: Client or trainer cancels session -> status updates to CANCELLED', () async {
      final bService = BookingService.instance;
      final now = DateTime.now();

      final booking = BookingModel(
        id: 'test_book_cancel_7',
        clientId: 'client_cancel',
        trainerId: 'trainer_omega',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Rohan Mehra',
        sessionDate: now.add(const Duration(days: 2)),
        startTime: '09:00',
        endTime: '10:00',
        status: BookingStatus.confirmed,
      );

      bService.addOrUpdateBooking(booking);
      await bService.cancelBooking(
        bookingId: 'test_book_cancel_7',
        isTrainer: false,
        reason: 'Personal emergency',
      );

      final updated = bService.allBookings.firstWhere((b) => b.id == 'test_book_cancel_7');
      expect(updated.isCancelled, isTrue);
      expect(updated.status, BookingStatus.cancelledClientEarly);
    });

    test('TEST 8: TrainerScheduleService formats consistent collision lock ID', () {
      final scheduleService = TrainerScheduleService.instance;
      final testDate = DateTime(2026, 11, 15);

      final lockId = scheduleService.formatSlotLockId(
        trainerId: 'coach_john',
        date: testDate,
        startTime: '07:00 AM',
      );

      expect(lockId, 'coach_john_2026-11-15_0700AM');
    });

    test('TEST 9: BookingStatus toFirestore and fromFirestore round-trips all required states', () {
      for (final status in [
        BookingStatus.pending,
        BookingStatus.confirmed,
        BookingStatus.rescheduled,
        BookingStatus.cancelled,
        BookingStatus.completed,
        BookingStatus.rejected,
      ]) {
        final firestoreString = status.toFirestore();
        final parsed = BookingStatus.fromFirestore(firestoreString);
        expect(parsed, status);
      }
    });
  });
}
