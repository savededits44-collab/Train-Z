import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../shared/models/trainer_profile_model.dart';
import '../../../../widgets/app_widgets.dart';
import 'trainer_email_verification_screen.dart';

class TrainerRegistrationSuccessScreen extends StatelessWidget {
  final String fullName;
  final String email;
  final TrainerCategory category;
  final double experienceYears;

  const TrainerRegistrationSuccessScreen({
    super.key,
    required this.fullName,
    required this.email,
    required this.category,
    required this.experienceYears,
  });

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final hPad = (w * 0.072).clamp(18.0, 32.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: (h * 0.04 * sf).clamp(20.0, 50.0)),

              // Success Icon Container
              Container(
                width: (80.0 * sf).clamp(70.0, 96.0),
                height: (80.0 * sf).clamp(70.0, 96.0),
                decoration: BoxDecoration(
                  color: kDark,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Iconsax.tick_circle,
                  color: kLime,
                  size: 40,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Application Received!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (26.0 * sf).clamp(22.0, 32.0),
                  fontWeight: FontWeight.w800,
                  color: kDark,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Welcome, $fullName. Your trainer application has been submitted to the TRAIN Z administration network.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (13.5 * sf).clamp(12.0, 14.5),
                  color: kGrey,
                  height: 1.4,
                ),
              ),

              SizedBox(height: (h * 0.035 * sf).clamp(20.0, 36.0)),

              // Application Summary Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: kField,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'APPLICATION DETAILS',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kGrey,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Registered Email', email),
                    const Divider(height: 18),
                    _buildInfoRow('Applied Category', category.displayName),
                    if (category == TrainerCategory.advancedTrainer) ...[
                      const Divider(height: 18),
                      _buildInfoRow(
                        'Reported Experience',
                        '${experienceYears.toStringAsFixed(1)} Years',
                      ),
                    ],
                    const Divider(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Initial Status',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            color: kGrey,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFB74D)),
                          ),
                          child: const Text(
                            'PENDING APPROVAL',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: (h * 0.03 * sf).clamp(18.0, 30.0)),

              // Next Steps Checklist
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Next Steps for Activation:',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStepItem(
                      step: '1',
                      title: 'Verify Your Email',
                      desc:
                          'A verification link has been sent to your email. You must verify ownership to proceed.',
                    ),
                    const SizedBox(height: 10),
                    _buildStepItem(
                      step: '2',
                      title: 'Admin Verification Review',
                      desc:
                          'Our team reviews qualifications and background credentials. Status remains PENDING during this stage.',
                    ),
                    const SizedBox(height: 10),
                    _buildStepItem(
                      step: '3',
                      title: 'Activation & Dashboard Access',
                      desc:
                          'Once approved, full access to coach management and sessions will be unlocked.',
                    ),
                  ],
                ),
              ),

              SizedBox(height: (h * 0.04 * sf).clamp(24.0, 40.0)),

              AppPrimaryButton(
                label: 'Proceed to Email Verification',
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => TrainerEmailVerificationScreen(email: email),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.5,
            color: kGrey,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: kDark,
          ),
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required String step,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: kDark,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kLime,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: kDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.5,
                  color: kGrey,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
