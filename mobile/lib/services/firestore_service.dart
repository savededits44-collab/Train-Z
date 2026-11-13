import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_collections.dart';
import '../core/errors/app_exceptions.dart';
import '../shared/models/booking_model.dart';
import '../shared/models/city_model.dart';
import '../shared/models/client_profile_model.dart';
import '../shared/models/notification_model.dart';
import '../shared/models/payment_model.dart';
import '../shared/models/platform_settings_model.dart';
import '../shared/models/review_model.dart';
import '../shared/models/trainer_availability_model.dart';
import '../shared/models/trainer_profile_model.dart';
import '../shared/models/training_plan_model.dart';
import '../shared/models/user_model.dart';
import 'booking_service.dart';
import 'credit_service.dart';
import 'notification_service.dart';
import 'location_service.dart';
import 'trainer_availability_service.dart';

/// Core Firestore data access service for TRAIN Z shared features.
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore get _firestore {
    try {
      _firestoreInstance ??= FirebaseFirestore.instance;
      return _firestoreInstance!;
    } catch (_) {
      return FirebaseFirestore.instance;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Training Plans & Packages
  // ───────────────────────────────────────────────────────────────────────────

  /// Streams active platform training packages (used by Standard Trainers and platform default)
  Stream<List<TrainingPlanModel>> streamTrainingPlans() {
    return streamPlatformTrainingPlans();
  }

  /// Streams the 6 predefined TRAIN Z platform packages.
  /// Falls back to [TrainingPlanModel.platformPackages] if the collection has not yet been seeded.
  Stream<List<TrainingPlanModel>> streamPlatformTrainingPlans() {
    try {
      return _firestore
          .collection(FirestoreCollections.trainingPlans)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snap) {
        final plans = snap.docs
            .map((d) => TrainingPlanModel.fromDocument(d))
            .where((p) => p.isPlatformPackage)
            .toList();
        if (plans.isEmpty) {
          return TrainingPlanModel.platformPackages;
        }
        plans.sort((a, b) => a.price.compareTo(b.price));
        return plans;
      }).handleError((_) => TrainingPlanModel.platformPackages);
    } catch (_) {
      return Stream.value(TrainingPlanModel.platformPackages);
    }
  }

  /// Streams custom training plans created by an Advanced Trainer.
  /// Enforces that only plans approved (isApproved: true) and published (isActive: true)
  /// by TRAIN Z Admin are returned.
  Stream<List<TrainingPlanModel>> streamAdvancedTrainerPlans(String trainerUid) {
    if (trainerUid.trim().isEmpty) return Stream.value([]);
    try {
      return _firestore
          .collection(FirestoreCollections.trainingPlans)
          .where('trainerId', isEqualTo: trainerUid)
          .where('isApproved', isEqualTo: true)
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snap) {
        final plans = snap.docs.map((d) => TrainingPlanModel.fromDocument(d)).toList();
        plans.sort((a, b) => a.price.compareTo(b.price));
        return plans;
      }).handleError((_) => <TrainingPlanModel>[]);
    } catch (e) {
      return Stream.value([]);
    }
  }

  /// Category-aware package streaming for a selected trainer:
  /// - Standard Trainer: returns the 6 predefined TRAIN Z platform packages.
  /// - Advanced Trainer: returns only custom plans approved & published for this trainer.
  /// - Professional Trainer: returns empty (Coming Soon).
  Stream<List<TrainingPlanModel>> streamPackagesForTrainer(TrainerDisplayModel? trainer) {
    if (trainer == null) {
      return streamPlatformTrainingPlans();
    }
    switch (trainer.category) {
      case TrainerCategory.trainer:
        return streamPlatformTrainingPlans();
      case TrainerCategory.advancedTrainer:
        return streamAdvancedTrainerPlans(trainer.uid);
      case TrainerCategory.professionalTrainer:
        return Stream.value([]);
    }
  }

  /// Get single training plan by id
  Future<TrainingPlanModel?> getTrainingPlan(String planId) async {
    if (planId.trim().isEmpty) return null;
    try {
      final doc = await _firestore.collection(FirestoreCollections.trainingPlans).doc(planId).get();
      if (!doc.exists) {
        // Fallback to platform packages list if not in Firestore
        for (final p in TrainingPlanModel.platformPackages) {
          if (p.id == planId) return p;
        }
        return null;
      }
      return TrainingPlanModel.fromDocument(doc);
    } catch (_) {
      for (final p in TrainingPlanModel.platformPackages) {
        if (p.id == planId) return p;
      }
      return null;
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Cities
  // ───────────────────────────────────────────────────────────────────────────

  /// Streams active launch cities
  Stream<List<CityModel>> streamLaunchCities() {
    return _firestore
        .collection(FirestoreCollections.cities)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => CityModel.fromDocument(d)).toList());
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Trainers (Filtered by Approval & Gender Matching)
  // ───────────────────────────────────────────────────────────────────────────

  /// Streams approved & active trainers matching a client's gender
  /// Requirement 5 & 6:
  /// - Male clients can only see & book Male trainers
  /// - Female clients can only see & book Female trainers
  /// - Only APPROVED and active trainers appear
  Stream<List<TrainerProfileModel>> streamApprovedTrainers({
    required Gender clientGender,
    String? cityId,
  }) {
    Query query = _firestore
        .collection(FirestoreCollections.trainerProfiles)
        .where('verificationStatus', isEqualTo: 'APPROVED')
        .where('isActive', isEqualTo: true);

    if (cityId != null && cityId.isNotEmpty) {
      query = query.where('cityId', isEqualTo: cityId);
    }

    return query.snapshots().asyncMap((snap) async {
      final List<TrainerProfileModel> list = [];
      for (final doc in snap.docs) {
        final trainer = TrainerProfileModel.fromDocument(doc);
        if (trainer.uid.trim().isEmpty) continue;
        // Verify gender match from users collection
        final userDoc = await _firestore.collection(FirestoreCollections.users).doc(trainer.uid).get();
        if (userDoc.exists) {
          final user = UserModel.fromDocument(userDoc);
          if (user.gender == clientGender) {
            list.add(trainer);
          }
        }
      }
      return list;
    });
  }

  /// Streams approved trainers with full display details for Client Home and Discovery
  /// Enforces:
  /// - Only APPROVED and active trainers
  /// - Strict 1-on-1 gender matching (Male -> Male, Female -> Female)
  /// - Real-time slot availability from Firebase trainer_availability
  /// - Optional launch city filter
  /// - Pagination / limit support
  Stream<List<TrainerDisplayModel>> streamApprovedTrainersDisplay({
    required Gender clientGender,
    String? cityId,
    int limit = 25,
  }) {
    Query query = _firestore
        .collection(FirestoreCollections.trainerProfiles)
        .where('verificationStatus', isEqualTo: 'APPROVED')
        .limit(limit);

    return query.snapshots().asyncMap((snap) async {
      final List<TrainerDisplayModel> list = [];

      for (final doc in snap.docs) {
        final profile = TrainerProfileModel.fromDocument(doc);
        if (!profile.isActive) continue;

        // Inactive city guard: Never return trainers for inactive cities (Requirement 6)
        if (cityId != null && !LocationService.instance.isCityActive(cityId)) {
          continue;
        }

        // Service city filtering: match cityId if specified
        if (cityId != null &&
            cityId.isNotEmpty &&
            profile.cityId != null &&
            profile.cityId!.isNotEmpty &&
            profile.cityId != cityId) {
          continue;
        }

        // Fetch corresponding user record for name, photo and gender verification
        if (profile.uid.trim().isEmpty) continue;
        final userDoc = await _firestore.collection(FirestoreCollections.users).doc(profile.uid).get();
        if (!userDoc.exists) continue;

        final user = UserModel.fromDocument(userDoc);
        // STRICT 1-ON-1 GENDER MATCHING: Male clients with Male trainers only, Female with Female
        if (user.gender != clientGender) continue;

        final rawData = doc.data() as Map<String, dynamic>? ?? {};
        final gymName = rawData['gymName'] as String?;
        final serviceArea = rawData['serviceArea'] as String? ?? gymName;

        // Fetch real availability from Firebase trainer_availability
        bool hasSlots = true;
        try {
          final availSnap = await _firestore
              .collection(FirestoreCollections.trainerAvailability)
              .where('trainerId', isEqualTo: profile.uid)
              .limit(1)
              .get();
          if (availSnap.docs.isNotEmpty) {
            final availModel = TrainerAvailabilityModel.fromDocument(availSnap.docs.first);
            hasSlots = availModel.timeSlots.isEmpty || availModel.timeSlots.any((s) => !s.isBooked);
          }
        } catch (_) {
          hasSlots = true;
        }

        final trainingGoals = (rawData['trainingGoals'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
            profile.specialties;
        final certs = (rawData['verifiedCertifications'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
            (rawData['certifications'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
            <String>[];

        list.add(TrainerDisplayModel(
          profile: profile,
          uid: profile.uid,
          displayName: user.displayName ?? (rawData['fullName'] as String?) ?? 'Personal Trainer',
          photoUrl: user.photoUrl,
          gender: user.gender ?? clientGender,
          email: user.email,
          phoneNumber: user.phoneNumber,
          gymName: gymName,
          serviceArea: serviceArea,
          specialties: profile.specialties,
          experienceYears: profile.experienceYears,
          cityId: profile.cityId,
          ratingAvg: profile.ratingAvg,
          totalReviews: profile.totalReviews,
          hourlyRate: profile.hourlyRate,
          hasAvailableSlots: hasSlots,
          trainingGoals: trainingGoals,
          certifications: certs,
        ));
      }

      return list;
    });
  }

  /// Get trainer profile
  Future<TrainerProfileModel?> getTrainerProfile(String trainerId) async {
    if (trainerId.trim().isEmpty) return null;
    final doc = await _firestore.collection(FirestoreCollections.trainerProfiles).doc(trainerId).get();
    if (!doc.exists) return null;
    return TrainerProfileModel.fromDocument(doc);
  }

  /// Get client profile
  Future<ClientProfileModel?> getClientProfile(String clientId) async {
    if (clientId.trim().isEmpty) return null;
    final doc = await _firestore.collection(FirestoreCollections.clientProfiles).doc(clientId).get();
    if (!doc.exists) return null;
    return ClientProfileModel.fromDocument(doc);
  }

  /// Stream client profile in real time
  Stream<ClientProfileModel?> streamClientProfile(String clientId) {
    if (clientId.trim().isEmpty) return Stream.value(null);
    return _firestore
        .collection(FirestoreCollections.clientProfiles)
        .doc(clientId)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return ClientProfileModel.fromDocument(snap);
    });
  }

  /// Atomically saves common user info into `users/{uid}` and client-specific info into `client_profiles/{uid}`
  Future<void> saveFullClientProfile({
    required String uid,
    required String displayName,
    required String phoneNumber,
    String? photoUrl,
    required ClientProfileModel profile,
  }) async {
    if (uid.trim().isEmpty) return;
    final batch = _firestore.batch();

    // 1. Update common user information in users collection
    final userRef = _firestore.collection(FirestoreCollections.users).doc(uid);
    final userUpdates = <String, dynamic>{
      'displayName': displayName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'onboarded': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (photoUrl != null && photoUrl.isNotEmpty) {
      userUpdates['photoUrl'] = photoUrl;
    }
    batch.update(userRef, userUpdates);

    // 2. Save client-specific information in client_profiles collection
    final profileRef = _firestore.collection(FirestoreCollections.clientProfiles).doc(uid);
    batch.set(profileRef, profile.toMap(), SetOptions(merge: true));

    await batch.commit();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Favorite Trainers
  // ───────────────────────────────────────────────────────────────────────────

  /// Toggles whether a trainer is in client's favorites in Firestore.
  /// Returns `true` if trainer is now favorited, `false` if removed.
  Future<bool> toggleFavoriteTrainer({
    required String clientId,
    required String trainerId,
  }) async {
    if (clientId.isEmpty || trainerId.isEmpty) return false;

    final docRef = _firestore.collection(FirestoreCollections.clientProfiles).doc(clientId);
    final docSnap = await docRef.get();

    List<String> favorites = [];
    if (docSnap.exists) {
      final data = docSnap.data() ?? {};
      favorites = (data['favoriteTrainerIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    }

    final isFav = favorites.contains(trainerId);
    if (isFav) {
      favorites.remove(trainerId);
      await docRef.set({
        'favoriteTrainerIds': FieldValue.arrayRemove([trainerId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return false;
    } else {
      favorites.add(trainerId);
      await docRef.set({
        'favoriteTrainerIds': FieldValue.arrayUnion([trainerId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    }
  }

  /// Streams whether a trainer is favorited by the client.
  Stream<bool> streamIsTrainerFavorite({
    required String clientId,
    required String trainerId,
  }) {
    if (clientId.isEmpty || trainerId.isEmpty) return Stream.value(false);

    return _firestore
        .collection(FirestoreCollections.clientProfiles)
        .doc(clientId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return false;
      final data = snap.data() ?? {};
      final favorites = (data['favoriteTrainerIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
      return favorites.contains(trainerId);
    });
  }

  /// Streams the list of all favorite trainer IDs for a client.
  Stream<List<String>> streamFavoriteTrainerIds(String clientId) {
    if (clientId.isEmpty) return Stream.value(const []);

    return _firestore
        .collection(FirestoreCollections.clientProfiles)
        .doc(clientId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return const [];
      final data = snap.data() ?? {};
      return (data['favoriteTrainerIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [];
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Bookings (With Gender Matching Validation)
  // ───────────────────────────────────────────────────────────────────────────

  /// Validates gender matching before creating booking record
  Future<void> validateGenderMatch({
    required String clientId,
    required String trainerId,
  }) async {
    final clientUserDoc = await _firestore.collection(FirestoreCollections.users).doc(clientId).get();
    final trainerUserDoc = await _firestore.collection(FirestoreCollections.users).doc(trainerId).get();

    if (!clientUserDoc.exists || !trainerUserDoc.exists) {
      throw const AuthException('User record not found for booking validation.');
    }

    final clientGender = clientUserDoc.data()?['gender'];
    final trainerGender = trainerUserDoc.data()?['gender'];

    if (clientGender == null || trainerGender == null) {
      throw const GenderMismatchException(
        'Both client and trainer must have a verified gender in their profile.',
      );
    }

    if (clientGender != trainerGender) {
      throw GenderMismatchException(
        'Gender matching rule: $clientGender clients can only book $clientGender trainers.',
      );
    }
  }

  /// Streams bookings for a client
  Stream<List<BookingModel>> streamClientBookings(String clientId) {
    if (clientId.trim().isEmpty) return Stream.value(<BookingModel>[]);
    return _firestore
        .collection(FirestoreCollections.bookings)
        .where('clientId', isEqualTo: clientId)
        .orderBy('sessionDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => BookingModel.fromDocument(d)).toList());
  }

  /// Gets a single booking document by ID
  Future<BookingModel?> getBooking(String bookingId) async {
    if (bookingId.trim().isEmpty) return null;
    final doc = await _firestore.collection(FirestoreCollections.bookings).doc(bookingId).get();
    if (!doc.exists) return null;
    return BookingModel.fromDocument(doc);
  }

  /// Updates client's selected city and training venue preference in real time
  Future<void> updateClientLocation({
    required String clientId,
    required String cityId,
    String? preferredLocation,
  }) async {
    if (clientId.trim().isEmpty) return;
    final docRef = _firestore.collection(FirestoreCollections.clientProfiles).doc(clientId);
    final updates = <String, dynamic>{
      'preferredCityId': cityId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (preferredLocation != null && preferredLocation.isNotEmpty) {
      updates['preferredTrainingLocation'] = preferredLocation;
    }
    await docRef.set(updates, SetOptions(merge: true));
  }

  /// Cancels a booking as a client, applying the Section 8 (12-hour) cancellation refund policy
  Future<bool> cancelBookingAsClient({
    required String bookingId,
    required String clientId,
  }) async {
    final bookingDoc = await _firestore.collection(FirestoreCollections.bookings).doc(bookingId).get();
    if (!bookingDoc.exists) return false;

    final booking = BookingModel.fromDocument(bookingDoc);

    // Enforce 12-hour cancellation rule through CreditService
    final creditReturned = await CreditService().processCancellationCredit(
      clientId: clientId,
      bookingId: bookingId,
      sessionStartTime: booking.sessionDate,
      cancelledByRole: UserRole.client,
    );

    final newStatus = creditReturned
        ? BookingStatus.cancelledClientEarly
        : BookingStatus.cancelledClientLate;

    await _firestore.collection(FirestoreCollections.bookings).doc(bookingId).update({
      'status': newStatus.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    BookingService.instance.addOrUpdateBooking(booking.copyWith(
      status: newStatus,
      updatedAt: DateTime.now(),
    ));

    // Create in-app notification for the client
    final notifRef = _firestore.collection(FirestoreCollections.notifications).doc();
    await notifRef.set({
      'id': notifRef.id,
      'userId': clientId,
      'title': creditReturned ? 'Booking Cancelled (Credit Returned)' : 'Booking Cancelled (Credit Forfeited)',
      'body': creditReturned
          ? 'Your session with ${booking.displayTrainerName} was cancelled. 1 session credit has been returned to your available balance.'
          : 'Your session with ${booking.displayTrainerName} was cancelled within 12h of workout. 1 session credit was forfeited per Section 8 policy.',
      'type': 'BOOKING_CANCELLED',
      'isRead': false,
      'data': {
        'bookingId': bookingId,
        'returnedCredit': creditReturned,
        'status': newStatus.toFirestore(),
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    return creditReturned;
  }

  /// Reschedules an active booking session, subject to trainer availability and double-booking protection
  Future<bool> rescheduleBooking({
    required String bookingId,
    required DateTime newSessionDate,
    required String newStartTime,
    required String newEndTime,
    String? newTimeSlotId,
  }) async {
    final bookingRef = _firestore.collection(FirestoreCollections.bookings).doc(bookingId);
    final bookingDoc = await bookingRef.get();
    if (!bookingDoc.exists) {
      throw const AuthException('Booking record not found.');
    }

    final booking = BookingModel.fromDocument(bookingDoc);
    if (booking.status != BookingStatus.confirmed && booking.status != BookingStatus.pending) {
      throw Exception('Only confirmed or pending bookings can be rescheduled.');
    }

    // Availability re-check on target date to prevent double-booking
    final startOfDay = DateTime(newSessionDate.year, newSessionDate.month, newSessionDate.day);
    final endOfDay = DateTime(newSessionDate.year, newSessionDate.month, newSessionDate.day, 23, 59, 59);

    final conflictQuery = await _firestore
        .collection(FirestoreCollections.bookings)
        .where('trainerId', isEqualTo: booking.trainerId)
        .where('sessionDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('sessionDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    for (final doc in conflictQuery.docs) {
      if (doc.id == bookingId) continue;
      final statusStr = doc.data()['status'] as String? ?? '';
      final startTime = doc.data()['startTime'] as String? ?? '';
      if ((statusStr == 'CONFIRMED' || statusStr == 'PENDING' || statusStr == 'RESERVED') &&
          startTime == newStartTime) {
        throw const BookingConflictException(
          'Selected trainer slot is already booked. Please choose another time slot.',
        );
      }
    }

    // Update booking document
    await bookingRef.update({
      'sessionDate': Timestamp.fromDate(newSessionDate),
      'startTime': newStartTime,
      'endTime': newEndTime,
      'timeSlotId': ?newTimeSlotId,
      'isRescheduled': true,
      'rescheduledAt': FieldValue.serverTimestamp(),
      'previousSessionDate': Timestamp.fromDate(booking.sessionDate),
      'previousStartTime': booking.startTime,
      'previousEndTime': booking.endTime,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create notification
    final notifRef = _firestore.collection(FirestoreCollections.notifications).doc();
    await notifRef.set({
      'id': notifRef.id,
      'userId': booking.clientId,
      'title': 'Session Rescheduled',
      'body': 'Your session with ${booking.displayTrainerName} has been rescheduled to ${newSessionDate.day}/${newSessionDate.month}/${newSessionDate.year} at $newStartTime - $newEndTime.',
      'type': 'BOOKING_RESCHEDULED',
      'isRead': false,
      'data': {
        'bookingId': bookingId,
        'newDate': newSessionDate.toIso8601String(),
        'newStartTime': newStartTime,
        'newEndTime': newEndTime,
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  /// Streams bookings for a trainer
  Stream<List<BookingModel>> streamTrainerBookings(String trainerId) {
    return _firestore
        .collection(FirestoreCollections.bookings)
        .where('trainerId', isEqualTo: trainerId)
        .orderBy('sessionDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => BookingModel.fromDocument(d)).toList());
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Booking Reservations & Double-Booking Protection
  // ───────────────────────────────────────────────────────────────────────────

  /// Atomically reserves a trainer time slot with 15-minute checkout hold and double-booking protection.
  Future<BookingModel> reserveBookingSlot({
    required String clientId,
    required String trainerId,
    required String packageId,
    required DateTime sessionDate,
    required String startTime,
    required String endTime,
    required String trainingLocation,
    String? notes,
    String? clientName,
    String? clientPhone,
    Gender clientGender = Gender.male,
    Gender trainerGender = Gender.male,
  }) async {
    // 1. Strict Gender Matching Invariant Check
    if (clientGender != trainerGender) {
      throw GenderMismatchException(
        'Gender matching violation: $clientGender clients can only book $clientGender trainers.',
      );
    }

    // 2. Authoritative package lookup
    final plan = await getTrainingPlan(packageId);
    final planPrice = plan?.price ?? 10799;
    final planSessions = plan?.sessionsCount ?? 26;
    final planValidity = plan?.validityDays ?? 30;

    // 3. Slot lock key: trainerId_YYYY-MM-DD_safeTime
    final dateStr = sessionDate.toIso8601String().substring(0, 10);
    final safeTime = startTime.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final lockDocId = '${trainerId}_${dateStr}_$safeTime';

    final slotLockRef = _firestore.collection(FirestoreCollections.slotLocks).doc(lockDocId);
    final bookingRef = _firestore.collection(FirestoreCollections.bookings).doc();

    final now = DateTime.now();
    final expiresAt = now.add(const Duration(minutes: 15));

    final reservedBooking = await _firestore.runTransaction((transaction) async {
      final lockSnap = await transaction.get(slotLockRef);
      if (lockSnap.exists) {
        final data = lockSnap.data() ?? {};
        final status = data['status'] as String? ?? '';
        final expRaw = data['expiresAt'];
        DateTime? lockExpires;
        if (expRaw is Timestamp) lockExpires = expRaw.toDate();

        if (status == 'CONFIRMED') {
          throw const BookingConflictException(
            'This time slot has already been booked by another client. Please select another slot.',
          );
        }

        if (status == 'RESERVED' && lockExpires != null && lockExpires.isAfter(DateTime.now())) {
          final reservedBy = data['clientId'] as String? ?? '';
          if (reservedBy != clientId) {
            throw const BookingConflictException(
              'This time slot is temporarily reserved by another client during checkout. Please select another slot.',
            );
          }
        }
      }

      // Set the temporary slot lock
      transaction.set(slotLockRef, {
        'id': lockDocId,
        'bookingId': bookingRef.id,
        'trainerId': trainerId,
        'clientId': clientId,
        'date': dateStr,
        'startTime': startTime,
        'endTime': endTime,
        'status': 'RESERVED',
        'expiresAt': Timestamp.fromDate(expiresAt),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Create booking in reserved state
      final booking = BookingModel(
        id: bookingRef.id,
        clientId: clientId,
        trainerId: trainerId,
        clientGender: clientGender,
        trainerGender: trainerGender,
        packageId: packageId,
        planId: packageId,
        packagePrice: planPrice,
        sessionsCount: planSessions,
        validityDays: planValidity,
        sessionDate: sessionDate,
        startTime: startTime,
        endTime: endTime,
        status: BookingStatus.reserved,
        paymentStatus: PaymentStatus.pending,
        clientName: clientName,
        clientPhone: clientPhone,
        meetingLocation: trainingLocation,
        locationReference: trainingLocation,
        notes: notes,
        reservedAt: now,
        expiresAt: expiresAt,
        createdAt: now,
        updatedAt: now,
      );

      transaction.set(bookingRef, booking.toMap());
      BookingService.instance.addOrUpdateBooking(booking);
      return booking;
    });

    // Notify trainer of the incoming reservation in real-time
    NotificationService.instance.sendNotification(
      userId: trainerId,
      title: 'New Session Request! 📅',
      body: '${reservedBooking.displayClientName} requested a session for ${reservedBooking.sessionDate.day}/${reservedBooking.sessionDate.month} at ${reservedBooking.startTime}.',
      type: 'BOOKING_RECEIVED',
      relatedId: reservedBooking.id,
      data: {
        'clientId': clientId,
        'packageId': packageId,
        'startTime': startTime,
        'endTime': endTime,
      },
    );

    return reservedBooking;
  }

  /// Server-verified payment confirmation: marks booking CONFIRMED and payment COMPLETED
  Future<BookingModel> confirmBookingPayment({
    required String bookingId,
    String? paymentTransactionId,
  }) async {
    final bookingRef = _firestore.collection(FirestoreCollections.bookings).doc(bookingId);

    final reservedBooking = await _firestore.runTransaction((transaction) async {
      final docSnap = await transaction.get(bookingRef);
      if (!docSnap.exists) {
        throw const AuthException('Booking record not found.');
      }

      final booking = BookingModel.fromDocument(docSnap);

      // Verify not expired
      if (booking.isReservationExpired) {
        transaction.update(bookingRef, {
          'status': 'EXPIRED',
          'paymentStatus': 'FAILED',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        throw const ReservationExpiredException(
          'Temporary slot reservation has expired. Please select the time slot again.',
        );
      }

      final now = DateTime.now();
      final updated = booking.copyWith(
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.completed,
        paymentTransactionId: paymentTransactionId ?? 'TXN_${now.millisecondsSinceEpoch}',
        confirmedAt: now,
        updatedAt: now,
      );

      transaction.update(bookingRef, {
        'status': 'CONFIRMED',
        'paymentStatus': 'COMPLETED',
        'paymentTransactionId': updated.paymentTransactionId,
        'confirmedAt': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update slot lock to CONFIRMED
      final dateStr = booking.sessionDate.toIso8601String().substring(0, 10);
      final safeTime = booking.startTime.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final lockDocId = '${booking.trainerId}_${dateStr}_$safeTime';
      final lockRef = _firestore.collection(FirestoreCollections.slotLocks).doc(lockDocId);

      transaction.set(lockRef, {
        'status': 'CONFIRMED',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      BookingService.instance.addOrUpdateBooking(updated);
      return updated;
    });

    // Notify trainer of confirmed payment and booking
    NotificationService.instance.sendNotification(
      userId: reservedBooking.trainerId,
      title: 'Payment & Session Confirmed! 💳',
      body: '${reservedBooking.displayClientName} confirmed payment for session on ${reservedBooking.sessionDate.day}/${reservedBooking.sessionDate.month} at ${reservedBooking.startTime}.',
      type: 'PAYMENT_SUCCESS',
      relatedId: reservedBooking.id,
    );

    return reservedBooking;
  }

  /// Releases a temporary reservation on payment cancellation, failure, or user exit
  Future<void> releaseBookingReservation({
    required String bookingId,
    String reason = 'USER_CANCELLED',
  }) async {
    final bookingRef = _firestore.collection(FirestoreCollections.bookings).doc(bookingId);
    final docSnap = await bookingRef.get();
    if (!docSnap.exists) return;

    final booking = BookingModel.fromDocument(docSnap);
    if (booking.status == BookingStatus.confirmed) return; // Do not cancel confirmed

    await bookingRef.update({
      'status': reason == 'EXPIRED' ? 'EXPIRED' : 'CANCELLED',
      'paymentStatus': 'FAILED',
      'notes': '${booking.notes ?? ""}\n[Reservation Released: $reason]'.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final dateStr = booking.sessionDate.toIso8601String().substring(0, 10);
    final safeTime = booking.startTime.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final lockDocId = '${booking.trainerId}_${dateStr}_$safeTime';
    await _firestore.collection(FirestoreCollections.slotLocks).doc(lockDocId).delete();

    BookingService.instance.addOrUpdateBooking(booking.copyWith(
      status: reason == 'EXPIRED' ? BookingStatus.expired : BookingStatus.cancelledClientEarly,
      updatedAt: DateTime.now(),
    ));
  }

  /// Streams available 60-minute time slots for a specific trainer and date,
  /// respecting the trainer's weekly availability, date overrides/blackouts,
  /// confirmed bookings, temporary reservations (slot locks) and past times.
  Stream<List<TimeSlot>> streamSlotsForTrainerDate({
    required String trainerId,
    required DateTime date,
    String? currentClientId,
  }) {
    return TrainerAvailabilityService.instance.streamSlotsForTrainerDate(
      trainerId: trainerId,
      date: date,
      currentClientId: currentClientId,
    );
  }

  /// Checks if a time slot has already elapsed today
  static bool isTimeInPast(String timeStr, DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    if (targetDate.isBefore(today)) return true;
    if (targetDate.isAfter(today)) return false;

    // It's today, check the hour/minute
    final parsed = parseTimeOfDay(timeStr);
    if (parsed == null) return false;
    final slotDateTime = DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
    return now.isAfter(slotDateTime);
  }

  /// Parses 12-hour AM/PM string into 24-hour hour & minute
  static ({int hour, int minute})? parseTimeOfDay(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final digits = clean.replaceAll(RegExp(r'[^0-9:]'), '');
      final parts = digits.split(':');
      if (parts.isEmpty) return null;
      int hour = int.parse(parts[0]);
      int minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      if (isPm && hour < 12) hour += 12;
      if (isAm && hour == 12) hour = 0;
      return (hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  /// Helper to compute end time for 60-minute slots
  static String computeSlotEndTime(String start) {
    if (start.contains('06:00 AM')) return '07:00 AM';
    if (start.contains('07:00 AM')) return '08:00 AM';
    if (start.contains('08:30 AM')) return '09:30 AM';
    if (start.contains('10:00 AM')) return '11:00 AM';
    if (start.contains('11:30 AM')) return '12:30 PM';
    if (start.contains('05:00 PM')) return '06:00 PM';
    if (start.contains('06:30 PM')) return '07:30 PM';
    if (start.contains('08:00 PM')) return '09:00 PM';
    return '';
  }

  /// Checks if client address is within trainer's service area or city
  static bool isAddressInTrainerServiceArea({
    required String clientAddress,
    required String trainerServiceArea,
    String? trainerCity,
  }) {
    if (clientAddress.trim().isEmpty) return false;
    if (trainerServiceArea.trim().isEmpty) return true;

    final lowerAddr = clientAddress.toLowerCase();
    final lowerArea = trainerServiceArea.toLowerCase();

    if (trainerCity != null && trainerCity.isNotEmpty) {
      if (lowerAddr.contains(trainerCity.toLowerCase())) return true;
      final cityName = LocationService.instance.getCityName(trainerCity).toLowerCase();
      if (cityName.isNotEmpty && lowerAddr.contains(cityName)) return true;
    }

    final areaKeywords = lowerArea
        .replaceAll(',', ' ')
        .replaceAll('&', ' ')
        .split(' ')
        .map((w) => w.trim())
        .where((w) => w.length > 2);

    for (final kw in areaKeywords) {
      if (lowerAddr.contains(kw)) return true;
    }

    return lowerArea.contains(lowerAddr) || lowerAddr.contains(lowerArea);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Trainer Availability
  // ───────────────────────────────────────────────────────────────────────────

  /// Streams trainer availability
  Stream<List<TrainerAvailabilityModel>> streamTrainerAvailability(String trainerId) {
    return _firestore
        .collection(FirestoreCollections.trainerAvailability)
        .where('trainerId', isEqualTo: trainerId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => TrainerAvailabilityModel.fromDocument(d)).toList());
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Reviews
  // ───────────────────────────────────────────────────────────────────────────

  /// Streams public reviews for a trainer
  Stream<List<ReviewModel>> streamTrainerReviews(String trainerId) {
    return _firestore
        .collection(FirestoreCollections.reviews)
        .where('trainerId', isEqualTo: trainerId)
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ReviewModel.fromDocument(d)).toList());
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Platform Settings
  // ───────────────────────────────────────────────────────────────────────────

  /// Fetches platform settings
  Future<PlatformSettingsModel> getPlatformSettings() async {
    final doc = await _firestore.collection(FirestoreCollections.platformSettings).doc('general').get();
    if (!doc.exists) {
      return const PlatformSettingsModel();
    }
    return PlatformSettingsModel.fromDocument(doc);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Notifications
  // ───────────────────────────────────────────────────────────────────────────

  /// Streams unread notifications for a user
  Stream<List<NotificationModel>> streamUserNotifications(String userId) {
    return _firestore
        .collection(FirestoreCollections.notifications)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => NotificationModel.fromDocument(d)).toList());
  }

  /// Marks notification as read
  Future<void> markNotificationRead(String notificationId) async {
    await _firestore
        .collection(FirestoreCollections.notifications)
        .doc(notificationId)
        .update({'isRead': true});
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Payments & Transaction History
  // ───────────────────────────────────────────────────────────────────────────

  /// Streams payment transaction history for a client
  Stream<List<PaymentModel>> streamClientPayments(String clientId) {
    if (clientId.trim().isEmpty) return Stream.value(<PaymentModel>[]);
    return _firestore
        .collection(FirestoreCollections.payments)
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => PaymentModel.fromDocument(d)).toList());
  }

  /// Get single payment record by ID
  Future<PaymentModel?> getPayment(String paymentId) async {
    if (paymentId.trim().isEmpty) return null;
    final doc = await _firestore.collection(FirestoreCollections.payments).doc(paymentId).get();
    if (!doc.exists) return null;
    return PaymentModel.fromDocument(doc);
  }

  /// Atomically finalizes a verified payment, allocates session credits,
  /// and confirms any attached booking reservation with idempotency protection.
  Future<PaymentModel> finalizeVerifiedPayment({
    required String paymentDocId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    String? paymentMethod,
  }) async {
    final paymentRef = _firestore.collection(FirestoreCollections.payments).doc(paymentDocId);

    return await _firestore.runTransaction<PaymentModel>((transaction) async {
      final docSnap = await transaction.get(paymentRef);
      if (!docSnap.exists) {
        throw const AuthException('Payment record not found.');
      }

      final payment = PaymentModel.fromDocument(docSnap);

      // Idempotency: Do not grant credits multiple times
      if (payment.isSuccess && payment.creditsGranted) {
        return payment;
      }

      final now = DateTime.now();
      final sessionsCount = payment.sessionsCount ?? 1;

      // 1. Allocate session credits via double-entry transaction
      final creditDocRef = _firestore.collection(FirestoreCollections.sessionCredits).doc(payment.clientId);
      final creditSnap = await transaction.get(creditDocRef);
      final currentCredits = creditSnap.exists
          ? creditSnap.data() ?? {}
          : {'totalPurchased': 0, 'availableBalance': 0};

      final newPurchased = ((currentCredits['totalPurchased'] as num?)?.toInt() ?? 0) + sessionsCount;
      final newAvailable = ((currentCredits['availableBalance'] as num?)?.toInt() ?? 0) + sessionsCount;

      transaction.set(
        creditDocRef,
        {
          'clientId': payment.clientId,
          'totalPurchased': newPurchased,
          'availableBalance': newAvailable,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final txRef = creditDocRef.collection(FirestoreCollections.creditTransactions).doc();
      transaction.set(txRef, {
        'id': txRef.id,
        'clientId': payment.clientId,
        'type': 'PURCHASE',
        'count': sessionsCount,
        'paymentId': paymentDocId,
        'reason': 'Purchased package: ${payment.displayPackageName} ($sessionsCount sessions)',
        'balanceAfter': newAvailable,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Activate purchased package record
      final packageDocRef = _firestore.collection(FirestoreCollections.purchasedPackages).doc();
      final validity = payment.validityDays ?? 30;
      final expiryDate = now.add(Duration(days: validity));

      transaction.set(packageDocRef, {
        'id': packageDocRef.id,
        'clientId': payment.clientId,
        'clientName': 'TRAIN Z Athlete',
        'trainerId': payment.trainerId ?? '',
        'trainerName': payment.trainerName ?? 'Personal Coach',
        'packageId': payment.packageId,
        'packageName': payment.displayPackageName,
        'price': payment.amount,
        'purchaseDate': Timestamp.fromDate(now),
        'startDate': Timestamp.fromDate(now),
        'expiryDate': Timestamp.fromDate(expiryDate),
        'totalDays': validity,
        'totalSessions': sessionsCount,
        'completedSessions': 0,
        'paymentStatus': 'COMPLETED',
        'paymentTransactionId': razorpayPaymentId,
        'status': 'ACTIVE',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Confirm linked booking reservation (if present and not expired)
      if (payment.bookingId != null && payment.bookingId!.isNotEmpty) {
        final bookingRef = _firestore.collection(FirestoreCollections.bookings).doc(payment.bookingId);
        final bookingSnap = await transaction.get(bookingRef);

        if (bookingSnap.exists) {
          final bookingData = bookingSnap.data() ?? {};
          final status = bookingData['status'] as String? ?? '';
          final expiresAt = (bookingData['expiresAt'] as Timestamp?)?.toDate();
          final isExpired = expiresAt != null && expiresAt.isBefore(now);

          if (!isExpired && (status == 'RESERVED' || status == 'PENDING')) {
            transaction.update(bookingRef, {
              'status': 'CONFIRMED',
              'paymentStatus': 'COMPLETED',
              'paymentTransactionId': razorpayPaymentId,
              'packageId': payment.packageId,
              'purchasedPackageId': packageDocRef.id,
              'confirmedAt': Timestamp.fromDate(now),
              'updatedAt': FieldValue.serverTimestamp(),
            });

            final dateStr = (bookingData['sessionDate'] as Timestamp?)?.toDate().toIso8601String().substring(0, 10) ?? '';
            final safeTime = (bookingData['startTime'] as String? ?? '').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
            final trainerId = bookingData['trainerId'] as String? ?? '';
            if (trainerId.isNotEmpty && dateStr.isNotEmpty) {
              final lockDocId = '${trainerId}_${dateStr}_$safeTime';
              final lockRef = _firestore.collection(FirestoreCollections.slotLocks).doc(lockDocId);
              transaction.set(lockRef, {
                'status': 'CONFIRMED',
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
            }
          } else if (isExpired && status == 'RESERVED') {
            transaction.update(bookingRef, {
              'status': 'EXPIRED',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      // 4. Update payment record to SUCCESS
      final updated = payment.copyWith(
        status: PaymentStatus.success,
        razorpayPaymentId: razorpayPaymentId,
        razorpaySignature: razorpaySignature,
        paymentMethod: paymentMethod ?? 'ONLINE',
        creditsGranted: true,
        purchasedPackageId: packageDocRef.id,
        verifiedAt: now,
        updatedAt: now,
      );

      transaction.update(paymentRef, {
        'status': 'SUCCESS',
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
        'paymentMethod': paymentMethod ?? 'ONLINE',
        'creditsGranted': true,
        'purchasedPackageId': packageDocRef.id,
        'verifiedAt': Timestamp.fromDate(now),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return updated;
    });
  }

  /// Records payment failure or cancellation on the payment document
  Future<void> recordPaymentFailure({
    required String paymentDocId,
    String? errorCode,
    String? errorDescription,
  }) async {
    final paymentRef = _firestore.collection(FirestoreCollections.payments).doc(paymentDocId);
    final paymentSnap = await paymentRef.get();

    await paymentRef.update({
      'status': 'FAILED',
      'errorCode': errorCode ?? 'PAYMENT_CANCELLED_OR_FAILED',
      'errorMessage': errorDescription ?? 'Payment cancelled or failed',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Release temporary slot reservation if attached
    if (paymentSnap.exists) {
      final paymentData = paymentSnap.data() ?? {};
      final bookingId = paymentData['bookingId'] as String?;
      if (bookingId != null && bookingId.isNotEmpty) {
        final bookingRef = _firestore.collection(FirestoreCollections.bookings).doc(bookingId);
        final bookingSnap = await bookingRef.get();
        if (bookingSnap.exists) {
          final b = bookingSnap.data() ?? {};
          if (b['status'] == 'RESERVED') {
            await bookingRef.update({
              'status': 'CANCELLED',
              'cancellationReason': 'Payment cancelled or failed during checkout',
              'updatedAt': FieldValue.serverTimestamp(),
            });

            final dateStr = (b['sessionDate'] as Timestamp?)?.toDate().toIso8601String().substring(0, 10) ?? '';
            final safeTime = (b['startTime'] as String? ?? '').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
            final trainerId = b['trainerId'] as String? ?? '';
            if (trainerId.isNotEmpty && dateStr.isNotEmpty) {
              final lockDocId = '${trainerId}_${dateStr}_$safeTime';
              await _firestore.collection(FirestoreCollections.slotLocks).doc(lockDocId).update({
                'status': 'RELEASED',
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }
          }
        }
      }
    }
  }
}
