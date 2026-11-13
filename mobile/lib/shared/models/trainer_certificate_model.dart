import 'package:cloud_firestore/cloud_firestore.dart';
import 'trainer_profile_model.dart';

enum CertificateVerificationStatus {
  notSubmitted,
  pending,
  verified,
  rejected,
  resubmissionRequired;

  String toFirestore() {
    switch (this) {
      case CertificateVerificationStatus.notSubmitted:
        return 'NOT_SUBMITTED';
      case CertificateVerificationStatus.pending:
        return 'PENDING';
      case CertificateVerificationStatus.verified:
        return 'VERIFIED';
      case CertificateVerificationStatus.rejected:
        return 'REJECTED';
      case CertificateVerificationStatus.resubmissionRequired:
        return 'RESUBMISSION_REQUIRED';
    }
  }

  static CertificateVerificationStatus fromFirestore(dynamic val) {
    if (val == null) return CertificateVerificationStatus.pending;
    final str = val.toString().trim().toUpperCase();
    if (str == 'VERIFIED' || str == 'APPROVED') return CertificateVerificationStatus.verified;
    if (str == 'REJECTED') return CertificateVerificationStatus.rejected;
    if (str == 'RESUBMISSION_REQUIRED') return CertificateVerificationStatus.resubmissionRequired;
    if (str == 'NOT_SUBMITTED') return CertificateVerificationStatus.notSubmitted;
    return CertificateVerificationStatus.pending;
  }

  String get displayName {
    switch (this) {
      case CertificateVerificationStatus.notSubmitted:
        return 'Not Submitted';
      case CertificateVerificationStatus.pending:
        return 'Pending Verification';
      case CertificateVerificationStatus.verified:
        return 'Verified';
      case CertificateVerificationStatus.rejected:
        return 'Rejected';
      case CertificateVerificationStatus.resubmissionRequired:
        return 'Resubmission Required';
    }
  }
}

/// Client-facing public qualification metadata.
/// Strictly sanitized: contains zero private storage links or raw documents.
class VerifiedQualification {
  final String id;
  final String certificateName;
  final String courseName;
  final String issuingOrganization;
  final String yearOfCompletion;
  final String? qualificationDetails;

  const VerifiedQualification({
    required this.id,
    required this.certificateName,
    required this.courseName,
    required this.issuingOrganization,
    required this.yearOfCompletion,
    this.qualificationDetails,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'certificateName': certificateName,
        'courseName': courseName,
        'issuingOrganization': issuingOrganization,
        'yearOfCompletion': yearOfCompletion,
        if (qualificationDetails != null) 'qualificationDetails': qualificationDetails,
      };

  factory VerifiedQualification.fromMap(Map<String, dynamic> map) {
    return VerifiedQualification(
      id: map['id'] as String? ?? '',
      certificateName: map['certificateName'] as String? ?? '',
      courseName: map['courseName'] as String? ?? '',
      issuingOrganization: map['issuingOrganization'] as String? ?? '',
      yearOfCompletion: map['yearOfCompletion'] as String? ?? '',
      qualificationDetails: map['qualificationDetails'] as String?,
    );
  }

  String get displayText => '$certificateName • $issuingOrganization ($yearOfCompletion)';
}

/// Full private certificate record submitted by a Trainer.
/// Stored in `trainer_certificates/{certId}` and private storage path `certificates/{trainerId}/{certId}.{ext}`.
/// Accessible ONLY to the Trainer owner and Admin accounts.
class TrainerCertificateModel {
  final String id;
  final String trainerId;
  final String certificateName;
  final String courseName;
  final String issuingOrganization;
  final String yearOfCompletion;
  final String? qualificationDetails;
  final String storagePath;
  final String? fileUrl; // private download url or empty
  final String fileName;
  final String fileType; // pdf, jpg, png, webp
  final int fileSizeBytes;
  final CertificateVerificationStatus verificationStatus;
  final TrainerCategory targetCategory;
  final String? adminReviewNotes;
  final String? rejectionReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TrainerCertificateModel({
    required this.id,
    required this.trainerId,
    required this.certificateName,
    required this.courseName,
    required this.issuingOrganization,
    required this.yearOfCompletion,
    this.qualificationDetails,
    required this.storagePath,
    this.fileUrl,
    required this.fileName,
    required this.fileType,
    required this.fileSizeBytes,
    this.verificationStatus = CertificateVerificationStatus.pending,
    this.targetCategory = TrainerCategory.trainer,
    this.adminReviewNotes,
    this.rejectionReason,
    this.reviewedBy,
    this.reviewedAt,
    this.isArchived = false,
    this.createdAt,
    this.updatedAt,
  });

