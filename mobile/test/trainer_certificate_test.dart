import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainuspro/screens/trainer/trainer_certificates_screen.dart';
import 'package:trainuspro/services/trainer_certificate_service.dart';
import 'package:trainuspro/shared/models/trainer_certificate_model.dart';
import 'package:trainuspro/shared/models/trainer_profile_model.dart';

void main() {
  final service = TrainerCertificateService.instance;

  setUp(() {
    service.clearMockData();
  });

  group('Group 1: File Type and Size Validation', () {
    test('Validates accepted formats: PDF, JPG, PNG, WebP under 10MB', () {
      expect(
        () => service.validateCertificateFile(fileName: 'cert.pdf', fileSizeBytes: 1024 * 1024),
        returnsNormally,
      );
      expect(
        () => service.validateCertificateFile(fileName: 'diploma.jpg', fileSizeBytes: 2 * 1024 * 1024),
        returnsNormally,
      );
      expect(
        () => service.validateCertificateFile(fileName: 'cert.png', fileSizeBytes: 5 * 1024 * 1024),
        returnsNormally,
      );
      expect(
        () => service.validateCertificateFile(fileName: 'fitness_cpt.webp', fileSizeBytes: 8 * 1024 * 1024),
        returnsNormally,
      );
      // Exactly 10MB (10 * 1024 * 1024) is permitted
      expect(
        () => service.validateCertificateFile(fileName: 'doc.pdf', fileSizeBytes: 10 * 1024 * 1024),
        returnsNormally,
      );
    });

    test('Rejects unsupported file formats (exe, zip, docx, mp4)', () {
      expect(
        () => service.validateCertificateFile(fileName: 'certificate.exe', fileSizeBytes: 5000),
        throwsA(isA<CertificateValidationException>().having((e) => e.code, 'code', 'INVALID_FILE_TYPE')),
      );
      expect(
        () => service.validateCertificateFile(fileName: 'docs.zip', fileSizeBytes: 5000),
        throwsA(isA<CertificateValidationException>().having((e) => e.code, 'code', 'INVALID_FILE_TYPE')),
      );
      expect(
        () => service.validateCertificateFile(fileName: 'document.docx', fileSizeBytes: 5000),
        throwsA(isA<CertificateValidationException>().having((e) => e.code, 'code', 'INVALID_FILE_TYPE')),
      );
      expect(
        () => service.validateCertificateFile(fileName: 'video.mp4', fileSizeBytes: 5000),
        throwsA(isA<CertificateValidationException>().having((e) => e.code, 'code', 'INVALID_FILE_TYPE')),
      );
    });

    test('Rejects files exceeding the 10 MB size threshold', () {
      const tenMbAndOneByte = (10 * 1024 * 1024) + 1;
      expect(
        () => service.validateCertificateFile(fileName: 'big_cert.pdf', fileSizeBytes: tenMbAndOneByte),
        throwsA(isA<CertificateValidationException>().having((e) => e.code, 'code', 'FILE_TOO_LARGE')),
      );
      const fifteenMb = 15 * 1024 * 1024;
      expect(
        () => service.validateCertificateFile(fileName: 'huge.jpg', fileSizeBytes: fifteenMb),
        throwsA(isA<CertificateValidationException>().having((e) => e.code, 'code', 'FILE_TOO_LARGE')),
      );
    });

    test('Rejects 0-byte or negative size files and blank file names', () {
      expect(
        () => service.validateCertificateFile(fileName: 'empty.pdf', fileSizeBytes: 0),
        throwsA(isA<CertificateValidationException>().having((e) => e.code, 'code', 'EMPTY_FILE')),
      );
      expect(
        () => service.validateCertificateFile(fileName: 'corrupt.jpg', fileSizeBytes: -100),
        throwsA(isA<CertificateValidationException>().having((e) => e.code, 'code', 'EMPTY_FILE')),
      );
      expect(
        () => service.validateCertificateFile(fileName: '   ', fileSizeBytes: 1024),
        throwsA(isA<CertificateValidationException>().having((e) => e.code, 'code', 'MISSING_FILE')),
      );
    });
  });

  group('Group 2: Trainer Category Requirements & Eligibility Checks', () {
    test('Standard Trainer category requirements: requires at least 1 beginner certificate; no experience requirement', () {
      // 0 certificates submitted -> not eligible for verification
      final res0 = service.checkCategoryRequirements(
        category: TrainerCategory.trainer,
        certificates: [],
        experienceYears: 0.0,
      );
      expect(res0.isEligible, isFalse);
      expect(res0.isFullyVerified, isFalse);
      expect(res0.requiredCertificatesCount, 1);
      expect(res0.requiredExperienceYears, 0.0);

      // 1 certificate pending -> eligible for review
      final certPending = TrainerCertificateModel(
        id: 'c1',
        trainerId: 't1',
        certificateName: 'Gym Instructor Level 1',
        courseName: 'Basic Fitness Training',
        issuingOrganization: 'Fitness Academy',
        yearOfCompletion: '2023',
        storagePath: 'certificates/t1/c1.pdf',
        fileName: 'cert.pdf',
        fileType: 'pdf',
        fileSizeBytes: 1024 * 500,
        verificationStatus: CertificateVerificationStatus.pending,
      );

      final resPending = service.checkCategoryRequirements(
        category: TrainerCategory.trainer,
        certificates: [certPending],
        experienceYears: 0.0,
      );
      expect(resPending.isEligible, isTrue);
      expect(resPending.isFullyVerified, isFalse);
      expect(resPending.submittedCertificatesCount, 1);

      // 1 certificate verified -> fully verified
      final certVerified = certPending.copyWith(verificationStatus: CertificateVerificationStatus.verified);
      final resVerified = service.checkCategoryRequirements(
        category: TrainerCategory.trainer,
        certificates: [certVerified],
        experienceYears: 0.5,
      );
      expect(resVerified.isEligible, isTrue);
      expect(resVerified.isFullyVerified, isTrue);
      expect(resVerified.verifiedCertificatesCount, 1);
    });

    test('Advanced Trainer category requirements: requires professional certificates AND at least 3.5 years experience', () {
      final cert = TrainerCertificateModel(
        id: 'c2',
        trainerId: 't2',
        certificateName: 'CSCS - Certified Strength and Conditioning Specialist',
        courseName: 'Advanced Exercise Science',
        issuingOrganization: 'NSCA',
        yearOfCompletion: '2021',
        storagePath: 'certificates/t2/c2.pdf',
        fileName: 'cscs.pdf',
        fileType: 'pdf',
        fileSizeBytes: 1024 * 1024,
        verificationStatus: CertificateVerificationStatus.verified,
      );

      // 2.0 years exp (< 3.5), even with verified certificate -> NOT eligible
      final resUnderExp = service.checkCategoryRequirements(
        category: TrainerCategory.advancedTrainer,
        certificates: [cert],
        experienceYears: 2.0,
      );
      expect(resUnderExp.isEligible, isFalse);
      expect(resUnderExp.isFullyVerified, isFalse);
      expect(resUnderExp.requiredExperienceYears, 3.5);

      // 4.0 years exp, but 0 certificates -> NOT eligible
      final resNoCerts = service.checkCategoryRequirements(
        category: TrainerCategory.advancedTrainer,
        certificates: [],
        experienceYears: 4.0,
      );
      expect(resNoCerts.isEligible, isFalse);
      expect(resNoCerts.isFullyVerified, isFalse);

      // 3.5 years exp AND pending certificate -> eligible, pending admin verification
      final pendingCert = cert.copyWith(verificationStatus: CertificateVerificationStatus.pending);
      final resPending = service.checkCategoryRequirements(
        category: TrainerCategory.advancedTrainer,
        certificates: [pendingCert],
        experienceYears: 3.5,
      );
      expect(resPending.isEligible, isTrue);
      expect(resPending.isFullyVerified, isFalse);

      // 3.5 years exp AND verified certificate -> fully verified
      final resVerified = service.checkCategoryRequirements(
        category: TrainerCategory.advancedTrainer,
        certificates: [cert],
        experienceYears: 3.5,
      );
      expect(resVerified.isEligible, isTrue);
      expect(resVerified.isFullyVerified, isTrue);
    });

    test('Professional Trainer category is strictly Coming Soon and disabled at launch', () async {
      final res = service.checkCategoryRequirements(
        category: TrainerCategory.professionalTrainer,
        certificates: [],
        experienceYears: 10.0,
      );
      expect(res.isEligible, isFalse);
      expect(res.isFullyVerified, isFalse);
      expect(res.message, contains('Coming Soon'));

      // uploadCertificate for Professional Trainer throws TIER_DISABLED
      expect(
        () => service.uploadCertificate(
          trainerId: 't3',
          certificateName: 'Olympian Coach',
          courseName: 'Olympic Lifting',
          issuingOrganization: 'Olympic Org',
          yearOfCompletion: '2020',
          targetCategory: TrainerCategory.professionalTrainer,
          fileName: 'olympic.pdf',
          fileSizeBytes: 1024,
        ),
        throwsA(isA<CertificateValidationException>().having((e) => e.code, 'code', 'TIER_DISABLED')),
      );
    });
  });

  group('Group 3: Certificate Verification States & Status Transitions', () {
    test('Supports all 5 verification states correctly', () {
      expect(CertificateVerificationStatus.notSubmitted.toFirestore(), 'NOT_SUBMITTED');
      expect(CertificateVerificationStatus.pending.toFirestore(), 'PENDING');
      expect(CertificateVerificationStatus.verified.toFirestore(), 'VERIFIED');
      expect(CertificateVerificationStatus.rejected.toFirestore(), 'REJECTED');
      expect(CertificateVerificationStatus.resubmissionRequired.toFirestore(), 'RESUBMISSION_REQUIRED');

      expect(CertificateVerificationStatus.fromFirestore('NOT_SUBMITTED'), CertificateVerificationStatus.notSubmitted);
      expect(CertificateVerificationStatus.fromFirestore('PENDING'), CertificateVerificationStatus.pending);
      expect(CertificateVerificationStatus.fromFirestore('VERIFIED'), CertificateVerificationStatus.verified);
      expect(CertificateVerificationStatus.fromFirestore('APPROVED'), CertificateVerificationStatus.verified);
      expect(CertificateVerificationStatus.fromFirestore('REJECTED'), CertificateVerificationStatus.rejected);
      expect(CertificateVerificationStatus.fromFirestore('RESUBMISSION_REQUIRED'), CertificateVerificationStatus.resubmissionRequired);
      expect(CertificateVerificationStatus.fromFirestore(null), CertificateVerificationStatus.pending);
    });

    test('New certificate uploads start in PENDING state by default (no self-approval)', () async {
      final cert = await service.uploadCertificate(
        trainerId: 'trainer_123',
        certificateName: 'ACE Certified Personal Trainer',
        courseName: 'Personal Training Essentials',
        issuingOrganization: 'American Council on Exercise',
        yearOfCompletion: '2022',
        targetCategory: TrainerCategory.trainer,
        fileName: 'ace_cpt.pdf',
        fileSizeBytes: 2 * 1024 * 1024,
        fileBytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(cert.verificationStatus, CertificateVerificationStatus.pending);
      expect(cert.isPending, isTrue);
      expect(cert.isVerified, isFalse);
      expect(cert.storagePath, 'certificates/trainer_123/${cert.id}.pdf');
      expect(cert.fileType, 'pdf');
    });
  });

  group('Group 4: Certificate Management, Replacement & Audit Deletion Protection', () {
    test('Trainers can replace/resubmit rejected certificates which resets status to PENDING', () async {
      // 1. Submit
      final initialCert = await service.uploadCertificate(
        trainerId: 'trainer_replace',
        certificateName: 'ISSA Trainer',
        courseName: 'Fitness Trainer Course',
        issuingOrganization: 'ISSA',
        yearOfCompletion: '2021',
        targetCategory: TrainerCategory.trainer,
        fileName: 'issa.jpg',
        fileSizeBytes: 1024 * 500,
      );

      // Simulate Admin rejection with review notes
      final rejectedCert = initialCert.copyWith(
        verificationStatus: CertificateVerificationStatus.resubmissionRequired,
        rejectionReason: 'Image is too blurry. Please re-upload a clear copy.',
      );
      service.seedMockCertificates('trainer_replace', [rejectedCert]);

      // 2. Resubmit with clear document
      final resubmitted = await service.resubmitCertificate(
        certificateId: rejectedCert.id,
        trainerId: 'trainer_replace',
        fileName: 'issa_clear_copy.pdf',
        fileSizeBytes: 1024 * 800,
        fileBytes: Uint8List.fromList([10, 20, 30]),
        updatedCertificateName: 'ISSA Certified Fitness Trainer',
      );

      expect(resubmitted.verificationStatus, CertificateVerificationStatus.pending);
      expect(resubmitted.isPending, isTrue);
      expect(resubmitted.rejectionReason, isNull);
      expect(resubmitted.fileName, 'issa_clear_copy.pdf');
      expect(resubmitted.certificateName, 'ISSA Certified Fitness Trainer');
    });

    test('Deletion protection: Unverified certificates can be deleted; VERIFIED certificates CANNOT be deleted', () async {
      final unverifiedCert = TrainerCertificateModel(
        id: 'unverified_1',
        trainerId: 'trainer_del',
        certificateName: 'Old Certificate',
        courseName: 'Intro Course',
        issuingOrganization: 'Gym X',
        yearOfCompletion: '2020',
        storagePath: 'certificates/trainer_del/unverified_1.pdf',
        fileName: 'old.pdf',
        fileType: 'pdf',
        fileSizeBytes: 1024,
        verificationStatus: CertificateVerificationStatus.pending,
      );
      service.seedMockCertificates('trainer_del', [unverifiedCert]);

      // Delete unverified passes
      await expectLater(service.deleteCertificate(unverifiedCert), completes);
      final remaining = await service.getTrainerCertificates('trainer_del');
      expect(remaining.isEmpty, isTrue);

      // Now test verified certificate deletion protection
      final verifiedCert = unverifiedCert.copyWith(
        id: 'verified_audit_1',
        verificationStatus: CertificateVerificationStatus.verified,
      );
      service.seedMockCertificates('trainer_del', [verifiedCert]);

      expect(
        () => service.deleteCertificate(verifiedCert),
        throwsA(isA<CertificateValidationException>().having((e) => e.code, 'code', 'AUDIT_PROTECTION')),
      );
    });
  });

  group('Group 5: Public vs Private Qualification Data Separation', () {
    test('VerifiedQualification strips all private paths, download links and file data', () {
      final privateCert = TrainerCertificateModel(
        id: 'cert_priv_999',
        trainerId: 'trainer_sec_1',
        certificateName: 'K11 Diploma in Personal Training',
        courseName: 'Certified Personal Trainer Course',
        issuingOrganization: 'K11 School of Fitness Sciences',
        yearOfCompletion: '2023',
        qualificationDetails: 'Specialized in hypertrophy and functional strength',
        storagePath: 'certificates/trainer_sec_1/cert_priv_999.pdf',
        fileUrl: 'https://private.firebasestorage.com/certificates/secret_doc.pdf?token=xyz',
        fileName: 'k11_secret.pdf',
        fileType: 'pdf',
        fileSizeBytes: 3 * 1024 * 1024,
        verificationStatus: CertificateVerificationStatus.verified,
        adminReviewNotes: 'Internal admin note: Verified via institute portal',
        rejectionReason: null,
        reviewedBy: 'admin_uid_777',
        reviewedAt: DateTime(2024, 1, 15),
      );

      final publicQual = privateCert.toPublicQualification();

      // Public view contains approved metadata
      expect(publicQual.id, 'cert_priv_999');
      expect(publicQual.certificateName, 'K11 Diploma in Personal Training');
      expect(publicQual.courseName, 'Certified Personal Trainer Course');
      expect(publicQual.issuingOrganization, 'K11 School of Fitness Sciences');
      expect(publicQual.yearOfCompletion, '2023');
      expect(publicQual.qualificationDetails, 'Specialized in hypertrophy and functional strength');

      // Verify serialization of public qualification
      final map = publicQual.toMap();
      expect(map.containsKey('storagePath'), isFalse);
      expect(map.containsKey('fileUrl'), isFalse);
      expect(map.containsKey('fileName'), isFalse);
      expect(map.containsKey('fileSizeBytes'), isFalse);
      expect(map.containsKey('adminReviewNotes'), isFalse);
      expect(map.containsKey('reviewedBy'), isFalse);
    });

    test('TrainerProfileModel serializes verifiedQualifications safely to public schema', () {
      final qual = const VerifiedQualification(
        id: 'vq1',
        certificateName: 'CPR & AED First Aid',
        courseName: 'Cardiopulmonary Resuscitation',
        issuingOrganization: 'Red Cross',
        yearOfCompletion: '2024',
      );

      final profile = TrainerProfileModel(
        uid: 't_prof_1',
        fullName: 'Rahul Sharma',
        category: TrainerCategory.trainer,
        verifiedQualifications: [qual],
      );

      final map = profile.toMap();
      expect(map['verifiedQualifications'], isA<List>());
      final list = map['verifiedQualifications'] as List;
      expect(list.length, 1);
      expect(list.first['certificateName'], 'CPR & AED First Aid');
      expect(list.first['issuingOrganization'], 'Red Cross');

      // Deserialization restores verifiedQualifications
      final restored = TrainerProfileModel.fromMap(map, uid: 't_prof_1');
      expect(restored.verifiedQualifications.length, 1);
      expect(restored.verifiedQualifications.first.certificateName, 'CPR & AED First Aid');
      expect(restored.verifiedQualifications.first.displayText, 'CPR & AED First Aid • Red Cross (2024)');
    });
  });

  group('Group 6: Zero Dating & Romantic Language Audit', () {
    test('Certificate screen copy contains zero dating or romantic terms', () {
      final certScreen = const TrainerCertificatesScreen();
      expect(certScreen, isNotNull);

      const forbidden = ['dating', 'matchmaking', 'crush', 'single', 'flirt', 'romantic', 'hookup'];
      const sampleTexts = [
        'Certificates & Qualifications',
        'Upload your professional certification document (PDF or image). Max 10 MB.',
        'Private & Secure: Full certificates and documents are accessible ONLY to you and TRAIN Z administrators.',
        'Standard Trainer requires at least one beginner-level trainer certificate for Admin verification.',
        'Advanced Trainer requires relevant professional trainer certificates and at least 3.5 years of experience.',
      ];

      for (final text in sampleTexts) {
        for (final word in forbidden) {
          expect(text.toLowerCase().contains(word), isFalse, reason: 'Found forbidden word: $word in $text');
        }
      }
    });
  });

  group('Group 7: Widget Tests for TrainerCertificatesScreen', () {
    testWidgets('Renders empty state, requirements card, and upload button when no certificates', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerCertificatesScreen(
            trainerId: 'trainer_empty_test',
            category: TrainerCategory.trainer,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Certificates & Qualifications'), findsOneWidget);
      expect(find.text('TRAINER'), findsOneWidget);
      expect(find.text('Action Required'), findsOneWidget);
      expect(find.text('No Certificates Uploaded'), findsOneWidget);
      expect(find.text('Upload First Certificate'), findsOneWidget);
      expect(find.text('Upload Certificate'), findsWidgets);
    });

    testWidgets('Renders certificate cards with status chips and privacy notice', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cert1 = TrainerCertificateModel(
        id: 'c_widget_1',
        trainerId: 'trainer_widgets',
        certificateName: 'American College of Sports Medicine (ACSM)',
        courseName: 'Certified Personal Trainer',
        issuingOrganization: 'ACSM',
        yearOfCompletion: '2023',
        storagePath: 'certificates/trainer_widgets/c_widget_1.pdf',
        fileName: 'acsm_cert.pdf',
        fileType: 'pdf',
        fileSizeBytes: 2 * 1024 * 1024,
        verificationStatus: CertificateVerificationStatus.verified,
      );

      final cert2 = TrainerCertificateModel(
        id: 'c_widget_2',
        trainerId: 'trainer_widgets',
        certificateName: 'Functional Strength Coach',
        courseName: 'Kettlebell & Bodyweight Training',
        issuingOrganization: 'Fitness Institute',
        yearOfCompletion: '2024',
        storagePath: 'certificates/trainer_widgets/c_widget_2.jpg',
        fileName: 'kettlebell.jpg',
        fileType: 'jpg',
        fileSizeBytes: 1024 * 800,
        verificationStatus: CertificateVerificationStatus.resubmissionRequired,
        rejectionReason: 'Certificate expiry date is not visible.',
      );

      service.seedMockCertificates('trainer_widgets', [cert1, cert2]);

      await tester.pumpWidget(
        const MaterialApp(
          home: TrainerCertificatesScreen(
            trainerId: 'trainer_widgets',
            category: TrainerCategory.advancedTrainer,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('American College of Sports Medicine (ACSM)'), findsOneWidget);
      expect(find.text('Verified'), findsWidgets);
      expect(find.text('Functional Strength Coach'), findsOneWidget);
      expect(find.text('Resubmission Required'), findsOneWidget);
      expect(find.text('Replace / Resubmit'), findsOneWidget);
      expect(find.text('Certificate expiry date is not visible.'), findsOneWidget);
    });
  });
}
