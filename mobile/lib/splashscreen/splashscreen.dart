import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../screens/onboarding/role_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    // Continuous loop for playful bounce, blinking and floating stars
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onStartTransformation() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, anim, secondaryAnim) => const RoleSelectionScreen(),
        transitionsBuilder: (context, anim, secondaryAnim, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 450),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final double w = mq.size.width;
    final double h = mq.size.height;
    final double sf = (w / 360).clamp(0.75, 1.3);

    final double hPad = (w * 0.075).clamp(20.0, 32.0);
    final double graphicSize = (h * 0.32).clamp(190.0, 280.0);
    final double brandFontSize = (38.0 * sf).clamp(32.0, 46.0);
    final double btnHeight = (56.0 * sf).clamp(50.0, 62.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // ── Playful Animated Fitness Mascot ──
              AnimatedBuilder(
                animation: _animController,
                builder: (context, _) {
                  return SizedBox(
                    width: graphicSize,
                    height: graphicSize,
                    child: CustomPaint(
                      painter: _PlayfulFitnessMascotPainter(
                        progress: _animController.value,
                      ),
                    ),
                  );
                },
              ),

              SizedBox(height: (h * 0.02 * sf).clamp(16.0, 28.0)),

              // ── Brand Name: TrainZ ──
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Train',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: brandFontSize,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111111),
                        letterSpacing: 1.2,
                      ),
                    ),
                    TextSpan(
                      text: 'Z',
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: brandFontSize,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFB2FF59),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 3),

              // ── Start Transformation Button ──
              SizedBox(
                width: double.infinity,
                height: btnHeight,
                child: ElevatedButton(
                  onPressed: _onStartTransformation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: (18.0 * sf).clamp(14.0, 22.0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Start Transformation',
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: (14.5 * sf).clamp(13.0, 16.5),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: (28.0 * sf).clamp(24.0, 32.0),
                        height: (28.0 * sf).clamp(24.0, 32.0),
                        decoration: const BoxDecoration(
                          color: Color(0xFFB2FF59),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Iconsax.arrow_right_1,
                          size: (15.0 * sf).clamp(13.0, 17.0),
                          color: const Color(0xFF111111),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: (h * 0.03 * sf).clamp(18.0, 32.0)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Playful Animated Fitness Mascot Painter (Pure Canvas, 60/120fps)
// ─────────────────────────────────────────────────────────────────────────────

class _PlayfulFitnessMascotPainter extends CustomPainter {
  final double progress;

  _PlayfulFitnessMascotPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2 - 6;
    final double baseR = size.width * 0.28;

    final double t = progress * 2 * math.pi;

    // Bounce and squash & stretch physics
    final double bounceY = math.sin(t) * 14.0;
    final double squashX = 1.0 + math.cos(t * 2) * 0.04;
    final double squashY = 1.0 - math.cos(t * 2) * 0.04;
    final double tilt = math.sin(t * 0.8) * 0.05;

    // ── 1. Floor Drop Shadow ──
    final double shadowScale = (1.0 - bounceY / 45.0) * squashX;
    final double shadowAlpha = (0.08 + (1.0 - bounceY / 35.0) * 0.06).clamp(0.04, 0.16);
    final Rect shadowRect = Rect.fromCenter(
      center: Offset(cx, cy + baseR * 1.5),
      width: baseR * 2.1 * shadowScale,
      height: baseR * 0.44 * shadowScale,
    );
    final Paint shadowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.fromRGBO(17, 17, 17, shadowAlpha),
          Color.fromRGBO(17, 17, 17, shadowAlpha * 0.35),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(shadowRect);
    canvas.drawOval(shadowRect, shadowPaint);

    // ── 2. Floating Playful Energy Sparks & Stars ──
    _drawStar(
      canvas,
      cx - baseR * 1.35 + math.sin(t * 0.9) * 6,
      cy - baseR * 0.7 + math.cos(t * 0.8) * 7,
      baseR * 0.14,
      const Color(0xFFB2FF59),
      t * 0.4,
    );

    _drawStar(
      canvas,
      cx + baseR * 1.3 + math.cos(t * 0.7) * 7,
      cy - baseR * 0.85 + math.sin(t * 0.9) * 8,
      baseR * 0.16,
      const Color(0xFF111111),
      -t * 0.3,
    );

    _drawStar(
      canvas,
      cx + baseR * 1.2 + math.sin(t) * 5,
      cy + baseR * 0.8 + math.cos(t * 0.6) * 6,
      baseR * 0.12,
      const Color(0xFFB2FF59),
      t * 0.7,
    );

    _drawSparkleDot(
      canvas,
      cx - baseR * 1.15,
      cy + baseR * 0.7 + math.sin(t * 1.1) * 5,
      baseR * 0.05,
      const Color(0xFFB2FF59),
    );

    _drawSparkleDot(
      canvas,
      cx + baseR * 1.45,
      cy + baseR * 0.2 + math.cos(t * 1.2) * 5,
      baseR * 0.045,
      const Color(0xFFCCCCCC),
    );

    // ── 3. Main Character (Kettlebell Hero) ──
    canvas.save();
    canvas.translate(cx, cy + bounceY);
    canvas.rotate(tilt);
    canvas.scale(squashX, squashY);

    // A. Handle (Curved loop on top)
    final handlePaint = Paint()
      ..color = const Color(0xFF191922)
      ..style = PaintingStyle.stroke
      ..strokeWidth = baseR * 0.28
      ..strokeCap = StrokeCap.round;

    final Path handlePath = Path()
      ..arcTo(
        Rect.fromCenter(
          center: Offset(0, -baseR * 0.68),
          width: baseR * 1.15,
          height: baseR * 1.1,
        ),
        math.pi * 1.12,
        math.pi * 0.76,
        false,
      );
    canvas.drawPath(handlePath, handlePaint);

    // Handle inner metallic highlight
    final handleHighlight = Paint()
      ..color = const Color(0xFF333342)
      ..style = PaintingStyle.stroke
      ..strokeWidth = baseR * 0.07
      ..strokeCap = StrokeCap.round;

    final Path highlightPath = Path()
      ..arcTo(
        Rect.fromCenter(
          center: Offset(0, -baseR * 0.7),
          width: baseR * 1.1,
          height: baseR * 1.05,
        ),
        math.pi * 1.22,
        math.pi * 0.56,
        false,
      );
    canvas.drawPath(highlightPath, handleHighlight);

    // B. Body (Kettlebell ball with soft gradient)
    final Rect bodyRect = Rect.fromCircle(
      center: Offset(0, baseR * 0.25),
      radius: baseR,
    );

    final Paint bodyPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.2),
        radius: 0.9,
        colors: const [
          Color(0xFF2C2C38),
          Color(0xFF1A1A22),
          Color(0xFF101016),
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(bodyRect);

    canvas.drawCircle(Offset(0, baseR * 0.25), baseR, bodyPaint);

    // C. Neon Lime Athletic Sweatband
    canvas.save();
    final Rect clipRect = Rect.fromLTWH(
      -baseR * 1.1,
      -baseR * 0.32,
      baseR * 2.2,
      baseR * 0.38,
    );
    canvas.clipRect(clipRect);

    // Headband base
    final Paint bandPaint = Paint()..color = const Color(0xFFB2FF59);
    canvas.drawCircle(Offset(0, baseR * 0.25), baseR, bandPaint);

    // Headband athletic stripe
    final Paint bandStripe = Paint()..color = const Color(0xFF98E640);
    canvas.drawRect(
      Rect.fromLTWH(-baseR * 1.1, -baseR * 0.16, baseR * 2.2, baseR * 0.06),
      bandStripe,
    );

    // Athletic Bolt Emblem in center of sweatband
    final Paint boltPaint = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.fill;
    final Path boltPath = Path()
      ..moveTo(baseR * 0.03, -baseR * 0.26)
      ..lineTo(-baseR * 0.09, -baseR * 0.1)
      ..lineTo(-baseR * 0.02, -baseR * 0.1)
      ..lineTo(-baseR * 0.06, baseR * 0.04)
      ..lineTo(baseR * 0.09, -baseR * 0.14)
      ..lineTo(baseR * 0.01, -baseR * 0.14)
      ..close();
    canvas.drawPath(boltPath, boltPaint);
    canvas.restore();

    // D. Playful Animated Eyes (with dynamic blinking)
    final double blinkCycle = math.sin(t * 0.55);
    final bool isBlinking = blinkCycle > 0.94;
    final double eyeR = baseR * 0.125;
    final double eyeH = isBlinking ? baseR * 0.025 : eyeR * 1.45;
    final double eyeSpacing = baseR * 0.34;
    final double eyeY = baseR * 0.30;

    // Pupil look offset
    final double pupilLookX = math.sin(t * 0.7) * (baseR * 0.03);

    final Paint whitePaint = Paint()..color = Colors.white;
    final Paint pupilPaint = Paint()..color = const Color(0xFF111111);
    final Paint catchLightPaint = Paint()..color = Colors.white;

    // Left Eye
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-eyeSpacing, eyeY), width: eyeR * 1.8, height: eyeH * 1.8),
      whitePaint,
    );

    if (!isBlinking) {
      canvas.drawCircle(
        Offset(-eyeSpacing + pupilLookX, eyeY),
        eyeR * 0.72,
        pupilPaint,
      );
      canvas.drawCircle(
        Offset(-eyeSpacing + pupilLookX - eyeR * 0.22, eyeY - eyeR * 0.22),
        eyeR * 0.28,
        catchLightPaint,
      );
    }

    // Right Eye
    canvas.drawOval(
      Rect.fromCenter(center: Offset(eyeSpacing, eyeY), width: eyeR * 1.8, height: eyeH * 1.8),
      whitePaint,
    );

    if (!isBlinking) {
      canvas.drawCircle(
        Offset(eyeSpacing + pupilLookX, eyeY),
        eyeR * 0.72,
        pupilPaint,
      );
      canvas.drawCircle(
        Offset(eyeSpacing + pupilLookX - eyeR * 0.22, eyeY - eyeR * 0.22),
        eyeR * 0.28,
        catchLightPaint,
      );
    }

    // E. Confident Smile
    final smilePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = baseR * 0.04
      ..strokeCap = StrokeCap.round;

    final Path smilePath = Path()
      ..arcTo(
        Rect.fromCenter(
          center: Offset(0, baseR * 0.54),
          width: baseR * 0.32,
          height: baseR * 0.25,
        ),
        math.pi * 0.18,
        math.pi * 0.64,
        false,
      );
    canvas.drawPath(smilePath, smilePaint);

    // F. Energetic Cheeks (Soft Lime Glow)
    final Paint cheekPaint = Paint()
      ..color = const Color(0xFFB2FF59).withValues(alpha: 0.32);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(-baseR * 0.56, baseR * 0.44), width: baseR * 0.19, height: baseR * 0.12),
      cheekPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(baseR * 0.56, baseR * 0.44), width: baseR * 0.19, height: baseR * 0.12),
      cheekPaint,
    );

    canvas.restore();
  }

  void _drawStar(Canvas canvas, double x, double y, double r, Color color, double rot) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(rot);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    for (int i = 0; i < 4; i++) {
      final double a1 = (i * math.pi) / 2;
      final double a2 = a1 + math.pi / 4;
      if (i == 0) {
        path.moveTo(math.cos(a1) * r, math.sin(a1) * r);
      } else {
        path.lineTo(math.cos(a1) * r, math.sin(a1) * r);
      }
      path.lineTo(math.cos(a2) * (r * 0.36), math.sin(a2) * (r * 0.36));
    }
    path.close();
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _drawSparkleDot(Canvas canvas, double x, double y, double r, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x, y), r, paint);
  }

  @override
  bool shouldRepaint(covariant _PlayfulFitnessMascotPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
