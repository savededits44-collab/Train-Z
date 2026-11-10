import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/firestore_collections.dart';
import '../shared/models/booking_model.dart';
import '../shared/models/user_model.dart';

/// Singleton service providing real-time, live booking synchronization
/// between Clients and Trainers.
class BookingService extends ChangeNotifier {
  static final BookingService _instance = BookingService._internal();
  static BookingService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _firestoreSub;

  final List<BookingModel> _bookings = [];
  final StreamController<List<BookingModel>> _streamController =
      StreamController<List<BookingModel>>.broadcast();

  BookingService._internal() {
    _initializeSeedData();
    _initFirestoreListener();
  }

  Stream<List<BookingModel>> get stream => _streamController.stream;
  List<BookingModel> get allBookings => List.unmodifiable(_bookings);

  List<BookingModel> get pendingBookings =>
      _bookings.where((b) => b.status == BookingStatus.pending).toList();

  List<BookingModel> get confirmedBookings =>
      _bookings.where((b) => b.status == BookingStatus.confirmed).toList();

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
      BookingModel(
        id: 'book_seed_01',
        clientId: 'client_rohan',
        trainerId: 'trainer_active',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Rohan Sharma',
        clientPhone: '+91 98201 54321',
        workoutType: 'Strength & Hypertrophy',
        sessionDate: now,
        startTime: '07:00 AM',
        endTime: '08:00 AM',
        meetingLocation: "Gold's Gym Bandra (Floor 2)",
        notes: 'Focusing on barbell deadlift form and progressive core overload.',
        status: BookingStatus.pending,
        createdAt: now.subtract(const Duration(minutes: 15)),
      ),
      BookingModel(
        id: 'book_seed_02',
        clientId: 'client_priya',
        trainerId: 'trainer_active',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        clientName: 'Ananya Verma',
        clientPhone: '+91 98765 11223',
        workoutType: 'HIIT Conditioning & Fat Loss',
        sessionDate: now.add(const Duration(days: 1)),
        startTime: '06:00 PM',
        endTime: '07:00 PM',
        meetingLocation: 'Cult.fit Studio, Khar West',
        notes: 'High intensity cardio and kettlebell circuits.',
        status: BookingStatus.pending,
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      BookingModel(
        id: 'book_seed_03',
        clientId: 'client_sameer',
        trainerId: 'trainer_active',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        clientName: 'Sameer Kapoor',
        clientPhone: '+91 91234 56789',
        workoutType: 'Athletic Agility & Mobility',
        sessionDate: now.add(const Duration(days: 2)),
        startTime: '08:30 AM',
        endTime: '09:30 AM',
        meetingLocation: 'Personal Training Zone, Mumbai',
        notes: 'Rotator cuff warmups and explosive plyometrics.',
        status: BookingStatus.pending,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ]);
    _notify();
  }

  void _initFirestoreListener() {
    try {
      _firestoreSub = _firestore
          .collection(FirestoreCollections.bookings)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen(
        (snapshot) {
          if (snapshot.docs.isNotEmpty) {
            final fromDb = snapshot.docs
                .map((d) => BookingModel.fromDocument(d))
                .toList();

            for (final item in fromDb) {
              final index = _bookings.indexWhere((b) => b.id == item.id);
              if (index >= 0) {
                _bookings[index] = item;
              } else {
                _bookings.insert(0, item);
              }
            }
            _notify();
          }
        },
        onError: (err) {
          debugPrint('Notice: BookingService live stream Firestore fallback active: $err');
        },
      );
    } catch (e) {
      debugPrint('Notice: Firestore not connected yet, using live reactive memory stream: $e');
    }
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
          .collection(FirestoreCollections.bookings)
          .doc(newId)
          .set(booking.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Notice: Booking created in local real-time state: $e');
    }

    return booking;
  }

  /// Trainer accepts a booking in real-time
  Future<void> acceptBooking(String bookingId) async {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index >= 0) {
      final updated = _bookings[index].copyWith(
        status: BookingStatus.confirmed,
        updatedAt: DateTime.now(),
      );
      _bookings[index] = updated;
      _notify();
    }

    try {
      await _firestore
          .collection(FirestoreCollections.bookings)
          .doc(bookingId)
          .set({
        'status': 'CONFIRMED',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Notice: Booking accept updated in local state: $e');
    }
  }

  /// Trainer rejects a booking in real-time
  Future<void> rejectBooking(String bookingId, {String? reason}) async {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
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
      _notify();
    }

    try {
      await _firestore
          .collection(FirestoreCollections.bookings)
          .doc(bookingId)
          .set({
        'status': 'REJECTED',
        'updatedAt': FieldValue.serverTimestamp(),
        ...?reason != null ? {'rejectionReason': reason} : null,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Notice: Booking reject updated in local state: $e');
    }
  }

  @override
  void dispose() {
    _firestoreSub?.cancel();
    _streamController.close();
    super.dispose();
  }
}
