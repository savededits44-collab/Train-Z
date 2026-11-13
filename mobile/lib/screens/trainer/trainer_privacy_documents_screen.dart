import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/trainer_certificate_service.dart';
import '../../shared/models/trainer_certificate_model.dart';
import 'trainer_certificates_screen.dart';

const Color _kDark = Color(0xFF141416);
const Color _kCardBg = Color(0xFF1C1C1E);
const Color _kLime = Color(0xFFD4FF00);
const Color _kGrey = Color(0xFF777E90);
const Color _kBorder = Color(0xFF2E323E);
const Color _kSuccess = Color(0xFF10B981);
const Color _kWarning = Color(0xFFF59E0B);
const Color _kDanger = Color(0xFFEF4444);

/// Screen for Trainers to review certificate submissions, document privacy policies,
/// and understand qualification verification states.
class TrainerPrivacyDocumentsScreen extends StatefulWidget {
  final String? trainerId;

  const TrainerPrivacyDocumentsScreen({super.key, this.trainerId});

  @override
  State<TrainerPrivacyDocumentsScreen> createState() =>
      _TrainerPrivacyDocumentsScreenState();
}

class _TrainerPrivacyDocumentsScreenState
    extends State<TrainerPrivacyDocumentsScreen> {
  final TrainerCertificateService _certService =
      TrainerCertificateService.instance;
  late final String _trainerId;

  @override
  void initState() {
    super.initState();
    _trainerId = widget.trainerId ??
        AuthService().currentUser?.uid ??
        '';
  }

  Color _getStatusColor(CertificateVerificationStatus status) {
    switch (status) {
      case CertificateVerificationStatus.verified:
        return _kSuccess;
      case CertificateVerificationStatus.pending:
        return _kWarning;
      case CertificateVerificationStatus.rejected:
      case CertificateVerificationStatus.resubmissionRequired:
        return _kDanger;
      case CertificateVerificationStatus.notSubmitted:
        return _kGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDark,
      appBar: AppBar(
        backgroundColor: _kDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Privacy & Certificate Documents',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 1. Document Privacy Guarantee ─────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Iconsax.shield_security, color: _kLime, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Document Privacy Guarantee',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '• Full certificate files, diplomas, and government IDs are kept strictly private in encrypted storage.\n• Only platform administrators and you have access to raw files.\n• Clients and athletes ONLY see approved qualification titles, issuing organizations, and years of completion.\n• Private storage links are never exposed to the public.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: _kGrey,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── 2. Submitted Certificates Header ──────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Submitted Certificates',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TrainerCertificatesScreen(trainerId: _trainerId),
                    ),
                  );
                },
                icon: const Icon(Iconsax.add_circle, color: _kLime, size: 16),
                label: const Text(
                  'Upload / Manage',
                  style: TextStyle(fontFamily: 'Syne', fontSize: 12, color: _kLime, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // ── 3. Certificates Stream List ───────────────────
          StreamBuilder<List<TrainerCertificateModel>>(
            stream: _certService.streamTrainerCertificates(_trainerId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: _kLime),
                  ),
                );
              }

              final certs = snapshot.data ?? [];

              if (certs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _kCardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Column(
                    children: [
                      const Icon(Iconsax.document_text, color: _kGrey, size: 36),
                      const SizedBox(height: 12),
                      const Text(
                        'No Certificates Submitted',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Upload qualifications to upgrade to Advanced Trainer and unlock custom plans.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: _kGrey),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kLime,
                          foregroundColor: _kDark,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TrainerCertificatesScreen(trainerId: _trainerId),
                            ),
                          );
                        },
                        child: const Text(
                          'Upload First Certificate',
                          style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: certs.map((cert) {
                  final statusColor = _getStatusColor(cert.verificationStatus);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kCardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Iconsax.award, color: statusColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cert.certificateName,
                                    style: const TextStyle(
                                      fontFamily: 'Syne',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${cert.issuingOrganization} • ${cert.yearOfCompletion}',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      color: _kGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: statusColor.withAlpha(80)),
                              ),
                              child: Text(
                                cert.verificationStatus.displayName.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'Syne',
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (cert.rejectionReason != null &&
                            cert.rejectionReason!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _kDanger.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _kDanger.withAlpha(60)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline, color: _kDanger, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Admin Feedback: ${cert.rejectionReason}',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
