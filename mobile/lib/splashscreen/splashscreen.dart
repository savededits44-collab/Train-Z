import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

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

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _scaleAnimation = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    _animController.forward();

    // Auto-navigate to login screen after splash animation
    Future.delayed(const Duration(milliseconds: 2800), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, anim, secondaryAnim) => const LoginScreen(),
          transitionsBuilder: (context, anim, secondaryAnim, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 550),
        ),
      );
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final double w = mq.size.width;
    final double h = mq.size.height;
    final double sf = (w / 360).clamp(0.75, 1.3);

    final double graphicSize = (190.0 * sf).clamp(150.0, 240.0);
    final double brandFontSize = (34.0 * sf).clamp(28.0, 42.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              final double t = _animController.value;
              // Smooth 3D rotation parameters
              final double rotY = 0.4 + t * (math.pi * 1.3);
              final double rotX = 0.35 + math.sin(t * math.pi * 2) * 0.08;
              final double rotZ = -0.12;

              return Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ─── 3D Gym Dumbbell Graphic ───
                      SizedBox(
                        width: graphicSize,
                        height: graphicSize,
                        child: CustomPaint(
                          painter: _ThreeDDumbbellPainter(
                            angleX: rotX,
                            angleY: rotY,
                            angleZ: rotZ,
                          ),
                        ),
                      ),

                      SizedBox(height: (h * 0.02 * sf).clamp(12.0, 22.0)),

                      // ─── Brand: TrainZ ───
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
                                letterSpacing: brandFontSize * 0.04,
                              ),
                            ),
                            TextSpan(
                              text: 'Z',
                              style: TextStyle(
                                fontFamily: 'Syne',
                                fontSize: brandFontSize,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFB2FF59),
                                letterSpacing: brandFontSize * 0.04,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: (6.0 * sf).clamp(4.0, 8.0)),

                      Text(
                        'PEAK PERFORMANCE',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: (10.0 * sf).clamp(9.0, 12.0),
                          fontWeight: FontWeight.w600,
                          letterSpacing: (3.0 * sf).clamp(2.0, 4.0),
                          color: const Color(0xFF9E9E9E),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3D Gym Hex-Dumbbell CustomPainter
// ─────────────────────────────────────────────────────────────────────────────

class _ThreeDDumbbellPainter extends CustomPainter {
  final double angleX;
  final double angleY;
  final double angleZ;

  _ThreeDDumbbellPainter({
    required this.angleX,
    required this.angleY,
    required this.angleZ,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2 - 8;

    // ── Floor Drop Shadow ──
    final double shadowScale = 1.0 + math.sin(angleY * 2) * 0.07;
    final Rect shadowRect = Rect.fromCenter(
      center: Offset(cx, cy + size.height * 0.42),
      width: size.width * 0.72 * shadowScale,
      height: size.height * 0.18 * shadowScale,
    );

    final Paint shadowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withValues(alpha: 0.12),
          Colors.black.withValues(alpha: 0.04),
          Colors.black.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(shadowRect);

    canvas.drawOval(shadowRect, shadowPaint);

    // ── 3D Projection Engine ──
    const double fov = 500.0;
    final double cosY = math.cos(angleY), sinY = math.sin(angleY);
    final double cosX = math.cos(angleX), sinX = math.sin(angleX);
    final double cosZ = math.cos(angleZ), sinZ = math.sin(angleZ);

    Offset3D project(double x, double y, double z) {
      // Y-axis rotation
      final double x1 = x * cosY + z * sinY;
      final double y1 = y;
      final double z1 = -x * sinY + z * cosY;

      // X-axis rotation
      final double x2 = x1;
      final double y2 = y1 * cosX - z1 * sinX;
      final double z2 = y1 * sinX + z1 * cosX;

      // Z-axis rotation
      final double x3 = x2 * cosZ - y2 * sinZ;
      final double y3 = x2 * sinZ + y2 * cosZ;
      final double z3 = z2;

      final double scale = fov / (fov + z3);
      return Offset3D(
        cx + x3 * scale,
        cy + y3 * scale,
        z3,
      );
    }

    // Normalized Light Vector (Top-left-front)
    const double lx = -0.4, ly = -0.7, lz = 0.6;
    final double lLen = math.sqrt(lx * lx + ly * ly + lz * lz);
    final double nlx = lx / lLen, nly = ly / lLen, nlz = lz / lLen;

    final List<_PolygonFace> faces = [];

    // 1. Central Bar Cylinders (Steel Knurling)
    const double barRadius = 6.5;
    const double barLength = 80.0;
    const int barSteps = 10;

    for (int i = 0; i < barSteps; i++) {
      final double a1 = (i * 2 * math.pi) / barSteps;
      final double a2 = ((i + 1) * 2 * math.pi) / barSteps;
      final double by1 = math.cos(a1) * barRadius, bz1 = math.sin(a1) * barRadius;
      final double by2 = math.cos(a2) * barRadius, bz2 = math.sin(a2) * barRadius;

      faces.add(
        _PolygonFace(
          vertices: [
            Vector3D(-barLength / 2, by1, bz1),
            Vector3D(barLength / 2, by1, bz1),
            Vector3D(barLength / 2, by2, bz2),
            Vector3D(-barLength / 2, by2, bz2),
          ],
          type: _FaceType.bar,
          hasLimeAccent: false,
        ),
      );
    }

    // Helper: Build Hexagonal Weight Plate
    void addHexPlate(double centerOffset, double radius, double thickness, bool hasLimeRing) {
      final List<Vector3D> frontHex = [];
      final List<Vector3D> backHex = [];

      for (int i = 0; i < 6; i++) {
        final double a = (i * math.pi) / 3;
        final double hy = math.cos(a) * radius;
        final double hz = math.sin(a) * radius;
        frontHex.add(Vector3D(centerOffset - thickness / 2, hy, hz));
        backHex.add(Vector3D(centerOffset + thickness / 2, hy, hz));
      }

      // Outer & Inner Hex Faces
      faces.add(_PolygonFace(vertices: frontHex, type: _FaceType.hexCap, hasLimeAccent: hasLimeRing));
      faces.add(_PolygonFace(vertices: backHex.reversed.toList(), type: _FaceType.hexCap, hasLimeAccent: false));

      // 6 Lateral Facets
      for (int i = 0; i < 6; i++) {
        final int next = (i + 1) % 6;
        faces.add(
          _PolygonFace(
            vertices: [
              frontHex[i],
              backHex[i],
              backHex[next],
              frontHex[next],
            ],
            type: _FaceType.hexSide,
            hasLimeAccent: false,
          ),
        );
      }
    }

    // Outer primary hex plates (with energetic lime ring)
    addHexPlate(-62.0, 52.0, 24.0, true);
    addHexPlate(62.0, 52.0, 24.0, true);

    // Inner secondary hex plates
    addHexPlate(-44.0, 42.0, 16.0, false);
    addHexPlate(44.0, 42.0, 16.0, false);

    // ── Project, Calculate Normals & Lighting ──
    final List<_ProjectedFace> projectedList = [];

    for (final face in faces) {
      final List<Offset3D> projectedPts = [];
      double sumZ = 0;

      for (final v in face.vertices) {
        final p = project(v.x, v.y, v.z);
        projectedPts.add(p);
        sumZ += p.z;
      }
      final double avgZ = sumZ / face.vertices.length;

      // Surface Normal Vector
      final v0 = face.vertices[0];
      final v1 = face.vertices[1];
      final v2 = face.vertices[2];

      final double ux = v1.x - v0.x, uy = v1.y - v0.y, uz = v1.z - v0.z;
      final double vx = v2.x - v0.x, vy = v2.y - v0.y, vz = v2.z - v0.z;

      final double nx = uy * vz - uz * vy;
      final double ny = uz * vx - ux * vz;
      final double nz = ux * vy - uy * vx;

      final double nLen = math.sqrt(nx * nx + ny * ny + nz * nz);
      final double normX = nLen > 0 ? nx / nLen : 0;
      final double normY = nLen > 0 ? ny / nLen : 0;
      final double normZ = nLen > 0 ? nz / nLen : 1;

      final double dot = math.max(0.0, normX * nlx + normY * nly + normZ * nlz);

      projectedList.add(
        _ProjectedFace(
          points: projectedPts,
          avgZ: avgZ,
          intensity: dot,
          type: face.type,
          hasLimeAccent: face.hasLimeAccent,
        ),
      );
    }

    // Painter's Algorithm: Sort Back to Front
    projectedList.sort((a, b) => b.avgZ.compareTo(a.avgZ));

    // ── Render Faces ──
    final Paint fillPaint = Paint()..style = PaintingStyle.fill;
    final Paint strokePaint = Paint()..style = PaintingStyle.stroke;

    for (final pf in projectedList) {
      final Path path = Path()..moveTo(pf.points[0].x, pf.points[0].y);
      for (int i = 1; i < pf.points.length; i++) {
        path.lineTo(pf.points[i].x, pf.points[i].y);
      }
      path.close();

      if (pf.type == _FaceType.bar) {
        // Metallic Steel Bar
        final int bVal = (150 + pf.intensity * 95).toInt().clamp(0, 255);
        fillPaint.color = Color.fromARGB(255, bVal, bVal, bVal + 5);
        canvas.drawPath(path, fillPaint);

        strokePaint.color = Color.fromARGB(255, (bVal - 25).clamp(0, 255), (bVal - 25).clamp(0, 255), (bVal - 20).clamp(0, 255));
        strokePaint.strokeWidth = 0.6;
        canvas.drawPath(path, strokePaint);
      } else if (pf.type == _FaceType.hexCap) {
        // Matte Obsidian Hex Face
        final int darkBase = (28 + pf.intensity * 46).toInt().clamp(0, 255);
        fillPaint.color = Color.fromARGB(255, darkBase, darkBase + 2, darkBase + 5);
        canvas.drawPath(path, fillPaint);

        strokePaint.color = const Color(0xFF141418);
        strokePaint.strokeWidth = 1.0;
        canvas.drawPath(path, strokePaint);

        // Lime Accent Ring on the Outer Plate Face
        if (pf.hasLimeAccent) {
          strokePaint.color = const Color(0xFFB2FF59);
          strokePaint.strokeWidth = 2.2;
          canvas.drawPath(path, strokePaint);
        }
      } else {
        // Hex Plate Side Bevel Facets
        final int facetBase = (20 + pf.intensity * 65).toInt().clamp(0, 255);
        fillPaint.color = Color.fromARGB(255, facetBase, facetBase + 1, facetBase + 3);
        canvas.drawPath(path, fillPaint);

        strokePaint.color = const Color(0xFF111116);
        strokePaint.strokeWidth = 0.8;
        canvas.drawPath(path, strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ThreeDDumbbellPainter oldDelegate) {
    return oldDelegate.angleX != angleX ||
        oldDelegate.angleY != angleY ||
        oldDelegate.angleZ != angleZ;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Geometry & Projection Data Structures
// ─────────────────────────────────────────────────────────────────────────────

enum _FaceType { bar, hexCap, hexSide }

class Vector3D {
  final double x, y, z;
  const Vector3D(this.x, this.y, this.z);
}

class Offset3D {
  final double x, y, z;
  const Offset3D(this.x, this.y, this.z);
}

class _PolygonFace {
  final List<Vector3D> vertices;
  final _FaceType type;
  final bool hasLimeAccent;

  const _PolygonFace({
    required this.vertices,
    required this.type,
    required this.hasLimeAccent,
  });
}

class _ProjectedFace {
  final List<Offset3D> points;
  final double avgZ;
  final double intensity;
  final _FaceType type;
  final bool hasLimeAccent;

  const _ProjectedFace({
    required this.points,
    required this.avgZ,
    required this.intensity,
    required this.type,
    required this.hasLimeAccent,
  });
}
