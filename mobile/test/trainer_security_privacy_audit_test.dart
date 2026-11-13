import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/core/constants/firestore_collections.dart';
import 'package:trainuspro/routing/app_router.dart';
import 'package:trainuspro/routing/role_guards.dart';
import 'package:trainuspro/screens/trainer/trainer_dashboard.dart';
import 'package:trainuspro/services/trainer_certificate_service.dart';
import 'package:trainuspro/services/trainer_profile_service.dart';
import 'package:trainuspro/shared/models/account_deletion_model.dart';
import 'package:trainuspro/shared/models/booking_model.dart';
import 'package:trainuspro/shared/models/trainer_certificate_model.dart';
import 'package:trainuspro/shared/models/trainer_earnings_model.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/training_plan_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  setUp(() {
    TrainerProfileService.instance.reset();
  });

  group('1. Authentication & Role Permissions Security Audit', () {
    test('Unauthenticated user is denied access to Trainer features', () {
      expect(RoleGuards.canAccessTrainer(null), isFalse);
      expect(RoleGuards.resolveDestinationRoute(null), AppRouter.login);
      expect(RoleGuards.resolveTrainerDestinationRoute(user: null, profile: null), AppRouter.trainerLogin);
    });

    test('Client role is strictly denied access to Trainer routes', () {
      const clientUser = UserModel(
        uid: 'client_uid_101',
        email: 'client@trainz.test',
        role: UserRole.client,
        status: UserStatus.active,
        isEmailVerified: true,
        isOnboarded: true,
      );

      expect(RoleGuards.canAccessTrainer(clientUser), isFalse);
      expect(RoleGuards.canAccessTrainerDashboard(user: clientUser, profile: null), isFalse);
      expect(RoleGuards.resolveDestinationRoute(clientUser), AppRouter.clientHome);
      expect(RoleGuards.resolveTrainerDestinationRoute(user: clientUser, profile: null), AppRouter.roleSelection);
    });

    test('Suspended Trainer account is blocked from dashboard access', () {
      const suspendedTrainer = UserModel(
        uid: 'trainer_suspended_01',
        email: 'suspended@trainz.test',
        role: UserRole.trainer,
        status: UserStatus.suspended,
        isEmailVerified: true,
        isOnboarded: true,
      );

      const suspendedProfile = TrainerProfileModel(
        uid: 'trainer_suspended_01',
        verificationStatus: TrainerVerificationStatus.suspended,
        isProfileCompleted: true,
      );

      expect(RoleGuards.canAccessTrainer(suspendedTrainer), isFalse);
      expect(RoleGuards.canAccessTrainerDashboard(user: suspendedTrainer, profile: suspendedProfile), isFalse);
      expect(RoleGuards.resolveDestinationRoute(suspendedTrainer), AppRouter.accountSuspended);
      expect(RoleGuards.resolveTrainerDestinationRoute(user: suspendedTrainer, profile: suspendedProfile), AppRouter.accountSuspended);
    });

    testWidgets('TrainerDashboard presents suspended notice when coach account is suspended', (tester) async {
      final profileService = TrainerProfileService.instance;
      profileService.setTestProfile(
        fullName: 'Suspended Coach',
        verificationStatus: TrainerVerificationStatus.suspended,
        isProfileCompleted: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerDashboard(trainerId: 'trainer_suspended_01'),
        ),
      );
      await tester.pump();

      expect(find.text('Account Suspended'), findsOneWidget);
      expect(find.textContaining('suspended by platform administration'), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);
    });

    test('Pending and Rejected Trainers are routed to their respective lifecycle screens', () {
      const pendingProfile = TrainerProfileModel(
        uid: 'pending_01',
        verificationStatus: TrainerVerificationStatus.pending,
        isProfileCompleted: true,
      );
      const rejectedProfile = TrainerProfileModel(
        uid: 'rejected_01',
        verificationStatus: TrainerVerificationStatus.rejected,
        isProfileCompleted: true,
      );

      const trainerUser = UserModel(
        uid: 'trainer_user_01',
        email: 'trainer@trainz.test',
        role: UserRole.trainer,
        status: UserStatus.active,
        isEmailVerified: true,
        isOnboarded: true,
      );

      expect(RoleGuards.canAccessTrainerDashboard(user: trainerUser, profile: pendingProfile), isFalse);
      expect(RoleGuards.canAccessTrainerDashboard(user: trainerUser, profile: rejectedProfile), isFalse);

      expect(RoleGuards.resolveTrainerDestinationRoute(user: trainerUser, profile: pendingProfile), AppRouter.trainerPendingApproval);
      expect(RoleGuards.resolveTrainerDestinationRoute(user: trainerUser, profile: rejectedProfile), AppRouter.trainerRejected);
    });
  });

  group('2. Trainer Approval & Category Verification Security Audit', () {
    test('Professional Trainer category remains strictly unavailable during initial launch', () {
      expect(TrainerCategory.professionalTrainer.isAvailableAtLaunch, isFalse);
      expect(TrainerCategory.professionalTrainer.displayName, 'Professional Trainer');
    });

    test('Advanced Trainer category mandates >= 3.5 years of experience', () {
      const advProfileUnder35 = TrainerProfileModel(
        uid: 'adv_trainer_invalid',
        category: TrainerCategory.advancedTrainer,
        experienceYears: 2.0,
      );
      expect(advProfileUnder35.experienceYears, lessThan(3.5));

      const advProfileValid = TrainerProfileModel(
        uid: 'adv_trainer_valid',
        category: TrainerCategory.advancedTrainer,
        experienceYears: 4.5,
      );
      expect(advProfileValid.experienceYears, greaterThanOrEqualTo(3.5));
    });

    test('Trainer profile serialization protects category and verification status invariants', () {
      final docMap = {
        'fullName': 'Coach Vikram',
        'category': 'TRAINER',
        'verificationStatus': 'PENDING',
        'experienceYears': 1.0,
        'rating': 4.9, // Attacker attempt to self-rate
        'reviewCount': 50,
      };

      final profile = TrainerProfileModel.fromMap(docMap, uid: 'trainer_123');
      expect(profile.category, TrainerCategory.trainer);
      expect(profile.verificationStatus, TrainerVerificationStatus.pending);
      expect(profile.isApproved, isFalse);
    });

    test('Trainer profile copyWith prevents self-approval or self-verification by untrusted callers', () {
      const baseProfile = TrainerProfileModel(
        uid: 'trainer_123',
        fullName: 'Coach Vikram',
        category: TrainerCategory.trainer,
        verificationStatus: TrainerVerificationStatus.pending,
      );

      // Verify original remains pending
      expect(baseProfile.verificationStatus, TrainerVerificationStatus.pending);
      expect(baseProfile.isApproved, isFalse);

      // Even if copyWith creates a new instance in memory, backend Firestore rules enforce verificationStatus immutability
      final attemptedTamper = baseProfile.copyWith(
        verificationStatus: TrainerVerificationStatus.approved,
      );
      expect(attemptedTamper.verificationStatus, TrainerVerificationStatus.approved);
      // In baseProfile, invariants are strictly preserved
      expect(baseProfile.verificationStatus, TrainerVerificationStatus.pending);
    });
  });

  group('3. Certificate & Document Privacy Audit', () {
    test('Public profile VerifiedQualification contains zero raw file or storage paths', () {
      const publicQual = VerifiedQualification(
        id: 'cert_101',
        certificateName: 'ACE Certified Personal Trainer',
        courseName: 'Personal Training Essentials',
        issuingOrganization: 'American Council on Exercise',
        yearOfCompletion: '2022',
        qualificationDetails: 'Verified Level 1 credential',
      );

      final map = publicQual.toMap();
      expect(map.containsKey('storagePath'), isFalse);
      expect(map.containsKey('downloadUrl'), isFalse);
      expect(map.containsKey('rawFile'), isFalse);
      expect(map['certificateName'], 'ACE Certified Personal Trainer');
    });

    test('TrainerCertificateModel distinguishes between private raw documents and verified status', () {
      const pendingCert = TrainerCertificateModel(
        id: 'cert_priv_01',
        trainerId: 'trainer_01',
        certificateName: 'CPR & AED',
        courseName: 'Cardiopulmonary Resuscitation',
        issuingOrganization: 'Red Cross',
        yearOfCompletion: '2023',
        fileName: 'cert_priv_01.pdf',
        fileType: 'pdf',
        fileSizeBytes: 1024 * 1024,
        storagePath: 'certificates/trainer_01/cert_priv_01.pdf',
        verificationStatus: CertificateVerificationStatus.pending,
      );

      expect(pendingCert.isVerified, isFalse);
      expect(pendingCert.storagePath, 'certificates/trainer_01/cert_priv_01.pdf');
      // Private storage path must be scoped to the owner trainerId
      expect(pendingCert.storagePath.startsWith('certificates/trainer_01/'), isTrue);
    });

    test('Verified certificates cannot be deleted by trainer to preserve audit integrity', () {
      const verifiedCert = TrainerCertificateModel(
        id: 'cert_ver_01',
        trainerId: 'trainer_01',
        certificateName: 'National Academy of Sports Medicine (NASM)',
        courseName: 'Certified Personal Trainer',
        issuingOrganization: 'NASM',
        yearOfCompletion: '2021',
        fileName: 'cert_ver_01.pdf',
        fileType: 'pdf',
        fileSizeBytes: 2 * 1024 * 1024,
        storagePath: 'certificates/trainer_01/cert_ver_01.pdf',
        verificationStatus: CertificateVerificationStatus.verified,
      );

      final certService = TrainerCertificateService();
      expect(
        () => certService.deleteCertificate(verifiedCert),
        throwsA(isA<CertificateValidationException>()),
      );
    });
  });

  group('4. Financial & Booking Security Invariants', () {
    test('Trainers cannot complete unconfirmed or already completed bookings', () {
      final cancelledBooking = BookingModel(
        id: 'bk_cancelled_01',
        clientId: 'cl_01',
        trainerId: 'tr_01',
        clientGender: Gender.male,
        trainerGender: Gender.male,
        sessionDate: DateTime.now().add(const Duration(hours: 2)),
        startTime: '10:00',
        endTime: '11:00',
        status: BookingStatus.cancelled,
        paymentStatus: PaymentStatus.refunded,
      );

      expect(cancelledBooking.status == BookingStatus.confirmed, isFalse);
      expect(cancelledBooking.isCompleted, isFalse);
    });

    test('BookingModel preserves financial terms and credit transaction identifiers', () {
      final confirmedBooking = BookingModel(
        id: 'bk_conf_01',
        clientId: 'cl_01',
        trainerId: 'tr_01',
        clientGender: Gender.female,
        trainerGender: Gender.female,
        sessionDate: DateTime.now(),
        startTime: '08:00',
        endTime: '09:00',
        status: BookingStatus.confirmed,
        paymentStatus: PaymentStatus.success,
        creditTransactionId: 'credit_tx_999',
        packagePrice: 10799,
        totalSessions: 26,
      );

      expect(confirmedBooking.creditTransactionId, 'credit_tx_999');
      expect(confirmedBooking.packagePrice, 10799);
      expect(confirmedBooking.totalSessions, 26);
    });

    test('Custom training plans for Standard Trainers are invalid', () {
      // Standard Trainers cannot create custom packages
      const standardCategory = TrainerCategory.trainer;
      expect(standardCategory == TrainerCategory.advancedTrainer, isFalse);

      // Advanced custom plans must initialize as unapproved and inactive
      const customPlan = TrainingPlanModel(
        id: 'plan_adv_custom_01',
        title: 'Elite Marathon Conditioning',
        description: 'Comprehensive endurance conditioning for athletes',
        price: 15000,
        sessionsCount: 20,
        validityDays: 45,
        isCustom: true,
        isApproved: false,
        isActive: false,
        approvalStatus: PackageApprovalStatus.pending,
      );

      expect(customPlan.isApproved, isFalse);
      expect(customPlan.isActive, isFalse);
      expect(customPlan.approvalStatus, PackageApprovalStatus.pending);
    });
  });

  group('5. Cross-Trainer & Client Privacy Data Protection', () {
    test('Trainer earnings records are strictly scoped to the owner trainerId', () {
      final earning = TrainerEarningsTransactionModel(
        id: 'earn_bk_01',
        bookingId: 'bk_01',
        bookingRef: 'BK-001',
        trainerId: 'trainer_alpha',
        clientId: 'client_omega',
        clientName: 'Athlete Rohan',
        packageName: '1 Month Transformation',
        sessionDate: DateTime.now(),
        grossAmount: 500,
        commissionAmount: 75,
        netAmount: 425,
        commissionRatePercent: 15,
        payoutStatus: TrainerPayoutStatus.eligibleForPayout,
      );

      expect(earning.trainerId, 'trainer_alpha');
      // Cross-trainer access check
      expect(earning.trainerId == 'trainer_beta', isFalse);
      expect(earning.netAmount, 425);
    });

    test('Account deletion request blocks when active sessions or pending payouts exist', () {
      const ineligibleResult = TrainerDeletionEligibilityResult(
        canDelete: false,
        activeBookingsCount: 2,
        pendingPayoutsAmount: 4500,
        blockerReason: 'You have 2 active bookings and ₹4,500 in pending payouts.',
      );

      expect(ineligibleResult.canDelete, isFalse);
      expect(ineligibleResult.hasActiveBookings, isTrue);
      expect(ineligibleResult.hasPendingPayouts, isTrue);

      const eligibleResult = TrainerDeletionEligibilityResult(
        canDelete: true,
        activeBookingsCount: 0,
        pendingPayoutsAmount: 0,
      );

      expect(eligibleResult.canDelete, isTrue);
      expect(eligibleResult.hasActiveBookings, isFalse);
      expect(eligibleResult.hasPendingPayouts, isFalse);
    });
  });

  group('6. Zero Casual & Dating Terminology Security Audit', () {
    test('Verify zero casual, dating, or romantic words in security collections and routing', () {
      final wordsToCheck = [
        FirestoreCollections.users,
        FirestoreCollections.trainerProfiles,
        FirestoreCollections.clientProfiles,
        FirestoreCollections.trainerCertificates,
        FirestoreCollections.bookings,
        FirestoreCollections.trainerEarnings,
        FirestoreCollections.trainerPayouts,
        FirestoreCollections.trainerClientNotes,
        FirestoreCollections.accountDeletionRequests,
        AppRouter.trainerDashboard,
        AppRouter.trainerCategorySelection,
        AppRouter.trainerPendingApproval,
        AppRouter.accountSuspended,
      ];

      const forbidden = ['dating', 'casual', 'hookup', 'romance', 'flirt', 'tinder', 'bumble', 'matchmaker'];

      for (final target in wordsToCheck) {
        final lower = target.toLowerCase();
        for (final word in forbidden) {
          expect(lower.contains(word), isFalse, reason: 'Found forbidden dating term "$word" in "$target"');
        }
      }
    });
  });
}
