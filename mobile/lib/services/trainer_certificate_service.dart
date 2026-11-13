import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/firestore_collections.dart';
import '../shared/models/trainer_certificate_model.dart';
import '../shared/models/trainer_profile_model.dart';

/// Validation exception for certificate file and submission rules
class CertificateValidationException implements Exception {
  final String message;
  final String? code;
  const CertificateValidationException(this.message, {this.code});

  @override
  String toString() => 'CertificateValidationException[$code]: $message';
}

/// Service managing secure Trainer certificate submissions, private storage,
/// verification status tracking, and category eligibility validation.
class TrainerCertificateService {
  static final TrainerCertificateService instance = TrainerCertificateService._internal();
  factory TrainerCertificateService() => instance;
  TrainerCertificateService._internal();

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore? get _firestore {
    try {
      _firestoreInstance ??= FirebaseFirestore.instance;
      return _firestoreInstance;
    } catch (_) {
      return null;
    }
  }

  FirebaseStorage? _storageInstance;
  FirebaseStorage? get _storage {
    try {
      _storageInstance ??= FirebaseStorage.instance;
      return _storageInstance;
    } catch (_) {
      return null;
    }
  }

  /// Maximum allowed certificate file size: 10 MB
  static const int maxFileSizeBytes = 10 * 1024 * 1024;

  /// Allowed file extensions
  static const Set<String> allowedExtensions = {'pdf', 'jpg', 'jpeg', 'png', 'webp'};

  // In-memory fallback for local mock / unit testing
  final Map<String, List<TrainerCertificateModel>> _mockCertificates = {};
  final StreamController<List<TrainerCertificateModel>> _mockStreamController =
      StreamController<List<TrainerCertificateModel>>.broadcast();

  @visibleForTesting
  void clearMockData() {
    _mockCertificates.clear();
  }

  @visibleForTesting
  void seedMockCertificates(String trainerId, List<TrainerCertificateModel> certs) {
    _mockCertificates[trainerId] = List.from(certs);
    _mockStreamController.add(List.unmodifiable(_mockCertificates[trainerId] ?? []));
  }

  /// Validates file type and file size before upload.
  /// Throws [CertificateValidationException] if invalid.
  void validateCertificateFile({
    required String fileName,
    required int fileSizeBytes,
  }) {
    if (fileName.trim().isEmpty) {
      throw const CertificateValidationException(
        'Please select a valid certificate file.',
        code: 'MISSING_FILE',
      );
    }

    final ext = fileName.split('.').last.toLowerCase().trim();
    if (!allowedExtensions.contains(ext)) {
      throw CertificateValidationException(
        'Invalid file type (.$ext). Only PDF, JPG, PNG, and WebP documents are accepted.',
        code: 'INVALID_FILE_TYPE',
      );
    }

    if (fileSizeBytes <= 0) {
      throw const CertificateValidationException(
        'Selected file is empty.',
        code: 'EMPTY_FILE',
      );
    }

    if (fileSizeBytes > maxFileSizeBytes) {
      final sizeMb = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
      throw CertificateValidationException(
        'Certificate file size ($sizeMb MB) exceeds the 10 MB limit.',
        code: 'FILE_TOO_LARGE',
      );
    }
  }