  bool get isVerified => verificationStatus == CertificateVerificationStatus.verified;
  bool get isPending => verificationStatus == CertificateVerificationStatus.pending;
  bool get isRejected => verificationStatus == CertificateVerificationStatus.rejected;
  bool get isResubmissionRequired => verificationStatus == CertificateVerificationStatus.resubmissionRequired;

  String get formattedFileSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Sanitized client-safe public representation
  VerifiedQualification toPublicQualification() {
    return VerifiedQualification(
      id: id,
      certificateName: certificateName,
      courseName: courseName,
      issuingOrganization: issuingOrganization,
      yearOfCompletion: yearOfCompletion,
      qualificationDetails: qualificationDetails,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trainerId': trainerId,
      'certificateName': certificateName,
      'courseName': courseName,
      'issuingOrganization': issuingOrganization,
      'yearOfCompletion': yearOfCompletion,
      'qualificationDetails': qualificationDetails,
      'storagePath': storagePath,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileType': fileType,
      'fileSizeBytes': fileSizeBytes,
      'verificationStatus': verificationStatus.toFirestore(),
      'targetCategory': targetCategory.toFirestore(),
      'adminReviewNotes': adminReviewNotes,
      'rejectionReason': rejectionReason,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'isArchived': isArchived,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory TrainerCertificateModel.fromMap(Map<String, dynamic> map, {required String id}) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return TrainerCertificateModel(
      id: id,
      trainerId: map['trainerId'] as String? ?? '',
      certificateName: map['certificateName'] as String? ?? '',
      courseName: map['courseName'] as String? ?? '',
      issuingOrganization: map['issuingOrganization'] as String? ?? '',
      yearOfCompletion: map['yearOfCompletion'] as String? ?? '',
      qualificationDetails: map['qualificationDetails'] as String?,
      storagePath: map['storagePath'] as String? ?? '',
      fileUrl: map['fileUrl'] as String?,
      fileName: map['fileName'] as String? ?? 'certificate',
      fileType: map['fileType'] as String? ?? 'pdf',
      fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt() ?? 0,
      verificationStatus: CertificateVerificationStatus.fromFirestore(map['verificationStatus']),
      targetCategory: TrainerCategory.fromFirestore(map['targetCategory']),
      adminReviewNotes: map['adminReviewNotes'] as String?,
      rejectionReason: map['rejectionReason'] as String?,
      reviewedBy: map['reviewedBy'] as String?,
      reviewedAt: parseTimestamp(map['reviewedAt']),
      isArchived: map['isArchived'] as bool? ?? false,
      createdAt: parseTimestamp(map['createdAt']),
      updatedAt: parseTimestamp(map['updatedAt']),
    );
  }

  factory TrainerCertificateModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TrainerCertificateModel.fromMap(data, id: doc.id);
  }

  TrainerCertificateModel copyWith({
    String? id,
    String? trainerId,
    String? certificateName,
    String? courseName,
    String? issuingOrganization,
    String? yearOfCompletion,
    String? qualificationDetails,
    String? storagePath,
    String? fileUrl,
    String? fileName,
    String? fileType,
    int? fileSizeBytes,
    CertificateVerificationStatus? verificationStatus,
    TrainerCategory? targetCategory,
    String? adminReviewNotes,
    String? rejectionReason,
    bool clearRejectionReason = false,
    bool clearAdminReviewNotes = false,
    String? reviewedBy,
    DateTime? reviewedAt,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TrainerCertificateModel(
      id: id ?? this.id,
      trainerId: trainerId ?? this.trainerId,
      certificateName: certificateName ?? this.certificateName,
      courseName: courseName ?? this.courseName,
      issuingOrganization: issuingOrganization ?? this.issuingOrganization,
      yearOfCompletion: yearOfCompletion ?? this.yearOfCompletion,
      qualificationDetails: qualificationDetails ?? this.qualificationDetails,
      storagePath: storagePath ?? this.storagePath,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      targetCategory: targetCategory ?? this.targetCategory,
      adminReviewNotes: clearAdminReviewNotes ? null : (adminReviewNotes ?? this.adminReviewNotes),
      rejectionReason: clearRejectionReason ? null : (rejectionReason ?? this.rejectionReason),
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
