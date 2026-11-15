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

/// TRAIN Z Premium Animated Motion-Graphics Splash Screen.
/// Features a bespoke sequential letter-by-letter entrance for the TRAIN Z wordmark,
/// mathematically centered logo alignment, refined kinetic accent line, and
/// seamless authentication state resolution with zero cartoonish bounce or lag.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

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

    // 1700ms total duration: crisp, athletic, and respectful of user's time
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
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
    // Dwell for the animation duration so the brand reveal can be appreciated
    await Future.delayed(const Duration(milliseconds: 1750));
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
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  // ─── Individual Letter Animator ─────────────────────────────────────────────
  Widget _buildAnimatedLetter({
    required String char,
    required int index,
    required double sf,
    required Color color,
    required double controllerValue,
    required bool reduceMotion,
  }) {
    final double letterFontSize = (36.0 * sf).clamp(30.0, 44.0);

    if (reduceMotion) {
      return Text(
        char,
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: letterFontSize,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.1,
        ),
      );
    }

    // Staggered sequential entry windows:
    // Letter 0 (T): 0.20 - 0.36
    // Letter 1 (R): 0.26 - 0.42
    // Letter 2 (A): 0.32 - 0.48
    // Letter 3 (I): 0.38 - 0.54
    // Letter 4 (N): 0.44 - 0.60
    // Letter 5 (Z): 0.52 - 0.70  (intentional slight pause before the accent Z)
    final double start = 0.20 + (index * 0.06) + (index == 5 ? 0.02 : 0.0);
    final double end = (start + 0.17).clamp(0.0, 1.0);

    final double rawT = ((controllerValue - start) / (end - start)).clamp(0.0, 1.0);

    // Athletic spring curve with restrained settling
    const athleticCurve = Cubic(0.25, 1.18, 0.42, 1.0);
    final double easedT = athleticCurve.transform(rawT);

    // Motion attributes:
    // 1. Vertical translation: +24px below baseline -> 0.0px with natural micro-settle
    final double translateY = (1.0 - easedT) * 24.0;
    // 2. Scale: 0.82 -> 1.0
    final double scale = 0.82 + (easedT * 0.18);
    // 3. Opacity: fast linear fade-in over the first 65% of the letter's interval
    final double opacity = (rawT / 0.65).clamp(0.0, 1.0);

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Transform.scale(
          scale: scale,
          child: Text(
            char,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: letterFontSize,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Kinetic Hairline Accent ────────────────────────────────────────────────
  Widget _buildKineticAccentLine(double controllerValue, double sf, bool reduceMotion) {
    final double targetWidth = (120.0 * sf).clamp(90.0, 150.0);

    if (reduceMotion) {
      return Container(
        width: targetWidth,
        height: 1.5,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(1),
          gradient: const LinearGradient(
            colors: [
              Colors.transparent,
              Color(0xCCFF00CC), // subtle volt
              Color(0xFFCCFF00),
              Colors.white,
              Color(0xFFCCFF00),
              Color(0xCCFF00CC),
              Colors.transparent,
            ],
            stops: [0.0, 0.2, 0.4, 0.5, 0.6, 0.8, 1.0],
          ),
        ),
      );
    }

    // Line expands outward from center as letter Z lands: 0.68 - 0.86
    const double start = 0.68;
    const double end = 0.86;
    final double rawT = ((controllerValue - start) / (end - start)).clamp(0.0, 1.0);
    final double eased = Curves.easeOutCubic.transform(rawT);

    final double currentWidth = targetWidth * eased;
    final double opacity = (rawT / 0.50).clamp(0.0, 1.0);

    if (currentWidth <= 0.0) {
      return const SizedBox(height: 1.5);
    }

    return Opacity(
      opacity: opacity,
      child: Container(
        width: currentWidth,
        height: 1.5,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(1),
          gradient: const LinearGradient(
            colors: [
              Colors.transparent,
              Color(0x80CCFF00),
              Color(0xFFCCFF00),
              Colors.white,
              Color(0xFFCCFF00),
              Color(0x80CCFF00),
              Colors.transparent,
            ],
            stops: [0.0, 0.2, 0.4, 0.5, 0.6, 0.8, 1.0],
          ),
        ),
      ),
    );
  }

  // ─── Subtitle Tagline ───────────────────────────────────────────────────────
  Widget _buildSubtitle(double controllerValue, double sf, bool reduceMotion) {
    final double subtitleFontSize = (10.0 * sf).clamp(9.0, 11.5);

    if (reduceMotion) {
      return Text(
        'PREMIUM PERSONAL TRAINING',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Outfit',
          fontSize: subtitleFontSize,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF8E8E93),
          letterSpacing: 2.5,
        ),
      );
    }

    // Subtitle entrance: 0.74 - 0.90
    const double start = 0.74;
    const double end = 0.90;
    final double rawT = ((controllerValue - start) / (end - start)).clamp(0.0, 1.0);
    final double eased = Curves.easeOutCubic.transform(rawT);

    final double opacity = rawT;
    final double translateY = (1.0 - eased) * 10.0;

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Text(
          'PREMIUM PERSONAL TRAINING',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: subtitleFontSize,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF8E8E93),
            letterSpacing: 2.5,
          ),
        ),
      ),
    );
  }

  // ─── Monogram Badge ────────────────────────────────────────────────────────
  Widget _buildMonogram(double controllerValue, double sf, bool reduceMotion) {
    final double size = (54.0 * sf).clamp(46.0, 64.0);
    final double zSize = (28.0 * sf).clamp(24.0, 34.0);

    if (reduceMotion) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF14171A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.2,
          ),
        ),
        child: Center(
          child: Text(
            'Z',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: zSize,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFCCFF00),
            ),
          ),
        ),
      );
    }

    // Monogram entrance: 0.04 - 0.24
    const double start = 0.04;
    const double end = 0.24;
    final double rawT = ((controllerValue - start) / (end - start)).clamp(0.0, 1.0);
    final double eased = Curves.easeOutCubic.transform(rawT);

    final double opacity = rawT;
    final double scale = 0.78 + (eased * 0.22);
    final double translateY = (1.0 - eased) * 14.0;

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFF14171A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFCCFF00).withValues(alpha: 0.06 * eased),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                'Z',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: zSize,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFCCFF00),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final double w = mq.size.width;
    final double h = mq.size.height;
    final double sf = (w / 360).clamp(0.75, 1.3);
    final bool reduceMotion = mq.disableAnimations;

    final double letterSpacing = (3.5 * sf).clamp(2.5, 5.0);
    final double wordSpacing = (13.0 * sf).clamp(10.0, 18.0);

    return Scaffold(
      backgroundColor: AppTheme.pureBlack,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // ── 1. Subtle Luxury Ambient Radial Glow (Centered) ──
          Positioned(
            top: h * 0.26,
            left: 0,
            right: 0,
            height: h * 0.38,
            child: Center(
              child: Container(
                width: w * 0.75,
                height: w * 0.75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFCCFF00).withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.75],
                  ),
                ),
              ),
            ),
          ),

          // ── 2. Intended Branding Area: Mathematically Absolute Center ──
          Center(
            child: SizedBox(
              width: double.infinity,
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, _) {
                  final double val = _animController.value;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Monogram Logo Badge
                      _buildMonogram(val, sf, reduceMotion),

                      SizedBox(height: (h * 0.022).clamp(14.0, 22.0)),

                      // TRAIN Z Wordmark with Staggered Sequential Letter Animation
                      Semantics(
                        label: 'TRAIN Z',
                        header: true,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Semantic text anchor ensuring screen readers and tests find the brand name
                            const Opacity(
                              opacity: 0.0,
                              child: Text(
                                'TRAIN Z',
                                style: TextStyle(fontSize: 1),
                              ),
                            ),
                            // Symmetrical, perfectly centered letter-by-letter row
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                _buildAnimatedLetter(
                                  char: 'T',
                                  index: 0,
                                  sf: sf,
                                  color: Colors.white,
                                  controllerValue: val,
                                  reduceMotion: reduceMotion,
                                ),
                                SizedBox(width: letterSpacing),
                                _buildAnimatedLetter(
                                  char: 'R',
                                  index: 1,
                                  sf: sf,
                                  color: Colors.white,
                                  controllerValue: val,
                                  reduceMotion: reduceMotion,
                                ),
                                SizedBox(width: letterSpacing),
                                _buildAnimatedLetter(
                                  char: 'A',
                                  index: 2,
                                  sf: sf,
                                  color: Colors.white,
                                  controllerValue: val,
                                  reduceMotion: reduceMotion,
                                ),
                                SizedBox(width: letterSpacing),
                                _buildAnimatedLetter(
                                  char: 'I',
                                  index: 3,
                                  sf: sf,
                                  color: Colors.white,
                                  controllerValue: val,
                                  reduceMotion: reduceMotion,
                                ),
                                SizedBox(width: letterSpacing),
                                _buildAnimatedLetter(
                                  char: 'N',
                                  index: 4,
                                  sf: sf,
                                  color: Colors.white,
                                  controllerValue: val,
                                  reduceMotion: reduceMotion,
                                ),
                                SizedBox(width: wordSpacing),
                                _buildAnimatedLetter(
                                  char: 'Z',
                                  index: 5,
                                  sf: sf,
                                  color: const Color(0xFFCCFF00),
                                  controllerValue: val,
                                  reduceMotion: reduceMotion,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Restrained Kinetic Accent Hairline Line
                      _buildKineticAccentLine(val, sf, reduceMotion),

                      const SizedBox(height: 12),

                      // Luxury Subtitle Tagline
                      _buildSubtitle(val, sf, reduceMotion),
                    ],
                  );
                },
              ),
            ),
          ),

          // ── 3. Bottom Action Area: Positioned independently at screen bottom ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  (w * 0.08).clamp(20.0, 36.0),
                  0,
                  (w * 0.08).clamp(20.0, 36.0),
                  (h * 0.025 * sf).clamp(16.0, 26.0),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: _isCheckingAuth
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          height: (54.0 * sf).clamp(48.0, 60.0),
                          child: Center(
                            child: SizedBox(
                              width: 44,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: const LinearProgressIndicator(
                                  minHeight: 2.2,
                                  backgroundColor: Color(0xFF222222),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFFCCFF00),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      : SizedBox(
                          key: const ValueKey('get_started'),
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
                                    fontFamily: 'Outfit',
                                    fontSize: (14.5 * sf).clamp(13.0, 16.0),
                                    fontWeight: FontWeight.w500,
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}
