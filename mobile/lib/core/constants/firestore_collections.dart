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
  static const String reviewReports = 'review_reports';
  static const String notifications = 'notifications';
  static const String purchasedPackages = 'purchased_packages';
  static const String platformSettings = 'platform_settings';
  static const String slotLocks = 'slot_locks';
  static const String conversations = 'conversations';
  static const String messages = 'messages';
  static const String trainerCertificates = 'trainer_certificates';
  static const String supportTickets = 'support_tickets';
  static const String deletionRequests = 'deletion_requests';
  static const String userSettings = 'settings';
  static const String deletionAudits = 'deletion_audits';

  /// Subcollections
  static const String creditTransactions = 'transactions';
  static const String availabilitySlots = 'slots';
  static const String supportMessages = 'messages';

  /// Storage buckets & directories
  static const String storageProfilePictures = 'profile_pictures';
  static const String storageCertificates = 'certificates';
  static const String storageTrainerCertifications = 'trainer_documents/certifications';
  static const String storageTrainerVerifications = 'trainer_documents/verifications';
  static const String storageSupportAttachments = 'support_attachments';
}

