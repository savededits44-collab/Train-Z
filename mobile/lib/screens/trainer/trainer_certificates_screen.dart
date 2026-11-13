import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../services/trainer_certificate_service.dart';
import '../../services/trainer_profile_service.dart';
import '../../shared/models/trainer_certificate_model.dart';
import '../../shared/models/trainer_profile_model.dart';
import '../../widgets/app_widgets.dart';

/// Lightweight wrapper for picked certificate file
class PickedCertificateFile {
  final String name;
  final int size;
  final Uint8List? bytes;
  final String? path;

  const PickedCertificateFile({
    required this.name,
    required this.size,
    this.bytes,
    this.path,
  });
}

/// Screen allowing trainers to securely upload, view, manage, and resubmit
/// certificates and qualifications for Admin verification.
class TrainerCertificatesScreen extends StatefulWidget {
  final String? trainerId;
  final TrainerCategory? category;

  const TrainerCertificatesScreen({
    super.key,
    this.trainerId,
    this.category,
  });

  @override
  State<TrainerCertificatesScreen> createState() => _TrainerCertificatesScreenState();
}

class _TrainerCertificatesScreenState extends State<TrainerCertificatesScreen> {
  final TrainerCertificateService _certificateService = TrainerCertificateService.instance;
  late String _trainerId;
  late TrainerCategory _category;

  @override
  void initState() {
    super.initState();
    _trainerId = widget.trainerId ??
        FirebaseAuth.instance.currentUser?.uid ??
        'trainer_mock_user';
    _category = widget.category ?? TrainerProfileService.instance.category;
  }

