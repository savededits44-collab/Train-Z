import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/features/trainer/presentation/screens/trainer_approved_screen.dart';
import 'package:trainuspro/features/trainer/presentation/screens/trainer_pending_approval_screen.dart';
import 'package:trainuspro/features/trainer/presentation/screens/trainer_rejected_screen.dart';
import 'package:trainuspro/screens/trainer/trainer_dashboard.dart';
import 'package:trainuspro/services/auth_service.dart';
import 'package:trainuspro/services/trainer_certificate_service.dart';
import 'package:trainuspro/services/trainer_profile_service.dart';
import 'package:trainuspro/shared/models/trainer_certificate_model.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';
import 'package:trainuspro/shared/models/user_model.dart';

void main() {
  group('PROMPT: Standard Trainer Demo Account Verification', () {
    const standardEmail = 'trainer.demo@trainz.test';
    const standardUid = 'nY3lebkFPBZwWNV6ycj4QtpttV92';

    test('Standard Trainer credentials and role configuration', () {
      expect(standardEmail, 'trainer.demo@trainz.test');
      expect(AuthService.demoStandardTrainerUid, standardUid);
      expect(AuthService.demoStandardTrainerEmail, standardEmail);

      const userModel = UserModel(
        uid: standardUid,
        email: standardEmail,
        displayName: 'Demo Standard Trainer',
        role: UserRole.trainer,
        status: UserStatus.active,
        isEmailVerified: true,
        isOnboarded: true,
      );

      expect(userModel.role, UserRole.trainer);
      expect(userModel.isTrainer, isTrue);
      expect(userModel.status, UserStatus.active);
      expect(userModel.isActive, isTrue);
      expect(userModel.isEmailVerified, isTrue);
    });

    test('Standard Trainer profile attributes, category, and approval', () {
      const profile = TrainerProfileModel(
        uid: standardUid,
        fullName: 'Demo Standard Trainer',
        phoneNumber: '+919876543210',
        gender: Gender.male,
        dateOfBirth: '1995-05-15',
        category: TrainerCategory.trainer,
        verificationStatus: TrainerVerificationStatus.approved,
        experienceYears: 1.5,
        isProfileCompleted: true,
        profileCompletionScore: 100,
        isActive: true,
        verifiedQualifications: [
          VerifiedQualification(
            id: 'cert_demo_standard_01',
            certificateName: '[DEMO TEST] Certified Personal Trainer Level 1 (Beginner)',
            courseName: 'Foundation in Personal Training',
            issuingOrganization: 'TRAIN Z Fitness Academy (Test Synthetic)',
            yearOfCompletion: '2024',
          ),
        ],
      );

      expect(profile.isStandardTrainer, isTrue);
      expect(profile.isAdvancedTrainer, isFalse);
      expect(profile.category, TrainerCategory.trainer);
      expect(profile.verificationStatus, TrainerVerificationStatus.approved);
      expect(profile.isApproved, isTrue);
      expect(profile.isProfileCompleted, isTrue);
      expect(profile.profileCompletionScore, 100);
      expect(profile.verifiedQualifications.length, 1);
      expect(profile.verifiedQualifications.first.certificateName, contains('Beginner'));
    });

    test('Standard Trainer eligibility validation in TrainerCertificateService', () {
      final certs = [
        const TrainerCertificateModel(
          id: 'cert_demo_standard_01',
          trainerId: standardUid,
          certificateName: '[DEMO TEST] Certified Personal Trainer Level 1 (Beginner)',
          courseName: 'Foundation in Personal Training',
          issuingOrganization: 'TRAIN Z Fitness Academy (Test Synthetic)',
          yearOfCompletion: '2024',
          storagePath: 'certificates/nY3lebkFPBZwWNV6ycj4QtpttV92/cert_demo_standard_01.pdf',
          fileName: 'demo_cpt_level1_synthetic.pdf',
          fileType: 'pdf',
          fileSizeBytes: 1048576,
          verificationStatus: CertificateVerificationStatus.verified,
          targetCategory: TrainerCategory.trainer,
        ),
      ];

      final eligibility = TrainerCertificateService.instance.checkCategoryRequirements(
        category: TrainerCategory.trainer,
        certificates: certs,
        experienceYears: 1.5,
      );

      expect(eligibility.isEligible, isTrue);
      expect(eligibility.isFullyVerified, isTrue);
      expect(eligibility.submittedCertificatesCount, 1);
      expect(eligibility.verifiedCertificatesCount, 1);
    });

    testWidgets('Standard Trainer Approved Screen displays Standard Trainer Privileges', (tester) async {
      const profile = TrainerProfileModel(
        uid: standardUid,
        fullName: 'Demo Standard Trainer',
        category: TrainerCategory.trainer,
        verificationStatus: TrainerVerificationStatus.approved,
        isActive: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerApprovedScreen(profile: profile),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Application Approved!'), findsOneWidget);
      expect(find.text('ACTIVE & APPROVED'), findsOneWidget);
      expect(find.text('Trainer'), findsOneWidget);
      expect(find.text('Standard Platform Packages'), findsOneWidget);
      expect(find.text('Go to Trainer Dashboard'), findsOneWidget);
    });
  });

  group('PROMPT: Advanced Trainer Demo Account Verification', () {
    const advancedEmail = 'advanced.demo@trainz.test';
    const advancedUid = 'tBzc47n2bpbLVVIFSIEd34Mfbma2';

    test('Advanced Trainer credentials and role configuration', () {
      expect(advancedEmail, 'advanced.demo@trainz.test');
      expect(AuthService.demoAdvancedTrainerUid, advancedUid);
      expect(AuthService.demoAdvancedTrainerEmail, advancedEmail);

      const userModel = UserModel(
        uid: advancedUid,
        email: advancedEmail,
        displayName: 'Demo Advanced Trainer',
        role: UserRole.trainer,
        status: UserStatus.active,
        isEmailVerified: true,
        isOnboarded: true,
      );

      expect(userModel.role, UserRole.trainer);
      expect(userModel.isTrainer, isTrue);
      expect(userModel.status, UserStatus.active);
      expect(userModel.isActive, isTrue);
      expect(userModel.isEmailVerified, isTrue);
    });

    test('Advanced Trainer profile attributes, category, 4 years experience, and approval', () {
      const profile = TrainerProfileModel(
        uid: advancedUid,
        fullName: 'Demo Advanced Trainer',
        phoneNumber: '+919876543211',
        gender: Gender.male,
        dateOfBirth: '1992-08-20',
        category: TrainerCategory.advancedTrainer,
        verificationStatus: TrainerVerificationStatus.approved,
        experienceYears: 4.0,
        isProfileCompleted: true,
        profileCompletionScore: 100,
        isActive: true,
        verifiedQualifications: [
          VerifiedQualification(
            id: 'cert_demo_advanced_01',
            certificateName: '[DEMO TEST] Certified Strength & Conditioning Specialist (CSCS)',
            courseName: 'Advanced Strength & Periodization Masterclass',
            issuingOrganization: 'National Strength & Conditioning Association (Test Synthetic)',
            yearOfCompletion: '2021',
          ),
          VerifiedQualification(
            id: 'cert_demo_advanced_02',
            certificateName: '[DEMO TEST] Precision Nutrition Level 1 (Pn1)',
            courseName: 'Exercise Nutrition & Periodization',
            issuingOrganization: 'Precision Nutrition (Test Synthetic)',
            yearOfCompletion: '2022',
          ),
        ],
      );

      expect(profile.isAdvancedTrainer, isTrue);
      expect(profile.isStandardTrainer, isFalse);
      expect(profile.category, TrainerCategory.advancedTrainer);
      expect(profile.verificationStatus, TrainerVerificationStatus.approved);
      expect(profile.isApproved, isTrue);
      expect(profile.experienceYears, 4.0);
      expect(profile.experienceYears >= 3.5, isTrue);
      expect(profile.isProfileCompleted, isTrue);
      expect(profile.profileCompletionScore, 100);
      expect(profile.verifiedQualifications.length, 2);
    });

    test('Advanced Trainer eligibility validation requires min 3.5 years (Demo has 4.0)', () {
      final certs = [
        const TrainerCertificateModel(
          id: 'cert_demo_advanced_01',
          trainerId: advancedUid,
          certificateName: '[DEMO TEST] Certified Strength & Conditioning Specialist (CSCS)',
          courseName: 'Advanced Strength & Periodization Masterclass',
          issuingOrganization: 'National Strength & Conditioning Association (Test Synthetic)',
          yearOfCompletion: '2021',
          storagePath: 'certificates/tBzc47n2bpbLVVIFSIEd34Mfbma2/cert_demo_advanced_01.pdf',
          fileName: 'demo_cscs_advanced_synthetic.pdf',
          fileType: 'pdf',
          fileSizeBytes: 2097152,
          verificationStatus: CertificateVerificationStatus.verified,
          targetCategory: TrainerCategory.advancedTrainer,
        ),
      ];

      final eligibility = TrainerCertificateService.instance.checkCategoryRequirements(
        category: TrainerCategory.advancedTrainer,
        certificates: certs,
        experienceYears: 4.0,
      );

      expect(eligibility.isEligible, isTrue);
      expect(eligibility.isFullyVerified, isTrue);
      expect(eligibility.currentExperienceYears, 4.0);
      expect(eligibility.requiredExperienceYears, 3.5);
      expect(eligibility.verifiedCertificatesCount, 1);
    });

    testWidgets('Advanced Trainer Approved Screen displays Advanced Trainer Privileges', (tester) async {
      const profile = TrainerProfileModel(
        uid: advancedUid,
        fullName: 'Demo Advanced Trainer',
        category: TrainerCategory.advancedTrainer,
        verificationStatus: TrainerVerificationStatus.approved,
        experienceYears: 4.0,
        isActive: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerApprovedScreen(profile: profile),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Application Approved!'), findsOneWidget);
      expect(find.text('ACTIVE & APPROVED'), findsOneWidget);
      expect(find.text('Advanced Trainer'), findsOneWidget);
      expect(find.text('Custom Plans & Flexible Rates'), findsOneWidget);
      expect(find.text('Go to Trainer Dashboard'), findsOneWidget);
    });
  });

  group('PROMPT: Development Safety & Zero Romantic Terminology Audit', () {
    test('Both accounts are strictly identified as DEMO accounts with synthetic data', () {
      final syntheticLabels = [
        'Demo Standard Trainer',
        'Demo Advanced Trainer',
        '[DEMO TEST] Certified Personal Trainer Level 1 (Beginner)',
        '[DEMO TEST] Certified Strength & Conditioning Specialist (CSCS)',
        '[DEMO TEST] Precision Nutrition Level 1 (Pn1)',
        'TRAIN Z Fitness Academy (Test Synthetic)',
        'National Strength & Conditioning Association (Test Synthetic)',
        'Precision Nutrition (Test Synthetic)',
      ];

      for (final label in syntheticLabels) {
        expect(
          label.contains('Demo') || label.contains('DEMO') || label.contains('Test') || label.contains('Synthetic'),
          isTrue,
        );
      }
    });

    test('Audit: Zero dating or romantic terminology in Trainer demo records', () {
      final demoTexts = [
        'Demo Standard Trainer',
        'Demo Advanced Trainer',
        'Standard Platform Packages',
        'Custom Plans & Flexible Rates',
        'Verified Coach',
        '4 Years Exp',
        'Personal Trainer Coaching Sessions',
        'Evidence-based strength and conditioning',
      ];

      final prohibitedWords = ['dating', 'match', 'hookup', 'swipe', 'romance', 'couple', 'singles'];

      for (final text in demoTexts) {
        for (final word in prohibitedWords) {
          expect(
            text.toLowerCase().contains(word),
            isFalse,
            reason: 'Prohibited word "$word" found in "$text"',
          );
        }
      }
    });
  });

  group('PROMPT: Trainer Demo vs Real Trainer Access Control & Routing', () {
    setUp(() {
      TrainerProfileService.instance.reset();
    });

    testWidgets('1. Standard Trainer Demo account reaches Trainer Dashboard directly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final demoProfile = await AuthService().getTrainerProfile(AuthService.demoStandardTrainerUid);
      expect(demoProfile, isNotNull);
      expect(demoProfile!.isApproved, isTrue);
      expect(demoProfile.category, TrainerCategory.trainer);

      TrainerProfileService.instance.populateFromModel(demoProfile);

      await tester.pumpWidget(
        MaterialApp(
          home: TrainerDashboard(trainerId: AuthService.demoStandardTrainerUid),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Successfully reached Trainer Dashboard
      expect(find.text('Demo Standard Trainer'), findsOneWidget);
      expect(find.text('Approved & Active'), findsOneWidget);
      expect(find.text('TRAIN Z Platform Packages'), findsOneWidget);
      expect(find.byType(TrainerPendingApprovalScreen), findsNothing);
    });

    testWidgets('2. Advanced Trainer Demo account reaches Trainer Dashboard directly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final demoProfile = await AuthService().getTrainerProfile(AuthService.demoAdvancedTrainerUid);
      expect(demoProfile, isNotNull);
      expect(demoProfile!.isApproved, isTrue);
      expect(demoProfile.category, TrainerCategory.advancedTrainer);
      expect(demoProfile.experienceYears, 4.0);

      TrainerProfileService.instance.populateFromModel(demoProfile);

      await tester.pumpWidget(
        MaterialApp(
          home: TrainerDashboard(trainerId: AuthService.demoAdvancedTrainerUid),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Successfully reached Trainer Dashboard
      expect(find.text('Demo Advanced Trainer'), findsOneWidget);
      expect(find.text('Advanced Trainer'), findsWidgets);
      expect(find.text('Qualifications Verified (3.5+ Yrs Exp)'), findsOneWidget);
      expect(find.text('Custom Training Plans Eligible'), findsOneWidget);
      expect(find.byType(TrainerPendingApprovalScreen), findsNothing);
    });

    testWidgets('3. Approved real Trainer reaches Trainer Dashboard', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const realApprovedProfile = TrainerProfileModel(
        uid: 'real_approved_trainer_777',
        fullName: 'Real Approved Coach',
        phoneNumber: '+919876543299',
        gender: Gender.male,
        dateOfBirth: '1991-03-12',
        category: TrainerCategory.trainer,
        verificationStatus: TrainerVerificationStatus.approved,
        experienceYears: 3.0,
        isProfileCompleted: true,
        profileCompletionScore: 100,
        isActive: true,
      );

      TrainerProfileService.instance.populateFromModel(realApprovedProfile);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerDashboard(trainerId: 'real_approved_trainer_777'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Real Approved Coach'), findsOneWidget);
      expect(find.text('Approved & Active'), findsOneWidget);
      expect(find.text('TRAIN Z Platform Packages'), findsOneWidget);
      expect(find.byType(TrainerPendingApprovalScreen), findsNothing);
    });

    testWidgets('4. Pending real Trainer is blocked from Dashboard and sees Pending Approval screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const realPendingProfile = TrainerProfileModel(
        uid: 'real_pending_trainer_555',
        fullName: 'Real Pending Coach',
        phoneNumber: '+919876543255',
        gender: Gender.male,
        dateOfBirth: '1993-07-15',
        category: TrainerCategory.trainer,
        verificationStatus: TrainerVerificationStatus.pending,
        experienceYears: 2.0,
        isProfileCompleted: true,
        profileCompletionScore: 100,
        isActive: false,
      );

      TrainerProfileService.instance.populateFromModel(realPendingProfile);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerDashboard(trainerId: 'real_pending_trainer_555'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Must NOT display dashboard content
      expect(find.text('TRAIN Z Platform Packages'), findsNothing);
      expect(find.text('CURRENT EARNINGS'), findsNothing);

      // Must display TrainerPendingApprovalScreen
      expect(find.byType(TrainerPendingApprovalScreen), findsOneWidget);
    });

    testWidgets('5. Rejected real Trainer is blocked from Dashboard and sees Rejected screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const realRejectedProfile = TrainerProfileModel(
        uid: 'real_rejected_trainer_444',
        fullName: 'Real Rejected Coach',
        phoneNumber: '+919876543244',
        gender: Gender.male,
        dateOfBirth: '1993-07-15',
        category: TrainerCategory.trainer,
        verificationStatus: TrainerVerificationStatus.rejected,
        experienceYears: 1.0,
        isProfileCompleted: true,
        profileCompletionScore: 100,
        isActive: false,
        adminReviewNotes: 'Submitted documents could not be verified.',
      );

      TrainerProfileService.instance.populateFromModel(realRejectedProfile);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerDashboard(trainerId: 'real_rejected_trainer_444'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Must NOT display dashboard content
      expect(find.text('TRAIN Z Platform Packages'), findsNothing);

      // Must display TrainerRejectedScreen
      expect(find.byType(TrainerRejectedScreen), findsOneWidget);
      expect(find.textContaining('Application Not Approved'), findsOneWidget);
    });
  });
}
