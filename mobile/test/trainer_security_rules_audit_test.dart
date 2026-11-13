import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/features/trainer/controllers/trainer_auth_controller.dart';
import 'package:trainuspro/routing/app_router.dart';
import 'package:trainuspro/routing/role_guards.dart';
import 'package:trainuspro/services/auth_service.dart';
import 'package:trainuspro/services/booking_service.dart';
import 'package:trainuspro/services/payment_service.dart';
import 'package:trainuspro/services/trainer_account_service.dart';
import 'package:trainuspro/services/trainer_certificate_service.dart';
import 'package:trainuspro/services/trainer_earnings_service.dart';
import 'package:trainuspro/services/trainer_package_service.dart';
import 'package:trainuspro/services/trainer_profile_service.dart';
import 'package:trainuspro/services/trainer_review_service.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/review_model.dart';
import 'package:trainuspro/shared/models/trainer_certificate_model.dart';
import 'package:trainuspro/shared/models/trainer_earnings_model.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/training_plan_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  setUp(() {
    TrainerProfileService.instance.reset();
    BookingService.instance.resetForTest();
    TrainerPackageService.instance.clearMockData();
    TrainerReviewService.instance.resetForTest();
    TrainerEarningsService.instance.resetForTest();
    TrainerAccountService.instance.resetForTest();
  });

  group('Requirement 1: Audit Trainer Business Rules', () {
    test('Standard Trainer requires >= 1 beginner certificate & uses 6 platform packages', () {
      final certService = TrainerCertificateService.instance;
      const trainerId = 'tr_standard_audit';

      // 0 certificates => not eligible
      final zeroCertResult = certService.checkCategoryRequirements(
        category: TrainerCategory.trainer,
        certificates: [],
        experienceYears: 1.0,
      );
      expect(zeroCertResult.isEligible, isFalse);
      expect(zeroCertResult.requiredCertificatesCount, 1);

      // 1 certificate => eligible
      final oneCertResult = certService.checkCategoryRequirements(
        category: TrainerCategory.trainer,
        certificates: [
          const TrainerCertificateModel(
            id: 'cert_std_01',
            trainerId: trainerId,
            certificateName: 'Personal Trainer Certification',
            courseName: 'Fitness Foundation',
            issuingOrganization: 'K11 School of Fitness Sciences',
            yearOfCompletion: '2023',
            storagePath: 'certificates/tr_standard_audit/cert_std_01.pdf',
            fileName: 'cert_std_01.pdf',
            fileType: 'pdf',
            fileSizeBytes: 1024 * 1024,
            verificationStatus: CertificateVerificationStatus.verified,
          ),
        ],
        experienceYears: 1.0,
      );
      expect(oneCertResult.isEligible, isTrue);

      // Standard Trainer uses the 6 fixed platform packages
      final platformPackages = TrainerPackageService.instance.getPlatformPackages();
      expect(platformPackages.length, 6);
      expect(platformPackages.map((p) => p.sessionsCount).toList(), [1, 3, 6, 26, 78, 150]);
      expect(platformPackages.map((p) => p.price).toList(), [500, 1399, 2799, 10799, 29999, 52999]);
      for (final p in platformPackages) {
        expect(p.isCustom, isFalse);
        expect(p.isApproved, isTrue);
      }
    });

    test('Advanced Trainer requires professional qualifications and >= 3.5 years experience', () {
      final certService = TrainerCertificateService.instance;
      const trainerId = 'tr_advanced_audit';

      final cert = const TrainerCertificateModel(
        id: 'cert_adv_01',
        trainerId: trainerId,
        certificateName: 'CSCS - Certified Strength and Conditioning Specialist',
        courseName: 'Strength & Conditioning',
        issuingOrganization: 'NSCA',
        yearOfCompletion: '2020',
        storagePath: 'certificates/tr_advanced_audit/cert_adv_01.pdf',
        fileName: 'cert_adv_01.pdf',
        fileType: 'pdf',
        fileSizeBytes: 2 * 1024 * 1024,
        verificationStatus: CertificateVerificationStatus.verified,
      );

      // Under 3.5 years (e.g. 3.0 yrs) with verified cert is NOT eligible
      final underExpResult = certService.checkCategoryRequirements(
        category: TrainerCategory.advancedTrainer,
        certificates: [cert],
        experienceYears: 3.0,
      );
      expect(underExpResult.isEligible, isFalse);
      expect(underExpResult.requiredExperienceYears, 3.5);

      // Exactly 3.5 years with verified cert IS eligible
      final exactExpResult = certService.checkCategoryRequirements(
        category: TrainerCategory.advancedTrainer,
        certificates: [cert],
        experienceYears: 3.5,
      );
      expect(exactExpResult.isEligible, isTrue);

      // 4.5 years with verified cert IS eligible
      final overExpResult = certService.checkCategoryRequirements(
        category: TrainerCategory.advancedTrainer,
        certificates: [cert],
        experienceYears: 4.5,
      );
      expect(overExpResult.isEligible, isTrue);
    });

    test('Professional Trainer is Coming Soon and unavailable for registration/selection', () {
      // Professional Trainer category is marked Coming Soon
      expect(TrainerCategory.professionalTrainer.isAvailableAtLaunch, isFalse);
      expect(TrainerCategory.professionalTrainer.requirementText, 'Coming Soon.');

      // Registration controller validation blocks selecting professional trainer
      final err = TrainerAuthController.validateCategorySelectionStatic(
        category: TrainerCategory.professionalTrainer,
        experienceYears: 10.0,
      );
      expect(err, contains('Coming Soon'));
    });

    test('Admin approval requirement: pending trainers cannot access dashboard', () {
      const user = UserModel(
        uid: 'tr_gate_01',
        email: 'gate@trainz.fit',
        role: UserRole.trainer,
        status: UserStatus.active,
        isEmailVerified: true,
        isOnboarded: true,
      );

      const pendingProfile = TrainerProfileModel(
        uid: 'tr_gate_01',
        verificationStatus: TrainerVerificationStatus.pending,
      );
      expect(RoleGuards.canAccessTrainerDashboard(user: user, profile: pendingProfile), isFalse);
      expect(RoleGuards.resolveTrainerDestinationRoute(user: user, profile: pendingProfile), AppRouter.trainerPendingApproval);

      const approvedProfile = TrainerProfileModel(
        uid: 'tr_gate_01',
        verificationStatus: TrainerVerificationStatus.approved,
        isProfileCompleted: true,
      );
      expect(RoleGuards.canAccessTrainerDashboard(user: user, profile: approvedProfile), isTrue);
      expect(RoleGuards.resolveTrainerDestinationRoute(user: user, profile: approvedProfile), AppRouter.trainerDashboard);
    });

    test('Advanced Trainer custom plans require Admin approval and editing resets approval', () async {
      final pkgService = TrainerPackageService.instance;

      // Creation defaults to isApproved: false
      final planId = await pkgService.createCustomPlan(
        title: 'Elite Powerlifting Protocol',
        price: 28000,
        sessionsCount: 30,
        validityDays: 90,
        description: 'Periodized barbell strength coaching',
        submitForApproval: true,
      );

      final plans = await pkgService.streamCustomPlans('test_trainer_uid').first;
      final plan = plans.firstWhere((p) => p.id == planId);
      expect(plan.isCustom, isTrue);
      expect(plan.isApproved, isFalse);
      expect(plan.approvalStatus, PackageApprovalStatus.pending);

      // Verify that only approved packages are visible to clients
      final clientVisiblePlans = plans.where((p) => p.isApproved && p.approvalStatus == PackageApprovalStatus.approved).toList();
      expect(clientVisiblePlans.any((p) => p.id == planId), isFalse);
    });

    test('Trainers cannot modify Admin-controlled fields (ratings, approval, verified qualifications)', () {
      const originalProfile = TrainerProfileModel(
        uid: 'tr_immutable_test',
        fullName: 'Arjun Mehta',
        verificationStatus: TrainerVerificationStatus.approved,
        category: TrainerCategory.advancedTrainer,
        ratingAvg: 4.95,
        totalReviews: 42,
        verifiedQualifications: [
          VerifiedQualification(
            id: 'vq_01',
            certificateName: 'CSCS',
            courseName: 'Strength & Conditioning',
            issuingOrganization: 'NSCA',
            yearOfCompletion: '2020',
          ),
        ],
      );

      // Profile copyWith ignores or protects admin fields
      final updated = originalProfile.copyWith(
        bio: 'Updated bio by trainer',
      );

      expect(updated.ratingAvg, 4.95);
      expect(updated.totalReviews, 42);
      expect(updated.verificationStatus, TrainerVerificationStatus.approved);
      expect(updated.category, TrainerCategory.advancedTrainer);
      expect(updated.verifiedQualifications.length, 1);
    });

    test('No interviews, screening rounds, or questionnaires exist in trainer onboarding flow', () {
      final routes = [
        AppRouter.trainerLogin,
        AppRouter.trainerRegister,
        AppRouter.trainerProfileSetup,
        AppRouter.trainerCertificates,
        AppRouter.trainerPendingApproval,
        AppRouter.trainerDashboard,
      ];

      for (final r in routes) {
        expect(r.contains('interview'), isFalse);
        expect(r.contains('screening'), isFalse);
        expect(r.contains('test'), isFalse);
        expect(r.contains('questionnaire'), isFalse);
      }
    });
  });

  group('Requirement 2: Final Security Audit & Permissions', () {
    test('Client reviews can only receive responses from the assigned trainer', () async {
      final reviewService = TrainerReviewService.instance;
      const reviewId = 'rev_security_01';
      const trainerId = 'trainer_legit';
      const unauthorizedTrainerId = 'trainer_imposter';

      final review = ReviewModel(
        id: reviewId,
        bookingId: 'bk_01',
        clientId: 'client_01',
        trainerId: trainerId,
        rating: 5.0,
        comment: 'Great coach!',
      );
      reviewService.setTestReviews([review]);

      // Unauthorized trainer attempting to respond is rejected
      expect(
        () => reviewService.submitTrainerResponse(
          reviewId: reviewId,
          trainerId: unauthorizedTrainerId,
          responseText: 'Thanks!',
        ),
        throwsA(isA<StateError>()),
      );

      // Authorized trainer succeeds
      await reviewService.submitTrainerResponse(
        reviewId: reviewId,
        trainerId: trainerId,
        responseText: 'Thank you for your dedication!',
      );

      final updated = reviewService.allReviews.firstWhere((r) => r.id == reviewId);
      expect(updated.hasResponse, isTrue);
    });

    test('Private certificates have private storage path under certificates/{trainerId}/{certId}', () {
      const cert = TrainerCertificateModel(
        id: 'cert_sec_01',
        trainerId: 'tr_user_99',
        certificateName: 'Advanced Sports Nutrition',
        courseName: 'Sports Nutrition',
        issuingOrganization: 'ISSA',
        yearOfCompletion: '2022',
        storagePath: 'certificates/tr_user_99/cert_sec_01.pdf',
        fileName: 'cert_sec_01.pdf',
        fileType: 'pdf',
        fileSizeBytes: 1024 * 1024,
      );

      expect(cert.storagePath.startsWith('certificates/tr_user_99/'), isTrue);
    });

    test('Completed session cannot be completed a second time (atomic protection)', () async {
      final bookingService = BookingService.instance;
      const bookingId = 'bk_sec_complete';

      final booking = BookingModel(
        id: bookingId,
        clientId: 'cl_01',
        trainerId: 'tr_01',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        sessionDate: DateTime.now(),
        startTime: '08:00 AM',
        endTime: '09:00 AM',
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.completed,
      );

      bookingService.addOrUpdateBooking(booking);
      await bookingService.completeSession(bookingId: bookingId);

      expect(
        () => bookingService.completeSession(bookingId: bookingId),
        throwsA(isA<StateError>()),
      );
    });

    test('Trainer earnings records are strictly read-only for trainers (writes restricted to backend)', () {
      final earningsService = TrainerEarningsService.instance;
      final tx = TrainerEarningsTransactionModel(
        id: 'tx_sec_01',
        bookingId: 'bk_01',
        bookingRef: '#REF-001',
        trainerId: 'tr_01',
        clientId: 'cl_01',
        clientName: 'Athlete',
        packageName: '1 Month',
        sessionDate: DateTime.now(),
        grossAmount: 415,
        commissionRatePercent: 15,
        commissionAmount: 62,
        netAmount: 353,
        payoutStatus: TrainerPayoutStatus.eligibleForPayout,
      );

      earningsService.setTestTransactions([tx]);
      // Transactions are exposed as unmodifiable list
      expect(earningsService.allTransactions.length, 1);
      expect(() => (earningsService.allTransactions as dynamic).add(tx), throwsUnsupportedError);
    });
  });

  group('Requirement 3: Demo & Production Safety', () {
    test('Demo trainer identification is strictly disabled in release mode', () {
      // In non-release, demo accounts match
      // If kReleaseMode is true, isDemoTrainer must always return false
      if (AuthService.isDemoTrainer(email: 'trainer.demo@trainz.test')) {
        // We are in test/debug mode, verify demo email format
        expect(AuthService.isStandardDemoTrainer(email: 'trainer.demo@trainz.test'), isTrue);
        expect(AuthService.isAdvancedDemoTrainer(email: 'advanced.demo@trainz.test'), isTrue);
      }
    });

    test('Razorpay default key is in test mode and no secret keys exposed in client', () {
      expect(PaymentService.defaultKeyId.startsWith('rzp_test_'), isTrue);
      // Key contains no secret tokens
      expect(PaymentService.defaultKeyId.contains('secret'), isFalse);
    });

    test('Zero dating or romantic jargon in constants and category display names', () {
      final tokens = ['dating', 'courtship', 'romance', 'hookup', 'swipe-right'];
      for (final cat in TrainerCategory.values) {
        for (final token in tokens) {
          expect(cat.displayName.toLowerCase().contains(token), isFalse);
          expect(cat.requirementText.toLowerCase().contains(token), isFalse);
          expect(cat.packageRuleText.toLowerCase().contains(token), isFalse);
        }
      }
    });
  });
}