  void _openUploadBottomSheet({TrainerCertificateModel? certificateToReplace}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CertificateUploadSheet(
        trainerId: _trainerId,
        initialCategory: _category,
        certificateToReplace: certificateToReplace,
      ),
    );
  }

  Future<void> _handleDelete(TrainerCertificateModel certificate) async {
    if (certificate.isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'Verified certificates cannot be deleted. They are preserved for platform audit requirements.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 13),
          ),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Certificate?',
          style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to remove "${certificate.certificateName}"? This action cannot be undone.',
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: kGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await _certificateService.deleteCertificate(certificate);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: kDark,
              content: Text('Certificate deleted successfully.', style: TextStyle(fontFamily: 'Poppins')),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.redAccent,
              content: Text('Error: $e', style: const TextStyle(fontFamily: 'Poppins')),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: kDark),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Certificates & Qualifications',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: kDark,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.add_circle, color: kDark),
            tooltip: 'Upload Certificate',
            onPressed: () => _openUploadBottomSheet(),
          ),
        ],
      ),
      body: StreamBuilder<List<TrainerCertificateModel>>(
        stream: _certificateService.streamTrainerCertificates(_trainerId),
        builder: (context, snapshot) {
          final certificates = snapshot.data ?? [];
          final expYears = TrainerProfileService.instance.experienceYears;
          final eligibility = _certificateService.checkCategoryRequirements(
            category: _category,
            certificates: certificates,
            experienceYears: expYears,
          );

          return CustomScrollView(
            slivers: [
              // Category Requirements & Privacy Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRequirementsCard(eligibility),
                      const SizedBox(height: 12),
                      _buildPrivacyBanner(),
                    ],
                  ),
                ),
              ),

              // Certificate List Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'SUBMITTED CERTIFICATES (${certificates.length})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Syne',
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: kDark,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (certificates.isNotEmpty)
                        Text(
                          '${eligibility.verifiedCertificatesCount} Verified',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: eligibility.verifiedCertificatesCount > 0
                                ? const Color(0xFF2E7D32)
                                : kGrey,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Empty State or List
              if (certificates.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final cert = certificates[index];
                        return _buildCertificateCard(cert);
                      },
                      childCount: certificates.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: ElevatedButton.icon(
            onPressed: () => _openUploadBottomSheet(),
            icon: const Icon(Iconsax.document_upload, color: kDark, size: 20),
            label: const Text(
              'Upload Certificate',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kDark,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: kLime,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementsCard(CategoryEligibilityResult eligibility) {
    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (eligibility.isFullyVerified) {
      badgeColor = const Color(0xFF2E7D32);
      badgeText = 'Verified';
      badgeIcon = Iconsax.verify;
    } else if (eligibility.isEligible) {
      badgeColor = const Color(0xFFF57C00);
      badgeText = 'Pending Review';
      badgeIcon = Iconsax.clock;
    } else {
      badgeColor = const Color(0xFFD32F2F);
      badgeText = 'Action Required';
      badgeIcon = Iconsax.info_circle;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kField,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: kDark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Iconsax.award, color: kLime, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _category.displayName.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: kDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 13, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _category == TrainerCategory.advancedTrainer
                ? 'Advanced Trainer requires relevant professional trainer certificates and at least 3.5 years of experience. Verified by Admin.'
                : 'Standard Trainer requires at least one beginner-level trainer certificate submitted for Admin verification.',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              color: Color(0xFF555555),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                Icon(
                  eligibility.isEligible ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 16,
                  color: eligibility.isEligible ? const Color(0xFF2E7D32) : kGrey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    eligibility.message,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: kDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Iconsax.shield_tick, color: Color(0xFF16A34A), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Private & Secure: Full certificates and documents are accessible ONLY to you and TRAIN Z administrators. Clients never see your raw documents or download links.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                color: Color(0xFF166534),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateCard(TrainerCertificateModel cert) {
    Color statusColor;
    Color statusBg;
    IconData statusIcon;

    switch (cert.verificationStatus) {
      case CertificateVerificationStatus.verified:
        statusColor = const Color(0xFF16A34A);
        statusBg = const Color(0xFFDCFCE7);
        statusIcon = Iconsax.verify;
        break;
      case CertificateVerificationStatus.pending:
        statusColor = const Color(0xFFD97706);
        statusBg = const Color(0xFFFEF3C7);
        statusIcon = Iconsax.clock;
        break;
      case CertificateVerificationStatus.rejected:
        statusColor = const Color(0xFFDC2626);
        statusBg = const Color(0xFFFEE2E2);
        statusIcon = Iconsax.close_circle;
        break;
      case CertificateVerificationStatus.resubmissionRequired:
        statusColor = const Color(0xFFEA580C);
        statusBg = const Color(0xFFFFEDD5);
        statusIcon = Iconsax.warning_2;
        break;
      case CertificateVerificationStatus.notSubmitted:
        statusColor = kGrey;
        statusBg = kField;
        statusIcon = Iconsax.info_circle;
        break;
    }

    final isPdf = cert.fileType.toLowerCase() == 'pdf';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cert.isResubmissionRequired || cert.isRejected
              ? statusColor.withValues(alpha: 0.4)
              : kBorder,
          width: cert.isResubmissionRequired || cert.isRejected ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Document type & status badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isPdf ? const Color(0xFFFFEBEE) : const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPdf ? Iconsax.document_text : Iconsax.gallery,
                                size: 12,
                                color: isPdf ? Colors.redAccent : const Color(0xFF0284C7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                cert.fileType.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'Syne',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isPdf ? Colors.redAccent : const Color(0xFF0284C7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          cert.formattedFileSize,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: kGrey,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            cert.verificationStatus.displayName,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Certificate title
                Text(
                  cert.certificateName,
                  style: const TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 4),

                // Course and issuing organization
                Text(
                  '${cert.courseName} • ${cert.issuingOrganization}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Color(0xFF444444),
                  ),
                ),
                const SizedBox(height: 2),

                // Year of completion
                Text(
                  'Completed in ${cert.yearOfCompletion}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: kGrey,
                  ),
                ),

                if (cert.qualificationDetails != null && cert.qualificationDetails!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    cert.qualificationDetails!,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Color(0xFF666666),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Admin Feedback if Rejected / Resubmission Required
          if (cert.isRejected || cert.isResubmissionRequired) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: statusBg.withValues(alpha: 0.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Iconsax.info_circle, size: 14, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        cert.isRejected ? 'Admin Rejection Feedback' : 'Admin Resubmission Request',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cert.rejectionReason ??
                        cert.adminReviewNotes ??
                        'Please upload a clearer copy of your official certificate for verification.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: statusColor.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Action Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: kBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (cert.isRejected || cert.isResubmissionRequired)
                  TextButton.icon(
                    onPressed: () => _openUploadBottomSheet(certificateToReplace: cert),
                    icon: const Icon(Iconsax.refresh, size: 16, color: kDark),
                    label: const Text(
                      'Replace / Resubmit',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kDark,
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      const Icon(Iconsax.lock, size: 13, color: kGrey),
                      const SizedBox(width: 4),
                      Text(
                        cert.isVerified ? 'Publicly Verified' : 'Under Review',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: kGrey,
                        ),
                      ),
                    ],
                  ),
                IconButton(
                  tooltip: cert.isVerified ? 'Verified certificates cannot be deleted' : 'Delete certificate',
                  icon: Icon(
                    Iconsax.trash,
                    size: 16,
                    color: cert.isVerified ? const Color(0xFFCCCCCC) : Colors.redAccent,
                  ),
                  onPressed: () => _handleDelete(cert),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kField,
                shape: BoxShape.circle,
                border: Border.all(color: kBorder),
              ),
              child: const Icon(Iconsax.award, size: 48, color: kGrey),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Certificates Uploaded',
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: kDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _category == TrainerCategory.advancedTrainer
                  ? 'Submit your professional certifications and qualifications to qualify for Advanced Trainer status.'
                  : 'Submit at least one beginner-level trainer certificate for Admin verification.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: kGrey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _openUploadBottomSheet(),
              icon: const Icon(Iconsax.add, color: kDark),
              label: const Text(
                'Upload First Certificate',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontWeight: FontWeight.w700,
                  color: kDark,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: kLime,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal bottom sheet for certificate file selection, validation, and submission
class _CertificateUploadSheet extends StatefulWidget {
  final String trainerId;
  final TrainerCategory initialCategory;
  final TrainerCertificateModel? certificateToReplace;

  const _CertificateUploadSheet({
    required this.trainerId,
    required this.initialCategory,
    this.certificateToReplace,
  });

  @override
  State<_CertificateUploadSheet> createState() => _CertificateUploadSheetState();
}

class _CertificateUploadSheetState extends State<_CertificateUploadSheet> {
  final _formKey = GlobalKey<FormState>();
  final _certNameController = TextEditingController();
  final _courseNameController = TextEditingController();
  final _issuerController = TextEditingController();
  final _yearController = TextEditingController();
  final _detailsController = TextEditingController();

  PickedCertificateFile? _pickedFile;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _fileValidationError;
  late TrainerCategory _targetCategory;

  @override
  void initState() {
    super.initState();
    _targetCategory = widget.certificateToReplace?.targetCategory ?? widget.initialCategory;

    if (widget.certificateToReplace != null) {
      final c = widget.certificateToReplace!;
      _certNameController.text = c.certificateName;
      _courseNameController.text = c.courseName;
      _issuerController.text = c.issuingOrganization;
      _yearController.text = c.yearOfCompletion;
      _detailsController.text = c.qualificationDetails ?? '';
    }
  }

  @override
  void dispose() {
    _certNameController.dispose();
    _courseNameController.dispose();
    _issuerController.dispose();
    _yearController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _fileValidationError = null);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final size = file.lengthSync() ?? (await file.length()) ?? 0;
        final bytes = await file.readAsBytes();

        try {
          TrainerCertificateService.instance.validateCertificateFile(
            fileName: file.name,
            fileSizeBytes: size,
          );
          setState(() {
            _pickedFile = PickedCertificateFile(
              name: file.name,
              size: size,
              bytes: bytes,
              path: file.path,
            );
            _fileValidationError = null;
          });
        } on CertificateValidationException catch (e) {
          setState(() {
            _fileValidationError = e.message;
            _pickedFile = null;
          });
        }
      }
    } catch (e) {
      setState(() => _fileValidationError = 'Error selecting file: $e');
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickedFile == null && widget.certificateToReplace == null) {
      setState(() {
        _fileValidationError = 'Please select a PDF or image certificate file.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.1;
    });

    try {
      if (widget.certificateToReplace != null) {
        // Resubmission / Replacement
        await TrainerCertificateService.instance.resubmitCertificate(
          certificateId: widget.certificateToReplace!.id,
          trainerId: widget.trainerId,
          fileName: _pickedFile?.name ?? widget.certificateToReplace!.fileName,
          fileSizeBytes: _pickedFile?.size ?? widget.certificateToReplace!.fileSizeBytes,
          fileBytes: _pickedFile?.bytes,
          file: _pickedFile?.path != null ? File(_pickedFile!.path!) : null,
          updatedCertificateName: _certNameController.text.trim(),
          updatedCourseName: _courseNameController.text.trim(),
          updatedIssuingOrganization: _issuerController.text.trim(),
          updatedYearOfCompletion: _yearController.text.trim(),
          updatedQualificationDetails: _detailsController.text.trim(),
          onProgress: (p) => setState(() => _uploadProgress = p),
        );
      } else {
        // New Submission
        await TrainerCertificateService.instance.uploadCertificate(
          trainerId: widget.trainerId,
          certificateName: _certNameController.text.trim(),
          courseName: _courseNameController.text.trim(),
          issuingOrganization: _issuerController.text.trim(),
          yearOfCompletion: _yearController.text.trim(),
          qualificationDetails: _detailsController.text.trim().isEmpty ? null : _detailsController.text.trim(),
          targetCategory: _targetCategory,
          fileName: _pickedFile!.name,
          fileSizeBytes: _pickedFile!.size,
          fileBytes: _pickedFile!.bytes,
          file: _pickedFile!.path != null ? File(_pickedFile!.path!) : null,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: kDark,
            content: Text(
              widget.certificateToReplace != null
                  ? 'Certificate resubmitted for Admin review.'
                  : 'Certificate uploaded successfully. Pending Admin verification.',
              style: const TextStyle(fontFamily: 'Poppins', color: kLime),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Submission failed: $e', style: const TextStyle(fontFamily: 'Poppins')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isReplace = widget.certificateToReplace != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isReplace ? 'Replace / Resubmit Certificate' : 'Upload Certificate',
                style: const TextStyle(
                  fontFamily: 'Syne',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: kDark,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Upload your professional certification document (PDF or image). Max 10 MB.',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: kGrey),
              ),
              const SizedBox(height: 20),

              // File Picker Area
              GestureDetector(
                onTap: _isUploading ? null : _pickFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kField,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _fileValidationError != null ? Colors.redAccent : kBorder,
                      width: 1.5,
                    ),
                  ),
                  child: _pickedFile != null
                      ? Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: kDark,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Iconsax.document_text, color: kLime, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _pickedFile!.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Syne',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: kDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${(_pickedFile!.size / (1024 * 1024)).toStringAsFixed(2)} MB • Tap to replace',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      color: kGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Iconsax.refresh, color: kDark, size: 18),
                          ],
                        )
                      : Column(
                          children: [
                            const Icon(Iconsax.document_upload, size: 36, color: kDark),
                            const SizedBox(height: 8),
                            const Text(
                              'Choose Document or Image',
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: kDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Supported formats: PDF, JPG, PNG, WebP (up to 10 MB)',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: kGrey,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              if (_fileValidationError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _fileValidationError!,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Colors.redAccent,
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // Form fields
              AppTextField(
                controller: _certNameController,
                label: 'Certificate / Credential Name (e.g. Certified Personal Trainer)',
                icon: Iconsax.award,
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter certificate name' : null,
              ),
              const SizedBox(height: 12),

              AppTextField(
                controller: _courseNameController,
                label: 'Course or Qualification Program',
                icon: Iconsax.book,
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter course name' : null,
              ),
              const SizedBox(height: 12),

              AppTextField(
                controller: _issuerController,
                label: 'Issuing Institution / Organisation',
                icon: Iconsax.building,
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter issuing organisation' : null,
              ),
              const SizedBox(height: 12),

              AppTextField(
                controller: _yearController,
                label: 'Year of Completion (e.g. 2023)',
                icon: Iconsax.calendar_1,
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Please enter year';
                  final numYear = int.tryParse(val.trim());
                  if (numYear == null || numYear < 1970 || numYear > DateTime.now().year + 1) {
                    return 'Please enter a valid year';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              AppTextField(
                controller: _detailsController,
                label: 'Relevant Details / Specialisations (Optional)',
                icon: Iconsax.note,
                maxLines: 2,
              ),

              const SizedBox(height: 20),

              // Upload Progress Indicator
              if (_isUploading) ...[
                LinearProgressIndicator(
                  value: _uploadProgress,
                  backgroundColor: kField,
                  valueColor: const AlwaysStoppedAnimation<Color>(kLime),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Encrypting & Uploading (${(_uploadProgress * 100).toInt()}%)...',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: kDark,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Submit Button
              ElevatedButton(
                onPressed: _isUploading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDark,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _isUploading
                      ? 'Uploading...'
                      : (isReplace ? 'Resubmit for Verification' : 'Submit for Verification'),
                  style: const TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kLime,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
