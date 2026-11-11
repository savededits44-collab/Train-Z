import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/firestore_collections.dart';
import '../shared/models/booking_model.dart';
import '../shared/models/user_model.dart';
import 'client_package_service.dart';
import 'notification_service.dart';
import 'trainer_profile_service.dart';

/// Singleton service providing real-time, live booking synchronization
/// between Clients and Trainers.
class BookingService extends ChangeNotifier {
  static final BookingService _instance = BookingService._internal();
  static BookingService get instance => _instance;

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore? get _firestore {
    try {
      _firestoreInstance ??= FirebaseFirestore.instance;
      return _firestoreInstance;
    } catch (_) {
      return null;
    }
  }
  StreamSubscription<QuerySnapshot>? _firestoreSub;
  StreamSubscription<User?>? _authSub;

  final List<BookingModel> _bookings = [];
  final StreamController<List<BookingModel>> _streamController =
      StreamController<List<BookingModel>>.broadcast();

  BookingService._internal() {
    _initializeSeedData();
    _initFirestoreListener();
    _initAuthListener();
  }

  void _initAuthListener() {
    try {
      _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          _initFirestoreListener();
        }
      });
    } catch (e) {
      debugPrint('Notice: FirebaseAuth not active in tests: $e');
    }
  }

  Stream<List<BookingModel>> get stream => _streamController.stream;
  List<BookingModel> get allBookings => List.unmodifiable(_bookings);

  List<BookingModel> get pendingBookings => _bookings.where((b) {
        if (b.status == BookingStatus.pending) return true;
        if (b.status == BookingStatus.reserved && !b.isReservationExpired) return true;
        return false;
      }).toList();

  List<BookingModel> get confirmedBookings =>
      _bookings.where((b) => b.status == BookingStatus.confirmed).toList();

  /// Confirmed or completed sessions scheduled for today
  List<BookingModel> get todayConfirmedBookings {
    final now = DateTime.now();
    return _bookings.where((b) {
      if (b.status != BookingStatus.confirmed && b.status != BookingStatus.completed) {
        return false;
      }
      return b.sessionDate.year == now.year &&
             b.sessionDate.month == now.month &&
             b.sessionDate.day == now.day;
    }).toList();
  }

  /// Real-time today's income earned from today's confirmed/completed sessions
  int get todaysIncome {
    final rate = TrainerProfileService.instance.hourlyRate;
    return todayConfirmedBookings.length * rate;
  }

  List<BookingModel> get historyBookings => _bookings
      .where((b) =>
          b.status == BookingStatus.completed ||
          b.status == BookingStatus.rejected ||
          b.status == BookingStatus.cancelledClientEarly ||
          b.status == BookingStatus.cancelledClientLate ||
          b.status == BookingStatus.cancelledTrainer)
      .toList();

  void _initializeSeedData() {
    final now = DateTime.now();
    _bookings.addAll([
      // Client 1 (Today 07:00 AM, Monthly Package, 15/30 Days Left - Green)
      BookingModel(
        id: 'book_seed_01',
        clientId: 'client_rohan',
        trainerId: 'trainer_active',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Rohan Sharma',
        clientPhone: '+91 98201 54321',
        clientAge: 28,
        fitnessGoal: 'Strength & Hypertrophy',
        workoutType: 'Strength & Hypertrophy',
        packageName: 'Monthly Pro (30 Sessions)',
        totalPackageDays: 30,
        packageStartDate: now.subtract(const Duration(days: 15)),
        packageExpiryDate: now.add(const Duration(days: 15)),
        totalSessions: 26,
        sessionsCompleted: 13,
        sessionDate: now,
        startTime: '07:00 AM',
        endTime: '08:00 AM',
        meetingLocation: "Gold's Gym Bandra (Floor 2)",
        notes: 'Focusing on barbell deadlift form and progressive core overload.',
        status: BookingStatus.confirmed,
        createdAt: now.subtract(const Duration(days: 15)),
      ),
      // Client 2 (Today 10:30 AM, 3 Months Package, 7/90 Days Left - Orange / Nearing Expiry)
      BookingModel(
        id: 'book_seed_02',
        clientId: 'client_ananya',
        trainerId: 'trainer_active',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        clientName: 'Ananya Verma',
        clientPhone: '+91 98765 11223',
        clientAge: 25,
        fitnessGoal: 'HIIT Conditioning & Fat Loss',
        workoutType: 'HIIT Conditioning & Fat Loss',
        packageName: '3 Months Transformation',
        totalPackageDays: 90,
        packageStartDate: now.subtract(const Duration(days: 83)),
        packageExpiryDate: now.add(const Duration(days: 7)),
        totalSessions: 78,
        sessionsCompleted: 71,
        sessionDate: now,
        startTime: '10:30 AM',
        endTime: '11:30 AM',
        meetingLocation: 'Cult.fit Studio, Khar West',
        notes: 'High intensity cardio and kettlebell circuits.',
        status: BookingStatus.confirmed,
        createdAt: now.subtract(const Duration(days: 83)),
      ),
      // Client 3 (Today 05:30 PM, Monthly Package, 3/30 Days Left - Red / Expiring Soon)
      BookingModel(
        id: 'book_seed_03',
        clientId: 'client_sameer',
        trainerId: 'trainer_active',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Sameer Kapoor',
        clientPhone: '+91 91234 56789',
        clientAge: 32,
        fitnessGoal: 'Athletic Agility & Mobility',
        workoutType: 'Athletic Agility & Mobility',
        packageName: 'Monthly Pro (30 Sessions)',
        totalPackageDays: 30,
        packageStartDate: now.subtract(const Duration(days: 27)),
        packageExpiryDate: now.add(const Duration(days: 3)),
        totalSessions: 26,
        sessionsCompleted: 23,
        sessionDate: now,
        startTime: '05:30 PM',
        endTime: '06:30 PM',
        meetingLocation: 'Personal Training Zone',
        notes: 'Rotator cuff warmups and explosive plyometrics.',
        status: BookingStatus.confirmed,
        createdAt: now.subtract(const Duration(days: 27)),
      ),
      // Client 4 (Tomorrow 08:00 AM, 6 Months Package, 142/180 Days Left - Green)
      BookingModel(
        id: 'book_seed_04',
        clientId: 'client_vikram',
        trainerId: 'trainer_active',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Vikram Malhotra',
        clientPhone: '+91 99887 66554',
        clientAge: 29,
        fitnessGoal: 'Hypertrophy & Powerlifting',
        workoutType: 'Chest & Tricep Hypertrophy',
        packageName: '6-Month Transformation',
        totalPackageDays: 180,
        packageStartDate: now.subtract(const Duration(days: 38)),
        packageExpiryDate: now.add(const Duration(days: 142)),
        totalSessions: 150,
        sessionsCompleted: 32,
        sessionDate: now.add(const Duration(days: 1)),
        startTime: '08:00 AM',
        endTime: '09:00 AM',
        meetingLocation: 'Nitro Gym BKC',
        notes: 'Bench press overload (3 sets x 5 reps).',
        status: BookingStatus.confirmed,
        createdAt: now.subtract(const Duration(days: 38)),
      ),
      // Client 5 (In 2 days 06:00 PM, Monthly Package, 5/30 Days Left - Orange)
      BookingModel(
        id: 'book_seed_05',
        clientId: 'client_neha',
        trainerId: 'trainer_active',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        clientName: 'Neha Deshmukh',
        clientPhone: '+91 97654 32109',
        clientAge: 31,
        fitnessGoal: 'Posture & Core Stability',
        workoutType: 'Pilates & Core Rehab',
        packageName: 'Monthly Pro (30 Sessions)',
        totalPackageDays: 30,
        packageStartDate: now.subtract(const Duration(days: 25)),
        packageExpiryDate: now.add(const Duration(days: 5)),
        totalSessions: 26,
        sessionsCompleted: 21,
        sessionDate: now.add(const Duration(days: 2)),
        startTime: '06:00 PM',
        endTime: '07:00 PM',
        meetingLocation: 'The Pilates Studio, Juhu',
        notes: 'Spine decompression and posterior chain strengthening.',
        status: BookingStatus.confirmed,
        createdAt: now.subtract(const Duration(days: 25)),
      ),
      // Client 6 (Pending Live Request, 3 Months Package, 45/90 Days Left - Green)
      BookingModel(
        id: 'book_seed_06',
        clientId: 'client_aryan',
        trainerId: 'trainer_active',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Aryan Joshi',
        clientPhone: '+91 98112 33445',
        clientAge: 27,
        fitnessGoal: 'Marathon Stamina & Legs',
        workoutType: 'Endurance & VO2 Max Interval',
        packageName: '3 Months Transformation',
        totalPackageDays: 90,
        packageStartDate: now.subtract(const Duration(days: 45)),
        packageExpiryDate: now.add(const Duration(days: 45)),
        totalSessions: 78,
        sessionsCompleted: 39,
        sessionDate: now.add(const Duration(days: 3)),
        startTime: '06:30 AM',
        endTime: '07:30 AM',
        meetingLocation: 'Shivaji Park Running Track',
        notes: 'Heart-rate zone 4 tempo intervals + quad conditioning.',
        status: BookingStatus.pending,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ]);
    _notify();
  }

  void _initFirestoreListener() {
    if (_firestore == null) return;
    _firestoreSub?.cancel();
    try {
      // Real-time Firestore stream: listens to the bookings collection live
      _firestoreSub = _firestore!
          .collection(FirestoreCollections.bookings)
          .snapshots()
          .listen(
        (snapshot) {
          bool changed = false;
          for (final change in snapshot.docChanges) {
            final doc = change.doc;
            final item = BookingModel.fromDocument(doc);
            final index = _bookings.indexWhere((b) => b.id == item.id);

            if (change.type == DocumentChangeType.removed) {
              if (index >= 0) {
                _bookings.removeAt(index);
                changed = true;
              }
            } else {
              if (index >= 0) {
                _bookings[index] = item;
                changed = true;
              } else {
                _bookings.insert(0, item);
                changed = true;
              }
            }
          }
          if (changed) {
            _notify();
          }
        },
        onError: (err) {
          debugPrint('Notice: BookingService live stream Firestore fallback active: $err');
          _initScopedListener();
        },
      );
    } catch (e) {
      debugPrint('Notice: Firestore not connected yet, using live reactive memory stream: $e');
    }
  }

  void _initScopedListener() {
    if (_firestore == null) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) return;

      _firestoreSub?.cancel();
      _firestoreSub = _firestore!
          .collection(FirestoreCollections.bookings)
          .where('trainerId', isEqualTo: uid)
          .snapshots()
          .listen(
        (snapshot) {
          for (final doc in snapshot.docs) {
            final item = BookingModel.fromDocument(doc);
            final index = _bookings.indexWhere((b) => b.id == item.id);
            if (index >= 0) {
              _bookings[index] = item;
            } else {
              _bookings.insert(0, item);
            }
          }
          _notify();
        },
        onError: (e) {
          debugPrint('Notice: Scoped listener error: $e');
        },
      );
    } catch (e) {
      debugPrint('Notice: Scoped listener exception: $e');
    }
  }

  /// Add or update booking in real-time memory and broadcast to all trainer screens immediately
  void addOrUpdateBooking(BookingModel booking) {
    final index = _bookings.indexWhere((b) => b.id == booking.id);
    if (index >= 0) {
      _bookings[index] = booking;
    } else {
      _bookings.insert(0, booking);
    }
    _notify();
  }

  void _notify() {
    _streamController.add(List.unmodifiable(_bookings));
    notifyListeners();
  }

  /// Client creates a new booking request in real-time
  Future<BookingModel> createBookingRequest({
    required String clientName,
    required String clientPhone,
    required DateTime sessionDate,
    required String startTime,
    required String endTime,
    required String workoutType,
    required String meetingLocation,
    String? notes,
    String? trainerId,
    Gender clientGender = Gender.male,
    Gender trainerGender = Gender.male,
  }) async {
    final now = DateTime.now();
    final newId = 'book_${now.millisecondsSinceEpoch}';

    final booking = BookingModel(
      id: newId,
      clientId: 'client_${now.millisecondsSinceEpoch}',
      trainerId: trainerId ?? 'trainer_active',
      clientGender: clientGender,
      trainerGender: trainerGender,
      clientName: clientName.trim(),
      clientPhone: clientPhone.trim(),
      workoutType: workoutType.trim(),
      sessionDate: sessionDate,
      startTime: startTime,
      endTime: endTime,
      meetingLocation: meetingLocation.trim(),
      notes: notes?.trim(),
      status: BookingStatus.pending,
      createdAt: now,
      updatedAt: now,
    );

    // Add to live memory and notify all trainer screens instantly
    _bookings.insert(0, booking);
    _notify();

    // Sync to Firestore in real time
    try {
      await _firestore
          ?.collection(FirestoreCollections.bookings)
          .doc(newId)
          .set(booking.toMap(), SetOptions(merge: true));

      // Notify trainer immediately
      await NotificationService.instance.sendNotification(
        userId: booking.trainerId,
        title: 'New Session Request! 📅',
        body: '${booking.displayClientName} requested a session for ${_formatDate(sessionDate)} at $startTime.',
        type: 'BOOKING_RECEIVED',
        relatedId: booking.id,
        data: {
          'clientId': booking.clientId,
          'date': sessionDate.toIso8601String(),
          'startTime': startTime,
          'endTime': endTime,
        },
      );
    } catch (e) {
      debugPrint('Notice: Booking created in local real-time state: $e');
    }

    return booking;
  }

  /// Trainer accepts a booking in real-time
  Future<void> acceptBooking(String bookingId) async {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    BookingModel? target;
    if (index >= 0) {
      final updated = _bookings[index].copyWith(
        status: BookingStatus.confirmed,
        updatedAt: DateTime.now(),
      );
      _bookings[index] = updated;
      target = updated;
      _notify();
    }

    try {
      await _firestore
          ?.collection(FirestoreCollections.bookings)
          .doc(bookingId)
          .set({
        'status': 'CONFIRMED',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (target != null) {
        await NotificationService.instance.sendNotification(
          userId: target.clientId,
          title: 'Session Confirmed! ✅',
          body: 'Coach ${target.displayTrainerName} accepted your session on ${_formatDate(target.sessionDate)} at ${target.startTime}.',
          type: 'BOOKING_CONFIRMED',
          relatedId: bookingId,
        );
      }
    } catch (e) {
      debugPrint('Notice: Booking accept updated in local state: $e');
    }
  }

  /// Trainer rejects a booking in real-time
  Future<void> rejectBooking(String bookingId, {String? reason}) async {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    BookingModel? target;
    if (index >= 0) {
      final current = _bookings[index];
      final updated = current.copyWith(
        status: BookingStatus.rejected,
        notes: reason != null && reason.trim().isNotEmpty
            ? '${current.notes != null ? "${current.notes}\n" : ""}[Trainer Rejection Reason: $reason]'
            : current.notes,
        updatedAt: DateTime.now(),
      );
      _bookings[index] = updated;
      target = updated;
      _notify();
    }

    try {
      await _firestore
          ?.collection(FirestoreCollections.bookings)
          .doc(bookingId)
          .set({
        'status': 'REJECTED',
        'updatedAt': FieldValue.serverTimestamp(),
        ...?reason != null ? {'rejectionReason': reason} : null,
      }, SetOptions(merge: true));

      if (target != null) {
        await NotificationService.instance.sendNotification(
          userId: target.clientId,
          title: 'Session Request Declined ✕',
          body: 'Coach ${target.displayTrainerName} was unable to accept your session request.${reason != null && reason.trim().isNotEmpty ? " Reason: $reason" : ""}',
          type: 'BOOKING_REJECTED',
          relatedId: bookingId,
        );
      }
    } catch (e) {
      debugPrint('Notice: Booking reject updated in local state: $e');
    }
  }

  /// Trainer marks a session as completed / records attendance
  Future<void> markSessionCompleted(String bookingId) async {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    BookingModel? target;
    if (index >= 0) {
      final current = _bookings[index];
      final currentCompleted = current.sessionsCompleted ?? current.resolvedSessionsCompleted;
      final updated = current.copyWith(
        status: BookingStatus.completed,
        sessionsCompleted: currentCompleted + 1,
        updatedAt: DateTime.now(),
      );
      _bookings[index] = updated;
      target = updated;
      _notify();
    }

    try {
      await _firestore
          ?.collection(FirestoreCollections.bookings)
          .doc(bookingId)
          .set({
        'status': 'COMPLETED',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (target != null) {
        await NotificationService.instance.sendNotification(
          userId: target.clientId,
          title: 'Workout Completed! 💪',
          body: 'Great workout with Coach ${target.displayTrainerName}! Your session has been marked completed.',
          type: 'WORKOUT_COMPLETED',
          relatedId: bookingId,
        );
        if (target.packageId != null) {
          ClientPackageService.instance.incrementCompletedSession(target.packageId!);
        }
      }
    } catch (e) {
      debugPrint('Notice: Booking complete updated in local state: $e');
    }
  }

  /// Reschedule booking date and time in real-time
  Future<void> rescheduleBooking({
    required String bookingId,
    required DateTime newDate,
    required String newStartTime,
    required String newEndTime,
    String? reason,
  }) async {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    BookingModel? target;
    if (index >= 0) {
      final current = _bookings[index];
      final updated = current.copyWith(
        sessionDate: newDate,
        startTime: newStartTime,
        endTime: newEndTime,
        status: BookingStatus.rescheduled,
        notes: reason != null && reason.trim().isNotEmpty
            ? '${current.notes != null ? "${current.notes}\n" : ""}[Rescheduled: $reason]'
            : current.notes,
        updatedAt: DateTime.now(),
      );
      _bookings[index] = updated;
      target = updated;
      _notify();
    }

    try {
      await _firestore
          ?.collection(FirestoreCollections.bookings)
          .doc(bookingId)
          .set({
        'sessionDate': Timestamp.fromDate(newDate),
        'startTime': newStartTime,
        'endTime': newEndTime,
        'status': 'RESCHEDULED',
        'updatedAt': FieldValue.serverTimestamp(),
        ...?reason != null ? {'rescheduleReason': reason} : null,
      }, SetOptions(merge: true));

      if (target != null) {
        await NotificationService.instance.sendNotification(
          userId: target.clientId,
          title: 'Session Rescheduled 🔄',
          body: 'Your session with Coach ${target.displayTrainerName} has been moved to ${_formatDate(newDate)} at $newStartTime.',
          type: 'BOOKING_RESCHEDULED',
          relatedId: bookingId,
          data: {
            'newDate': newDate.toIso8601String(),
            'newStartTime': newStartTime,
            'newEndTime': newEndTime,
          },
        );
      }
    } catch (e) {
      debugPrint('Notice: Error rescheduling booking: $e');
    }
  }

  /// Cancel booking in real-time (by client or trainer)
  Future<void> cancelBooking({
    required String bookingId,
    required bool isTrainer,
    String? reason,
  }) async {
    final newStatus = isTrainer ? BookingStatus.cancelledTrainer : BookingStatus.cancelledClientEarly;
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    BookingModel? target;
    if (index >= 0) {
      final current = _bookings[index];
      final updated = current.copyWith(
        status: newStatus,
        notes: reason != null && reason.trim().isNotEmpty
            ? '${current.notes != null ? "${current.notes}\n" : ""}[Cancelled by ${isTrainer ? "Trainer" : "Client"}: $reason]'
            : current.notes,
        updatedAt: DateTime.now(),
      );
      _bookings[index] = updated;
      target = updated;
      _notify();
    }

    try {
      await _firestore
          ?.collection(FirestoreCollections.bookings)
          .doc(bookingId)
          .set({
        'status': isTrainer ? 'CANCELLED_TRAINER' : 'CANCELLED_CLIENT_EARLY',
        'updatedAt': FieldValue.serverTimestamp(),
        ...?reason != null ? {'cancellationReason': reason} : null,
      }, SetOptions(merge: true));

      if (target != null) {
        // Release slot lock
        final dateStr = '${target.sessionDate.year.toString().padLeft(4, '0')}-${target.sessionDate.month.toString().padLeft(2, '0')}-${target.sessionDate.day.toString().padLeft(2, '0')}';
        final safeTime = target.startTime.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        final lockDocId = '${target.trainerId}_${dateStr}_$safeTime';
        if (_firestore != null) {
          await _firestore!.collection(FirestoreCollections.slotLocks).doc(lockDocId).delete();
        }

        // Send notification to the opposite party
        final recipientId = isTrainer ? target.clientId : target.trainerId;
        final senderName = isTrainer ? target.displayTrainerName : target.displayClientName;
        await NotificationService.instance.sendNotification(
          userId: recipientId,
          title: 'Session Cancelled ❌',
          body: '$senderName cancelled the session on ${_formatDate(target.sessionDate)} at ${target.startTime}.${reason != null ? " Reason: $reason" : ""}',
          type: 'BOOKING_CANCELLED',
          relatedId: bookingId,
        );
      }
    } catch (e) {
      debugPrint('Notice: Error cancelling booking: $e');
    }
  }

  String _formatDate(DateTime dt) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month]}';
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _firestoreSub?.cancel();
    _streamController.close();
    super.dispose();
  }
}