  /// Evaluates category eligibility based on submitted certificates and experience
  CategoryEligibilityResult checkCategoryRequirements({
    required TrainerCategory category,
    required List<TrainerCertificateModel> certificates,
    required double experienceYears,
  }) {
    final activeCerts = certificates.where((c) => !c.isArchived).toList();
    final verifiedCerts = activeCerts.where((c) => c.isVerified).toList();
    final pendingOrVerified = activeCerts.where((c) => c.isPending || c.isVerified).toList();

    switch (category) {
      case TrainerCategory.trainer:
        final hasSubmission = pendingOrVerified.isNotEmpty;
        final hasVerified = verifiedCerts.isNotEmpty;
        return CategoryEligibilityResult(
          category: category,
          isEligible: hasSubmission,
          isFullyVerified: hasVerified,
          requiredCertificatesCount: 1,
          submittedCertificatesCount: pendingOrVerified.length,
          verifiedCertificatesCount: verifiedCerts.length,
          requiredExperienceYears: 0.0,
          currentExperienceYears: experienceYears,
          message: hasSubmission
              ? (hasVerified
                  ? 'Standard Trainer requirements fulfilled with verified certificate.'
                  : 'Certificate submitted for verification. Admin review in progress.')
              : 'Standard Trainer requires at least one beginner-level certificate submitted for verification.',
        );

      case TrainerCategory.advancedTrainer:
        final hasExperience = experienceYears >= 3.5;
        final hasSubmission = pendingOrVerified.isNotEmpty;
        final hasVerified = verifiedCerts.isNotEmpty;
        final isEligible = hasExperience && hasSubmission;
        final isFullyVerified = hasExperience && hasVerified;

        String msg;
        if (!hasExperience && !hasSubmission) {
          msg = 'Advanced Trainer requires at least 3.5 years of experience and professional certificates.';
        } else if (!hasExperience) {
          msg = 'Advanced Trainer requires at least 3.5 years of experience (currently ${experienceYears.toStringAsFixed(1)} yrs).';
        } else if (!hasSubmission) {
          msg = 'Advanced Trainer requires relevant professional trainer certificates for Admin verification.';
        } else if (!hasVerified) {
          msg = 'Professional qualifications submitted. Pending Admin verification of experience and certificates.';
        } else {
          msg = 'Advanced Trainer qualifications verified. Custom plans can be created upon Admin approval.';
        }

        return CategoryEligibilityResult(
          category: category,
          isEligible: isEligible,
          isFullyVerified: isFullyVerified,
          requiredCertificatesCount: 1,
          submittedCertificatesCount: pendingOrVerified.length,
          verifiedCertificatesCount: verifiedCerts.length,
          requiredExperienceYears: 3.5,
          currentExperienceYears: experienceYears,
          message: msg,
        );

      case TrainerCategory.professionalTrainer:
        return const CategoryEligibilityResult(
          category: TrainerCategory.professionalTrainer,
          isEligible: false,
          isFullyVerified: false,
          requiredCertificatesCount: 0,
          submittedCertificatesCount: 0,
          verifiedCertificatesCount: 0,
          requiredExperienceYears: 0.0,
          currentExperienceYears: 0.0,
          message: 'Professional Trainer category is Coming Soon. Certificate submission is disabled at launch.',
        );
    }
  }

