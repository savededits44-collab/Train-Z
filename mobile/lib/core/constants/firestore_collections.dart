/// Centralized registry of all Firestore collection and subcollection names for TRAIN Z.
class FirestoreCollections {
  FirestoreCollections._();

  /// Primary collections
  static const String users = 'users';
  static const String clientProfiles = 'client_profiles';
  static const String trainerProfiles = 'trainer_profiles';
  static const String cities = 'cities';
  static const String trainingPlans = 'training_plans';
  static const String bookings = 'bookings';
  static const String payments = 'payments';
  static const String sessionCredits = 'session_credits';
  static const String trainerAvailability = 'trainer_availability';
  static const String reviews = 'reviews';
  static const String notifications = 'notifications';
  static const String platformSettings = 'platform_settings';

  /// Subcollections
  static const String creditTransactions = 'transactions';
  static const String availabilitySlots = 'slots';

  /// Storage buckets & directories
  static const String storageProfilePictures = 'profile_pictures';
  static const String storageTrainerCertifications = 'trainer_documents/certifications';
  static const String storageTrainerVerifications = 'trainer_documents/verifications';
}

