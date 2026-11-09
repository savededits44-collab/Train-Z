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

  /// Get trainer profile
  Future<TrainerProfileModel?> getTrainerProfile(String trainerId) async {
    final doc = await _firestore.collection(FirestoreCollections.trainerProfiles).doc(trainerId).get();
    if (!doc.exists) return null;
    return TrainerProfileModel.fromDocument(doc);
  }

  /// Get client profile
  Future<ClientProfileModel?> getClientProfile(String clientId) async {
    final doc = await _firestore.collection(FirestoreCollections.clientProfiles).doc(clientId).get();
    if (!doc.exists) return null;
    return ClientProfileModel.fromDocument(doc);
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
    return _firestore
        .collection(FirestoreCollections.bookings)
        .where('clientId', isEqualTo: clientId)
        .orderBy('sessionDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => BookingModel.fromDocument(d)).toList());
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
