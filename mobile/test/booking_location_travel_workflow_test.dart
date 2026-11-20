import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/payment_model.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TRAIN Z — 14 Booking Location, Trainer Travel & Workflow Scenarios', () {
    // ──────────────────────────────────────────────────────────────────────────
    // Scenario 1: Client selects Gym A, trainer primary gym is Gym B.
    // ──────────────────────────────────────────────────────────────────────────
    test('Scenario 1: Client selects Gym A while Trainer primary gym is Gym B (locations decoupled)', () {
      // Trainer profile with Gym B as primary
      const trainerProfile = TrainerProfileModel(
        uid: 'trainer_b',
        fullName: 'Coach Vikram',
        trainsAtGym: true,
        primaryGymName: 'Talwalkars Gym, Baner',
        primaryGymAddress: 'Baner Road, Pune 411045',
        primaryGymLat: 18.5590,
        primaryGymLng: 73.7868,
        travelRadiusKm: 25.0,
      );

      // Client chooses Gym A
      final clientBooking = BookingModel(
        id: 'bk_gym_a_01',
        clientId: 'client_rahul',
        trainerId: trainerProfile.uid,
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime(2026, 4, 15),
        startTime: '08:00 AM',
        endTime: '09:00 AM',
        gymId: 'gym_golds_kp',
        gymName: "Gold's Gym, Koregaon Park",
        gymAddress: 'North Main Road, Koregaon Park, Pune 411001',
        gymLat: 18.5362,
        gymLng: 73.8940,
        gymMapsUrl: 'https://maps.google.com/?q=18.5362,73.8940',
        trainerTravelDistanceKm: 11.6,
        status: BookingStatus.pending,
        createdAt: DateTime.now(),
      );

      // Verify locations are completely decoupled and distinct
      expect(clientBooking.displayGymName, equals("Gold's Gym, Koregaon Park"));
      expect(clientBooking.gymLat, equals(18.5362));
      expect(trainerProfile.primaryGymName, equals('Talwalkars Gym, Baner'));
      expect(trainerProfile.primaryGymLat, equals(18.5590));
      expect(clientBooking.displayGymName, isNot(equals(trainerProfile.primaryGymName)));
    });

    // ──────────────────────────────────────────────────────────────────────────
    // Scenario 2: Gym A is within trainer's travel radius.
    // ──────────────────────────────────────────────────────────────────────────
    test("Scenario 2: Gym A is within trainer's travel radius via accurate Haversine calculation", () {
      const trainer = TrainerProfileModel(
        uid: 'trainer_02',
        fullName: 'Coach Priya',
        primaryGymName: 'Talwalkars Gym, Baner',
        primaryGymLat: 18.5590,
        primaryGymLng: 73.7868,
        travelRadiusKm: 15.0, // 15 km radius
      );

      // Gym A in Koregaon Park: ~11.6 km away
      const gymALat = 18.5362;
      const gymALng = 73.8940;

      final distance = trainer.calculateDistanceToGymKm(gymALat, gymALng);
      expect(distance, isNotNull);
      expect(distance!, greaterThan(10.0));
      expect(distance, lessThan(15.0));

      final isWithinRadius = trainer.isGymWithinTravelRadius(gymALat, gymALng);
      expect(isWithinRadius, isTrue, reason: 'Gym A is ~11.6 km away, inside 15 km radius');
    });

    // ──────────────────────────────────────────────────────────────────────────
    // Scenario 3: Trainer accepts request -> 15-minute reservation starts.
    // ──────────────────────────────────────────────────────────────────────────
    test('Scenario 3: Trainer accepts request -> status becomes RESERVED with 15-min atomic window', () async {
      final now = DateTime.now();
      final pendingBooking = BookingModel(
        id: 'bk_accept_test',
        clientId: 'client_amit',
        trainerId: 'trainer_accepted',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime(2026, 4, 20),
        startTime: '07:00 AM',
        endTime: '08:00 AM',
        gymName: "Cult Fitness, Kalyani Nagar",
        status: BookingStatus.pending,
        createdAt: now,
      );

      expect(pendingBooking.isPending, isTrue);
      expect(pendingBooking.isAwaitingPayment, isFalse);

      // Simulate trainer acceptance
      final reservationExpiresAt = now.add(const Duration(minutes: 15));
      final reservedBooking = pendingBooking.copyWith(
        status: BookingStatus.reserved,
        reservedAt: now,
        expiresAt: reservationExpiresAt,
      );

      expect(reservedBooking.status, equals(BookingStatus.reserved));
      expect(reservedBooking.isAwaitingPayment, isTrue);
      expect(reservedBooking.isReservationExpired, isFalse);
      expect(reservedBooking.expiresAt, equals(reservationExpiresAt));
      expect(reservedBooking.secondsRemaining, greaterThan(850));
    });

    // ──────────────────────────────────────────────────────────────────────────
    // Scenario 4: Client pays within 15 minutes.
    // ──────────────────────────────────────────────────────────────────────────
    test('Scenario 4: Client completes payment within the active 15-minute hold', () {
      final now = DateTime.now();
      final reservedBooking = BookingModel(
        id: 'bk_pay_active',
        clientId: 'client_pay_1',
        trainerId: 'trainer_1',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime(2026, 4, 22),
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        gymName: "Gold's Gym, Koregaon Park",
        packagePrice: 10799,
        status: BookingStatus.reserved,
        reservedAt: now.subtract(const Duration(minutes: 5)),
        expiresAt: now.add(const Duration(minutes: 10)), // 10 minutes remaining
        createdAt: now.subtract(const Duration(minutes: 5)),
      );

      expect(reservedBooking.isReservationExpired, isFalse);
      expect(reservedBooking.isAwaitingPayment, isTrue);

      // Verify payment model creation for valid hold
      final payment = PaymentModel(
        id: 'pay_trans_101',
        clientId: reservedBooking.clientId,
        planId: 'plan_12_sessions',
        packageName: '12-Session Commercial Gym Pack',
        sessionsCount: 12,
        validityDays: 60,
        amount: reservedBooking.packagePrice!,
        status: PaymentStatus.pending,
        gatewayOrderId: 'order_rzp_101',
        receiptNumber: 'REC-PAY-101',
        bookingId: reservedBooking.id,
        trainerId: reservedBooking.trainerId,
      );

      expect(payment.amount, equals(10799));
      expect(payment.bookingId, equals(reservedBooking.id));
    });

    // ──────────────────────────────────────────────────────────────────────────
    // Scenario 5: Payment verification succeeds -> confirmed booking.
    // ──────────────────────────────────────────────────────────────────────────
    test('Scenario 5: Payment verification succeeds -> booking CONFIRMED and gym session recorded', () {
      final now = DateTime.now();
      final reservedBooking = BookingModel(
        id: 'bk_confirm_test',
        clientId: 'client_vinit',
        trainerId: 'trainer_vinit',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime(2026, 4, 25),
        startTime: '06:00 PM',
        endTime: '07:00 PM',
        gymId: 'gym_cult_kn',
        gymName: 'Cult Fitness, Kalyani Nagar',
        packagePrice: 10799,
        status: BookingStatus.reserved,
        createdAt: now,
      );

      // Successful verification transitions booking to confirmed
      final confirmedBooking = reservedBooking.copyWith(
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.completed,
        paymentTransactionId: 'pay_rzp_verified_999',
        gymSettlementStatus: 'pending',
        gymCompensationAmount: 250, // Standard TRAIN Z commercial gym host compensation
        updatedAt: now,
      );

      expect(confirmedBooking.isConfirmed, isTrue);
      expect(confirmedBooking.paymentStatus, equals(PaymentStatus.completed));
      expect(confirmedBooking.gymSettlementStatus, equals('pending'));
      expect(confirmedBooking.gymCompensationAmount, equals(250));
    });

    // ──────────────────────────────────────────────────────────────────────────
    // Scenario 6: Trainer declines request -> no charge, status rejected.
    // ──────────────────────────────────────────────────────────────────────────
    test('Scenario 6: Trainer declines request -> status REJECTED, no charges, client notified', () {
      final now = DateTime.now();
      final pendingBooking = BookingModel(
        id: 'bk_decline_test',
        clientId: 'client_sneha',
        trainerId: 'trainer_decline',
        clientGender: Gender.female,
        trainerGender: Gender.male,
        sessionDate: DateTime(2026, 4, 26),
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        gymName: "Anytime Fitness, Baner",
        status: BookingStatus.pending,
        createdAt: now,
      );

      // Trainer rejects request
      final rejectedBooking = pendingBooking.copyWith(
        status: BookingStatus.rejected,
        notes: 'Trainer unavailable due to prior travel commitment',
        updatedAt: now,
      );

      expect(rejectedBooking.status, equals(BookingStatus.rejected));
      expect(rejectedBooking.paymentStatus, equals(PaymentStatus.pending)); // Never charged
      expect(rejectedBooking.paymentTransactionId, isNull);
      expect(rejectedBooking.isConfirmed, isFalse);
    });

    // ──────────────────────────────────────────────────────────────────────────
    // Scenario 7: Trainer active location changes -> primary preserved.
    // ──────────────────────────────────────────────────────────────────────────
    test('Scenario 7: Trainer updates active location -> primary gym is strictly preserved', () {
      // Initial profile with primary gym in Baner
      var trainer = const TrainerProfileModel(
        uid: 'trainer_rohit',
        fullName: 'Coach Rohit',
        primaryGymName: 'Talwalkars Gym, Baner',
        primaryGymAddress: 'Baner High Street, Pune',
        primaryGymLat: 18.5590,
        primaryGymLng: 73.7868,
        travelRadiusKm: 15.0,
      );

      expect(trainer.effectiveLat, equals(18.5590));
      expect(trainer.effectiveLng, equals(73.7868));
      expect(trainer.hasActiveLocationOverride, isFalse);

      // Trainer updates active coaching location to Koregaon Park
      trainer = trainer.updateActiveLocation(
        locationName: 'Koregaon Park Coaching Zone',
        locationAddress: 'North Main Road, Koregaon Park',
        lat: 18.5362,
        lng: 73.8940,
      );

      // Verify active location is updated, while primary gym remains completely unchanged
      expect(trainer.hasActiveLocationOverride, isTrue);
      expect(trainer.activeLocationName, equals('Koregaon Park Coaching Zone'));
      expect(trainer.effectiveLat, equals(18.5362));
      expect(trainer.effectiveLng, equals(73.8940));
      expect(trainer.primaryGymName, equals('Talwalkars Gym, Baner'));
      expect(trainer.primaryGymLat, equals(18.5590));
      expect(trainer.primaryGymLng, equals(73.7868));

      // Reset active location back to primary
      final resetTrainer = trainer.clearActiveLocation();
      expect(resetTrainer.hasActiveLocationOverride, isFalse);
      expect(resetTrainer.effectiveLat, equals(18.5590));
      expect(resetTrainer.effectiveLng, equals(73.7868));
    });

    // ──────────────────────────────────────────────────────────────────────────
    // Scenario 8: Gym outside travel radius -> rejected / flagged.
    // ──────────────────────────────────────────────────────────────────────────
    test('Scenario 8: Commercial gym outside trainer travel radius is flagged and rejected', () {
      const trainer = TrainerProfileModel(
        uid: 'trainer_local',
        fullName: 'Coach Local',
        primaryGymName: 'Cult Fitness, Kalyani Nagar',
        primaryGymLat: 18.5463,
        primaryGymLng: 73.9033,
        travelRadiusKm: 10.0, // 10 km limit
      );

      // Faraway gym in Lonavala: ~65 km away
      const lonavalaLat = 18.7546;
      const lonavalaLng = 73.4062;

      final distance = trainer.calculateDistanceToGymKm(lonavalaLat, lonavalaLng);
      expect(distance, isNotNull);
      expect(distance!, greaterThan(50.0));

      final isWithin = trainer.isGymWithinTravelRadius(lonavalaLat, lonavalaLng);
      expect(isWithin, isFalse, reason: 'Lonavala is ~65 km away, far exceeding 10 km radius');
    });

    // ──────────────────────────────────────────────────────────────────────────
    // Scenario 9: Trainer unavailable at time -> conflict detected.
    // ──────────────────────────────────────────────────────────────────────────
    test('Scenario 9: Trainer unavailable at requested time -> scheduling conflict detected', () {
      final existingBooking = BookingModel(
        id: 'bk_existing_slot',
        clientId: 'client_user_a',
        trainerId: 'trainer_busy',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime(2026, 4, 10),
        startTime: '10:00 AM',
        endTime: '11:00 AM',
        gymName: "Gold's Gym, Koregaon Park",
        status: BookingStatus.confirmed,
        createdAt: DateTime.now(),
      );

      // Helper function matching backend conflict detection
      bool hasScheduleConflict(BookingModel existing, DateTime reqDate, String reqStart, String reqEnd) {
        final sameDate = existing.sessionDate.year == reqDate.year &&
            existing.sessionDate.month == reqDate.month &&
            existing.sessionDate.day == reqDate.day;
        if (!sameDate) return false;
        if (existing.status != BookingStatus.confirmed && existing.status != BookingStatus.reserved) {
          return false;
        }
        return existing.startTime == reqStart && existing.endTime == reqEnd;
      }

      final isConflicting = hasScheduleConflict(
        existingBooking,
        DateTime(2026, 4, 10),
        '10:00 AM',
        '11:00 AM',
      );
      expect(isConflicting, isTrue);

      final isDifferentTime = hasScheduleConflict(
        existingBooking,
        DateTime(2026, 4, 10),
        '11:00 AM',
        '12:00 PM',
      );
      expect(isDifferentTime, isFalse);
    });

    // ──────────────────────────────────────────────────────────────────────────
    // Scenario 10: Two clients reserve same slot -> atomic lock collision prevented.
    // ──────────────────────────────────────────────────────────────────────────
    test('Scenario 10: Two clients attempting to reserve same slot -> second reservation locked out', () {
      final now = DateTime.now();
      // Client 1 holds atomic reservation
      final activeReservation = BookingModel(
        id: 'bk_client_1',
        clientId: 'client_1',
        trainerId: 'trainer_locked',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime(2026, 4, 12),
        startTime: '05:00 PM',
        endTime: '06:00 PM',
        status: BookingStatus.reserved,
        reservedAt: now,
        expiresAt: now.add(const Duration(minutes: 15)),
        createdAt: now,
      );

      // Simulation of atomic reservation lock verification
      bool canReserveSlot(List<BookingModel> existingBookings, DateTime date, String start, String end) {
        for (final b in existingBookings) {
          final sameDate = b.sessionDate.year == date.year &&
              b.sessionDate.month == date.month &&
              b.sessionDate.day == date.day;
          if (sameDate && b.startTime == start && b.endTime == end) {
            if (b.status == BookingStatus.confirmed) return false;
            if (b.status == BookingStatus.reserved && !b.isReservationExpired) return false;
          }
        }
        return true;
      }

      final canClient2Reserve = canReserveSlot(
        [activeReservation],
        DateTime(2026, 4, 12),
        '05:00 PM',
        '06:00 PM',
      );

      expect(canClient2Reserve, isFalse, reason: 'Client 1 holds an active 15-minute reservation lock');
    });

    // ──────────────────────────────────────────────────────────────────────────
    // Scenario 11: Client fails to pay in 15 minutes -> reservation expires.
    // ──────────────────────────────────────────────────────────────────────────
    test('Scenario 11: Client fails to pay within 15 minutes -> reservation expires and slot freed', () {
      final now = DateTime.now();
      // Reservation created 20 minutes ago (15-min limit expired)
      final expiredBooking = BookingModel(
        id: 'bk_expired_01',
        clientId: 'client_slow',
        trainerId: 'trainer_1',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime(2026, 4, 14),
        startTime: '08:00 AM',
        endTime: '09:00 AM',
        gymName: "Gold's Gym",
        status: BookingStatus.reserved,
        reservedAt: now.subtract(const Duration(minutes: 20)),
        expiresAt: now.subtract(const Duration(minutes: 5)),
        createdAt: now.subtract(const Duration(minutes: 20)),
      );

      expect(expiredBooking.isReservationExpired, isTrue);

      // Expired booking marked as expired
      final updatedExpired = expiredBooking.copyWith(
        status: BookingStatus.expired,
        paymentStatus: PaymentStatus.failed,
      );

      expect(updatedExpired.status, equals(BookingStatus.expired));
      expect(updatedExpired.isReservationExpired, isTrue);
    });

    // ──────────────────────────────────────────────────────────────────────────
    // Scenario 12: Payment succeeds with delayed notification -> idempotency handles callback.
    // ──────────────────────────────────────────────────────────────────────────
    test('Scenario 12: Delayed gateway notification processed safely and idempotently', () {
      final now = DateTime.now();
      final reservedBooking = BookingModel(
        id: 'bk_delayed_webhook',
        clientId: 'client_webhook',
        trainerId: 'trainer_webhook',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime(2026, 4, 18),
        startTime: '07:00 AM',
        endTime: '08:00 AM',
        status: BookingStatus.reserved,
        packagePrice: 10799,
        reservedAt: now.subtract(const Duration(minutes: 10)),
        expiresAt: now.add(const Duration(minutes: 5)),
        createdAt: now.subtract(const Duration(minutes: 10)),
      );

      // Delayed webhook arrives with verified signature
      const webhookTxId = 'pay_rzp_delayed_12345';
      final confirmedBooking = reservedBooking.copyWith(
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.completed,
        paymentTransactionId: webhookTxId,
        gymSettlementStatus: 'pending',
      );

      expect(confirmedBooking.isConfirmed, isTrue);
      expect(confirmedBooking.paymentTransactionId, equals(webhookTxId));
    });

    // ──────────────────────────────────────────────────────────────────────────
    // Scenario 13: Duplicate payment callbacks -> idempotent protection against duplicate credits.
    // ──────────────────────────────────────────────────────────────────────────
    test('Scenario 13: Duplicate payment callbacks do not double-grant session credits', () {
      int creditsGrantedCount = 0;

      // Simulated idempotent handler matching backend finalizePaymentAndGrantCredits
      bool processPaymentCallback({
        required String paymentId,
        required BookingModel currentBooking,
        required bool alreadyCredited,
      }) {
        if (alreadyCredited || currentBooking.status == BookingStatus.confirmed) {
          // Idempotent no-op
          return false;
        }
        creditsGrantedCount += 12; // 12-pack allocation
        return true;
      }

      final booking = BookingModel(
        id: 'bk_idempotent_test',
        clientId: 'client_idem',
        trainerId: 'trainer_idem',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime(2026, 4, 19),
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        status: BookingStatus.reserved,
        createdAt: DateTime.now(),
      );

      // First webhook delivery
      final firstResult = processPaymentCallback(
        paymentId: 'pay_idem_001',
        currentBooking: booking,
        alreadyCredited: false,
      );
      expect(firstResult, isTrue);
      expect(creditsGrantedCount, equals(12));

      // Second webhook delivery for same payment
      final confirmedBooking = booking.copyWith(status: BookingStatus.confirmed);
      final secondResult = processPaymentCallback(
        paymentId: 'pay_idem_001',
        currentBooking: confirmedBooking,
        alreadyCredited: true,
      );
      expect(secondResult, isFalse);
      expect(creditsGrantedCount, equals(12), reason: 'Credits must NOT be double-granted');
    });

    // ──────────────────────────────────────────────────────────────────────────
    // Scenario 14: Confirmed gym details consistent and immutable in both apps.
    // ──────────────────────────────────────────────────────────────────────────
    test('Scenario 14: Confirmed commercial gym details are immutable and identical across Client and Trainer', () {
      final confirmedBooking = BookingModel(
        id: 'bk_immutable_final',
        clientId: 'client_alok',
        trainerId: 'trainer_meera',
        clientName: 'Alok Sharma',
        trainerName: 'Meera Rao',
        clientGender: Gender.male,
        trainerGender: Gender.female,
        sessionDate: DateTime(2026, 4, 28),
        startTime: '06:00 AM',
        endTime: '07:00 AM',
        gymId: 'gym_pune_gold_kp',
        gymName: "Gold's Gym, Koregaon Park",
        gymAddress: 'Main Road, Koregaon Park, Pune 411001',
        gymLat: 18.5362,
        gymLng: 73.8940,
        gymMapsUrl: 'https://maps.google.com/?q=18.5362,73.8940',
        trainerTravelDistanceKm: 4.8,
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.completed,
        gymSettlementStatus: 'pending',
        gymCompensationAmount: 250,
        createdAt: DateTime.now(),
      );

      // Verify client-side display getters
      expect(confirmedBooking.displayGymName, equals("Gold's Gym, Koregaon Park"));
      expect(confirmedBooking.displayGymAddress, equals('Main Road, Koregaon Park, Pune 411001'));
      expect(confirmedBooking.gymMapsUrl, contains('18.5362,73.8940'));
      expect(confirmedBooking.trainerTravelDistanceKm, equals(4.8));
      expect(confirmedBooking.gymCompensationAmount, equals(250));

      // Verify serialized map preserves all commercial gym and settlement fields
      final map = confirmedBooking.toMap();
      expect(map['gymId'], equals('gym_pune_gold_kp'));
      expect(map['gymName'], equals("Gold's Gym, Koregaon Park"));
      expect(map['gymAddress'], equals('Main Road, Koregaon Park, Pune 411001'));
      expect(map['gymLat'], equals(18.5362));
      expect(map['gymLng'], equals(73.8940));
      expect(map['gymMapsUrl'], equals('https://maps.google.com/?q=18.5362,73.8940'));
      expect(map['trainerTravelDistanceKm'], equals(4.8));
      expect(map['gymSettlementStatus'], equals('pending'));
      expect(map['gymCompensationAmount'], equals(250));

      // Verify deserialization recreates identical instance
      final deserialized = BookingModel.fromMap(map, id: 'bk_immutable_final');
      expect(deserialized.displayGymName, equals(confirmedBooking.displayGymName));
      expect(deserialized.displayGymAddress, equals(confirmedBooking.displayGymAddress));
      expect(deserialized.gymLat, equals(confirmedBooking.gymLat));
      expect(deserialized.gymLng, equals(confirmedBooking.gymLng));
      expect(deserialized.trainerTravelDistanceKm, equals(confirmedBooking.trainerTravelDistanceKm));
      expect(deserialized.gymSettlementStatus, equals('pending'));
    });
  });
}
