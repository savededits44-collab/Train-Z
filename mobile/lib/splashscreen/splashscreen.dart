import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../features/client/presentation/screens/client_home_screen.dart';
import '../features/client/presentation/screens/client_profile_setup_screen.dart';
import '../features/trainer/presentation/screens/trainer_pending_approval_screen.dart';
import '../features/trainer/presentation/screens/trainer_rejected_screen.dart';
import '../screens/onboarding/role_selection_screen.dart';
import '../screens/trainer/trainer_dashboard.dart';
import '../services/auth_service.dart';
import '../services/trainer_profile_service.dart';
import '../shared/models/trainer_profile_model.dart';
import '../theme/app_theme.dart';

/// TRAIN Z Premium Minimal Splash Screen.
/// Delivers an elegant luxury entrance experience with subtle brand reveal animation,
/// seamless authentication state resolution, and zero playful/casual clutter.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  bool _navigated = false;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: AppTheme.pureBlack,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.94,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _animController.forward();
    _resolveAuthState();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _resolveAuthState() async {
    // Minimum elegant dwell time for brand appreciation
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted || _navigated) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profile = await AuthService().getUserProfile(user.uid);
        final role = profile?['role'] as String?;
        final isOnboarded = profile?['onboarded'] == true || profile?['isOnboarded'] == true;

        if (!mounted || _navigated) return;

        if (isOnboarded && role != null) {
          if (role.toLowerCase() == 'trainer') {
            final prof = await AuthService().getTrainerProfile(user.uid);
            if (!mounted || _navigated) return;
            _navigated = true;

            if (prof == null || prof.verificationStatus == TrainerVerificationStatus.pending) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const TrainerPendingApprovalScreen()),
              );
            } else if (prof.verificationStatus == TrainerVerificationStatus.rejected) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => TrainerRejectedScreen(profile: prof)),
              );
            } else {
              TrainerProfileService.instance.populateFromModel(prof);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => TrainerDashboard(trainerId: user.uid)),
              );
            }
            return;
          }

          _navigated = true;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ClientHomeScreen()),
          );
          return;
        } else if (role?.toLowerCase() == 'client') {
          _navigated = true;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ClientProfileSetupScreen()),
          );
          return;
        }
      }
    } catch (e) {
      debugPrint('SplashScreen auth resolution notice: $e');
    }

    if (mounted && !_navigated) {
      setState(() => _isCheckingAuth = false);
    }
  }

  void _onGetStarted() {
    if (_navigated || !mounted) return;
    _navigated = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, anim, secondaryAnim) =>
            const RoleSelectionScreen(),
        transitionsBuilder: (context, anim, secondaryAnim, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final double w = mq.size.width;
    final double h = mq.size.height;
    final double sf = (w / 360).clamp(0.75, 1.3);

    final double subtitleFontSize = (10.5 * sf).clamp(9.5, 12.0);

    return Scaffold(
      backgroundColor: AppTheme.pureBlack,
      body: Stack(
        children: [
          // ── Subtle Luxury Ambient Glow ──
          Positioned(
            top: h * 0.25,
            left: w * 0.15,
            right: w * 0.15,
            height: h * 0.4,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFCCFF00).withValues(alpha: 0.07),
                      const Color(0xFF101010).withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: (w * 0.08).clamp(20.0, 36.0),
              ),
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // ── Elegant Brand Reveal Animation ──
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Minimal Monogram / Icon Accent
                            Container(
                              width: (54.0 * sf).clamp(46.0, 64.0),
                              height: (54.0 * sf).clamp(46.0, 64.0),
                              decoration: BoxDecoration(
                                color: const Color(0xFF14171A),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.10),
                                  width: 1.2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Z',
                                  style: TextStyle(
                                    fontFamily: 'Syne',
                                    fontSize: (28.0 * sf).clamp(24.0, 34.0),
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFFCCFF00),
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: (h * 0.024).clamp(16.0, 24.0)),

                            // Brand Typography: TRAIN Z
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'TRAIN ',
                                      style: TextStyle(
                                        fontFamily: 'Syne',
                                        fontSize: (38.0 * sf).clamp(32.0, 44.0),
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'Z',
                                      style: TextStyle(
                                        fontFamily: 'Syne',
                                        fontSize: (38.0 * sf).clamp(32.0, 44.0),
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFFCCFF00),
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Subtitle Tagline
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'PREMIUM PERSONAL TRAINING',
                                maxLines: 1,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: subtitleFontSize,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF8E8E93),
                                  letterSpacing: 2.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // ── Action / Minimal Loading Indicator ──
                  if (_isCheckingAuth) ...[
                    // Sleek Minimalist Loading Indicator
                    SizedBox(
                      width: 48,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: const LinearProgressIndicator(
                          minHeight: 2.5,
                          backgroundColor: Color(0xFF222222),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFCCFF00),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ] else ...[
                    // Premium Get Started Button for New / Guest Users
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SizedBox(
                        width: double.infinity,
                        height: (54.0 * sf).clamp(48.0, 60.0),
                        child: ElevatedButton(
                          onPressed: _onGetStarted,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.pureBlack,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Get Started',
                                style: TextStyle(
                                  fontFamily: 'Syne',
                                  fontSize: (14.5 * sf).clamp(13.0, 16.0),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: AppTheme.pureBlack,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Iconsax.arrow_right_1,
                                size: 17,
                                color: AppTheme.pureBlack,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: (h * 0.02 * sf).clamp(16.0, 24.0)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
