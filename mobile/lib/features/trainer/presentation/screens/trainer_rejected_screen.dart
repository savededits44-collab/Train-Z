import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../shared/models/trainer_profile_model.dart';
import '../../../../widgets/app_widgets.dart';
import '../../controllers/trainer_auth_controller.dart';
import 'trainer_login_screen.dart';

class TrainerRejectedScreen extends StatelessWidget {
  final TrainerProfileModel profile;

  const TrainerRejectedScreen({
    super.key,
    required this.profile,
  });

  Future<void> _handleSignOut(BuildContext context) async {
    final controller = TrainerAuthController();
    await controller.signOut();
    controller.dispose();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TrainerLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final hPad = (w * 0.072).clamp(18.0, 32.0);

    final reasonText = profile.adminReviewNotes != null &&
            profile.adminReviewNotes!.trim().isNotEmpty
        ? profile.adminReviewNotes!.trim()
        : 'The submitted qualifications or experience could not be verified in accordance with platform quality standards.';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => _handleSignOut(context),
            icon: const Icon(Iconsax.logout, size: 16, color: kGrey),
            label: const Text(
              'Sign Out',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: kGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: (h * 0.03 * sf).clamp(16.0, 40.0)),

              // Rejected Icon Container
              Container(
                width: (84.0 * sf).clamp(72.0, 100.0),
                height: (84.0 * sf).clamp(72.0, 100.0),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFCDD2),
                    width: 2.0,
                  ),
                ),
                child: const Icon(
                  Iconsax.close_circle,
                  color: Color(0xFFD32F2F),
                  size: 42,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Application Not Approved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (26.0 * sf).clamp(22.0, 32.0),
                  fontWeight: FontWeight.w800,
                  color: kDark,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Thank you for your interest in joining the TRAIN Z Trainer Network. After careful review, our administration team could not approve your application at this time.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (13.0 * sf).clamp(11.5, 14.0),
                  color: kGrey,
                  height: 1.4,
                ),
              ),

              SizedBox(height: (h * 0.035 * sf).clamp(20.0, 36.0)),

              // Reason / Explanation Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'REVIEW DECISION',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD32F2F),
                            letterSpacing: 0.8,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'REJECTED',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD32F2F),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    const Text(
                      'Explanation / Feedback:',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      reasonText,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (12.5 * sf).clamp(11.5, 13.5),
                        color: const Color(0xFF424242),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: (h * 0.03 * sf).clamp(16.0, 28.0)),

              // Next Steps Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kField,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Next Steps & Appeals:',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '1. Review certificate and qualification guidelines.\n2. If you believe this decision was made in error or have updated credentials to provide, please contact our administrative team directly.\n3. Send an email with your application email to trainers@trainz.app.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: (12.0 * sf).clamp(11.0, 13.0),
                        color: const Color(0xFF424242),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: (h * 0.04 * sf).clamp(24.0, 36.0)),

              AppPrimaryButton(
                label: 'Sign Out & Return Home',
                onTap: () => _handleSignOut(context),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

