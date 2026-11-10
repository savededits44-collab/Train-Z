import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../services/trainer_profile_service.dart';
import '../../widgets/app_widgets.dart';

class AdminTrainerReviewScreen extends StatefulWidget {
  const AdminTrainerReviewScreen({super.key});

  @override
  State<AdminTrainerReviewScreen> createState() => _AdminTrainerReviewScreenState();
}

class _AdminTrainerReviewScreenState extends State<AdminTrainerReviewScreen> {
  final TextEditingController _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _showImageDialog(BuildContext context, String path, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: kDark,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Container(
                color: Colors.black,
                constraints: const BoxConstraints(maxHeight: 480),
                child: Image.file(
                  File(path),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmReject(BuildContext context) {
    final reasonController = TextEditingController(
      text: 'Incomplete or unverified coaching credentials.',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Reject Application',
          style: TextStyle(fontFamily: 'Syne', fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a reason for the rejection so the coach can resolve the issue:',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12.5, color: kGrey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
              decoration: InputDecoration(
                filled: true,
                fillColor: kField,
                hintText: 'Enter reason...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kBorder),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins', color: kGrey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
              await TrainerProfileService.instance.rejectByAdmin(
                reason: reasonController.text.trim(),
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Coach application marked as Rejected.',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
                    backgroundColor: Color(0xFFE53935),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              elevation: 0,
            ),
            child: const Text(
              'Confirm Rejection',
              style: TextStyle(fontFamily: 'Syne', color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final hPad = (w * 0.072).clamp(18.0, 32.0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kDark, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Admin Review & Approvals',
          style: TextStyle(
            fontFamily: 'Syne',
            fontSize: (16.0 * sf).clamp(14.0, 18.0),
            fontWeight: FontWeight.w700,
            color: kDark,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: kDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_rounded, color: kLime, size: 13),
                SizedBox(width: 4),
                Text(
                  'Admin Mode',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: TrainerProfileService.instance,
          builder: (context, _) {
            final service = TrainerProfileService.instance;
            final isApproved = service.isApproved;
            final isRejected = service.isRejected;
            final hasPhoto = service.photoPath != null && File(service.photoPath!).existsSync();
            final hasCert = service.certificatePath != null && File(service.certificatePath!).existsSync();

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // ── Decision Status Banner ──
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isApproved
                          ? const Color(0xFFE8F5E9)
                          : isRejected
                              ? const Color(0xFFFFEBEE)
                              : const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isApproved
                            ? const Color(0xFF4CAF50)
                            : isRejected
                                ? const Color(0xFFE53935)
                                : const Color(0xFFFFB300),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isApproved
                                ? const Color(0xFF2E7D32)
                                : isRejected
                                    ? const Color(0xFFC62828)
                                    : const Color(0xFFE65100),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isApproved
                                ? Icons.verified_rounded
                                : isRejected
                                    ? Icons.cancel_rounded
                                    : Iconsax.clock,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isApproved
                                    ? 'Status: Approved'
                                    : isRejected
                                        ? 'Status: Rejected'
                                        : 'Status: Pending Admin Decision',
                                style: TextStyle(
                                  fontFamily: 'Syne',
                                  fontSize: (14.5 * sf).clamp(13.0, 16.0),
                                  fontWeight: FontWeight.w700,
                                  color: isApproved
                                      ? const Color(0xFF1B5E20)
                                      : isRejected
                                          ? const Color(0xFFB71C1C)
                                          : const Color(0xFFE65100),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isApproved
                                    ? 'Coach is authorized to accept clients and deliver sessions.'
                                    : isRejected
                                        ? 'Application rejected: ${service.adminNotes ?? "Incomplete credentials"}'
                                        : 'Review submitted credentials below and choose to Approve or Reject.',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: (11.5 * sf).clamp(10.0, 13.0),
                                  color: kDark.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Coach Identity Card ──
                  Text(
                    'Coach Identity & Details',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (14.5 * sf).clamp(13.0, 16.5),
                      fontWeight: FontWeight.w700,
                      color: kDark,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kField,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: hasPhoto
                                  ? () => _showImageDialog(
                                        context,
                                        service.photoPath!,
                                        'Coach Live Photo - ${service.fullName ?? ""}',
                                      )
                                  : null,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: kDark,
                                      border: Border.all(color: kLime, width: 2),
                                    ),
                                    child: ClipOval(
                                      child: hasPhoto
                                          ? Image.file(
                                              File(service.photoPath!),
                                              fit: BoxFit.cover,
                                            )
                                          : const Icon(Iconsax.user, color: kLime, size: 30),
                                    ),
                                  ),
                                  if (hasPhoto)
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: kDark,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Iconsax.eye, color: kLime, size: 10),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    service.fullName ?? 'Coach (Name Pending)',
                                    style: TextStyle(
                                      fontFamily: 'Syne',
                                      fontSize: (16.0 * sf).clamp(14.0, 18.0),
                                      fontWeight: FontWeight.w700,
                                      color: kDark,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Mobile: ${service.mobileNumber ?? "Not provided"}',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: (12.0 * sf).clamp(10.5, 13.0),
                                      color: kGrey,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Age: ${service.age != null ? "${service.age} Years" : "Not specified"}',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: (12.0 * sf).clamp(10.5, 13.0),
                                      color: kGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24, color: kBorder),
                        _AdminRow(
                          label: 'Gym / Fitness Studio',
                          value: service.gymName ?? 'Not specified',
                          icon: Iconsax.building,
                          sf: sf,
                        ),
                        const SizedBox(height: 10),
                        _AdminRow(
                          label: 'Working Since',
                          value: service.sinceWhen ?? 'Not specified',
                          icon: Iconsax.clock,
                          sf: sf,
                        ),
                        const SizedBox(height: 10),
                        _AdminRow(
                          label: 'Experience',
                          value: service.experience,
                          icon: Iconsax.award,
                          sf: sf,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Certification Review Section ──
                  Text(
                    'Uploaded Certification',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (14.5 * sf).clamp(13.0, 16.5),
                      fontWeight: FontWeight.w700,
                      color: kDark,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: hasCert ? kLime : kBorder,
                        width: hasCert ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: hasCert
                        ? Row(
                            children: [
                              GestureDetector(
                                onTap: () => _showImageDialog(
                                  context,
                                  service.certificatePath!,
                                  'Coach Certificate Document',
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(service.certificatePath!),
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.verified_rounded, size: 14, color: Color(0xFF2E7D32)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Certificate Attached',
                                          style: TextStyle(
                                            fontFamily: 'Syne',
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF2E7D32),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      service.certificatePath!.split('/').last,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: kDark,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Tap image to enlarge document',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        color: kGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => _showImageDialog(
                                  context,
                                  service.certificatePath!,
                                  'Coach Certificate Document',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kDark,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text(
                                  'View',
                                  style: TextStyle(
                                    fontFamily: 'Syne',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: kLime,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: const [
                              Icon(Iconsax.document_text, size: 28, color: kGrey),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'No certification document uploaded (Optional).',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12.5,
                                    color: kGrey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 20),

                  // ── Specializations & Philosophy ──
                  Text(
                    'Specialties & Coaching Philosophy',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (14.5 * sf).clamp(13.0, 16.5),
                      fontWeight: FontWeight.w700,
                      color: kDark,
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kField,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: service.specialties.map((s) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: kDark,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                s,
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '"${service.philosophy}"',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: (12.0 * sf).clamp(10.5, 13.0),
                            fontStyle: FontStyle.italic,
                            color: kDark,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Admin Decision Actions ──
                  Text(
                    'Admin Decision',
                    style: TextStyle(
                      fontFamily: 'Syne',
                      fontSize: (14.5 * sf).clamp(13.0, 16.5),
                      fontWeight: FontWeight.w700,
                      color: kDark,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      // Reject Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmReject(context),
                          icon: const Icon(Icons.cancel_rounded, size: 18, color: Color(0xFFE53935)),
                          label: const Text(
                            'Reject',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE53935),
                              fontSize: 13,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE53935)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Approve Button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            HapticFeedback.heavyImpact();
                            await TrainerProfileService.instance.approveByAdmin(
                              notes: 'Approved by Admin Team. Verified coaching identity.',
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Coach approved! Eligible to deliver service on TrainZ.',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Color(0xFF2E7D32),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.check_circle_rounded, size: 18, color: kDark),
                          label: const Text(
                            'Approve Application',
                            style: TextStyle(
                              fontFamily: 'Syne',
                              fontWeight: FontWeight.w800,
                              color: kDark,
                              fontSize: 13,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kLime,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Reset to Pending (For testing & demonstration)
                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        await TrainerProfileService.instance.resetToPending();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Application reset to Pending Review.',
                                style: TextStyle(fontFamily: 'Poppins'),
                              ),
                              backgroundColor: Color(0xFF424242),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 15, color: kGrey),
                      label: const Text(
                        'Reset Application to Pending (Demo)',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: kGrey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AdminRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final double sf;

  const _AdminRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.sf,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: kDark),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: (11.5 * sf).clamp(10.0, 12.5),
            color: kGrey,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: (12.0 * sf).clamp(10.5, 13.0),
              fontWeight: FontWeight.w700,
              color: kDark,
            ),
          ),
        ),
      ],
    );
  }
}
