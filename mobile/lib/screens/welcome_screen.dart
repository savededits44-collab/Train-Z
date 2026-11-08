import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../theme/app_theme.dart';

/// Trainuspro Landing / Welcome Screen
/// Elegant Black & White corporate portal for Athletes & Trainers
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pureBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Brand Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.borderSubtle),
                          color: AppTheme.surfaceBlack,
                        ),
                        child: const Icon(
                          Iconsax.weight,
                          color: AppTheme.pureWhite,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: 'TRAIN',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.0,
                                color: AppTheme.pureWhite,
                              ),
                            ),
                            TextSpan(
                              text: 'US',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 2.0,
                                color: AppTheme.mutedWhite,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.pureWhite,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: AppTheme.pureBlack,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.borderDark),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Iconsax.verify,
                          size: 12,
                          color: AppTheme.pureWhite,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'CERTIFIED',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.0,
                            color: AppTheme.mutedWhite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // Hero Corporate Headline
              const Text(
                'ELEVATE YOUR\nPERFORMANCE',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: 1.5,
                  color: AppTheme.pureWhite,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'The premier network connecting goal-driven clients with world-class certified fitness coaches.',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  height: 1.6,
                  color: AppTheme.slateGrey,
                ),
              ),

              const Spacer(flex: 3),

              // Dual Portal Cards: Athlete vs Trainer
              _PortalCard(
                icon: Iconsax.activity,
                title: 'Continue as Athlete',
                subtitle: 'Find elite trainers, customized plans & 1-on-1 coaching',
                isPrimary: true,
                onTap: () {},
              ),
              const SizedBox(height: 14),
              _PortalCard(
                icon: Iconsax.profile_2user,
                title: 'Continue as Trainer',
                subtitle: 'Manage roster, client metrics, schedule & earnings',
                isPrimary: false,
                onTap: () {},
              ),

              const Spacer(flex: 2),

              // Bottom Security & Compliance Note
              const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Iconsax.shield_tick,
                      size: 14,
                      color: AppTheme.darkGrey,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'SECURE END-TO-END ATHLETIC PLATFORM',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                        color: AppTheme.darkGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortalCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isPrimary;
  final VoidCallback onTap;

  const _PortalCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.pureWhite : AppTheme.surfaceBlack,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary ? AppTheme.pureWhite : AppTheme.borderDark,
            width: 1.2,
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPrimary ? AppTheme.pureBlack : AppTheme.elevatedSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isPrimary ? AppTheme.pureWhite : AppTheme.mutedWhite,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isPrimary ? AppTheme.pureBlack : AppTheme.pureWhite,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: isPrimary
                          ? AppTheme.pureBlack.withValues(alpha: 0.7)
                          : AppTheme.slateGrey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Iconsax.arrow_right_3,
              size: 18,
              color: isPrimary ? AppTheme.pureBlack : AppTheme.mutedWhite,
            ),
          ],
        ),
      ),
    );
  }
}
