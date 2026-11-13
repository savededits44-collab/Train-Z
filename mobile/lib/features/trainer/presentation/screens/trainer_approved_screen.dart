import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../../../screens/trainer/trainer_dashboard.dart';
import '../../../../shared/models/trainer_profile_model.dart';
import '../../../../widgets/app_widgets.dart';

class TrainerApprovedScreen extends StatelessWidget {
  final TrainerProfileModel profile;

  const TrainerApprovedScreen({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final sf = scaleFactor(context);
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final hPad = (w * 0.072).clamp(18.0, 32.0);

    final isAdvanced = profile.category == TrainerCategory.advancedTrainer;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: (h * 0.04 * sf).clamp(24.0, 54.0)),

              // Success/Approved Graphic
              Container(
                width: (88.0 * sf).clamp(76.0, 104.0),
                height: (88.0 * sf).clamp(76.0, 104.0),
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
                  Iconsax.verify,
                  color: kLime,
                  size: 46,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Application Approved!',
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
                'Congratulations! Your credentials have been verified by TRAIN Z administrators.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (13.5 * sf).clamp(12.0, 14.5),
                  color: kGrey,
                  height: 1.4,
                ),
              ),

              SizedBox(height: (h * 0.035 * sf).clamp(20.0, 36.0)),

              // Tier & Privileges Card
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'PARTNER STATUS',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: kGrey,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA5D6A7)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 12,
                                color: Color(0xFF2E7D32),
                              ),
                              SizedBox(width: 4),
                              Text(
                                'ACTIVE & APPROVED',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _buildFeatureLine(
                      'Verified Category',
                      profile.category.displayName,
                    ),
                    const Divider(height: 20),
                    _buildFeatureLine(
                      'Coaching Privileges',
                      isAdvanced
                          ? 'Custom Plans & Flexible Rates'
                          : 'Standard Platform Packages',
                    ),
                  ],
                ),
              ),

              SizedBox(height: (h * 0.04 * sf).clamp(24.0, 42.0)),

              AppPrimaryButton(
                label: 'Go to Trainer Dashboard',
                onTap: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => TrainerDashboard(trainerId: profile.uid),
                    ),
                    (route) => false,
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

  Widget _buildFeatureLine(String label, String value) {
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
}
