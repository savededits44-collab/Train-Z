import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../features/trainer/trainer_feature.dart';
import '../../widgets/app_widgets.dart';
import '../admin/admin_trainer_review_screen.dart';
import 'client_onboarding.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  // 0 = Client/Athlete, 1 = Coach/Trainer
  int _selectedRole = 0;

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
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: (h * 0.035 * sf).clamp(20.0, 44.0)),
              const AppLogo(fontSize: 16),
              SizedBox(height: (h * 0.035 * sf).clamp(18.0, 36.0)),
              Text(
                'Tell us who\nyou are.',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: (30.0 * sf).clamp(24.0, 38.0),
                  fontWeight: FontWeight.w800,
                  color: kDark,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you want to use Trainuspro to tailor your experience.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: (13.0 * sf).clamp(11.0, 14.0),
                  color: kGrey,
                ),
              ),
              SizedBox(height: (h * 0.04 * sf).clamp(24.0, 44.0)),

              // Card 1: Athlete / Client
              _RoleOptionCard(
                title: 'Athlete / Client',
                subtitle:
                    'Find top trainers, schedule sessions & track your personal fitness progress.',
                icon: Iconsax.user,
                selected: _selectedRole == 0,
                onTap: () => setState(() => _selectedRole = 0),
                sf: sf,
              ),

              SizedBox(height: (14.0 * sf).clamp(10.0, 18.0)),

              // Card 2: Personal Trainer
              _RoleOptionCard(
                title: 'Personal Trainer',
                subtitle:
                    'Train clients, manage bookings & grow your personal training career.',
                icon: Iconsax.teacher,
                selected: _selectedRole == 1,
                onTap: () => setState(() => _selectedRole = 1),
                sf: sf,
              ),

              SizedBox(height: (h * 0.06 * sf).clamp(32.0, 60.0)),

              AppPrimaryButton(
                label: 'Continue',
                onTap: () {
                  if (_selectedRole == 1) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const TrainerRegisterScreen(),
                      ),
                    );
                  } else {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const ClientOnboardingScreen(),
                      ),
                    );
                  }
                },
              ),

              SizedBox(height: (14.0 * sf).clamp(10.0, 18.0)),

              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminTrainerReviewScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.shield_rounded, size: 15, color: kGrey),
                  label: const Text(
                    'Admin Portal (Trainer Approvals)',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kGrey,
                    ),
                  ),
                ),
              ),

              SizedBox(height: (h * 0.02 * sf).clamp(12.0, 24.0)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final double sf;

  const _RoleOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    required this.sf,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: EdgeInsets.all((16.0 * sf).clamp(12.0, 20.0)),
        decoration: BoxDecoration(
          color: selected ? kDark : kField,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? kDark : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: (42.0 * sf).clamp(34.0, 48.0),
              height: (42.0 * sf).clamp(34.0, 48.0),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF222222) : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: (20.0 * sf).clamp(16.0, 24.0),
                color: selected ? kLime : kDark,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Syne',
                            fontSize: (14.5 * sf).clamp(12.5, 16.5),
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : kDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        selected ? Iconsax.tick_circle : Iconsax.record,
                        size: (18.0 * sf).clamp(15.0, 20.0),
                        color: selected ? kLime : const Color(0xFFCCCCCC),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: (11.5 * sf).clamp(9.5, 12.5),
                      color: selected
                          ? Colors.white.withValues(alpha: 0.65)
                          : kGrey,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
