import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/firestore_collections.dart';
import '../shared/models/booking_model.dart';
import 'booking_service.dart';

/// Manages real-time trainer schedule, slot availability checks,
/// and double-booking prevention.
class TrainerScheduleService {
  static final TrainerScheduleService instance = TrainerScheduleService._internal();
  factory TrainerScheduleService() => instance;
  TrainerScheduleService._internal();

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore? get _firestore {
    try {
      _firestoreInstance ??= FirebaseFirestore.instance;
      return _firestoreInstance;
    } catch (_) {
      return null;
    }
  }

  /// Generate consistent slot lock document ID: `${trainerId}_${YYYY-MM-DD}_${safeStartTime}`
  String formatSlotLockId({
    required String trainerId,
    required DateTime date,
    required String startTime,
  }) {
    final dateStr = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final safeTime = startTime.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return '${trainerId}_${dateStr}_$safeTime';
  }

  /// Verifies slot availability directly against Firestore slot locks and active bookings.
  /// Prevents race-conditions and double bookings across devices.
  Future<bool> isSlotAvailable({
    required String trainerId,
    required DateTime date,
    required String startTime,
  }) async {
    final lockId = formatSlotLockId(
      trainerId: trainerId,
      date: date,
      startTime: startTime,
    );

    // 1. Check slot locks collection
    if (_firestore != null) {
      final lockSnap = await _firestore!.collection(FirestoreCollections.slotLocks).doc(lockId).get();
      if (lockSnap.exists) {
        final data = lockSnap.data();
        final status = data?['status'] as String? ?? '';
        final expiresAt = data?['expiresAt'] is Timestamp
            ? (data!['expiresAt'] as Timestamp).toDate()
            : null;

        if (status == 'CONFIRMED') return false; // Booked and confirmed
        if (status == 'RESERVED' && expiresAt != null && expiresAt.isAfter(DateTime.now())) {
          return false; // Active 15-min temporary reservation
        }
      }
    }

    // 2. Cross-check in-memory BookingService bookings
    final inMemoryCollision = BookingService.instance.allBookings.any((b) {
      if (b.trainerId != trainerId) return false;
      if (b.sessionDate.year != date.year ||
          b.sessionDate.month != date.month ||
          b.sessionDate.day != date.day) {
        return false;
      }
      if (b.startTime != startTime) return false;
      if (b.status == BookingStatus.confirmed) return true;
      if (b.status == BookingStatus.pending) return true;
      if (b.status == BookingStatus.reserved && !b.isReservationExpired) return true;
      return false;
    });

    return !inMemoryCollision;
  }

  /// Atomically claims a slot lock during booking initiation
  Future<bool> claimSlotLock({
    required String trainerId,
    required DateTime date,
    required String startTime,
    required String clientId,
    Duration holdDuration = const Duration(minutes: 15),
  }) async {
    final lockId = formatSlotLockId(
      trainerId: trainerId,
      date: date,
      startTime: startTime,
    );
    if (_firestore == null) return true;
    final lockRef = _firestore!.collection(FirestoreCollections.slotLocks).doc(lockId);

    try {
      return await _firestore!.runTransaction((tx) async {
        final snap = await tx.get(lockRef);
        final now = DateTime.now();

        if (snap.exists) {
          final data = snap.data()!;
          final status = data['status'] as String? ?? '';
          final expiresAt = data['expiresAt'] is Timestamp
              ? (data['expiresAt'] as Timestamp).toDate()
              : null;

          if (status == 'CONFIRMED') {
            return false; // Already booked
          }
          if (status == 'RESERVED' && expiresAt != null && expiresAt.isAfter(now)) {
            // Check if held by same client
            final heldBy = data['clientId'] as String? ?? '';
            if (heldBy != clientId) return false; // Held by another client
          }
        }

        final expiresAt = now.add(holdDuration);
        tx.set(lockRef, {
          'lockId': lockId,
          'trainerId': trainerId,
          'clientId': clientId,
          'sessionDate': Timestamp.fromDate(date),
          'startTime': startTime,
          'status': 'RESERVED',
          'expiresAt': Timestamp.fromDate(expiresAt),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (e) {
      debugPrint('Notice: Error claiming slot lock: $e');
      return false;
    }
  }

  /// Filter trainer's sessions for today
  List<BookingModel> getTodaySessions(String trainerId) {
    final now = DateTime.now();
    return BookingService.instance.allBookings.where((b) {
      if (b.trainerId != trainerId) return false;
      if (b.status == BookingStatus.rejected || b.isCancelled || b.status == BookingStatus.expired) {
        return false;
      }
      return b.sessionDate.year == now.year &&
          b.sessionDate.month == now.month &&
          b.sessionDate.day == now.day;
    }).toList();
  }

  /// Filter trainer's upcoming sessions (today and future)
  List<BookingModel> getUpcomingSessions(String trainerId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return BookingService.instance.allBookings.where((b) {
      if (b.trainerId != trainerId) return false;
      if (b.status == BookingStatus.rejected || b.isCancelled || b.status == BookingStatus.expired) {
        return false;
      }
      final sDate = DateTime(b.sessionDate.year, b.sessionDate.month, b.sessionDate.day);
      return !sDate.isBefore(today);
    }).toList();
  }

  /// Filter trainer's sessions for a specific week starting on [weekStart]
  List<BookingModel> getWeeklySchedule(String trainerId, DateTime weekStart) {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));
    return BookingService.instance.allBookings.where((b) {
      if (b.trainerId != trainerId) return false;
      if (b.status == BookingStatus.rejected || b.isCancelled || b.status == BookingStatus.expired) {
        return false;
      }
      final sDate = DateTime(b.sessionDate.year, b.sessionDate.month, b.sessionDate.day);
      return !sDate.isBefore(start) && sDate.isBefore(end);
    }).toList();
  }

  /// Filter trainer's sessions for a specific month
  List<BookingModel> getMonthlySchedule(String trainerId, int year, int month) {
    return BookingService.instance.allBookings.where((b) {
      if (b.trainerId != trainerId) return false;
      if (b.status == BookingStatus.rejected || b.isCancelled || b.status == BookingStatus.expired) {
        return false;
      }
      return b.sessionDate.year == year && b.sessionDate.month == month;
    }).toList();
  }
}
