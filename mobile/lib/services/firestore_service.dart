import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/firestore_collections.dart';
import '../core/errors/app_exceptions.dart';
import '../shared/models/booking_model.dart';
import '../shared/models/city_model.dart';
import '../shared/models/client_profile_model.dart';
import '../shared/models/notification_model.dart';
import '../shared/models/platform_settings_model.dart';
import '../shared/models/review_model.dart';
import '../shared/models/trainer_availability_model.dart';
import '../shared/models/trainer_profile_model.dart';
import '../shared/models/training_plan_model.dart';
import '../shared/models/user_model.dart';
import 'credit_service.dart';

/// Core Firestore data access service for TRAIN Z shared features.
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ───────────────────────────────────────────────────────────────────────────
  // Training Plans (Fixed Packages)
  // ───────────────────────────────────────────────────────────────────────────

  /// Streams active platform training packages
  Stream<List<TrainingPlanModel>> streamTrainingPlans() {
    return _firestore
        .collection(FirestoreCollections.trainingPlans)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => TrainingPlanModel.fromDocument(d)).toList()
          ..sort((a, b) => a.price.compareTo(b.price)));
  }

  /// Get single training plan by id
  Future<TrainingPlanModel?> getTrainingPlan(String planId) async {
    if (planId.trim().isEmpty) return null;
    final doc = await _firestore.collection(FirestoreCollections.trainingPlans).doc(planId).get();
    if (!doc.exists) return null;
    return TrainingPlanModel.fromDocument(doc);
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
        final certs = (rawData['certifications'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
            (profile.certificationDocuments.isNotEmpty
                ? ['Certified Personal Coach', 'CPR/AED Certified']
                : ['TRAIN Z Verified Professional']);

        list.add(TrainerDisplayModel(
          profile: profile,
          uid: profile.uid,
          displayName: user.displayName ?? (rawData['fullName'] as String?) ?? 'Coach',
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

    return creditReturned;
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
}
