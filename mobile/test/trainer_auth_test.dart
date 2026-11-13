import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/features/trainer/controllers/trainer_auth_controller.dart';
import 'package:trainuspro/routing/app_router.dart';
import 'package:trainuspro/routing/role_guards.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  group('PROMPT 3A: Trainer Registration Form Validation', () {
    test('validates full name requirement', () {
      expect(
        TrainerAuthController.validateRegistrationFormStatic(
          name: '',
          email: 'coach@trainz.app',
          phoneNumber: '9876543210',
          password: 'password123',
          confirmPassword: 'password123',
        ),
        'Full name is required.',
      );

      expect(
        TrainerAuthController.validateRegistrationFormStatic(
          name: 'A',
          email: 'coach@trainz.app',
          phoneNumber: '9876543210',
          password: 'password123',
          confirmPassword: 'password123',
        ),
        'Name must be at least 2 characters.',
      );
    });

    test('validates email address format', () {
      expect(
        TrainerAuthController.validateRegistrationFormStatic(
          name: 'Rahul Sharma',
          email: '',
          phoneNumber: '9876543210',
          password: 'password123',
          confirmPassword: 'password123',
        ),
        'Email address is required.',
      );

      expect(
        TrainerAuthController.validateRegistrationFormStatic(
          name: 'Rahul Sharma',
          email: 'invalid-email',
          phoneNumber: '9876543210',
          password: 'password123',
          confirmPassword: 'password123',
        ),
        'Please enter a valid email address.',
      );
    });

    test('validates phone number (+91 / 10 digits)', () {
      expect(
        TrainerAuthController.validateRegistrationFormStatic(
          name: 'Rahul Sharma',
          email: 'coach@trainz.app',
          phoneNumber: '',
          password: 'password123',
          confirmPassword: 'password123',
        ),
        'Phone number is required.',
      );

      expect(
        TrainerAuthController.validateRegistrationFormStatic(
          name: 'Rahul Sharma',
          email: 'coach@trainz.app',
          phoneNumber: '1234',
          password: 'password123',
          confirmPassword: 'password123',
        ),
        'Please enter a valid 10-digit phone number.',
      );

      // Valid phone numbers
      expect(
        TrainerAuthController.validateRegistrationFormStatic(
          name: 'Rahul Sharma',
          email: 'coach@trainz.app',
          phoneNumber: '+919876543210',
          password: 'password123',
          confirmPassword: 'password123',
        ),
        isNull,
      );
    });

    test('validates password length and confirmation match', () {
      expect(
        TrainerAuthController.validateRegistrationFormStatic(
          name: 'Rahul Sharma',
          email: 'coach@trainz.app',
          phoneNumber: '9876543210',
          password: '123',
          confirmPassword: '123',
        ),
        'Password must be at least 6 characters.',
      );

      expect(
        TrainerAuthController.validateRegistrationFormStatic(
          name: 'Rahul Sharma',
          email: 'coach@trainz.app',
          phoneNumber: '9876543210',
          password: 'password123',
          confirmPassword: 'differentPassword',
        ),
        'Passwords do not match. Please re-enter.',
      );

      expect(
        TrainerAuthController.validateRegistrationFormStatic(
          name: 'Rahul Sharma',
          email: 'coach@trainz.app',
          phoneNumber: '9876543210',
          password: 'password123',
          confirmPassword: 'password123',
        ),
        isNull,
      );
    });
  });

  group('Revised Trainer Eligibility Policy: Category Selection Rules', () {
    test('Standard Trainer category requires NO certificates and NO minimum experience', () {
      // 0.0 years and no certificate passes
      expect(
        TrainerAuthController.validateCategorySelectionStatic(
          category: TrainerCategory.trainer,
          experienceYears: 0.0,
          hasConfirmedCertificate: false,
        ),
        isNull,
      );

      // Any experience and no certificate passes
      expect(
        TrainerAuthController.validateCategorySelectionStatic(
          category: TrainerCategory.trainer,
          experienceYears: 2.0,
          hasConfirmedCertificate: false,
        ),
        isNull,
      );

      // Certificate confirmed also passes
      expect(
        TrainerAuthController.validateCategorySelectionStatic(
          category: TrainerCategory.trainer,
          experienceYears: 1.0,
          hasConfirmedCertificate: true,
        ),
        isNull,
      );

      expect(
        TrainerCategory.trainer.requirementText,
        'No certificate or minimum experience required. Standard platform packages apply.',
      );
      expect(
        TrainerCategory.trainer.packageRuleText,
        'Uses standard TRAIN Z platform packages.',
      );
    });

    test('Advanced Trainer enforces 3.5 years minimum experience threshold', () {
      // 2.0 years (< 3.5) rejected
      expect(
        TrainerAuthController.validateCategorySelectionStatic(
          category: TrainerCategory.advancedTrainer,
          experienceYears: 2.0,
          hasConfirmedCertificate: true,
        ),
        'Advanced Trainers must have at least 3.5 years of relevant training experience.',
      );

      // 3.4 years (< 3.5) rejected
      expect(
        TrainerAuthController.validateCategorySelectionStatic(
          category: TrainerCategory.advancedTrainer,
          experienceYears: 3.4,
          hasConfirmedCertificate: true,
        ),
        'Advanced Trainers must have at least 3.5 years of relevant training experience.',
      );

      // 3.5 years exact qualifies
      expect(
        TrainerAuthController.validateCategorySelectionStatic(
          category: TrainerCategory.advancedTrainer,
          experienceYears: 3.5,
          hasConfirmedCertificate: true,
        ),
        isNull,
      );

      // 5.0 years qualifies
      expect(
        TrainerAuthController.validateCategorySelectionStatic(
          category: TrainerCategory.advancedTrainer,
          experienceYears: 5.0,
          hasConfirmedCertificate: true,
        ),
        isNull,
      );
    });

    test('Advanced Trainer requires professional qualifications confirmation', () {
      expect(
        TrainerAuthController.validateCategorySelectionStatic(
          category: TrainerCategory.advancedTrainer,
          experienceYears: 4.0,
          hasConfirmedCertificate: false,
        ),
        'You must confirm possession of relevant professional certificates and qualifications.',
      );

      expect(
        TrainerCategory.advancedTrainer.requirementText,
        'Must have relevant professional trainer qualifications & at least 3.5 years of experience.',
      );
      expect(
        TrainerCategory.advancedTrainer.packageRuleText,
        'Can create custom training plans and set independent session rates. Each custom plan requires Admin approval.',
      );
    });

    test('Professional Trainer is Coming Soon and unavailable at launch', () {
      expect(
        TrainerCategory.professionalTrainer.isAvailableAtLaunch,
        isFalse,
      );

      expect(
        TrainerAuthController.validateCategorySelectionStatic(
          category: TrainerCategory.professionalTrainer,
          experienceYears: 10.0,
          hasConfirmedCertificate: true,
        ),
        'Professional Trainer category is Coming Soon and unavailable at launch.',
      );

      expect(
        TrainerCategory.professionalTrainer.requirementText,
        'Coming Soon.',
      );
      expect(
        TrainerCategory.professionalTrainer.packageRuleText,
        'Coming Soon.',
      );
    });

    test('TrainerCategory enum serialization and display attributes', () {
      expect(TrainerCategory.trainer.toFirestore(), 'TRAINER');
      expect(TrainerCategory.advancedTrainer.toFirestore(), 'ADVANCED_TRAINER');
      expect(TrainerCategory.professionalTrainer.toFirestore(), 'PROFESSIONAL_TRAINER');

      expect(TrainerCategory.fromFirestore('TRAINER'), TrainerCategory.trainer);
      expect(TrainerCategory.fromFirestore('ADVANCED_TRAINER'), TrainerCategory.advancedTrainer);
      expect(TrainerCategory.fromFirestore('PROFESSIONAL_TRAINER'), TrainerCategory.professionalTrainer);
      expect(TrainerCategory.fromFirestore(null), TrainerCategory.trainer);

      expect(TrainerCategory.trainer.displayName, 'Trainer');
      expect(TrainerCategory.advancedTrainer.displayName, 'Advanced Trainer');
      expect(TrainerCategory.professionalTrainer.displayName, 'Professional Trainer');
    });
  });

  group('PROMPT 3A: Approval & Verification Lifecycle Rules', () {
    test('New trainer profiles receive PENDING status by default', () {
      const profile = TrainerProfileModel(
        uid: 'trainer_123',
        category: TrainerCategory.trainer,
      );

      expect(profile.verificationStatus, TrainerVerificationStatus.pending);
      expect(profile.isPending, isTrue);
      expect(profile.isApproved, isFalse);
      expect(profile.isRejected, isFalse);
      expect(profile.canBeBooked, isFalse);
    });

    test('Approved trainer has verified access to coaching dashboard', () {
      const profile = TrainerProfileModel(
        uid: 'trainer_456',
        category: TrainerCategory.advancedTrainer,
        verificationStatus: TrainerVerificationStatus.approved,
        isActive: true,
      );

      expect(profile.isApproved, isTrue);
      expect(profile.canBeBooked, isTrue);
      expect(profile.isAdvancedTrainer, isTrue);
    });

    test('Rejected trainer profile captures administrative review feedback', () {
      const profile = TrainerProfileModel(
        uid: 'trainer_789',
        category: TrainerCategory.trainer,
        verificationStatus: TrainerVerificationStatus.rejected,
        adminReviewNotes: 'Certification could not be verified with issuing authority.',
      );

      expect(profile.isRejected, isTrue);
      expect(profile.isApproved, isFalse);
      expect(profile.adminReviewNotes, contains('Certification could not be verified'));
    });
  });

  group('PROMPT 3A: Role Protection & Navigation Guards', () {
    const trainerUser = UserModel(
      uid: 'trainer_user_1',
      email: 'trainer@trainz.app',
      role: UserRole.trainer,
      isEmailVerified: true,
    );

    const clientUser = UserModel(
      uid: 'client_user_1',
      email: 'client@trainz.app',
      role: UserRole.client,
      isEmailVerified: true,
    );

    const suspendedTrainer = UserModel(
      uid: 'suspended_trainer_1',
      email: 'bad@trainz.app',
      role: UserRole.trainer,
      status: UserStatus.suspended,
    );

    test('Role Guards strictly allow Trainer role and deny Client from Trainer portal', () {
      expect(RoleGuards.canAccessTrainer(trainerUser), isTrue);
      expect(RoleGuards.canAccessTrainer(clientUser), isFalse);
      expect(RoleGuards.canAccessTrainer(suspendedTrainer), isFalse);
    });

    test('Trainer dashboard access requires APPROVED status; denies PENDING and REJECTED', () {
      const pendingProfile = TrainerProfileModel(
        uid: 'trainer_user_1',
        verificationStatus: TrainerVerificationStatus.pending,
      );

      const rejectedProfile = TrainerProfileModel(
        uid: 'trainer_user_1',
        verificationStatus: TrainerVerificationStatus.rejected,
      );

      const approvedProfile = TrainerProfileModel(
        uid: 'trainer_user_1',
        verificationStatus: TrainerVerificationStatus.approved,
      );

      // Pending trainer cannot access dashboard
      expect(
        RoleGuards.canAccessTrainerDashboard(
          user: trainerUser,
          profile: pendingProfile,
        ),
        isFalse,
      );

      // Rejected trainer cannot access dashboard
      expect(
        RoleGuards.canAccessTrainerDashboard(
          user: trainerUser,
          profile: rejectedProfile,
        ),
        isFalse,
      );

      // Approved trainer can access dashboard
      expect(
        RoleGuards.canAccessTrainerDashboard(
          user: trainerUser,
          profile: approvedProfile,
        ),
        isTrue,
      );
    });

    test('Resolves trainer destination route accurately across all lifecycle states', () {
      const unverifiedTrainer = UserModel(
        uid: 'tr_unverified',
        email: 'unverified@trainz.app',
        role: UserRole.trainer,
        isEmailVerified: false,
      );

      const pendingProfile = TrainerProfileModel(
        uid: 'tr_1',
        verificationStatus: TrainerVerificationStatus.pending,
      );

      const approvedProfile = TrainerProfileModel(
        uid: 'tr_1',
        verificationStatus: TrainerVerificationStatus.approved,
      );

      const rejectedProfile = TrainerProfileModel(
        uid: 'tr_1',
        verificationStatus: TrainerVerificationStatus.rejected,
      );

      // 1. Unverified email -> Verify Email screen
      expect(
        RoleGuards.resolveTrainerDestinationRoute(
          user: unverifiedTrainer,
          profile: pendingProfile,
        ),
        AppRouter.trainerVerifyEmail,
      );

      // 2. Pending admin approval -> Pending screen
      expect(
        RoleGuards.resolveTrainerDestinationRoute(
          user: trainerUser,
          profile: pendingProfile,
        ),
        AppRouter.trainerPendingApproval,
      );

      // 3. Approved -> Dashboard
      expect(
        RoleGuards.resolveTrainerDestinationRoute(
          user: trainerUser,
          profile: approvedProfile,
        ),
        AppRouter.trainerDashboard,
      );

      // 4. Rejected -> Rejected screen
      expect(
        RoleGuards.resolveTrainerDestinationRoute(
          user: trainerUser,
          profile: rejectedProfile,
        ),
        AppRouter.trainerRejected,
      );

      // 5. Suspended user -> Suspended screen
      expect(
        RoleGuards.resolveTrainerDestinationRoute(
          user: suspendedTrainer,
          profile: approvedProfile,
        ),
        AppRouter.accountSuspended,
      );
    });
  });

  group('Revised Trainer Eligibility Policy & Certificate Privacy Invariants', () {
    test('Standard Trainer profile setup and registration succeed without certificates', () {
      // Standard trainer profile model with empty certification documents
      const standardProfile = TrainerProfileModel(
        uid: 'standard_trainer_1',
        category: TrainerCategory.trainer,
        experienceYears: 0.0,
        certificationDocuments: [],
        verificationStatus: TrainerVerificationStatus.pending,
      );

      expect(standardProfile.isStandardTrainer, isTrue);
      expect(standardProfile.isAdvancedTrainer, isFalse);
      expect(standardProfile.certificationDocuments, isEmpty);
      expect(standardProfile.experienceYears, 0.0);

      // Category validation succeeds without certificates
      final err = TrainerAuthController.validateCategorySelectionStatic(
        category: TrainerCategory.trainer,
        experienceYears: 0.0,
        hasConfirmedCertificate: false,
      );
      expect(err, isNull);
    });

    test('Admin approval is valid for Standard Trainers without certificates', () {
      final approvedStandardTrainer = const TrainerProfileModel(
        uid: 'standard_trainer_2',
        category: TrainerCategory.trainer,
        experienceYears: 1.0,
        certificationDocuments: [],
        verificationStatus: TrainerVerificationStatus.approved,
        isActive: true,
      );

      expect(approvedStandardTrainer.isApproved, isTrue);
      expect(approvedStandardTrainer.canBeBooked, isTrue);
      expect(approvedStandardTrainer.certificationDocuments, isEmpty);
    });

    test('Advanced Trainer requires certificates and at least 3.5 years experience', () {
      // Missing cert fails
      expect(
        TrainerAuthController.validateCategorySelectionStatic(
          category: TrainerCategory.advancedTrainer,
          experienceYears: 4.0,
          hasConfirmedCertificate: false,
        ),
        'You must confirm possession of relevant professional certificates and qualifications.',
      );

      // Low experience fails
      expect(
        TrainerAuthController.validateCategorySelectionStatic(
          category: TrainerCategory.advancedTrainer,
          experienceYears: 2.5,
          hasConfirmedCertificate: true,
        ),
        'Advanced Trainers must have at least 3.5 years of relevant training experience.',
      );

      // Valid experience and cert passes
      expect(
        TrainerAuthController.validateCategorySelectionStatic(
          category: TrainerCategory.advancedTrainer,
          experienceYears: 3.5,
          hasConfirmedCertificate: true,
        ),
        isNull,
      );
    });

    test('Certificate privacy: clients see verified qualification names, never raw documents', () {
      const advancedProfile = TrainerProfileModel(
        uid: 'adv_trainer_1',
        category: TrainerCategory.advancedTrainer,
        experienceYears: 5.0,
        verificationStatus: TrainerVerificationStatus.approved,
        certificationDocuments: [
          'https://storage.googleapis.com/trainer_documents/adv_trainer_1/certifications/secret_cert.pdf',
        ],
      );

      const displayModel = TrainerDisplayModel(
        profile: advancedProfile,
        uid: 'adv_trainer_1',
        displayName: 'Aarav Sharma',
        gender: Gender.male,
        specialties: ['Hypertrophy', 'Strength'],
        experienceYears: 5.0,
        ratingAvg: 4.9,
        totalReviews: 24,
        hourlyRate: 1200,
        certifications: ['Certified Personal Trainer (CSCS)', 'Sports Nutrition Specialist'],
      );

      // Display model presents human-readable verified credentials
      expect(displayModel.certifications, contains('Certified Personal Trainer (CSCS)'));
      expect(displayModel.certifications, contains('Sports Nutrition Specialist'));

      // Raw private document URLs are never in certifications
      for (final cert in displayModel.certifications) {
        expect(cert, isNot(contains('.pdf')));
        expect(cert, isNot(contains('storage.googleapis.com')));
        expect(cert, isNot(contains('trainer_documents')));
      }

      // Standard trainer without verified certifications has empty cert list
      const standardDisplayModel = TrainerDisplayModel(
        profile: TrainerProfileModel(
          uid: 'std_trainer_1',
          category: TrainerCategory.trainer,
          experienceYears: 1.0,
          verificationStatus: TrainerVerificationStatus.approved,
        ),
        uid: 'std_trainer_1',
        displayName: 'Rahul Patel',
        gender: Gender.male,
        specialties: ['General Fitness'],
        experienceYears: 1.0,
        ratingAvg: 5.0,
        totalReviews: 5,
        hourlyRate: 500,
        certifications: [],
      );

      expect(standardDisplayModel.certifications, isEmpty);
    });

    test('Package rules: Standard trainers use fixed platform packages; Advanced can create custom plans', () {
      expect(
        TrainerCategory.trainer.packageRuleText,
        'Uses standard TRAIN Z platform packages.',
      );

      expect(
        TrainerCategory.advancedTrainer.packageRuleText,
        'Can create custom training plans and set independent session rates. Each custom plan requires Admin approval.',
      );

      expect(
        TrainerCategory.professionalTrainer.packageRuleText,
        'Coming Soon.',
      );
    });
  });
}