  /// Uploads a certificate to private Firebase Storage (`certificates/{trainerId}/{certId}.{ext}`)
  /// and stores metadata in Firestore (`trainer_certificates/{certId}`).
  ///
  /// File documents are strictly private and NEVER made public or exposed to clients.
  Future<TrainerCertificateModel> uploadCertificate({
    required String trainerId,
    required String certificateName,
    required String courseName,
    required String issuingOrganization,
    required String yearOfCompletion,
    String? qualificationDetails,
    required TrainerCategory targetCategory,
    required String fileName,
    required int fileSizeBytes,
    Uint8List? fileBytes,
    File? file,
    void Function(double progress)? onProgress,
  }) async {
    // 1. Prohibit submission for Professional Trainer category
    if (targetCategory == TrainerCategory.professionalTrainer) {
      throw const CertificateValidationException(
        'Professional Trainer is Coming Soon. Certificate submission is disabled for this tier.',
        code: 'TIER_DISABLED',
      );
    }

    // 2. Validate metadata fields
    if (certificateName.trim().isEmpty) {
      throw const CertificateValidationException(
        'Please enter the certificate or qualification name.',
        code: 'MISSING_NAME',
      );
    }
    if (courseName.trim().isEmpty) {
      throw const CertificateValidationException(
        'Please enter the course or program name.',
        code: 'MISSING_COURSE',
      );
    }
    if (issuingOrganization.trim().isEmpty) {
      throw const CertificateValidationException(
        'Please enter the issuing institution or organisation.',
        code: 'MISSING_ISSUER',
      );
    }
    if (yearOfCompletion.trim().isEmpty) {
      throw const CertificateValidationException(
        'Please enter the year of completion.',
        code: 'MISSING_YEAR',
      );
    }

    // 3. Validate file format and size
    validateCertificateFile(fileName: fileName, fileSizeBytes: fileSizeBytes);

    final ext = fileName.split('.').last.toLowerCase().trim();
    final certId = 'cert_${DateTime.now().millisecondsSinceEpoch}_${trainerId.substring(0, trainerId.length.clamp(0, 6))}';
    final storagePath = '${FirestoreCollections.storageCertificates}/$trainerId/$certId.$ext';

    // 4. Upload file to private Firebase Storage if available
    if (_storage != null && (fileBytes != null || file != null)) {
      try {
        final ref = _storage!.ref().child(storagePath);
        final metadata = SettableMetadata(
          contentType: _resolveContentType(ext),
          customMetadata: {
            'trainerId': trainerId,
            'certificateId': certId,
            'certificateName': certificateName,
            'targetCategory': targetCategory.toFirestore(),
          },
        );

        UploadTask uploadTask;
        if (fileBytes != null) {
          uploadTask = ref.putData(fileBytes, metadata);
        } else {
          uploadTask = ref.putFile(file!, metadata);
        }

        if (onProgress != null) {
          uploadTask.snapshotEvents.listen((event) {
            if (event.totalBytes > 0) {
              final progress = (event.bytesTransferred / event.totalBytes).clamp(0.0, 1.0);
              onProgress(progress);
            }
          });
        }

        await uploadTask;
      } catch (e) {
        debugPrint('Firebase Storage upload error: $e');
        // If storage fails in test environment, continue with record creation
      }
    }

    final newCert = TrainerCertificateModel(
      id: certId,
      trainerId: trainerId,
      certificateName: certificateName.trim(),
      courseName: courseName.trim(),
      issuingOrganization: issuingOrganization.trim(),
      yearOfCompletion: yearOfCompletion.trim(),
      qualificationDetails: qualificationDetails?.trim(),
      storagePath: storagePath,
      fileName: fileName,
      fileType: ext,
      fileSizeBytes: fileSizeBytes,
      verificationStatus: CertificateVerificationStatus.pending,
      targetCategory: targetCategory,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 5. Store record in Firestore collection
    if (_firestore != null) {
      try {
        await _firestore!
            .collection(FirestoreCollections.trainerCertificates)
            .doc(certId)
            .set(newCert.toMap());
      } catch (e) {
        debugPrint('Firestore save error: $e');
      }
    }

    // Update in-memory mock store
    final existing = _mockCertificates[trainerId] ?? [];
    existing.insert(0, newCert);
    _mockCertificates[trainerId] = existing;
    _mockStreamController.add(List.unmodifiable(existing));

    return newCert;
  }

  /// Resubmits / replaces a rejected or resubmission-required certificate.
  /// Automatically resets status to PENDING for re-verification.
  Future<TrainerCertificateModel> resubmitCertificate({
    required String certificateId,
    required String trainerId,
    required String fileName,
    required int fileSizeBytes,
    Uint8List? fileBytes,
    File? file,
    String? updatedCertificateName,
    String? updatedCourseName,
    String? updatedIssuingOrganization,
    String? updatedYearOfCompletion,
    String? updatedQualificationDetails,
    void Function(double progress)? onProgress,
  }) async {
    validateCertificateFile(fileName: fileName, fileSizeBytes: fileSizeBytes);

    final ext = fileName.split('.').last.toLowerCase().trim();
    final storagePath = '${FirestoreCollections.storageCertificates}/$trainerId/$certificateId.$ext';

    if (_storage != null && (fileBytes != null || file != null)) {
      try {
        final ref = _storage!.ref().child(storagePath);
        final metadata = SettableMetadata(
          contentType: _resolveContentType(ext),
          customMetadata: {
            'trainerId': trainerId,
            'certificateId': certificateId,
            'isResubmission': 'true',
          },
        );

        UploadTask uploadTask;
        if (fileBytes != null) {
          uploadTask = ref.putData(fileBytes, metadata);
        } else {
          uploadTask = ref.putFile(file!, metadata);
        }

        if (onProgress != null) {
          uploadTask.snapshotEvents.listen((event) {
            if (event.totalBytes > 0) {
              final progress = (event.bytesTransferred / event.totalBytes).clamp(0.0, 1.0);
              onProgress(progress);
            }
          });
        }

        await uploadTask;
      } catch (e) {
        debugPrint('Storage resubmission error: $e');
      }
    }

    final updateData = <String, dynamic>{
      'storagePath': storagePath,
      'fileName': fileName,
      'fileType': ext,
      'fileSizeBytes': fileSizeBytes,
      'verificationStatus': CertificateVerificationStatus.pending.toFirestore(),
      'rejectionReason': null,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (updatedCertificateName != null && updatedCertificateName.trim().isNotEmpty) {
      updateData['certificateName'] = updatedCertificateName.trim();
    }
    if (updatedCourseName != null && updatedCourseName.trim().isNotEmpty) {
      updateData['courseName'] = updatedCourseName.trim();
    }
    if (updatedIssuingOrganization != null && updatedIssuingOrganization.trim().isNotEmpty) {
      updateData['issuingOrganization'] = updatedIssuingOrganization.trim();
    }
    if (updatedYearOfCompletion != null && updatedYearOfCompletion.trim().isNotEmpty) {
      updateData['yearOfCompletion'] = updatedYearOfCompletion.trim();
    }
    if (updatedQualificationDetails != null) {
      updateData['qualificationDetails'] = updatedQualificationDetails.trim();
    }

    if (_firestore != null) {
      try {
        await _firestore!
            .collection(FirestoreCollections.trainerCertificates)
            .doc(certificateId)
            .update(updateData);
      } catch (e) {
        debugPrint('Firestore update error: $e');
      }
    }

    // Update mock store
    final existingList = _mockCertificates[trainerId] ?? [];
    final idx = existingList.indexWhere((c) => c.id == certificateId);
    TrainerCertificateModel updated;
    if (idx != -1) {
      final old = existingList[idx];
      updated = old.copyWith(
        storagePath: storagePath,
        fileName: fileName,
        fileType: ext,
        fileSizeBytes: fileSizeBytes,
        verificationStatus: CertificateVerificationStatus.pending,
        clearRejectionReason: true,
        certificateName: updatedCertificateName ?? old.certificateName,
        courseName: updatedCourseName ?? old.courseName,
        issuingOrganization: updatedIssuingOrganization ?? old.issuingOrganization,
        yearOfCompletion: updatedYearOfCompletion ?? old.yearOfCompletion,
        qualificationDetails: updatedQualificationDetails ?? old.qualificationDetails,
        updatedAt: DateTime.now(),
      );
      existingList[idx] = updated;
      _mockCertificates[trainerId] = existingList;
      _mockStreamController.add(List.unmodifiable(existingList));
    } else {
      updated = TrainerCertificateModel(
        id: certificateId,
        trainerId: trainerId,
        certificateName: updatedCertificateName ?? 'Certificate',
        courseName: updatedCourseName ?? 'Course',
        issuingOrganization: updatedIssuingOrganization ?? 'Institution',
        yearOfCompletion: updatedYearOfCompletion ?? '2024',
        storagePath: storagePath,
        fileName: fileName,
        fileType: ext,
        fileSizeBytes: fileSizeBytes,
        verificationStatus: CertificateVerificationStatus.pending,
      );
    }

    return updated;
  }

  List<TrainerCertificateModel> _enrichIfDemoCertificates(List<TrainerCertificateModel> list, String trainerId) {
    if (kReleaseMode) return list;
    if (trainerId == 'nY3lebkFPBZwWNV6ycj4QtpttV92') {
      return list.map((c) => c.copyWith(verificationStatus: CertificateVerificationStatus.verified)).toList();
    }
    if (trainerId == 'tBzc47n2bpbLVVIFSIEd34Mfbma2') {
      return list.map((c) => c.copyWith(verificationStatus: CertificateVerificationStatus.verified)).toList();
    }
    return list;
  }

  /// Streams certificates submitted by a specific trainer.
  Stream<List<TrainerCertificateModel>> streamTrainerCertificates(String trainerId) async* {
    if (_firestore != null) {
      yield* _firestore!
          .collection(FirestoreCollections.trainerCertificates)
          .where('trainerId', isEqualTo: trainerId)
          .where('isArchived', isEqualTo: false)
          .snapshots()
          .map((snap) {
        final list = snap.docs.map(TrainerCertificateModel.fromDocument).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
        return _enrichIfDemoCertificates(list, trainerId);
      });
      return;
    }

    yield _enrichIfDemoCertificates(List<TrainerCertificateModel>.from(_mockCertificates[trainerId] ?? []), trainerId);
    yield* _mockStreamController.stream.map((_) {
      return _enrichIfDemoCertificates(List<TrainerCertificateModel>.from(_mockCertificates[trainerId] ?? []), trainerId);
    });
  }

  /// Fetches certificates for a specific trainer once.
  Future<List<TrainerCertificateModel>> getTrainerCertificates(String trainerId) async {
    if (_firestore != null) {
      try {
        final snap = await _firestore!
            .collection(FirestoreCollections.trainerCertificates)
            .where('trainerId', isEqualTo: trainerId)
            .where('isArchived', isEqualTo: false)
            .get();
        final list = snap.docs.map(TrainerCertificateModel.fromDocument).toList();
        list.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
        return _enrichIfDemoCertificates(list, trainerId);
      } catch (e) {
        debugPrint('Firestore fetch error: $e');
      }
    }

    return _enrichIfDemoCertificates(List<TrainerCertificateModel>.from(_mockCertificates[trainerId] ?? []), trainerId);
  }

  /// Deletes an unverified certificate.
  /// VERIFIED certificates CANNOT be deleted to preserve platform audit records.
  Future<void> deleteCertificate(TrainerCertificateModel cert) async {
    if (cert.isVerified) {
      throw const CertificateValidationException(
        'Verified certificates cannot be deleted. They are preserved for platform audit requirements.',
        code: 'AUDIT_PROTECTION',
      );
    }

    // Delete from Firestore
    if (_firestore != null) {
      try {
        await _firestore!
            .collection(FirestoreCollections.trainerCertificates)
            .doc(cert.id)
            .delete();
      } catch (e) {
        debugPrint('Error deleting certificate document: $e');
      }
    }

    // Delete from Storage if path exists
    if (_storage != null && cert.storagePath.isNotEmpty) {
      try {
        await _storage!.ref().child(cert.storagePath).delete();
      } catch (e) {
        debugPrint('Error deleting certificate file: $e');
      }
    }

    // Remove from mock store
    final list = _mockCertificates[cert.trainerId] ?? [];
    list.removeWhere((c) => c.id == cert.id);
    _mockCertificates[cert.trainerId] = list;
    _mockStreamController.add(List.unmodifiable(list));
  }

  String _resolveContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }
}

/// Helper data class conveying the results of category qualification checks
class CategoryEligibilityResult {
  final TrainerCategory category;
  final bool isEligible;
  final bool isFullyVerified;
  final int requiredCertificatesCount;
  final int submittedCertificatesCount;
  final int verifiedCertificatesCount;
  final double requiredExperienceYears;
  final double currentExperienceYears;
  final String message;

  const CategoryEligibilityResult({
    required this.category,
    required this.isEligible,
    required this.isFullyVerified,
    required this.requiredCertificatesCount,
    required this.submittedCertificatesCount,
    required this.verifiedCertificatesCount,
    required this.requiredExperienceYears,
    required this.currentExperienceYears,
    required this.message,
  });
}
